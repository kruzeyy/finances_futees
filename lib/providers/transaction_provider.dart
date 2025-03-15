import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/transaction.dart';

class TransactionNotifier extends StateNotifier<List<Transaction>> {
  TransactionNotifier() : super([]) {
    _loadTransactions(); // Charge les transactions au démarrage
  }

  final Box<Transaction> _box = Hive.box('transactions');

  void _loadTransactions() {
    state = _box.values.toList();
  }

  void addTransaction(Transaction transaction) {
    _box.put(transaction.id, transaction);
    state = [...state, transaction];
  }

  void deleteTransaction(String id) {
    _box.delete(id);
    state = state.where((tx) => tx.id != id).toList();
  }
}

final transactionProvider =
StateNotifierProvider<TransactionNotifier, List<Transaction>>((ref) {
  return TransactionNotifier();
});