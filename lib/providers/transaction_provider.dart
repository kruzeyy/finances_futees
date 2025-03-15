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

  // ✅ **Ajout de la fonction pour modifier une transaction**
  void editTransaction(String id, String newTitle, double newAmount, String newCategory) {
    final transactionIndex = state.indexWhere((tx) => tx.id == id);
    if (transactionIndex != -1) {
      final updatedTransaction = Transaction(
        id: id,
        title: newTitle,
        amount: newAmount,
        date: state[transactionIndex].date, // On garde la même date
        category: newCategory,
      );

      _box.put(id, updatedTransaction); // Mise à jour dans Hive

      state = [
        ...state.sublist(0, transactionIndex),
        updatedTransaction,
        ...state.sublist(transactionIndex + 1),
      ];
    }
  }
}

// Fournisseur Riverpod pour gérer les transactions
final transactionProvider =
StateNotifierProvider<TransactionNotifier, List<Transaction>>((ref) {
  return TransactionNotifier();
});