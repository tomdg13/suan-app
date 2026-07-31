import 'package:flutter/material.dart';
import '../../config/constants.dart';

/// Full-screen photo viewer with pinch-to-zoom, opened by tapping the
/// main product image. Swipe between photos just like the inline gallery.
class FullscreenGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullscreenGalleryScreen({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullscreenGalleryScreen> createState() => _FullscreenGalleryScreenState();
}

class _FullscreenGalleryScreenState extends State<FullscreenGalleryScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_index + 1} / ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                '${ApiConfig.mediaBaseUrl}${widget.images[index]}',
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
