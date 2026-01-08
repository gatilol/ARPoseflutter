import Flutter
import UIKit
import Foundation
import ARKit
import Combine
import ARCoreCloudAnchors

class IosARView: NSObject, FlutterPlatformView, ARSCNViewDelegate, UIGestureRecognizerDelegate, ARSessionDelegate {
    let sceneView: ARSCNView
    let coachingView: ARCoachingOverlayView
    let sessionManagerChannel: FlutterMethodChannel
    let objectManagerChannel: FlutterMethodChannel
    let anchorManagerChannel: FlutterMethodChannel
    var showPlanes = false
    var planeCount = 0
    var customPlaneTexturePath: String? = nil
    private var trackedPlanes = [UUID: (SCNNode, SCNNode)]()
    let modelBuilder = ArModelBuilder()
    
    var cancellableCollection = Set<AnyCancellable>() //Used to store all cancellables in (needed for working with Futures)
    var anchorCollection = [String: ARAnchor]() //Used to bookkeep all anchors created by Flutter calls
    
    private var cloudAnchorHandler: CloudAnchorHandler? = nil
    private var arcoreSession: GARSession? = nil
    private var arcoreMode: Bool = false
    private var configuration: ARWorldTrackingConfiguration!
    private var tappedPlaneAnchorAlignment = ARPlaneAnchor.Alignment.horizontal // default alignment
    
    private var panStartLocation: CGPoint?
    private var panCurrentLocation: CGPoint?
    private var panCurrentVelocity: CGPoint?
    private var panCurrentTranslation: CGPoint?
    private var rotationStartLocation: CGPoint?
    private var rotation: CGFloat?
    private var rotationVelocity: CGFloat?
    private var panningNode: SCNNode?
    private var panningNodeCurrentWorldLocation: SCNVector3?

    // MARK: - Face AR Properties
    var faceArManager: FaceArManager?
    var currentArMode: String = "world"

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        NSLog("[IosARView] init called with frame: \(frame)")
        
        self.sceneView = ARSCNView(frame: frame)
        self.coachingView = ARCoachingOverlayView(frame: frame)
        
        self.sessionManagerChannel = FlutterMethodChannel(name: "arsession_\(viewId)", binaryMessenger: messenger)
        self.objectManagerChannel = FlutterMethodChannel(name: "arobjects_\(viewId)", binaryMessenger: messenger)
        self.anchorManagerChannel = FlutterMethodChannel(name: "aranchors_\(viewId)", binaryMessenger: messenger)
        super.init()

        // IMPORTANT: Configure view to resize with parent
        self.sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.sceneView.backgroundColor = .black
        
        // Check ARKit support
        guard ARWorldTrackingConfiguration.isSupported else {
            NSLog("[IosARView] ERROR: ARWorldTrackingConfiguration not supported!")
            return
        }
        
        // FIX: Ne configurer que les delegates ici
        // La session sera démarrée dans initializeARView() (comme Android)
        self.sceneView.delegate = self
        self.coachingView.delegate = self
        self.sceneView.session.delegate = self
        
        NSLog("[IosARView] Delegates configured, waiting for initializeARView()")

        self.sessionManagerChannel.setMethodCallHandler(self.onSessionMethodCalled)
        self.objectManagerChannel.setMethodCallHandler(self.onObjectMethodCalled)
        self.anchorManagerChannel.setMethodCallHandler(self.onAnchorMethodCalled)
        
        NSLog("[IosARView] init completed")
    }

    func view() -> UIView {
        NSLog("[IosARView] view() called - returning sceneView with frame: \(sceneView.frame)")
        return self.sceneView
    }

    func onDispose(_ result:FlutterResult) {
        sceneView.session.pause()
        faceArManager?.cleanup()
        faceArManager = nil
        self.sessionManagerChannel.setMethodCallHandler(nil)
        self.objectManagerChannel.setMethodCallHandler(nil)
        self.anchorManagerChannel.setMethodCallHandler(nil)
        result(nil)
    }

    // MARK: - Session Method Handler
    
    func onSessionMethodCalled(_ call :FlutterMethodCall, _ result:FlutterResult) {
        let arguments = call.arguments as? Dictionary<String, Any>

        switch call.method {
            case "init":
                if let args = arguments {
                    initializeARView(arguments: args, result: result)
                } else {
                    initializeARView(arguments: [:], result: result)
                }
                break
            case "getCameraPose":
                if let cameraPose = sceneView.session.currentFrame?.camera.transform {
                    result(serializeMatrix(cameraPose))
                } else {
                    result(FlutterError())
                }
                break
            case "getAnchorPose":
                if let cameraPose = anchorCollection[arguments?["anchorId"] as! String]?.transform {
                    result(serializeMatrix(cameraPose))
                } else {
                    result(FlutterError())
                }
                break
            case "snapshot":
                let snapshotImage = sceneView.snapshot()
                if let bytes = snapshotImage.pngData() {
                    let data = FlutterStandardTypedData(bytes:bytes)
                    result(data)
                } else {
                    result(nil)
                }
            case "dispose":
                onDispose(result)
                result(nil)
                break
            case "showPlanes":
                if let showPlanesArgument = arguments?["showPlanes"] as? Bool {
                    showPlanes = showPlanesArgument
                } else {
                    showPlanes = false
                }
                if (showPlanes){
                    for plane in trackedPlanes.values {
                        plane.0.addChildNode(plane.1)
                    }
                } else {
                    for plane in trackedPlanes.values {
                        plane.1.removeFromParentNode()
                    }
                }
                result(nil)
                break
            
            // MARK: - Face AR Session Methods
            case "switchToFaceAR":
                switchToFaceAR(result: result)
                break
            case "switchToWorldAR":
                switchToWorldAR(result: result)
                break
            case "isFaceARSupported":
                result(ARFaceTrackingConfiguration.isSupported)
                break
            case "getCurrentMode":
                result(["mode": currentArMode])
                break
            
            // MARK: - Face AR Model Methods
            case "setFaceModel":
                if let modelPath = arguments?["modelPath"] as? String {
                    faceArManager?.loadFaceModel(assetPath: modelPath)
                    result(["success": true])
                } else {
                    result(["success": false, "error": "modelPath required"])
                }
                break
            case "clearFaceModel":
                faceArManager?.clearFaceModel()
                result(["success": true])
                break
            case "setFaceMakeupTexture":
                if let texturePath = arguments?["texturePath"] as? String {
                    faceArManager?.setMakeupTexture(assetPath: texturePath)
                    result(["success": true])
                } else {
                    result(["success": false, "error": "texturePath required"])
                }
                break
            case "clearFaceMakeupTexture":
                faceArManager?.clearMakeupTexture()
                result(["success": true])
                break
            case "setFaceFilterColor":
                if let r = arguments?["r"] as? Double,
                   let g = arguments?["g"] as? Double,
                   let b = arguments?["b"] as? Double,
                   let a = arguments?["a"] as? Double {
                    let color = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
                    faceArManager?.setFaceMeshColor(color)
                    result(["success": true])
                } else {
                    result(["success": false, "error": "r, g, b, a required"])
                }
                break
            case "setFaceFilterVisible":
                if let visible = arguments?["visible"] as? Bool {
                    faceArManager?.setFaceMeshVisible(visible)
                    result(["success": true])
                } else {
                    result(["success": false, "error": "visible required"])
                }
                break
                
            default:
                result(FlutterMethodNotImplemented)
                break
        }
    }

    // MARK: - Object Method Handler
    
    func onObjectMethodCalled(_ call :FlutterMethodCall, _ result: @escaping FlutterResult) {
        let arguments = call.arguments as? Dictionary<String, Any>
          
        switch call.method {
            case "init":
                DispatchQueue.main.async {self.objectManagerChannel.invokeMethod("onError", arguments: ["ObjectTEST from iOS"])}
                result(nil)
                break
            case "addNode":
                addNode(dict_node: arguments!).sink(receiveCompletion: {completion in }, receiveValue: { val in
                       result(val)
                    }).store(in: &self.cancellableCollection)
                break
            case "addNodeToPlaneAnchor":
                if let dict_node = arguments!["node"] as? Dictionary<String, Any>, let dict_anchor = arguments!["anchor"] as? Dictionary<String, Any> {
                    addNode(dict_node: dict_node, dict_anchor: dict_anchor).sink(receiveCompletion: {completion in }, receiveValue: { val in
                           result(val)
                        }).store(in: &self.cancellableCollection)
                }
                break
            case "removeNode":
                if let name = arguments!["name"] as? String {
                    sceneView.scene.rootNode.childNode(withName: name, recursively: true)?.removeFromParentNode()
                }
                break
            case "transformationChanged":
                if let name = arguments!["name"] as? String, let transform = arguments!["transformation"] as? Array<NSNumber> {
                    transformNode(name: name, transform: transform)
                    result(nil)
                }
                break
            default:
                result(FlutterMethodNotImplemented)
                break
        }
    }

    // MARK: - Anchor Method Handler
    
    func onAnchorMethodCalled(_ call :FlutterMethodCall, _ result: @escaping FlutterResult) {
        let arguments = call.arguments as? Dictionary<String, Any>
          
        switch call.method {
            case "init":
                DispatchQueue.main.async {self.objectManagerChannel.invokeMethod("onError", arguments: ["ObjectTEST from iOS"])}
                result(nil)
                break
            case "addAnchor":
                if let type = arguments!["type"] as? Int {
                    switch type {
                    case 0: //Plane Anchor
                        if let transform = arguments!["transformation"] as? Array<NSNumber>, let name = arguments!["name"] as? String {
                            addPlaneAnchor(transform: transform, name: name)
                            result(true)
                        }
                        result(false)
                        break
                    default:
                        result(false)
                    }
                }
                result(nil)
                break
            case "removeAnchor":
                if let name = arguments!["name"] as? String {
                    deleteAnchor(anchorName: name)
                }
                break
            case "initGoogleCloudAnchorMode":
                arcoreSession = try! GARSession.session()

                if (arcoreSession != nil){
                    let configuration = GARSessionConfiguration();
                    configuration.cloudAnchorMode = .enabled;
                    arcoreSession?.setConfiguration(configuration, error: nil);
                    if let token = JWTGenerator().generateWebToken(){
                        arcoreSession!.setAuthToken(token)
                        
                        cloudAnchorHandler = CloudAnchorHandler(session: arcoreSession!)
                        arcoreSession!.delegate = cloudAnchorHandler
                        arcoreSession!.delegateQueue = DispatchQueue.main
                        
                        arcoreMode = true
                    } else {
                        DispatchQueue.main.async {self.sessionManagerChannel.invokeMethod("onError", arguments: ["Error generating JWT, have you added cloudAnchorKey.json into the ios/Runner directory ?"])}
                    }
                } else {
                    DispatchQueue.main.async {self.sessionManagerChannel.invokeMethod("onError", arguments: ["Error initializing Google AR Session"])}
                }
                    
                break
            case "uploadAnchor":
                if let anchorName = arguments!["name"] as? String, let anchor = anchorCollection[anchorName] {
                    print("---------------- HOSTING INITIATED ------------------")
                    if let ttl = arguments!["ttl"] as? Int {
                        cloudAnchorHandler?.hostCloudAnchorWithTtl(anchorName: anchorName, anchor: anchor, listener: cloudAnchorUploadedListener(parent: self), ttl: ttl)
                    } else {
                        cloudAnchorHandler?.hostCloudAnchor(anchorName: anchorName, anchor: anchor, listener: cloudAnchorUploadedListener(parent: self))
                    }
                }
                result(true)
                break
            case "downloadAnchor":
                if let anchorId = arguments!["cloudanchorid"] as? String {
                    print("---------------- RESOLVING INITIATED ------------------")
                    cloudAnchorHandler?.resolveCloudAnchor(anchorId: anchorId, listener: cloudAnchorDownloadedListener(parent: self))
                }
                break
                
            default:
                result(FlutterMethodNotImplemented)
                break
        }
    }

    // MARK: - AR View Initialization

    func initializeARView(arguments: Dictionary<String,Any>, result: FlutterResult){
        NSLog("[IosARView] initializeARView called with arguments: \(arguments)")
        
        // Set plane detection configuration
        self.configuration = ARWorldTrackingConfiguration()
        self.configuration.environmentTexturing = .automatic
        if let planeDetectionConfig = arguments["planeDetectionConfig"] as? Int {
            switch planeDetectionConfig {
                case 1: 
                    configuration.planeDetection = .horizontal
                case 2: 
                    if #available(iOS 11.3, *) {
                        configuration.planeDetection = .vertical
                    }
                case 3: 
                    if #available(iOS 11.3, *) {
                        configuration.planeDetection = [.horizontal, .vertical]
                    }
                default: 
                    configuration.planeDetection = []
            }
        }

        // Set plane rendering options
        if let configShowPlanes = arguments["showPlanes"] as? Bool {
            showPlanes = configShowPlanes
            if (showPlanes){
                for plane in trackedPlanes.values {
                    plane.0.addChildNode(plane.1)
                }
            } else {
                for plane in trackedPlanes.values {
                    plane.1.removeFromParentNode()
                }
            }
        }
        if let configCustomPlaneTexturePath = arguments["customPlaneTexturePath"] as? String {
            customPlaneTexturePath = configCustomPlaneTexturePath
        }

        // Set debug options
        var debugOptions = ARSCNDebugOptions().rawValue
        if let showFeaturePoints = arguments["showFeaturePoints"] as? Bool {
            if (showFeaturePoints) {
                debugOptions |= ARSCNDebugOptions.showFeaturePoints.rawValue
            }
        }
        if let showWorldOrigin = arguments["showWorldOrigin"] as? Bool {
            if (showWorldOrigin) {
                debugOptions |= ARSCNDebugOptions.showWorldOrigin.rawValue
            }
        }
        self.sceneView.debugOptions = ARSCNDebugOptions(rawValue: debugOptions)
        
        if let configHandleTaps = arguments["handleTaps"] as? Bool {
            if (configHandleTaps){
                let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                tapGestureRecognizer.delegate = self
                self.sceneView.gestureRecognizers?.append(tapGestureRecognizer)
            }
        }

        if let configHandlePans = arguments["handlePans"] as? Bool {
            if (configHandlePans){
                let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                panGestureRecognizer.maximumNumberOfTouches = 1
                panGestureRecognizer.delegate = self
                self.sceneView.gestureRecognizers?.append(panGestureRecognizer)
            }
        }
        
        if let configHandleRotation = arguments["handleRotation"] as? Bool {
            if (configHandleRotation){
                let rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
                rotationGestureRecognizer.delegate = self
                self.sceneView.gestureRecognizers?.append(rotationGestureRecognizer)
            }
        }
        
        // Add coaching view
        if let configShowAnimatedGuide = arguments["showAnimatedGuide"] as? Bool {
            if configShowAnimatedGuide {
                if self.sceneView.superview != nil && self.coachingView.superview == nil {
                    self.sceneView.addSubview(self.coachingView)
                    self.coachingView.autoresizingMask = [
                          .flexibleWidth, .flexibleHeight
                        ]
                    self.coachingView.session = self.sceneView.session
                    self.coachingView.activatesAutomatically = true
                    if configuration.planeDetection == .horizontal {
                        self.coachingView.goal = .horizontalPlane
                    }else{
                        self.coachingView.goal = .verticalPlane
                    }
                }
            }
        }
    
        // FIX: Démarrer la session UNE SEULE FOIS ici (comme Android)
        self.sceneView.session.run(configuration)
        currentArMode = "world"
        
        NSLog("[IosARView] initializeARView completed - session running, frame: \(self.sceneView.frame)")
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        // Face AR handling
        if let faceAnchor = anchor as? ARFaceAnchor {
            faceArManager?.didAddFaceAnchor(faceAnchor, node: node)
            return
        }
        
        if let planeAnchor = anchor as? ARPlaneAnchor{
            let plane = modelBuilder.makePlane(anchor: planeAnchor, flutterAssetFile: customPlaneTexturePath)
            trackedPlanes[anchor.identifier] = (node, plane)
            planeCount += 1
            DispatchQueue.main.async {self.sessionManagerChannel.invokeMethod("onPlaneDetected", arguments: self.planeCount)}
            if (showPlanes) {
                node.addChildNode(plane)
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        // Face AR handling
        if let faceAnchor = anchor as? ARFaceAnchor {
            faceArManager?.didUpdateFaceAnchor(faceAnchor, node: node)
            return
        }
        
        if let planeAnchor = anchor as? ARPlaneAnchor, let plane = trackedPlanes[anchor.identifier] {
            modelBuilder.updatePlaneNode(planeNode: plane.1, anchor: planeAnchor)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        // Face AR handling
        if let faceAnchor = anchor as? ARFaceAnchor {
            faceArManager?.didRemoveFaceAnchor(faceAnchor, node: node)
            return
        }
        
        trackedPlanes.removeValue(forKey: anchor.identifier)
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if (arcoreMode) {
            do {
                try arcoreSession!.update(frame)
            } catch {
                print(error)
            }
        }
    }
    
    // MARK: - ARSession Error Handling
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        NSLog("[IosARView] AR Session failed with error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.sessionManagerChannel.invokeMethod("onError", arguments: ["AR Session error: \(error.localizedDescription)"])
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        NSLog("[IosARView] Camera tracking state changed: \(camera.trackingState)")
        switch camera.trackingState {
        case .notAvailable:
            NSLog("[IosARView] Tracking not available")
        case .limited(let reason):
            NSLog("[IosARView] Tracking limited: \(reason)")
        case .normal:
            NSLog("[IosARView] Tracking normal")
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        NSLog("[IosARView] Session was interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        NSLog("[IosARView] Session interruption ended")
    }

    // MARK: - Node Management
    
    func addNode(dict_node: Dictionary<String, Any>, dict_anchor: Dictionary<String, Any>? = nil) -> Future<Bool, Never> {

        return Future {promise in
            
            switch (dict_node["type"] as! Int) {
                case 0: // GLTF2 Model from Flutter asset folder
                    let key = FlutterDartProject.lookupKey(forAsset: dict_node["uri"] as! String)
                    if let node: SCNNode = self.modelBuilder.makeNodeFromGltf(name: dict_node["name"] as! String, modelPath: key, transformation: dict_node["transformation"] as? Array<NSNumber>) {
                        if let anchorName = dict_anchor?["name"] as? String, let anchorType = dict_anchor?["type"] as? Int {
                            switch anchorType{
                                case 0: //PlaneAnchor
                                    if let anchor = self.anchorCollection[anchorName]{
                                        self.sceneView.node(for: anchor)?.addChildNode(node)
                                        promise(.success(true))
                                    } else {
                                        promise(.success(false))
                                    }
                                default:
                                    promise(.success(false))
                                }
                            
                        } else {
                            self.sceneView.scene.rootNode.addChildNode(node)
                            promise(.success(true))
                        }
                        promise(.success(false))
                    } else {
                        DispatchQueue.main.async {self.sessionManagerChannel.invokeMethod("onError", arguments: ["Unable to load renderable \(dict_node["uri"] as! String)"])}
                        promise(.success(false))
                    }
                    break
                case 1: // GLB Model from the web
                    self.modelBuilder.makeNodeFromWebGlb(name: dict_node["name"] as! String, modelURL: dict_node["uri"] as! String, transformation: dict_node["transformation"] as? Array<NSNumber>)
                    .sink(receiveCompletion: {
                                    completion in print("Async Model Downloading Task completed: ", completion)
                    }, receiveValue: { val in
                        if let node: SCNNode = val {
                            if let anchorName = dict_anchor?["name"] as? String, let anchorType = dict_anchor?["type"] as? Int {
                                switch anchorType{
                                    case 0: //PlaneAnchor
                                        if let anchor = self.anchorCollection[anchorName]{
                                            self.sceneView.node(for: anchor)?.addChildNode(node)
                                            promise(.success(true))
                                        } else {
                                            promise(.success(false))
                                        }
                                    default:
                                        promise(.success(false))
                                    }
                                
                            } else {
                                self.sceneView.scene.rootNode.addChildNode(node)
                                promise(.success(true))
                            }
                            promise(.success(false))
                        } else {
                            DispatchQueue.main.async {self.sessionManagerChannel.invokeMethod("onError", arguments: ["Unable to load renderable \(dict_node["name"] as! String)"])}
                            promise(.success(false))
                        }
                    }).store(in: &self.cancellableCollection)
                    break
                case 2: // GLB Model from the app's documents folder
                    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                    let documentsDirectory = paths[0]
                    let targetPath = documentsDirectory.appendingPathComponent(dict_node["uri"] as! String).path

                    if let node: SCNNode = self.modelBuilder.makeNodeFromFileSystemGLB(name: dict_node["name"] as! String, modelPath: targetPath, transformation: dict_node["transformation"] as? Array<NSNumber>) {
                        if let anchorName = dict_anchor?["name"] as? String, let anchorType = dict_anchor?["type"] as? Int {
                            switch anchorType{
                                case 0: //PlaneAnchor
                                    if let anchor = self.anchorCollection[anchorName]{
                                        self.sceneView.node(for: anchor)?.addChildNode(node)
                                        promise(.success(true))
                                    } else {
                                        promise(.success(false))
                                    }
                                default:
                                    promise(.success(false))
                                }
                            
                        } else {
                            self.sceneView.scene.rootNode.addChildNode(node)
                            promise(.success(true))
                        }
                        promise(.success(false))
                    } else {
                        DispatchQueue.main.async {self.sessionManagerChannel.invokeMethod("onError", arguments: ["Unable to load renderable \(dict_node["uri"] as! String)"])}
                        promise(.success(false))
                    }
                    break
                case 3: //fileSystemAppFolderGLTF2
                    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                    let documentsDirectory = paths[0]
                    let targetPath = documentsDirectory.appendingPathComponent(dict_node["uri"] as! String).path

                    if let node: SCNNode = self.modelBuilder.makeNodeFromFileSystemGltf(name: dict_node["name"] as! String, modelPath: targetPath, transformation: dict_node["transformation"] as? Array<NSNumber>) {
                        if let anchorName = dict_anchor?["name"] as? String, let anchorType = dict_anchor?["type"] as? Int {
                            switch anchorType{
                                case 0: //PlaneAnchor
                                    if let anchor = self.anchorCollection[anchorName]{
                                        self.sceneView.node(for: anchor)?.addChildNode(node)
                                        promise(.success(true))
                                    } else {
                                        promise(.success(false))
                                    }
                                default:
                                    promise(.success(false))
                                }
                            
                        } else {
                            self.sceneView.scene.rootNode.addChildNode(node)
                            promise(.success(true))
                        }
                        promise(.success(false))
                    } else {
                        DispatchQueue.main.async {self.sessionManagerChannel.invokeMethod("onError", arguments: ["Unable to load renderable \(dict_node["uri"] as! String)"])}
                        promise(.success(false))
                    }
                    break
                default:
                    promise(.success(false))
            }
            
        }
    }
    
    func transformNode(name: String, transform: Array<NSNumber>) {
        let node = sceneView.scene.rootNode.childNode(withName: name, recursively: true)
        node?.transform = deserializeMatrix4(transform)
    }
    
    // MARK: - Gesture Handlers
    
    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let sceneView = recognizer.view as? ARSCNView else {
            return
        }
        
        // FIX: Vérifier que le tracking est stable avant d'accepter le tap (comme Android)
        // Android vérifie: trackable.trackingState == TrackingState.TRACKING
        guard let frame = sceneView.session.currentFrame else {
            NSLog("[IosARView] Tap ignored - no current frame")
            return
        }
        
        guard frame.camera.trackingState == .normal else {
            NSLog("[IosARView] Tap ignored - tracking not ready (state: \(frame.camera.trackingState))")
            return
        }
        
        let touchLocation = recognizer.location(in: sceneView)
    
        let allHitResults = sceneView.hitTest(touchLocation, options: [SCNHitTestOption.searchMode : SCNHitTestSearchMode.closest.rawValue])
        let nodeHitResults: Array<String> = allHitResults.compactMap { nearestParentWithNameStart(node: $0.node, characters: "[#")?.name }
        if (nodeHitResults.count != 0) {
            DispatchQueue.main.async {self.objectManagerChannel.invokeMethod("onNodeTap", arguments: Array(Set(nodeHitResults)))}
            return
        }
            
        let planeTypes: ARHitTestResult.ResultType
        if #available(iOS 11.3, *){
            planeTypes = ARHitTestResult.ResultType([.existingPlaneUsingGeometry, .featurePoint])
        }else {
            planeTypes = ARHitTestResult.ResultType([.existingPlaneUsingExtent, .featurePoint])
        }
        
        let planeAndPointHitResults = sceneView.hitTest(touchLocation, types: planeTypes)
        
        // Store the alignment of the tapped plane anchor
        if planeAndPointHitResults.count > 0, let hitAnchor = planeAndPointHitResults.first?.anchor as? ARPlaneAnchor {
            self.tappedPlaneAnchorAlignment = hitAnchor.alignment
        }
        
        // FIX: Corriger la rotation pour qu'elle soit face à la caméra (comme Android)
        // Android envoie une rotation identity: floatArrayOf(0f, 0f, 0f, 1f)
        let serializedPlaneAndPointHitResults = planeAndPointHitResults.map { hitResult -> Dictionary<String, Any> in
            var serialized = serializeHitResult(hitResult)
            
            // Corriger la rotation pour les plans
            if hitResult.type == .existingPlaneUsingGeometry ||
               hitResult.type == .existingPlaneUsingExtent {
                
                if let camera = sceneView.session.currentFrame?.camera {
                    let correctedTransform = self.createCameraAlignedTransform(
                        hitTransform: hitResult.worldTransform,
                        cameraTransform: camera.transform
                    )
                    serialized["worldTransform"] = serializeMatrix(correctedTransform)
                }
            }
            
            return serialized
        }
            
        if (serializedPlaneAndPointHitResults.count != 0) {
            DispatchQueue.main.async {self.sessionManagerChannel.invokeMethod("onPlaneOrPointTap", arguments: serializedPlaneAndPointHitResults)}
        }
    }
    
    // MARK: - Transform Correction for Reticle (comme Android)
    
    /// Crée une transformation avec la position du hit mais rotation face à la caméra
    /// Cela reproduit le comportement Android qui envoie une rotation identity
    private func createCameraAlignedTransform(hitTransform: simd_float4x4, cameraTransform: simd_float4x4) -> simd_float4x4 {
        // Extraire la position du hit (on garde ça)
        let hitPosition = hitTransform.columns.3
        
        // Calculer la direction de la caméra projetée sur le plan horizontal (Y=0)
        let cameraForward = simd_float3(
            -cameraTransform.columns.2.x,
            0,  // On ignore la composante Y pour rester sur le plan horizontal
            -cameraTransform.columns.2.z
        )
        
        // Normaliser (éviter division par zéro si caméra regarde droit vers le bas)
        let forwardLength = simd_length(cameraForward)
        let forward: simd_float3
        if forwardLength > 0.001 {
            forward = cameraForward / forwardLength
        } else {
            // Fallback: utiliser la direction X de la caméra
            forward = simd_normalize(simd_float3(cameraTransform.columns.0.x, 0, cameraTransform.columns.0.z))
        }
        
        // Construire une base orthonormale (right, up, forward)
        let up = simd_float3(0, 1, 0)
        let right = simd_normalize(simd_cross(up, forward))
        let correctedForward = simd_cross(right, up)  // Recalculer pour être sûr de l'orthogonalité
        
        // Construire la nouvelle matrice de transformation
        var result = simd_float4x4(1.0)  // Identity
        result.columns.0 = simd_float4(right.x, right.y, right.z, 0)
        result.columns.1 = simd_float4(up.x, up.y, up.z, 0)
        result.columns.2 = simd_float4(-correctedForward.x, -correctedForward.y, -correctedForward.z, 0)  // -forward car Z- est "devant"
        result.columns.3 = hitPosition  // Garder la position originale
        
        return result
    }

    @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let sceneView = recognizer.view as? ARSCNView else {
            return
        }

        // State Begins
        if recognizer.state == UIGestureRecognizer.State.began
        {
            panStartLocation = recognizer.location(in: sceneView)
            if let startLocation = panStartLocation {
                let allHitResults = sceneView.hitTest(startLocation, options: [SCNHitTestOption.searchMode : SCNHitTestSearchMode.closest.rawValue])
                let nodeHitResults: Array<String> = allHitResults.compactMap {
                    if let nearestNode = nearestParentWithNameStart(node: $0.node, characters: "[#") {
                        panningNode = nearestNode
                        return nearestNode.name
                    }else{
                        return nil
                    }
                }
                if (nodeHitResults.count != 0 && panningNode != nil) {
                    panningNodeCurrentWorldLocation = panningNode!.worldPosition
                    DispatchQueue.main.async {self.objectManagerChannel.invokeMethod("onPanStart", arguments: self.panningNode!.name)}
                    return
                }
            }
        }
        // State Changes
        if(recognizer.state == UIGestureRecognizer.State.changed)
        {
            panCurrentVelocity = recognizer.velocity(in: sceneView)
            panCurrentLocation = recognizer.location(in: sceneView)
            panCurrentTranslation = recognizer.translation(in: sceneView)

            if let panLoc = panCurrentLocation, let panNode = panningNode {
                if let query = sceneView.raycastQuery(from: panLoc, allowing: .estimatedPlane, alignment: .any) {
                    guard let result = self.sceneView.session.raycast(query).first else {
                        return
                    }
                    let posX = result.worldTransform.columns.3.x
                    let posY = result.worldTransform.columns.3.y
                    let posZ = result.worldTransform.columns.3.z
                    panNode.worldPosition = SCNVector3(posX, posY, posZ)
                }
                DispatchQueue.main.async {self.objectManagerChannel.invokeMethod("onPanChange", arguments: panNode.name)}
            }
        }
        // State Ended
        if(recognizer.state == UIGestureRecognizer.State.ended)
        {
            panStartLocation = nil
            panCurrentLocation = nil
            DispatchQueue.main.async {self.objectManagerChannel.invokeMethod("onPanEnd", arguments: serializeLocalTransformation(node: self.panningNode))}
            panningNode = nil
        }
    }
    
    @objc func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        guard let sceneView = recognizer.view as? ARSCNView else {
            return
        }

        // State Begins
        if recognizer.state == UIGestureRecognizer.State.began
        {
            rotationStartLocation = recognizer.location(in: sceneView)
            if let startLocation = rotationStartLocation {
                let allHitResults = sceneView.hitTest(startLocation, options: [SCNHitTestOption.searchMode : SCNHitTestSearchMode.closest.rawValue])
                let nodeHitResults: Array<String> = allHitResults.compactMap {
                    if let nearestNode = nearestParentWithNameStart(node: $0.node, characters: "[#") {
                        panningNode = nearestNode
                        return nearestNode.name
                    }else{
                        return nil
                    }
                }
                if (nodeHitResults.count != 0 && panningNode != nil) {
                    DispatchQueue.main.async {self.objectManagerChannel.invokeMethod("onRotationStart", arguments: self.panningNode!.name)}
                    return
                }
            }
        }
        // State Changes
        if(recognizer.state == UIGestureRecognizer.State.changed)
        {
            rotation = recognizer.rotation
            rotationVelocity = recognizer.velocity

            if let r = rotationVelocity, let panNode = panningNode {
                let r2 = (r*0.01) * -1
                let nodeRotation = panNode.rotation
                let rotation: SCNQuaternion!
                let planeAlignment = self.tappedPlaneAnchorAlignment
                if planeAlignment == .horizontal {
                    rotation = SCNQuaternion(x: 0, y: 1, z: 0, w: nodeRotation.w+Float(r2))
                }else{
                    rotation = SCNQuaternion(x: 0, y: 0, z: 1, w: nodeRotation.w+Float(r2))
                }
                panNode.rotation = rotation
                DispatchQueue.main.async {self.objectManagerChannel.invokeMethod("onRotationChange", arguments: panNode.name)}
            }
        }
        // State Ended
        if(recognizer.state == UIGestureRecognizer.State.ended)
        {
            rotation = nil
            rotationVelocity = nil
            DispatchQueue.main.async {self.objectManagerChannel.invokeMethod("onRotationEnd", arguments: serializeLocalTransformation(node: self.panningNode))}
            panningNode = nil
        }
    }

    // MARK: - Helper Functions
    
    func nearestParentWithNameStart(node: SCNNode?, characters: String) -> SCNNode? {
        if let nodeNamePrefix = node?.name?.prefix(characters.count) {
            if (nodeNamePrefix == characters) { return node }
        }
        if let parent = node?.parent { return nearestParentWithNameStart(node: parent, characters: characters) }
        return nil
    }
    
    func addPlaneAnchor(transform: Array<NSNumber>, name: String){
        let arAnchor = ARAnchor(transform: simd_float4x4(deserializeMatrix4(transform)))
        anchorCollection[name] = arAnchor
        sceneView.session.add(anchor: arAnchor)
        // Ensure root node is added to anchor before any other function can run
        while (sceneView.node(for: arAnchor) == nil) {
            usleep(1)
        }
    }
    
    func deleteAnchor(anchorName: String) {
        if let anchor = anchorCollection[anchorName]{
            if var attachedNodes = sceneView.node(for: anchor)?.childNodes {
                attachedNodes.removeAll()
            }
            sceneView.session.remove(anchor: anchor)
            anchorCollection.removeValue(forKey: anchorName)
        }
    }
    
    // MARK: - Face AR Mode Switching
    
    func switchToFaceAR(result: FlutterResult) {
        guard ARFaceTrackingConfiguration.isSupported else {
            DispatchQueue.main.async {
                self.sessionManagerChannel.invokeMethod("onError", arguments: ["Face tracking not supported on this device (requires TrueDepth camera)"])
            }
            result(["switched": false, "error": "Face tracking not supported"])
            return
        }
        
        NSLog("[IosARView] Switching to Face AR mode")
        
        sceneView.session.pause()
        cleanupWorldARContent()
        
        if faceArManager == nil {
            faceArManager = FaceArManager(
                sceneView: sceneView,
                anchorChannel: anchorManagerChannel,
                sessionChannel: sessionManagerChannel
            )
        }
        
        if faceArManager!.startFaceTracking() {
            currentArMode = "face"
            result(["switched": true, "mode": "face"])
        } else {
            result(["switched": false, "error": "Failed to start face tracking"])
        }
    }
    
    func switchToWorldAR(result: FlutterResult) {
        NSLog("[IosARView] Switching to World AR mode")
        
        faceArManager?.stopFaceTracking()
        
        if configuration == nil {
            configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.environmentTexturing = .automatic
        }
        
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        currentArMode = "world"
        
        result(["switched": true, "mode": "world"])
    }
    
    private func cleanupWorldARContent() {
        for plane in trackedPlanes.values {
            plane.1.removeFromParentNode()
        }
        trackedPlanes.removeAll()
        
        for (_, anchor) in anchorCollection {
            sceneView.session.remove(anchor: anchor)
        }
        anchorCollection.removeAll()
        
        for child in sceneView.scene.rootNode.childNodes {
            child.removeFromParentNode()
        }
        
        planeCount = 0
    }
    
    // MARK: - Cloud Anchor Listeners
    
    private class cloudAnchorUploadedListener: CloudAnchorListener {
        private var parent: IosARView
        
        init(parent: IosARView) {
            self.parent = parent
        }
        
        func onCloudTaskComplete(anchorName: String?, anchor: GARAnchor?) {
            if let cloudState = anchor?.cloudState {
                if (cloudState == GARCloudAnchorState.success) {
                    var args = Dictionary<String, String?>()
                    args["name"] = anchorName
                    args["cloudanchorid"] = anchor?.cloudIdentifier
                    DispatchQueue.main.async {self.parent.anchorManagerChannel.invokeMethod("onCloudAnchorUploaded", arguments: args)}
                } else {
                    print("Error uploading anchor, state: \(parent.decodeCloudAnchorState(state: cloudState))")
                    DispatchQueue.main.async {self.parent.sessionManagerChannel.invokeMethod("onError", arguments: ["Error uploading anchor, state: \(self.parent.decodeCloudAnchorState(state: cloudState))"])}
                    return
                }
            }
        }
    }

    private class cloudAnchorDownloadedListener: CloudAnchorListener {
        private var parent: IosARView
        
        init(parent: IosARView) {
            self.parent = parent
        }
        
        func onCloudTaskComplete(anchorName: String?, anchor: GARAnchor?) {
            if let cloudState = anchor?.cloudState {
                if (cloudState == GARCloudAnchorState.success) {
                    let newAnchor = ARAnchor(transform: anchor!.transform)
                    DispatchQueue.main.async {self.parent.anchorManagerChannel.invokeMethod("onAnchorDownloadSuccess", arguments: serializeAnchor(anchor: newAnchor, anchorNode: nil, ganchor: anchor!, name: anchorName), result: { result in
                        if let anchorName = result as? String {
                            self.parent.sceneView.session.add(anchor: newAnchor)
                            self.parent.anchorCollection[anchorName] = newAnchor
                        } else {
                            DispatchQueue.main.async {self.parent.sessionManagerChannel.invokeMethod("onError", arguments: ["Error while registering downloaded anchor at the AR Flutter plugin"])}
                        }
                    })}
                } else {
                    print("Error downloading anchor, state \(cloudState)")
                    DispatchQueue.main.async {self.parent.sessionManagerChannel.invokeMethod("onError", arguments: ["Error downloading anchor, state \(cloudState)"])}
                    return
                }
            }
        }
    }
    
    func decodeCloudAnchorState(state: GARCloudAnchorState) -> String {
        switch state {
        case .errorCloudIdNotFound:
            return "Cloud anchor id not found"
        case .errorHostingDatasetProcessingFailed:
            return "Dataset processing failed, feature map insufficient"
        case .errorHostingServiceUnavailable:
            return "Hosting service unavailable"
        case .errorInternal:
            return "Internal error"
        case .errorNotAuthorized:
            return "Authentication failed: Not Authorized"
        case .errorResolvingSdkVersionTooNew:
            return "Resolving Sdk version too new"
        case .errorResolvingSdkVersionTooOld:
            return "Resolving Sdk version too old"
        case .errorResourceExhausted:
            return " Resource exhausted"
        case .none:
            return "Empty state"
        case .taskInProgress:
            return "Task in progress"
        case .success:
            return "Success"
        case .errorServiceUnavailable:
            return "Cloud Anchor Service unavailable"
        case .errorResolvingLocalizationNoMatch:
            return "No match"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - ARCoachingOverlayViewDelegate

extension IosARView: ARCoachingOverlayViewDelegate {
    
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView){
        // use this delegate method to hide anything in the UI that could cover the coaching overlay view
    }
    
    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        self.sceneView.session.run(configuration, options: [.resetTracking])
    }
}