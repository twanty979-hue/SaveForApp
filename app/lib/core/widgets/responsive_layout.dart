import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool centerVertically;
  final EdgeInsetsGeometry? padding;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.maxWidth = 600.0,
    this.centerVertically = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget current = child;
    if (padding != null) {
      current = Padding(padding: padding!, child: current);
    }

    current = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: current,
      ),
    );

    return current;
  }
}
