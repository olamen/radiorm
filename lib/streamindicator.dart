import 'package:flutter/material.dart';

class StreamIndicator extends StatefulWidget {
  @override
  _StreamIndicatorState createState() => _StreamIndicatorState();
}

class _StreamIndicatorState extends State<StreamIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return IconButton(
          icon: Icon(
            Icons.circle,
            color: _animationController.value > 0.1
                ? Colors.red
                : Colors.transparent,
          ),
          onPressed: () {},
        );
      },
    );
  }
}
