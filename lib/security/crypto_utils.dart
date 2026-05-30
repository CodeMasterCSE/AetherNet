import 'dart:convert';
import 'package:crypto/crypto.dart';

class CryptoUtils {
  static String generateHash(String payload) {
    var bytes = utf8.encode(payload);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool verifyHash(String payload, String hash) {
    return generateHash(payload) == hash;
  }
}
