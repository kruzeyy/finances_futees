import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transaction_provider.dart';
import '../providers/theme_provider.dart'; // Import du provider de thème
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart'; // Import du modèle Transaction

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);
    final isDarkMode = ref.watch(themeProvider); // Récupérer l'état du mode sombre

    // 🔥 Calculer le total des dépenses
    double totalExpenses = transactions.fold(0, (sum, tx) => sum + tx.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Finances Futées"),
        actions: [
          Switch(
            value: isDarkMode,
            onChanged: (value) {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
        ],
      ),
      body: transactions.isEmpty
          ? const Center(child: Text("Aucune transaction enregistrée"))
          : Column(
        children: [
          const SizedBox(height: 10),
          // 🔥 Affichage du total des dépenses
          Text(
            "Total des dépenses : ${totalExpenses.toStringAsFixed(2)}€",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          // Graphique en camembert
          SizedBox(
            height: 200,
            child: buildChart(transactions),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (ctx, index) {
                final tx = transactions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 3,
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 30,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text("${tx.amount}€"),
                      ),
                    ),
                    title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(tx.category),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${tx.date.day}/${tx.date.month}/${tx.date.year}"),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            ref.read(transactionProvider.notifier).deleteTransaction(tx.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  // 🔥 Fonction pour afficher un camembert des dépenses avec des couleurs
  Widget buildChart(List transactions) {
    if (transactions.isEmpty) {
      return const Center(child: Text("Aucune donnée disponible"));
    }

    // Dictionnaire de couleurs pour chaque catégorie
    final Map<String, Color> categoryColors = {
      "Courses": Colors.blue,
      "Transport": Colors.green,
      "Loisirs": Colors.orange,
      "Logement": Colors.purple,
      "Autre": Colors.grey,
    };

    final Map<String, double> categoryTotals = {};
    for (var tx in transactions) {
      categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0) + tx.amount;
    }

    final List<PieChartSectionData> sections = categoryTotals.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        title: "${entry.key}\n${entry.value.toStringAsFixed(2)}€",
        radius: 50,
        color: categoryColors[entry.key] ?? Colors.black, // Attribuer la couleur
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        borderData: FlBorderData(show: false),
      ),
    );
  }

  // 🔥 Fonction pour afficher la boîte de dialogue d'ajout de transaction
  void _showAddTransactionDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = "Courses";

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Ajouter une transaction"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Titre"),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: "Montant (€)"),
                keyboardType: TextInputType.number,
              ),
              DropdownButton<String>(
                value: selectedCategory,
                onChanged: (value) {
                  selectedCategory = value!;
                },
                items: ["Courses", "Transport", "Loisirs", "Logement", "Autre"]
                    .map((category) => DropdownMenuItem(
                  value: category,
                  child: Text(category),
                ))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text;
                final amount = double.tryParse(amountController.text) ?? 0;

                if (title.isEmpty || amount <= 0) {
                  return; // Empêche l'ajout si les valeurs sont invalides
                }

                ref.read(transactionProvider.notifier).addTransaction(
                  Transaction(
                    id: DateTime.now().toString(),
                    title: title,
                    amount: amount,
                    date: DateTime.now(),
                    category: selectedCategory,
                  ),
                );

                Navigator.of(ctx).pop(); // Ferme la boîte de dialogue
              },
              child: const Text("Ajouter"),
            ),
          ],
        );
      },
    );
  }
}