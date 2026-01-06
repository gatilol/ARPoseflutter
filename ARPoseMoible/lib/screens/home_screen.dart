import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import 'ar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  InAppWebViewController? webViewController;
  bool isLoading = true;

  Key _webViewKey = UniqueKey();
  bool _isResetting = false;

  // URL de démarrage
  String _initialUrl = kWebViewUrl;


  // ──────────────────────────────────────────────────────────────
  // WebView reset
  // ──────────────────────────────────────────────────────────────

  Future<void> _resetWebView() async {
    if (_isResetting) return;
    _isResetting = true;

    // 1. Détruire complètement le controller
    if (webViewController != null) {
      try {
        await webViewController?.clearCache();
        await webViewController?.clearHistory();
      } catch (e) {
        debugPrint('Error clearing webview: $e');
      }
    }

    // 2. Supprimer tous les cookies
    await CookieManager.instance().deleteAllCookies();

    // 3. Mettre le controller à null et forcer un rebuild complet
    setState(() {
      webViewController = null;
      isLoading = true;
    });

    // 4. Attendre un frame pour s'assurer que le widget est détruit
    await Future.delayed(const Duration(milliseconds: 100));

    // 5. Changer l'URL initiale vers la page de login
    // Si vous avez défini kLoginUrl dans app_config.dart, utilisez-le
    // Sinon, construire l'URL dynamiquement
    final loginUrl = Uri.parse(kWebViewUrl);
    _initialUrl = '${loginUrl.scheme}://${loginUrl.host}${loginUrl.port != 80 && loginUrl.port != 443 ? ':${loginUrl.port}' : ''}${loginUrl.path}/login';

    debugPrint('🔄 Redirecting to login: $_initialUrl');

    // 6. Recréer la WebView avec une nouvelle clé
    setState(() {
      _webViewKey = UniqueKey();
    });

    _isResetting = false;
  }

  // ──────────────────────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onAndroidBackPressed,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Afficher la WebView uniquement si elle n'est pas en train d'être reset
            if (webViewController != null || !_isResetting)
              InAppWebView(
                key: _webViewKey,
                initialUrlRequest: URLRequest(
                  url: WebUri(_initialUrl), // Utiliser l'URL dynamique
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  allowFileAccess: true,
                  allowContentAccess: true,
                  cacheEnabled: true,
                  clearCache: false,
                ),
                onWebViewCreated: _onWebViewCreated,

                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final uri = navigationAction.request.url;
                  if (uri == null) return NavigationActionPolicy.CANCEL;

                  // Intercepter les liens flutter://
                  if (uri.scheme == 'flutter') {
                    _handleFlutterLink(uri);
                    return NavigationActionPolicy.CANCEL;
                  }

                  // Intercepter la route de réservation et l'ouvrir dans le navigateur externe
                  if (uri.path.contains('/useyaland/reservation')) {
                    debugPrint('🌐 Opening reservation in external browser: $uri');
                    await _openInExternalBrowser(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.scheme == 'http' || uri.scheme == 'https') {
                    return NavigationActionPolicy.ALLOW;
                  }

                  return NavigationActionPolicy.CANCEL;
                },

                onLoadStart: (controller, url) {
                  setState(() => isLoading = true);
                },

                onLoadStop: (controller, url) async {
                  setState(() => isLoading = false);

                  // Injecter le safe area padding
                  final topPadding = MediaQuery.of(context).padding.top;
                  await controller.evaluateJavascript(source: '''
                    (function() {
                      document.documentElement.style.setProperty('--safe-area-top', '${topPadding}px');
                      
                      var mainDiv = document.querySelector('div[style*="100dvh"]');
                      if (mainDiv) {
                        mainDiv.style.paddingTop = '${topPadding}px';
                      }
                    })();
                  ''');
                },

                onUpdateVisitedHistory: (controller, url, isReload) {
                  if (url != null) {
                    debugPrint('📍 NAV → $url');
                  }
                },
              ),

            // Loader au-dessus de la WebView
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

  void _handleFlutterLink(Uri uri) {
    switch (uri.host.toLowerCase()) {
      case 'pelicular':
        _openARCamera();
        break;
    }
  }


  // ──────────────────────────────────────────────────────────────
  // WebView Handlers (JS → Flutter)
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

    // Handler pour le logout depuis la WebView
    webViewController!.addJavaScriptHandler(
      handlerName: 'userLogout',
      callback: (args) async {
        debugPrint('Logout triggered from WebView');
        await _resetWebView();
        return {'status': 'logged_out'};
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Navigation
  // ──────────────────────────────────────────────────────────────

  Future<void> _openInExternalBrowser(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Ouvre dans le navigateur par défaut
        );
      } else {
        debugPrint('❌ Cannot launch URL: $url');
      }
    } catch (e) {
      debugPrint('❌ Error launching URL: $e');
    }
  }

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


  void _sendResultToWebView(Map result) {
    if (result.containsKey('imagePath') && webViewController != null) {
      webViewController!.evaluateJavascript(source: '''
        if (typeof window.onARPhotoTaken === 'function') {
          window.onARPhotoTaken('${result['imagePath']}');
        }
      ''');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Android back button
  // ──────────────────────────────────────────────────────────────

  Future<bool> _onAndroidBackPressed() async {
    // Si la WebView n'existe pas (en cours de reset), bloquer
    if (webViewController == null || _isResetting) {
      return true;
    }

    // Comportement normal : permettre la navigation arrière dans la WebView
    if (await webViewController!.canGoBack()) {
      webViewController!.goBack();
      return false; // Empêche de quitter l'app
    }

    return true;
  }

  // ──────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    webViewController = null;
    super.dispose();
  }
}