import UIKit
import Foundation
import ARKit
import GLTFSceneKit
import Combine

// ============================================================
// ArModelBuilder - Charge les modèles 3D à leur taille originale
// et applique le scale depuis Flutter
// ============================================================
//
// COMPORTEMENT:
// - Le modèle est chargé à sa TAILLE ORIGINALE
// - Le scale de Flutter (via la matrice de transformation) est extrait
// - Ce scale MULTIPLIE la taille originale du modèle
//
// EXEMPLE:
// - Modèle de 10m avec scale=0.1 → 1m affiché
// - Modèle de 1m avec scale=1.0 → 1m affiché
// - Modèle de 1m avec scale=2.0 → 2m affiché
//
// ============================================================

class ArModelBuilder: NSObject {

    // MARK: - Plane Methods
    
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
    
    // MARK: - Scale Extraction
    
    /// Extrait le scale (X, Y, Z) de la matrice de transformation Flutter
    /// La matrice 4x4 contient position, rotation ET scale
    private func extractScale(from transformation: Array<NSNumber>?) -> SCNVector3 {
        guard let transform = transformation, transform.count >= 16 else {
            return SCNVector3(1.0, 1.0, 1.0) // Taille originale par défaut
        }
        
        let m = transform.map { $0.floatValue }
        
        // Extraire le scale de la matrice 4x4
        // Scale X = longueur du vecteur colonne 0 (m[0], m[1], m[2])
        // Scale Y = longueur du vecteur colonne 1 (m[4], m[5], m[6])
        // Scale Z = longueur du vecteur colonne 2 (m[8], m[9], m[10])
        let scaleX = sqrt(m[0]*m[0] + m[1]*m[1] + m[2]*m[2])
        let scaleY = sqrt(m[4]*m[4] + m[5]*m[5] + m[6]*m[6])
        let scaleZ = sqrt(m[8]*m[8] + m[9]*m[9] + m[10]*m[10])
        
        print("[ArModelBuilder] Extracted scale: (\(scaleX), \(scaleY), \(scaleZ))")
        
        return SCNVector3(scaleX, scaleY, scaleZ)
    }
    
    /// Extrait la position de la matrice de transformation
    private func extractPosition(from transformation: Array<NSNumber>?) -> SCNVector3 {
        guard let transform = transformation, transform.count >= 16 else {
            return SCNVector3Zero
        }
        
        // Position = colonne 3 de la matrice (indices 12, 13, 14)
        let x = transform[12].floatValue
        let y = transform[13].floatValue
        let z = transform[14].floatValue
        
        return SCNVector3(x, y, z)
    }
    
    /// Extrait la rotation (quaternion) de la matrice de transformation
    private func extractRotation(from transformation: Array<NSNumber>?) -> SCNQuaternion {
        guard let transform = transformation, transform.count >= 16 else {
            return SCNQuaternion(0, 0, 0, 1) // Identité
        }
        
        let m = transform.map { $0.floatValue }
        
        // D'abord extraire le scale pour normaliser la matrice de rotation
        let scaleX = sqrt(m[0]*m[0] + m[1]*m[1] + m[2]*m[2])
        let scaleY = sqrt(m[4]*m[4] + m[5]*m[5] + m[6]*m[6])
        let scaleZ = sqrt(m[8]*m[8] + m[9]*m[9] + m[10]*m[10])
        
        guard scaleX > 0 && scaleY > 0 && scaleZ > 0 else {
            return SCNQuaternion(0, 0, 0, 1)
        }
        
        // Matrice de rotation normalisée (3x3)
        let m00 = m[0] / scaleX; let m01 = m[1] / scaleX; let m02 = m[2] / scaleX
        let m10 = m[4] / scaleY; let m11 = m[5] / scaleY; let m12 = m[6] / scaleY
        let m20 = m[8] / scaleZ; let m21 = m[9] / scaleZ; let m22 = m[10] / scaleZ
        
        // Convertir matrice de rotation en quaternion
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
        
        return SCNQuaternion(qx, qy, qz, qw)
    }
    
    /// Applique position, rotation et scale au noeud
    /// Le scale fonctionne comme scaleToUnits sur Android :
    /// Il normalise le modèle pour qu'il fasse "scale" mètres de haut
    private func applyTransformation(to node: SCNNode, from transformation: Array<NSNumber>?) {
        let targetSize = extractScale(from: transformation).x  // On prend juste X car c'est uniforme
        let position = extractPosition(from: transformation)
        let rotation = extractRotation(from: transformation)
        
        // Appliquer position et rotation
        node.position = position
        node.orientation = rotation
        
        // ========== SCALE TO UNITS (comme Android) ==========
        // Calculer le bounding box du modèle
        let (minBound, maxBound) = node.boundingBox
        let width = maxBound.x - minBound.x
        let height = maxBound.y - minBound.y
        let depth = maxBound.z - minBound.z
        let maxDimension = max(width, max(height, depth))
        
        print("[ArModelBuilder] Model bounding box: \(width) x \(height) x \(depth), max: \(maxDimension)")
        
        // Calculer le scale pour que le modèle fasse targetSize mètres
        if maxDimension > 0 && targetSize > 0 {
            let normalizedScale = targetSize / maxDimension
            node.scale = SCNVector3(normalizedScale, normalizedScale, normalizedScale)
            print("[ArModelBuilder] scaleToUnits: targetSize=\(targetSize), normalizedScale=\(normalizedScale)")
        } else {
            node.scale = SCNVector3(targetSize, targetSize, targetSize)
            print("[ArModelBuilder] Using direct scale: \(targetSize)")
        }
        // ====================================================
        
        print("[ArModelBuilder] Applied transform - pos: \(position), finalScale: \(node.scale)")
    }

    // MARK: - Model Loading Methods
    
    /// Charge un modèle GLTF/GLB depuis les assets Flutter
    func makeNodeFromGltf(name: String, modelPath: String, transformation: Array<NSNumber>?) -> SCNNode? {
        print("[ArModelBuilder] Loading GLTF model: \(modelPath)")
        
        var scene: SCNScene
        let node: SCNNode = SCNNode()

        do {
            let sceneSource = try GLTFSceneSource(named: modelPath)
            scene = try sceneSource.scene()
            
            print("[ArModelBuilder] GLTF scene loaded, childNodes count: \(scene.rootNode.childNodes.count)")

            // Ajouter les enfants avec clone() (pas flattenedClone())
            // clone() préserve la hiérarchie - le scale du parent affecte les enfants
            for child in scene.rootNode.childNodes {
                node.addChildNode(child.clone())
            }

            node.name = name
            
            // Appliquer la transformation de Flutter (position, rotation, scale)
            applyTransformation(to: node, from: transformation)
            
            print("[ArModelBuilder] Node '\(name)' created with scale")
            return node
        } catch {
            print("[ArModelBuilder] ERROR loading GLTF: \(error.localizedDescription)")
            return nil
        }
    }

    /// Charge un modèle GLTF depuis le système de fichiers
    func makeNodeFromFileSystemGltf(name: String, modelPath: String, transformation: Array<NSNumber>?) -> SCNNode? {
        print("[ArModelBuilder] Loading FileSystem GLTF: \(modelPath)")
        
        var scene: SCNScene
        let node: SCNNode = SCNNode()

        do {
            let sceneSource = try GLTFSceneSource(path: modelPath)
            scene = try sceneSource.scene()
            
            print("[ArModelBuilder] FileSystem GLTF loaded, childNodes: \(scene.rootNode.childNodes.count)")

            for child in scene.rootNode.childNodes {
                node.addChildNode(child.clone())
            }

            node.name = name
            applyTransformation(to: node, from: transformation)

            print("[ArModelBuilder] FileSystem node '\(name)' created")
            return node
        } catch {
            print("[ArModelBuilder] ERROR loading FileSystem GLTF: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Charge un modèle GLB depuis le système de fichiers
    func makeNodeFromFileSystemGLB(name: String, modelPath: String, transformation: Array<NSNumber>?) -> SCNNode? {
        print("[ArModelBuilder] Loading FileSystem GLB: \(modelPath)")
        
        var scene: SCNScene
        let node: SCNNode = SCNNode()

        do {
            let sceneSource = try GLTFSceneSource(path: modelPath)
            scene = try sceneSource.scene()
            
            print("[ArModelBuilder] FileSystem GLB loaded, childNodes: \(scene.rootNode.childNodes.count)")

            for child in scene.rootNode.childNodes {
                node.addChildNode(child.clone())
            }

            node.name = name
            applyTransformation(to: node, from: transformation)

            print("[ArModelBuilder] FileSystem GLB node '\(name)' created")
            return node
        } catch {
            print("[ArModelBuilder] ERROR loading FileSystem GLB: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Charge un modèle GLB depuis une URL web
    func makeNodeFromWebGlb(name: String, modelURL: String, transformation: Array<NSNumber>?) -> Future<SCNNode?, Never> {
        print("[ArModelBuilder] Loading Web GLB: \(modelURL)")
        
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
                                node?.addChildNode(child.clone())
                            }

                            node?.name = name
                            self?.applyTransformation(to: node!, from: transformation)
                            
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
}