import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  // القيم الافتراضية
  static const String defaultCurrency = 'JOD';
  static const double defaultExchangeRate = 1.0;
  static const double defaultTaxRate = 16.0;
  static const String defaultTaxMode = 'EXCLUSIVE';

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _selectedCurrency;
  late double _exchangeRate;
  late double _taxRate;
  late String _taxMode;

  late TextEditingController _taxRateController;
  bool _isLoading = true;

  final Map<String, double> _currencyExchangeRates = {
    'JOD': 1.0,
    'USD': 0.71,
    'AED': 0.19,
  };

  @override
  void initState() {
    super.initState();
    _selectedCurrency = SettingsPage.defaultCurrency;
    _exchangeRate = SettingsPage.defaultExchangeRate;
    _taxRate = SettingsPage.defaultTaxRate;
    _taxMode = SettingsPage.defaultTaxMode;

    _taxRateController = TextEditingController(text: _taxRate.toString());
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _selectedCurrency =
          prefs.getString('currency') ?? SettingsPage.defaultCurrency;
      _exchangeRate =
          prefs.getDouble('exchange_rate') ?? SettingsPage.defaultExchangeRate;
      _taxRate = prefs.getDouble('tax_rate') ?? SettingsPage.defaultTaxRate;
      _taxMode = prefs.getString('tax_mode') ?? SettingsPage.defaultTaxMode;

      _taxRateController.text = _taxRate.toString();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    super.dispose();
  }

  void _onCurrencyChanged(String? newCurrency) {
    if (newCurrency != null) {
      setState(() {
        _selectedCurrency = newCurrency;
        _exchangeRate = _currencyExchangeRates[newCurrency] ?? 1.0;
      });
    }
  }

  Future<void> _saveSettings() async {
    _taxRate = double.tryParse(_taxRateController.text) ?? 16.0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', _selectedCurrency);
    await prefs.setDouble('exchange_rate', _exchangeRate);
    await prefs.setDouble('tax_rate', _taxRate);
    await prefs.setString('tax_mode', _taxMode);

    if (!mounted) return;
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات بنجاح')));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('الإعدادات العامة')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات العامة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إعدادات العملة والضريبة الافتراضية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedCurrency,
              decoration: const InputDecoration(
                labelText: 'العملة الافتراضية',
                border: OutlineInputBorder(),
              ),
              items: _currencyExchangeRates.keys.map((currency) {
                return DropdownMenuItem(value: currency, child: Text(currency));
              }).toList(),
              onChanged: _onCurrencyChanged,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: Key(_exchangeRate.toString()),
              initialValue: _exchangeRate.toString(),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'سعر الصرف مقابل الدينار (Exchange Rate)',
                border: OutlineInputBorder(),
                suffixText: 'JOD',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _taxMode,
              decoration: const InputDecoration(
                labelText: 'نظام الضريبة',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'EXCLUSIVE',
                  child: Text('غير شامل الضريبة (EXCLUSIVE)'),
                ),
                DropdownMenuItem(
                  value: 'INCLUSIVE',
                  child: Text('شامل الضريبة (INCLUSIVE)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _taxMode = val);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _taxRateController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'نسبة الضريبة (%)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saveSettings,
                child: const Text(
                  'حفظ الإعدادات',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
