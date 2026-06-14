import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const CitizenAlertApp());
}

class CitizenAlertApp extends StatelessWidget {
  const CitizenAlertApp({super.key});

  Future<bool> _isLoggedIn() async {
    final token = await ApiService().getToken();
    return token != null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CitizenAlert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF4FC3F7),
          surface: const Color(0xFF0D1B2A),
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: _isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0D1B2A),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
              ),
            );
          }
          return snapshot.data == true
              ? const HomeScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}