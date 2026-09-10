import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // المفاتيح المستعملة في التخزين المحلي
  static const String _keyCurrency = 'currency';
  static const String _keyExchangeRate = 'exchange_rate';
  static const String _keyTaxRate = 'tax_rate';
  static const String _keyTaxMode = 'tax_mode';

  // القيم الافتراضية للتطبيق
  static const String defaultCurrency = 'JOD';
  static const double defaultExchangeRate = 1.0;
  static const double defaultTaxRate = 16.0;
  static const String defaultTaxMode = 'EXCLUSIVE';

  /// دالة جلب الإعدادات
  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'currency': prefs.getString(_keyCurrency) ?? defaultCurrency,
      'exchangeRate': prefs.getDouble(_keyExchangeRate) ?? defaultExchangeRate,
      'taxRate': prefs.getDouble(_keyTaxRate) ?? defaultTaxRate,
      'taxMode': prefs.getString(_keyTaxMode) ?? defaultTaxMode,
    };
  }

  /// دالة حفظ الإعدادات
  static Future<void> saveSettings({
    required String currency,
    required double exchangeRate,
    required double taxRate,
    required String taxMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyCurrency, currency);
    await prefs.setDouble(_keyExchangeRate, exchangeRate);
    await prefs.setDouble(_keyTaxRate, taxRate);
    await prefs.setString(_keyTaxMode, taxMode);
  }
}
