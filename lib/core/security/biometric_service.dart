import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth;

  BiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Authenticate to access EnvOps'}) async {
    try {
      final available = await canCheckBiometrics();
      if (!available) return true; // If device doesn't support biometric/PIN, let pass

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // Allows device PIN/pattern fallback
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
