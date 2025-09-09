import 'package:flutter/material.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المستخدمون')),
      body: const Center(child: Text('قائمة المستخدمين ستظهر هنا')),
    );
  }
}
