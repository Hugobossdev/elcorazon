import 'package:flutter/material.dart';

/// Widget Column sécurisé qui évite les débordements
/// Utilise Flexible pour les enfants qui peuvent s'adapter
class SafeColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final EdgeInsetsGeometry? padding;

  const SafeColumn({
    required this.children, super.key,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children.map((child) {
          // Si c'est un Expanded ou Flexible, on le garde tel quel
          if (child is Expanded || child is Flexible) {
            return child;
          }
          
          // Pour les autres widgets, on les enveloppe dans Flexible
          // sauf s'ils ont une hauteur fixe
          return Flexible(
            child: child,
          );
        }).toList(),
      ),
    );
  }
}

/// Widget Row sécurisé qui évite les débordements
class SafeRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final EdgeInsetsGeometry? padding;

  const SafeRow({
    required this.children, super.key,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children.map((child) {
          // Si c'est un Expanded ou Flexible, on le garde tel quel
          if (child is Expanded || child is Flexible) {
            return child;
          }
          
          // Pour les autres widgets, on les enveloppe dans Flexible
          return Flexible(
            child: child,
          );
        }).toList(),
      ),
    );
  }
}

/// Widget Container sécurisé qui gère les débordements
class SafeContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Decoration? decoration;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;

  const SafeContainer({
    required this.child, super.key,
    this.padding,
    this.margin,
    this.color,
    this.decoration,
    this.width,
    this.height,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      color: color,
      decoration: decoration,
      width: width,
      height: height,
      constraints: constraints,
      child: child is Column || child is Row
          ? SingleChildScrollView(child: child)
          : child,
    );
  }
}

