import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_locale.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, AppLocale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<AppLocale> {
  LocaleNotifier() : super(AppLocale(AppLanguage.en));

  void toggleLanguage() {
    if (state.language == AppLanguage.en) {
      state = AppLocale(AppLanguage.bn);
    } else {
      state = AppLocale(AppLanguage.en);
    }
  }

  void setLanguage(AppLanguage lang) {
    state = AppLocale(lang);
  }
}
