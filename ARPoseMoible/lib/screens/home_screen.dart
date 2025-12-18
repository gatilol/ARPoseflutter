import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../config/app_config.dart';
import 'ar_screen.dart';

/// Home screen with WebView as the main entry point
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late InAppWebViewController webViewController;
  bool isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Useya Land'),
        actions: [
          // Direct AR access button (for testing)
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _openARCamera,
            tooltip: 'Open AR Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(kWebViewUrl),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              allowFileAccess: true,
              allowContentAccess: true,
            ),
            onWebViewCreated: _onWebViewCreated,
            onLoadStart: (controller, url) {
              setState(() {
                isLoading = true;
              });
            },
            onLoadStop: (controller, url) {
              setState(() {
                isLoading = false;
              });
            },
            onConsoleMessage: (controller, consoleMessage) {
              debugPrint('WebView Console: ${consoleMessage.message}');
            },
          ),

          // Loading indicator
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────
  // WebView Handlers
  // ──────────────────────────────────────────────────────────────

  /// Configure WebView JavaScript handlers
  void _onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;

    // Handler to open AR camera from web
    webViewController.addJavaScriptHandler(
      handlerName: 'goToFlutterAR',
      callback: (args) {
        _openARCamera();
        return {'status': 'ok'};
      },
    );

    // Handler to open AR camera with a specific model
    webViewController.addJavaScriptHandler(
      handlerName: 'openARWithModel',
      callback: (args) {
        if (args.isNotEmpty && args[0] is String) {
          _openARCameraWithModel(args[0] as String);
        } else {
          _openARCamera();
        }
        return {'status': 'ok', 'modelUrl': args.isNotEmpty ? args[0] : null};
      },
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Navigation
  // ──────────────────────────────────────────────────────────────

  /// Open AR camera
  void _openARCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ArScreen(),
      ),
    ).then((result) {
      if (result != null && result is Map) {
        _sendResultToWebView(result);
      }
    });
  }

  /// Open AR camera with a predefined 3D model
  void _openARCameraWithModel(String modelUrl) {
    // TODO: Implement model preloading
    _openARCamera();
  }

  /// Send AR result (photo path) back to the web page
  void _sendResultToWebView(Map result) {
    if (result.containsKey('imagePath')) {
      final imagePath = result['imagePath'];

      webViewController.evaluateJavascript(source: '''
        if (typeof window.onARPhotoTaken === 'function') {
          window.onARPhotoTaken('$imagePath');
        }
      ''');
    }
  }
}