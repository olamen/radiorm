import 'dart:math';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class AudioVisualizer extends StatelessWidget {
  const AudioVisualizer({super.key});

  @override
  Widget build(BuildContext context) {
    return ZoomIn(
      child: SizedBox(
        height: 100,
        width: 200,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(10, (index) {
            final height = Random().nextInt(80) + 10;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: height.toDouble(),
              width: 8,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ),
    );
  }
}
