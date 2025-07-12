import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/history_item.dart';
import 'screens/onboarding_page.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(HistoryItemAdapter());
  await Hive.openBox<HistoryItem>('history');
  
  // Vérifier si l'utilisateur a déjà vu l'onboarding
  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
  
  runApp(MyApp(hasSeenOnboarding: hasSeenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  
  const MyApp({super.key, required this.hasSeenOnboarding});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chiffrement de César',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.white,
          surface: const Color(0xFF1E2530),
          background: const Color(0xFF151B24),
        ),
        scaffoldBackgroundColor: const Color(0xFF151B24),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E2530),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E2530),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingPage(),
        '/home': (context) => const MyHomePage(title: 'Chiffrement César'),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _inputText = '';
  String _outputText = '';
  int _shift = 3;
  late Box<HistoryItem> _historyBox;
  String? _importedFileName;
  TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _historyBox = Hive.box<HistoryItem>('history');
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _pickAndReadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final contents = await file.readAsString();
        setState(() {
          _inputText = contents;
          _importedFileName = result.files.single.name;
          _inputController.clear();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la lecture du fichier')),
      );
    }
  }

  String _caesarCipher(String text, int shift, bool encrypt) {
    if (text.isEmpty) return '';
    
    return text.split('').map((char) {
      if (!RegExp(r'[a-zA-Z]').hasMatch(char)) return char;
      
      String alphabet = char.toLowerCase() == char ? 'abcdefghijklmnopqrstuvwxyz' : 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      int index = alphabet.indexOf(char);
      int newIndex = encrypt 
          ? (index + shift) % 26 
          : (index - shift + 26) % 26;
      
      return alphabet[newIndex];
    }).join('');
  }

  void _processText(bool encrypt) {
    setState(() {
      _outputText = _caesarCipher(_inputText, _shift, encrypt);
      
      // Sauvegarder dans l'historique
      final historyItem = HistoryItem(
        inputText: _inputText,
        outputText: _outputText,
        shift: _shift,
        wasEncrypted: encrypt,
        timestamp: DateTime.now(),
      );
      _historyBox.add(historyItem);
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copié dans le presse-papiers')),
    );
  }

  void _shareText(String text) {
    Share.share(text);
  }

  Future<void> _exportToFile(String text) async {
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Sauvegarder le message',
        fileName: 'message_decrypte.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier sauvegardé avec succès')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la sauvegarde du fichier')),
      );
    }
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2530),
      builder: (context) {
        return ValueListenableBuilder(
          valueListenable: _historyBox.listenable(),
          builder: (context, Box<HistoryItem> box, _) {
            final items = box.values.toList().reversed.toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Historique',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white54),
                        onPressed: () {
                          box.clear();
                          Navigator.pop(context);
                        },
                        tooltip: 'Effacer l\'historique',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Dismissible(
                        key: Key(item.key.toString()),
                        onDismissed: (direction) {
                          item.delete();
                        },
                        background: Container(
                          color: Colors.red.withOpacity(0.7),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: ListTile(
                          title: Text(
                            item.inputText,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item.wasEncrypted ? "Chiffré" : "Déchiffré"} (Clé: ${item.shift})',
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                          trailing: Text(
                            _formatDate(item.timestamp),
                            style: TextStyle(color: Colors.white.withOpacity(0.5)),
                          ),
                          onTap: () {
                            setState(() {
                              _inputText = item.inputText;
                              _outputText = item.outputText;
                              _shift = item.shift;
                            });
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 40.0, 20.0, 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo/logo_white.png',
                        width: 48,
                        height: 48,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Chiffrement César',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: Icon(
                          Icons.history,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        onPressed: _showHistory,
                        tooltip: 'Historique',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Message:',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.upload_file, color: Colors.white54),
                          onPressed: _pickAndReadFile,
                          tooltip: 'Importer un fichier texte',
                        ),
                      ],
                    ),
                    if (_importedFileName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3341),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.file_present, 
                              color: Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Fichier importé: $_importedFileName',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, 
                                color: Colors.white54,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _importedFileName = null;
                                  _inputText = '';
                                  _outputText = '';
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Supprimer le fichier',
                            ),
                          ],
                        ),
                      ),
                    ],
                    TextField(
                      controller: _inputController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _importedFileName != null 
                            ? 'Contenu du fichier chargé...'
                            : 'Entrez votre message...',
                        hintStyle: const TextStyle(color: Colors.white38),
                      ),
                      enabled: _importedFileName == null,
                      onChanged: (value) {
                        setState(() {
                          _inputText = value;
                          _outputText = '';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Clé:',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2530),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _shift,
                                dropdownColor: const Color(0xFF1E2530),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                items: List.generate(25, (index) => index + 1)
                                    .map((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(value.toString()),
                                  );
                                }).toList(),
                                onChanged: (int? value) {
                                  if (value != null) {
                                    setState(() {
                                      _shift = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E2530),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _processText(true),
                        child: const Text('Crypter'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E2530),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _processText(false),
                        child: const Text('Décrypter'),
                      ),
                    ),
                  ],
                ),
                if (_outputText.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2530),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Résultat:',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy, color: Colors.white54),
                                  onPressed: () => _copyToClipboard(_outputText),
                                  tooltip: 'Copier',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share, color: Colors.white54),
                                  onPressed: () => _shareText(_outputText),
                                  tooltip: 'Partager',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download, color: Colors.white54),
                                  onPressed: () => _exportToFile(_outputText),
                                  tooltip: 'Exporter en fichier texte',
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _outputText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
