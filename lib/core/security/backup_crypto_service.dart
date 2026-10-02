import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class BackupCryptoService {
  static const String prefix = 'ENVOPS_ENC_V1:';
  static const int _pbkdf2Iterations = 10000;
  static const int _keyLength = 32; // 256 bits

  static String encrypt(String plainText, String password) {
    if (password.trim().isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }

    final rng = Random.secure();
    final salt = Uint8List(16);
    final iv = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      salt[i] = rng.nextInt(256);
      iv[i] = rng.nextInt(256);
    }

    // Derive 256-bit key using PBKDF2 with SHA-256
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
    final key = pbkdf2.process(Uint8List.fromList(utf8.encode(password)));

    // AES-CBC with PKCS7 padding
    final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );

    final inputBytes = Uint8List.fromList(utf8.encode(plainText));
    final encryptedBytes = cipher.process(inputBytes);

    // Payload structure: [16 bytes salt] + [16 bytes iv] + [ciphertext]
    final combined = Uint8List(salt.length + iv.length + encryptedBytes.length);
    combined.setRange(0, 16, salt);
    combined.setRange(16, 32, iv);
    combined.setRange(32, combined.length, encryptedBytes);

    return '$prefix${base64.encode(combined)}';
  }

  static String decrypt(String encryptedPayload, String password) {
    if (password.trim().isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }

    var cleanPayload = encryptedPayload.trim();
    final isEnvOps = cleanPayload.startsWith(prefix);
    final isLegacy = cleanPayload.startsWith('CASOPS_ENC_V1:');
    if (!isEnvOps && !isLegacy) {
      throw const FormatException('Invalid backup format: missing ENVOPS_ENC_V1 prefix');
    }

    final activePrefix = isEnvOps ? prefix : 'CASOPS_ENC_V1:';
    cleanPayload = cleanPayload.substring(activePrefix.length).trim();
    final combined = base64.decode(cleanPayload);

    if (combined.length < 32) {
      throw const FormatException('Corrupted backup payload: insufficient length');
    }

    final salt = combined.sublist(0, 16);
    final iv = combined.sublist(16, 32);
    final cipherBytes = combined.sublist(32);

    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
    final key = pbkdf2.process(Uint8List.fromList(utf8.encode(password)));

    try {
      final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
        ..init(
          false,
          PaddedBlockCipherParameters(
            ParametersWithIV(KeyParameter(key), iv),
            null,
          ),
        );

      final decryptedBytes = cipher.process(Uint8List.fromList(cipherBytes));
      return utf8.decode(decryptedBytes);
    } catch (_) {
      throw const FormatException('Decryption failed. Incorrect master password or corrupted backup.');
    }
  }
}
