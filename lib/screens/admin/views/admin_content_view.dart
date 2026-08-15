import 'package:flutter/material.dart';
import '../../../services/app_content_service.dart';

/// Lets an admin edit small pieces of app text (currently the payment
/// success screen's title/subtitle) without a code deploy.
class AdminContentView extends StatefulWidget {
  const AdminContentView({super.key});

  @override
  State<AdminContentView> createState() => _AdminContentViewState();
}

class _AdminContentViewState extends State<AdminContentView> {
  final _contentService = AppContentService();

  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _savedMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content = await _contentService.fetchAll();
      if (!mounted) return;
      setState(() {
        _titleCtrl.text = content['payment_success_title'] ?? '';
        _subtitleCtrl.text = content['payment_success_subtitle'] ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _savedMessage = null;
    });
    try {
      await _contentService.update('payment_success_title', _titleCtrl.text.trim());
      await _contentService.update('payment_success_subtitle', _subtitleCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _saving = false;
        _savedMessage = 'ບັນທຶກສຳເລັດແລ້ວ';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Failed to save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ຂໍ້ຄວາມໜ້າຊຳລະເງິນສຳເລັດ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'ສະແດງໃຫ້ຜູ້ຊື້ເຫັນທັນທີຫຼັງຈາກສົ່ງການຢືນຢັນການຊຳລະເງິນ.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          const Text('ຫົວຂໍ້', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          const Text('ຄຳອະທິບາຍຍ່ອຍ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _subtitleCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 12),
          ],
          if (_savedMessage != null) ...[
            Text(_savedMessage!, style: const TextStyle(color: Colors.green, fontSize: 13)),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'ກຳລັງບັນທຶກ...' : 'ບັນທຶກ'),
            ),
          ),
        ],
      ),
    );
  }
}
