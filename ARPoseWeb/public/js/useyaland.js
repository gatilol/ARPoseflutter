// Quand on clique sur le bouton
document.getElementById("startButton").addEventListener("click", function () {

    // Vérifier si on est dans une WebView Flutter
    if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler("goToFlutterAR");
    } else {
        alert("Flutter WebView non détectée (test navigateur)");
    }
});
