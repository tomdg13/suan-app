import 'package:flutter/material.dart';
import '../../../models/admin_user.dart';
import '../../../services/user_service.dart';
import '../../../services/api_client.dart';

class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key});

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  final _userService = UserService();
  List<AdminUser> _users = [];
  bool _loading = true;
  String? _error;

  final _roles = const ['buyer', 'seller', 'admin'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _userService.getAllUsers();
      setState(() => _users = users);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(AdminUser user, String role) async {
    try {
      await _userService.updateRole(user.id, role);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggleActive(AdminUser user) async {
    try {
      await _userService.setActive(user.id, user.isActive == 0);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openEditDialog(AdminUser user) async {
    final nameCtrl = TextEditingController(text: user.fullName);
    final phoneCtrl = TextEditingController(text: user.phone);
    final emailCtrl = TextEditingController(text: user.email ?? '');
    String? error;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              setDialogState(() {
                saving = true;
                error = null;
              });
              try {
                await _userService.updateProfile(
                  user.id,
                  fullName: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                _load();
              } on ApiException catch (e) {
                setDialogState(() {
                  error = e.message;
                  saving = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Edit User'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Full name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'Phone', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'Email (optional)', border: OutlineInputBorder()),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.blueGrey;
      case 'seller':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Users', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._users.map((user) {
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _roleColor(user.role),
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user.fullName),
                subtitle: Text(user.phone),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      tooltip: 'Edit user',
                      onPressed: () => _openEditDialog(user),
                    ),
                    DropdownButton<String>(
                      value: user.role,
                      items: _roles
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _changeRole(user, v);
                      },
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: user.isActive == 1,
                      onChanged: (_) => _toggleActive(user),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
