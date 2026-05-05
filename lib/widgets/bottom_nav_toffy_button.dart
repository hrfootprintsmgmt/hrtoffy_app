import 'package:flutter/material.dart';



class BottomNavToffyButton extends StatefulWidget {
  const BottomNavToffyButton({Key? key}) : super(key: key);

  @override
  State<BottomNavToffyButton> createState() => _BottomNavToffyButtonState();
}

class _BottomNavToffyButtonState extends State<BottomNavToffyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: _scale.value,
      child: Image.asset(
        "assets/hi toffy.gif",
        width: 65,
        height: 55,
      ),
    );
  }
}
