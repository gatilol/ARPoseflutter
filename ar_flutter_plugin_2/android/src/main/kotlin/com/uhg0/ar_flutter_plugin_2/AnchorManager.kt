package com.uhg0.ar_flutter_plugin_2

import android.util.Log
import com.google.ar.core.Anchor.CloudAnchorState
import com.google.ar.core.Config
import com.google.ar.core.Pose
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.ar.arcore.canHostCloudAnchor
import io.github.sceneview.ar.node.AnchorNode
import io.github.sceneview.ar.node.CloudAnchorNode
import io.github.sceneview.math.Position
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * AnchorManager - Gestionnaire des ancres et Cloud Anchors
 * 
 * Cette classe gère :
 * - La création et suppression d'ancres locales
 * - L'initialisation du mode Google Cloud Anchor
 * - L'upload et le download des Cloud Anchors
 * - La résolution des Cloud Anchors
 */
class AnchorManager(
    private val sessionChannel: MethodChannel,
    private val anchorChannel: MethodChannel,
    private val mainScope: CoroutineScope
) {
    companion object {
        private const val TAG = "AnchorManager"
    }

    // ========== État ==========
    val anchorNodesMap = mutableMapOf<String, AnchorNode>()
    
    // Référence à la sceneView (sera définie par ArView)
    private var sceneView: ARSceneView? = null

    // ========== Configuration ==========

    fun setSceneView(view: ARSceneView) {
        this.sceneView = view
    }

    fun getSceneView(): ARSceneView? = sceneView

    // ========== Method Handlers ==========

    /**
     * Ajoute une ancre à la scène
     */
    fun handleAddAnchor(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val sv = sceneView
        if (sv == null) {
            result.error("NO_SCENE_VIEW", "SceneView not available", null)
            return
        }
        
        try {
            val anchorType = call.argument<Int>("type")
            if (anchorType == 0) { // Plane Anchor
                val transform = call.argument<ArrayList<Double>>("transformation")
                val name = call.argument<String>("name")

                if (name != null && transform != null) {
                    try {
                        val position = Position(
                            x = transform[12].toFloat(),
                            y = transform[13].toFloat(),
                            z = transform[14].toFloat()
                        )
                        
                        val m = FloatArray(16) { i -> transform[i].toFloat() }
                        
                        // Extraire scale
                        val scaleX = kotlin.math.sqrt(m[0]*m[0] + m[1]*m[1] + m[2]*m[2])
                        val scaleY = kotlin.math.sqrt(m[4]*m[4] + m[5]*m[5] + m[6]*m[6])
                        val scaleZ = kotlin.math.sqrt(m[8]*m[8] + m[9]*m[9] + m[10]*m[10])
                        
                        // Extraire rotation
                        val r = FloatArray(9)
                        r[0] = m[0] / scaleX; r[1] = m[1] / scaleX; r[2] = m[2] / scaleX
                        r[3] = m[4] / scaleY; r[4] = m[5] / scaleY; r[5] = m[6] / scaleY
                        r[6] = m[8] / scaleZ; r[7] = m[9] / scaleZ; r[8] = m[10] / scaleZ
                        
                        // Convertir en quaternion
                        val trace = r[0] + r[4] + r[8]
                        val quat = FloatArray(4)
                        
                        if (trace > 0) {
                            val s = 0.5f / kotlin.math.sqrt(trace + 1.0f)
                            quat[3] = 0.25f / s
                            quat[0] = (r[7] - r[5]) * s
                            quat[1] = (r[2] - r[6]) * s
                            quat[2] = (r[3] - r[1]) * s
                        } else if (r[0] > r[4] && r[0] > r[8]) {
                            val s = 2.0f * kotlin.math.sqrt(1.0f + r[0] - r[4] - r[8])
                            quat[3] = (r[7] - r[5]) / s
                            quat[0] = 0.25f * s
                            quat[1] = (r[1] + r[3]) / s
                            quat[2] = (r[2] + r[6]) / s
                        } else if (r[4] > r[8]) {
                            val s = 2.0f * kotlin.math.sqrt(1.0f + r[4] - r[0] - r[8])
                            quat[3] = (r[2] - r[6]) / s
                            quat[0] = (r[1] + r[3]) / s
                            quat[1] = 0.25f * s
                            quat[2] = (r[5] + r[7]) / s
                        } else {
                            val s = 2.0f * kotlin.math.sqrt(1.0f + r[8] - r[0] - r[4])
                            quat[3] = (r[3] - r[1]) / s
                            quat[0] = (r[2] + r[6]) / s
                            quat[1] = (r[5] + r[7]) / s
                            quat[2] = 0.25f * s
                        }

                        val pose = Pose(
                            floatArrayOf(position.x, position.y, position.z),
                            floatArrayOf(quat[0], quat[1], quat[2], quat[3])
                        )

                        val anchor = sv.session?.createAnchor(pose)
                        if (anchor != null) {
                            val anchorNode = AnchorNode(sv.engine, anchor)
                            sv.addChildNode(anchorNode)
                            anchorNodesMap[name] = anchorNode
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in handleAddAnchor: ${e.message}")
                        result.success(false)
                    }
                } else {
                    result.success(false)
                }
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleAddAnchor: ${e.message}")
            e.printStackTrace()
            result.success(false)
        }
    }

    /**
     * Supprime une ancre de la scène
     */
    fun handleRemoveAnchor(
        anchorName: String?,
        result: MethodChannel.Result
    ) {
        val sv = sceneView
        if (sv == null) {
            result.error("NO_SCENE_VIEW", "SceneView not available", null)
            return
        }
        
        try {
            if (anchorName == null) {
                result.error("INVALID_ARGUMENT", "Anchor name is required", null)
                return
            }

            val anchor = anchorNodesMap[anchorName]
            if (anchor != null) {
                sv.removeChildNode(anchor)
                anchor.anchor?.detach()
                anchorNodesMap.remove(anchorName)
                result.success(null)
            } else {
                result.error("ANCHOR_NOT_FOUND", "Anchor with name $anchorName not found", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error removing anchor", e)
            result.error("REMOVE_ANCHOR_ERROR", e.message, null)
        }
    }

    /**
     * Initialise le mode Google Cloud Anchor
     */
    fun handleInitGoogleCloudAnchorMode(result: MethodChannel.Result) {
        val sv = sceneView
        if (sv == null) {
            result.error("NO_SCENE_VIEW", "SceneView not available", null)
            return
        }
        
        try {
            Log.d(TAG, "🔄 Initialisation du mode Cloud Anchor...")
            sv.session?.let { session ->
                session.configure(session.config.apply {
                    cloudAnchorMode = Config.CloudAnchorMode.ENABLED
                })
            }
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Erreur lors de l'initialisation du mode Cloud Anchor", e)
            mainScope.launch {
                sessionChannel.invokeMethod("onError", listOf("Error initializing cloud anchor mode: ${e.message}"))
            }
            result.error("CLOUD_ANCHOR_INIT_ERROR", e.message, null)
        }
    }

    /**
     * Upload une ancre vers le cloud
     */
    fun handleUploadAnchor(call: MethodCall, result: MethodChannel.Result) {
        val sv = sceneView
        if (sv == null) {
            result.error("NO_SCENE_VIEW", "SceneView not available", null)
            return
        }
        
        try {
            val anchorName = call.argument<String>("name")
            Log.d(TAG, "⚓ Début de l'upload de l'ancre: $anchorName")
            
            val session = sv.session
            if (session == null) {
                Log.e(TAG, "❌ Erreur: session AR non disponible")
                result.error("SESSION_ERROR", "AR Session is not available", null)
                return
            }

            Log.d(TAG, "🔄 Vérification de la configuration Cloud Anchor...")
            try {
                sv.configureSession { session, config ->
                    config.cloudAnchorMode = Config.CloudAnchorMode.ENABLED
                    config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                }
                Log.d(TAG, "✅ Mode Cloud Anchor configuré avec succès")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Erreur lors de la configuration du mode Cloud Anchor", e)
                result.error("CLOUD_ANCHOR_CONFIG_ERROR", e.message, null)
                return
            }

            if (anchorName == null) {
                Log.e(TAG, "❌ Erreur: nom de l'ancre manquant")
                result.error("INVALID_ARGUMENT", "Anchor name is required", null)
                return
            }

            Log.d(TAG, "📱 Vérification de la capacité à héberger l'ancre cloud...")
            if (!session.canHostCloudAnchor(sv.cameraNode)) {
                Log.e(TAG, "❌ Erreur: données visuelles insuffisantes pour héberger l'ancre cloud")
                result.error("HOSTING_ERROR", "Insufficient visual data to host", null)
                return
            }

            val anchorNode = anchorNodesMap[anchorName]
            if (anchorNode == null) {
                Log.e(TAG, "❌ Erreur: ancre non trouvée: $anchorName")
                Log.d(TAG, "📍 Ancres disponibles: ${anchorNodesMap.keys}")
                result.error("ANCHOR_NOT_FOUND", "Anchor not found: $anchorName", null)
                return
            }

            Log.d(TAG, "🔄 Création du CloudAnchorNode...")
            val cloudAnchorNode = CloudAnchorNode(sv.engine, anchorNode.anchor!!)
            
            Log.d(TAG, "☁️ Début de l'hébergement de l'ancre cloud...")
            cloudAnchorNode.host(session) { cloudAnchorId, state ->
                Log.d(TAG, "📡 État de l'hébergement: $state, ID: $cloudAnchorId")
                mainScope.launch {
                    if (state == CloudAnchorState.SUCCESS && cloudAnchorId != null) {
                        Log.d(TAG, "✅ Ancre cloud hébergée avec succès: $cloudAnchorId")
                        val args = mapOf(
                            "name" to anchorName,
                            "cloudanchorid" to cloudAnchorId
                        )
                        anchorChannel.invokeMethod("onCloudAnchorUploaded", args)
                        result.success(true)
                    } else {
                        Log.e(TAG, "❌ Échec de l'hébergement de l'ancre cloud: $state")
                        sessionChannel.invokeMethod("onError", listOf("Failed to host cloud anchor: $state"))
                        result.error("HOSTING_ERROR", "Failed to host cloud anchor: $state", null)
                    }
                }
            }
            
            Log.d(TAG, "➕ Ajout du CloudAnchorNode à la scène...")
            sv.addChildNode(cloudAnchorNode)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception lors de l'upload de l'ancre", e)
            Log.e(TAG, "Stack trace:", e)
            result.error("UPLOAD_ANCHOR_ERROR", e.message, null)
        }
    }

    /**
     * Download une ancre depuis le cloud
     */
    fun handleDownloadAnchor(call: MethodCall, result: MethodChannel.Result) {
        val sv = sceneView
        if (sv == null) {
            result.error("NO_SCENE_VIEW", "SceneView not available", null)
            return
        }
        
        try {
            val cloudAnchorId = call.argument<String>("cloudanchorid")
            if (cloudAnchorId == null) {
                mainScope.launch {
                    sessionChannel.invokeMethod("onError", listOf("Cloud Anchor ID is required"))
                }
                result.error("INVALID_ARGUMENT", "Cloud Anchor ID is required", null)
                return
            }

            val session = sv.session
            if (session == null) {
                mainScope.launch {
                    sessionChannel.invokeMethod("onError", listOf("AR Session is not available"))
                }
                result.error("SESSION_ERROR", "AR Session is not available", null)
                return
            }

            CloudAnchorNode.resolve(
                sv.engine,
                session,
                cloudAnchorId
            ) { state, node ->
                mainScope.launch {
                    if (!state.isError && node != null) {
                        sv.addChildNode(node)
                        val anchorData = mapOf(
                            "type" to 0,
                            "cloudanchorid" to cloudAnchorId
                        )
                        anchorChannel.invokeMethod(
                            "onAnchorDownloadSuccess",
                            anchorData,
                            object : MethodChannel.Result {
                                override fun success(result: Any?) {
                                    val anchorName = result.toString()
                                    anchorNodesMap[anchorName] = node
                                }

                                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                                    sessionChannel.invokeMethod("onError", listOf("Error registering downloaded anchor: $errorMessage"))
                                }

                                override fun notImplemented() {
                                    sessionChannel.invokeMethod("onError", listOf("Error registering downloaded anchor: not implemented"))
                                }
                            }
                        )
                        result.success(true)
                    } else {
                        sessionChannel.invokeMethod("onError", listOf("Failed to resolve cloud anchor: $state"))
                        result.error("RESOLVE_ERROR", "Failed to resolve cloud anchor: $state", null)
                    }
                }
            }
        } catch (e: Exception) {
            mainScope.launch {
                sessionChannel.invokeMethod("onError", listOf("Error downloading anchor: ${e.message}"))
            }
            result.error("DOWNLOAD_ANCHOR_ERROR", e.message, null)
        }
    }

    /**
     * Résout une Cloud Anchor par son ID
     */
    fun handleResolveCloudAnchor(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val sv = sceneView
        if (sv == null) {
            result.error("NO_SCENE_VIEW", "SceneView not available", null)
            return
        }
        
        try {
            val cloudAnchorId = call.argument<String>("cloudAnchorId")
            if (cloudAnchorId == null) {
                result.error("INVALID_ARGUMENT", "Cloud Anchor ID is required", null)
                return
            }

            val session = sv.session
            if (session == null) {
                result.error("SESSION_ERROR", "AR Session is not available", null)
                return
            }

            CloudAnchorNode.resolve(
                sv.engine,
                session,
                cloudAnchorId,
            ) { state, node ->
                if (!state.isError && node != null) {
                    sv.addChildNode(node)
                    result.success(null)
                } else {
                    result.error("RESOLVE_ERROR", "Failed to resolve cloud anchor: $state", null)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error resolving cloud anchor", e)
            result.error("RESOLVE_CLOUD_ANCHOR_ERROR", e.message, null)
        }
    }

    /**
     * Récupère la pose d'une ancre
     */
    fun handleGetAnchorPose(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val sv = sceneView
        if (sv == null) {
            result.error("NO_SCENE_VIEW", "SceneView not available", null)
            return
        }
        
        try {
            val anchorId = call.argument<String>("anchorId")
            if (anchorId == null) {
                result.error("INVALID_ARGUMENT", "Anchor ID is required", null)
                return
            }

            val anchor = sv.session?.allAnchors?.find { it.cloudAnchorId == anchorId }
            if (anchor != null) {
                val anchorPose = anchor.pose
                val poseData = mapOf(
                    "position" to mapOf(
                        "x" to anchorPose.tx(),
                        "y" to anchorPose.ty(),
                        "z" to anchorPose.tz()
                    ),
                    "rotation" to mapOf(
                        "x" to anchorPose.rotationQuaternion[0],
                        "y" to anchorPose.rotationQuaternion[1],
                        "z" to anchorPose.rotationQuaternion[2],
                        "w" to anchorPose.rotationQuaternion[3]
                    )
                )
                result.success(poseData)
            } else {
                result.error("ANCHOR_NOT_FOUND", "Anchor with ID $anchorId not found", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting anchor pose", e)
            result.error("ANCHOR_POSE_ERROR", e.message, null)
        }
    }

    // ========== Cleanup ==========

    /**
     * Nettoie toutes les ancres
     */
    fun cleanup() {
        val sv = sceneView
        
        anchorNodesMap.values.forEach { anchor ->
            sv?.removeChildNode(anchor)
            anchor.anchor?.detach()
        }
        anchorNodesMap.clear()
        
        Log.d(TAG, "🧹 AnchorManager cleaned up")
    }
}