import 'package:flutter/material.dart';

class UsersScreen extends StatelessWidget {
	const UsersScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('الملف الشخصي'),
			),
			body: Center(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: const [
						Icon(Icons.manage_accounts, size: 64, color: Colors.deepPurple),
						SizedBox(height: 16),
						Text(
							'سيتم إضافة إعدادات الملف الشخصي قريبًا.',
							textAlign: TextAlign.center,
							style: TextStyle(fontSize: 16),
						),
					],
				),
			),
		);
	}
}
