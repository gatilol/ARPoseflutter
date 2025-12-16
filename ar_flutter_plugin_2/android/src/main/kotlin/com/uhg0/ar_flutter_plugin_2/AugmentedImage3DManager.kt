package com.uhg0.ar_flutter_plugin_2

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.google.ar.core.AugmentedImage
import com.google.ar.core.AugmentedImageDatabase
import com.google.ar.core.Frame
import com.google.ar.core.Pose
import com.google.ar.core.TrackingState
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.node.ModelNode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import io.github.sceneview.math.Position as ScenePosition
import io.github.sceneview.math.Rotation as SceneRotation
import io.github.sceneview.math.Scale as SceneScale

/**
 * AugmentedImage3DManager - Gestionnaire de modèles 3D sur images augmentées
 * 
 * Cette classe gère :
 * - La détection d'images connues via ARCore Augmented Images
 * - L'affichage d'un modèle 3D qui "sort" de l'image détectée
 * - Le suivi de position du modèle sur l'image
 * 
 * Workflow:
 * 1. Charger les images de référence + chemin vers modèle 3D
 * 2. Détecter les images dans le monde réel
 * 3. Quand activé, afficher le modèle 3D au-dessus de l'image
 */
class AugmentedImage3DManager(
    private val context: Context,
    private val sessionChannel: MethodChannel,
    private val mainScope: CoroutineScope
) {
    companion object {
        private const val TAG = "AugmentedImage3DManager"
    }
    
    // ========== State ==========
    private var sceneView: ARSceneView? = null
    private var isEnabled = false
    private var imageDatabase: AugmentedImageDatabase? = null
    
    // Tracked images
    private val trackedImages = mutableMapOf<String, TrackedImageInfo>()
    private var activeImageName: String? = null
    
    // 3D Model
    private var modelNode: ModelNode? = null
    private var currentImageData: ImageData? = null
    private var initialRotationY: Float = 0f  // Rotation Y fixée au placement
    private var lastCameraPose: Pose? = null  // Dernière position caméra connue
    
    // Image data cache
    internal data class ImageData(
        val name: String,
        val modelPath: String,       // Chemin vers le modèle 3D
        val physicalWidth: Float,    // Taille physique en mètres
        val modelScale: Float = 1.0f, // Échelle du modèle
        val modelYOffset: Float = 0f,  // Décalage vertical (négatif = plus bas)
        val modelRotationOffset: Float = 0f  // Offset de rotation Y en degrés (pour ajuster manuellement)
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
    
    // ========== Public API ==========
    
    fun setSceneView(sceneView: ARSceneView) {
        this.sceneView = sceneView
        Log.d(TAG, "📱 SceneView set")
    }
    
    /**
     * Load images from Flutter assets into ARCore database
     * Each image config should contain:
     * - name: unique identifier
     * - imagePath: path to detection image
     * - modelPath: path to 3D model (.glb)
     * - physicalWidth: width in meters
     * - modelScale: (optional) scale factor for the model
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
                    val modelPath = config["modelPath"] as? String ?: continue
                    val physicalWidth = (config["physicalWidth"] as? Double)?.toFloat() ?: 0.3f
                    val modelScale = (config["modelScale"] as? Double)?.toFloat() ?: 1.0f
                    val modelYOffset = (config["modelYOffset"] as? Double)?.toFloat() ?: 0f
                    val modelRotationOffset = (config["modelRotationOffset"] as? Double)?.toFloat() ?: 0f
                    
                    // Load image from Flutter assets for ARCore detection
                    val imageBitmap = loadBitmapFromAssets(imagePath)
                    
                    if (imageBitmap != null) {
                        // Add to ARCore database
                        imageDatabase?.addImage(name, imageBitmap, physicalWidth)
                        
                        // Cache the data
                        loadedImages[name] = ImageData(
                            name = name,
                            modelPath = modelPath,
                            physicalWidth = physicalWidth,
                            modelScale = modelScale,
                            modelYOffset = modelYOffset,
                            modelRotationOffset = modelRotationOffset
                        )
                        
                        loadedCount++
                        Log.d(TAG, "✅ Loaded image: $name → model: $modelPath")
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
     * Enable 3D model on a detected image
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
                
                // Remove existing model if any
                modelNode?.let { 
                    sv.removeChildNode(it)
                    it.destroy()
                }
                
                // Load 3D model using Flutter asset path
                val loader = FlutterInjector.instance().flutterLoader()
                val modelKey = loader.getLookupKeyForAsset(imageData.modelPath)
                val modelInstance = sv.modelLoader.loadModelInstance(modelKey)
                
                if (modelInstance == null) {
                    result.error("MODEL_ERROR", "Failed to load model: ${imageData.modelPath}", null)
                    return@launch
                }
                
                // Create model node
                modelNode = ModelNode(
                    modelInstance = modelInstance
                ).apply {
                    // Position sur l'image avec offset Y
                    val pose = trackedInfo.pose
                    position = ScenePosition(
                        x = pose.tx(),
                        y = pose.ty() + imageData.modelYOffset,
                        z = pose.tz()
                    )
                    
                    // Calculer la rotation pour que le modèle regarde vers la caméra
                    val camPose = lastCameraPose
                    if (camPose != null) {
                        // Direction du modèle vers la caméra
                        val dx = camPose.tx() - pose.tx()
                        val dz = camPose.tz() - pose.tz()
                        
                        // Angle en degrés (atan2 donne l'angle vers la caméra)
                        val angleToCamera = Math.toDegrees(Math.atan2(dx.toDouble(), dz.toDouble())).toFloat()
                        
                        // Rotation finale = angle vers caméra + offset manuel
                        initialRotationY = angleToCamera + imageData.modelRotationOffset
                    } else {
                        // Fallback si pas de camera pose
                        initialRotationY = imageData.modelRotationOffset
                    }
                    
                    rotation = SceneRotation(x = 0f, y = initialRotationY, z = 0f)
                    
                    // Échelle du modèle
                    val s = imageData.modelScale
                    scale = SceneScale(s, s, s)
                }
                
                // Store current image data for updates
                currentImageData = imageData
                
                sv.addChildNode(modelNode!!)
                
                activeImageName = imageName
                isEnabled = true
                
                Log.d(TAG, "✅ 3D model enabled for: $imageName")
                result.success(mapOf("success" to true))
                
            } catch (e: Exception) {
                Log.e(TAG, "Error enabling 3D model", e)
                result.error("ENABLE_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Disable 3D model
     */
    fun handleDisable3DEffect(result: MethodChannel.Result) {
        try {
            modelNode?.let { node ->
                sceneView?.removeChildNode(node)
                node.destroy()
            }
            modelNode = null
            currentImageData = null
            initialRotationY = 0f
            activeImageName = null
            isEnabled = false
            
            Log.d(TAG, "✅ 3D model disabled")
            result.success(mapOf("success" to true))
            
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling 3D model", e)
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
        
        // Store camera pose for model orientation calculation
        lastCameraPose = cameraPose
        
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
                        
                        // Update model position if this is the active image
                        if (isEnabled && name == activeImageName) {
                            updateModelPosition(pose)
                        }
                    }
                    
                    TrackingState.PAUSED, TrackingState.STOPPED -> {
                        val existingInfo = trackedImages[name]
                        if (existingInfo != null && existingInfo.trackingState == TrackingState.TRACKING) {
                            existingInfo.trackingState = trackingState
                            notifyImageDetected(name, false)
                            Log.d(TAG, "📤 Image lost: $name")
                            
                            // Hide model if this was the active image
                            if (name == activeImageName) {
                                modelNode?.isVisible = false
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
     * Update 3D model position to follow the image
     */
    private fun updateModelPosition(pose: Pose) {
        modelNode?.let { node ->
            node.isVisible = true
            
            // Position avec Y offset
            val yOffset = currentImageData?.modelYOffset ?: 0f
            node.position = ScenePosition(
                x = pose.tx(),
                y = pose.ty() + yOffset,
                z = pose.tz()
            )
            
            // Pas de mise à jour de rotation pour éviter les tremblements/rotations
        }
    }
    
    /**
     * Cleanup resources
     */
    fun cleanup() {
        modelNode?.let { node ->
            sceneView?.removeChildNode(node)
            node.destroy()
        }
        modelNode = null
        currentImageData = null
        initialRotationY = 0f
        lastCameraPose = null
        
        loadedImages.clear()
        trackedImages.clear()
        
        imageDatabase = null
        activeImageName = null
        isEnabled = false
        sceneView = null
        
        Log.d(TAG, "🧹 AugmentedImage3DManager cleaned up")
    }
    
    /**
     * Reset state for camera switch (keeps loadedImages but clears tracking state)
     */
    fun resetForCameraSwitch() {
        modelNode?.let { node ->
            sceneView?.removeChildNode(node)
            node.destroy()
        }
        modelNode = null
        currentImageData = null
        initialRotationY = 0f
        lastCameraPose = null
        
        trackedImages.clear()
        imageDatabase = null
        activeImageName = null
        isEnabled = false
        
        Log.d(TAG, "🔄 AugmentedImage3DManager reset for camera switch")
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