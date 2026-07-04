import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/widgets/navigation_error_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        if (!appService.isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NavigationService.navigateToAuth(context);
          });
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = appService.currentUser!;

        // Rediriger vers l'écran de navigation approprié selon le rôle
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            NavigationService.navigateBasedOnRole(context, user);
          } catch (e) {
            NavigationErrorHandler.handleNavigationError(
                context, e.toString(), user,);
          }
        });

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
