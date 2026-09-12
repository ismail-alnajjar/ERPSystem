import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../model/invoice_item_model.dart';
import '../model/invoice_model.dart';
import '../model/product_model.dart';

class InvoicesLocalDataSource {
  final DatabaseHelper dbHelper;

  InvoicesLocalDataSource({required this.dbHelper});

  // 1. Get All Local Invoices with Items
  Future<List<InvoiceModel>> getInvoices() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> invoiceMaps = await db.query(
      'invoices',
      orderBy: 'id DESC',
    );

    List<InvoiceModel> result = [];
    for (var invMap in invoiceMaps) {
      final localId = invMap['id'] as int;
      final serverId = invMap['server_id'] as int?;

      // Fetch Items for this invoice
      final List<Map<String, dynamic>> itemMaps = await db.query(
        'invoice_items',
        where: 'local_invoice_id = ?',
        whereArgs: [localId],
      );

      final items = itemMaps.map((item) {
        return InvoiceItemModel(
          id: item['id'] as int?,
          invoiceId: serverId,
          productId: item['product_id'] as int?,
          itemDescription: item['item_description']?.toString() ?? '',
          quantity: (item['quantity'] as num).toDouble(),
          unitPrice: (item['unit_price'] as num).toDouble(),
          lineTotal: (item['line_total'] as num).toDouble(),
        );
      }).toList();

      result.add(
        InvoiceModel(
          id: serverId ?? localId,
          invoiceNumber: invMap['invoice_number']?.toString() ?? '',
          invoiceDate: DateTime.tryParse(invMap['invoice_date'].toString()) ??
              DateTime.now(),
          currencyCode: invMap['currency_code']?.toString() ?? 'JOD',
          exchangeRate: (invMap['exchange_rate'] as num).toDouble(),
          taxMode: invMap['tax_mode']?.toString() ?? 'EXCLUSIVE',
          taxRate: (invMap['tax_rate'] as num).toDouble(),
          status: invMap['status']?.toString() ?? 'DRAFT',
          subtotalAmount: (invMap['subtotal_amount'] as num).toDouble(),
          taxAmount: (invMap['tax_amount'] as num).toDouble(),
          totalAmount: (invMap['total_amount'] as num).toDouble(),
          items: items,
        ),
      );
    }
    return result;
  }

  // 2. Cache Invoices from Remote Server (skip locally-deleted ones)
  Future<void> cacheInvoices(List<InvoiceModel> invoices) async {
    final db = await dbHelper.database;

    // Get set of server IDs that were deleted locally
    final deletedIds = await getDeletedServerIds();

    await db.transaction((txn) async {
      for (var inv in invoices) {
        if (inv.id == null) continue;

        // تجاهل الفواتير المحذوفة محلياً لمنع إعادتها من السيرفر
        if (deletedIds.contains(inv.id)) continue;

        // Upsert Invoice
        await txn.insert(
          'invoices',
          {
            'server_id': inv.id,
            'invoice_number': inv.invoiceNumber,
            'invoice_date': inv.invoiceDate.toIso8601String(),
            'currency_code': inv.currencyCode,
            'exchange_rate': inv.exchangeRate,
            'tax_mode': inv.taxMode,
            'tax_rate': inv.taxRate,
            'status': inv.status,
            'subtotal_amount': inv.subtotalAmount,
            'tax_amount': inv.taxAmount,
            'total_amount': inv.totalAmount,
            'is_synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Fetch local row ID
        final List<Map<String, dynamic>> res = await txn.query(
          'invoices',
          columns: ['id'],
          where: 'server_id = ?',
          whereArgs: [inv.id],
        );

        if (res.isNotEmpty) {
          final localId = res.first['id'] as int;

          // Delete existing items to replace with updated list
          await txn.delete(
            'invoice_items',
            where: 'local_invoice_id = ?',
            whereArgs: [localId],
          );

          for (var item in inv.items) {
            await txn.insert('invoice_items', {
              'local_invoice_id': localId,
              'server_invoice_id': inv.id,
              'product_id': item.productId,
              'item_description': item.itemDescription,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'line_total': item.lineTotal,
            });
          }
        }
      }
    });
  }

  // 3. Cache Products
  Future<void> cacheProducts(List<ProductModel> products) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      for (var p in products) {
        await txn.insert(
          'products',
          p.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // 4. Get Products
  Future<List<ProductModel>> getAllProducts() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return maps.map((m) => ProductModel.fromJson(m)).toList();
  }

  // 5. Get Product By Barcode
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    if (maps.isNotEmpty) {
      return ProductModel.fromJson(maps.first);
    }
    return null;
  }

  // 6. Save or Update Invoice Locally (Offline creation, edit, or sync queue)
  Future<int> saveLocalInvoice(InvoiceModel invoice, {required bool isSynced}) async {
    final db = await dbHelper.database;
    int localInvoiceId = 0;

    await db.transaction((txn) async {
      // Check if invoice already exists locally by server_id or invoice_number
      List<Map<String, dynamic>> existing = [];
      if (invoice.id != null) {
        existing = await txn.query(
          'invoices',
          where: 'server_id = ?',
          whereArgs: [invoice.id],
        );
      }
      if (existing.isEmpty && invoice.invoiceNumber.isNotEmpty) {
        existing = await txn.query(
          'invoices',
          where: 'invoice_number = ?',
          whereArgs: [invoice.invoiceNumber],
        );
      }

      final rowData = {
        if (invoice.id != null) 'server_id': invoice.id,
        'invoice_number': invoice.invoiceNumber,
        'invoice_date': invoice.invoiceDate.toIso8601String(),
        'currency_code': invoice.currencyCode,
        'exchange_rate': invoice.exchangeRate,
        'tax_mode': invoice.taxMode,
        'tax_rate': invoice.taxRate,
        'status': invoice.status,
        'subtotal_amount': invoice.subtotalAmount,
        'tax_amount': invoice.taxAmount,
        'total_amount': invoice.totalAmount,
        'is_synced': isSynced ? 1 : 0,
      };

      if (existing.isNotEmpty) {
        // Update existing invoice row
        localInvoiceId = existing.first['id'] as int;
        await txn.update(
          'invoices',
          rowData,
          where: 'id = ?',
          whereArgs: [localInvoiceId],
        );

        // Delete old items to replace with updated list
        await txn.delete(
          'invoice_items',
          where: 'local_invoice_id = ?',
          whereArgs: [localInvoiceId],
        );
      } else {
        // Insert new invoice row
        localInvoiceId = await txn.insert('invoices', rowData);
      }

      for (var item in invoice.items) {
        await txn.insert('invoice_items', {
          'local_invoice_id': localInvoiceId,
          'server_invoice_id': invoice.id,
          'product_id': item.productId,
          'item_description': item.itemDescription,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'line_total': item.lineTotal,
        });
      }
    });

    return localInvoiceId;
  }

  // 7. Get Unsynced Invoices
  Future<List<Map<String, dynamic>>> getUnsyncedInvoicesWithLocalId() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> invoiceMaps = await db.query(
      'invoices',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    List<Map<String, dynamic>> unsyncedList = [];

    for (var invMap in invoiceMaps) {
      final localId = invMap['id'] as int;

      final List<Map<String, dynamic>> itemMaps = await db.query(
        'invoice_items',
        where: 'local_invoice_id = ?',
        whereArgs: [localId],
      );

      final items = itemMaps.map((i) => InvoiceItemModel(
        productId: i['product_id'] as int?,
        itemDescription: i['item_description']?.toString() ?? '',
        quantity: (i['quantity'] as num).toDouble(),
        unitPrice: (i['unit_price'] as num).toDouble(),
        lineTotal: (i['line_total'] as num).toDouble(),
      )).toList();

      final model = InvoiceModel(
        id: invMap['server_id'] as int?,
        invoiceNumber: invMap['invoice_number']?.toString() ?? '',
        invoiceDate: DateTime.tryParse(invMap['invoice_date'].toString()) ?? DateTime.now(),
        currencyCode: invMap['currency_code']?.toString() ?? 'JOD',
        exchangeRate: (invMap['exchange_rate'] as num).toDouble(),
        taxMode: invMap['tax_mode']?.toString() ?? 'EXCLUSIVE',
        taxRate: (invMap['tax_rate'] as num).toDouble(),
        status: invMap['status']?.toString() ?? 'DRAFT',
        subtotalAmount: (invMap['subtotal_amount'] as num).toDouble(),
        taxAmount: (invMap['tax_amount'] as num).toDouble(),
        totalAmount: (invMap['total_amount'] as num).toDouble(),
        items: items,
      );

      unsyncedList.add({
        'local_id': localId,
        'invoice': model,
      });
    }

    return unsyncedList;
  }

  // 8. Mark Invoice as Synced
  Future<void> markInvoiceSynced(int localId, int serverId) async {
    final db = await dbHelper.database;
    await db.update(
      'invoices',
      {
        'server_id': serverId,
        'is_synced': 1,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // 9. Update Invoice Status Locally
  Future<void> updateInvoiceStatusLocally(int invoiceId, String newStatus) async {
    final db = await dbHelper.database;
    await db.update(
      'invoices',
      {'status': newStatus.toUpperCase()},
      where: 'server_id = ? OR id = ?',
      whereArgs: [invoiceId, invoiceId],
    );
  }

  // 10. Delete Invoice Locally (Hard Delete from SQLite)
  Future<void> deleteInvoiceLocally(int invoiceId) async {
    final db = await dbHelper.database;

    // Step 1: القراءة أولاً خارج الـ transaction لتحديد الـ server_id
    final List<Map<String, dynamic>> preRows = await db.query(
      'invoices',
      columns: ['id', 'server_id'],
      where: 'server_id = ? OR id = ?',
      whereArgs: [invoiceId, invoiceId],
    );

    // Step 2: الحذف الرئيسي في transaction مستقلة (يجب أن تنجح دائماً)
    await db.transaction((txn) async {
      for (final row in preRows) {
        final localId = row['id'] as int;
        await txn.delete(
          'invoice_items',
          where: 'local_invoice_id = ?',
          whereArgs: [localId],
        );
        await txn.delete(
          'invoices',
          where: 'id = ?',
          whereArgs: [localId],
        );
      }
    });

    // Step 3: تسجيل server_id في جدول المحذوفات (منفصل - لا يؤثر على الحذف)
    try {
      // تسجيل الـ invoiceId الممرر مباشرة
      await db.insert(
        'deleted_server_invoices',
        {'server_id': invoiceId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      for (final row in preRows) {
        final serverId = row['server_id'] as int?;
        if (serverId != null) {
          await db.insert(
            'deleted_server_invoices',
            {'server_id': serverId},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    } catch (_) {
      // الجدول لا يزال غير موجود (قبل ترقية DB) - تُجاهَل
    }
  }

  // 11. Get all deleted server invoice IDs
  Future<Set<int>> getDeletedServerIds() async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query('deleted_server_invoices', columns: ['server_id']);
      return rows.map((r) => r['server_id'] as int).toSet();
    } catch (_) {
      // الجدول قد لا يكون موجوداً بعد (قبل ترقية DB)
      return <int>{};
    }
  }

  // 12. Mark a specific server invoice as deleted (for external use)
  Future<void> markServerInvoiceAsDeleted(int serverId) async {
    final db = await dbHelper.database;
    await db.insert(
      'deleted_server_invoices',
      {'server_id': serverId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
