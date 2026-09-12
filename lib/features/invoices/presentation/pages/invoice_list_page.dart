import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/invoice_bloc.dart';
import '../bloc/invoice_event.dart';
import '../bloc/invoice_state.dart';
import 'create_invoice_page.dart';
import 'invoice_details_page.dart';
import 'settings_page.dart';

class InvoiceListPage extends StatefulWidget {
  const InvoiceListPage({super.key});

  @override
  State<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  @override
  void initState() {
    super.initState();
    // جلب أحدث البيانات فور فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<InvoiceBloc>().add(FetchInvoicesEvent());
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      case 'DRAFT':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<InvoiceBloc>().add(FetchInvoicesEvent());
            },
          ),
        ],
      ),
      body: BlocConsumer<InvoiceBloc, InvoiceState>(
        listener: (context, state) {
          if (state is InvoiceOperationSuccessState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is InvoiceErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is InvoiceLoadingState) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is InvoiceErrorState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.message,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      context.read<InvoiceBloc>().add(FetchInvoicesEvent());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is InvoiceLoadedState) {
            // إخفاء الفواتير الملغاة من العرض مع إبقائها في قاعدة البيانات
            final visibleInvoices = state.invoices
                .where((inv) => inv.status.toUpperCase() != 'CANCELLED')
                .toList();

            if (visibleInvoices.isEmpty) {
              return const Center(
                child: Text('No invoices found. Tap + to create one.'),
              );
            }

            return ListView.builder(
              itemCount: visibleInvoices.length,
              itemBuilder: (context, index) {
                final invoice = visibleInvoices[index];
                final statusColor = _getStatusColor(invoice.status);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Date: ${invoice.invoiceDate.toString().split(' ')[0]}\nTotal: ${invoice.totalAmount.toStringAsFixed(2)} ${invoice.currencyCode}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        invoice.status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvoiceDetailsPage(invoice: invoice),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }

          if (state is InvoiceInitialState) {
            context.read<InvoiceBloc>().add(FetchInvoicesEvent());
            return const Center(child: CircularProgressIndicator());
          }

          return const Center(child: Text('Press refresh to load invoices.'));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateInvoicePage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
    );
  }
}
