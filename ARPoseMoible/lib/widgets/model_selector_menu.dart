import 'package:flutter/material.dart';

import '../models/face_filter_type.dart';
import '../models/model_3d.dart';

/// Sliding menu for selecting 3D models and face filters
class ModelSelectorMenu extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Function(Model3D) onModelSelected;
  final Function(FaceFilterType)? onFilterRemoved;
  final String? currentModelPath;
  final String? currentMakeupPath;
  final bool isWorldMode;

  const ModelSelectorMenu({
    required this.isOpen,
    required this.onClose,
    required this.onModelSelected,
    this.onFilterRemoved,
    this.currentModelPath,
    this.currentMakeupPath,
    this.isWorldMode = true,
    super.key,
  });

  /// Returns the appropriate model list based on current mode
  List<Model3D> get currentModels => isWorldMode ? worldModels : faceFilters;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Semi-transparent overlay
        if (isOpen)
          GestureDetector(
            onTap: onClose,
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),

        // Sliding menu panel
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
                  _buildHeader(),
                  Expanded(
                    child: currentModels.isEmpty
                        ? _buildEmptyState()
                        : isWorldMode
                            ? _buildSimpleList()
                            : _buildCategorizedList(),
                  ),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Header
  // ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
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
          // Icon container
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

          // Title and count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWorldMode ? '3D Models' : 'Face Filters',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isWorldMode
                      ? '${worldModels.length} models available'
                      : '${faceFilters.length} filters available',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Close button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Lists
  // ──────────────────────────────────────────────────────────────

  /// Simple list for World AR models
  Widget _buildSimpleList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: currentModels.length,
      itemBuilder: (context, index) {
        final model = currentModels[index];
        final isSelected = currentModelPath == model.path;
        return _buildModelItem(model, isSelected);
      },
    );
  }

  /// Categorized list for Face AR filters (3D models + makeup)
  Widget _buildCategorizedList() {
    final modelFilters = faceFilters
        .where((m) => m.filterType == FaceFilterType.model3D)
        .toList();
    final makeupFilters = faceFilters
        .where((m) => m.filterType == FaceFilterType.makeup)
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // 3D Accessories section
        if (modelFilters.isNotEmpty) ...[
          _buildSectionHeader('3D Accessories', Icons.view_in_ar),
          ...modelFilters.map(
            (m) => _buildModelItem(m, currentModelPath == m.path),
          ),
        ],

        // Makeup section
        if (makeupFilters.isNotEmpty) ...[
          _buildSectionHeader('Makeup', Icons.brush),
          ...makeupFilters.map(
            (m) => _buildModelItem(m, currentMakeupPath == m.path),
          ),
        ],
      ],
    );
  }

  /// Section header for categorized list
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.purple.withValues(alpha: 0.7),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Model Item
  // ──────────────────────────────────────────────────────────────

  Widget _buildModelItem(Model3D model, bool isSelected) {
    final accentColor = isWorldMode ? Colors.blue : Colors.purple;

    // Icon background color based on type and selection
    Color iconBgColor;
    if (isSelected) {
      iconBgColor = accentColor;
    } else if (model.filterType == FaceFilterType.makeup) {
      iconBgColor = Colors.pink.withValues(alpha: 0.3);
    } else {
      iconBgColor = Colors.white.withValues(alpha: 0.1);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        // Icon
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(model.icon, color: Colors.white, size: 24),
        ),

        // Title
        title: Text(
          model.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Description
        subtitle: model.description != null
            ? Text(
                model.description!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              )
            : null,

        // Trailing (checkmark and/or remove button)
        trailing: isSelected
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: accentColor),

                  // Remove button (Face AR only)
                  if (!isWorldMode) ...[
                    const SizedBox(width: 8),
                    _buildRemoveButton(model.filterType),
                  ],
                ],
              )
            : const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),

        onTap: () {
          onModelSelected(model);
          onClose();
        },
      ),
    );
  }

  /// Remove button for active filters (Face AR only)
  Widget _buildRemoveButton(FaceFilterType filterType) {
    return GestureDetector(
      onTap: () {
        if (onFilterRemoved != null) {
          onFilterRemoved!(filterType);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: const Icon(Icons.close, color: Colors.red, size: 18),
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Empty State & Footer
  // ──────────────────────────────────────────────────────────────

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
            isWorldMode ? 'No 3D models available' : 'No filters available',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

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
                  ? 'Select a model before placing'
                  : 'Select a filter for your face',
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