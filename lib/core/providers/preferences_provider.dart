import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// Localization Class (L10n)
// ─────────────────────────────────────────────
class L10n {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'settings': 'Settings',
      'live_sync': 'Live Sync',
      'language': 'Language',
      'english': 'English',
      'bangla': 'Bangla',
      'currency': 'Currency',
      'save': 'Save',
      'change_success': 'Preferences updated successfully!',
    },
    'bn': {
      'settings': 'সেটিংস',
      'live_sync': 'লাইভ সিঙ্ক',
      'language': 'ভাষা',
      'english': 'ইংরেজি',
      'bangla': 'বাংলা',
      'currency': 'মুদ্রা',
      'save': 'সংরক্ষণ',
      'change_success': 'পছন্দসমূহ সফলভাবে আপডেট করা হয়েছে!',
    },
  };

  static String get(String key, String lang) {
    final language = lang.toLowerCase() == 'bn' ? 'bn' : 'en';
    return _localizedValues[language]?[key] ?? key;
  }
}

// ─────────────────────────────────────────────
// Preferences State Model
// ─────────────────────────────────────────────
class PreferencesState {
  final String language;
  final String currency;
  final List<String> availableLanguages;
  final Map<String, double> exchangeRates;

  const PreferencesState({
    this.language = 'en',
    this.currency = 'USDT',
    this.availableLanguages = const ['en', 'bn'],
    this.exchangeRates = const {'USDT': 1.0, 'BDT': 120.0},
  });

  double get conversionRate => exchangeRates[currency] ?? 1.0;

  PreferencesState copyWith({
    String? language,
    String? currency,
    List<String>? availableLanguages,
    Map<String, double>? exchangeRates,
  }) {
    return PreferencesState(
      language: language ?? this.language,
      currency: currency ?? this.currency,
      availableLanguages: availableLanguages ?? this.availableLanguages,
      exchangeRates: exchangeRates ?? this.exchangeRates,
    );
  }
}

// ─────────────────────────────────────────────
// Preferences Notifier
// ─────────────────────────────────────────────
class PreferencesNotifier extends Notifier<PreferencesState> {
  @override
  PreferencesState build() {
    _loadLocalPreferences();
    return const PreferencesState();
  }

  Future<void> _loadLocalPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('user_language') ?? 'en';
      final curr = prefs.getString('user_currency') ?? 'USDT';
      
      // Try to load cached exchange rates or available languages if any
      final cachedRatesJson = prefs.getString('cached_exchange_rates');
      Map<String, double> rates = const {'USDT': 1.0, 'BDT': 120.0};
      if (cachedRatesJson != null) {
        try {
          rates = Map<String, double>.from(
            json.decode(cachedRatesJson).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
          );
        } catch (_) {}
      }

      final cachedLangsJson = prefs.getString('cached_available_languages');
      List<String> langs = const ['en', 'bn'];
      if (cachedLangsJson != null) {
        try {
          langs = List<String>.from(json.decode(cachedLangsJson));
        } catch (_) {}
      }

      state = PreferencesState(
        language: lang,
        currency: curr,
        availableLanguages: langs,
        exchangeRates: rates,
      );
    } catch (e) {
      debugPrint("Error loading preferences: $e");
    }
  }

  Future<void> updatePreferences({
    String? language,
    String? currency,
  }) async {
    final newLang = language ?? state.language;
    final newCurr = currency ?? state.currency;

    state = state.copyWith(
      language: newLang,
      currency: newCurr,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_language', newLang);
      await prefs.setString('user_currency', newCurr);
    } catch (e) {
      debugPrint("Error saving preferences: $e");
    }
  }

  void syncFromServer(dynamic data) {
    if (data == null) return;
    try {
      String? serverLang;
      String? serverCurr;
      List<String>? serverLangs;
      Map<String, double>? serverRates;

      if (data is Map) {
        serverLang = data['language']?.toString();
        serverCurr = data['currency']?.toString();
        
        if (data['languages'] != null) {
          serverLangs = List<String>.from(data['languages']);
        }
        if (data['exchange_rates'] != null) {
          serverRates = Map<String, double>.from(
            (data['exchange_rates'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
          );
        }
      }

      final newLang = serverLang ?? state.language;
      final newCurr = serverCurr ?? state.currency;
      final newLangs = serverLangs ?? state.availableLanguages;
      final newRates = serverRates ?? state.exchangeRates;

      state = state.copyWith(
        language: newLang,
        currency: newCurr,
        availableLanguages: newLangs,
        exchangeRates: newRates,
      );

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('user_language', newLang);
        prefs.setString('user_currency', newCurr);
        prefs.setString('cached_exchange_rates', json.encode(newRates));
        prefs.setString('cached_available_languages', json.encode(newLangs));
      });
    } catch (e) {
      debugPrint("Error syncing preferences from server: $e");
    }
  }
}

final preferencesProvider = NotifierProvider<PreferencesNotifier, PreferencesState>(() {
  return PreferencesNotifier();
});