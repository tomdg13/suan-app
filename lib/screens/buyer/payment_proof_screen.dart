import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../config/constants.dart';
import '../../services/orders_service.dart';

// ---------------------------------------------------------------------
// PaymentProofScreen
//
// After the buyer scans the QR and pays in their own banking app, they
// come back here to upload the bank's success screenshot as proof.
//
// OCR happens two different ways depending on platform:
//  - Mobile (Android/iOS): on-device OCR via google_mlkit_text_recognition
//    — fast, works offline.
//  - Web: google_mlkit has no web implementation at all, so instead we
//    send the image to POST /orders/ocr-scan, which runs server-side OCR
//    (tesseract.js) and returns the extracted RRN the same way.
// Either way, the RRN textbox is pre-filled but stays fully editable —
// the buyer can correct it if OCR got it wrong.
// ---------------------------------------------------------------------

class PaymentProofScreen extends StatefulWidget {
  // A single QR payment can cover MULTIPLE orders at once — checkout
  // creates one order per store in the cart, but the buyer pays for
  // all of them together in one scan. So the same screenshot + RRN
  // needs to be attached to every order created in that checkout, not
  // just the first one.
  final List<int> orderIds;

  const PaymentProofScreen({super.key, required this.orderIds});

  @override
  State<PaymentProofScreen> createState() => _PaymentProofScreenState();
}

class _PaymentProofScreenState extends State<PaymentProofScreen> {
  final _picker = ImagePicker();
  final _ordersService = OrdersService();
  final _rrnController = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageName;
  bool _scanning = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _rrnController.dispose();
    super.dispose();
  }

  void _showFullscreen(BuildContext context) {
    if (_imageBytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.memory(_imageBytes!),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageName = picked.name;
      _error = null;
    });

    if (kIsWeb) {
      // ML Kit has no web implementation — use the server-side OCR
      // endpoint instead.
      await _runServerOcr(bytes, picked.name);
    } else {
      await _runOcr(picked.path);
    }
  }

  Future<void> _runServerOcr(Uint8List bytes, String filename) async {
    setState(() => _scanning = true);
    try {
      final result = await _ordersService.ocrScan(imageBytes: bytes, filename: filename);
      final rrn = result['rrn'] as String?;
      if (rrn != null && rrn.isNotEmpty && mounted) {
        setState(() => _rrnController.text = rrn);
      }
    } catch (_) {
      // Non-fatal — buyer can still type the RRN manually.
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _runOcr(String path) async {
    setState(() => _scanning = true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(path);
      final result = await recognizer.processImage(input);
      final extracted = _extractRrn(result.text);
      if (extracted != null && mounted) {
        setState(() => _rrnController.text = extracted);
      }
    } catch (_) {
      // Non-fatal — buyer can still type the RRN manually.
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Looks for "Reference ID 1: <code>" first (the secondary/QR reference
  /// shown on LDB Bank receipts, e.g. "FQR26218PM7O1316"). Falls back to
  /// a bare "FQR..." token, then to the first plain "Reference ID: <code>"
  /// if neither of those match.
  String? _extractRrn(String ocrText) {
    final refId1 = RegExp(r'Reference\s*ID\s*1\s*[:.]?\s*([A-Za-z0-9]+)', caseSensitive: false)
        .firstMatch(ocrText);
    if (refId1 != null) return refId1.group(1);

    final fqrToken = RegExp(r'\bFQR[A-Za-z0-9]+\b').firstMatch(ocrText);
    if (fqrToken != null) return fqrToken.group(0);

    final refId = RegExp(r'Reference\s*ID\s*[:.]?\s*([A-Za-z0-9]+)', caseSensitive: false)
        .firstMatch(ocrText);
    if (refId != null) return refId.group(1);

    return null;
  }

  Future<void> _submit() async {
    if (_imageBytes == null) {
      setState(() => _error = 'Please upload the payment screenshot first');
      return;
    }
    if (_rrnController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the RRN / reference number');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Submit the SAME screenshot + RRN to every order created by this
      // checkout — a single QR payment can cover multiple orders (one
      // per store in the cart), so each of them needs the proof attached,
      // not just the first.
      for (final id in widget.orderIds) {
        await _ordersService.submitPaymentProof(
          orderId: id,
          imageBytes: _imageBytes!,
          filename: _imageName ?? 'payment_proof.jpg',
          rrn: _rrnController.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not submit: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Payment Confirmation',
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Upload the success screenshot from your banking app. '
                'We\'ll try to read the reference number automatically — '
                'please double check it before submitting.',
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Screenshot preview / picker
              GestureDetector(
                onTap: _imageBytes != null ? () => _showFullscreen(context) : _pickImage,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 280, maxHeight: 520),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(AppColors.borderValue)),
                    color: Colors.grey.shade50,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.contain, alignment: Alignment.center)
                      : const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to upload screenshot', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                ),
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Tap the image to view full-size',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
              const SizedBox(height: 10),
              if (_imageBytes != null)
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Choose a different image'),
                ),

              const SizedBox(height: 20),

              // RRN field
              Row(
                children: [
                  const Text('RRN / Reference Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (_scanning) ...[
                    const SizedBox(width: 8),
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 6),
                    Text('scanning...', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rrnController,
                onChanged: (_) => setState(() {}), // keep the submit button's enabled state in sync
                decoration: InputDecoration(
                  hintText: 'e.g. FQR26218PM7O1316',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 6),
                Text(
                  'Scanning runs on our server for web — double check the result.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],

              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(AppColors.primaryValue),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: (_submitting || _scanning || _rrnController.text.trim().isEmpty)
                      ? null
                      : _submit,
                  child: Text(
                    _scanning ? 'Scanning...' : (_submitting ? 'Submitting...' : 'Submit Payment Confirmation'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
