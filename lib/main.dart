import 'package:alerta_vecinal/providers/auth_provider.dart';
import 'package:alerta_vecinal/screens/auth/login_screen.dart';
import 'package:alerta_vecinal/screens/home/home_screen.dart';
import 'package:alerta_vecinal/core/constants/colors.dart';
import 'package:alerta_vecinal/core/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  await Firebase.initializeApp();
  
  // Inicializar servicio de notificaciones
  await NotificationService().initialize();
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Guardar token cuando el usuario inicie sesión
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) {
          // Guardar token FCM del usuario
          NotificationService().saveUserToken(user.uid);
        }
      });
    });

    return MaterialApp(
      title: 'Alerta Vecinal',
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          elevation: 0,
        ),
      ),
      home: Consumer(
        builder: (context, ref, child) {
          final authState = ref.watch(authStateProvider);
          return authState.when(
            data: (user) => user != null ? const HomeScreen() : const LoginScreen(),
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => const LoginScreen(),
          );
        },
      ),
    );
  }
}














// import 'package:alerta_vecinal/providers/auth_provider.dart';
// import 'package:alerta_vecinal/screens/auth/login_screen.dart';
// import 'package:alerta_vecinal/screens/home/home_screen.dart';
// import 'package:alerta_vecinal/core/constants/colors.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';


// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(const ProviderScope(child: MyApp()));
// }

// class MyApp extends ConsumerWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return MaterialApp(
//       title: 'Alerta Vecinal',
//       theme: ThemeData(
//         primaryColor: AppColors.primary,
//         scaffoldBackgroundColor: AppColors.background,
//         appBarTheme: const AppBarTheme(
//           backgroundColor: AppColors.primary,
//           foregroundColor: AppColors.background,
//           elevation: 0,
//         ),
//       ),
//       home: Consumer(
//         builder: (context, ref, child) {
//           final authState = ref.watch(authStateProvider);
//           return authState.when(
//             data: (user) => user != null ? const HomeScreen() : const LoginScreen(),
//             loading: () => const Scaffold(
//               body: Center(child: CircularProgressIndicator()),
//             ),
//             error: (error, stack) => const LoginScreen(),
//           );
//         },
//       ),
//     );
//   }
// }



