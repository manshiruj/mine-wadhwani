import 'package:flutter/material.dart';

/// Two panels side by side on tablets / landscape (>= [breakpoint] wide),
/// stacked in one scrolling column on phones.
class ResponsivePanels extends StatelessWidget {
  final Widget left;
  final Widget right;
  final EdgeInsets leftPadding;
  final EdgeInsets rightPadding;
  final double breakpoint;

  const ResponsivePanels({
    super.key,
    required this.left,
    required this.right,
    this.leftPadding = const EdgeInsets.fromLTRB(24, 20, 12, 20),
    this.rightPadding = const EdgeInsets.fromLTRB(12, 20, 24, 20),
    this.breakpoint = 700,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= breakpoint) {
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: SingleChildScrollView(padding: leftPadding, child: left)),
          Expanded(child: SingleChildScrollView(padding: rightPadding, child: right)),
        ]);
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          left,
          const SizedBox(height: 16),
          right,
        ]),
      );
    });
  }
}
