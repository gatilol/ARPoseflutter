import 'package:flutter/foundation.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';

class ARState extends ChangeNotifier {
  final List<ARNode> nodes = [];
  bool hasPlacedModel = false;
  bool isCapturing = false;

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
}
