import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String? id;
  final String userId;
  final double amount;
  final String category;
  final String type; // 'income' or 'expense'
  final String description;
  final DateTime date;
  final String? paymentMethod;
  final bool isRecurring;
  final DateTime createdAt;

  TransactionModel({
    this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.type,
    required this.description,
    required this.date,
    this.paymentMethod,
    this.isRecurring = false,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'category': category,
      'type': type,
      'description': description,
      'date': Timestamp.fromDate(date),
      'paymentMethod': paymentMethod,
      'isRecurring': isRecurring,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? 'Other',
      type: data['type'] ?? 'expense',
      description: data['description'] ?? 'Transaction',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentMethod: data['paymentMethod'],
      isRecurring: data['isRecurring'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Copy with new values
  TransactionModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    String? type,
    String? description,
    DateTime? date,
    String? paymentMethod,
    bool? isRecurring,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      type: type ?? this.type,
      description: description ?? this.description,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isRecurring: isRecurring ?? this.isRecurring,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}