import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/auth_provider.dart';
import '../../shared/widgets/lemony_logo.dart';

/// Building blocks shared by the sign-in flow and the profile phone verification.
/// Large type and labels that stay visible — built for older viewers too (same as the web).

InputDecoration authInputDecoration(String? hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFF52525B)),
  filled: true,
  fillColor: Colors.black,
  counterText: '',
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(
      color: Colors.white.withValues(alpha: 0.15),
      width: 2,
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Colors.white, width: 2),
  ),
);

class AuthGlow extends StatelessWidget {
  const AuthGlow({super.key});
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Positioned(
      top: -h * 0.15,
      left: 0,
      right: 0,
      child: Container(
        height: h * 0.6,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              LemonyBrand.rose.withValues(alpha: 0.16),
              Colors.transparent,
            ],
            radius: 0.75,
          ),
        ),
      ),
    );
  }
}

class AuthTitle extends StatelessWidget {
  final String text;
  final String? sub;
  const AuthTitle(this.text, {super.key, this.sub});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 8),
          Text(
            sub!,
            style: const TextStyle(
              color: Color(0xFFD4D4D8),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ],
    ),
  );
}

class AuthLabel extends StatelessWidget {
  final String text;
  const AuthLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class AuthInput extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final ValueChanged<String>? onSubmitted;
  final double letterSpacing;

  const AuthInput({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.autofillHints,
    this.autofocus = false,
    this.obscure = false,
    this.onToggleObscure,
    this.onSubmitted,
    this.letterSpacing = 0,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    autofillHints: autofillHints,
    autofocus: autofocus,
    obscureText: obscure,
    onSubmitted: onSubmitted,
    style: TextStyle(
      color: Colors.white,
      fontSize: 18,
      letterSpacing: letterSpacing,
    ),
    decoration: authInputDecoration(hint).copyWith(
      suffixIcon: onToggleObscure == null
          ? null
          : TextButton.icon(
              onPressed: onToggleObscure,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD4D4D8),
              ),
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
              ),
              label: Text(obscure ? 'Харах' : 'Нуух'),
            ),
    ),
  );
}

/// 4-digit PIN, shown as dots with large spacing.
class PinInput extends StatelessWidget {
  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String>? onCompleted;
  const PinInput({
    super.key,
    required this.controller,
    this.autofocus = false,
    this.onCompleted,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    obscureText: true,
    obscuringCharacter: '●',
    keyboardType: TextInputType.number,
    textAlign: TextAlign.center,
    maxLength: 4,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: (v) {
      if (v.length == 4) onCompleted?.call(v);
    },
    style: const TextStyle(
      color: Colors.white,
      fontSize: 30,
      fontWeight: FontWeight.w900,
      letterSpacing: 24,
    ),
    decoration: authInputDecoration('••••'),
  );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const PrimaryButton({super.key, required this.label, this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.45 : 1,
    child: Material(
      color: Colors.transparent,
      child: Ink(
        height: 56,
        decoration: BoxDecoration(
          gradient: LemonyBrand.gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  const SecondaryButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.45 : 1,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AuthBackButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const AuthBackButton({super.key, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFD4D4D8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 22),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'эсвэл',
            style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 15),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
      ],
    ),
  );
}

class LinkText extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool muted;
  const LinkText(this.text, {super.key, this.onTap, this.muted = false});
  @override
  Widget build(BuildContext context) {
    final color = muted ? const Color(0xFFA1A1AA) : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: color,
          ),
        ),
      ),
    );
  }
}

class AuthBanner extends StatelessWidget {
  final String text;
  final bool ok;
  const AuthBanner(this.text, {super.key, this.ok = false});
  @override
  Widget build(BuildContext context) {
    final c = ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: ok ? const Color(0xFFA7F3D0) : const Color(0xFFFEF3C7),
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }
}

class AuthErrorText extends StatelessWidget {
  final String text;
  const AuthErrorText(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFFFCA5A5),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

/// The "send one SMS" panel: verify.mn's instruction word for word, a button that opens the
/// messages app with everything filled in, a countdown, and the same tips as the web.
class SmsWaitPanel extends StatelessWidget {
  final PhoneSession session;
  final ValueChanged<String> onError;
  const SmsWaitPanel({super.key, required this.session, required this.onError});

  Future<void> _openSms() async {
    final uri = session.smsUri;
    if (uri == null) return;
    const msg = 'Мессеж апп нээгдсэнгүй. Дээрх мессежийг гараар илгээнэ үү.';
    try {
      final ok = await launchUrl(
        Uri.parse(uri),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) onError(msg);
    } catch (_) {
      onError(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = session.expiresAt == null
        ? 0
        : session.expiresAt!
              .difference(DateTime.now())
              .inSeconds
              .clamp(0, 99999);
    final mm = left ~/ 60, ss = (left % 60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session.displayInstruction != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              session.displayInstruction!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        const SizedBox(height: 20),
        if (session.smsUri != null)
          PrimaryButton(
            label: 'SMS илгээх',
            icon: Icons.sms_outlined,
            onTap: _openSms,
          ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Мессеж хүлээж байна… $mm:$ss',
              style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NumberedLine(
                '1.',
                'Дээр бичсэн дугаартай утаснаасаа илгээнэ үү.',
              ),
              _NumberedLine(
                '2.',
                'Нэг л удаа илгээхэд хангалттай (операторын төлбөр 150₮).',
              ),
              _NumberedLine(
                '3.',
                'Энэ дэлгэцийг хааж болохгүй — өөрөө үргэлжилнэ.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberedLine extends StatelessWidget {
  final String n;
  final String text;
  const _NumberedLine(this.n, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$n ',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFD4D4D8),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
