import 'package:flutter/material.dart';

class SideSelectionDialog extends StatelessWidget {
  const SideSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chọn bên của bạn',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bên đỏ luôn đi trước, bên đen đi sau',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSideButton(context, 'Đỏ', Colors.red, true),
                _buildSideButton(context, 'Đen', Colors.black, false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideButton(
    BuildContext context,
    String sideName,
    Color color,
    bool isRed,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop(isRed);
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, color: color, size: 40),
            const SizedBox(height: 8),
            Text(
              sideName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SideSelectionDialog(),
    );
  }
}
