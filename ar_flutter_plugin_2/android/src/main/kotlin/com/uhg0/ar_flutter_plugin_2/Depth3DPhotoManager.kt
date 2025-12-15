package com.uhg0.ar_flutter_plugin_2

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import android.util.Log
import com.google.android.filament.Box
import com.google.android.filament.Engine
import com.google.android.filament.EntityManager
import com.google.android.filament.IndexBuffer
import com.google.android.filament.MaterialInstance
import com.google.android.filament.RenderableManager
import com.google.android.filament.Texture
import com.google.android.filament.TextureSampler
import com.google.android.filament.VertexBuffer
import com.google.android.filament.android.TextureHelper
import com.google.ar.core.CameraIntrinsics
import com.google.ar.core.Frame
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.NotYetAvailableException
import io.flutter.plugin.common.MethodChannel
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.loaders.MaterialLoader
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer

/**
 * Depth3DPhotoManager - Creates 3D photo effect from 2D image using ARCore Depth
 * 
 * Workflow:
 * 1. Capture camera image (RGB) + depth map
 * 2. Unproject depth pixels to 3D vertices (CPU)
 * 3. Create textured mesh from vertices
 * 4. Animate virtual camera around the scene for parallax effect
 * 
 * Requirements:
 * - Device must support ARCore Depth API
 * - Config.DepthMode.AUTOMATIC must be enabled
 * - World AR mode only (not Face AR)
 */
class Depth3DPhotoManager(
    private val context: Context,
    private val sessionChannel: MethodChannel,
    private val mainScope: CoroutineScope
) {
    companion object {
        private const val TAG = "Depth3DPhotoManager"
        
        // Mesh resolution (lower = better performance, higher = more detail)
        private const val MESH_WIDTH = 80   // Number of columns
        private const val MESH_HEIGHT = 60  // Number of rows
        private const val VERTEX_COUNT = MESH_WIDTH * MESH_HEIGHT
        private const val INDEX_COUNT = (MESH_WIDTH - 1) * (MESH_HEIGHT - 1) * 6  // 2 triangles per cell
        
        // Animation
        private const val ANIMATION_RADIUS = 0.05f  // Camera orbit radius in meters
        private const val ANIMATION_SPEED = 1.0f    // Radians per second
    }
    
    // ========== State ==========
    private var sceneView: ARSceneView? = null
    private var is3DPhotoActive = false
    private var depthMeshRenderer: DepthMeshRenderer? = null
    
    // Captured data
    private var capturedCameraBitmap: Bitmap? = null
    private var capturedDepthData: ShortArray? = null
    private var capturedDepthWidth: Int = 0
    private var capturedDepthHeight: Int = 0
    private var capturedIntrinsics: CameraIntrinsics? = null
    private var capturedCameraPose: FloatArray? = null
    
    // Animation state
    private var isAnimating = false
    private var animationAngle = 0f
    private var originalCameraPosition: FloatArray? = null
    
    // ========== Inner Class: DepthMeshRenderer ==========
    
    /**
     * Renders a textured mesh created from depth data
     */
    inner class DepthMeshRenderer(
        private val engine: Engine,
        private val scene: com.google.android.filament.Scene,
        private val materialLoader: MaterialLoader
    ) {
        private val MESH_TAG = "DepthMeshRenderer"
        
        private var entity: Int = 0
        private var vertexBuffer: VertexBuffer? = null
        private var indexBuffer: IndexBuffer? = null
        private var materialInstance: MaterialInstance? = null
        private var texture: Texture? = null
        
        private var isInitialized = false
        private var isVisible = true
        
        // Buffers
        private val positionBuffer: FloatBuffer = ByteBuffer
            .allocateDirect(VERTEX_COUNT * 3 * Float.SIZE_BYTES)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
        
        private val uvBuffer: FloatBuffer = ByteBuffer
            .allocateDirect(VERTEX_COUNT * 2 * Float.SIZE_BYTES)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
        
        private val indexData: ShortBuffer = ByteBuffer
            .allocateDirect(INDEX_COUNT * Short.SIZE_BYTES)
            .order(ByteOrder.nativeOrder())
            .asShortBuffer()
        
        /**
         * Initialize the mesh with depth data and camera image
         */
        fun initialize(
            depthData: ShortArray,
            depthWidth: Int,
            depthHeight: Int,
            cameraBitmap: Bitmap,
            intrinsics: CameraIntrinsics,
            cameraPose: FloatArray
        ) {
            if (isInitialized) {
                destroy()
            }
            
            try {
                Log.d(MESH_TAG, "🖼️ Initializing DepthMeshRenderer...")
                Log.d(MESH_TAG, "   Depth: ${depthWidth}x${depthHeight}")
                Log.d(MESH_TAG, "   Camera: ${cameraBitmap.width}x${cameraBitmap.height}")
                Log.d(MESH_TAG, "   Mesh: ${MESH_WIDTH}x${MESH_HEIGHT} = $VERTEX_COUNT vertices")
                
                // 1. Generate vertex positions from depth (unprojection)
                generateVerticesFromDepth(depthData, depthWidth, depthHeight, intrinsics, cameraPose)
                
                // 2. Generate UVs for texture mapping
                generateUVs()
                
                // 3. Generate triangle indices
                generateIndices()
                
                // 4. Create Filament buffers
                createVertexBuffer()
                createIndexBuffer()
                
                // 5. Create texture from camera image
                createTexture(cameraBitmap)
                
                // 6. Create material with texture
                createMaterial()
                
                // 7. Create renderable entity
                createRenderable()
                
                isInitialized = true
                isVisible = true
                
                Log.d(MESH_TAG, "✅ DepthMeshRenderer initialized!")
                
            } catch (e: Exception) {
                Log.e(MESH_TAG, "❌ Failed to initialize DepthMeshRenderer", e)
                destroy()
            }
        }
        
        /**
         * Unproject depth pixels to 3D world coordinates
         * Formula: X = depth * (u - cx) / fx
         *          Y = depth * (cy - v) / fy
         *          Z = -depth
         */
        private fun generateVerticesFromDepth(
            depthData: ShortArray,
            depthWidth: Int,
            depthHeight: Int,
            intrinsics: CameraIntrinsics,
            cameraPose: FloatArray
        ) {
            val fx = intrinsics.focalLength[0]
            val fy = intrinsics.focalLength[1]
            val cx = intrinsics.principalPoint[0]
            val cy = intrinsics.principalPoint[1]
            
            Log.d(MESH_TAG, "📐 Camera intrinsics: fx=$fx, fy=$fy, cx=$cx, cy=$cy")
            
            positionBuffer.clear()
            
            for (row in 0 until MESH_HEIGHT) {
                for (col in 0 until MESH_WIDTH) {
                    // Map mesh grid to depth image coordinates
                    val depthU = (col.toFloat() / (MESH_WIDTH - 1)) * (depthWidth - 1)
                    val depthV = (row.toFloat() / (MESH_HEIGHT - 1)) * (depthHeight - 1)
                    
                    // Get depth value (bilinear interpolation for smoothness)
                    val depthMillimeters = sampleDepthBilinear(depthData, depthWidth, depthHeight, depthU, depthV)
                    val depthMeters = depthMillimeters / 1000f
                    
                    // Unproject to camera space
                    val pointX: Float
                    val pointY: Float
                    val pointZ: Float
                    
                    if (depthMeters > 0.1f && depthMeters < 10f) {
                        // Valid depth - unproject
                        pointX = depthMeters * (depthU - cx) / fx
                        pointY = depthMeters * (cy - depthV) / fy
                        pointZ = -depthMeters
                    } else {
                        // Invalid depth - use default distance
                        val defaultDepth = 1.5f
                        pointX = defaultDepth * (depthU - cx) / fx
                        pointY = defaultDepth * (cy - depthV) / fy
                        pointZ = -defaultDepth
                    }
                    
                    // Transform to world coordinates using camera pose
                    val worldPos = transformToWorld(pointX, pointY, pointZ, cameraPose)
                    
                    positionBuffer.put(worldPos[0])
                    positionBuffer.put(worldPos[1])
                    positionBuffer.put(worldPos[2])
                }
            }
            
            positionBuffer.rewind()
            Log.d(MESH_TAG, "📍 Generated $VERTEX_COUNT vertex positions")
        }
        
        /**
         * Sample depth with bilinear interpolation
         */
        private fun sampleDepthBilinear(
            depthData: ShortArray,
            width: Int,
            height: Int,
            u: Float,
            v: Float
        ): Float {
            val x0 = u.toInt().coerceIn(0, width - 1)
            val y0 = v.toInt().coerceIn(0, height - 1)
            val x1 = (x0 + 1).coerceIn(0, width - 1)
            val y1 = (y0 + 1).coerceIn(0, height - 1)
            
            val fx = u - x0
            val fy = v - y0
            
            val d00 = depthData[y0 * width + x0].toInt() and 0xFFFF
            val d10 = depthData[y0 * width + x1].toInt() and 0xFFFF
            val d01 = depthData[y1 * width + x0].toInt() and 0xFFFF
            val d11 = depthData[y1 * width + x1].toInt() and 0xFFFF
            
            val d0 = d00 * (1 - fx) + d10 * fx
            val d1 = d01 * (1 - fx) + d11 * fx
            
            return (d0 * (1 - fy) + d1 * fy)
        }
        
        /**
         * Transform point from camera space to world space
         */
        private fun transformToWorld(x: Float, y: Float, z: Float, pose: FloatArray): FloatArray {
            // pose is a 4x4 column-major matrix
            val wx = pose[0] * x + pose[4] * y + pose[8] * z + pose[12]
            val wy = pose[1] * x + pose[5] * y + pose[9] * z + pose[13]
            val wz = pose[2] * x + pose[6] * y + pose[10] * z + pose[14]
            return floatArrayOf(wx, wy, wz)
        }
        
        /**
         * Generate UV coordinates for texture mapping
         */
        private fun generateUVs() {
            uvBuffer.clear()
            
            for (row in 0 until MESH_HEIGHT) {
                for (col in 0 until MESH_WIDTH) {
                    val u = col.toFloat() / (MESH_WIDTH - 1)
                    val v = row.toFloat() / (MESH_HEIGHT - 1)
                    
                    uvBuffer.put(u)
                    uvBuffer.put(v)
                }
            }
            
            uvBuffer.rewind()
            Log.d(MESH_TAG, "🎨 Generated $VERTEX_COUNT UV coordinates")
        }
        
        /**
         * Generate triangle indices for the mesh grid
         */
        private fun generateIndices() {
            indexData.clear()
            
            for (row in 0 until MESH_HEIGHT - 1) {
                for (col in 0 until MESH_WIDTH - 1) {
                    val topLeft = (row * MESH_WIDTH + col).toShort()
                    val topRight = (row * MESH_WIDTH + col + 1).toShort()
                    val bottomLeft = ((row + 1) * MESH_WIDTH + col).toShort()
                    val bottomRight = ((row + 1) * MESH_WIDTH + col + 1).toShort()
                    
                    // First triangle (top-left, bottom-left, top-right)
                    indexData.put(topLeft)
                    indexData.put(bottomLeft)
                    indexData.put(topRight)
                    
                    // Second triangle (top-right, bottom-left, bottom-right)
                    indexData.put(topRight)
                    indexData.put(bottomLeft)
                    indexData.put(bottomRight)
                }
            }
            
            indexData.rewind()
            Log.d(MESH_TAG, "📐 Generated $INDEX_COUNT indices")
        }
        
        private fun createVertexBuffer() {
            vertexBuffer = VertexBuffer.Builder()
                .bufferCount(2)
                .vertexCount(VERTEX_COUNT)
                .attribute(
                    VertexBuffer.VertexAttribute.POSITION,
                    0,
                    VertexBuffer.AttributeType.FLOAT3,
                    0,
                    3 * Float.SIZE_BYTES
                )
                .attribute(
                    VertexBuffer.VertexAttribute.UV0,
                    1,
                    VertexBuffer.AttributeType.FLOAT2,
                    0,
                    2 * Float.SIZE_BYTES
                )
                .build(engine)
            
            vertexBuffer?.setBufferAt(engine, 0, positionBuffer)
            vertexBuffer?.setBufferAt(engine, 1, uvBuffer)
            
            Log.d(MESH_TAG, "📐 VertexBuffer created")
        }
        
        private fun createIndexBuffer() {
            indexBuffer = IndexBuffer.Builder()
                .indexCount(INDEX_COUNT)
                .bufferType(IndexBuffer.Builder.IndexType.USHORT)
                .build(engine)
            
            indexBuffer?.setBuffer(engine, indexData)
            
            Log.d(MESH_TAG, "📐 IndexBuffer created")
        }
        
        private fun createTexture(bitmap: Bitmap) {
            texture = Texture.Builder()
                .width(bitmap.width)
                .height(bitmap.height)
                .sampler(Texture.Sampler.SAMPLER_2D)
                .format(Texture.InternalFormat.SRGB8_A8)
                .levels(1)
                .build(engine)
            
            TextureHelper.setBitmap(engine, texture!!, 0, bitmap)
            
            Log.d(MESH_TAG, "🖼️ Texture created (${bitmap.width}x${bitmap.height})")
        }
        
        private fun createMaterial() {
            // Create unlit material with texture using SceneView's MaterialLoader
            materialInstance = materialLoader.createImageInstance(
                imageTexture = texture!!
            )
            
            Log.d(MESH_TAG, "🎨 Material created with texture")
        }
        
        private fun createRenderable() {
            entity = EntityManager.get().create()
            
            RenderableManager.Builder(1)
                .boundingBox(Box(0f, 0f, 0f, 10f, 10f, 10f))
                .geometry(
                    0,
                    RenderableManager.PrimitiveType.TRIANGLES,
                    vertexBuffer!!,
                    indexBuffer!!,
                    0,
                    INDEX_COUNT
                )
                .material(0, materialInstance!!)
                .culling(false)
                .castShadows(false)
                .receiveShadows(false)
                .build(engine, entity)
            
            scene.addEntity(entity)
            
            Log.d(MESH_TAG, "🎭 Renderable created and added to scene")
        }
        
        fun setVisible(visible: Boolean) {
            if (!isInitialized || isVisible == visible) return
            isVisible = visible
            
            if (visible) {
                scene.addEntity(entity)
            } else {
                scene.removeEntity(entity)
            }
        }
        
        fun destroy() {
            if (entity != 0) {
                try {
                    scene.removeEntity(entity)
                    engine.destroyEntity(entity)
                    EntityManager.get().destroy(entity)
                } catch (e: Exception) {
                    Log.e(MESH_TAG, "Error destroying entity", e)
                }
                entity = 0
            }
            
            vertexBuffer?.let {
                try { engine.destroyVertexBuffer(it) } catch (e: Exception) {}
            }
            vertexBuffer = null
            
            indexBuffer?.let {
                try { engine.destroyIndexBuffer(it) } catch (e: Exception) {}
            }
            indexBuffer = null
            
            texture?.let {
                try { engine.destroyTexture(it) } catch (e: Exception) {}
            }
            texture = null
            
            materialInstance?.let {
                try { engine.destroyMaterialInstance(it) } catch (e: Exception) {}
            }
            materialInstance = null
            
            isInitialized = false
            Log.d(MESH_TAG, "🧹 DepthMeshRenderer destroyed")
        }
    }
    
    // ========== Public API ==========
    
    fun setSceneView(sv: ARSceneView) {
        sceneView = sv
    }
    
    /**
     * Capture current frame as 3D photo
     * Call this when user taps "Capture 3D Photo" button
     */
    fun handleCapture3DPhoto(result: MethodChannel.Result) {
        val sv = sceneView
        if (sv == null) {
            result.error("NO_SCENEVIEW", "SceneView not available", null)
            return
        }
        
        mainScope.launch {
            try {
                val frame = sv.session?.update()
                if (frame == null) {
                    result.error("NO_FRAME", "Could not get AR frame", null)
                    return@launch
                }
                
                val camera = frame.camera
                if (camera.trackingState != TrackingState.TRACKING) {
                    result.error("NOT_TRACKING", "Camera is not tracking", null)
                    return@launch
                }
                
                Log.d(TAG, "📸 Capturing 3D photo...")
                
                // 1. Capture depth image
                val depthResult = captureDepthImage(frame)
                if (depthResult == null) {
                    result.error(
                        "NO_DEPTH",
                        "Could not capture depth image. Make sure depth mode is enabled.",
                        null
                    )
                    return@launch
                }
                
                capturedDepthData = depthResult.first
                capturedDepthWidth = depthResult.second
                capturedDepthHeight = depthResult.third
                
                Log.d(TAG, "   Depth captured: ${capturedDepthWidth}x${capturedDepthHeight}")
                
                // 2. Capture camera image
                capturedCameraBitmap = captureCameraImage(frame)
                if (capturedCameraBitmap == null) {
                    result.error("NO_IMAGE", "Could not capture camera image", null)
                    return@launch
                }
                
                Log.d(TAG, "   Camera image captured: ${capturedCameraBitmap!!.width}x${capturedCameraBitmap!!.height}")
                
                // 3. Capture camera intrinsics and pose
                capturedIntrinsics = camera.textureIntrinsics
                capturedCameraPose = FloatArray(16).also {
                    camera.displayOrientedPose.toMatrix(it, 0)
                }
                
                // 4. Create the 3D mesh
                create3DMesh()
                
                is3DPhotoActive = true
                
                Log.d(TAG, "✅ 3D photo captured successfully!")
                
                result.success(mapOf(
                    "success" to true,
                    "depthWidth" to capturedDepthWidth,
                    "depthHeight" to capturedDepthHeight,
                    "imageWidth" to capturedCameraBitmap!!.width,
                    "imageHeight" to capturedCameraBitmap!!.height
                ))
                
                // Notify Flutter
                notifyCapture3DPhotoComplete(true)
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error capturing 3D photo", e)
                result.error("CAPTURE_ERROR", e.message, null)
                notifyCapture3DPhotoComplete(false)
            }
        }
    }
    
    /**
     * Start animation (camera orbiting around the scene)
     */
    fun handleStartAnimation(result: MethodChannel.Result) {
        if (!is3DPhotoActive) {
            result.error("NO_3D_PHOTO", "No 3D photo captured", null)
            return
        }
        
        isAnimating = true
        animationAngle = 0f
        
        // Store original camera position for orbiting
        val sv = sceneView
        sv?.session?.update()?.camera?.let { camera ->
            originalCameraPosition = FloatArray(3).apply {
                this[0] = camera.displayOrientedPose.tx()
                this[1] = camera.displayOrientedPose.ty()
                this[2] = camera.displayOrientedPose.tz()
            }
        }
        
        Log.d(TAG, "🎬 Animation started")
        result.success(mapOf("success" to true))
    }
    
    /**
     * Stop animation
     */
    fun handleStopAnimation(result: MethodChannel.Result) {
        isAnimating = false
        Log.d(TAG, "⏹️ Animation stopped")
        result.success(mapOf("success" to true))
    }
    
    /**
     * Clear 3D photo and return to live camera
     */
    fun handleClear3DPhoto(result: MethodChannel.Result) {
        cleanup()
        Log.d(TAG, "🧹 3D photo cleared")
        result.success(mapOf("success" to true))
    }
    
    /**
     * Get depth info for current frame (for debugging)
     */
    fun handleGetDepthInfo(result: MethodChannel.Result) {
        val sv = sceneView
        if (sv == null) {
            result.error("NO_SCENEVIEW", "SceneView not available", null)
            return
        }
        
        mainScope.launch {
            try {
                val frame = sv.session?.update()
                if (frame == null) {
                    result.error("NO_FRAME", "Could not get AR frame", null)
                    return@launch
                }
                
                val depthResult = captureDepthImage(frame)
                if (depthResult == null) {
                    result.success(mapOf(
                        "available" to false,
                        "reason" to "Depth not available"
                    ))
                    return@launch
                }
                
                val (depthData, width, height) = depthResult
                
                // Analyze depth data
                var minDepth = Int.MAX_VALUE
                var maxDepth = 0
                var sumDepth = 0L
                var validCount = 0
                
                for (d in depthData) {
                    val depth = d.toInt() and 0xFFFF
                    if (depth > 0 && depth < 65535) {
                        minDepth = minOf(minDepth, depth)
                        maxDepth = maxOf(maxDepth, depth)
                        sumDepth += depth
                        validCount++
                    }
                }
                
                val avgDepth = if (validCount > 0) sumDepth / validCount else 0
                val centerDepth = depthData[(height / 2) * width + (width / 2)].toInt() and 0xFFFF
                
                result.success(mapOf(
                    "available" to true,
                    "width" to width,
                    "height" to height,
                    "minDepthMm" to minDepth,
                    "maxDepthMm" to maxDepth,
                    "avgDepthMm" to avgDepth,
                    "centerDepthMm" to centerDepth,
                    "validPixels" to validCount,
                    "totalPixels" to depthData.size
                ))
                
            } catch (e: Exception) {
                Log.e(TAG, "Error getting depth info", e)
                result.error("DEPTH_INFO_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Called every frame to update animation
     */
    fun onFrame(deltaTime: Float) {
        if (!is3DPhotoActive || !isAnimating) return
        
        // Update animation angle
        animationAngle += ANIMATION_SPEED * deltaTime
        if (animationAngle > 2 * Math.PI) {
            animationAngle -= (2 * Math.PI).toFloat()
        }
        
        // TODO: Move virtual camera in orbit
        // This requires manipulating the SceneView camera which may need
        // additional APIs not directly exposed
    }
    
    // ========== Private Methods ==========
    
    /**
     * Capture depth image from ARCore frame
     * Returns (depthData, width, height) or null if not available
     */
    private fun captureDepthImage(frame: Frame): Triple<ShortArray, Int, Int>? {
        return try {
            val depthImage = frame.acquireDepthImage16Bits()
            
            val width = depthImage.width
            val height = depthImage.height
            val plane = depthImage.planes[0]
            val buffer = plane.buffer
            
            // Convert to ShortArray
            val depthData = ShortArray(width * height)
            buffer.rewind()
            buffer.asShortBuffer().get(depthData)
            
            depthImage.close()
            
            Triple(depthData, width, height)
            
        } catch (e: NotYetAvailableException) {
            Log.w(TAG, "Depth not yet available")
            null
        } catch (e: Exception) {
            Log.e(TAG, "Error capturing depth image", e)
            null
        }
    }
    
    /**
     * Capture camera image as Bitmap
     */
    private fun captureCameraImage(frame: Frame): Bitmap? {
        return try {
            val cameraImage = frame.acquireCameraImage()
            
            val bitmap = yuvImageToBitmap(cameraImage)
            
            cameraImage.close()
            
            bitmap
            
        } catch (e: NotYetAvailableException) {
            Log.w(TAG, "Camera image not yet available")
            null
        } catch (e: Exception) {
            Log.e(TAG, "Error capturing camera image", e)
            null
        }
    }
    
    /**
     * Convert YUV_420_888 Image to Bitmap
     */
    private fun yuvImageToBitmap(image: Image): Bitmap {
        val width = image.width
        val height = image.height
        
        val yPlane = image.planes[0]
        val uPlane = image.planes[1]
        val vPlane = image.planes[2]
        
        val yBuffer = yPlane.buffer
        val uBuffer = uPlane.buffer
        val vBuffer = vPlane.buffer
        
        val ySize = yBuffer.remaining()
        val uSize = uBuffer.remaining()
        val vSize = vBuffer.remaining()
        
        val nv21 = ByteArray(ySize + uSize + vSize)
        
        yBuffer.get(nv21, 0, ySize)
        vBuffer.get(nv21, ySize, vSize)
        uBuffer.get(nv21, ySize + vSize, uSize)
        
        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 90, out)
        val imageBytes = out.toByteArray()
        
        return BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
    }
    
    /**
     * Create 3D mesh from captured data
     */
    private fun create3DMesh() {
        val sv = sceneView ?: return
        val depth = capturedDepthData ?: return
        val bitmap = capturedCameraBitmap ?: return
        val intrinsics = capturedIntrinsics ?: return
        val pose = capturedCameraPose ?: return
        
        // Destroy existing renderer
        depthMeshRenderer?.destroy()
        
        // Create new renderer
        val engine = sv.engine
        val scene = sv.scene
        val materialLoader = MaterialLoader(engine, context)
        
        depthMeshRenderer = DepthMeshRenderer(engine, scene, materialLoader)
        depthMeshRenderer?.initialize(
            depth,
            capturedDepthWidth,
            capturedDepthHeight,
            bitmap,
            intrinsics,
            pose
        )
    }
    
    // ========== Cleanup ==========
    
    fun cleanup() {
        depthMeshRenderer?.destroy()
        depthMeshRenderer = null
        
        capturedCameraBitmap?.recycle()
        capturedCameraBitmap = null
        capturedDepthData = null
        capturedIntrinsics = null
        capturedCameraPose = null
        
        is3DPhotoActive = false
        isAnimating = false
        
        Log.d(TAG, "🧹 Depth3DPhotoManager cleaned up")
    }
    
    // ========== Notifications ==========
    
    private fun notifyCapture3DPhotoComplete(success: Boolean) {
        mainScope.launch {
            sessionChannel.invokeMethod("on3DPhotoCaptured", mapOf("success" to success))
        }
    }
}