import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:test_webview/screens/ar_screen.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Verrouiller l'orientation en portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ARPoseApp());
}

class ARPoseApp extends StatelessWidget {
  const ARPoseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARPose',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WebViewPage(),
    );
  }
}

// Page avec WebView
class WebViewPage extends StatefulWidget {
  const WebViewPage({Key? key}) : super(key: key);

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late InAppWebViewController webViewController;
  bool isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Useya Land"),
        actions: [
          // Bouton pour ouvrir directement l'AR (pour tester)
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => _openARCamera(),
            tooltip: 'Ouvrir caméra AR',
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri("http://10.0.2.2:8000"), // Laravel local
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              allowFileAccess: true,
              allowContentAccess: true,
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;

              // Handler pour ouvrir la caméra AR depuis le site web
              webViewController.addJavaScriptHandler(
                handlerName: 'goToFlutterAR',
                callback: (args) {
                  print('📸 Demande d\'ouverture AR reçue depuis le web');
                  _openARCamera();
                  return {"status": "ok"};
                },
              );

              // Handler optionnel pour recevoir une URL de modèle 3D
              webViewController.addJavaScriptHandler(
                handlerName: 'openARWithModel',
                callback: (args) {
                  print('📸 Ouverture AR avec modèle: ${args[0]}');
                  if (args.isNotEmpty && args[0] is String) {
                    _openARCameraWithModel(args[0] as String);
                  } else {
                    _openARCamera();
                  }
                  return {"status": "ok", "modelUrl": args[0]};
                },
              );
            },
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
              print("Console: ${consoleMessage.message}");
            },
          ),

          // Indicateur de chargement
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  // Ouvrir la caméra AR sans modèle prédéfini
  void _openARCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ArTestScreen(),
      ),
    ).then((result) {
      // Quand l'utilisateur revient de l'AR
      if (result != null && result is Map) {
        // Envoyer le résultat au site web
        _sendResultToWebView(result);
      }
    });
  }

  // Ouvrir la caméra AR avec un modèle 3D prédéfini
  void _openARCameraWithModel(String modelUrl) {
  }

  // Envoyer le résultat (chemin de la photo) au site web
  void _sendResultToWebView(Map result) {
    if (result.containsKey('imagePath')) {
      String imagePath = result['imagePath'];
      print('📤 Envoi du résultat au web: $imagePath');

      // Appeler une fonction JavaScript dans la page web
      webViewController.evaluateJavascript(source: '''
        if (typeof window.onARPhotoTaken === 'function') {
          window.onARPhotoTaken('$imagePath');
        }
      ''');
    }
  }
}