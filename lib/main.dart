import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/api_test_screen.dart';
import 'screens/map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const GourmetGoApp());
}

class GourmetGoApp extends StatelessWidget {
  const GourmetGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gourmet Go',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Colors.deepOrange,
          secondary: Colors.amber,
          surface: const Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/map',
      routes: {
        '/': (context) => const HomeScreen(),
        '/map': (context) => const MapScreen(),
        '/test': (context) => const ApiTestScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gourmet Go'),
      ),
      body: const Center(
        child: Text(
          '🍣 Gourmet Go',
          style: TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}
