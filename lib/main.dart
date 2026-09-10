import 'package:erp_mobile_app/features/invoices/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection_container.dart';
import 'features/invoices/presentation/bloc/invoice_bloc.dart';
import 'features/invoices/presentation/bloc/invoice_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Connection

  // Setup Dependency Injection
  setupInjector();

  runApp(const ERPApp());
}

class ERPApp extends StatelessWidget {
  const ERPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<InvoiceBloc>()..add(FetchInvoicesEvent()),
      child: MaterialApp(
        title: 'ERP Invoicing System',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        home: const LoginPage(),
      ),
    );
  }
}
