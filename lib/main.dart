import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'providers/theme_provider.dart';
import 'providers/transaction_provider.dart';
import 'models/transaction.dart';
import 'views/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart'; // 📌 Import pour l'initialisation des locales

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null); // 📌 Initialisation de la locale française
  await Hive.initFlutter();

  // Enregistrer l'adaptateur pour le modèle Transaction
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TransactionAdapter());
  }

  // Ouvrir les boîtes Hive pour sauvegarder les transactions et le thème
  await Hive.openBox('settings');
  await Hive.openBox<Transaction>('transactions');

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);

    // 🔥 Ajout de transactionProvider pour qu'il soit bien pris en compte
    ref.watch(transactionProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Finances Futées',
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: const HomeScreen(),
    );
  }
}