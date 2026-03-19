import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:instagram_clone_flutter_firebase/firebase_options.dart';
import 'package:instagram_clone_flutter_firebase/providers/theme_provider.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/responsive/responsive_layout_screen.dart';
import 'package:instagram_clone_flutter_firebase/responsive/mobile_screen_layout.dart';
import 'package:instagram_clone_flutter_firebase/responsive/web_screen_layout.dart';
import 'package:instagram_clone_flutter_firebase/screens/login_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");
  await Firebase.initializeApp(options:  DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // ✅ add this
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final baseTheme = ThemeData.light().copyWith(
            scaffoldBackgroundColor: mobileBackgroundColor,
            appBarTheme: const AppBarTheme(
              backgroundColor: mobileBackgroundColor,
              foregroundColor: primaryColor,
              iconTheme: IconThemeData(color: primaryColor),
            ),
            iconTheme: const IconThemeData(color: primaryColor),
            textTheme: ThemeData.light().textTheme.apply(
                  bodyColor: primaryColor,
                  displayColor: primaryColor,
                ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: mobileSearchColor,
              hintStyle: const TextStyle(color: secondaryColor),
              labelStyle: const TextStyle(color: primaryColor),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: secondaryColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: primaryColor,
              selectionColor: Colors.black12,
              selectionHandleColor: primaryColor,
            ),
          );
          return MaterialApp(
            title: 'Instagram Clone',
            debugShowCheckedModeBanner: false,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light, // ✅
            theme: baseTheme,
            darkTheme: baseTheme,
            home: StreamBuilder(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  if (snapshot.hasData) {
                    return const ResponsiveLayout(
                      webScreenLayout: WebScreenLayout(),
                      mobileScreenLayout: MobileScreenLayout(),
                    );
                  } else if (snapshot.hasError) {
                    return Center(child: Text("${snapshot.error}"));
                  }
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  );
                }
                return const LoginScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
