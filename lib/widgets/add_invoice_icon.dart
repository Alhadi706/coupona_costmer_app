import 'package:flutter/material.dart';

class AddInvoiceIcon extends StatelessWidget {
  final VoidCallback? onTap;
  final double iconSize;
  const AddInvoiceIcon({Key? key, required this.onTap, this.iconSize = 40}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_box, color: Colors.blue, size: iconSize),
            SizedBox(height: 4),
            Text('إضافة عرض', style: TextStyle(color: Colors.blue, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}