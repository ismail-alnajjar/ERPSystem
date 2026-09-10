import 'package:erp_mobile_app/features/invoices/data/model/invoice_item_model.dart';
import 'package:erp_mobile_app/features/invoices/data/model/invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/invoice_bloc.dart';
import '../bloc/invoice_event.dart';
import '../bloc/invoice_state.dart';
import 'EditInvoicePage.dart';

class InvoiceDetailsPage extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoiceDetailsPage({super.key, required this.invoice});

  @override
  State<InvoiceDetailsPage> createState() => _InvoiceDetailsPageState();
}

class _InvoiceDetailsPageState extends State<InvoiceDetailsPage> {
  late InvoiceModel _currentInvoice;
  bool _isEditing = false;

  late TextEditingController _taxRateController;
  final List<TextEditingController> _qtyControllers = [];

  bool get _isEditable => _currentInvoice.status.toUpperCase() == 'DRAFT';

  @override
  void initState() {
    super.initState();
    _currentInvoice = widget.invoice;
    _taxRateController = TextEditingController(
      text: _currentInvoice.taxRate.toString(),
    );
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant InvoiceDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invoice != widget.invoice) {
      setState(() {
        _currentInvoice = widget.invoice;
        _taxRateController.text = _currentInvoice.taxRate.toString();
        _initControllers();
      });
    }
  }

  void _initControllers() {
    for (var c in _qtyControllers) {
      c.dispose();
    }
    _qtyControllers.clear();

    for (var item in _currentInvoice.items) {
      _qtyControllers.add(
        TextEditingController(text: item.quantity.toString()),
      );
    }
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    for (var c in _qtyControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _recalculate() {
    List<InvoiceItemModel> updatedItems = [];
    double newSubtotal = 0.0;

    for (int i = 0; i < _currentInvoice.items.length; i++) {
      final currentItem = _currentInvoice.items[i];

      final inputQty = double.tryParse(_qtyControllers[i].text);
      final newQty = (inputQty != null && inputQty >= 0)
          ? inputQty
          : currentItem.quantity;

      final lineTotal = newQty * currentItem.unitPrice;
      newSubtotal += lineTotal;

      updatedItems.add(
        currentItem.copyWith(quantity: newQty, lineTotal: lineTotal),
      );
    }

    final double inputTaxRate =
        double.tryParse(_taxRateController.text) ?? _currentInvoice.taxRate;
    final double newTaxRate = inputTaxRate < 0 ? 0 : inputTaxRate;

    double newTaxAmount = 0.0;
    double newTotalAmount = 0.0;

    if (_currentInvoice.taxMode.toUpperCase() == 'EXCLUSIVE') {
      newTaxAmount = newSubtotal * (newTaxRate / 100);
      newTotalAmount = newSubtotal + newTaxAmount;
    } else {
      newTotalAmount = newSubtotal;
      final double taxFactor = 1 + (newTaxRate / 100);
      newSubtotal = taxFactor != 0
          ? newTotalAmount / taxFactor
          : newTotalAmount;
      newTaxAmount = newTotalAmount - newSubtotal;
    }

    setState(() {
      _currentInvoice = _currentInvoice.copyWith(
        items: updatedItems,
        taxRate: newTaxRate,
        subtotalAmount: newSubtotal,
        taxAmount: newTaxAmount,
        totalAmount: newTotalAmount,
      );
    });
  }

  void _saveChanges() {
    _recalculate();
    setState(() {
      _isEditing = false;
    });

    if (_currentInvoice.id != null) {
      context.read<InvoiceBloc>().add(UpdateInvoiceEvent(_currentInvoice));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حساب التغييرات محلياً (لا يوجد معرف للفاتورة)'),
        ),
      );
    }
  }

  void _changeStatus(String newStatus) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          newStatus == 'APPROVED' ? 'اعتماد الفاتورة' : 'إلغاء الفاتورة',
        ),
        content: Text(
          newStatus == 'APPROVED'
              ? 'هل أنت تأكد من اعتماد هذه الفاتورة؟ لن تتمكن من التعديل عليها لاحقاً.'
              : 'هل أنت تأكد من إلغاء هذه الفاتورة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'APPROVED'
                  ? Colors.green
                  : Colors.red,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);

              if (_currentInvoice.id != null) {
                context.read<InvoiceBloc>().add(
                  UpdateInvoiceStatusEvent(_currentInvoice.id!, newStatus),
                );
              }
            },
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InvoiceBloc, InvoiceState>(
      listener: (context, state) {
        if (state is InvoiceOperationSuccessState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else if (state is InvoiceErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: BlocBuilder<InvoiceBloc, InvoiceState>(
        builder: (context, state) {
          final isLoading = state is InvoiceLoadingState;

          return Scaffold(
            appBar: AppBar(
              title: Text('فاتورة رقم: ${_currentInvoice.invoiceNumber}'),
              actions: [
                if (_isEditable && !isLoading)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit_save') {
                        if (_isEditing) {
                          _saveChanges();
                        } else {
                          setState(() => _isEditing = true);
                        }
                      } else if (value == 'approve') {
                        _changeStatus('APPROVED');
                      } else if (value == 'cancel') {
                        _changeStatus('CANCELLED');
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit_save',
                        child: Row(
                          children: [
                            Icon(
                              _isEditing ? Icons.save : Icons.edit,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isEditing ? 'حفظ التغييرات' : 'تعديل الفاتورة',
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'approve',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text('اعتماد الفاتورة'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.red),
                            SizedBox(width: 8),
                            Text('إلغاء الفاتورة'),
                          ],
                        ),
                      ),
                    ],
                  )
                else if (!_isEditable)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Icon(Icons.lock, color: Colors.grey),
                  ),
              ],
            ),
            body: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isEditable && !_isEditing) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'تعديل الفاتورة',
                                  style: TextStyle(color: Colors.white),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditInvoicePage(
                                        invoice: _currentInvoice,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'اعتماد (Approve)',
                                  style: TextStyle(color: Colors.white),
                                ),
                                onPressed: () => _changeStatus('APPROVED'),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'إلغاء الفاتورة',
                                  style: TextStyle(color: Colors.white),
                                ),
                                onPressed: () => _changeStatus('CANCELLED'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (!_isEditable)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12.0),
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color:
                                  _currentInvoice.status.toUpperCase() ==
                                      'CANCELLED'
                                  ? Colors.red.shade100
                                  : Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color:
                                      _currentInvoice.status.toUpperCase() ==
                                          'CANCELLED'
                                      ? Colors.red
                                      : Colors.amber.shade900,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _currentInvoice.status.toUpperCase() ==
                                            'CANCELLED'
                                        ? 'هذه الفاتورة ملغاة (CANCELLED) ولا يمكن التعديل عليها.'
                                        : 'الفاتورة معتمدة (APPROVED) ولا يمكن التعديل عليها.',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'التاريخ: ${_currentInvoice.invoiceDate.toString().split(' ')[0]}',
                                    ),
                                    Text(
                                      'الحالة: ${_currentInvoice.status}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isEditable
                                            ? Colors.orange
                                            : (_currentInvoice.status
                                                          .toUpperCase() ==
                                                      'APPROVED'
                                                  ? Colors.green
                                                  : Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'العملة: ${_currentInvoice.currencyCode}',
                                    ),
                                    if (_isEditing)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 16.0,
                                          ),
                                          child:
                                              DropdownButtonFormField<String>(
                                                value: _currentInvoice.taxMode
                                                    .toUpperCase(),
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'نوع الضريبة',
                                                      isDense: true,
                                                    ),
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: 'EXCLUSIVE',
                                                    child: Text('غير شاملة'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'INCLUSIVE',
                                                    child: Text('شاملة'),
                                                  ),
                                                ],
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    _currentInvoice =
                                                        _currentInvoice
                                                            .copyWith(
                                                              taxMode: val,
                                                            );
                                                    _recalculate();
                                                  }
                                                },
                                              ),
                                        ),
                                      )
                                    else
                                      Text(
                                        'نوع الضريبة: ${_currentInvoice.taxMode}',
                                      ),
                                  ],
                                ),
                                if (_isEditing) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _taxRateController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'نسبة الضريبة %',
                                      isDense: true,
                                    ),
                                    onChanged: (_) => _recalculate(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'العناصر',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _currentInvoice.items.length,
                          itemBuilder: (context, index) {
                            final item = _currentInvoice.items[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemDescription,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child:
                                              _isEditing &&
                                                  index < _qtyControllers.length
                                              ? TextFormField(
                                                  controller:
                                                      _qtyControllers[index],
                                                  keyboardType:
                                                      const TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'الكمية',
                                                        isDense: true,
                                                      ),
                                                  onChanged: (_) =>
                                                      _recalculate(),
                                                )
                                              : Text(
                                                  'الكمية: ${item.quantity}',
                                                ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'سعر القطعة: ${item.unitPrice}',
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'الإجمالي: ${item.lineTotal.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('المجموع الفرعي:'),
                                  Text(
                                    _currentInvoice.subtotalAmount
                                        .toStringAsFixed(2),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'الضريبة (${_currentInvoice.taxRate}%):',
                                  ),
                                  Text(
                                    _currentInvoice.taxAmount.toStringAsFixed(
                                      2,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'المجموع الكلي:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _currentInvoice.totalAmount.toStringAsFixed(
                                      2,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}
