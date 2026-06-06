import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addTransaction(TransactionModel transaction) async {
    await _firestore.collection('transactions').add(transaction.toMap());
  }

  Stream<List<TransactionModel>> getTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<TransactionModel>> getRecentTransactions(String userId, int limit) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<TransactionModel>> getTransactionsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThan: endDate)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<TransactionModel>> getTransactionsByDate(String userId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getTransactionsByDateRange(userId, startOfDay, endOfDay);
  }

  double calculateTotalIncome(List<TransactionModel> transactions) {
    return transactions
        .where((t) => t.type == 'income')
        .fold(0, (total, transaction) => total + transaction.amount);
  }

  double calculateTotalExpense(List<TransactionModel> transactions) {
    return transactions
        .where((t) => t.type == 'expense')
        .fold(0, (total, transaction) => total + transaction.amount);
  }

  double calculateBalance(List<TransactionModel> transactions) {
    return calculateTotalIncome(transactions) - calculateTotalExpense(transactions);
  }

  Map<String, double> getCategoryWiseExpense(List<TransactionModel> transactions) {
    final Map<String, double> categoryMap = {};
    for (var t in transactions.where((t) => t.type == 'expense')) {
      categoryMap[t.category] = (categoryMap[t.category] ?? 0) + t.amount;
    }
    return categoryMap;
  }

  Map<int, double> getMonthlyIncome(List<TransactionModel> transactions, int year) {
    final monthlyData = <int, double>{};
    for (int month = 1; month <= 12; month++) {
      final monthlyTransactions = transactions.where((t) =>
          t.type == 'income' &&
          t.date.year == year &&
          t.date.month == month);
      monthlyData[month] = monthlyTransactions.fold(0, (total, t) => total + t.amount);
    }
    return monthlyData;
  }
}