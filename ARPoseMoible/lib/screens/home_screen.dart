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
  InAppWebViewController? webViewController;
  bool isLoading = true;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onAndroidBackPressed,
      child: Scaffold(
        body: Stack(
          children: [
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

              /// INTERCEPTION flutter://
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;

                if (uri != null && uri.scheme == 'flutter') {
                  _handleFlutterLink(uri);
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },

              onLoadStart: (controller, url) {
                setState(() => isLoading = true);
              },
              onLoadStop: (controller, url) {
                setState(() => isLoading = false);
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint('WebView Console: ${consoleMessage.message}');
              },
            ),

            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Flutter URL Routing
  // ──────────────────────────────────────────────────────────────

  /// Handle flutter://Pelicular links
  void _handleFlutterLink(Uri uri) {
    debugPrint('Flutter link intercepted: $uri');

    switch (uri.host.toLowerCase()) {
      case 'pelicular':
        _openARCamera();
        break;

      default:
        debugPrint('Unknown Flutter route: ${uri.host}');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // WebView Handlers (JS)
  // ──────────────────────────────────────────────────────────────

  void _onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;

    webViewController!.addJavaScriptHandler(
      handlerName: 'goToFlutterAR',
      callback: (args) {
        _openARCamera();
        return {'status': 'ok'};
      },
    );

    webViewController!.addJavaScriptHandler(
      handlerName: 'openARWithModel',
      callback: (args) {
        if (args.isNotEmpty && args[0] is String) {
          _openARCameraWithModel(args[0] as String);
        } else {
          _openARCamera();
        }
        return {'status': 'ok'};
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Navigation
  // ──────────────────────────────────────────────────────────────

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

  void _openARCameraWithModel(String modelUrl) {
    // TODO: preload model
    _openARCamera();
  }

  void _sendResultToWebView(Map result) {
    if (result.containsKey('imagePath') && webViewController != null) {
      final imagePath = result['imagePath'];

      webViewController!.evaluateJavascript(source: '''
        if (typeof window.onARPhotoTaken === 'function') {
          window.onARPhotoTaken('$imagePath');
        }
      ''');
    }
  }

  Future<bool> _onAndroidBackPressed() async {
    if (webViewController != null) {
      final canGoBack = await webViewController!.canGoBack();

      if (canGoBack) {
        webViewController!.goBack();
        return false;
      }
    }
    return true;
  }

}