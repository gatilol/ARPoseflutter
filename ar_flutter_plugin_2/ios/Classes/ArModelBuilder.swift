import UIKit
import Foundation
import ARKit
import GLTFSceneKit
import Combine

// Responsible for creating Renderables and Nodes
// Compatible avec le comportement Android de scaleToUnits
class ArModelBuilder: NSObject {

    func makePlane(anchor: ARPlaneAnchor, flutterAssetFile: String?) -> SCNNode {
        let plane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        let material = SCNMaterial()
        let opacity: CGFloat
        
        if let textureSourcePath = flutterAssetFile {
            let key = FlutterDartProject.lookupKey(forAsset: textureSourcePath)
            if let image = UIImage(named: key, in: Bundle.main, compatibleWith: nil) {
                material.diffuse.contents = image
                material.diffuse.wrapS = .repeat
                material.diffuse.wrapT = .repeat
                plane.materials = [material]
                opacity = 1.0
            } else {
                opacity = 0.3
            }
        } else {
            opacity = 0.3
        }
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z)
        planeNode.eulerAngles.x = -.pi / 2
        planeNode.opacity = opacity

        return planeNode
    }

    func updatePlaneNode(planeNode: SCNNode, anchor: ARPlaneAnchor) {
        if let plane = planeNode.geometry as? SCNPlane {
            plane.width = CGFloat(anchor.extent.x)
            plane.height = CGFloat(anchor.extent.z)
            let imageSize: Float = 65
            let repeatAmount: Float = 1000 / imageSize
            if let gridMaterial = plane.materials.first {
                gridMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(anchor.extent.x * repeatAmount, anchor.extent.z * repeatAmount, 1)
            }
        }
        planeNode.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z)
    }
    
    // MARK: - Scale To Units (comme Android)
    
    /// Calcule le scale nécessaire pour que le modèle fasse exactement `targetSize` mètres
    /// C'est l'équivalent de `scaleToUnits` sur Android/SceneView
    private func calculateScaleToUnits(for node: SCNNode, targetSize: Float) -> Float {
        // Calculer la bounding box du modèle
        let (minBound, maxBound) = node.boundingBox
        
        let width = maxBound.x - minBound.x
        let height = maxBound.y - minBound.y
        let depth = maxBound.z - minBound.z
        
        // Trouver la dimension maximale
        let maxDimension = max(width, max(height, depth))
        
        guard maxDimension > 0 else {
            print("[ArModelBuilder] Warning: Model has zero dimensions, using scale 1.0")
            return 1.0
        }
        
        // Calculer le scale pour que le modèle fasse targetSize mètres
        let scale = targetSize / maxDimension
        
        print("[ArModelBuilder] Model dimensions: \(width) x \(height) x \(depth)")
        print("[ArModelBuilder] Max dimension: \(maxDimension), target: \(targetSize), scale: \(scale)")
        
        return scale
    }
    
    /// Extrait la valeur scaleToUnits depuis la matrice de transformation
    /// Sur Android, c'est transformation.first() (le premier élément de la matrice)
    private func extractScaleToUnits(from transformation: Array<NSNumber>?) -> Float {
        // Le premier élément de la matrice contient le scale (quand pas de rotation)
        // C'est ce que fait Android: scaleToUnits = transformation.first().toFloat()
        guard let transform = transformation, !transform.isEmpty else {
            return 1.0
        }
        return transform[0].floatValue
    }

    // MARK: - Model Loading
    
    // Creates a node from a given gltf2 (.gltf/.glb) model in the Flutter assets folder
    func makeNodeFromGltf(name: String, modelPath: String, transformation: Array<NSNumber>?) -> SCNNode? {
        print("[ArModelBuilder] Loading GLTF model: \(modelPath)")
        
        var scene: SCNScene
        let node: SCNNode = SCNNode()

        do {
            let sceneSource = try GLTFSceneSource(named: modelPath)
            scene = try sceneSource.scene()
            
            print("[ArModelBuilder] GLTF scene loaded, childNodes count: \(scene.rootNode.childNodes.count)")

            // Ajouter tous les enfants au node
            for child in scene.rootNode.childNodes {
                node.addChildNode(child.flattenedClone())
            }

            node.name = name
            
            // Extraire scaleToUnits depuis la transformation (comme Android)
            let scaleToUnits = extractScaleToUnits(from: transformation)
            
            // Calculer et appliquer le scale pour que le modèle fasse scaleToUnits mètres
            let scale = calculateScaleToUnits(for: node, targetSize: scaleToUnits)
            node.scale = SCNVector3(scale, scale, scale)
            
            // Appliquer la position et rotation depuis la transformation (sans le scale car déjà appliqué)
            if let transform = transformation {
                applyPositionAndRotation(to: node, from: transform)
            }
            
            print("[ArModelBuilder] Node '\(name)' created with scaleToUnits: \(scaleToUnits)")
            return node
        } catch {
            print("[ArModelBuilder] ERROR loading GLTF: \(error.localizedDescription)")
            return nil
        }
    }

    // Creates a node from a given gltf2 (.gltf) model in the file system
    func makeNodeFromFileSystemGltf(name: String, modelPath: String, transformation: Array<NSNumber>?) -> SCNNode? {
        print("[ArModelBuilder] Loading FileSystem GLTF: \(modelPath)")
        
        var scene: SCNScene
        let node: SCNNode = SCNNode()

        do {
            let sceneSource = try GLTFSceneSource(path: modelPath)
            scene = try sceneSource.scene()
            
            print("[ArModelBuilder] FileSystem GLTF loaded, childNodes: \(scene.rootNode.childNodes.count)")

            for child in scene.rootNode.childNodes {
                node.addChildNode(child.flattenedClone())
            }

            node.name = name
            
            let scaleToUnits = extractScaleToUnits(from: transformation)
            let scale = calculateScaleToUnits(for: node, targetSize: scaleToUnits)
            node.scale = SCNVector3(scale, scale, scale)
            
            if let transform = transformation {
                applyPositionAndRotation(to: node, from: transform)
            }

            print("[ArModelBuilder] FileSystem node '\(name)' created")
            return node
        } catch {
            print("[ArModelBuilder] ERROR loading FileSystem GLTF: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Creates a node from a given glb model in the app's documents directory
    func makeNodeFromFileSystemGLB(name: String, modelPath: String, transformation: Array<NSNumber>?) -> SCNNode? {
        print("[ArModelBuilder] Loading FileSystem GLB: \(modelPath)")
        
        var scene: SCNScene
        let node: SCNNode = SCNNode()

        do {
            let sceneSource = try GLTFSceneSource(path: modelPath)
            scene = try sceneSource.scene()
            
            print("[ArModelBuilder] FileSystem GLB loaded, childNodes: \(scene.rootNode.childNodes.count)")

            for child in scene.rootNode.childNodes {
                node.addChildNode(child.flattenedClone())
            }

            node.name = name
            
            let scaleToUnits = extractScaleToUnits(from: transformation)
            let scale = calculateScaleToUnits(for: node, targetSize: scaleToUnits)
            node.scale = SCNVector3(scale, scale, scale)
            
            if let transform = transformation {
                applyPositionAndRotation(to: node, from: transform)
            }

            print("[ArModelBuilder] FileSystem GLB node '\(name)' created")
            return node
        } catch {
            print("\(error.localizedDescription)")
            return nil
        }
    }
    
    // Creates a node from a given glb model URL from the web
    func makeNodeFromWebGlb(name: String, modelURL: String, transformation: Array<NSNumber>?) -> Future<SCNNode?, Never> {
        
        return Future { [weak self] promise in
            var node: SCNNode? = SCNNode()
            
            let handler: (URL?, URLResponse?, Error?) -> Void = { (url: URL?, urlResponse: URLResponse?, error: Error?) -> Void in
                if ((urlResponse as? HTTPURLResponse)?.statusCode != 200) {
                    print("[ArModelBuilder] Web GLB received non-200 response code")
                    node = nil
                    promise(.success(node))
                } else {
                    guard let fileURL = url else { return }
                    do {
                        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                        let documentsDirectory = paths[0]
                        let targetURL = documentsDirectory.appendingPathComponent(urlResponse!.url!.lastPathComponent)
                        
                        try? FileManager.default.removeItem(at: targetURL)
                        try FileManager.default.copyItem(at: fileURL, to: targetURL)

                        do {
                            let sceneSource = GLTFSceneSource(url: targetURL)
                            let scene = try sceneSource.scene()
                            
                            print("[ArModelBuilder] Web GLB loaded, childNodes: \(scene.rootNode.childNodes.count)")

                            for child in scene.rootNode.childNodes {
                                node?.addChildNode(child)
                            }

                            node?.name = name
                            
                            if let self = self, let node = node {
                                let scaleToUnits = self.extractScaleToUnits(from: transformation)
                                let scale = self.calculateScaleToUnits(for: node, targetSize: scaleToUnits)
                                node.scale = SCNVector3(scale, scale, scale)
                                
                                if let transform = transformation {
                                    self.applyPositionAndRotation(to: node, from: transform)
                                }
                            }
                            
                            print("[ArModelBuilder] Web GLB node '\(name)' created")

                        } catch {
                            print("[ArModelBuilder] ERROR loading Web GLB: \(error.localizedDescription)")
                            node = nil
                        }
                        
                        try FileManager.default.removeItem(at: targetURL)
                        promise(.success(node))
                    } catch {
                        node = nil
                        promise(.success(node))
                    }
                }
            }
            
            let downloadTask = URLSession.shared.downloadTask(with: URL(string: modelURL)!, completionHandler: handler)
            downloadTask.resume()
        }
    }
    
    // MARK: - Transform Helpers
    
    /// Applique uniquement la position et rotation depuis la matrice (sans le scale)
    private func applyPositionAndRotation(to node: SCNNode, from transformation: Array<NSNumber>) {
        guard transformation.count >= 16 else { return }
        
        // Extraire la position (colonne 3 de la matrice 4x4)
        let posX = transformation[12].floatValue
        let posY = transformation[13].floatValue
        let posZ = transformation[14].floatValue
        node.position = SCNVector3(posX, posY, posZ)
        
        // Extraire la rotation depuis la matrice 3x3 (sans le scale)
        // On doit d'abord normaliser les vecteurs pour enlever le scale
        let scaleX = sqrt(pow(transformation[0].floatValue, 2) + pow(transformation[1].floatValue, 2) + pow(transformation[2].floatValue, 2))
        let scaleY = sqrt(pow(transformation[4].floatValue, 2) + pow(transformation[5].floatValue, 2) + pow(transformation[6].floatValue, 2))
        let scaleZ = sqrt(pow(transformation[8].floatValue, 2) + pow(transformation[9].floatValue, 2) + pow(transformation[10].floatValue, 2))
        
        guard scaleX > 0 && scaleY > 0 && scaleZ > 0 else { return }
        
        // Matrice de rotation normalisée
        let m00 = transformation[0].floatValue / scaleX
        let m01 = transformation[1].floatValue / scaleX
        let m02 = transformation[2].floatValue / scaleX
        let m10 = transformation[4].floatValue / scaleY
        let m11 = transformation[5].floatValue / scaleY
        let m12 = transformation[6].floatValue / scaleY
        let m20 = transformation[8].floatValue / scaleZ
        let m21 = transformation[9].floatValue / scaleZ
        let m22 = transformation[10].floatValue / scaleZ
        
        // Convertir en quaternion
        let trace = m00 + m11 + m22
        var qw, qx, qy, qz: Float
        
        if trace > 0 {
            let s = sqrt(trace + 1.0) * 2
            qw = 0.25 * s
            qx = (m21 - m12) / s
            qy = (m02 - m20) / s
            qz = (m10 - m01) / s
        } else if m00 > m11 && m00 > m22 {
            let s = sqrt(1.0 + m00 - m11 - m22) * 2
            qw = (m21 - m12) / s
            qx = 0.25 * s
            qy = (m01 + m10) / s
            qz = (m02 + m20) / s
        } else if m11 > m22 {
            let s = sqrt(1.0 + m11 - m00 - m22) * 2
            qw = (m02 - m20) / s
            qx = (m01 + m10) / s
            qy = 0.25 * s
            qz = (m12 + m21) / s
        } else {
            let s = sqrt(1.0 + m22 - m00 - m11) * 2
            qw = (m10 - m01) / s
            qx = (m02 + m20) / s
            qy = (m12 + m21) / s
            qz = 0.25 * s
        }
        
        node.orientation = SCNQuaternion(qx, qy, qz, qw)
    }
}