import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/sign_in_screen.dart';
import 'firebase_options.dart';
import 'screens/create_account_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const HuntingPartyApp());
}

class HuntingPartyApp extends StatelessWidget {
  const HuntingPartyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'The Hunting Party',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF1B4332),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData) {
          return const DashboardScreen();
        }

        return const WelcomeScreen();
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

 
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
       child: Text(
          'THE HUNTING PARTY',
            textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateAccountScreen(),
                  ),
                );
              },
              child: const Text('CREATE ACCOUNT'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SignInScreen(),
                  ),
                );
              },
              child: const Text('SIGN IN'),
            ),
          ],
        ),
      ),
    );
  }
}