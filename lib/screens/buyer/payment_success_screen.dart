import 'package:flutter/material.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String? orderCode;
  final String deliveryEstimate;

  const PaymentSuccessScreen({
    super.key,
    this.orderCode,
    this.deliveryEstimate = '3-5 ມື້',
  });

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
              const Text(
                'ທ່ານໄດ້ຊຳລະເງິນສຳເລັດແລ້ວ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B7A3D),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ກະລຸນາລໍຖ້າຮັບເຄື່ອງພາຍໃນ $deliveryEstimate',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              if (orderCode != null) ...[
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
                    'ລະຫັດຄຳສັ່ງຊື້: $orderCode',
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
                    // Go back to home / orders list, clearing the stack
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
