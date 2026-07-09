import 'package:flutter/material.dart';

/// Points de rupture responsive (web/tablette/desktop).
class Breakpoints {
  Breakpoints._();
  static const double wide = 900; // NavigationRail + grilles
  static const double desktop = 1280; // grilles 3 colonnes
}

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.wide;

bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

/// Centre le contenu et limite sa largeur sur grands écrans.
class PageContainer extends StatelessWidget {
  const PageContainer({super.key, required this.child, this.maxWidth = 1040});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
