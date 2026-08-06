import 'package:flutter/material.dart';

/// Full-size, dedicated screen that just shows the payment QR.
///
/// Reached either from [AdminPaymentQrUploadScreen] right after a
/// successful upload, or pushed from anywhere else in the app (e.g. a
/// withdrawal/checkout screen) once you have a QR image URL on hand:
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (_) => PaymentQrViewScreen(qrImageUrl: qrUrl),
///   ),
/// );
/// ```
class PaymentQrViewScreen extends StatelessWidget {
  const PaymentQrViewScreen({
    super.key,
    required this.qrImageUrl,
    this.title = 'Payment QR',
    this.subtitle,
  });

  final String qrImageUrl;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitle != null) ...[
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: InteractiveViewer(
                        // Lets the user pinch-to-zoom the QR for easier scanning.
                        minScale: 1,
                        maxScale: 4,
                        child: Image.network(
                          qrImageUrl,
                          width: 320,
                          height: 320,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              width: 320,
                              height: 320,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => const SizedBox(
                            width: 320,
                            height: 320,
                            child: Center(
                              child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Scan this QR code to complete payment',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
