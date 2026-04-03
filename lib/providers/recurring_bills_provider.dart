import 'package:flutter/material.dart';
import '../models/recurring_bill.dart';
import '../services/database_helper.dart';

class RecurringBillsProvider extends ChangeNotifier {
  List<RecurringBill> _bills = [];
  bool _isLoading = true;

  List<RecurringBill> get bills => _bills;
  bool get isLoading => _isLoading;

  RecurringBillsProvider() {
    loadBills();
  }

  Future<void> loadBills() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dbBills = await DatabaseHelper.instance.getAllRecurringBills();
      _bills = dbBills.map((b) => RecurringBill.fromMap(b)).toList();
    } catch (e) {
      debugPrint('Error loading recurring bills: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBill(RecurringBill bill) async {
    try {
      final id = await DatabaseHelper.instance.insertRecurringBill(
        bill.toMap(),
      );
      final newBill = bill.copyWith(id: id);
      _bills.add(newBill);
      _sortBills();
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding recurring bill: $e');
      rethrow;
    }
  }

  Future<void> updateBill(RecurringBill bill) async {
    if (bill.id == null) return;
    try {
      await DatabaseHelper.instance.updateRecurringBill(bill.id!, bill.toMap());
      final index = _bills.indexWhere((b) => b.id == bill.id);
      if (index != -1) {
        _bills[index] = bill;
        _sortBills();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating recurring bill: $e');
      rethrow;
    }
  }

  Future<void> deleteBill(int id) async {
    try {
      await DatabaseHelper.instance.deleteRecurringBill(id);
      _bills.removeWhere((b) => b.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting recurring bill: $e');
      rethrow;
    }
  }

  Future<void> markAsPaid(int id) async {
    final index = _bills.indexWhere((b) => b.id == id);
    if (index == -1) return;

    final updatedBill = _bills[index].copyWith(lastPaid: DateTime.now());
    await updateBill(updatedBill);
  }

  void _sortBills() {
    _bills.sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
  }
}
