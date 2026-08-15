import 'package:flutter/material.dart';
import '../../services/app_content_service.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String? orderCode;

  const PaymentSuccessScreen({
    super.key,
    this.orderCode,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  final _contentService = AppContentService();

  // Fallbacks used if the API call fails or a key is missing, so the
  // screen never shows blank text.
  String _title = 'ທ່ານໄດ້ຊຳລະເງິນສຳເລັດແລ້ວ';
  String _subtitle = 'ກະລຸນາລໍຖ້າຮັບເຄື່ອງພາຍໃນ 3-5 ມື້';

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final content = await _contentService.fetchAll();
      if (!mounted) return;
      setState(() {
        _title = content['payment_success_title'] ?? _title;
        _subtitle = content['payment_success_subtitle'] ?? _subtitle;
      });
    } catch (_) {
      // Silently keep fallback text — this screen should never block or
      // show an error just because the content endpoint is unreachable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B7A3D),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B7A3D),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              if (widget.orderCode != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'ລະຫັດຄຳສັ່ງຊື້: ${widget.orderCode}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B7A3D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    'ກັບໄປໜ້າຫຼັກ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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
