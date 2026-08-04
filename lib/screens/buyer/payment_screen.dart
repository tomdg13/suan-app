import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/constants.dart';
import '../../services/payment_service.dart';

// ---------------------------------------------------------------------
// PaymentScreen
//
// Shows a QR code for the customer to scan to pay an order. While
// waiting, it polls the backend for the transaction status. Once the
// bank/switch confirms the payment, it shows the RRN (Retrieval
// Reference Number) returned from the transaction so the buyer/cashier
// has proof of payment.
//
// NOTE: This assumes a PaymentService with two methods — adjust the
// method names/fields below to match your real API:
//
//   Future<QrPaymentResult> createQrPayment({required int orderId, required double amount});
//   Future<PaymentStatusResult> checkPaymentStatus({required String transactionId});
//
// QrPaymentResult   -> { transactionId, qrPayload (raw EMV/QR string) or qrImageUrl }
// PaymentStatusResult -> { status: 'pending' | 'success' | 'failed', rrn, paidAt }
// ---------------------------------------------------------------------

class PaymentScreen extends StatefulWidget {
  final int orderId;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

enum _PayState { loading, waitingScan, success, failed }

class _PaymentScreenState extends State<PaymentScreen> {
  final _paymentService = PaymentService();

  _PayState _state = _PayState.loading;
  String? _qrPayload; // raw string to render as QR (EMV/QR30 payload)
  String? _qrImageUrl; // OR a ready-made QR image from backend
  String? _transactionId;
  String? _rrn;
  DateTime? _paidAt;
  String? _errorMessage;

  Timer? _pollTimer;
  int _secondsElapsed = 0;
  static const int _timeoutSeconds = 180; // stop polling after 3 minutes

  @override
  void initState() {
    super.initState();
    _startPayment();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startPayment() async {
    setState(() {
      _state = _PayState.loading;
      _errorMessage = null;
    });
    try {
      final result = await _paymentService.createQrPayment(
        orderId: widget.orderId,
        amount: widget.amount,
      );
      if (!mounted) return;
      setState(() {
        _transactionId = result.transactionId;
        _qrPayload = result.qrPayload;
        _qrImageUrl = result.qrImageUrl;
        _state = _PayState.waitingScan;
      });
      _beginPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _PayState.failed;
        _errorMessage = 'Could not create QR payment: $e';
      });
    }
  }

  void _beginPolling() {
    _secondsElapsed = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _secondsElapsed += 3;
      if (_secondsElapsed >= _timeoutSeconds) {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          _state = _PayState.failed;
          _errorMessage = 'Payment timed out. Please try again.';
        });
        return;
      }
      if (_transactionId == null) return;
      try {
        final status = await _paymentService.checkPaymentStatus(
          transactionId: _transactionId!,
        );
        if (!mounted) return;
        if (status.status == 'success') {
          timer.cancel();
          setState(() {
            _rrn = status.rrn;
            _paidAt = status.paidAt ?? DateTime.now();
            _state = _PayState.success;
          });
        } else if (status.status == 'failed') {
          timer.cancel();
          setState(() {
            _state = _PayState.failed;
            _errorMessage = 'Payment failed or was declined.';
          });
        }
        // status == 'pending' -> keep polling
      } catch (_) {
        // Ignore transient poll errors; keep trying until timeout.
      }
    });
  }

  void _copyRrn() {
    if (_rrn == null) return;
    Clipboard.setData(ClipboardData(text: _rrn!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('RRN copied')),
    );
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
          'Payment',
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _PayState.loading:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(AppColors.primaryValue)),
            SizedBox(height: 16),
            Text('Generating QR...'),
          ],
        );

      case _PayState.waitingScan:
        return _buildQrView();

      case _PayState.success:
        return _buildSuccessView();

      case _PayState.failed:
        return _buildFailedView();
    }
  }

  Widget _buildQrView() {
    final priceFormat = NumberFormat.decimalPattern('en_US');
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${priceFormat.format(widget.amount)} ກີບ',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(AppColors.primaryValue),
            ),
          ),
          const SizedBox(height: 4),
          Text('Order #${widget.orderId}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(AppColors.borderValue)),
            ),
            child: _qrPayload != null
                ? QrImageView(
                    data: _qrPayload!,
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                  )
                : (_qrImageUrl != null
                    ? Image.network(_qrImageUrl!, width: 240, height: 240, fit: BoxFit.contain)
                    : const SizedBox(
                        width: 240,
                        height: 240,
                        child: Center(child: Icon(Icons.qr_code_2, size: 80, color: Colors.black26)),
                      )),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Waiting for customer to scan...', style: TextStyle(color: Colors.black54, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'Open your banking app and scan this QR to pay.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 24),

          TextButton(
            onPressed: () {
              _pollTimer?.cancel();
              _startPayment();
            },
            child: const Text('Generate new QR'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final priceFormat = NumberFormat.decimalPattern('en_US');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(AppColors.primaryValue),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment Successful',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(AppColors.backgroundValue),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              _buildDetailRow('Amount', '${priceFormat.format(widget.amount)} ກີບ'),
              const SizedBox(height: 10),
              _buildDetailRow('Order', '#${widget.orderId}'),
              const SizedBox(height: 10),
              if (_paidAt != null) _buildDetailRow('Date/Time', dateFormat.format(_paidAt!)),
              if (_paidAt != null) const SizedBox(height: 10),

              // RRN row with copy button — this is the key confirmation
              // reference the switch/bank returns after the scan.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RRN', style: TextStyle(color: Colors.black54, fontSize: 13)),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      _rrn ?? '-',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (_rrn != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _copyRrn,
                      child: const Icon(Icons.copy, size: 15, color: Colors.black45),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(AppColors.primaryValue),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
      ],
    );
  }

  Widget _buildFailedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(AppColors.errorValue).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close, color: const Color(AppColors.errorValue), size: 40),
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment Not Completed',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Something went wrong.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(AppColors.primaryValue),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _startPayment,
            child: const Text('Try Again', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
