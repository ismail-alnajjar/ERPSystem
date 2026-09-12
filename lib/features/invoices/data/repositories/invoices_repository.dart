import 'package:erp_mobile_app/features/invoices/data/datasources/invoices_local_datasource.dart';
import 'package:erp_mobile_app/features/invoices/data/datasources/invoices_remote_datasource.dart';
import 'package:erp_mobile_app/features/invoices/data/model/invoice_model.dart';
import 'package:erp_mobile_app/features/invoices/data/model/product_model.dart';

class InvoicesRepository {
  final InvoicesRemoteDataSource remoteDataSource;
  final InvoicesLocalDataSource localDataSource;

  InvoicesRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  // 1. Fetch Invoices (Hybrid: Online with Offline Fallback & Auto Sync)
  Future<List<InvoiceModel>> getInvoices() async {
    // Attempt auto-sync of any pending offline invoices first
    await _syncPendingInvoices();

    try {
      // 🌐 Try Remote Server
      final remoteInvoices = await remoteDataSource.getInvoices();
      // Cache fresh data locally (skips deleted server invoices)
      await localDataSource.cacheInvoices(remoteInvoices);
      // Return SQLite local database as single source of truth
      return await localDataSource.getInvoices();
    } catch (_) {
      // 📱 Fallback to SQLite Local Database when Offline
      final localInvoices = await localDataSource.getInvoices();
      return localInvoices;
    }
  }

  // 1b. Fetch Invoices from Local SQLite Only (بدون رجوع للسيرفر)
  // تُستخدم بعد عمليات الحذف لتجنب إعادة الفاتورة من السيرفر
  Future<List<InvoiceModel>> getLocalInvoicesOnly() async {
    return await localDataSource.getInvoices();
  }

  // 2. Fetch Product By Barcode (Hybrid)
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    try {
      final remoteProduct = await remoteDataSource.getProductByBarcode(barcode);
      if (remoteProduct != null) {
        await localDataSource.cacheProducts([remoteProduct]);
      }
      return remoteProduct;
    } catch (_) {
      // Fallback to local SQLite cache
      return await localDataSource.getProductByBarcode(barcode);
    }
  }

  // 3. Fetch All Products (Hybrid)
  Future<List<ProductModel>> getAllProducts() async {
    try {
      final remoteProducts = await remoteDataSource.getAllProducts();
      await localDataSource.cacheProducts(remoteProducts);
      return remoteProducts;
    } catch (_) {
      // Fallback to SQLite cache
      return await localDataSource.getAllProducts();
    }
  }

  // 4. Create Invoice (Hybrid Sync Queue)
  Future<void> createInvoice(InvoiceModel invoice) async {
    try {
      // 🌐 Send to server if online
      final createdInvoice = await remoteDataSource.createInvoice(invoice);
      // Save locally as synced
      await localDataSource.saveLocalInvoice(createdInvoice, isSynced: true);
    } catch (_) {
      // 📱 Save locally into SQLite queue as unsynced (Offline Mode)
      await localDataSource.saveLocalInvoice(invoice, isSynced: false);
    }
  }

  // 5. Update Invoice (Hybrid)
  Future<void> updateInvoice(InvoiceModel invoice) async {
    try {
      await remoteDataSource.updateInvoice(invoice);
      await localDataSource.saveLocalInvoice(invoice, isSynced: true);
    } catch (_) {
      // Offline fallback: save locally
      await localDataSource.saveLocalInvoice(invoice, isSynced: false);
    }
  }

  // 6. Update Invoice Status (Hybrid)
  Future<void> updateInvoiceStatus(int invoiceId, String newStatus) async {
    try {
      await remoteDataSource.updateInvoiceStatus(invoiceId, newStatus);
      await localDataSource.updateInvoiceStatusLocally(invoiceId, newStatus);
    } catch (e) {
      await localDataSource.updateInvoiceStatusLocally(invoiceId, newStatus);
    }
  }

  // 7. Delete Invoice (Hard Delete - DRAFT only)
  Future<void> deleteInvoice(int invoiceId) async {
    // Always delete locally from SQLite
    await localDataSource.deleteInvoiceLocally(invoiceId);
    // Try to delete from server (ignore error if offline)
    try {
      await remoteDataSource.deleteInvoice(invoiceId);
    } catch (_) {
      // If offline or server error, local delete is enough
      // Server will be cleaned up later or via admin panel
    }
  }

  // 🔄 Helper: Auto Sync Pending Offline Invoices
  Future<void> _syncPendingInvoices() async {
    try {
      final unsyncedItems = await localDataSource.getUnsyncedInvoicesWithLocalId();

      for (var item in unsyncedItems) {
        final int localId = item['local_id'] as int;
        final InvoiceModel invoice = item['invoice'] as InvoiceModel;

        try {
          final serverInvoice = await remoteDataSource.createInvoice(invoice);
          if (serverInvoice.id != null) {
            await localDataSource.markInvoiceSynced(localId, serverInvoice.id!);
          }
        } catch (_) {
          // If server fails during sync loop, break and retry next time
          break;
        }
      }
    } catch (_) {
      // Ignore background sync errors silently
    }
  }
}
