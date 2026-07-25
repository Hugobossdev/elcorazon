import 'package:flutter/material.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';

/// Widget conteneur avec gradient de fond comme auth_screen
/// Utilise heroGradient pour le fond
class AuthStyleContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool useGradient;

  const AuthStyleContainer({
    required this.child,
    super.key,
    this.padding,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: useGradient
          ? const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.heroGradient,
                stops: [0.0, 0.5, 1.0],
              ),
            )
          : null,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: padding ?? DesignConstants.paddingL,
          child: child,
        ),
      ),
    );
  }
}
