import 'package:flutter/material.dart';

class TestRedirectScreen extends StatelessWidget {
  const TestRedirectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Page Flutter Test"),
      ),
      body: const Center(
        child: Text(
          "🎉 Tu es bien revenu dans Flutter !",
          style: TextStyle(fontSize: 20),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
