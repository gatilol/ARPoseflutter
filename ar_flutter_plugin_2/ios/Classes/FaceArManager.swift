//
//  FaceArManager.swift
//  ar_flutter_plugin_2
//
//  Gestionnaire pour Face AR avec ARKit.
//  S'intègre avec la structure existante de IosARView.
//
//  Fonctionnalités:
//  - Face tracking avec ARFaceAnchor
//  - Mesh facial avec ARSCNFaceGeometry
//  - Textures makeup
//  - Modèles 3D attachés au visage
//

import ARKit
import SceneKit
import Flutter
import GLTFSceneKit

/// Gestionnaire pour le mode Face AR
class FaceArManager: NSObject {
    
    // MARK: - Properties
    
    /// Référence à la vue AR
    private weak var sceneView: ARSCNView?
    
    /// Canal de communication avec Flutter
    private var anchorManagerChannel: FlutterMethodChannel?
    private var sessionManagerChannel: FlutterMethodChannel?
    
    /// Nœud principal du visage
    private var faceNode: SCNNode?
    
    /// Géométrie du mesh facial ARKit
    private var faceGeometry: ARSCNFaceGeometry?
    
    /// Nœud contenant le mesh facial
    private var faceMeshNode: SCNNode?
    
    /// Matériau pour le mesh facial
    private var faceMeshMaterial: SCNMaterial?
    
    /// Visibilité du mesh facial
    // ========== CONFIGURATION DÉVELOPPEUR ==========
    // Mettre à true pour afficher le mesh facial (debug)
    // Mettre à false pour le cacher (production/grand public)
    private var isFaceMeshVisible: Bool = false
    
    // Offset vertical du maquillage (pour ajuster le positionnement)
    // Valeur NÉGATIVE = texture MONTE sur le visage (ex: -0.03)
    // Valeur POSITIVE = texture DESCEND sur le visage (ex: 0.03)
    // Ajuster selon les besoins (essayer -0.02 à -0.05 pour remonter)
    private let makeupVerticalOffset: Float = 0.05
    // ================================================
    
    /// Couleur du mesh (format ARGB)
    private var meshColor: Int = 0x8800FF00  // Vert semi-transparent
    
    /// Texture makeup actuelle
    private var makeupTexture: UIImage?
    private var makeupTexturePath: String?
    
    /// Modèle 3D attaché au visage
    private var faceModelNode: SCNNode?
    private var faceModelPath: String?
    
    /// Nœuds attachés aux régions du visage
    private var regionNodes: [String: (node: SCNNode, region: String)] = [:]
    
    /// État de détection
    private var isFaceDetected: Bool = false
    
    /// Throttling pour les mises à jour de pose
    private var lastPoseUpdateTime: TimeInterval = 0
    private let poseUpdateInterval: TimeInterval = 0.033  // ~30 fps
    
    /// Blend shapes (expressions faciales)
    private var currentBlendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]?
    
    // MARK: - Initialization
    
    init(sceneView: ARSCNView, anchorChannel: FlutterMethodChannel?, sessionChannel: FlutterMethodChannel?) {
        self.sceneView = sceneView
        self.anchorManagerChannel = anchorChannel
        self.sessionManagerChannel = sessionChannel
        super.init()
        
        setupDefaultMaterial()
        print("[FaceArManager] Initialized")
    }
    
    // MARK: - Setup
    
    private func setupDefaultMaterial() {
        faceMeshMaterial = SCNMaterial()
        faceMeshMaterial?.lightingModel = .physicallyBased
        
        // Si mesh non visible, le rendre transparent (pas caché, pour que le maquillage fonctionne)
        if isFaceMeshVisible {
            faceMeshMaterial?.diffuse.contents = colorFromARGB(meshColor)
        } else {
            faceMeshMaterial?.diffuse.contents = UIColor.clear
        }
        
        faceMeshMaterial?.isDoubleSided = true
        faceMeshMaterial?.writesToDepthBuffer = true
        faceMeshMaterial?.readsFromDepthBuffer = true
        faceMeshMaterial?.transparencyMode = .dualLayer
    }
    
    // MARK: - Session Management
    
    /// Démarre une session Face AR
    func startFaceTracking() -> Bool {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("[FaceArManager] Face tracking not supported on this device")
            DispatchQueue.main.async {
                self.sessionManagerChannel?.invokeMethod("onError", arguments: ["Face tracking requires TrueDepth camera (iPhone X or later)"])
            }
            return false
        }
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        if #available(iOS 13.0, *) {
            configuration.maximumNumberOfTrackedFaces = 1
        }
        
        // Configurer l'éclairage de la scène pour les modèles 3D
        sceneView?.autoenablesDefaultLighting = true
        sceneView?.automaticallyUpdatesLighting = true
        
        // Ajouter une lumière ambiante pour éviter les modèles noirs
        addAmbientLight()
        
        sceneView?.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        print("[FaceArManager] Face tracking started")
        return true
    }
    
    /// Ajoute une lumière ambiante à la scène
    private func addAmbientLight() {
        // Lumière ambiante pour illuminer uniformément
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 1000
        ambientLight.color = UIColor.white
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        ambientLightNode.name = "faceAR_ambientLight"
        sceneView?.scene.rootNode.addChildNode(ambientLightNode)
        
        // Lumière directionnelle pour donner du relief
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 500
        directionalLight.color = UIColor.white
        
        let directionalLightNode = SCNNode()
        directionalLightNode.light = directionalLight
        directionalLightNode.position = SCNVector3(0, 1, 1)
        directionalLightNode.name = "faceAR_directionalLight"
        sceneView?.scene.rootNode.addChildNode(directionalLightNode)
        
        print("[FaceArManager] Lights added to scene")
    }
    
    /// Arrête le tracking facial
    func stopFaceTracking() {
        sceneView?.session.pause()
        cleanup()
        print("[FaceArManager] Face tracking stopped")
    }
    
    // MARK: - ARSCNViewDelegate Callbacks
    
    /// Appelé quand un visage est détecté
    func didAddFaceAnchor(_ anchor: ARFaceAnchor, node: SCNNode) {
        print("[FaceArManager] Face detected")
        
        faceNode = node
        
        // Créer le mesh facial
        if let device = sceneView?.device {
            createFaceMesh(device: device, node: node)
        }
        
        // Charger le modèle 3D si défini
        if let modelPath = faceModelPath {
            loadFaceModel(assetPath: modelPath)
        }
        
        // Ajouter les nœuds de région en attente
        for (name, info) in regionNodes {
            if info.node.parent == nil {
                node.addChildNode(info.node)
            }
        }
        
        isFaceDetected = true
        
        DispatchQueue.main.async {
            self.sessionManagerChannel?.invokeMethod("onFaceDetected", arguments: true)
        }
    }
    
    /// Appelé à chaque mise à jour du visage
    func didUpdateFaceAnchor(_ anchor: ARFaceAnchor, node: SCNNode) {
        // Mettre à jour la géométrie du mesh
        faceGeometry?.update(from: anchor.geometry)
        
        // Stocker les blend shapes
        currentBlendShapes = anchor.blendShapes
        
        // Notifier Flutter de la pose (throttled)
        notifyFacePose(anchor: anchor)
    }
    
    /// Appelé quand le visage est perdu
    func didRemoveFaceAnchor(_ anchor: ARFaceAnchor, node: SCNNode) {
        print("[FaceArManager] Face lost")
        
        isFaceDetected = false
        faceNode = nil
        faceMeshNode = nil
        
        DispatchQueue.main.async {
            self.sessionManagerChannel?.invokeMethod("onFaceDetected", arguments: false)
        }
    }
    
    // MARK: - Face Mesh
    
    private func createFaceMesh(device: MTLDevice, node: SCNNode) {
        guard let geometry = ARSCNFaceGeometry(device: device) else {
            print("[FaceArManager] Failed to create ARSCNFaceGeometry")
            return
        }
        
        faceGeometry = geometry
        
        faceMeshNode = SCNNode(geometry: geometry)
        faceMeshNode?.name = "faceMesh"
        
        // Appliquer le matériau
        if let material = faceMeshMaterial {
            geometry.firstMaterial = material
        }
        
        // NE PAS cacher le mesh - le rendre transparent si besoin
        // Cela permet au maquillage de s'afficher même si isFaceMeshVisible = false
        faceMeshNode?.isHidden = false
        node.addChildNode(faceMeshNode!)
        
        // Appliquer la texture si définie
        if let texturePath = makeupTexturePath {
            applyMakeupTexture(texturePath)
        }
        
        print("[FaceArManager] Face mesh created (1220 vertices), visible: \(isFaceMeshVisible)")
    }
    
    /// Définit la visibilité du mesh (couleur de base, pas le maquillage)
    func setFaceMeshVisible(_ visible: Bool) {
        isFaceMeshVisible = visible
        
        // Ne pas utiliser isHidden - ça cacherait aussi le maquillage
        // Au lieu de ça, rendre le matériau transparent ou coloré
        if makeupTexture == nil {
            // Pas de maquillage - appliquer la couleur ou transparent
            if visible {
                faceMeshMaterial?.diffuse.contents = colorFromARGB(meshColor)
            } else {
                faceMeshMaterial?.diffuse.contents = UIColor.clear
            }
        }
        // Si maquillage présent, ne pas toucher au diffuse (il contient la texture)
        
        print("[FaceArManager] Mesh visibility: \(visible)")
    }
    
    /// Définit la couleur du mesh (ARGB)
    func setFaceMeshColor(_ colorValue: Int) {
        meshColor = colorValue
        
        // Si une texture est appliquée, la supprimer
        if makeupTexture != nil {
            clearMakeupTexture()
        }
        
        faceMeshMaterial?.diffuse.contents = colorFromARGB(colorValue)
        print("[FaceArManager] Mesh color updated")
    }
    
    /// Définit la couleur du mesh (UIColor)
    func setFaceMeshColor(_ color: UIColor) {
        // Si une texture est appliquée, la supprimer
        if makeupTexture != nil {
            clearMakeupTexture()
        }
        
        faceMeshMaterial?.diffuse.contents = color
        print("[FaceArManager] Mesh color updated (UIColor)")
    }
    
    // MARK: - Makeup Texture
    
    /// Applique une texture makeup
    func setMakeupTexture(assetPath: String) {
        makeupTexturePath = assetPath
        
        if faceMeshNode != nil {
            applyMakeupTexture(assetPath)
        }
    }
    
    private func applyMakeupTexture(_ assetPath: String) {
        print("[FaceArManager] Applying makeup texture: \(assetPath)")
        
        guard let image = loadImageFromFlutterAssets(assetPath) else {
            print("[FaceArManager] Failed to load texture: \(assetPath)")
            DispatchQueue.main.async {
                self.sessionManagerChannel?.invokeMethod("onError", arguments: ["Failed to load makeup texture: \(assetPath)"])
            }
            return
        }
        
        makeupTexture = image
        
        // Mode UNLIT pour éviter les facettes visibles
        faceMeshMaterial?.lightingModel = .constant
        faceMeshMaterial?.diffuse.contents = image
        
        // ========== OFFSET VERTICAL DU MAQUILLAGE ==========
        // Applique un décalage pour ajuster la position de la texture
        // Translation sur Y pour remonter la texture sur le visage
        faceMeshMaterial?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0, makeupVerticalOffset, 0)
        // ===================================================
        
        // Configuration du filtrage
        faceMeshMaterial?.diffuse.wrapS = .clamp
        faceMeshMaterial?.diffuse.wrapT = .clamp
        faceMeshMaterial?.diffuse.magnificationFilter = .linear
        faceMeshMaterial?.diffuse.minificationFilter = .linear
        faceMeshMaterial?.diffuse.mipFilter = .linear
        
        // Transparence
        faceMeshMaterial?.transparencyMode = .dualLayer
        faceMeshMaterial?.blendMode = .alpha
        
        print("[FaceArManager] Makeup texture applied: \(Int(image.size.width))x\(Int(image.size.height)), offset: \(makeupVerticalOffset)")
    }
    
    /// Supprime la texture makeup
    func clearMakeupTexture() {
        makeupTexture = nil
        makeupTexturePath = nil
        
        faceMeshMaterial?.lightingModel = .physicallyBased
        
        // Réinitialiser le transform de la texture
        faceMeshMaterial?.diffuse.contentsTransform = SCNMatrix4Identity
        
        // Remettre la couleur ou transparent selon isFaceMeshVisible
        if isFaceMeshVisible {
            faceMeshMaterial?.diffuse.contents = colorFromARGB(meshColor)
        } else {
            faceMeshMaterial?.diffuse.contents = UIColor.clear
        }
        
        print("[FaceArManager] Makeup texture cleared")
    }
    
    // MARK: - 3D Face Model
    
    /// Charge un modèle 3D pour le visage
    func loadFaceModel(assetPath: String) {
        print("[FaceArManager] Loading face model: \(assetPath)")
        
        faceModelPath = assetPath
        
        guard let faceNode = faceNode else {
            print("[FaceArManager] Face not detected, model will load when face appears")
            return
        }
        
        // Supprimer l'ancien modèle
        faceModelNode?.removeFromParentNode()
        faceModelNode = nil
        
        // Charger le nouveau modèle
        guard let modelURL = getFlutterAssetURL(assetPath) else {
            print("[FaceArManager] Model not found: \(assetPath)")
            return
        }
        
        let fileExtension = (assetPath as NSString).pathExtension.lowercased()
        
        do {
            var scene: SCNScene?
            
            switch fileExtension {
            case "scn":
                scene = try SCNScene(url: modelURL, options: nil)
            case "dae":
                scene = try SCNScene(url: modelURL, options: [SCNSceneSource.LoadingOption.convertToYUp: true])
            case "glb", "gltf":
                // Utiliser GLTFSceneKit existant
                if let node = loadGLTFModel(url: modelURL, name: "faceModel") {
                    faceModelNode = node
                    faceNode.addChildNode(node)
                    print("[FaceArManager] GLTF face model loaded")
                    return
                } else {
                    print("[FaceArManager] Failed to load GLTF model: \(assetPath)")
                    return
                }
            default:
                print("[FaceArManager] Unsupported format: \(fileExtension)")
                return
            }
            
            guard let loadedScene = scene else { return }
            
            faceModelNode = SCNNode()
            faceModelNode?.name = "faceModel"
            
            for child in loadedScene.rootNode.childNodes {
                faceModelNode?.addChildNode(child.clone())
            }
            
            faceNode.addChildNode(faceModelNode!)
            print("[FaceArManager] Face model loaded")
            
        } catch {
            print("[FaceArManager] Error loading model: \(error.localizedDescription)")
        }
    }
    
    /// Charge un modèle GLTF via GLTFSceneKit
    private func loadGLTFModel(url: URL, name: String) -> SCNNode? {
        print("[FaceArManager] Loading GLTF model from: \(url.path)")
        
        do {
            let sceneSource = try GLTFSceneSource(path: url.path)
            let scene = try sceneSource.scene()
            
            let node = SCNNode()
            node.name = name
            
            print("[FaceArManager] GLTF scene loaded, childNodes: \(scene.rootNode.childNodes.count)")
            
            for child in scene.rootNode.childNodes {
                let clonedChild = child.flattenedClone()
                
                // Configurer les matériaux pour répondre à la lumière
                configureMaterialsForLighting(node: clonedChild)
                
                node.addChildNode(clonedChild)
            }
            
            print("[FaceArManager] GLTF node '\(name)' created successfully")
            return node
        } catch {
            print("[FaceArManager] GLTF loading error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Configure les matériaux d'un nœud pour qu'ils répondent à la lumière
    private func configureMaterialsForLighting(node: SCNNode) {
        // Configurer le matériau de ce nœud
        if let geometry = node.geometry {
            for material in geometry.materials {
                // Si le diffuse est noir ou non défini, utiliser une couleur par défaut
                if material.diffuse.contents == nil {
                    material.diffuse.contents = UIColor.white
                }
                
                // Utiliser un modèle d'éclairage qui fonctionne bien avec les lumières
                // blinn est un bon compromis entre réalisme et compatibilité
                material.lightingModel = .blinn
                
                // S'assurer que le matériau est visible des deux côtés
                material.isDoubleSided = true
                
                print("[FaceArManager] Material configured: \(material.name ?? "unnamed")")
            }
        }
        
        // Récursivement configurer les enfants
        for child in node.childNodes {
            configureMaterialsForLighting(node: child)
        }
    }
    
    /// Supprime le modèle 3D du visage
    func clearFaceModel() {
        faceModelNode?.removeFromParentNode()
        faceModelNode = nil
        faceModelPath = nil
        print("[FaceArManager] Face model cleared")
    }
    
    // MARK: - Face Region Nodes
    
    /// Ajoute un nœud à une région du visage
    func addFaceNode(args: [String: Any], result: @escaping FlutterResult) {
        guard let name = args["name"] as? String,
              let region = args["region"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "name and region required", details: nil))
            return
        }
        
        print("[FaceArManager] Adding node '\(name)' at region '\(region)'")
        
        let node = SCNNode()
        node.name = name
        
        // Position locale
        if let position = args["position"] as? [String: Double] {
            node.position = SCNVector3(
                Float(position["x"] ?? 0),
                Float(position["y"] ?? 0),
                Float(position["z"] ?? 0)
            )
        }
        
        // Rotation (degrés -> radians)
        if let rotation = args["rotation"] as? [String: Double] {
            node.eulerAngles = SCNVector3(
                Float(rotation["x"] ?? 0) * .pi / 180,
                Float(rotation["y"] ?? 0) * .pi / 180,
                Float(rotation["z"] ?? 0) * .pi / 180
            )
        }
        
        // Scale
        if let scale = args["scale"] as? [String: Double] {
            node.scale = SCNVector3(
                Float(scale["x"] ?? 1),
                Float(scale["y"] ?? 1),
                Float(scale["z"] ?? 1)
            )
        } else if let uniformScale = args["scale"] as? Double {
            node.scale = SCNVector3(Float(uniformScale), Float(uniformScale), Float(uniformScale))
        }
        
        // Charger le modèle ou créer une géométrie
        if let modelPath = args["modelPath"] as? String {
            if let modelURL = getFlutterAssetURL(modelPath) {
                if let modelNode = loadGLTFModel(url: modelURL, name: name + "_model") {
                    node.addChildNode(modelNode)
                }
            }
        } else if let geometryParams = args["geometry"] as? [String: Any] {
            node.geometry = createGeometry(params: geometryParams)
        }
        
        // Stocker la référence
        regionNodes[name] = (node: node, region: region)
        
        // Ajouter au visage si détecté
        if let faceNode = faceNode {
            faceNode.addChildNode(node)
        }
        
        result(["success": true, "name": name])
    }
    
    /// Supprime un nœud du visage
    func removeFaceNode(name: String) {
        guard let nodeInfo = regionNodes[name] else {
            print("[FaceArManager] Node not found: \(name)")
            return
        }
        
        nodeInfo.node.removeFromParentNode()
        regionNodes.removeValue(forKey: name)
        print("[FaceArManager] Node removed: \(name)")
    }
    
    // MARK: - Flutter Notifications
    
    private func notifyFacePose(anchor: ARFaceAnchor) {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastPoseUpdateTime > poseUpdateInterval else { return }
        lastPoseUpdateTime = currentTime
        
        let transform = anchor.transform
        
        let poseData: [String: Any] = [
            "position": [
                "x": Double(transform.columns.3.x),
                "y": Double(transform.columns.3.y),
                "z": Double(transform.columns.3.z)
            ],
            "rotation": [
                "x": Double(simd_quatf(transform).vector.x),
                "y": Double(simd_quatf(transform).vector.y),
                "z": Double(simd_quatf(transform).vector.z),
                "w": Double(simd_quatf(transform).vector.w)
            ]
        ]
        
        DispatchQueue.main.async {
            self.anchorManagerChannel?.invokeMethod("onFacePoseUpdate", arguments: poseData)
        }
    }
    
    /// Retourne les blend shapes actuels
    func getBlendShapes() -> [String: Double]? {
        guard let blendShapes = currentBlendShapes else { return nil }
        
        var data: [String: Double] = [:]
        for (key, value) in blendShapes {
            data[key.rawValue] = value.doubleValue
        }
        return data
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        faceMeshNode?.removeFromParentNode()
        faceMeshNode = nil
        faceGeometry = nil
        
        faceModelNode?.removeFromParentNode()
        faceModelNode = nil
        
        for (_, info) in regionNodes {
            info.node.removeFromParentNode()
        }
        regionNodes.removeAll()
        
        // Supprimer les lumières ajoutées
        sceneView?.scene.rootNode.childNode(withName: "faceAR_ambientLight", recursively: false)?.removeFromParentNode()
        sceneView?.scene.rootNode.childNode(withName: "faceAR_directionalLight", recursively: false)?.removeFromParentNode()
        
        faceNode = nil
        isFaceDetected = false
        makeupTexture = nil
        
        print("[FaceArManager] Cleaned up")
    }
    
    // MARK: - Utility Methods
    
    private func colorFromARGB(_ argb: Int) -> UIColor {
        let alpha = CGFloat((argb >> 24) & 0xFF) / 255.0
        let red = CGFloat((argb >> 16) & 0xFF) / 255.0
        let green = CGFloat((argb >> 8) & 0xFF) / 255.0
        let blue = CGFloat(argb & 0xFF) / 255.0
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    private func loadImageFromFlutterAssets(_ assetPath: String) -> UIImage? {
        let key = FlutterDartProject.lookupKey(forAsset: assetPath)
        
        if let image = UIImage(named: key, in: Bundle.main, compatibleWith: nil) {
            return image
        }
        
        if let path = Bundle.main.path(forResource: key, ofType: nil) {
            return UIImage(contentsOfFile: path)
        }
        
        // Essayer directement
        if let path = Bundle.main.path(forResource: assetPath, ofType: nil) {
            return UIImage(contentsOfFile: path)
        }
        
        return nil
    }
    
    private func getFlutterAssetURL(_ assetPath: String) -> URL? {
        let key = FlutterDartProject.lookupKey(forAsset: assetPath)
        
        if let path = Bundle.main.path(forResource: key, ofType: nil) {
            return URL(fileURLWithPath: path)
        }
        
        if let path = Bundle.main.path(forResource: assetPath, ofType: nil) {
            return URL(fileURLWithPath: path)
        }
        
        return nil
    }
    
    private func createGeometry(params: [String: Any]) -> SCNGeometry? {
        guard let type = params["type"] as? String else { return nil }
        
        var geometry: SCNGeometry?
        
        switch type {
        case "sphere":
            let radius = params["radius"] as? Double ?? 0.01
            geometry = SCNSphere(radius: CGFloat(radius))
            
        case "box":
            let width = params["width"] as? Double ?? 0.01
            let height = params["height"] as? Double ?? 0.01
            let length = params["length"] as? Double ?? 0.01
            geometry = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(length), chamferRadius: 0)
            
        case "cylinder":
            let radius = params["radius"] as? Double ?? 0.005
            let height = params["height"] as? Double ?? 0.01
            geometry = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
            
        case "plane":
            let width = params["width"] as? Double ?? 0.01
            let height = params["height"] as? Double ?? 0.01
            geometry = SCNPlane(width: CGFloat(width), height: CGFloat(height))
            
        default:
            return nil
        }
        
        // Couleur
        if let colorValue = params["color"] as? Int {
            let material = SCNMaterial()
            material.diffuse.contents = colorFromARGB(colorValue)
            geometry?.materials = [material]
        }
        
        return geometry
    }
    
    // MARK: - Public Getters
    
    var isDetectingFace: Bool { return isFaceDetected }
    var blendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]? { return currentBlendShapes }
}