import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.patch<dynamic>('/profile', data: {'name': name});
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профайл шинэчлэгдлээ')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профайл шинэчлэхэд алдаа гарлаа')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDeleteConfirmation() {
    final user = ref.read(authProvider).user;
    final requiresPassword = user?.hasPassword ?? true;
    showDialog(
      context: context,
      builder: (ctx) => _DeleteAccountDialog(requiresPassword: requiresPassword),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Профайл засах', style: TextStyle(color: Colors.white, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),
          // Avatar
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Name field
          _Label('Харагдах нэр'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1C1C1C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              hintText: 'Нэрээ оруулна уу',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          // Email (read-only)
          _Label('И-мэйл'),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: user?.email ?? ''),
            readOnly: true,
            style: const TextStyle(color: AppTheme.textSecondary),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF141414),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 16),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _loading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Хадгалах', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),

          // Danger zone
          const SizedBox(height: 48),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.shade900.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Бүртгэл устгах',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Устгасны дараа бүх мэдээлэл, түрээс болон үзэх түүх бүрмөсөн устгагдана.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _showDeleteConfirmation,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade800),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Бүртгэл устгах', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  final bool requiresPassword;
  const _DeleteAccountDialog({required this.requiresPassword});

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (widget.requiresPassword && _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Нууц үгээ оруулна уу');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      await api.delete<dynamic>(
        '/profile',
        data: widget.requiresPassword ? {'password': _passwordCtrl.text} : null,
      );
      if (mounted) {
        Navigator.of(context).pop();
        await ref.read(authProvider.notifier).logout();
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['errors']?['password']?.first
          ?? e.response?.data?['message']
          ?? 'Алдаа гарлаа';
      if (mounted) setState(() { _loading = false; _error = msg as String?; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Алдаа гарлаа'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Бүртгэл устгах',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Бүртгэлийг устгасны дараа буцааж сэргээх боломжгүй.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          if (widget.requiresPassword) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                hintText: 'Нууц үгээ оруулна уу',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                errorText: _error,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ] else if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Болих', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        TextButton(
          onPressed: _loading ? null : _confirm,
          child: _loading
              ? const SizedBox(
                  height: 16, width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                )
              : const Text('Устгах', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
}
