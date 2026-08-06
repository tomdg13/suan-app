import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/payment_qr_service.dart';
import '../shared/payment_qr_view_screen.dart';

/// Standalone screen (with its own AppBar) for pushing this page on its
/// own, e.g. from a button on the Withdrawals view:
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const AdminPaymentQrUploadScreen()),
/// );
/// ```
class AdminPaymentQrUploadScreen extends StatelessWidget {
  const AdminPaymentQrUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment QR')),
      body: const SafeArea(child: PaymentQrUploadView()),
    );
  }
}

/// Plain content widget (no Scaffold/AppBar) — used both inside
/// [AdminPaymentQrUploadScreen] above and as one of the admin shell's
/// `IndexedStack` views (where the shell itself already provides the
/// AppBar/Drawer).
class PaymentQrUploadView extends StatefulWidget {
  const PaymentQrUploadView({super.key});

  @override
  State<PaymentQrUploadView> createState() => _PaymentQrUploadViewState();
}

class _PaymentQrUploadViewState extends State<PaymentQrUploadView> {
  final _picker = ImagePicker();
  // TODO: wire this to the app's real auth token, e.g.
  // PaymentQrService(authToken: context.read<AppState>().token)
  final _qrService = PaymentQrService();

  // Bytes (not dart:io File) so the preview + upload both work on Web,
  // mobile, and desktop the same way.
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  String? _existingQrUrl;
  bool _isLoadingExisting = true;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExistingQr();
  }

  Future<void> _loadExistingQr() async {
    try {
      final url = await _qrService.fetchCurrentQr();
      if (!mounted) return;
      setState(() {
        _existingQrUrl = url;
        _isLoadingExisting = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Non-fatal: admin just won't see a "current QR" preview.
      setState(() => _isLoadingExisting = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageName = picked.name;
      _error = null;
    });
  }

  Future<void> _upload() async {
    if (_pickedImageBytes == null) return;
    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final url = await _qrService.uploadQr(
        _pickedImageBytes!,
        _pickedImageName ?? 'payment_qr.jpg',
      );
      if (!mounted) return;
      setState(() {
        _existingQrUrl = url;
        _pickedImageBytes = null;
        _pickedImageName = null;
        _isUploading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment QR uploaded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Upload failed: $e';
        _isUploading = false;
      });
    }
  }

  void _openQrLink() {
    if (_existingQrUrl == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentQrViewScreen(
          qrImageUrl: _existingQrUrl!,
          subtitle: 'Current payment QR',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoadingExisting
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Upload the QR code buyers/sellers will scan to pay '
                      '(e.g. PromptPay or bank transfer QR).',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),

                    // Preview: newly picked image takes priority over the
                    // existing uploaded one. Image.memory works on every
                    // platform (Image.file does NOT work on Flutter Web).
                    Center(
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          color: Colors.grey.shade50,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _pickedImageBytes != null
                            ? Image.memory(_pickedImageBytes!, fit: BoxFit.contain)
                            : (_existingQrUrl != null
                                ? Image.network(_existingQrUrl!, fit: BoxFit.contain)
                                : const Center(
                                    child: Icon(Icons.qr_code_2, size: 64, color: Colors.grey),
                                  )),
                      ),
                    ),
                    const SizedBox(height: 20),

                    OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(_pickedImageBytes == null ? 'Choose QR image' : 'Choose a different image'),
                    ),
                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: (_pickedImageBytes == null || _isUploading) ? null : _upload,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.upload),
                      label: Text(_isUploading ? 'Uploading…' : 'Upload QR'),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],

                    if (_existingQrUrl != null) ...[
                      const Divider(height: 40),
                      TextButton.icon(
                        onPressed: _openQrLink,
                        icon: const Icon(Icons.open_in_full),
                        label: const Text('View current QR full-size'),
                      ),
                    ],
                  ],
                ),
              );
  }
}
