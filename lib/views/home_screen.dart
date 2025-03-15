import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/transaction_provider.dart';
import '../providers/theme_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String selectedMonth = DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now());
  double budget = 0.0; // 🔥 Valeur du budget
  final budgetController = TextEditingController();
  final FocusNode budgetFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  // 🔥 Charger le budget depuis Hive
  void _loadBudget() async {
    final box = await Hive.openBox('settings');
    setState(() {
      budget = box.get('budget_$selectedMonth', defaultValue: 0.0);
      budgetController.text = budget.toString();
    });
  }

  // 🔥 Sauvegarder le budget dans Hive
  void _saveBudget() async {
    final box = await Hive.openBox('settings');
    box.put('budget_$selectedMonth', budget);
  }

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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "CSV") {
                _exportToCSV(filteredTransactions);
              } else if (value == "PDF") {
                _exportToPDF(filteredTransactions);
              } else if (value == "PRINT_PDF") {
                _printPDF(filteredTransactions);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: "CSV", child: Text("Exporter en CSV 📄")),
              const PopupMenuItem(value: "PDF", child: Text("Exporter en PDF 🖨️")),
              const PopupMenuItem(value: "PRINT_PDF", child: Text("Imprimer le PDF 🖨️")),
            ],
            icon: const Icon(Icons.download),
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
                _loadBudget(); // 🔥 Recharger le budget quand on change de mois
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

          // 🔥 Entrée pour définir un budget mensuel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: budgetController,
                    decoration: const InputDecoration(labelText: "Budget mensuel (€)"),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        budget = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.green),
                  onPressed: _saveBudget, // 🔥 Sauvegarde du budget
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 🔥 Alerte si les dépenses dépassent le budget
          if (budget > 0 && totalExpenses > budget)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                "⚠️ Alerte : Dépenses dépassant le budget !",
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),

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
  Widget buildChart(List<Transaction> transactions) {
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
  Future<void> _exportToCSV(List<Transaction> transactions) async {
    List<List<String>> csvData = [
      ["Titre", "Montant (€)", "Catégorie", "Date"]
    ];

    csvData.addAll(transactions.map((tx) => [
      tx.title,
      tx.amount.toStringAsFixed(2),
      tx.category,
      DateFormat('dd/MM/yyyy').format(tx.date)
    ]));

    String csv = const ListToCsvConverter().convert(csvData);

    // Permettre à l'utilisateur de choisir l'emplacement de sauvegarde
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: "Enregistrer le fichier CSV",
      fileName: "transactions.csv",
      type: FileType.custom,
      allowedExtensions: ["csv"],
    );

    if (outputFile != null) {
      final File file = File(outputFile);
      await file.writeAsString(csv);

      // Afficher un message de confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fichier CSV enregistré à : $outputFile")),
      );
    }
  }
  Future<void> _exportToPDF(List<Transaction> transactions) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Rapport des Transactions", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ["Titre", "Montant (€)", "Catégorie", "Date"],
              data: transactions.map((tx) => [
                tx.title,
                tx.amount.toStringAsFixed(2),
                tx.category,
                DateFormat('dd/MM/yyyy').format(tx.date)
              ]).toList(),
            ),
          ],
        ),
      ),
    );

    // Permettre à l'utilisateur de choisir l'emplacement de sauvegarde
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: "Enregistrer le fichier PDF",
      fileName: "transactions.pdf",
      type: FileType.custom,
      allowedExtensions: ["pdf"],
    );

    if (outputFile != null) {
      final File file = File(outputFile);
      await file.writeAsBytes(await pdf.save());

      // Afficher un message de confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fichier PDF enregistré à : $outputFile")),
      );
    }
  }
  Future<void> _printPDF(List<Transaction> transactions) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Rapport des Transactions", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ["Titre", "Montant (€)", "Catégorie", "Date"],
              data: transactions.map((tx) => [
                tx.title,
                tx.amount.toStringAsFixed(2),
                tx.category,
                DateFormat('dd/MM/yyyy').format(tx.date)
              ]).toList(),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}