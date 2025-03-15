import 'package:hive/hive.dart';

part 'transaction.g.dart'; // Important pour générer l'adaptateur !

@HiveType(typeId: 0) // Identifiant unique pour ce modèle
class Transaction {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String category;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
  });
}