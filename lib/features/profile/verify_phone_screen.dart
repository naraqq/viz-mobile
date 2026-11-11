import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../auth/auth_widgets.dart';

/// Verify the account's phone number with one SMS (verify.mn), same as the web profile page.
/// Accounts created in the app with phone + PIN start unverified; Google/email accounts can
/// add a number here too.
class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  final _phoneCtrl = TextEditingController();
  PhoneSession? _session;
  Timer? _poll;
  Timer? _tick;
  bool _busy = false;
  bool _polling = false;
  bool _done = false;
  int _renewals = 0;
  String? _error;
  String? _notice;

  AuthNotifier get _auth => ref.read(authProvider.notifier);

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = ref.read(authProvider).user?.phone ?? '';
  }

  @override
  void dispose() {
    _stop();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _stop() {
    _poll?.cancel();
    _tick?.cancel();
    _poll = _tick = null;
  }

  Future<void> _start({bool renewed = false}) async {
    if (_phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length < 8) {
      setState(() => _error = '8 оронтой утасны дугаараа бүтэн оруулна уу.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await _auth.startProfileVerification(_phoneCtrl.text);
      if (!mounted) return;
      setState(() {
        _session = s;
        _notice = renewed
            ? 'Өмнөх код хүчингүй боллоо. Доорх ШИНЭ мессежийг илгээнэ үү.'
            : null;
      });
      _stop();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
    } on AuthFlowException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    final id = _session?.id;
    if (id == null || _polling) return;
    _polling = true;
    try {
      final s = await _auth.checkProfileVerification(id);
      if (!mounted || s.isPending) return;
      _stop();
      if (s.isVerified) {
        setState(() => _done = true);
      } else if (_renewals < 2) {
        _renewals++;
        await _start(renewed: true);
      } else {
        setState(() {
          _session = s;
          _notice =
              'Хугацаа дууслаа. "Шинэ мессеж авах" дээр дарж дахин оролдоно уу.';
        });
      }
    } on AuthFlowException {
      // transient — the next tick retries
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Дугаар баталгаажуулах'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_done) ...[
                const SizedBox(height: 24),
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF34D399),
                  size: 72,
                ),
                const SizedBox(height: 16),
                const AuthTitle(
                  'Баталгаажлаа!',
                  sub:
                      'Таны утасны дугаар баталгаажлаа. ПИН кодоо мартсан ч SMS-ээр сэргээх боломжтой боллоо.',
                ),
                PrimaryButton(label: 'Буцах', onTap: () => context.pop()),
              ] else if (s == null) ...[
                const AuthTitle(
                  'Дугаараа баталгаажуулах',
                  sub:
                      'Нэг мессеж илгээгээд дугаараа баталгаажуулна. Ингэснээр бүртгэл тань илүү найдвартай болж, ПИН кодоо мартвал SMS-ээр сэргээнэ.',
                ),
                const AuthLabel('Утасны дугаар'),
                AuthInput(
                  controller: _phoneCtrl,
                  hint: '9911 2233',
                  keyboardType: TextInputType.phone,
                  letterSpacing: 1.5,
                  onSubmitted: (_) => _start(),
                ),
                if (_error != null) AuthErrorText(_error!),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _busy ? 'Түр хүлээнэ үү…' : 'Үргэлжлүүлэх',
                  onTap: _busy ? null : () => _start(),
                ),
              ] else ...[
                const AuthTitle('Нэг мессеж илгээнэ үү'),
                if (_notice != null) AuthBanner(_notice!),
                if (s.isPending)
                  SmsWaitPanel(
                    session: s,
                    onError: (m) => setState(() => _error = m),
                  )
                else
                  PrimaryButton(
                    label: 'Шинэ мессеж авах',
                    onTap: _busy
                        ? null
                        : () {
                            _renewals = 0;
                            _start(renewed: true);
                          },
                  ),
                if (_error != null) AuthErrorText(_error!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
