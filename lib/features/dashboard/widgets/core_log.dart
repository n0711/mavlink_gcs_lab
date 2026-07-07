import 'package:flutter/material.dart';

class CoreLog extends StatelessWidget {
  const CoreLog({super.key, required this.statusText});

  final String? statusText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Core Log',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF07090C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF29323B)),
              ),
              child: Text(
                statusText ?? 'No telemetry packet decoded yet.',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFFD5DEE8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
