import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _googleLoading = false;
  bool _appleLoading = false;

  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = ref.read(authProvider).forcedLogoutMessage;
      if (msg != null && mounted) {
        ref.read(authProvider.notifier).consumeForcedLogoutMessage();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool get _anyLoading => _googleLoading || _appleLoading;

  Future<void> _googleSignIn() async {
    setState(() => _googleLoading = true);
    final ok = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (!ok) {
      _showError(ref.read(authProvider).error ?? 'Google нэвтрэлт амжилтгүй боллоо');
    }
    // Router redirects automatically on success (/ or /set-password based on needsPassword).
  }

  Future<void> _appleSignIn() async {
    setState(() => _appleLoading = true);
    final ok = await ref.read(authProvider.notifier).signInWithApple();
    if (!mounted) return;
    setState(() => _appleLoading = false);
    if (!ok) {
      _showError(ref.read(authProvider).error ?? 'Apple нэвтрэлт амжилтгүй боллоо');
    }
    // Router redirects automatically on success (/ or /set-password based on needsPassword).
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: const Color(0xFFB00020),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (ok) {
      context.go('/');
    } else {
      _showError(ref.read(authProvider).error ?? 'Нэвтрэхэд алдаа гарлаа');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: -size.height * 0.15,
            left: 0,
            right: 0,
            child: Container(
              height: size.height * 0.6,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  radius: 0.75,
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: size.height * 0.08),

                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Image.asset(
                              'assets/images/app_icon_black.png',
                              height: 120,
                              width: 120,
                              errorBuilder: (_, __, ___) => Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 64,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: size.height * 0.06),

                        _Field(
                          controller: _emailCtrl,
                          hint: 'И-мэйл хаяг',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => v == null || !v.contains('@')
                              ? 'Зөв и-мэйл оруулна уу'
                              : null,
                        ),

                        const SizedBox(height: 12),

                        _Field(
                          controller: _passCtrl,
                          hint: 'Нууц үг',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          onToggleObscure: () =>
                              setState(() => _obscure = !_obscure),
                          validator: (v) => v == null || v.length < 8
                              ? 'Нууц үг хэт богино байна'
                              : null,
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (isLoading || _anyLoading) ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppTheme.primary.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Нэвтрэх',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Row(
                            children: [
                              Expanded(child: Divider(color: Color(0xFF2A2A2A))),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'Эсвэл',
                                  style: TextStyle(
                                    color: Color(0xFF555555),
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Color(0xFF2A2A2A))),
                            ],
                          ),
                        ),

                        _SocialButton(
                          onTap: (isLoading || _anyLoading) ? null : _googleSignIn,
                          loading: _googleLoading,
                          backgroundColor: Colors.white,
                          loadingColor: const Color(0xFF3C4043),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/google_logo.webp',
                                height: 20,
                                width: 20,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.g_mobiledata_rounded,
                                  color: Color(0xFF4285F4),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Google-ээр нэвтрэх',
                                style: TextStyle(
                                  color: Color(0xFF3C4043),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (Platform.isIOS) ...[
                          const SizedBox(height: 12),
                          _SocialButton(
                            onTap: (isLoading || _anyLoading) ? null : _appleSignIn,
                            loading: _appleLoading,
                            backgroundColor: const Color(0xFF1C1C1E),
                            border: Border.all(color: const Color(0xFF3A3A3A)),
                            loadingColor: Colors.white,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.apple, color: Colors.white, size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'Apple-ээр нэвтрэх',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: size.height * 0.04),

                        Text(
                          Platform.isIOS
                              ? 'Google эсвэл Apple-ээр нэвтэрч шинэ данс үүсгэж болно.'
                              : 'Google-ээр нэвтэрч шинэ данс үүсгэж болно.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF444444),
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  final Color backgroundColor;
  final BoxBorder? border;
  final Widget child;
  final Color loadingColor;

  const _SocialButton({
    required this.onTap,
    required this.loading,
    required this.backgroundColor,
    required this.child,
    required this.loadingColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: loadingColor,
                    ),
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 15),
        filled: true,
        fillColor: const Color(0xFF151515),
        prefixIcon: Icon(icon, color: const Color(0xFF555555), size: 20),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF555555),
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF555555)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.7)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
