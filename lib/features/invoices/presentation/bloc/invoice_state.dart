import 'package:erp_mobile_app/features/invoices/data/model/invoice_model.dart';
import 'package:erp_mobile_app/features/invoices/data/model/product_model.dart';

abstract class InvoiceState {}

class InvoiceInitialState extends InvoiceState {}

class InvoiceLoadingState extends InvoiceState {}

class InvoiceLoadedState extends InvoiceState {
  final List<InvoiceModel> invoices;
  InvoiceLoadedState(this.invoices);
}

class ProductScannedState extends InvoiceState {
  final ProductModel product;
  ProductScannedState(this.product);
}

class InvoiceOperationSuccessState extends InvoiceState {
  final String message;
  InvoiceOperationSuccessState(this.message);
}

class InvoiceErrorState extends InvoiceState {
  final String message;
  InvoiceErrorState(this.message);
}
