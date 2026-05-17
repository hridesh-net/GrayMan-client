import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/blobs.dart';
import '../../core/design_system/press_scale.dart';
import '../../services/phone_auth_repository.dart';

enum _AuthStage { phone, otp }

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, required this.onBack, required this.onNext});
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _repo = PhoneAuthRepository();
  _AuthStage _stage = _AuthStage.phone;
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  PhoneNumber get _phone => PhoneNumber(national: _phoneCtrl.text.replaceAll(RegExp(r'\D'), ''));

  Future<void> _sendOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _repo.sendCode(_phone);
      setState(() => _stage = _AuthStage.otp);
    } on PhoneAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _repo.verify(_otpCtrl.text.trim(), _phone);
      widget.onNext();
    } on PhoneAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Blobs(accent: theme.accent),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
                  const SizedBox(height: 24),
                  Text(theme.t('Your phone number', 'आपका फ़ोन नंबर'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.shadowGrey)),
                  const SizedBox(height: 8),
                  Text(theme.t('We will send a 6-digit OTP', 'हम 6 अंकों का OTP भेजेंगे'), style: const TextStyle(color: AppColors.mutedText)),
                  const SizedBox(height: 32),
                  if (_stage == _AuthStage.phone) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
                          child: const Text('+91', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(counterText: '', hintText: theme.t('10-digit mobile', '10 अंकों का मोबाइल'), filled: true, fillColor: AppColors.soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    TextField(
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(counterText: '', hintText: '• • • • • •', filled: true, fillColor: AppColors.soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
                  ],
                  const Spacer(),
                  PressScaleButton(
                    onPressed: _loading ? null : (_stage == _AuthStage.phone ? _sendOtp : _verify),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(16)),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(theme.t(_stage == _AuthStage.phone ? 'Send OTP' : 'Verify', _stage == _AuthStage.phone ? 'OTP भेजें' : 'सत्यापित करें'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
