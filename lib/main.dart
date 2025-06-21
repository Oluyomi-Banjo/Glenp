import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';

import 'providers/app_state_provider.dart';
import 'screens/splash_screen.dart'; // Changed from app_entry_screen
import 'utils/app_logger.dart';

final _logger = Logger('Main');

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize logging
    AppLogger.init();

    // Try to load .env file, but don't fail if it doesn't exist
    try {
      await dotenv.load(fileName: ".env");
      _logger.info("Environment loaded successfully");
    } catch (e) {
      _logger.warning("Could not load .env file: $e");
      // Continue anyway for testing
    }

    // Initialize Supabase here to avoid multiple initialization
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final supabaseKey = dotenv.env['SUPABASE_KEY'] ?? '';

      if (supabaseUrl.isNotEmpty &&
          supabaseKey.isNotEmpty &&
          supabaseUrl != 'https://placeholder.supabase.co' &&
          supabaseKey != 'placeholder-key') {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
        );
        _logger.info("Supabase initialized in main");
      } else {
        _logger.warning("Supabase not configured, skipping initialization");
      }
    } catch (e) {
      _logger.warning("Supabase initialization error in main: $e");
      // Continue without Supabase
    }

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    _logger.severe("Error in main", e, stackTrace);
    // Run a minimal app to show the error
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text("Error: $e"),
                const SizedBox(height: 16),
                const Text("Please check the console for more details."),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Email Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
