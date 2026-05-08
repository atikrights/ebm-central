import 'package:encrypt/encrypt.dart' as encrypt_pkg;

class EncryptionHelper {
  // AES-256 requires a 32-byte key.
  // ⚠️ This MUST match EBM_ENCRYPTION_KEY in backend/.env exactly.
  static final encrypt_pkg.Key _key = encrypt_pkg.Key.fromUtf8('888c8bc11652ba9c2674765e1425f1a2');
  
  // Initialization Vector (IV) for CBC mode, usually 16 bytes.
  static final encrypt_pkg.IV _iv = encrypt_pkg.IV.fromLength(16);

  // Initialize the encrypter with AES in CBC mode
  static final encrypt_pkg.Encrypter _encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(_key, mode: encrypt_pkg.AESMode.cbc));

  /// Encrypts plain text using AES-256-CBC and returns a base64 encoded string
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      return plainText; 
    }
  }

  /// Decrypts a base64 encoded string back to plain text
  static String decrypt(String encryptedText) {
    if (encryptedText.isEmpty) return '';
    try {
      final decrypted = _encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      return "Decryption Failed";
    }
  }
}
