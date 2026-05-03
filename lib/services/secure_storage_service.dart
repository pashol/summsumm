import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _openrouterKey = 'openrouter_api_key';
  static const _openaiKey = 'openai_api_key';
  static const _huggingFaceKey = 'huggingface_token';

  Future<void> saveApiKey(String provider, String key) {
    final storageKey = _keyFor(provider);
    return _storage.write(key: storageKey, value: key);
  }

  Future<String?> getApiKey(String provider) {
    return _storage.read(key: _keyFor(provider));
  }

  Future<void> deleteApiKey(String provider) {
    return _storage.delete(key: _keyFor(provider));
  }

  Future<void> saveHuggingFaceToken(String token) {
    return _storage.write(key: _huggingFaceKey, value: token);
  }

  Future<String?> getHuggingFaceToken() {
    return _storage.read(key: _huggingFaceKey);
  }

  Future<void> deleteHuggingFaceToken() {
    return _storage.delete(key: _huggingFaceKey);
  }

  String _keyFor(String provider) {
    switch (provider) {
      case 'openrouter':
        return _openrouterKey;
      case 'openai':
        return _openaiKey;
      default:
        return '${provider}_api_key';
    }
  }
}
