import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

/// Full-screen crop step shown after picking a photo and before upload.
/// Returns the cropped image bytes via Navigator.pop, or null if the
/// person backs out without cropping.
class ImageCropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final double aspectRatio; // width / height, e.g. 1.0 for a square logo
  final String title;

  const ImageCropScreen({
    super.key,
    required this.imageBytes,
    required this.aspectRatio,
    required this.title,
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _controller = CropController();
  bool _cropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        actions: [
          IconButton(
            icon: _cropping
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _controller.crop();
                  },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Crop(
          controller: _controller,
          image: widget.imageBytes,
          aspectRatio: widget.aspectRatio,
          baseColor: Colors.black,
          maskColor: Colors.black.withValues(alpha: 0.6),
          onCropped: (result) {
            switch (result) {
              case CropSuccess(:final croppedImage):
                Navigator.of(context).pop(croppedImage);
              case CropFailure():
                setState(() => _cropping = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not crop that image — try again.')),
                  );
                }
            }
          },
        ),
      ),
    );
  }
}
