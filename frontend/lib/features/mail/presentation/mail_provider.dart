import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mail_service.dart';

final mailInboxProvider = NotifierProvider<MailInboxNotifier, AsyncValue<List<dynamic>>>(() {
  return MailInboxNotifier();
});

class MailInboxNotifier extends Notifier<AsyncValue<List<dynamic>>> {
  @override
  AsyncValue<List<dynamic>> build() {
    // We can't call async stuff directly in build for Notifier usually,
    // or we can use FutureProvider. But for Notifier, we can do:
    Future.microtask(() => fetchInbox());
    return const AsyncValue.loading();
  }

  Future<void> fetchInbox() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(mailServiceProvider);
      final data = await service.getInbox();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final mailSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await ref.watch(mailServiceProvider).getSettings();
});
