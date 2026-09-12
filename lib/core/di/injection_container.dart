import 'package:get_it/get_it.dart';

import '../database/database_helper.dart';
import '../../features/invoices/data/datasources/invoices_local_datasource.dart';
import '../../features/invoices/data/datasources/invoices_remote_datasource.dart';
import '../../features/invoices/data/repositories/invoices_repository.dart';
import '../../features/invoices/presentation/bloc/invoice_bloc.dart';

final sl = GetIt.instance;

void setupInjector() {
  // Core
  sl.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper());

  // DataSources
  sl.registerLazySingleton<InvoicesLocalDataSource>(
    () => InvoicesLocalDataSource(dbHelper: sl()),
  );
  sl.registerLazySingleton<InvoicesRemoteDataSource>(
    () => InvoicesRemoteDataSource(),
  );

  // Repository
  sl.registerLazySingleton<InvoicesRepository>(
    () => InvoicesRepository(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );

  // BLoC
  sl.registerFactory<InvoiceBloc>(() => InvoiceBloc(sl()));
}

