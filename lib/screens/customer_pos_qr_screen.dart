import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

/// Shows a short-lived, single-use signed QR token the cashier scans to grant
/// points at checkout. The token is refreshed automatically before it expires
/// so the customer never sees a stale/expired code.
class CustomerPosQrScreen extends StatefulWidget {
  const CustomerPosQrScreen({super.key});

  @override
  State<CustomerPosQrScreen> createState() => _CustomerPosQrScreenState();
}

class _CustomerPosQrScreenState extends State<CustomerPosQrScreen> {
  String? _token;
  DateTime? _expiresAt;
  String? _error;
  bool _loading = true;
  Timer? _countdownTimer;
  Timer? _refreshTimer;
  int _secondsLeft = 0;

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  @override
  void initState() {
    super.initState();
    _fetchToken();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchToken() async {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await CompanyServerService.getPosGrantQrToken();
      final token = (data['token'] ?? '').toString();
      final expiresInSeconds = (data['expiresInSeconds'] as num?)?.toInt() ?? 90;
      final expiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));
      if (!mounted) return;
      setState(() {
        _token = token;
        _expiresAt = expiresAt;
        _secondsLeft = expiresInSeconds;
        _loading = false;
      });
      _startCountdown();
      // Regenerate a couple of seconds before actual expiry so a scan is never rejected
      // for arriving right as the previous token expired.
      final refreshDelay = Duration(seconds: expiresInSeconds > 3 ? expiresInSeconds - 3 : expiresInSeconds);
      _refreshTimer = Timer(refreshDelay, _fetchToken);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final expiresAt = _expiresAt;
      if (expiresAt == null) return;
      final remaining = expiresAt.difference(DateTime.now()).inSeconds;
      setState(() {
        _secondsLeft = remaining > 0 ? remaining : 0;
      });
      if (remaining <= 0) {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kIndigo,
      appBar: AppBar(
        title: Text(_tx('pos_qr_title', 'Show this QR to the cashier')),
        backgroundColor: kIndigo,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                const CircularProgressIndicator(color: kGold)
              else if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: kBodyTextStyle(size: 14, weight: FontWeight.w600, color: kGold),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchToken,
                  child: Text(_tx('retry', 'Retry')),
                ),
              ] else if (_token != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(data: _token!, size: 240),
                ),
                const SizedBox(height: 20),
                Text(
                  _tx('pos_qr_expires_in', 'Expires in {seconds}s').replaceAll('{seconds}', '$_secondsLeft'),
                  style: kBodyTextStyle(size: 14, weight: FontWeight.w600, color: kWhite),
                ),
                const SizedBox(height: 8),
                Text(
                  _tx('pos_qr_auto_refresh_note', 'This code refreshes automatically and can only be used once.'),
                  textAlign: TextAlign.center,
                  style: kBodyTextStyle(size: 12, weight: FontWeight.w400, color: kWhite),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
