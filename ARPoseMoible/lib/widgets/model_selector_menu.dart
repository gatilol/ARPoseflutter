import 'package:flutter/material.dart';

class Model3D {
  final String name;
  final String path;
  final IconData icon;
  final String? description;

  const Model3D({
    required this.name,
    required this.path,
    required this.icon,
    this.description,
  });
}

class ModelSelectorMenu extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Function(Model3D) onModelSelected;
  final String? currentModelPath;
  final bool isWorldMode; // ← NOUVEAU : mode actuel

  // ========== Modèles World AR ==========
  static const List<Model3D> worldModels = [
    Model3D(
      name: 'EVA-01',
      path: 'assets/models/world/eva_01_esg.glb',
      icon: Icons.android,
      description: 'Evangelion Unit-01',
    ),
    Model3D(
      name: 'EVA-02',
      path: 'assets/models/world/evangelion_unit-02.glb',
      icon: Icons.android,
      description: 'Evangelion Unit-02',
    ),
    Model3D(
      name: 'Human',
      path: 'assets/models/world/human_body_base_cartoon.glb',
      icon: Icons.accessibility_new,
      description: 'Modèle humain cartoon',
    ),
  ];

  // ========== Modèles Face AR ==========
  static const List<Model3D> faceModels = [
    Model3D(
      name: 'Aucun filtre',
      path: '', // Path vide = pas de modèle
      icon: Icons.face,
      description: 'Votre visage sans effet',
    ),
    Model3D(
      name: 'Lunettes',
      path: 'assets/models/face/fox.glb',
      icon: Icons.visibility,
      description: 'Lunettes de soleil',
    ),
  ];

  const ModelSelectorMenu({
    required this.isOpen,
    required this.onClose,
    required this.onModelSelected,
    this.currentModelPath,
    this.isWorldMode = true, // ← Par défaut World AR
    super.key,
  });

  // Retourne la liste appropriée selon le mode
  List<Model3D> get currentModels => isWorldMode ? worldModels : faceModels;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Overlay semi-transparent
        if (isOpen)
          GestureDetector(
            onTap: onClose,
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),

        // Menu qui slide
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          right: isOpen ? 0 : -320,
          top: 0,
          bottom: 0,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(-5, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header - change selon le mode
                  _buildHeader(),

                  // Liste des modèles
                  Expanded(
                    child: currentModels.isEmpty 
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: currentModels.length,
                          itemBuilder: (context, index) {
                            final model = currentModels[index];
                            final isSelected = currentModelPath == model.path;
                            return _buildModelItem(model, isSelected);
                          },
                        ),
                  ),

                  // Footer info
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Header du menu - change selon le mode
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Couleur de fond selon le mode
        color: isWorldMode 
          ? Colors.blue.withValues(alpha: 0.1)
          : Colors.purple.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Icône selon le mode
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isWorldMode 
                ? Colors.blue.withValues(alpha: 0.2)
                : Colors.purple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isWorldMode ? Icons.view_in_ar : Icons.face_retouching_natural,
              color: isWorldMode ? Colors.blue : Colors.purple,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWorldMode ? 'Modèles 3D' : 'Filtres Visage',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isWorldMode 
                    ? '${worldModels.length} modèles disponibles'
                    : '${faceModels.length} filtres disponibles',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  /// Item de modèle dans la liste
  Widget _buildModelItem(Model3D model, bool isSelected) {
    final accentColor = isWorldMode ? Colors.blue : Colors.purple;
    
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? accentColor.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? accentColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            model.icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          model.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: model.description != null
          ? Text(
              model.description!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            )
          : null,
        trailing: isSelected
            ? Icon(Icons.check_circle, color: accentColor)
            : const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 16,
              ),
        onTap: () {
          onModelSelected(model);
          onClose();
        },
      ),
    );
  }

  /// État vide si pas de modèles
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isWorldMode ? Icons.view_in_ar : Icons.face,
            color: Colors.white.withValues(alpha: 0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            isWorldMode 
              ? 'Aucun modèle 3D disponible'
              : 'Aucun filtre disponible',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des fichiers .glb dans\nassets/models/${isWorldMode ? "" : "face/"}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Footer du menu
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white.withValues(alpha: 0.6),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isWorldMode 
                ? 'Sélectionnez un modèle avant de placer'
                : 'Sélectionnez un filtre pour votre visage',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}