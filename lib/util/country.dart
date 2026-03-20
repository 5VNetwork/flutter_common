import 'dart:ui';



String getUserCountryCodeFromLocale() {
  final locale = PlatformDispatcher.instance.locale;
  return locale.countryCode ?? 'Unknown';
}
