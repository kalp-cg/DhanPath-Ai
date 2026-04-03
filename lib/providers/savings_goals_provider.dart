import 'package:flutter/material.dart';
import '../models/savings_goal.dart';
import '../services/database_helper.dart';

class SavingsGoalsProvider extends ChangeNotifier {
  List<SavingsGoal> _goals = [];
  bool _isLoading = true;

  List<SavingsGoal> get goals => _goals;
  bool get isLoading => _isLoading;

  SavingsGoalsProvider() {
    loadGoals();
  }

  Future<void> loadGoals() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dbGoals = await DatabaseHelper.instance.getAllSavingsGoals();
      _goals = dbGoals.map((g) => SavingsGoal.fromMap(g)).toList();
    } catch (e) {
      debugPrint('Error loading savings goals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addGoal(SavingsGoal goal) async {
    try {
      final id = await DatabaseHelper.instance.insertSavingsGoal(goal.toMap());
      final newGoal = goal.copyWith(id: id);
      _goals.add(newGoal);
      _sortGoals();
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding savings goal: $e');
      rethrow;
    }
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    if (goal.id == null) return;
    try {
      await DatabaseHelper.instance.updateSavingsGoal(goal.id!, {
        ...goal.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      final index = _goals.indexWhere((g) => g.id == goal.id);
      if (index != -1) {
        _goals[index] = goal;
        _sortGoals();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating savings goal: $e');
      rethrow;
    }
  }

  Future<void> addSavings(int goalId, double amount) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    final goal = _goals[index];
    final newAmount = goal.currentAmount + amount;

    // Check if goal completed
    final newStatus = newAmount >= goal.targetAmount
        ? 'completed'
        : goal.status;

    final updatedGoal = goal.copyWith(
      currentAmount: newAmount,
      status: newStatus,
    );

    await updateGoal(updatedGoal);

    // If completed, we might want to refresh to remove it from "active" list
    // depending on the app's requirement. For now, if "completed", it will
    // disappear on next load since `getAllSavingsGoals` only queries 'active'.
    if (newStatus == 'completed') {
      _goals.removeWhere((g) => g.id == goalId);
      notifyListeners();
    }
  }

  Future<void> deleteGoal(int id) async {
    try {
      await DatabaseHelper.instance.deleteSavingsGoal(id);
      _goals.removeWhere((g) => g.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting savings goal: $e');
      rethrow;
    }
  }

  void _sortGoals() {
    _goals.sort((a, b) => a.targetDate.compareTo(b.targetDate));
  }
}
