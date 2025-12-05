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
import com.google.android.filament.TextureSampler
import com.google.android.filament.VertexBuffer
import com.google.android.filament.android.TextureHelper
import com.google.ar.core.AugmentedFace
import com.google.ar.core.CameraConfig
import com.google.ar.core.CameraConfigFilter
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Pose
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.SessionPausedException
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.loaders.MaterialLoader
import io.github.sceneview.math.colorOf
import io.github.sceneview.model.ModelInstance
import io.github.sceneview.node.ModelNode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer
import io.github.sceneview.math.Position as ScenePosition
import io.github.sceneview.math.Rotation as SceneRotation
import androidx.lifecycle.Lifecycle

/**
 * FaceArManager - Gestionnaire complet du mode Face AR
 * 
 * Cette classe gère :
 * - La création et configuration de ARSceneView pour Face AR
 * - Le rendu du mesh facial (FaceMeshRenderer)
 * - Le tracking des visages
 * - Les modèles 3D attachés aux visages (filtres)
 * - Les textures de maquillage (makeup)
 * - Les notifications vers Flutter
 */
class FaceArManager(
    private val context: Context,
    private val lifecycle: Lifecycle,
    private val sessionChannel: MethodChannel,
    private val mainScope: CoroutineScope
) {
    companion object {
        private const val TAG = "FaceArManager"
    }

    // ========== État Face AR ==========
    var currentArMode: String = "world"
        private set
    
    private var faceModelPath: String? = null
    val faceNodesMap = mutableMapOf<Int, ModelNode>()
    private var isFaceDetected = false
    private var lastFacePose: Map<String, Any>? = null
    private var faceMeshRenderer: FaceMeshRenderer? = null
    private var currentFaceFilterColor: Int = 0x00000000  // Transparent par défaut
    private var faceFilterModelInstance: ModelInstance? = null
    private var faceFilterNode: ModelNode? = null
    private var isSessionPaused = false
    private var lastFaceLogTime = 0L
    
    // ========== Makeup Texture ==========
    private var currentMakeupTexturePath: String? = null
    
    // Référence à la sceneView courante
    private var sceneView: ARSceneView? = null

    // ========== FaceMeshRenderer - Inner Class ==========
    /**
     * FaceMeshRenderer - Renders the ARCore face mesh using Filament
     * Supports both solid colors and PNG textures for makeup
     */
    inner class FaceMeshRenderer(
        private val engine: Engine,
        private val scene: com.google.android.filament.Scene,
        private val materialLoader: MaterialLoader
    ) {
        private val MESH_TAG = "FaceMeshRenderer"
        private val VERTEX_COUNT = 468
        private val POSITION_SIZE = 3
        private val UV_SIZE = 2
        private val TANGENT_SIZE = 4

        private var entity: Int = 0
        private var vertexBuffer: VertexBuffer? = null
        private var indexBuffer: IndexBuffer? = null
        private var materialInstance: MaterialInstance? = null
        private var indexCount: Int = 0
        private var cachedUVs: FloatBuffer? = null
        private var cachedIndices: ShortBuffer? = null
        
        // Texture support
        private var currentTexture: Texture? = null
        private var isUsingTexture: Boolean = false
        
        private val positionBuffer: FloatBuffer = ByteBuffer
            .allocateDirect(VERTEX_COUNT * POSITION_SIZE * Float.SIZE_BYTES)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
        
        private val tangentBuffer: FloatBuffer = ByteBuffer
            .allocateDirect(VERTEX_COUNT * TANGENT_SIZE * Float.SIZE_BYTES)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
        
        private var isInitialized = false
        private var isVisible = false  // Hidden by default

        fun initialize(face: AugmentedFace, color: Int) {
            if (isInitialized) return
            
            try {
                Log.d(MESH_TAG, "🎭 Initializing FaceMeshRenderer...")
                Log.d(MESH_TAG, "   Color: ${String.format("#%08X", color)}")
                Log.d(MESH_TAG, "   Vertices: ${face.meshVertices.capacity() / 3}")
                Log.d(MESH_TAG, "   Indices: ${face.meshTriangleIndices.capacity()}")
                
                cacheStaticData(face)
                createVertexBuffer()
                createIndexBuffer()
                createMaterial(color)
                createRenderable()
                
                isInitialized = true
                isVisible = true
                Log.d(MESH_TAG, "✅ FaceMeshRenderer initialized successfully!")
                
            } catch (e: Exception) {
                Log.e(MESH_TAG, "❌ Failed to initialize FaceMeshRenderer", e)
                e.printStackTrace()
                destroy()
            }
        }
        
        /**
         * Initialize with a texture instead of color
         */
        fun initializeWithTexture(face: AugmentedFace, texturePath: String) {
            if (isInitialized) return
            
            try {
                Log.d(MESH_TAG, "🎭 Initializing FaceMeshRenderer with texture...")
                Log.d(MESH_TAG, "   Texture: $texturePath")
                Log.d(MESH_TAG, "   Vertices: ${face.meshVertices.capacity() / 3}")
                Log.d(MESH_TAG, "   Indices: ${face.meshTriangleIndices.capacity()}")
                
                cacheStaticData(face)
                createVertexBuffer()
                createIndexBuffer()
                
                // Load texture and create material
                val bitmap = loadBitmapFromAssets(texturePath)
                if (bitmap != null) {
                    createMaterialWithTexture(bitmap)
                    bitmap.recycle()
                    isUsingTexture = true
                } else {
                    Log.w(MESH_TAG, "⚠️ Failed to load texture, falling back to color")
                    createMaterial(currentFaceFilterColor)
                }
                
                createRenderable()
                
                isInitialized = true
                isVisible = true
                Log.d(MESH_TAG, "✅ FaceMeshRenderer initialized with texture successfully!")
                
            } catch (e: Exception) {
                Log.e(MESH_TAG, "❌ Failed to initialize FaceMeshRenderer with texture", e)
                e.printStackTrace()
                destroy()
            }
        }

        private fun cacheStaticData(face: AugmentedFace) {
            val uvs = face.meshTextureCoordinates
            cachedUVs = ByteBuffer
                .allocateDirect(uvs.capacity() * Float.SIZE_BYTES)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
            uvs.rewind()
            cachedUVs?.put(uvs)
            cachedUVs?.rewind()
            
            val indices = face.meshTriangleIndices
            indexCount = indices.capacity()
            cachedIndices = ByteBuffer
                .allocateDirect(indices.capacity() * Short.SIZE_BYTES)
                .order(ByteOrder.nativeOrder())
                .asShortBuffer()
            indices.rewind()
            cachedIndices?.put(indices)
            cachedIndices?.rewind()
            
            Log.d(MESH_TAG, "📊 Cached ${cachedUVs?.capacity()?.div(2)} UVs, $indexCount indices")
        }

        private fun createVertexBuffer() {
            vertexBuffer = VertexBuffer.Builder()
                .bufferCount(3)
                .vertexCount(VERTEX_COUNT)
                .attribute(VertexBuffer.VertexAttribute.POSITION, 0, VertexBuffer.AttributeType.FLOAT3, 0, POSITION_SIZE * Float.SIZE_BYTES)
                .attribute(VertexBuffer.VertexAttribute.UV0, 1, VertexBuffer.AttributeType.FLOAT2, 0, UV_SIZE * Float.SIZE_BYTES)
                .attribute(VertexBuffer.VertexAttribute.TANGENTS, 2, VertexBuffer.AttributeType.FLOAT4, 0, TANGENT_SIZE * Float.SIZE_BYTES)
                .build(engine)
            
            cachedUVs?.let { uvs ->
                uvs.rewind()
                vertexBuffer?.setBufferAt(engine, 1, uvs)
            }
            
            initializeTangentBuffer()
            vertexBuffer?.setBufferAt(engine, 2, tangentBuffer)
            
            Log.d(MESH_TAG, "📐 VertexBuffer created with $VERTEX_COUNT vertices")
        }
        
        private fun initializeTangentBuffer() {
            tangentBuffer.clear()
            for (i in 0 until VERTEX_COUNT) {
                tangentBuffer.put(0f)
                tangentBuffer.put(0f)
                tangentBuffer.put(0f)
                tangentBuffer.put(1f)
            }
            tangentBuffer.rewind()
        }

        private fun createIndexBuffer() {
            indexBuffer = IndexBuffer.Builder()
                .indexCount(indexCount)
                .bufferType(IndexBuffer.Builder.IndexType.USHORT)
                .build(engine)
            
            cachedIndices?.let { indices ->
                indices.rewind()
                indexBuffer?.setBuffer(engine, indices)
            }
            
            Log.d(MESH_TAG, "📐 IndexBuffer created with $indexCount indices")
        }

        private fun createMaterial(color: Int) {
            val a = ((color shr 24) and 0xFF) / 255f
            val r = ((color shr 16) and 0xFF) / 255f
            val g = ((color shr 8) and 0xFF) / 255f
            val b = (color and 0xFF) / 255f
            
            materialInstance = materialLoader.createColorInstance(
                color = colorOf(r, g, b, a),
                metallic = 0f,
                roughness = 1f,
                reflectance = 0f
            )
            
            isUsingTexture = false
            Log.d(MESH_TAG, "🎨 Material created with color ARGB($a, $r, $g, $b)")
        }
        
        /**
         * Create a material with a texture for makeup
         * Uses MaterialLoader.createTextureInstance which has proper texture support
         */
        private fun createMaterialWithTexture(bitmap: Bitmap) {
            try {
                // Destroy previous texture if exists
                currentTexture?.let {
                    try { engine.destroyTexture(it) } catch (e: Exception) {}
                }
                
                // Create Filament texture from bitmap
                currentTexture = Texture.Builder()
                    .width(bitmap.width)
                    .height(bitmap.height)
                    .sampler(Texture.Sampler.SAMPLER_2D)
                    .format(Texture.InternalFormat.SRGB8_A8)
                    .levels(0xff)  // Let Filament figure out mip levels
                    .build(engine)
                
                // Upload bitmap to texture
                TextureHelper.setBitmap(engine, currentTexture!!, 0, bitmap)
                currentTexture!!.generateMipmaps(engine)
                
                // Create material with texture using MaterialLoader.createTextureInstance
                // isOpaque = false for transparent makeup textures
                materialInstance = materialLoader.createTextureInstance(
                    texture = currentTexture!!,
                    isOpaque = false
                )
                
                isUsingTexture = true
                Log.d(MESH_TAG, "🎨 Material created with texture (${bitmap.width}x${bitmap.height})")
                
            } catch (e: Exception) {
                Log.e(MESH_TAG, "❌ Failed to create material with texture", e)
                e.printStackTrace()
                // Fallback to color
                createMaterial(currentFaceFilterColor)
            }
        }
        
        /**
         * Load bitmap from Flutter assets
         */
        private fun loadBitmapFromAssets(assetPath: String): Bitmap? {
            return try {
                val loader = FlutterInjector.instance().flutterLoader()
                val key = loader.getLookupKeyForAsset(assetPath)
                
                Log.d(MESH_TAG, "📁 Loading texture from: $key")
                
                val assetManager = context.assets
                val inputStream = assetManager.open(key)
                val bitmap = BitmapFactory.decodeStream(inputStream)
                inputStream.close()
                
                Log.d(MESH_TAG, "✅ Texture loaded: ${bitmap?.width}x${bitmap?.height}")
                bitmap
                
            } catch (e: Exception) {
                Log.e(MESH_TAG, "❌ Failed to load texture from assets: $assetPath", e)
                null
            }
        }

        private fun createRenderable() {
            entity = EntityManager.get().create()
            
            RenderableManager.Builder(1)
                .boundingBox(Box(0f, 0f, 0f, 0.3f, 0.3f, 0.3f))
                .geometry(0, RenderableManager.PrimitiveType.TRIANGLES, vertexBuffer!!, indexBuffer!!, 0, indexCount)
                .material(0, materialInstance!!)
                .culling(false)
                .castShadows(false)
                .receiveShadows(false)
                .build(engine, entity)
            
            scene.addEntity(entity)
            isVisible = true
            
            Log.d(MESH_TAG, "🎭 Renderable entity created and added to scene")
        }

        fun update(face: AugmentedFace) {
            if (!isInitialized) {
                // Initialize with texture if available, otherwise with color
                if (currentMakeupTexturePath != null) {
                    initializeWithTexture(face, currentMakeupTexturePath!!)
                } else {
                    initialize(face, currentFaceFilterColor)
                }
                return
            }
            
            if (!isVisible) return
            
            try {
                updateVertexPositions(face)
                updateTransform(face)
            } catch (e: Exception) {
                Log.e(MESH_TAG, "❌ Error updating face mesh", e)
            }
        }

        private fun updateVertexPositions(face: AugmentedFace) {
            val vertices = face.meshVertices
            val normals = face.meshNormals
            vertices.rewind()
            normals.rewind()
            
            positionBuffer.clear()
            positionBuffer.put(vertices)
            positionBuffer.rewind()
            
            tangentBuffer.clear()
            for (i in 0 until VERTEX_COUNT) {
                val nx = normals.get()
                val ny = normals.get()
                val nz = normals.get()
                
                val quat = normalToTangentQuaternion(nx, ny, nz)
                tangentBuffer.put(quat[0])
                tangentBuffer.put(quat[1])
                tangentBuffer.put(quat[2])
                tangentBuffer.put(quat[3])
            }
            tangentBuffer.rewind()
            
            vertexBuffer?.setBufferAt(engine, 0, positionBuffer)
            vertexBuffer?.setBufferAt(engine, 2, tangentBuffer)
        }
        
        private fun normalToTangentQuaternion(nx: Float, ny: Float, nz: Float): FloatArray {
            val dot = nz
            
            if (dot > 0.99999f) {
                return floatArrayOf(0f, 0f, 0f, 1f)
            }
            if (dot < -0.99999f) {
                return floatArrayOf(1f, 0f, 0f, 0f)
            }
            
            val ax = -ny
            val ay = nx
            val az = 0f
            
            val s = kotlin.math.sqrt((1f - dot) * 0.5f)
            val c = kotlin.math.sqrt((1f + dot) * 0.5f)
            
            val axisLen = kotlin.math.sqrt(ax * ax + ay * ay + az * az)
            if (axisLen < 0.0001f) {
                return floatArrayOf(0f, 0f, 0f, 1f)
            }
            
            val qx = (ax / axisLen) * s
            val qy = (ay / axisLen) * s
            val qz = (az / axisLen) * s
            val qw = c
            
            return floatArrayOf(qx, qy, qz, qw)
        }

        private fun updateTransform(face: AugmentedFace) {
            val transformManager = engine.transformManager
            val instance = transformManager.getInstance(entity)
            
            if (instance == 0) {
                transformManager.create(entity)
            }
            
            val matrix = FloatArray(16)
            face.centerPose.toMatrix(matrix, 0)
            
            transformManager.setTransform(transformManager.getInstance(entity), matrix)
        }

        fun setVisible(visible: Boolean) {
            if (isVisible == visible) return
            isVisible = visible
            
            if (entity != 0) {
                if (visible) {
                    scene.addEntity(entity)
                } else {
                    scene.removeEntity(entity)
                }
            }
            Log.d(MESH_TAG, "👁️ Visibility set to: $visible")
        }

        fun setColor(color: Int) {
            val a = ((color shr 24) and 0xFF) / 255f
            val r = ((color shr 16) and 0xFF) / 255f
            val g = ((color shr 8) and 0xFF) / 255f
            val b = (color and 0xFF) / 255f
            
            materialInstance = materialLoader.createColorInstance(
                color = colorOf(r, g, b, a),
                metallic = 0f,
                roughness = 1f,
                reflectance = 0f
            )
            
            if (entity != 0) {
                val renderableManager = engine.renderableManager
                val instance = renderableManager.getInstance(entity)
                if (instance != 0) {
                    renderableManager.setMaterialInstanceAt(instance, 0, materialInstance!!)
                }
            }
            
            isUsingTexture = false
            Log.d(MESH_TAG, "🎨 Color updated to ARGB($a, $r, $g, $b)")
        }
        
        /**
         * Set a texture for makeup
         */
        fun setTexture(texturePath: String) {
            try {
                val bitmap = loadBitmapFromAssets(texturePath)
                if (bitmap != null) {
                    createMaterialWithTexture(bitmap)
                    bitmap.recycle()
                    
                    // Update the renderable with new material
                    if (entity != 0 && materialInstance != null) {
                        val renderableManager = engine.renderableManager
                        val instance = renderableManager.getInstance(entity)
                        if (instance != 0) {
                            renderableManager.setMaterialInstanceAt(instance, 0, materialInstance!!)
                        }
                    }
                    
                    Log.d(MESH_TAG, "🎨 Texture updated to: $texturePath")
                } else {
                    Log.e(MESH_TAG, "❌ Failed to load texture: $texturePath")
                }
            } catch (e: Exception) {
                Log.e(MESH_TAG, "❌ Error setting texture", e)
            }
        }
        
        /**
         * Clear texture and revert to color
         */
        fun clearTexture() {
            currentTexture?.let {
                try { engine.destroyTexture(it) } catch (e: Exception) {}
            }
            currentTexture = null
            isUsingTexture = false
            
            // Revert to color
            setColor(currentFaceFilterColor)
            Log.d(MESH_TAG, "🧹 Texture cleared, reverted to color")
        }

        fun destroy() {
            if (!isInitialized) return
            
            try {
                if (entity != 0) {
                    try { scene.removeEntity(entity) } catch (e: Exception) {}
                    try { engine.destroyEntity(entity) } catch (e: Exception) {}
                    try { EntityManager.get().destroy(entity) } catch (e: Exception) {}
                    entity = 0
                }
                
                vertexBuffer?.let {
                    try { engine.destroyVertexBuffer(it) } catch (e: Exception) {}
                    vertexBuffer = null
                }
                
                indexBuffer?.let {
                    try { engine.destroyIndexBuffer(it) } catch (e: Exception) {}
                    indexBuffer = null
                }
                
                currentTexture?.let {
                    try { engine.destroyTexture(it) } catch (e: Exception) {}
                    currentTexture = null
                }
                
                materialInstance = null
                cachedUVs = null
                cachedIndices = null
                isInitialized = false
                isUsingTexture = false
                
                Log.d(MESH_TAG, "🧹 FaceMeshRenderer destroyed")
                
            } catch (e: Exception) {
                Log.e(MESH_TAG, "❌ Error destroying FaceMeshRenderer", e)
            }
        }
    }

    // ========== Configuration ==========

    fun setSceneView(view: ARSceneView) {
        this.sceneView = view
    }

    fun getSceneView(): ARSceneView? = sceneView

    fun setSessionPaused(paused: Boolean) {
        isSessionPaused = paused
    }

    // ========== Création de SceneView ==========

    fun createFaceARSceneView(): ARSceneView {
        return ARSceneView(
            context = context,
            sharedLifecycle = lifecycle,
            sessionFeatures = setOf(Session.Feature.FRONT_CAMERA),
            sessionCameraConfig = { session ->
                val filter = CameraConfigFilter(session)
                    .setFacingDirection(CameraConfig.FacingDirection.FRONT)
                val configs = session.getSupportedCameraConfigs(filter)
                configs.firstOrNull() ?: session.cameraConfig
            },
            sessionConfiguration = { session, config ->
                config.apply {
                    depthMode = Config.DepthMode.DISABLED
                    instantPlacementMode = Config.InstantPlacementMode.DISABLED
                    lightEstimationMode = Config.LightEstimationMode.DISABLED
                    focusMode = Config.FocusMode.AUTO
                    planeFindingMode = Config.PlaneFindingMode.DISABLED
                    augmentedFaceMode = Config.AugmentedFaceMode.MESH3D
                }
            }
        )
    }

    fun setupFaceTracking(arSceneView: ARSceneView) {
        Log.d(TAG, "🔧 Setting up Face Tracking...")
        
        this.sceneView = arSceneView
        
        arSceneView.apply {
            planeRenderer.isEnabled = false
            planeRenderer.isVisible = false

            onSessionCreated = { session ->
                Log.d(TAG, "📸 Face AR Session created")
                
                try {
                    val config = session.config
                    Log.d(TAG, "Current AugmentedFaceMode: ${config.augmentedFaceMode}")
                    
                    if (config.augmentedFaceMode == Config.AugmentedFaceMode.DISABLED) {
                        Log.w(TAG, "⚠️ AugmentedFace is DISABLED, trying to enable...")
                        session.configure(config.apply {
                            augmentedFaceMode = Config.AugmentedFaceMode.MESH3D
                        })
                        Log.d(TAG, "✅ AugmentedFaceMode set to MESH3D")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error configuring AugmentedFace", e)
                    mainScope.launch {
                        sessionChannel.invokeMethod("onError", mapOf(
                            "error" to "FACE_AR_NOT_SUPPORTED",
                            "message" to "AugmentedFace not supported: ${e.message}"
                        ))
                    }
                }
                
                Log.d(TAG, "🦊 Face filter model will be loaded via setFaceModel()")
            }

            environment = environmentLoader.createHDREnvironment(
                assetFileLocation = "environments/evening_meadow_2k.hdr"
            )!!.apply {
                indirectLight?.intensity = 6000f
            }
            Log.d(TAG, "💡 HDR environment configured for Face AR")

            onFrame = { frameTime ->
                try {
                    if (!isSessionPaused && currentArMode == "face") {
                        session?.update()?.let { frame ->
                            processFaceFrame(frame)
                        }
                    }
                } catch (e: Exception) {
                    when (e) {
                        is SessionPausedException -> {
                            Log.d(TAG, "Face AR: Session paused, skipping frame update")
                        }
                        else -> {
                            Log.e(TAG, "Face AR: Error during frame update", e)
                        }
                    }
                }
            }
        }
        
        Log.d(TAG, "✅ Face Tracking setup complete")
    }

    fun loadFaceFilterModel(modelPath: String) {
        val sv = sceneView ?: return
        Log.d(TAG, "🦊 Loading face filter model: $modelPath")
        
        mainScope.launch {
            try {
                faceFilterNode?.let { node ->
                    sv.removeChildNode(node)
                    node.destroy()
                }
                faceFilterNode = null
                faceFilterModelInstance = null
                
                val loader = FlutterInjector.instance().flutterLoader()
                val assetPath = loader.getLookupKeyForAsset(modelPath)
                
                Log.d(TAG, "🦊 Loading from asset path: $assetPath")
                
                faceFilterModelInstance = sv.modelLoader.loadModelInstance(assetPath)
                
                if (faceFilterModelInstance != null) {
                    Log.d(TAG, "✅ Face filter model loaded successfully!")
                } else {
                    Log.e(TAG, "❌ Failed to load face filter model - returned null")
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error loading face filter model: ${e.message}", e)
            }
        }
    }

    fun processFaceFrame(frame: Frame) {
        val sv = sceneView ?: return
        
        val allFaces = sv.session?.getAllTrackables(AugmentedFace::class.java) ?: return
        
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastFaceLogTime > 2000) {
            lastFaceLogTime = currentTime
            Log.d(TAG, "🔍 Face AR: All faces=${allFaces.size}, MeshRenderer=${faceMeshRenderer != null}, Model=${faceModelPath}, Texture=${currentMakeupTexturePath}")
        }
        
        var hasTrackingFace = false
        for (face in allFaces) {
            val faceId = face.hashCode()
            
            when (face.trackingState) {
                TrackingState.TRACKING -> {
                    hasTrackingFace = true
                    
                    if (!isFaceDetected) {
                        isFaceDetected = true
                        Log.d(TAG, "👤 Face detected! ID=$faceId")
                        notifyFaceDetected(true)
                    }
                    
                    // Create FaceMeshRenderer if needed
                    if (faceMeshRenderer == null) {
                        try {
                            val engine = sv.engine
                            val filamentScene = sv.scene
                            val matLoader = MaterialLoader(engine, context)
                            
                            faceMeshRenderer = FaceMeshRenderer(engine, filamentScene, matLoader)
                            Log.d(TAG, "🎭 FaceMeshRenderer created")
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ Failed to create FaceMeshRenderer", e)
                        }
                    }
                    
                    // Update mesh (will initialize with texture or color on first call)
                    faceMeshRenderer?.update(face)
                    
                    // Handle 3D face filter model
                    if (faceFilterNode == null && faceFilterModelInstance != null) {
                        try {
                            faceFilterNode = ModelNode(
                                modelInstance = faceFilterModelInstance!!
                            ).apply {
                                isShadowCaster = false
                                isShadowReceiver = false
                            }
                            
                            sv.addChildNode(faceFilterNode!!)
                            Log.d(TAG, "🦊 Face filter added to scene!")
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ Failed to create face filter node: ${e.message}", e)
                        }
                    }
                    
                    // Update 3D face filter position
                    faceFilterNode?.let { node ->
                        val centerPose = face.centerPose
                        
                        node.position = ScenePosition(
                            x = centerPose.tx(),
                            y = centerPose.ty(),
                            z = centerPose.tz()
                        )
                        
                        val quat = centerPose.rotationQuaternion
                        val rotation = quaternionToEuler(quat[0], quat[1], quat[2], quat[3])
                        node.rotation = rotation
                    }
                    
                    // Update face nodes
                    updateFaceNodes(face)
                    
                    // Update pose for Flutter
                    val centerPose = face.centerPose
                    val poseData = mapOf(
                        "position" to mapOf(
                            "x" to centerPose.tx().toDouble(),
                            "y" to centerPose.ty().toDouble(),
                            "z" to centerPose.tz().toDouble()
                        ),
                        "rotation" to mapOf(
                            "x" to centerPose.rotationQuaternion[0].toDouble(),
                            "y" to centerPose.rotationQuaternion[1].toDouble(),
                            "z" to centerPose.rotationQuaternion[2].toDouble(),
                            "w" to centerPose.rotationQuaternion[3].toDouble()
                        )
                    )
                    
                    if (lastFacePose != poseData) {
                        lastFacePose = poseData
                        notifyFacePoseUpdate(poseData)
                    }
                }
                
                TrackingState.PAUSED -> {
                    // Face temporarily lost
                }
                
                TrackingState.STOPPED -> {
                    removeFaceNode(faceId)
                }
            }
        }
        
        // No face tracked anymore
        if (!hasTrackingFace && isFaceDetected) {
            isFaceDetected = false
            Log.d(TAG, "👤 Face lost")
            notifyFaceDetected(false)
        }
    }

    private fun updateFaceNodes(face: AugmentedFace) {
        for ((_, node) in faceNodesMap) {
            val centerPose = face.centerPose
            node.position = ScenePosition(
                x = centerPose.tx(),
                y = centerPose.ty(),
                z = centerPose.tz()
            )
            
            val quat = centerPose.rotationQuaternion
            val rotation = quaternionToEuler(quat[0], quat[1], quat[2], quat[3])
            node.rotation = rotation
        }
    }

    private fun quaternionToEuler(x: Float, y: Float, z: Float, w: Float): SceneRotation {
        val sinr_cosp = 2 * (w * x + y * z)
        val cosr_cosp = 1 - 2 * (x * x + y * y)
        val roll = kotlin.math.atan2(sinr_cosp, cosr_cosp)
        
        val sinp = 2 * (w * y - z * x)
        val pitch = if (kotlin.math.abs(sinp) >= 1)
            Math.copySign(Math.PI.toFloat() / 2, sinp)
        else
            kotlin.math.asin(sinp)
        
        val siny_cosp = 2 * (w * z + x * y)
        val cosy_cosp = 1 - 2 * (y * y + z * z)
        val yaw = kotlin.math.atan2(siny_cosp, cosy_cosp)
        
        return SceneRotation(
            x = Math.toDegrees(roll.toDouble()).toFloat(),
            y = Math.toDegrees(pitch.toDouble()).toFloat(),
            z = Math.toDegrees(yaw.toDouble()).toFloat()
        )
    }

    private fun removeFaceNode(faceId: Int) {
        val sv = sceneView ?: return
        faceNodesMap[faceId]?.let { node ->
            sv.removeChildNode(node)
            node.destroy()
            faceNodesMap.remove(faceId)
        }
    }

    fun getRegionPose(face: AugmentedFace, region: String): Pose {
        return when (region) {
            "forehead" -> face.getRegionPose(AugmentedFace.RegionType.FOREHEAD_LEFT)
            "leftEye" -> face.getRegionPose(AugmentedFace.RegionType.FOREHEAD_LEFT)
            "rightEye" -> face.getRegionPose(AugmentedFace.RegionType.FOREHEAD_RIGHT)
            "nose" -> face.centerPose
            else -> face.centerPose
        }
    }

    // ========== Method Handlers ==========

    fun handleSwitchToFaceAR(
        result: MethodChannel.Result,
        onSwitch: (ARSceneView) -> Unit
    ) {
        if (currentArMode == "face") {
            result.success(mapOf("switched" to true, "mode" to "face"))
            return
        }

        try {
            Log.d(TAG, "🔄 Switching to Face AR mode...")
            
            cleanup()
            
            val newSceneView = createFaceARSceneView()
            setupFaceTracking(newSceneView)
            
            currentArMode = "face"
            
            onSwitch(newSceneView)
            
            notifyModeChanged("face")
            
            Log.d(TAG, "✅ Switched to Face AR mode successfully")
            result.success(mapOf("switched" to true, "mode" to "face"))
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error switching to Face AR mode", e)
            result.error("SWITCH_FACE_AR_ERROR", e.message, null)
        }
    }

    fun handleSwitchToWorldAR(
        result: MethodChannel.Result,
        onSwitch: () -> Unit
    ) {
        if (currentArMode == "world") {
            result.success(mapOf("switched" to true, "mode" to "world"))
            return
        }

        try {
            Log.d(TAG, "🔄 Switching to World AR mode...")
            
            cleanup()
            
            currentArMode = "world"
            isFaceDetected = false
            lastFacePose = null
            
            onSwitch()
            
            notifyModeChanged("world")
            
            Log.d(TAG, "✅ Switched to World AR mode successfully")
            result.success(mapOf("switched" to true, "mode" to "world"))
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error switching to World AR mode", e)
            result.error("SWITCH_WORLD_AR_ERROR", e.message, null)
        }
    }

    fun handleGetCurrentMode(result: MethodChannel.Result) {
        result.success(mapOf("mode" to currentArMode))
    }

    fun handleSetFaceModel(call: MethodCall, result: MethodChannel.Result) {
        try {
            val modelPath = call.argument<String>("modelPath")
            if (modelPath == null) {
                result.error("INVALID_ARGUMENT", "Model path is required", null)
                return
            }
            
            faceModelPath = modelPath
            Log.d(TAG, "🦊 Setting face model: $modelPath")
            
            loadFaceFilterModel(modelPath)
            
            result.success(mapOf("success" to true))
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error setting face model", e)
            result.error("SET_FACE_MODEL_ERROR", e.message, null)
        }
    }

    fun handleSetFaceFilterColor(call: MethodCall, result: MethodChannel.Result) {
        try {
            val colorValue = call.argument<Long>("color") ?: call.argument<Int>("color")?.toLong()
            if (colorValue == null) {
                result.error("INVALID_ARGUMENT", "Color value is required", null)
                return
            }
            
            currentFaceFilterColor = colorValue.toInt()
            faceMeshRenderer?.setColor(currentFaceFilterColor)
            faceMeshRenderer?.setVisible(true)  // Show mesh when color is set
            
            Log.d(TAG, "🎨 Face filter color set: ${String.format("#%08X", currentFaceFilterColor)}")
            result.success(mapOf("success" to true))
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error setting face filter color", e)
            result.error("SET_FACE_FILTER_COLOR_ERROR", e.message, null)
        }
    }

    fun handleSetFaceFilterVisible(call: MethodCall, result: MethodChannel.Result) {
        try {
            val visible = call.argument<Boolean>("visible") ?: true
            
            faceMeshRenderer?.setVisible(visible)
            faceFilterNode?.isVisible = visible
            
            Log.d(TAG, "👁️ Face filter visibility set: $visible")
            result.success(mapOf("success" to true))
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error setting face filter visibility", e)
            result.error("SET_FACE_FILTER_VISIBLE_ERROR", e.message, null)
        }
    }

    // ========== Cleanup ==========

    fun cleanup() {
        val sv = sceneView
        
        faceMeshRenderer?.destroy()
        faceMeshRenderer = null
        
        faceFilterNode?.let { node ->
            sv?.removeChildNode(node)
            node.destroy()
        }
        faceFilterNode = null
        faceFilterModelInstance = null
        
        faceNodesMap.values.forEach { node ->
            sv?.removeChildNode(node)
            node.destroy()
        }
        faceNodesMap.clear()
        
        isFaceDetected = false
        lastFacePose = null
        currentMakeupTexturePath = null
        
        Log.d(TAG, "🧹 FaceArManager cleaned up")
    }

    fun clearFaceModel() {
        val sv = sceneView
        
        faceFilterNode?.let { node ->
            sv?.removeChildNode(node)
            node.destroy()
        }
        faceFilterNode = null
        faceFilterModelInstance = null
        faceModelPath = null
        
        Log.d(TAG, "🧹 Face model cleared")
    }

    fun handleClearFaceModel(result: MethodChannel.Result) {
        try {
            clearFaceModel()
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error clearing face model", e)
            result.error("CLEAR_FACE_MODEL_ERROR", e.message, null)
        }
    }

    // ========== Makeup Texture Handlers ==========
    
    /**
     * Set a makeup texture (PNG) on the face mesh
     */
    fun handleSetFaceMakeupTexture(call: MethodCall, result: MethodChannel.Result) {
        try {
            val texturePath = call.argument<String>("texturePath")
            if (texturePath == null) {
                result.error("INVALID_ARGUMENT", "Texture path is required", null)
                return
            }
            
            Log.d(TAG, "💄 Setting makeup texture: $texturePath")
            
            currentMakeupTexturePath = texturePath
            
            // If mesh renderer exists, update texture immediately
            faceMeshRenderer?.setTexture(texturePath)
            faceMeshRenderer?.setVisible(true)
            
            result.success(mapOf("success" to true))
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error setting makeup texture", e)
            result.error("SET_MAKEUP_TEXTURE_ERROR", e.message, null)
        }
    }
    
    /**
     * Clear makeup texture and hide the mesh
     */
    fun handleClearFaceMakeupTexture(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "🧹 Clearing makeup texture")
            
            currentMakeupTexturePath = null
            faceMeshRenderer?.clearTexture()
            faceMeshRenderer?.setVisible(false)
            
            result.success(mapOf("success" to true))
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error clearing makeup texture", e)
            result.error("CLEAR_MAKEUP_TEXTURE_ERROR", e.message, null)
        }
    }

    // ========== Notifications ==========

    private fun notifyFaceDetected(detected: Boolean) {
        mainScope.launch {
            sessionChannel.invokeMethod("onFaceDetected", mapOf("detected" to detected))
        }
    }

    private fun notifyFacePoseUpdate(poseData: Map<String, Any>) {
        mainScope.launch {
            sessionChannel.invokeMethod("onFacePoseUpdate", poseData)
        }
    }

    private fun notifyModeChanged(mode: String) {
        mainScope.launch {
            sessionChannel.invokeMethod("onModeChanged", mapOf("mode" to mode))
        }
    }
}