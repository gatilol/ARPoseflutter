package com.uhg0.ar_flutter_plugin_2

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.PixelCopy
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.lifecycle.Lifecycle
import com.google.ar.core.AugmentedFace
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Plane
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.SessionPausedException
import com.uhg0.ar_flutter_plugin_2.Serialization.serializeHitResult
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.ar.arcore.fps
import io.github.sceneview.ar.node.AnchorNode
import io.github.sceneview.ar.node.HitResultNode
import io.github.sceneview.ar.scene.PlaneRenderer
import io.github.sceneview.gesture.MoveGestureDetector
import io.github.sceneview.gesture.RotateGestureDetector
import io.github.sceneview.loaders.MaterialLoader
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import io.github.sceneview.math.colorOf
import io.github.sceneview.model.ModelInstance
import io.github.sceneview.node.CylinderNode
import io.github.sceneview.node.ModelNode
import io.github.sceneview.node.Node
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import io.github.sceneview.math.Position as ScenePosition
import io.github.sceneview.math.Rotation as SceneRotation
import io.github.sceneview.math.Scale as SceneScale

class ArView(
    context: Context,
    private val activity: Activity,
    private val lifecycle: Lifecycle,
    messenger: BinaryMessenger,
    id: Int,
) : PlatformView {
    private val TAG: String = ArView::class.java.name
    private val viewContext: Context = context
    private var sceneView: ARSceneView
    private val mainScope = CoroutineScope(Dispatchers.Main)
    private var worldOriginNode: Node? = null

    private val rootLayout: ViewGroup = FrameLayout(context)

    private val sessionChannel: MethodChannel = MethodChannel(messenger, "arsession_$id")
    private val objectChannel: MethodChannel = MethodChannel(messenger, "arobjects_$id")
    private val anchorChannel: MethodChannel = MethodChannel(messenger, "aranchors_$id")
    
    // ========== Managers ==========
    private val faceArManager: FaceArManager
    private val anchorManager: AnchorManager
    
    // ========== État local ==========
    private val nodesMap = mutableMapOf<String, ModelNode>()
    private var planeCount = 0
    private var selectedNode: Node? = null
    private val detectedPlanes = mutableSetOf<Plane>()
    private var showAnimatedGuide = true
    private var showFeaturePoints = false
    private val pointCloudNodes = mutableListOf<PointCloudNode>()
    private var lastPointCloudTimestamp: Long? = null
    private var lastPointCloudFrame: Frame? = null
    private var pointCloudModelInstances = mutableListOf<ModelInstance>()
    private var handlePans = false  
    private var handleRotation = false
    private var isSessionPaused = false

    // ========== Stored Init Parameters ==========
    private var storedShowPlanes = true
    private var storedHandleTaps = true
    private var storedPlaneDetectionConfig = 1
    private var storedShowFeaturePoints = false
    private var isInitialized = false

    private class PointCloudNode(
        modelInstance: ModelInstance,
        var id: Int,
        var confidence: Float,
    ) : ModelNode(modelInstance)

    // ========== Method Handlers ==========

    private val onSessionMethodCall =
        MethodChannel.MethodCallHandler { call, result ->
            when (call.method) {
                "init" -> handleInit(call, result)
                "showPlanes" -> handleShowPlanes(call, result)
                "dispose" -> dispose()
                "getAnchorPose" -> anchorManager.handleGetAnchorPose(call, result)
                "getCameraPose" -> handleGetCameraPose(result)
                "snapshot" -> handleSnapshot(result)
                "disableCamera" -> handleDisableCamera(result)
                "enableCamera" -> handleEnableCamera(result)
                // ========== Face AR Methods (déléguées à FaceArManager) ==========
                "switchToFaceAR" -> faceArManager.handleSwitchToFaceAR(result) { newSceneView ->
                    switchSceneView(newSceneView)
                }
                "switchToWorldAR" -> faceArManager.handleSwitchToWorldAR(result) {
                    switchToWorldARSceneView()
                }
                "getCurrentMode" -> faceArManager.handleGetCurrentMode(result)
                "setFaceModel" -> faceArManager.handleSetFaceModel(call, result)
                "clearFaceModel" -> faceArManager.handleClearFaceModel(result)
                "setFaceFilterColor" -> faceArManager.handleSetFaceFilterColor(call, result)
                "setFaceFilterVisible" -> faceArManager.handleSetFaceFilterVisible(call, result)
                // ========== Makeup Texture Methods ==========
                "setFaceMakeupTexture" -> faceArManager.handleSetFaceMakeupTexture(call, result)
                "clearFaceMakeupTexture" -> faceArManager.handleClearFaceMakeupTexture(result)
                // =====================================
                else -> result.notImplemented()
            }
        }

    private val onObjectMethodCall =
        MethodChannel.MethodCallHandler { call, result ->
            when (call.method) {
                "addNode" -> {
                    val nodeData = call.arguments as? Map<String, Any>
                    nodeData?.let {
                        handleAddNode(it, result)
                    } ?: result.error("INVALID_ARGUMENTS", "Node data is required", null)
                }
                "addNodeToPlaneAnchor" -> handleAddNodeToPlaneAnchor(call, result)
                "addNodeToScreenPosition" -> handleAddNodeToScreenPosition(call, result)
                "removeNode" -> handleRemoveNode(call, result)
                "transformationChanged" -> handleTransformNode(call, result)
                // ========== Face AR Object Methods ==========
                "addNodeToFace" -> handleAddNodeToFace(call, result)
                // ============================================
                else -> result.notImplemented()
            }
        }

    private val onAnchorMethodCall =
        MethodChannel.MethodCallHandler { call, result ->
            when (call.method) {
                "addAnchor" -> anchorManager.handleAddAnchor(call, result)
                "removeAnchor" -> {
                    val anchorName = call.argument<String>("name")
                    anchorManager.handleRemoveAnchor(anchorName, result)
                }
                "initGoogleCloudAnchorMode" -> anchorManager.handleInitGoogleCloudAnchorMode(result)
                "uploadAnchor" -> anchorManager.handleUploadAnchor(call, result)
                "downloadAnchor" -> anchorManager.handleDownloadAnchor(call, result)
                else -> result.notImplemented()
            }
        }

    init {
        // Initialiser les managers
        faceArManager = FaceArManager(context, lifecycle, sessionChannel, mainScope)
        anchorManager = AnchorManager(sessionChannel, anchorChannel, mainScope)
        
        // Créer la vue World AR initiale
        sceneView = createWorldARSceneView()
        rootLayout.addView(sceneView)
        
        // Configurer les managers avec la sceneView
        faceArManager.setSceneView(sceneView)
        anchorManager.setSceneView(sceneView)

        // Configurer les handlers
        sessionChannel.setMethodCallHandler(onSessionMethodCall)
        objectChannel.setMethodCallHandler(onObjectMethodCall)
        anchorChannel.setMethodCallHandler(onAnchorMethodCall)
    }

    // ========== SceneView Management ==========

    /**
     * Crée une ARSceneView configurée pour World AR (caméra arrière)
     */
    private fun createWorldARSceneView(): ARSceneView {
        return ARSceneView(
            context = viewContext,
            sharedLifecycle = lifecycle,
            sessionConfiguration = { session, config ->
                config.apply {
                    depthMode = Config.DepthMode.DISABLED
                    instantPlacementMode = Config.InstantPlacementMode.DISABLED
                    lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
                    focusMode = Config.FocusMode.AUTO
                    planeFindingMode = Config.PlaneFindingMode.DISABLED
                    augmentedFaceMode = Config.AugmentedFaceMode.DISABLED
                }
            }
        )
    }

    /**
     * Switch vers une nouvelle SceneView (utilisé pour Face AR)
     */
    private fun switchSceneView(newSceneView: ARSceneView) {
        rootLayout.removeView(sceneView)
        sceneView.destroy()
        
        sceneView = newSceneView
        rootLayout.addView(sceneView)
        
        // Mettre à jour les références dans les managers
        faceArManager.setSceneView(sceneView)
        anchorManager.setSceneView(sceneView)
    }

    /**
     * Switch vers World AR SceneView
     */
    private fun switchToWorldARSceneView() {
        rootLayout.removeView(sceneView)
        sceneView.destroy()
        
        sceneView = createWorldARSceneView()
        rootLayout.addView(sceneView)
        
        // Mettre à jour les références dans les managers
        faceArManager.setSceneView(sceneView)
        anchorManager.setSceneView(sceneView)
        
        detectedPlanes.clear()
        
        // Reconfigurer si déjà initialisé
        if (isInitialized) {
            reconfigureWorldARSceneView()
        }
    }

    /**
     * Reconfigure la sceneView World AR avec les callbacks nécessaires
     */
    private fun reconfigureWorldARSceneView() {
        try {
            // Configurer la session ARCore
            sceneView.session?.let { session ->
                session.configure(session.config.apply {
                    depthMode = when (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                        true -> Config.DepthMode.AUTOMATIC
                        else -> Config.DepthMode.DISABLED
                    }
                    planeFindingMode = when (storedPlaneDetectionConfig) {
                        1 -> Config.PlaneFindingMode.HORIZONTAL
                        2 -> Config.PlaneFindingMode.VERTICAL
                        3 -> Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                        else -> Config.PlaneFindingMode.DISABLED
                    }
                    augmentedFaceMode = Config.AugmentedFaceMode.DISABLED
                })
            }

            sceneView.apply {
                // Environment HDR
                environment = environmentLoader.createHDREnvironment(
                    assetFileLocation = "environments/evening_meadow_2k.hdr"
                )!!

                // Plane renderer
                planeRenderer.isEnabled = storedShowPlanes
                planeRenderer.isVisible = storedShowPlanes
                planeRenderer.planeRendererMode = PlaneRenderer.PlaneRendererMode.RENDER_ALL

                // Frame callback
                onFrame = { frameTime ->
                    try {
                        if (!isSessionPaused && faceArManager.currentArMode == "world") {
                            session?.update()?.let { frame ->
                                // Masquer le guide animé quand un plan est détecté
                                if (showAnimatedGuide) {
                                    frame.getUpdatedTrackables(Plane::class.java).forEach { plane ->
                                        if (plane.trackingState == TrackingState.TRACKING) {
                                            rootLayout.findViewWithTag<View>("hand_motion_layout")?.let { handMotionLayout ->
                                                rootLayout.removeView(handMotionLayout)
                                                showAnimatedGuide = false
                                            }
                                        }
                                    }
                                }

                                // Détection des plans
                                frame.getUpdatedTrackables(Plane::class.java).forEach { plane ->
                                    if (plane.trackingState == TrackingState.TRACKING &&
                                        !detectedPlanes.contains(plane)
                                    ) {
                                        detectedPlanes.add(plane)
                                        mainScope.launch {
                                            sessionChannel.invokeMethod("onPlaneDetected", detectedPlanes.size)
                                        }
                                    }
                                }
                            }
                        }
                    } catch (e: Exception) {
                        when (e) {
                            is SessionPausedException -> {
                                Log.d(TAG, "Session paused, skipping frame update")
                            }
                            else -> {
                                Log.e(TAG, "Error during frame update", e)
                            }
                        }
                    }
                }

                // Gesture listener pour les taps
                setOnGestureListener(
                    onSingleTapConfirmed = { motionEvent: MotionEvent, node: Node? ->
                        if (node != null && storedHandleTaps) {
                            var anchorName: String? = null
                            var currentNode: Node? = node
                            while (currentNode != null) {
                                anchorManager.anchorNodesMap.forEach { (name, anchorNode) ->
                                    if (currentNode == anchorNode) {
                                        anchorName = name
                                        return@forEach
                                    }
                                }
                                if (anchorName != null) break
                                currentNode = currentNode.parent
                            }
                            objectChannel.invokeMethod("onNodeTap", listOf(anchorName))
                            true
                        } else {
                            // Tap sur une surface
                            session?.update()?.let { frame ->
                                val hitResults = frame.hitTest(motionEvent)

                                val planeHits = hitResults
                                    .filter { hit ->
                                        val trackable = hit.trackable
                                        trackable is Plane && trackable.trackingState == TrackingState.TRACKING
                                    }.map { hit ->
                                        mapOf(
                                            "type" to 1,
                                            "distance" to hit.distance.toDouble(),
                                            "position" to mapOf(
                                                "x" to hit.hitPose.tx().toDouble(),
                                                "y" to hit.hitPose.ty().toDouble(),
                                                "z" to hit.hitPose.tz().toDouble()
                                            )
                                        )
                                    }
                                notifyPlaneOrPointTap(planeHits)
                            }
                            true
                        }
                    },
                )
            }

            // Réafficher le guide animé
            showAnimatedGuide = true
            
            rootLayout.findViewWithTag<View>("hand_motion_layout")?.let {
                rootLayout.removeView(it)
            }
            
            val handMotionLayout = LayoutInflater
                .from(viewContext)
                .inflate(R.layout.sceneform_hand_layout, rootLayout, false)
                .apply {
                    tag = "hand_motion_layout"
                }
            rootLayout.addView(handMotionLayout)

            Log.d(TAG, "✅ World AR SceneView reconfigured successfully")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reconfiguring World AR SceneView", e)
        }
    }

    // ========== Init Handler ==========

    private fun handleInit(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            val argShowAnimatedGuide = call.argument<Boolean>("showAnimatedGuide") ?: true
            val argShowFeaturePoints = call.argument<Boolean>("showFeaturePoints") ?: false
            val argPlaneDetectionConfig: Int? = call.argument<Int>("planeDetectionConfig")
            val argShowPlanes = call.argument<Boolean>("showPlanes") ?: true
            val customPlaneTexturePath = call.argument<String>("customPlaneTexturePath")
            val showWorldOrigin = call.argument<Boolean>("showWorldOrigin") ?: false
            val handleTaps = call.argument<Boolean>("handleTaps") ?: true
            handlePans = call.argument<Boolean>("handlePans") ?: false
            handleRotation = call.argument<Boolean>("handleRotation") ?: false

            // Store parameters for later use
            storedShowPlanes = argShowPlanes
            storedHandleTaps = handleTaps
            storedPlaneDetectionConfig = argPlaneDetectionConfig ?: 1
            storedShowFeaturePoints = argShowFeaturePoints
            showAnimatedGuide = argShowAnimatedGuide
            isInitialized = true

            // Ne configurer la session World AR que si on est en mode World
            if (faceArManager.currentArMode == "world") {
                sceneView.session?.let { session ->
                    session.configure(session.config.apply {
                        depthMode = when (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                            true -> Config.DepthMode.AUTOMATIC
                            else -> Config.DepthMode.DISABLED
                        }
                        planeFindingMode = when (argPlaneDetectionConfig) {
                            1 -> Config.PlaneFindingMode.HORIZONTAL
                            2 -> Config.PlaneFindingMode.VERTICAL
                            3 -> Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                            else -> Config.PlaneFindingMode.DISABLED
                        }
                    })
                }

                handleShowWorldOrigin(showWorldOrigin)
            }
            
            sceneView.apply {
                environment = environmentLoader.createHDREnvironment(
                    assetFileLocation = "environments/evening_meadow_2k.hdr"
                )!!

                if (faceArManager.currentArMode == "world") {
                    planeRenderer.isEnabled = argShowPlanes
                    planeRenderer.isVisible = argShowPlanes
                    planeRenderer.planeRendererMode = PlaneRenderer.PlaneRendererMode.RENDER_ALL
                }

                onTrackingFailureChanged = { reason ->
                    mainScope.launch {
                        sessionChannel.invokeMethod("onTrackingFailure", reason?.name)
                    }
                }

                if (argShowFeaturePoints == true) {
                    showFeaturePoints = true
                } else {
                    showFeaturePoints = false
                    pointCloudNodes.toList().forEach { removePointCloudNode(it) }
                }

                onFrame = { frameTime ->
                    try {
                        if (!isSessionPaused) {
                            session?.update()?.let { frame ->
                                // Gestion World AR
                                if (faceArManager.currentArMode == "world") {
                                    if (showAnimatedGuide) {
                                        frame.getUpdatedTrackables(Plane::class.java).forEach { plane ->
                                            if (plane.trackingState == TrackingState.TRACKING) {
                                                rootLayout.findViewWithTag<View>("hand_motion_layout")?.let { handMotionLayout ->
                                                    rootLayout.removeView(handMotionLayout)
                                                    showAnimatedGuide = false
                                                }
                                            }
                                        }
                                    }

                                    if (showFeaturePoints) {
                                        val currentFps = frame.fps(lastPointCloudFrame)
                                        if (currentFps < 10) {
                                            frame.acquirePointCloud()?.let { pointCloud ->
                                                if (pointCloud.timestamp != lastPointCloudTimestamp) {
                                                    lastPointCloudFrame = frame
                                                    lastPointCloudTimestamp = pointCloud.timestamp

                                                    val pointsSize = pointCloud.ids?.limit() ?: 0

                                                    pointCloudNodes.toList().forEach { removePointCloudNode(it) }

                                                    val pointsBuffer = pointCloud.points
                                                    for (index in 0 until pointsSize) {
                                                        val pointIndex = index * 4
                                                        val position = Position(
                                                            pointsBuffer[pointIndex],
                                                            pointsBuffer[pointIndex + 1],
                                                            pointsBuffer[pointIndex + 2],
                                                        )
                                                        val confidence = pointsBuffer[pointIndex + 3]
                                                        addPointCloudNode(index, position, confidence)
                                                    }

                                                    pointCloud.release()
                                                }
                                            }
                                        }
                                    }

                                    frame.getUpdatedTrackables(Plane::class.java).forEach { plane ->
                                        if (plane.trackingState == TrackingState.TRACKING &&
                                            !detectedPlanes.contains(plane)
                                        ) {
                                            detectedPlanes.add(plane)
                                            mainScope.launch {
                                                sessionChannel.invokeMethod("onPlaneDetected", detectedPlanes.size)
                                            }
                                        }
                                    }
                                } else if (faceArManager.currentArMode == "face") {
                                    // Gestion Face AR - déléguée au manager
                                    faceArManager.processFaceFrame(frame)
                                }
                            }
                        }
                    } catch (e: Exception) {
                        when (e) {
                            is SessionPausedException -> {
                                Log.d(TAG, "Session paused, skipping frame update")
                            }
                            else -> {
                                Log.e(TAG, "Error during frame update", e)
                                e.printStackTrace()
                            }
                        }
                    }
                }

                setOnGestureListener(
                    onSingleTapConfirmed = { motionEvent: MotionEvent, node: Node? ->
                        if (node != null) {
                            var anchorName: String? = null
                            var currentNode: Node? = node
                            while (currentNode != null) {
                                anchorManager.anchorNodesMap.forEach { (name, anchorNode) ->
                                    if (currentNode == anchorNode) {
                                        anchorName = name
                                        return@forEach
                                    }
                                }
                                if (anchorName != null) break
                                currentNode = currentNode.parent
                            }
                            objectChannel.invokeMethod("onNodeTap", listOf(anchorName))
                            true
                        } else {
                            session?.update()?.let { frame ->
                                val hitResults = frame.hitTest(motionEvent)

                                Log.d(TAG, "Hit Results count: ${hitResults.size}")

                                val planeHits = hitResults
                                    .filter { hit ->
                                        val trackable = hit.trackable
                                        trackable is Plane && trackable.trackingState == TrackingState.TRACKING
                                    }.map { hit ->
                                        mapOf(
                                            "type" to 1,
                                            "distance" to hit.distance.toDouble(),
                                            "position" to mapOf(
                                                "x" to hit.hitPose.tx().toDouble(),
                                                "y" to hit.hitPose.ty().toDouble(),
                                                "z" to hit.hitPose.tz().toDouble()
                                            )
                                        )
                                    }
                                notifyPlaneOrPointTap(planeHits)
                            }
                            true
                        }
                    },
                )
            }

            // Afficher le guide animé si demandé
            if (argShowAnimatedGuide) {
                val handMotionLayout = LayoutInflater
                    .from(viewContext)
                    .inflate(R.layout.sceneform_hand_layout, rootLayout, false)
                    .apply {
                        tag = "hand_motion_layout"
                    }
                rootLayout.addView(handMotionLayout)
            }

            result.success(null)
        } catch (e: Exception) {
            result.error("INIT_ERROR", e.message, null)
        }
    }

    // ========== Camera Handlers ==========

    private fun handleDisableCamera(result: MethodChannel.Result) {
        try {
            isSessionPaused = true
            faceArManager.setSessionPaused(true)
            sceneView.session?.pause()
            result.success(null)
        } catch (e: Exception) {
            result.error("DISABLE_CAMERA_ERROR", e.message, null)
        }
    }

    private fun handleEnableCamera(result: MethodChannel.Result) {
        try {
            isSessionPaused = false
            faceArManager.setSessionPaused(false)
            sceneView.session?.resume()
            result.success(null)
        } catch (e: Exception) {
            result.error("ENABLE_CAMERA_ERROR", e.message, null)
        }
    }

    private fun handleGetCameraPose(result: MethodChannel.Result) {
        try {
            val frame = sceneView.session?.update()
            val cameraPose = frame?.camera?.pose
            if (cameraPose != null) {
                val poseData = mapOf(
                    "position" to mapOf(
                        "x" to cameraPose.tx(),
                        "y" to cameraPose.ty(),
                        "z" to cameraPose.tz()
                    ),
                    "rotation" to mapOf(
                        "x" to cameraPose.rotationQuaternion[0],
                        "y" to cameraPose.rotationQuaternion[1],
                        "z" to cameraPose.rotationQuaternion[2],
                        "w" to cameraPose.rotationQuaternion[3]
                    )
                )
                result.success(poseData)
            } else {
                result.error("NO_CAMERA_POSE", "Camera pose is not available", null)
            }
        } catch (e: Exception) {
            result.error("CAMERA_POSE_ERROR", e.message, null)
        }
    }

    private fun handleSnapshot(result: MethodChannel.Result) {
        try {
            mainScope.launch {
                val bitmap = withContext(Dispatchers.Main) {
                    val bitmap = Bitmap.createBitmap(
                        sceneView.width,
                        sceneView.height,
                        Bitmap.Config.ARGB_8888
                    )

                    try {
                        val listener = PixelCopy.OnPixelCopyFinishedListener { copyResult ->
                            if (copyResult == PixelCopy.SUCCESS) {
                                val outputStream = java.io.ByteArrayOutputStream()
                                bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
                                result.success(outputStream.toByteArray())
                            } else {
                                result.error("SNAPSHOT_ERROR", "Failed to capture snapshot", null)
                            }
                        }

                        PixelCopy.request(
                            sceneView,
                            bitmap,
                            listener,
                            Handler(Looper.getMainLooper())
                        )
                    } catch (e: Exception) {
                        result.error("SNAPSHOT_ERROR", e.message, null)
                    }

                    bitmap
                }
            }
        } catch (e: Exception) {
            result.error("SNAPSHOT_ERROR", e.message, null)
        }
    }

    private fun handleShowPlanes(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            val showPlanes = call.argument<Boolean>("showPlanes") ?: false
            sceneView.apply {
                planeRenderer.isEnabled = showPlanes
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("SHOW_PLANES_ERROR", e.message, null)
        }
    }

    // ========== Node Handlers ==========

    private suspend fun buildModelNode(nodeData: Map<String, Any>): ModelNode? {
        var fileLocation = nodeData["uri"] as? String ?: return null
        when (nodeData["type"] as Int) {
            0 -> { // GLTF2 Model from Flutter asset folder
                val loader = FlutterInjector.instance().flutterLoader()
                fileLocation = loader.getLookupKeyForAsset(fileLocation)
            }
            1 -> { // GLB Model from the web
                fileLocation = fileLocation
            }
            2 -> { // fileSystemAppFolderGLB
                fileLocation = fileLocation
            }
            3 -> { // fileSystemAppFolderGLTF2
                val documentsPath = viewContext.applicationInfo.dataDir
                fileLocation = "$documentsPath/app_flutter/${nodeData["uri"] as String}"
            }
            else -> {
                return null
            }
        }
        
        val transformation = nodeData["transformation"] as? ArrayList<Double> ?: return null

        return try {
            sceneView.modelLoader.loadModelInstance(fileLocation)?.let { modelInstance ->
                object : ModelNode(
                    modelInstance = modelInstance,
                    scaleToUnits = transformation.first().toFloat(),
                ) {
                    override fun onMove(detector: MoveGestureDetector, e: MotionEvent): Boolean {
                        if (handlePans) {
                            val defaultResult = super.onMove(detector, e)
                            objectChannel.invokeMethod("onPanChange", name)
                            return defaultResult
                        }
                        return false
                    }
                    
                    override fun onMoveBegin(detector: MoveGestureDetector, e: MotionEvent): Boolean {
                        if (handlePans) {
                            val defaultResult = super.onMoveBegin(detector, e)
                            objectChannel.invokeMethod("onPanStart", name)
                            defaultResult
                        } 
                        return false
                    }
                    
                    override fun onMoveEnd(detector: MoveGestureDetector, e: MotionEvent) {
                        if (handlePans) {
                            super.onMoveEnd(detector, e)
                            val transformMap = mapOf(
                                "name" to name,
                                "transform" to transform.toFloatArray().toList()
                            )
                            objectChannel.invokeMethod("onPanEnd", transformMap)
                        }
                    }

                    override fun onRotateBegin(detector: RotateGestureDetector, e: MotionEvent): Boolean {
                        if (handleRotation) {
                            val defaultResult = super.onRotateBegin(detector, e)
                            objectChannel.invokeMethod("onRotationStart", name)
                            return defaultResult
                        }
                        return false
                    }

                    override fun onRotate(detector: RotateGestureDetector, e: MotionEvent): Boolean {
                        if (handleRotation) {
                            val defaultResult = super.onRotate(detector, e)
                            objectChannel.invokeMethod("onRotationChange", name)
                            return defaultResult
                        }
                        return false
                    }

                    override fun onRotateEnd(detector: RotateGestureDetector, e: MotionEvent) {
                        if (handleRotation) {
                            super.onRotateEnd(detector, e)
                            val transformMap = mapOf(
                                "name" to name,
                                "transform" to transform.toFloatArray().toList()
                            )
                            objectChannel.invokeMethod("onRotationEnd", transformMap)
                        }
                    }
                }.apply {
                    isPositionEditable = handlePans
                    isRotationEditable = handleRotation
                    name = nodeData["name"] as? String
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun handleAddNode(
        nodeData: Map<String, Any>,
        result: MethodChannel.Result,
    ) {
        try {
            mainScope.launch {
                val node = buildModelNode(nodeData)
                if (node != null) {
                    sceneView.addChildNode(node)
                    node.name?.let { nodeName ->
                        nodesMap[nodeName] = node
                    }
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun handleAddNodeToPlaneAnchor(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            val nodeData = call.arguments as? Map<String, Any>
            val dict_node = nodeData?.get("node") as? Map<String, Any>
            val dict_anchor = nodeData?.get("anchor") as? Map<String, Any>
            if (dict_node == null || dict_anchor == null) {
                result.success(false)
                return
            }

            val anchorName = dict_anchor["name"] as? String
            val anchorNode = anchorManager.anchorNodesMap[anchorName]
            if (anchorNode != null) {
                mainScope.launch {
                    try {
                        buildModelNode(dict_node)?.let { node ->
                            anchorNode.addChildNode(node)
                            sceneView.addChildNode(anchorNode)
                            node.name?.let { nodeName ->
                                nodesMap[nodeName] = node
                            }
                            result.success(true)
                        } ?: result.success(false)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun handleAddNodeToScreenPosition(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            val nodeData = call.arguments as? Map<String, Any>
            val screenPosition = call.argument<Map<String, Double>>("screenPosition")

            if (nodeData == null || screenPosition == null) {
                result.error("INVALID_ARGUMENT", "Node data or screen position is null", null)
                return
            }

            mainScope.launch {
                val node = buildModelNode(nodeData) ?: return@launch
                val hitResultNode = HitResultNode(
                    engine = sceneView.engine,
                    xPx = screenPosition["x"]?.toFloat() ?: 0f,
                    yPx = screenPosition["y"]?.toFloat() ?: 0f,
                ).apply {
                    addChildNode(node)
                }

                sceneView.addChildNode(hitResultNode)
                result.success(null)
            }
        } catch (e: Exception) {
            result.error("ADD_NODE_TO_SCREEN_ERROR", e.message, null)
        }
    }

    private fun handleRemoveNode(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            val nodeData = call.arguments as? Map<String, Any>
            val nodeName = nodeData?.get("name") as? String
            
            if (nodeName == null) {
                result.error("INVALID_ARGUMENT", "Node name is required", null)
                return
            }
            
            Log.d(TAG, "Attempting to remove node with name: $nodeName")
            Log.d(TAG, "Current nodes in map: ${nodesMap.keys}")
            
            nodesMap[nodeName]?.let { node ->
                node.parent?.removeChildNode(node)
                sceneView.removeChildNode(node)
                node.destroy()
                nodesMap.remove(nodeName)
                
                Log.d(TAG, "Node removed successfully and destroyed")
                result.success(nodeName)
            } ?: run {
                Log.e(TAG, "Node not found in nodesMap")
                result.error("NODE_NOT_FOUND", "Node with name $nodeName not found", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error removing node", e)
            result.error("REMOVE_NODE_ERROR", e.message, null)
        }
    }

    private fun handleTransformNode(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            if (handlePans || handleRotation) {
                val name = call.argument<String>("name")
                val newTransformation: ArrayList<Double>? = call.argument<ArrayList<Double>>("transformation")

                if (name == null) {
                    result.error("INVALID_ARGUMENT", "Node name is required", null)
                    return
                }
                
                nodesMap[name]?.let { node ->
                    newTransformation?.let { transform ->
                        if (transform.size != 16) {
                            result.error("INVALID_TRANSFORMATION", "Transformation must be a 4x4 matrix (16 values)", null)
                            return
                        }

                        val position = ScenePosition(
                            x = transform[12].toFloat(),
                            y = transform[13].toFloat(),
                            z = transform[14].toFloat()
                        )

                        val scaleX = kotlin.math.sqrt(
                            (transform[0] * transform[0] + 
                            transform[1] * transform[1] + 
                            transform[2] * transform[2]).toFloat()
                        )
                        val scaleY = kotlin.math.sqrt(
                            (transform[4] * transform[4] + 
                            transform[5] * transform[5] + 
                            transform[6] * transform[6]).toFloat()
                        )
                        val scaleZ = kotlin.math.sqrt(
                            (transform[8] * transform[8] + 
                            transform[9] * transform[9] + 
                            transform[10] * transform[10]).toFloat()
                        )

                        val m00 = transform[0].toFloat() / scaleX
                        val m01 = transform[1].toFloat() / scaleX
                        val m02 = transform[2].toFloat() / scaleX
                        val m10 = transform[4].toFloat() / scaleY
                        val m11 = transform[5].toFloat() / scaleY
                        val m12 = transform[6].toFloat() / scaleY
                        val m20 = transform[8].toFloat() / scaleZ
                        val m21 = transform[9].toFloat() / scaleZ
                        val m22 = transform[10].toFloat() / scaleZ

                        val rotation = SceneRotation(
                            x = kotlin.math.atan2(m21, m22),
                            y = kotlin.math.atan2(-m02, kotlin.math.sqrt(m12 * m12 + m22 * m22)),
                            z = kotlin.math.atan2(m10, m00)
                        )

                        val scale = SceneScale(
                            x = scaleX,
                            y = scaleY,
                            z = scaleZ
                        )

                        node.transform(
                            position = position,
                            rotation = rotation,
                            scale = scale
                        )
                        
                        result.success(null)
                    } ?: result.error("INVALID_TRANSFORMATION", "Transformation is required", null)
                } ?: result.error("NODE_NOT_FOUND", "Node with name $name not found", null)
            }
        } catch (e: Exception) {
            result.error("TRANSFORM_NODE_ERROR", e.message, null)
        }
    }

    // ========== Face AR Node Handler ==========

    private fun handleAddNodeToFace(call: MethodCall, result: MethodChannel.Result) {
        if (faceArManager.currentArMode != "face") {
            result.error("WRONG_MODE", "Must be in Face AR mode to add nodes to face", null)
            return
        }

        try {
            val nodeData = call.arguments as? Map<String, Any>
            if (nodeData == null) {
                result.error("INVALID_ARGUMENT", "Node data is required", null)
                return
            }

            val region = nodeData["region"] as? String ?: "nose"
            
            mainScope.launch {
                val node = buildModelNode(nodeData)
                if (node != null) {
                    val faces = sceneView.session?.getAllTrackables(AugmentedFace::class.java)
                        ?.filter { it.trackingState == TrackingState.TRACKING }
                    
                    val face = faces?.firstOrNull()
                    if (face != null) {
                        val faceId = face.hashCode()
                        
                        val regionPose = faceArManager.getRegionPose(face, region)
                        node.position = ScenePosition(
                            x = regionPose.tx(),
                            y = regionPose.ty(),
                            z = regionPose.tz()
                        )
                        
                        sceneView.addChildNode(node)
                        faceArManager.faceNodesMap[faceId] = node
                        node.name?.let { nodeName ->
                            nodesMap[nodeName] = node
                        }
                        
                        result.success(true)
                    } else {
                        result.error("NO_FACE", "No face detected", null)
                    }
                } else {
                    result.success(false)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error adding node to face", e)
            result.error("ADD_NODE_TO_FACE_ERROR", e.message, null)
        }
    }

    // ========== Utility Methods ==========

    private fun handleShowWorldOrigin(show: Boolean) {
        if (show) {
            if (worldOriginNode == null) {
                worldOriginNode = makeWorldOriginNode(viewContext)
            }
            worldOriginNode?.let { node ->
                sceneView.addChildNode(node)
            }
        } else {
            worldOriginNode?.let { node ->
                sceneView.removeChildNode(node)
            }
            worldOriginNode = null
        }
    }

    private fun makeWorldOriginNode(context: Context): Node {
        val axisSize = 0.1f
        val axisRadius = 0.005f
        
        val engine = sceneView.engine
        val materialLoader = MaterialLoader(engine, context)
        
        val rootNode = Node(engine = engine)
        
        val xNode = CylinderNode(
            engine = engine,
            radius = axisRadius,
            height = axisSize,
            materialInstance = materialLoader.createColorInstance(
                color = colorOf(1f, 0f, 0f, 1f),
                metallic = 0.0f,
                roughness = 0.4f
            )
        )
        
        val yNode = CylinderNode(
            engine = engine,
            radius = axisRadius,
            height = axisSize,
            materialInstance = materialLoader.createColorInstance(
                color = colorOf(0f, 1f, 0f, 1f),
                metallic = 0.0f,
                roughness = 0.4f
            )
        )
        
        val zNode = CylinderNode(
            engine = engine,
            radius = axisRadius,
            height = axisSize,
            materialInstance = materialLoader.createColorInstance(
                color = colorOf(0f, 0f, 1f, 1f),
                metallic = 0.0f,
                roughness = 0.4f
            )
        )

        rootNode.addChildNode(xNode)
        rootNode.addChildNode(yNode)
        rootNode.addChildNode(zNode)

        xNode.position = Position(axisSize / 2, 0f, 0f)
        xNode.rotation = Rotation(0f, 0f, 90f)

        yNode.position = Position(0f, axisSize / 2, 0f)

        zNode.position = Position(0f, 0f, axisSize / 2)
        zNode.rotation = Rotation(90f, 0f, 0f)

        return rootNode
    }

    private fun getPointCloudModelInstance(): ModelInstance? {
        if (pointCloudModelInstances.isEmpty()) {
            pointCloudModelInstances = sceneView.modelLoader
                .createInstancedModel(
                    assetFileLocation = "models/point_cloud.glb",
                    count = 1000,
                ).toMutableList()
        }
        return pointCloudModelInstances.removeLastOrNull()
    }

    private fun addPointCloudNode(
        id: Int,
        position: Position,
        confidence: Float,
    ) {
        if (pointCloudNodes.size < 1000) {
            getPointCloudModelInstance()?.let { modelInstance ->
                val pointCloudNode = PointCloudNode(
                    modelInstance = modelInstance,
                    id = id,
                    confidence = confidence,
                ).apply {
                    this.position = position
                }
                pointCloudNodes += pointCloudNode
                sceneView.addChildNode(pointCloudNode)
            }
        }
    }

    private fun removePointCloudNode(pointCloudNode: PointCloudNode) {
        pointCloudNodes -= pointCloudNode
        sceneView.removeChildNode(pointCloudNode)
        pointCloudNode.destroy()
    }

    // ========== Notifications ==========

    private fun notifyError(error: String) {
        mainScope.launch {
            sessionChannel.invokeMethod("onError", listOf(error))
        }
    }

    private fun notifyPlaneOrPointTap(hitResults: List<Map<String, Any>>) {
        mainScope.launch {
            try {
                val serializedResults = ArrayList<HashMap<String, Any>>()
                hitResults.forEach { hit ->
                    serializedResults.add(serializeHitResult(hit))
                }
                sessionChannel.invokeMethod("onPlaneOrPointTap", serializedResults)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    // ========== PlatformView Implementation ==========

    override fun getView(): View = rootLayout

    override fun dispose() {
        Log.i(TAG, "dispose")
        sessionChannel.setMethodCallHandler(null)
        objectChannel.setMethodCallHandler(null)
        anchorChannel.setMethodCallHandler(null)
        
        // Cleanup managers
        faceArManager.cleanup()
        anchorManager.cleanup()
        
        nodesMap.clear()
        sceneView.destroy()
        pointCloudNodes.toList().forEach { removePointCloudNode(it) }
        pointCloudModelInstances.clear()
    }
}