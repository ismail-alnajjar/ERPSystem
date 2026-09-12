import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/invoices_repository.dart';
import 'invoice_event.dart';
import 'invoice_state.dart';

class InvoiceBloc extends Bloc<InvoiceEvent, InvoiceState> {
  final InvoicesRepository repository;

  InvoiceBloc(this.repository) : super(InvoiceInitialState()) {
    // 1. Handling Fetch Invoices
    on<FetchInvoicesEvent>((event, emit) async {
      emit(InvoiceLoadingState());
      try {
        final invoices = await repository.getInvoices();
        emit(InvoiceLoadedState(invoices));
      } catch (e) {
        emit(InvoiceErrorState('فشل في جلب الفواتير: ${e.toString()}'));
      }
    });

    // 2. Handling Create Invoice
    on<CreateInvoiceEvent>((event, emit) async {
      emit(InvoiceLoadingState());
      try {
        await repository.createInvoice(event.invoice);
        emit(InvoiceOperationSuccessState('تم حفظ الفاتورة بنجاح'));
        add(FetchInvoicesEvent());
      } catch (e) {
        emit(InvoiceErrorState('فشل في حفظ الفاتورة: ${e.toString()}'));
      }
    });

    // 3. Handling Full Invoice Update (تعديل بيانات الفاتورة/الكميات/الضريبة)
    on<UpdateInvoiceEvent>((event, emit) async {
      emit(InvoiceLoadingState());
      try {
        await repository.updateInvoice(event.invoice);
        emit(InvoiceOperationSuccessState('تم تعديل الفاتورة بنجاح'));
        add(FetchInvoicesEvent());
      } catch (e) {
        emit(InvoiceErrorState('فشل في تعديل الفاتورة: ${e.toString()}'));
      }
    });

    // 4. Handling Update Status (Approve / Cancel)
    on<UpdateInvoiceStatusEvent>((event, emit) async {
      try {
        await repository.updateInvoiceStatus(event.invoiceId, event.newStatus);
        emit(InvoiceOperationSuccessState('تم تحديث حالة الفاتورة بنجاح'));
        add(FetchInvoicesEvent());
      } catch (e) {
        emit(InvoiceErrorState('فشل في تحديث الحالة: ${e.toString()}'));
      }
    });

    // 5. Handling Barcode Scan
    on<ScanBarcodeEvent>((event, emit) async {
      try {
        final product = await repository.getProductByBarcode(event.barcode);
        if (product != null) {
          emit(ProductScannedState(product));
        } else {
          emit(InvoiceErrorState('لم يتم العثور على منتج بهذا الباركوود'));
        }
      } catch (e) {
        emit(InvoiceErrorState('خطأ أثناء قراءة الباركوود'));
      }
    });

    // 6. Handling Delete Invoice (Hard Delete - DRAFT only)
    on<DeleteInvoiceEvent>((event, emit) async {
      emit(InvoiceLoadingState());
      try {
        await repository.deleteInvoice(event.invoiceId);
        emit(InvoiceOperationSuccessState('تم حذف الفاتورة بنجاح'));
        // نجلب من SQLite فقط لتجنب إعادة الفاتورة من السيرفر
        final localInvoices = await repository.getLocalInvoicesOnly();
        emit(InvoiceLoadedState(localInvoices));
      } catch (e) {
        emit(InvoiceErrorState('فشل في حذف الفاتورة: ${e.toString()}'));
      }
    });
  }
}
