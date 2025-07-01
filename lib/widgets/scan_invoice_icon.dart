import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ScanInvoiceIcon extends StatelessWidget {
  final VoidCallback? onTap;
  final double iconSize;
  const ScanInvoiceIcon({Key? key, required this.onTap, this.iconSize = 40}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.green, size: iconSize),
            SizedBox(height: 4),
            Text('scan_invoice_icon'.tr(), style: TextStyle(color: Colors.green, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}