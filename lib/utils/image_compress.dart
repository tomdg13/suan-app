import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Resizes an image down to fit within [maxDimension] on its longest
/// side (keeping aspect ratio) and re-encodes it as JPEG at [quality]
/// to keep upload size small. Images already smaller than
/// [maxDimension] are only re-compressed, not upscaled.
Uint8List compressImage(
  Uint8List bytes, {
  int maxDimension = 1200,
  int quality = 85,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  img.Image toEncode = decoded;
  if (decoded.width > maxDimension || decoded.height > maxDimension) {
    toEncode = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxDimension)
        : img.copyResize(decoded, height: maxDimension);
  }

  return Uint8List.fromList(img.encodeJpg(toEncode, quality: quality));
}
