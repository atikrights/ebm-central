import '../../../core/network/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final mailServiceProvider = Provider<MailService>((ref) {
  return MailService(ref.watch(apiServiceProvider));
});

class MailService {
  final ApiService _api;
  MailService(this._api);

  Future<Map<String, dynamic>> getSettings() async {
    return await _api.get('/mail/settings');
  }

  Future<void> saveSettings(Map<String, dynamic> data) async {
    await _api.post('/mail/settings', data);
  }

  Future<void> testConnection() async {
    await _api.post('/mail/test', {});
  }

  Future<List<dynamic>> getInbox() async {
    return await _api.get('/mail/inbox');
  }

  Future<void> sendMail(String to, String subject, String body) async {
    await _api.post('/mail/send', {
      'to': to,
      'subject': subject,
      'body': body,
    });
  }

  Future<Map<String, dynamic>> generateAiContent(String prompt, {String? guidelines}) async {
    return await _api.post('/mail/ai/generate', {
      'prompt': prompt,
      if (guidelines != null) 'guidelines': guidelines,
    });
  }
}
