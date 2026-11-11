import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../shared/widgets/lemony_logo.dart';
import 'auth_widgets.dart';

/// Sign in and sign up are one flow: phone number, then a 4-digit PIN.
///  - known number with a PIN  → enter PIN
///  - new number               → create a PIN (number is verified later, in Profile)
///  - known number, no PIN yet → one SMS proves the number, then create a PIN
///    (also used for "forgot PIN")
/// Google, Apple (iOS) and email stay available below.
enum _Step { phone, pin, createPin, sms, setPin, email, emailRegister }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Step _step = _Step.phone;
  String? _error;
  String? _notice;
  bool _busy = false;
  bool _googleBusy = false;
  bool _appleBusy = false;

  // Phone + PIN
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _pin2Ctrl = TextEditingController();
  String _phone = ''; // digits only; the server normalizes too

  // SMS
  PhoneSession? _session;
  Timer? _poll;
  Timer? _tick;
  int _renewals = 0;
  bool _polling = false;
  bool _forgot = false;

  // Email
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _regNameCtrl = TextEditingController();
  bool _obscure = true;

  AuthNotifier get _auth => ref.read(authProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = ref.read(authProvider).forcedLogoutMessage;
      if (msg != null && mounted) {
        _auth.consumeForcedLogoutMessage();
        setState(() => _notice = msg);
      }
    });
  }

  @override
  void dispose() {
    _stopTimers();
    for (final c in [
      _phoneCtrl,
      _pinCtrl,
      _pin2Ctrl,
      _emailCtrl,
      _passCtrl,
      _regNameCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(_Step next) => setState(() {
    _error = null;
    _step = next;
  });

  void _stopTimers() {
    _poll?.cancel();
    _tick?.cancel();
    _poll = _tick = null;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthFlowException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Phone → what next ────────────────────────────────────────────────────

  Future<void> _submitPhone() async {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    // Explain instead of greying the button out — a dead button just looks broken.
    if (digits.length < 8) {
      setState(() => _error = '8 оронтой утасны дугаараа бүтэн оруулна уу.');
      return;
    }
    await _run(() async {
      final next = await _auth.checkPhone(_phoneCtrl.text);
      if (!mounted) return;
      _phone = digits;
      _pinCtrl.clear();
      _pin2Ctrl.clear();
      _notice = null;
      switch (next) {
        case 'pin':
          _go(_Step.pin);
        case 'create':
          _go(_Step.createPin);
        default:
          _forgot = false;
          _renewals = 0;
          await _startSms();
      }
    });
  }

  // ── PIN ──────────────────────────────────────────────────────────────────

  Future<void> _submitPin() async {
    if (_pinCtrl.text.length != 4) {
      setState(() => _error = '4 оронтой ПИН кодоо оруулна уу.');
      return;
    }
    await _run(() => _auth.loginWithPin(_phone, _pinCtrl.text));
    if (mounted && _error != null) _pinCtrl.clear();
  }

  String? _pinPairError() {
    if (_pinCtrl.text.length != 4) return '4 оронтой ПИН код үүсгэнэ үү.';
    if (_pin2Ctrl.text != _pinCtrl.text) {
      return 'ПИН код таарахгүй байна. Дахин оруулна уу.';
    }
    return null;
  }

  Future<void> _submitCreatePin() async {
    final err = _pinPairError();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    await _run(() => _auth.registerWithPin(_phone, _pinCtrl.text));
  }

  Future<void> _submitSetPin() async {
    final err = _pinPairError();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final v = _session?.verification;
    if (v == null) return;
    await _run(() => _auth.completeSms(v, _pinCtrl.text));
  }

  // ── SMS (no PIN yet / forgot PIN) ────────────────────────────────────────

  Future<void> _forgotPin() async {
    _forgot = true;
    _renewals = 0;
    await _run(_startSms);
  }

  Future<void> _startSms({bool renewed = false}) async {
    final s = await _auth.startSms(_phone);
    if (!mounted) return;
    setState(() {
      _session = s;
      _notice = renewed
          ? 'Өмнөх код хүчингүй боллоо. Доорх ШИНЭ мессежийг илгээнэ үү.'
          : null;
    });
    _go(_Step.sms);
    _stopTimers();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _checkSms());
  }

  Future<void> _checkSms() async {
    final v = _session?.verification;
    if (v == null || _polling || _step != _Step.sms) return;
    _polling = true;
    try {
      final s = await _auth.checkSms(v);
      if (!mounted || s.isPending) return;
      _stopTimers();
      setState(() => _session = s);
      if (s.isVerified) {
        _pinCtrl.clear();
        _pin2Ctrl.clear();
        _notice = null;
        _go(_Step.setPin);
      } else if (s.isOver) {
        // Expired: a new code (twice automatically), then ask.
        if (_renewals < 2) {
          _renewals++;
          await _run(() => _startSms(renewed: true));
        } else {
          setState(
            () => _notice =
                'Хугацаа дууслаа. "Шинэ мессеж авах" дээр дарж дахин оролдоно уу.',
          );
        }
      }
    } on AuthFlowException {
      // transient — the next tick retries
    } finally {
      _polling = false;
    }
  }

  // ── Google / Apple / Email ───────────────────────────────────────────────

  Future<void> _google() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    final ok = await _auth.signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleBusy = false);
    if (!ok) {
      setState(
        () => _error =
            ref.read(authProvider).error ??
            'Google нэвтрэлт цуцлагдсан эсвэл амжилтгүй боллоо.',
      );
    }
  }

  Future<void> _apple() async {
    setState(() {
      _appleBusy = true;
      _error = null;
    });
    final ok = await _auth.signInWithApple();
    if (!mounted) return;
    setState(() => _appleBusy = false);
    if (!ok) {
      setState(
        () => _error =
            ref.read(authProvider).error ?? 'Apple нэвтрэлт амжилтгүй боллоо.',
      );
    }
  }

  Future<void> _emailLogin() async {
    if (!_emailCtrl.text.contains('@') || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Имэйл болон нууц үгээ оруулна уу.');
      return;
    }
    setState(() => _error = null);
    final ok = await _auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!ok && mounted) {
      _passCtrl.clear();
      setState(
        () =>
            _error = ref.read(authProvider).error ?? 'Нэвтрэхэд алдаа гарлаа.',
      );
    }
  }

  Future<void> _emailRegister() async {
    if (_regNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Нэрээ оруулна уу.');
      return;
    }
    if (!_emailCtrl.text.contains('@')) {
      setState(() => _error = 'Зөв имэйл оруулна уу.');
      return;
    }
    if (_passCtrl.text.length < 8) {
      setState(() => _error = 'Нууц үг хамгийн багадаа 8 тэмдэгт байна.');
      return;
    }
    setState(() => _error = null);
    final ok = await _auth.register(
      _regNameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    if (!ok && mounted) {
      setState(
        () => _error =
            ref.read(authProvider).error ?? 'Бүртгүүлэхэд алдаа гарлаа.',
      );
    }
  }

  // ── Back handling ────────────────────────────────────────────────────────

  _Step? get _backStep => switch (_step) {
    _Step.phone => null,
    _Step.pin || _Step.createPin => _Step.phone,
    _Step.sms => _forgot ? _Step.pin : _Step.phone,
    _Step.setPin => null, // number already proven — only forward
    _Step.email => _Step.phone,
    _Step.emailRegister => _Step.email,
  };

  void _back() {
    final to = _backStep;
    if (to == null) return;
    if (_step == _Step.sms) {
      _stopTimers();
      _session = null;
      _notice = null;
    }
    _pinCtrl.clear();
    _pin2Ctrl.clear();
    _go(to);
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final emailLoading = ref.watch(authProvider.select((s) => s.isLoading));

    return PopScope(
      canPop: _step == _Step.phone,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const AuthGlow(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_backStep != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: AuthBackButton(
                              label:
                                  _step == _Step.pin ||
                                      _step == _Step.createPin ||
                                      (_step == _Step.sms && !_forgot)
                                  ? 'Дугаар солих'
                                  : 'Буцах',
                              onTap: _back,
                            ),
                          ),
                        if (_notice != null) AuthBanner(_notice!),
                        ...switch (_step) {
                          _Step.phone => _phoneStep(),
                          _Step.pin => _pinStep(),
                          _Step.createPin => _createPinStep(),
                          _Step.sms => _smsStep(),
                          _Step.setPin => _setPinStep(),
                          _Step.email => _emailStep(emailLoading),
                          _Step.emailRegister => _registerStep(emailLoading),
                        },
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _prettyPhone => _phone.length == 8
      ? '${_phone.substring(0, 4)} ${_phone.substring(4)}'
      : _phone;

  List<Widget> _phoneStep() => [
    const SizedBox(height: 28),
    const Center(child: LemonyLogo(size: 76)),
    const SizedBox(height: 32),
    const AuthTitle(
      'Тавтай морил',
      sub: 'Утасны дугаараа оруулаад 4 оронтой ПИН кодоор нэвтэрнэ.',
    ),
    const AuthLabel('Утасны дугаар'),
    AuthInput(
      controller: _phoneCtrl,
      hint: '9911 2233',
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumber],
      letterSpacing: 1.5,
      onSubmitted: (_) => _submitPhone(),
    ),
    if (_error != null) AuthErrorText(_error!),
    const SizedBox(height: 16),
    PrimaryButton(
      label: _busy ? 'Түр хүлээнэ үү…' : 'Үргэлжлүүлэх',
      onTap: _busy ? null : _submitPhone,
    ),
    const AuthDivider(),
    SecondaryButton(
      onTap: _googleBusy ? null : _google,
      icon: Image.asset(
        'assets/images/google_logo.webp',
        width: 22,
        height: 22,
      ),
      label: _googleBusy ? 'Түр хүлээнэ үү…' : 'Google-ээр нэвтрэх',
    ),
    if (Platform.isIOS) ...[
      const SizedBox(height: 12),
      SecondaryButton(
        onTap: _appleBusy ? null : _apple,
        icon: const Icon(Icons.apple, color: Colors.white, size: 24),
        label: _appleBusy ? 'Түр хүлээнэ үү…' : 'Apple-ээр нэвтрэх',
      ),
    ],
    const SizedBox(height: 12),
    SecondaryButton(
      onTap: () => _go(_Step.email),
      icon: const Icon(Icons.mail_outline_rounded, color: Colors.white),
      label: 'Имэйлээр нэвтрэх',
    ),
  ];

  List<Widget> _pinStep() => [
    AuthTitle('ПИН кодоо оруулна уу', sub: '$_prettyPhone дугаартай бүртгэл'),
    PinInput(
      controller: _pinCtrl,
      autofocus: true,
      onCompleted: (_) => _submitPin(),
    ),
    if (_error != null) AuthErrorText(_error!),
    const SizedBox(height: 16),
    PrimaryButton(
      label: _busy ? 'Нэвтэрч байна…' : 'Нэвтрэх',
      onTap: _busy ? null : _submitPin,
    ),
    const SizedBox(height: 12),
    Center(
      child: LinkText(
        'ПИН кодоо мартсан уу?',
        muted: true,
        onTap: _busy ? null : _forgotPin,
      ),
    ),
  ];

  List<Widget> _pinPair({required String button, required VoidCallback go}) => [
    const AuthLabel('ПИН код'),
    PinInput(controller: _pinCtrl, autofocus: true),
    const SizedBox(height: 16),
    const AuthLabel('ПИН кодоо давтана уу'),
    PinInput(controller: _pin2Ctrl, onCompleted: (_) => go()),
    if (_error != null) AuthErrorText(_error!),
    const SizedBox(height: 16),
    PrimaryButton(
      label: _busy ? 'Түр хүлээнэ үү…' : button,
      onTap: _busy ? null : go,
    ),
    const SizedBox(height: 12),
    const Text(
      'ПИН кодоо бусдад бүү хэлээрэй. 1234, 0000 гэх мэт амархан код бүү сонгоорой.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 14, height: 1.5),
    ),
  ];

  List<Widget> _createPinStep() => [
    AuthTitle(
      'ПИН код үүсгэх',
      sub:
          '$_prettyPhone дугаартаа 4 оронтой ПИН код үүсгэнэ үү. Дараа нэвтрэхэд энэ код хэрэгтэй.',
    ),
    ..._pinPair(button: 'Үргэлжлүүлэх', go: _submitCreatePin),
  ];

  List<Widget> _setPinStep() => [
    AuthBanner('$_prettyPhone дугаар баталгаажлаа!', ok: true),
    AuthTitle(
      _forgot ? 'Шинэ ПИН код' : 'ПИН код үүсгэх',
      sub: 'Дараа нэвтрэхэд энэ 4 оронтой код хэрэгтэй.',
    ),
    ..._pinPair(button: 'Хадгалаад нэвтрэх', go: _submitSetPin),
  ];

  List<Widget> _smsStep() {
    final s = _session;
    if (s == null) return const [];
    return [
      AuthTitle(
        'Нэг мессеж илгээнэ үү',
        sub: _forgot
            ? 'ПИН кодоо шинэчлэхийн тулд $_prettyPhone дугаараа баталгаажуулна.'
            : 'Таны бүртгэл олдлоо. Анх удаа апп-аар нэвтэрч байгаа тул дугаараа баталгаажуулаад ПИН код үүсгэнэ.',
      ),
      if (s.isPending)
        SmsWaitPanel(session: s, onError: (m) => setState(() => _error = m))
      else
        PrimaryButton(
          label: 'Шинэ мессеж авах',
          onTap: _busy
              ? null
              : () {
                  _renewals = 0;
                  _run(() => _startSms(renewed: true));
                },
        ),
      if (_error != null) AuthErrorText(_error!),
    ];
  }

  List<Widget> _emailStep(bool loading) => [
    const AuthTitle('Имэйлээр нэвтрэх'),
    const AuthLabel('Имэйл'),
    AuthInput(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.username],
      autofocus: true,
    ),
    const SizedBox(height: 16),
    const AuthLabel('Нууц үг'),
    AuthInput(
      controller: _passCtrl,
      obscure: _obscure,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      autofillHints: const [AutofillHints.password],
      onSubmitted: (_) => _emailLogin(),
    ),
    if (_error != null) AuthErrorText(_error!),
    const SizedBox(height: 16),
    PrimaryButton(
      label: loading ? 'Нэвтэрч байна…' : 'Нэвтрэх',
      onTap: loading ? null : _emailLogin,
    ),
    const SizedBox(height: 20),
    Center(
      child: LinkText(
        'Имэйлээр шинээр бүртгүүлэх',
        muted: true,
        onTap: () => _go(_Step.emailRegister),
      ),
    ),
  ];

  List<Widget> _registerStep(bool loading) => [
    const AuthTitle('Имэйлээр бүртгүүлэх'),
    const AuthLabel('Нэр'),
    AuthInput(
      controller: _regNameCtrl,
      autofocus: true,
      autofillHints: const [AutofillHints.name],
    ),
    const SizedBox(height: 16),
    const AuthLabel('Имэйл'),
    AuthInput(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
    ),
    const SizedBox(height: 16),
    const AuthLabel('Нууц үг'),
    AuthInput(
      controller: _passCtrl,
      obscure: _obscure,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      autofillHints: const [AutofillHints.newPassword],
      onSubmitted: (_) => _emailRegister(),
    ),
    if (_error == null)
      const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text(
          'Хамгийн багадаа 8 тэмдэгт',
          style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 14),
        ),
      ),
    if (_error != null) AuthErrorText(_error!),
    const SizedBox(height: 16),
    PrimaryButton(
      label: loading ? 'Түр хүлээнэ үү…' : 'Бүртгүүлэх',
      onTap: loading ? null : _emailRegister,
    ),
  ];
}
