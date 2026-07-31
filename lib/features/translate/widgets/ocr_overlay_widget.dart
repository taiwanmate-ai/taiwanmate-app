import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/ocr_region.dart';
import '../utils/image_overlay_transform.dart';

class OcrOverlayWidget extends StatefulWidget {
  final Uint8List imageBytes;
  final Size imageSize;
  final List<OcrRegion> regions;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;

  const OcrOverlayWidget({
    super.key,
    required this.imageBytes,
    required this.imageSize,
    required this.regions,
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  @override
  State<OcrOverlayWidget> createState() => _OcrOverlayWidgetState();
}

class _OcrOverlayWidgetState extends State<OcrOverlayWidget> {
  void _handleTapUp(TapUpDetails details, Size displaySize) {
    final transform = ImageOverlayTransform(
        imageSize: widget.imageSize, displaySize: displaySize);
    final imagePoint = transform.displayPointToImage(details.localPosition);
    for (final region in widget.regions) {
      if (region.boundingBox.contains(imagePoint)) {
        final newSelection = Set<String>.from(widget.selectedIds);
        if (newSelection.contains(region.id)) {
          newSelection.remove(region.id);
        } else {
          newSelection.add(region.id);
        }
        widget.onSelectionChanged(newSelection);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displaySize = Size(constraints.maxWidth, constraints.maxHeight);
        final transform = ImageOverlayTransform(
            imageSize: widget.imageSize, displaySize: displaySize);
        return GestureDetector(
          onTapUp: (details) => _handleTapUp(details, displaySize),
          child: Stack(children: [
            Positioned.fill(
                child: Image.memory(widget.imageBytes, fit: BoxFit.contain)),
            ...widget.regions.map((region) {
              final displayRect = transform.imageToDisplay(region.boundingBox);
              final isSelected = widget.selectedIds.contains(region.id);
              return Positioned(
                left: displayRect.left,
                top: displayRect.top,
                width: displayRect.width,
                height: displayRect.height,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.indigo.withOpacity(0.25)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Colors.indigo
                          : Colors.indigo.withOpacity(0.4),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ]),
        );
      },
    );
  }
}
