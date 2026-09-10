import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:erp_mobile_app/features/invoices/data/model/invoice_model.dart';
import 'package:erp_mobile_app/features/invoices/data/model/product_model.dart';

class InvoicesRepository {
  static const String baseUrl = 'http://192.168.1.27:3000/api';

  // 1. جلب جميع الفواتير
  Future<List<InvoiceModel>> getInvoices() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/invoices'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => InvoiceModel.fromJson(j)).toList();
      } else {
        throw Exception('فشل جلب الفواتير (رمز: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('خطأ في الاتصال بالشبكة: $e');
    }
  }

  // 2. جلب المنتجات بالباركوود
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/barcode/$barcode'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ProductModel.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('فشل البحث عن المنتج (رمز: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('خطأ أثناء البحث عن الباركوود: $e');
    }
  }

  // 3. جلب جميع المنتجات
  Future<List<ProductModel>> getAllProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => ProductModel.fromJson(j)).toList();
      } else {
        throw Exception('فشل جلب المنتجات (رمز: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('خطأ في شبكة المنتجات: $e');
    }
  }

  // 4. إنشاء فاتورة جديدة
  Future<void> createInvoice(InvoiceModel invoice) async {
    try {
      final payload = json.encode(invoice.toJson());

      final response = await http.post(
        Uri.parse('$baseUrl/invoices'),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(
          'فشل حفظ الفاتورة (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('خطأ عند إرسال الفاتورة: $e');
    }
  }

  // 5. تعديل الفاتورة مع ضمان إرسال البيانات بشكل سليمة
  Future<void> updateInvoice(InvoiceModel invoice) async {
    try {
      if (invoice.id == null) {
        throw Exception('لا يمكن تعديل فاتورة بدون ID');
      }

      final payload = json.encode(invoice.toJson());

      final response = await http.put(
        Uri.parse('$baseUrl/invoices/${invoice.id}'),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      if (response.statusCode != 200) {
        print('Server Reject Payload: $payload');
        print('Server Error Body: ${response.body}');
        throw Exception(
          'فشل تعديل الفاتورة (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('خطأ عند تحديث بيانات الفاتورة: $e');
    }
  }

  // 6. تحديث حالة الفاتورة مع تحويل الحروف لـ UPPERCASE
  Future<void> updateInvoiceStatus(int invoiceId, String newStatus) async {
    try {
      final formattedStatus = newStatus.trim().toUpperCase();

      final response = await http.patch(
        Uri.parse('$baseUrl/invoices/$invoiceId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': formattedStatus}),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'فشل تحديث حالة الفاتورة (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('خطأ في تحديث الحالة: $e');
    }
  }
}
