import 'package:erp_mobile_app/features/invoices/data/model/invoice_model.dart';

abstract class InvoiceEvent {}

// حدث جلب كل الفواتير
class FetchInvoicesEvent extends InvoiceEvent {}

// حدث إنشاء فاتورة جديدة
class CreateInvoiceEvent extends InvoiceEvent {
  final InvoiceModel invoice;
  CreateInvoiceEvent(this.invoice);
}

class UpdateInvoiceEvent extends InvoiceEvent {
  final InvoiceModel invoice;
  UpdateInvoiceEvent(this.invoice);
}

// حدث تغيير حالة الفاتورة (اعتماد Approved / إلغاء Cancelled)
class UpdateInvoiceStatusEvent extends InvoiceEvent {
  final int invoiceId;
  final String newStatus;
  UpdateInvoiceStatusEvent(this.invoiceId, this.newStatus);
}

// حدث قراءة الباركوود
class ScanBarcodeEvent extends InvoiceEvent {
  final String barcode;
  ScanBarcodeEvent(this.barcode);
}
