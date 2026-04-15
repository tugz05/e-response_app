import 'package:flutter/material.dart';

class VLogo extends StatelessWidget {
  final double size;
  final double topSpacing;

  const VLogo({super.key, this.size = 100, this.topSpacing = 24});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: topSpacing),
        child: Image.asset(
          'lib/assets/images/logo.png',
          width: size,
          height: size,
        ),
      ),
    );
  }
}
