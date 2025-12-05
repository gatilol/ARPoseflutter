import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'ar_session_manager.dart';
import 'ar_object_manager.dart';

/// Example screen demonstrating World AR and Face AR switching
class ARFaceScreen extends StatefulWidget {
  const ARFaceScreen({super.key});

  @override
  State<ARFaceScreen> createState() => _ARFaceScreenState();
}

class _ARFaceScreenState extends State<ARFaceScreen> {
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  
  // State
  String _currentMode = 'world';
  bool _isInitialized = false;
  bool _isSwitching = false;
  bool _faceDetected = false;
  String? _statusMessage;
  Map<String, dynamic>? _lastFacePose;

  @override
  void dispose() {
    _arSessionManager?.dispose();
    super.dispose();
  }

  void _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    _arSessionManager = ARSessionManager(
      viewId: 0, // Will be set by the plugin
      onSessionCreated: _onSessionCreated,
      onError: _onError,
      onPlaneDetected: _onPlaneDetected,
      onFaceDetected: _onFaceDetected,
      onFacePoseUpdate: _onFacePoseUpdate,
      onModeChanged: _onModeChanged,
    );

    _arObjectManager = ARObjectManager(
      viewId: 0,
      onError: _onError,
    );

    // Initialize with World AR mode
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    await _arSessionManager?.init(
      showAnimatedGuide: _currentMode == 'world',
      showPlanes: _currentMode == 'world',
      planeDetectionConfig: _currentMode == 'world' ? 3 : 0, // Horizontal + Vertical
      handleTaps: true,
    );
  }

  void _onSessionCreated() {
    setState(() {
      _isInitialized = true;
      _statusMessage = _currentMode == 'world' 
          ? 'World AR ready - Scan environment'
          : 'Face AR ready - Point camera at face';
    });
  }

  void _onError(String error) {
    setState(() {
      _statusMessage = 'Error: $error';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _onPlaneDetected(int planeCount) {
    if (_currentMode == 'world') {
      setState(() {
        _statusMessage = 'Detected $planeCount plane(s)';
      });
    }
  }

  void _onFaceDetected(bool detected) {
    setState(() {
      _faceDetected = detected;
      if (_currentMode == 'face') {
        _statusMessage = detected 
            ? 'Face detected! 😊'
            : 'No face detected - Point camera at face';
      }
    });
  }

  void _onFacePoseUpdate(Map<String, dynamic> poseData) {
    setState(() {
      _lastFacePose = poseData;
    });
  }

  void _onModeChanged(String mode) {
    setState(() {
      _currentMode = mode;
      _isSwitching = false;
      _faceDetected = false;
      _lastFacePose = null;
    });
  }

  Future<void> _toggleMode() async {
    if (_isSwitching || _arSessionManager == null) return;

    setState(() {
      _isSwitching = true;
      _statusMessage = 'Switching camera...';
    });

    try {
      final newMode = await _arSessionManager!.toggleMode();
      if (newMode != null) {
        // Re-initialize session for new mode
        await _initializeSession();
      }
    } catch (e) {
      setState(() {
        _isSwitching = false;
        _statusMessage = 'Failed to switch: $e';
      });
    }
  }

  Future<void> _addModelToFace() async {
    if (_currentMode != 'face' || !_faceDetected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switch to Face AR mode and detect a face first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final success = await _arObjectManager?.addNodeToFace(
      node: ARNode(
        name: 'face_accessory_${DateTime.now().millisecondsSinceEpoch}',
        uri: 'assets/models/glasses.glb', // Your model path
        type: NodeType.flutterAsset,
        scale: 0.1,
      ),
      region: FaceRegion.nose,
    );

    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Model added to face!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentMode == 'world' ? 'World AR' : 'Face AR'),
        backgroundColor: _currentMode == 'world' 
            ? Colors.blue.shade700 
            : Colors.purple.shade700,
        actions: [
          // Mode indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Chip(
              avatar: Icon(
                _currentMode == 'world' ? Icons.language : Icons.face,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                _currentMode.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: Colors.black38,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // AR View
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: _currentMode == 'world'
                ? PlaneDetectionConfig.horizontalAndVertical
                : PlaneDetectionConfig.none,
          ),

          // Status bar at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status message
                    if (_statusMessage != null)
                      Text(
                        _statusMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    
                    // Face detection indicator (Face AR mode)
                    if (_currentMode == 'face') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _faceDetected ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _faceDetected ? 'Face Tracking Active' : 'No Face',
                            style: TextStyle(
                              color: _faceDetected ? Colors.green : Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Face pose debug info (optional - Face AR mode)
          if (_currentMode == 'face' && _lastFacePose != null)
            Positioned(
              bottom: 120,
              left: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Face Pose:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'X: ${(_lastFacePose!['position']['x'] as double).toStringAsFixed(3)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    Text(
                      'Y: ${(_lastFacePose!['position']['y'] as double).toStringAsFixed(3)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    Text(
                      'Z: ${(_lastFacePose!['position']['z'] as double).toStringAsFixed(3)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

          // Loading overlay during switch
          if (_isSwitching)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Switching camera...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Switch mode button
                    _buildControlButton(
                      icon: _currentMode == 'world' 
                          ? Icons.face 
                          : Icons.language,
                      label: _currentMode == 'world' 
                          ? 'Face AR' 
                          : 'World AR',
                      onPressed: _isSwitching ? null : _toggleMode,
                      color: _currentMode == 'world' 
                          ? Colors.purple 
                          : Colors.blue,
                    ),

                    // Add model button (Face AR only)
                    if (_currentMode == 'face')
                      _buildControlButton(
                        icon: Icons.add_circle,
                        label: 'Add Model',
                        onPressed: _faceDetected ? _addModelToFace : null,
                        color: Colors.green,
                      ),

                    // Snapshot button
                    _buildControlButton(
                      icon: Icons.camera_alt,
                      label: 'Snapshot',
                      onPressed: () async {
                        final image = await _arSessionManager?.snapshot();
                        if (image != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Snapshot captured!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    final isEnabled = onPressed != null;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? color : Colors.grey,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isEnabled ? Colors.white : Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}