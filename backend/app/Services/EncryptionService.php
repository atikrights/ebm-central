<?php

namespace App\Services;

/**
 * EBM AES-256-CBC Encryption Service
 * 
 * This service is designed to be COMPATIBLE with the Flutter 'encrypt' package
 * used in ebm-sp (Super Admin app). The same KEY and IV are used on both sides,
 * so keys encrypted by Flutter can be decrypted by this service and vice versa.
 * 
 * PRODUCTION NOTE: The ENCRYPTION_KEY and ENCRYPTION_IV must be stored in the
 * server's .env file and never committed to version control.
 * 
 * Algorithm: AES-256-CBC
 * Key Size: 32 bytes (256-bit)
 * IV Size:  16 bytes (128-bit)
 */
class EncryptionService
{
    // MUST MATCH Flutter's EncryptionHelper:
    // Key: 'ebm_production_secret_key_256bit' (32 chars = 256-bit)
    // IV:  16 zero bytes (fromLength(16) in Flutter generates zero-filled IV)
    private string $key;
    private string $iv;
    private string $cipher = 'aes-256-cbc';

    public function __construct()
    {
        // Load from .env — fallback to the same hardcoded value used in Flutter for now
        $this->key = env('EBM_ENCRYPTION_KEY', 'ebm_production_secret_key_256bit');
        $this->iv  = env('EBM_ENCRYPTION_IV', str_repeat("\0", 16)); // 16 zero bytes
    }

    /**
     * Encrypt a plain-text string.
     * Returns a Base64-encoded encrypted string.
     */
    public function encrypt(string $plainText): string
    {
        if (empty($plainText)) return '';

        $encrypted = openssl_encrypt(
            $plainText,
            $this->cipher,
            $this->key,
            OPENSSL_RAW_DATA,
            $this->iv
        );

        if ($encrypted === false) {
            throw new \RuntimeException('Encryption failed: ' . openssl_error_string());
        }

        return base64_encode($encrypted);
    }

    /**
     * Decrypt a Base64-encoded encrypted string.
     * Returns the original plain-text string.
     */
    public function decrypt(string $encryptedBase64): string
    {
        if (empty($encryptedBase64)) return '';

        $decrypted = openssl_decrypt(
            base64_decode($encryptedBase64),
            $this->cipher,
            $this->key,
            OPENSSL_RAW_DATA,
            $this->iv
        );

        if ($decrypted === false) {
            throw new \RuntimeException('Decryption failed: ' . openssl_error_string());
        }

        return $decrypted;
    }

    /**
     * Verify an incoming value (possibly encrypted) against a stored encrypted value.
     * The Flutter app sends ENCRYPTED keys, so we compare encrypted == encrypted directly.
     * This avoids ever decrypting the stored values unnecessarily.
     */
    public function verifyEncrypted(string $incoming, string $storedEncrypted): bool
    {
        // Both incoming and stored are AES-256-CBC encrypted base64 strings.
        // Because the same key+IV is used, same plaintext → same ciphertext.
        return hash_equals($storedEncrypted, $incoming);
    }
}
