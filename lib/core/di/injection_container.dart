import 'package:get_it/get_it.dart';

import '../../features/invoices/data/repositories/invoices_repository.dart';
import '../../features/invoices/presentation/bloc/invoice_bloc.dart';

final sl = GetIt.instance;

void setupInjector() {
  // Repository
  sl.registerLazySingleton<InvoicesRepository>(() => InvoicesRepository());

  // BLoC
  sl.registerFactory<InvoiceBloc>(() => InvoiceBloc(sl()));
}
