import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gal/gal.dart';

/// Service de gestion des photos
class PhotoService {
  /// Sauvegarder une photo dans la galerie
  Future<String> saveToGallery(Uint8List imageBytes) async {
    try {
      // Créer un fichier temporaire
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = path.join(directory.path, 'ar_photo_$timestamp.png');
      
      // Écrire les bytes dans le fichier
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);
      
      // Enregistrer dans la galerie
      await Gal.putImage(imagePath);
      
      return imagePath;
    } catch (e) {
      throw Exception('Erreur lors de la sauvegarde: $e');
    }
  }
  
  /// Générer un nom de fichier unique
  String generateFileName() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'ar_photo_$timestamp.png';
  }
}