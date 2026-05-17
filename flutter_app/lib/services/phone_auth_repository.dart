import '../core/networking/api_client.dart';
import '../core/networking/token_store.dart';
import '../models/worker_dto.dart';

class PhoneNumber {
  const PhoneNumber({this.countryCode = '+91', required this.national});
  final String countryCode;
  final String national;

  /// E.164 — same as iOS PhoneNumber.e164
  String get e164 {
    final digits = national.replaceAll(RegExp(r'\D'), '');
    return '$countryCode$digits';
  }

  bool get isValid => national.replaceAll(RegExp(r'\D'), '').length >= 10;
}

class PhoneAuthException implements Exception {
  PhoneAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Mirrors APIPhoneAuthRepository.swift.
class PhoneAuthRepository {
  Future<void> sendCode(PhoneNumber phone) async {
    if (!phone.isValid) throw PhoneAuthException('Please enter a valid phone number.');
    try {
      await ApiClient.instance.request<Map<String, dynamic>>(
        HttpMethod.post,
        '/auth/otp/send',
        body: {'phone': phone.e164},
        authenticated: false,
        decode: (j) => (j as Map<String, dynamic>?) ?? {},
      );
    } on ApiException catch (e) {
      throw PhoneAuthException("Couldn't send the code: ${e.message}");
    } catch (e) {
      throw PhoneAuthException("Couldn't send the code: $e");
    }
  }

  Future<TokenResponse> verify(String code, PhoneNumber phone) async {
    if (!phone.isValid) throw PhoneAuthException('Please enter a valid phone number.');
    try {
      final j = await ApiClient.instance.request<Map<String, dynamic>>(
        HttpMethod.post,
        '/auth/otp/verify',
        body: {'phone': phone.e164, 'otp': code.trim()},
        authenticated: false,
        decode: (json) => json as Map<String, dynamic>,
      );
      final token = TokenResponse.fromJson(j);
      await TokenStore.instance.save(token.accessToken, workerId: token.workerID);
      return token;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 400) {
        throw PhoneAuthException("That code doesn't match. Try again.");
      }
      throw PhoneAuthException('Verification failed: ${e.message}');
    } catch (e) {
      throw PhoneAuthException('Verification failed: $e');
    }
  }
}
