import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transaction_provider.dart';
import '../providers/theme_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String selectedMonth = DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionProvider);
    final isDarkMode = ref.watch(themeProvider);

    final List<String> months = transactions
        .map((tx) => DateFormat('MMMM yyyy', 'fr_FR').format(tx.date))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (months.isEmpty) {
      months.add(DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now()));
    }

    final filteredTransactions = transactions.where((tx) {
      return DateFormat('MMMM yyyy', 'fr_FR').format(tx.date) == selectedMonth;
    }).toList();

    double totalExpenses = filteredTransactions.fold(0, (sum, tx) => sum + tx.amount);

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
      body: Column(
        children: [
          const SizedBox(height: 10),

          DropdownButton<String>(
            value: selectedMonth,
            onChanged: (newValue) {
              setState(() {
                selectedMonth = newValue!;
              });
            },
            items: months
                .map((month) => DropdownMenuItem(
              value: month,
              child: Text(month),
            ))
                .toList(),
          ),

          const SizedBox(height: 10),

          Text(
            "Total des dépenses : ${totalExpenses.toStringAsFixed(2)}€",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 200,
            child: buildChart(filteredTransactions),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: filteredTransactions.isEmpty
                ? const Center(child: Text("Aucune transaction pour ce mois."))
                : ListView.builder(
              itemCount: filteredTransactions.length,
              itemBuilder: (ctx, index) {
                final tx = filteredTransactions[index];
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
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            _showEditTransactionDialog(context, ref, tx);
                          },
                        ),
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
        color: categoryColors[entry.key] ?? Colors.black,
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

  // 🔥 Boîte de dialogue pour modifier une transaction
  void _showEditTransactionDialog(BuildContext context, WidgetRef ref, Transaction transaction) {
    final titleController = TextEditingController(text: transaction.title);
    final amountController = TextEditingController(text: transaction.amount.toString());
    String selectedCategory = transaction.category;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Modifier la transaction"),
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
                  setState(() {
                    selectedCategory = value!;
                  });
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
                  return;
                }

                ref.read(transactionProvider.notifier).editTransaction(
                  transaction.id,
                  title,
                  amount,
                  selectedCategory,
                );

                Navigator.of(ctx).pop();
              },
              child: const Text("Modifier"),
            ),
          ],
        );
      },
    );
  }
  // 🔥 Boîte de dialogue pour ajouter une transaction
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
                  setState(() {
                    selectedCategory = value!;
                  });
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
                  return;
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

                Navigator.of(ctx).pop();
              },
              child: const Text("Ajouter"),
            ),
          ],
        );
      },
    );
  }
}