import 'package:flutter/material.dart';

import '../models/family_workspace_model.dart';
import '../services/budget_forecast_service.dart';
import '../services/family_sync_service.dart';

class FamilyWorkspaceProvider extends ChangeNotifier {
  final FamilySyncService _familySyncService;
  final BudgetForecastService _budgetForecastService;

  FamilyWorkspace? _workspace;
  List<FamilyMember> _members = const [];
  BudgetForecast _forecast = const BudgetForecast(
    currentBurnRatePerDay: 0,
    projectedMonthSpend: 0,
    projectedBudgetExhaustionDay: null,
    willExhaustWithinMonth: false,
  );
  bool _isLoading = false;
  String? _error;

  FamilyWorkspaceProvider({
    FamilySyncService? familySyncService,
    BudgetForecastService? budgetForecastService,
  }) : _familySyncService = familySyncService ?? InMemoryFamilySyncService(),
       _budgetForecastService =
           budgetForecastService ?? const BudgetForecastService();

  FamilyWorkspace? get workspace => _workspace;
  List<FamilyMember> get members => _members;
  BudgetForecast get forecast => _forecast;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasWorkspace => _workspace != null;

  double get totalFamilySpend {
    return _members.fold(0.0, (sum, member) => sum + member.monthlySpend);
  }

  Future<void> createWorkspace({
    required String workspaceName,
    required String ownerUserId,
    required String ownerDisplayName,
  }) async {
    _setLoading(true);
    try {
      _workspace = await _familySyncService.createWorkspace(
        workspaceName: workspaceName,
        ownerUserId: ownerUserId,
        ownerDisplayName: ownerDisplayName,
      );
      _members = await _familySyncService.getFamilyMembers(
        workspaceId: _workspace!.id,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> joinWorkspace({
    required String inviteCode,
    required String userId,
    required String displayName,
  }) async {
    _setLoading(true);
    try {
      _workspace = await _familySyncService.joinWorkspace(
        inviteCode: inviteCode,
        userId: userId,
        displayName: displayName,
      );
      _members = await _familySyncService.getFamilyMembers(
        workspaceId: _workspace!.id,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void updateMemberSpend({
    required String userId,
    required double monthlySpend,
  }) {
    _members = _members
        .map(
          (member) => member.userId == userId
              ? member.copyWith(monthlySpend: monthlySpend)
              : member,
        )
        .toList();
    notifyListeners();
  }

  void refreshForecast({
    required double monthlyFamilyBudget,
    required int daysElapsed,
    required int daysInMonth,
  }) {
    _forecast = _budgetForecastService.generate(
      monthlyBudget: monthlyFamilyBudget,
      spentSoFar: totalFamilySpend,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
    );
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
