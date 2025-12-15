package com.uhg0.ar_flutter_plugin_2

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.google.android.filament.Box
import com.google.android.filament.Engine
import com.google.android.filament.EntityManager
import com.google.android.filament.IndexBuffer
import com.google.android.filament.MaterialInstance
import com.google.android.filament.RenderableManager
import com.google.android.filament.Texture
import com.google.android.filament.VertexBuffer
import com.google.android.filament.android.TextureHelper
import com.google.ar.core.AugmentedImage
import com.google.ar.core.AugmentedImageDatabase
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Pose
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.loaders.MaterialLoader
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer
import kotlin.math.abs

/**
 * AugmentedImage3DManager - Gestionnaire de l'effet 3D sur images augmentées
 * 
 * Cette classe gère :
 * - La détection d'images connues via ARCore Augmented Images
 * - Le chargement des images de référence et leurs depth maps
 * - L'effet parallaxe 3D basé sur la position de la caméra
 * - Les notifications vers Flutter
 * 
 * Workflow:
 * 1. Charger les images de référence dans la base de données ARCore
 * 2. Détecter les images dans le monde réel
 * 3. Quand activé, afficher un quad avec effet parallaxe
 * 4. L'effet utilise la depth map pour simuler la 3D
 */
class AugmentedImage3DManager(
    private val context: Context,
    private val sessionChannel: MethodChannel,
    private val mainScope: CoroutineScope
) {
    companion object {
        private const val TAG = "AugmentedImage3DManager"
        
        // Parallax effect settings
        private const val PARALLAX_STRENGTH = 0.03f  // How much the image moves
        private const val QUAD_SEGMENTS = 80  // Grid resolution for mesh deformation
    }
    
    // ========== State ==========
    private var sceneView: ARSceneView? = null
    private var isEnabled = false
    private var imageDatabase: AugmentedImageDatabase? = null
    
    // Tracked images
    private val trackedImages = mutableMapOf<String, TrackedImageInfo>()
    private var activeImageName: String? = null
    
    // 3D Effect renderer
    private var parallaxRenderer: ParallaxRenderer? = null
    
    // Image data cache
    internal data class ImageData(
        val name: String,
        val image: Bitmap,
        val depthMap: Bitmap,
        val physicalWidth: Float  // in meters
    )
    private val loadedImages = mutableMapOf<String, ImageData>()
    
    // Tracking info for detected images
    private data class TrackedImageInfo(
        val name: String,
        var pose: Pose,
        var extentX: Float,
        var extentZ: Float,
        var trackingState: TrackingState,
        var lastUpdateTime: Long
    )
    
    // ========== ParallaxRenderer Inner Class ==========
    /**
     * ParallaxRenderer - Renders a quad with parallax displacement effect
     * Uses the depth map to displace vertices based on camera position
     */
    inner class ParallaxRenderer(
        private val engine: Engine,
        private val scene: com.google.android.filament.Scene,
        private val materialLoader: MaterialLoader
    ) {
        private val RENDERER_TAG = "ParallaxRenderer"
        
        // Grid dimensions
        private val gridWidth = QUAD_SEGMENTS
        private val gridHeight = QUAD_SEGMENTS
        private val vertexCount = (gridWidth + 1) * (gridHeight + 1)
        private val indexCount = gridWidth * gridHeight * 6
        
        // Filament resources
        private var entity: Int = 0
        private var vertexBuffer: VertexBuffer? = null
        private var indexBuffer: IndexBuffer? = null
        private var materialInstance: MaterialInstance? = null
        private var imageTexture: Texture? = null
        private var depthTexture: Texture? = null
        
        // Buffers
        private val positionBuffer: FloatBuffer = ByteBuffer
            .allocateDirect(vertexCount * 3 * Float.SIZE_BYTES)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            
        private val uvBuffer: FloatBuffer = ByteBuffer
            .allocateDirect(vertexCount * 2 * Float.SIZE_BYTES)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            
        private val indexData: ShortBuffer = ByteBuffer
            .allocateDirect(indexCount * Short.SIZE_BYTES)
            .order(ByteOrder.nativeOrder())
            .asShortBuffer()
        
        // State
        private var isInitialized = false
        private var isVisible = false
        private var currentImageData: ImageData? = null
        private var currentPose: Pose? = null
        private var quadWidth = 1f
        private var quadHeight = 1f
        
        // Base positions (without displacement)
        private val basePositions = FloatArray(vertexCount * 3)
        
        // Depth values cache
        private var depthValues: FloatArray? = null
        
        internal fun initialize(imageData: ImageData, pose: Pose, extentX: Float, extentZ: Float) {
            if (isInitialized) {
                destroy()
            }
            
            try {
                Log.d(RENDERER_TAG, "🖼️ Initializing ParallaxRenderer for: ${imageData.name}")
                Log.d(RENDERER_TAG, "   Image size: ${imageData.image.width}x${imageData.image.height}")
                Log.d(RENDERER_TAG, "   Depth size: ${imageData.depthMap.width}x${imageData.depthMap.height}")
                Log.d(RENDERER_TAG, "   Physical extent: ${extentX}m x ${extentZ}m")
                
                currentImageData = imageData
                currentPose = pose
                quadWidth = extentX
                quadHeight = extentZ
                
                // Cache depth values
                cacheDepthValues(imageData.depthMap)
                
                // Generate mesh
                generateBaseMesh()
                generateUVs()
                generateIndices()
                
                // Create Filament resources
                createVertexBuffer()
                createIndexBuffer()
                createTextures(imageData)
                createMaterial()
                createRenderable()
                
                isInitialized = true
                isVisible = true
                
                Log.d(RENDERER_TAG, "✅ ParallaxRenderer initialized!")
                
            } catch (e: Exception) {
                Log.e(RENDERER_TAG, "❌ Failed to initialize ParallaxRenderer", e)
            }
        }
        
        private fun cacheDepthValues(depthMap: Bitmap) {
            depthValues = FloatArray(vertexCount)
            
            for (row in 0..gridHeight) {
                for (col in 0..gridWidth) {
                    val u = col.toFloat() / gridWidth
                    val v = row.toFloat() / gridHeight
                    
                    // Sample depth map (bitmap origin is top-left)
                    val pixelX = (u * (depthMap.width - 1)).toInt().coerceIn(0, depthMap.width - 1)
                    val pixelY = (v * (depthMap.height - 1)).toInt().coerceIn(0, depthMap.height - 1)
                    val pixel = depthMap.getPixel(pixelX, pixelY)
                    
                    // Convert to normalized depth (0-1, where 1 is closest/white)
                    val gray = (android.graphics.Color.red(pixel) + 
                               android.graphics.Color.green(pixel) + 
                               android.graphics.Color.blue(pixel)) / (3f * 255f)
                    
                    val index = row * (gridWidth + 1) + col
                    depthValues!![index] = gray
                }
            }
        }
        
        private fun generateBaseMesh() {
            positionBuffer.clear()
            
            val halfWidth = quadWidth / 2f
            val halfHeight = quadHeight / 2f
            
            var idx = 0
            for (row in 0..gridHeight) {
                for (col in 0..gridWidth) {
                    val u = col.toFloat() / gridWidth
                    val v = row.toFloat() / gridHeight
                    
                    // Position in local space (centered at origin)
                    val x = (u - 0.5f) * quadWidth
                    val y = 0f  // Flat on the surface
                    val z = (v - 0.5f) * quadHeight
                    
                    basePositions[idx * 3] = x
                    basePositions[idx * 3 + 1] = y
                    basePositions[idx * 3 + 2] = z
                    
                    positionBuffer.put(x)
                    positionBuffer.put(y)
                    positionBuffer.put(z)
                    
                    idx++
                }
            }
            positionBuffer.rewind()
        }
        
        private fun generateUVs() {
            uvBuffer.clear()
            
            for (row in 0..gridHeight) {
                for (col in 0..gridWidth) {
                    val u = col.toFloat() / gridWidth
                    // Invert V coordinate (texture origin is bottom-left, image origin is top-left)
                    val v = 1.0f - (row.toFloat() / gridHeight)
                    
                    uvBuffer.put(u)
                    uvBuffer.put(v)
                }
            }
            uvBuffer.rewind()
        }
        
        private fun generateIndices() {
            indexData.clear()
            
            for (row in 0 until gridHeight) {
                for (col in 0 until gridWidth) {
                    val topLeft = row * (gridWidth + 1) + col
                    val topRight = topLeft + 1
                    val bottomLeft = (row + 1) * (gridWidth + 1) + col
                    val bottomRight = bottomLeft + 1
                    
                    // First triangle
                    indexData.put(topLeft.toShort())
                    indexData.put(bottomLeft.toShort())
                    indexData.put(topRight.toShort())
                    
                    // Second triangle
                    indexData.put(topRight.toShort())
                    indexData.put(bottomLeft.toShort())
                    indexData.put(bottomRight.toShort())
                }
            }
            indexData.rewind()
        }
        
        private fun createVertexBuffer() {
            vertexBuffer = VertexBuffer.Builder()
                .bufferCount(2)
                .vertexCount(vertexCount)
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
        }
        
        private fun createIndexBuffer() {
            indexBuffer = IndexBuffer.Builder()
                .indexCount(indexCount)
                .bufferType(IndexBuffer.Builder.IndexType.USHORT)
                .build(engine)
            
            indexBuffer?.setBuffer(engine, indexData)
        }
        
        private fun createTextures(imageData: ImageData) {
            // Main image texture
            imageTexture = Texture.Builder()
                .width(imageData.image.width)
                .height(imageData.image.height)
                .sampler(Texture.Sampler.SAMPLER_2D)
                .format(Texture.InternalFormat.SRGB8_A8)
                .levels(1)
                .build(engine)
            
            TextureHelper.setBitmap(engine, imageTexture!!, 0, imageData.image)
            
            // Depth map texture (for reference, not used in current simple implementation)
            depthTexture = Texture.Builder()
                .width(imageData.depthMap.width)
                .height(imageData.depthMap.height)
                .sampler(Texture.Sampler.SAMPLER_2D)
                .format(Texture.InternalFormat.R8)
                .levels(1)
                .build(engine)
            
            Log.d(RENDERER_TAG, "🎨 Textures created")
        }
        
        private fun createMaterial() {
            // Use unlit material with image texture
            materialInstance = materialLoader.createImageInstance(
                imageTexture = imageTexture!!
            )
            Log.d(RENDERER_TAG, "🎨 Material created")
        }
        
        private fun createRenderable() {
            entity = EntityManager.get().create()
            
            val halfWidth = quadWidth / 2f
            val halfHeight = quadHeight / 2f
            
            RenderableManager.Builder(1)
                .boundingBox(Box(
                    -halfWidth, -0.1f, -halfHeight,
                    halfWidth, 0.1f, halfHeight
                ))
                .geometry(
                    0,
                    RenderableManager.PrimitiveType.TRIANGLES,
                    vertexBuffer!!,
                    indexBuffer!!,
                    0,
                    indexCount
                )
                .material(0, materialInstance!!)
                .culling(false)
                .castShadows(false)
                .receiveShadows(false)
                .build(engine, entity)
            
            scene.addEntity(entity)
            Log.d(RENDERER_TAG, "✅ Renderable created and added to scene")
        }
        
        /**
         * Update the parallax effect based on camera position
         */
        fun updateParallax(cameraPose: Pose, imagePose: Pose) {
            if (!isInitialized || !isVisible || depthValues == null) return
            
            // Calculate camera offset relative to image center
            val imagePos = imagePose.translation
            val cameraPos = cameraPose.translation
            
            // Offset in image's local space
            val dx = cameraPos[0] - imagePos[0]
            val dz = cameraPos[2] - imagePos[2]
            
            // Update vertex positions with parallax displacement
            positionBuffer.clear()
            
            for (i in 0 until vertexCount) {
                val depth = depthValues!![i]
                
                // Displacement based on depth and camera offset
                // Closer pixels (higher depth value) move more
                val displacement = (depth - 0.5f) * PARALLAX_STRENGTH
                
                val baseX = basePositions[i * 3]
                val baseY = basePositions[i * 3 + 1]
                val baseZ = basePositions[i * 3 + 2]
                
                // Apply displacement
                val newX = baseX + dx * displacement
                val newY = baseY + depth * PARALLAX_STRENGTH * 0.5f  // Slight height variation
                val newZ = baseZ + dz * displacement
                
                positionBuffer.put(newX)
                positionBuffer.put(newY)
                positionBuffer.put(newZ)
            }
            positionBuffer.rewind()
            
            // Update vertex buffer
            vertexBuffer?.setBufferAt(engine, 0, positionBuffer)
            
            // Update transform to match image pose
            val transformManager = engine.transformManager
            val instance = transformManager.getInstance(entity)
            if (instance != 0) {
                val matrix = FloatArray(16)
                imagePose.toMatrix(matrix, 0)
                transformManager.setTransform(instance, matrix)
            }
        }
        
        fun setVisible(visible: Boolean) {
            if (!isInitialized) return
            
            if (visible && !isVisible) {
                scene.addEntity(entity)
            } else if (!visible && isVisible) {
                scene.removeEntity(entity)
            }
            isVisible = visible
        }
        
        fun destroy() {
            if (!isInitialized) return
            
            try {
                scene.removeEntity(entity)
                engine.destroyEntity(entity)
                EntityManager.get().destroy(entity)
                
                vertexBuffer?.let { engine.destroyVertexBuffer(it) }
                indexBuffer?.let { engine.destroyIndexBuffer(it) }
                imageTexture?.let { engine.destroyTexture(it) }
                depthTexture?.let { engine.destroyTexture(it) }
                materialInstance?.let { engine.destroyMaterialInstance(it) }
                
                vertexBuffer = null
                indexBuffer = null
                imageTexture = null
                depthTexture = null
                materialInstance = null
                depthValues = null
                currentImageData = null
                
                isInitialized = false
                isVisible = false
                
                Log.d(RENDERER_TAG, "🗑️ ParallaxRenderer destroyed")
            } catch (e: Exception) {
                Log.e(RENDERER_TAG, "Error destroying ParallaxRenderer", e)
            }
        }
        
        fun isActive(): Boolean = isInitialized && isVisible
    }
    
    // ========== Public API ==========
    
    fun setSceneView(sceneView: ARSceneView) {
        this.sceneView = sceneView
        Log.d(TAG, "📱 SceneView set")
    }
    
    /**
     * Load images from Flutter assets into ARCore database
     */
    fun handleLoadImages(call: MethodCall, result: MethodChannel.Result) {
        val imageConfigs = call.argument<List<Map<String, Any>>>("images")
        
        if (imageConfigs.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "No images provided", null)
            return
        }
        
        mainScope.launch {
            try {
                val session = sceneView?.session
                if (session == null) {
                    result.error("NO_SESSION", "AR session not available", null)
                    return@launch
                }
                
                // Create image database
                imageDatabase = AugmentedImageDatabase(session)
                
                var loadedCount = 0
                
                for (config in imageConfigs) {
                    val name = config["name"] as? String ?: continue
                    val imagePath = config["imagePath"] as? String ?: continue
                    val depthPath = config["depthPath"] as? String ?: continue
                    val physicalWidth = (config["physicalWidth"] as? Double)?.toFloat() ?: 0.3f
                    
                    // Load images from Flutter assets
                    val imageBitmap = loadBitmapFromAssets(imagePath)
                    val depthBitmap = loadBitmapFromAssets(depthPath)
                    
                    if (imageBitmap != null && depthBitmap != null) {
                        // Add to ARCore database
                        imageDatabase?.addImage(name, imageBitmap, physicalWidth)
                        
                        // Cache the data
                        loadedImages[name] = ImageData(
                            name = name,
                            image = imageBitmap,
                            depthMap = depthBitmap,
                            physicalWidth = physicalWidth
                        )
                        
                        loadedCount++
                        Log.d(TAG, "✅ Loaded image: $name (${imageBitmap.width}x${imageBitmap.height})")
                    } else {
                        Log.e(TAG, "❌ Failed to load image: $name")
                    }
                }
                
                // Configure session with image database
                if (loadedCount > 0 && imageDatabase != null) {
                    session.configure(session.config.apply {
                        augmentedImageDatabase = imageDatabase!!
                    })
                    Log.d(TAG, "✅ Configured ARCore with $loadedCount images")
                }
                
                result.success(mapOf(
                    "success" to true,
                    "loadedCount" to loadedCount
                ))
                
            } catch (e: Exception) {
                Log.e(TAG, "Error loading images", e)
                result.error("LOAD_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Enable 3D effect on a detected image
     */
    fun handleEnable3DEffect(call: MethodCall, result: MethodChannel.Result) {
        val imageName = call.argument<String>("imageName")
        
        if (imageName.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "Image name required", null)
            return
        }
        
        mainScope.launch {
            try {
                val trackedInfo = trackedImages[imageName]
                if (trackedInfo == null || trackedInfo.trackingState != TrackingState.TRACKING) {
                    result.error("NOT_TRACKED", "Image '$imageName' is not currently tracked", null)
                    return@launch
                }
                
                val imageData = loadedImages[imageName]
                if (imageData == null) {
                    result.error("NOT_LOADED", "Image data for '$imageName' not found", null)
                    return@launch
                }
                
                val sv = sceneView
                if (sv == null) {
                    result.error("NO_SCENEVIEW", "SceneView not available", null)
                    return@launch
                }
                
                // Create parallax renderer
                parallaxRenderer?.destroy()
                parallaxRenderer = ParallaxRenderer(
                    engine = sv.engine,
                    scene = sv.scene,
                    materialLoader = sv.materialLoader
                )
                
                parallaxRenderer?.initialize(
                    imageData = imageData,
                    pose = trackedInfo.pose,
                    extentX = trackedInfo.extentX,
                    extentZ = trackedInfo.extentZ
                )
                
                activeImageName = imageName
                isEnabled = true
                
                Log.d(TAG, "✅ 3D effect enabled for: $imageName")
                result.success(mapOf("success" to true))
                
            } catch (e: Exception) {
                Log.e(TAG, "Error enabling 3D effect", e)
                result.error("ENABLE_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Disable 3D effect
     */
    fun handleDisable3DEffect(result: MethodChannel.Result) {
        try {
            parallaxRenderer?.destroy()
            parallaxRenderer = null
            activeImageName = null
            isEnabled = false
            
            Log.d(TAG, "✅ 3D effect disabled")
            result.success(mapOf("success" to true))
            
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling 3D effect", e)
            result.error("DISABLE_ERROR", e.message, null)
        }
    }
    
    /**
     * Get list of currently detected images
     */
    fun handleGetDetectedImages(result: MethodChannel.Result) {
        val detected = trackedImages.filter { 
            it.value.trackingState == TrackingState.TRACKING 
        }.map { entry ->
            mapOf(
                "name" to entry.key,
                "extentX" to entry.value.extentX.toDouble(),
                "extentZ" to entry.value.extentZ.toDouble(),
                "isActive" to (entry.key == activeImageName)
            )
        }
        
        result.success(mapOf(
            "images" to detected,
            "count" to detected.size
        ))
    }
    
    /**
     * Process frame - called from ArView's onFrame
     */
    fun onFrame(frame: Frame, cameraPose: Pose) {
        if (imageDatabase == null) return
        
        try {
            // Update tracked images
            val updatedImages = frame.getUpdatedTrackables(AugmentedImage::class.java)
            
            for (augmentedImage in updatedImages) {
                val name = augmentedImage.name
                val trackingState = augmentedImage.trackingState
                
                when (trackingState) {
                    TrackingState.TRACKING -> {
                        val pose = augmentedImage.centerPose
                        val extentX = augmentedImage.extentX
                        val extentZ = augmentedImage.extentZ
                        
                        val existingInfo = trackedImages[name]
                        if (existingInfo == null) {
                            // New image detected
                            trackedImages[name] = TrackedImageInfo(
                                name = name,
                                pose = pose,
                                extentX = extentX,
                                extentZ = extentZ,
                                trackingState = trackingState,
                                lastUpdateTime = System.currentTimeMillis()
                            )
                            notifyImageDetected(name, true)
                            Log.d(TAG, "🎯 Image detected: $name")
                        } else {
                            // Update existing
                            existingInfo.pose = pose
                            existingInfo.extentX = extentX
                            existingInfo.extentZ = extentZ
                            existingInfo.trackingState = trackingState
                            existingInfo.lastUpdateTime = System.currentTimeMillis()
                        }
                        
                        // Update parallax effect if this is the active image
                        if (isEnabled && name == activeImageName && parallaxRenderer?.isActive() == true) {
                            parallaxRenderer?.updateParallax(cameraPose, pose)
                        }
                    }
                    
                    TrackingState.PAUSED, TrackingState.STOPPED -> {
                        val existingInfo = trackedImages[name]
                        if (existingInfo != null && existingInfo.trackingState == TrackingState.TRACKING) {
                            existingInfo.trackingState = trackingState
                            notifyImageDetected(name, false)
                            Log.d(TAG, "📤 Image lost: $name")
                            
                            // Hide effect if this was the active image
                            if (name == activeImageName) {
                                parallaxRenderer?.setVisible(false)
                            }
                        }
                    }
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error processing frame", e)
        }
    }
    
    /**
     * Cleanup resources
     */
    fun cleanup() {
        parallaxRenderer?.destroy()
        parallaxRenderer = null
        
        loadedImages.values.forEach { data ->
            data.image.recycle()
            data.depthMap.recycle()
        }
        loadedImages.clear()
        trackedImages.clear()
        
        imageDatabase = null
        activeImageName = null
        isEnabled = false
        sceneView = null
        
        Log.d(TAG, "🧹 AugmentedImage3DManager cleaned up")
    }
    
    // ========== Private Methods ==========
    
    private suspend fun loadBitmapFromAssets(assetPath: String): Bitmap? = withContext(Dispatchers.IO) {
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            val key = loader.getLookupKeyForAsset(assetPath)
            context.assets.open(key).use { inputStream ->
                BitmapFactory.decodeStream(inputStream)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load bitmap: $assetPath", e)
            null
        }
    }
    
    private fun notifyImageDetected(imageName: String, detected: Boolean) {
        mainScope.launch {
            sessionChannel.invokeMethod("onAugmentedImageDetected", mapOf(
                "name" to imageName,
                "detected" to detected
            ))
        }
    }
}