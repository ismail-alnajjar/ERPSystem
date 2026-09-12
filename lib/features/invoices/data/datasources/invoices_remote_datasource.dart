import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/api_constants.dart';
import '../model/invoice_model.dart';
import '../model/product_model.dart';

class InvoicesRemoteDataSource {
  static String get baseUrl => ApiConstants.baseUrl;

  // 1. Fetch Invoices from Server
  Future<List<InvoiceModel>> getInvoices() async {
    final response = await http
        .get(Uri.parse('$baseUrl/invoices'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((j) => InvoiceModel.fromJson(j)).toList();
    } else {
      throw Exception('فشل جلب الفواتير من السيرفر (رمز: ${response.statusCode})');
    }
  }

  // 2. Fetch Product by Barcode
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    final response = await http
        .get(Uri.parse('$baseUrl/products/barcode/$barcode'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return ProductModel.fromJson(data);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('فشل البحث عن المنتج (رمز: ${response.statusCode})');
    }
  }

  // 3. Fetch All Products
  Future<List<ProductModel>> getAllProducts() async {
    final response = await http
        .get(Uri.parse('$baseUrl/products'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((j) => ProductModel.fromJson(j)).toList();
    } else {
      throw Exception('فشل جلب المنتجات (رمز: ${response.statusCode})');
    }
  }

  // 4. Create Invoice on Server (returns created object with ID)
  Future<InvoiceModel> createInvoice(InvoiceModel invoice) async {
    final payload = json.encode(invoice.toJson());

    final response = await http
        .post(
          Uri.parse('$baseUrl/invoices'),
          headers: {'Content-Type': 'application/json'},
          body: payload,
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return InvoiceModel.fromJson(data);
    } else {
      throw Exception('فشل حفظ الفاتورة على السيرفر (${response.statusCode}): ${response.body}');
    }
  }

  // 5. Update Invoice on Server
  Future<void> updateInvoice(InvoiceModel invoice) async {
    if (invoice.id == null) {
      throw Exception('لا يمكن تعديل فاتورة بدون ID');
    }

    final payload = json.encode(invoice.toJson());

    final response = await http
        .put(
          Uri.parse('$baseUrl/invoices/${invoice.id}'),
          headers: {'Content-Type': 'application/json'},
          body: payload,
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('فشل تعديل الفاتورة (${response.statusCode}): ${response.body}');
    }
  }

  // 6. Update Invoice Status
  Future<void> updateInvoiceStatus(int invoiceId, String newStatus) async {
    final formattedStatus = newStatus.trim().toUpperCase();

    final response = await http
        .patch(
          Uri.parse('$baseUrl/invoices/$invoiceId/status'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'status': formattedStatus}),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('فشل تحديث حالة الفاتورة (${response.statusCode}): ${response.body}');
    }
  }

  // 7. Delete Invoice from Server (Hard Delete)
  Future<void> deleteInvoice(int invoiceId) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/invoices/$invoiceId'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('فشل حذف الفاتورة من السيرفر (${response.statusCode}): ${response.body}');
    }
  }
}
