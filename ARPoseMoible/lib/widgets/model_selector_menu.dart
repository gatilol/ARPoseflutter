import 'package:flutter/material.dart';

class Model3D {
  final String name;
  final String path;
  final IconData icon;

  const Model3D({
    required this.name,
    required this.path,
    required this.icon,
  });
}

class ModelSelectorMenu extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Function(Model3D) onModelSelected;
  final String? currentModelPath;

  // Liste des modèles disponibles
  static const List<Model3D> availableModels = [
    Model3D(
      name: 'EVA-01',
      path: 'assets/models/eva_01_esg.glb',
      icon: Icons.android,
    ),
    Model3D(
      name: 'Human',
      path: 'assets/models/human_body_base_cartoon.glb',
      icon: Icons.view_in_ar,
    )
  ];

  const ModelSelectorMenu({
    required this.isOpen,
    required this.onClose,
    required this.onModelSelected,
    this.currentModelPath,
    super.key,
  });

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
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.view_in_ar,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Modèles 3D',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                  ),

                  // Liste des modèles
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: availableModels.length,
                      itemBuilder: (context, index) {
                        final model = availableModels[index];
                        final isSelected = currentModelPath == model.path;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue
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
                            trailing: isSelected
                                ? const Icon(
                              Icons.check_circle,
                              color: Colors.blue,
                            )
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
                      },
                    ),
                  ),

                  // Footer info
                  Container(
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
                            'Sélectionnez un modèle avant de placer',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}