import 'package:flutter/material.dart';
import 'app_auth_controller.dart';
import 'login_page.dart';

/// The only route to the original app shell.
/// Data screens never mount while the user is unauthenticated.
class AuthGate extends StatefulWidget {
  final Widget shell;
  const AuthGate({super.key, required this.shell});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    AppAuthController.instance.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppAuthController.instance,
      builder: (context, _) {
        final controller = AppAuthController.instance;
        switch (controller.status) {
          case AuthStatus.checking:
            return const Scaffold(
              backgroundColor: Color(0xFFFFFAF4),
              body: Center(child: CircularProgressIndicator(color: Color(0xFFA4542D))),
            );
          case AuthStatus.signedOut:
            return const LoginPage();
          case AuthStatus.signedIn:
            return widget.shell;
        }
      },
    );
  }
}
