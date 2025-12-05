import 'package:flutter/foundation.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'ar_mode.dart';

class ARState extends ChangeNotifier {
  final List<ARNode> nodes = [];

  bool hasPlacedModel = false;
  bool isCapturing = false;
  bool reticleVisible = false;
  
  // ========== Face AR State ==========
  ArMode currentMode = ArMode.world;
  bool isFaceDetected = false;
  Map<String, dynamic>? lastFacePose;
  // ====================================

  void addNode(ARNode node) {
    nodes.add(node);
    hasPlacedModel = nodes.isNotEmpty;
    notifyListeners();
  }

  void removeNode(ARNode node) {
    nodes.remove(node);
    hasPlacedModel = nodes.isNotEmpty;
    notifyListeners();
  }

  void clearNodes() {
    nodes.clear();
    hasPlacedModel = false;
    notifyListeners();
  }

  void setCapturing(bool value) {
    isCapturing = value;
    notifyListeners();
  }

  void setReticleVisible(bool value) {
    reticleVisible = value;
    notifyListeners();
  }

  // ========== Face AR Methods ==========
  void setMode(ArMode mode) {
    currentMode = mode;
    notifyListeners();
  }

  void setFaceDetected(bool detected) {
    isFaceDetected = detected;
    notifyListeners();
  }

  void updateFacePose(Map<String, dynamic> pose) {
    lastFacePose = pose;
    notifyListeners();
  }

  bool get isWorldMode => currentMode == ArMode.world;
  bool get isFaceMode => currentMode == ArMode.face;
  // =====================================
}