import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

enum _Stage { creating, qr, paid, error }

class QPaySheet extends ConsumerStatefulWidget {
  final double amount;
  final String description;
  final String invoiceType; // 'subscription' or 'rental'
  final int? planId;
  final String? rentableType;
  final int? rentableId;
  final int rentalDurationHours;
  final VoidCallback onSuccess;

  const QPaySheet({
    super.key,
    required this.amount,
    required this.description,
    required this.invoiceType,
    this.planId,
    this.rentableType,
    this.rentableId,
    this.rentalDurationHours = 72,
    required this.onSuccess,
  });

  @override
  ConsumerState<QPaySheet> createState() => _QPaySheetState();

  static Future<void> show({
    required BuildContext context,
    required double amount,
    required String description,
    required String invoiceType,
    int? planId,
    String? rentableType,
    int? rentableId,
    int rentalDurationHours = 72,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => QPaySheet(
        amount: amount,
        description: description,
        invoiceType: invoiceType,
        planId: planId,
        rentableType: rentableType,
        rentableId: rentableId,
        rentalDurationHours: rentalDurationHours,
        onSuccess: onSuccess,
      ),
    );
  }
}

class _QPaySheetState extends ConsumerState<QPaySheet>
    with SingleTickerProviderStateMixin {
  _Stage _stage = _Stage.creating;
  String? _qrImageBase64;
  List<_BankUrl> _bankUrls = [];
  int? _localInvoiceId;
  String? _errorMsg;
  bool _checking = false;
  Timer? _pollTimer;

  late AnimationController _successAnim;

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _createInvoice();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _successAnim.dispose();
    super.dispose();
  }

  Future<void> _createInvoice() async {
    _pollTimer?.cancel();
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post<Map<String, dynamic>>(
        ApiEndpoints.qpayCreateInvoice,
        data: {
          'invoice_description': widget.description,
          'amount': widget.amount,
          'invoice_type': widget.invoiceType,
          if (widget.planId != null) 'plan_id': widget.planId,
          if (widget.rentableType != null) 'rentable_type': widget.rentableType,
          if (widget.rentableId != null) 'rentable_id': widget.rentableId,
          'rental_duration_hours': widget.rentalDurationHours,
        },
      );

      final data = res.data!;
      if (data['success'] != true) {
        _showError(
          data['message'] as String? ?? 'Нэхэмжлэл үүсгэхэд алдаа гарлаа.',
        );
        return;
      }

      final payload = data['data'] as Map<String, dynamic>? ?? {};
      _localInvoiceId = _readInt(payload['local_id']);
      if (_localInvoiceId == null) {
        _showError('Нэхэмжлэлийн дугаар ирсэнгүй. Дахин оролдоно уу.');
        return;
      }

      final rawUrls = payload['urls'] as List<dynamic>? ?? [];
      setState(() {
        _qrImageBase64 = _normalizeQrImage(payload['qr_image'] as String?);
        _bankUrls = rawUrls
            .map((u) => _BankUrl.fromJson(u as Map<String, dynamic>))
            .toList();
        _stage = _Stage.qr;
      });

      _pollTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _checkPayment(),
      );
    } catch (e) {
      _showError(_messageFromError(e));
    }
  }

  Future<void> _checkPayment() async {
    if (_localInvoiceId == null) return;
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post<Map<String, dynamic>>(
        ApiEndpoints.qpayCheckPayment,
        data: {'invoice_id': _localInvoiceId},
      );
      if (res.data?['success'] == true) {
        _pollTimer?.cancel();
        setState(() => _stage = _Stage.paid);
        _successAnim.forward();
        await ref.read(authProvider.notifier).refreshUser();
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess();
        }
      } else if (res.data?['status'] == 'error') {
        _showError(
          res.data?['message'] as String? ?? 'Төлбөр шалгахад алдаа гарлаа.',
        );
      }
    } catch (e) {
      if (_checking) {
        _showError(_messageFromError(e));
      }
    }
  }

  Future<void> _manualCheck() async {
    setState(() => _checking = true);
    await _checkPayment();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              if (_stage != _Stage.paid)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: () {
                        _pollTimer?.cancel();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),

              _buildBody(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_stage) {
      _Stage.creating => _buildCreating(),
      _Stage.qr => _buildQR(),
      _Stage.paid => _buildPaid(),
      _Stage.error => _buildError(),
    };
  }

  Widget _buildCreating() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 2.5,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Нэхэмжлэл үүсгэж байна…',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildQR() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Text(
            'QPay төлбөр',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            '₮${widget.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // QR code
          if (_qrImageBase64 != null)
            Container(
              width: 190,
              height: 190,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _QrImage(imageBase64: _qrImageBase64!),
            ),

          if (_qrImageBase64 == null && _bankUrls.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'QPay нэхэмжлэл үүссэн боловч QR болон банкны холбоос ирсэнгүй.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],

          const SizedBox(height: 12),
          const Text(
            'QPay эсвэл банкны апп-аар уншуулна уу',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),

          // Bank app links
          if (_bankUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _bankUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _BankAppTile(bank: _bankUrls[i]),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Check button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _checking ? null : _manualCheck,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _checking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Төлбөр шалгах',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 10),
          const Text(
            'Төлбөр хийгдсэний дараа автоматаар шалгагдана',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPaid() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _successAnim,
            builder: (_, child) => Transform.scale(
              scale: 0.5 + _successAnim.value * 0.5,
              child: Opacity(opacity: _successAnim.value, child: child),
            ),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.shade700.withValues(alpha: 0.15),
                border: Border.all(color: Colors.green.shade600, width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.green,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Төлбөр амжилттай!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Таны захиалга баталгаажлаа.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.error_outline,
              color: AppTheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Алдаа гарлаа',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMsg ?? 'Тодорхойгүй алдаа.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              _pollTimer?.cancel();
              setState(() {
                _stage = _Stage.creating;
                _errorMsg = null;
                _localInvoiceId = null;
                _qrImageBase64 = null;
                _bankUrls = [];
              });
              _createInvoice();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Дахин оролдох'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    _pollTimer?.cancel();
    setState(() {
      _stage = _Stage.error;
      _errorMsg = message;
    });
  }

  String? _normalizeQrImage(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    final marker = 'base64,';
    final markerIndex = trimmed.indexOf(marker);
    return markerIndex >= 0
        ? trimmed.substring(markerIndex + marker.length)
        : trimmed;
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _messageFromError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return _translateServerMessage(message);
        }
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
          return first.toString();
        }
      }

      if (error.response?.statusCode == 401) {
        return 'Төлбөр төлөхийн тулд дахин нэвтэрнэ үү.';
      }
      if (error.response?.statusCode != null) {
        return 'Төлбөрийн хүсэлт ${error.response!.statusCode} төлөвтэй амжилтгүй боллоо.';
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Холболтын хугацаа дууслаа. Дахин оролдоно уу.';
        case DioExceptionType.connectionError:
          return 'Төлбөрийн сервертэй холбогдож чадсангүй.';
        case DioExceptionType.badCertificate:
          return 'Төлбөрийн SSL сертификат зөвшөөрөгдсөнгүй.';
        case DioExceptionType.cancel:
          return 'Төлбөрийн хүсэлт цуцлагдлаа.';
        case DioExceptionType.badResponse:
        case DioExceptionType.unknown:
          return error.message ?? 'Төлбөрийн алдаа гарлаа. Дахин оролдоно уу.';
      }
    }

    return 'Төлбөрийн алдаа гарлаа. Дахин оролдоно уу.';
  }

  String _translateServerMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('unauthenticated')) {
      return 'Төлбөр төлөхийн тулд дахин нэвтэрнэ үү.';
    }
    if (normalized.contains('selected plan id is invalid') ||
        normalized.contains('plan_id')) {
      return 'Сонгосон багц олдсонгүй. Багцуудыг дахин ачаална уу.';
    }
    if (normalized.contains('amount')) {
      return 'Төлбөрийн дүн буруу байна. Багцыг дахин сонгоно уу.';
    }
    return message;
  }
}

// ─── Data classes ──────────────────────────────────────────────────────────────

class _BankUrl {
  final String name;
  final String? logo;
  final String link;

  const _BankUrl({required this.name, this.logo, required this.link});

  factory _BankUrl.fromJson(Map<String, dynamic> j) => _BankUrl(
    name: (j['name'] as String?) ?? 'Банк',
    logo: j['logo'] as String?,
    link: (j['link'] as String?) ?? '',
  );
}

class _QrImage extends StatelessWidget {
  final String imageBase64;

  const _QrImage({required this.imageBase64});

  @override
  Widget build(BuildContext context) {
    try {
      return Image.memory(base64Decode(imageBase64), fit: BoxFit.contain);
    } catch (_) {
      return const Icon(
        Icons.qr_code_2_rounded,
        color: Colors.black54,
        size: 120,
      );
    }
  }
}

class _BankAppTile extends StatelessWidget {
  final _BankUrl bank;

  const _BankAppTile({required this.bank});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(bank.link);
        if (uri == null) return;
        try {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!launched && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${bank.name} апп суулгаагүй байна.')),
            );
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${bank.name} апп нээж чадсангүй.')),
            );
          }
        }
      },
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: bank.logo != null
                  ? Image.network(
                      bank.logo!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(height: 5),
            Text(
              bank.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(
      Icons.account_balance,
      color: AppTheme.textSecondary,
      size: 22,
    ),
  );
}
