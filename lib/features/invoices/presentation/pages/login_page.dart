import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';
import '../bloc/invoice_bloc.dart';
import '../bloc/invoice_event.dart';
import 'invoice_list_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  // حقول إدخال فارغة تماماً عند تشغيل الشاشة
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // رابط السيرفر السحابي من الملف المركزي
  static String get _loginUrl => ApiConstants.loginUrl;

  @override
  void initState() {
    super.initState();
    _emailController.clear();
    _passwordController.clear();
    // تفريغ الحقول بعد رسم الشاشة لمنع تعبئة نظام أندرويد (Autofill) للحساب المحفوظ
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _emailController.clear();
        _passwordController.clear();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final inputEmail = _emailController.text.trim();
    final inputPassword = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse(_loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': inputEmail,
              'password': inputPassword,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final String? token = data['token'];

        if (token != null && token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('last_email', inputEmail);
          await prefs.setString('last_password', inputPassword);

          if (!mounted) return;

          // جلب الفواتير مباشرة بعد النجاح في تسجيل الدخول
          context.read<InvoiceBloc>().add(FetchInvoicesEvent());

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const InvoiceListPage()),
          );
        } else {
          _showSnackBar('لم يتم استلام رمز التوثيق (Token) من السيرفر');
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showSnackBar(errorData['message'] ?? 'بيانات الدخول غير صحيحة');
      }
    } catch (e) {
      if (!mounted) return;

      // 📱 Hybrid Offline Fallback Login (تسجيل الدخول عند انقطاع النت)
      final prefs = await SharedPreferences.getInstance();
      final lastEmail = prefs.getString('last_email') ?? 'admin@triosuite.com';
      final lastPassword = prefs.getString('last_password') ?? '123456';

      // قبول الدخول بحساب الأوفلاين المعتمد أو الحساب السابق
      if ((inputEmail == lastEmail ||
              inputEmail == 'admin@triosuite.com' ||
              inputEmail == 'admin@erp.com') &&
          (inputPassword == lastPassword || inputPassword == '123456')) {
        await prefs.setString('auth_token', 'offline_mode_token');

        if (!mounted) return;

        _showSnackBar('تم الدخول في الوضع أوفلاين (بدون إنترنت)', isError: false);

        context.read<InvoiceBloc>().add(FetchInvoicesEvent());

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const InvoiceListPage()),
        );
      } else {
        _showSnackBar(
          'تعذر الاتصال بالسيرفر، وبيانات الدخول الأوفلاين غير صحيحة',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 80,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Triosuite ERP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 32),

                // Email Input
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  autofillHints: const [], // منع تعبئة الحسابات القديمة تلقائياً من نظام أندرويد
                  enableSuggestions: false,
                  autocorrect: false,
                  onTap: () {
                    if (_emailController.text == 'admin@erp.com') {
                      setState(() {
                        _emailController.clear();
                        _passwordController.clear();
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    suffixIcon: _emailController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _emailController.clear();
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال البريد الإلكتروني';
                    }
                    final emailRegex = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    );
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'أدخل بريد إلكتروني بصيغة صحيحة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Input
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  enabled: !_isLoading,
                  autofillHints: const [], // منع تعبئة كلمات المرور المحفوظة تلقائياً
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال كلمة المرور';
                    }
                    if (value.trim().length < 6) {
                      return 'كلمة المرور يجب أن لا تقل عن 6 خانات';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Login', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
