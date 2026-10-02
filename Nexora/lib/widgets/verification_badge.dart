import 'package:flutter/material.dart';

import '../core/utils.dart';

/// Badge drawn in the signature colour of the officer who verified the entry.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({
    super.key,
    required this.colorHex,
    this.label = 'Verified',
    this.showLabel = true,
  });

  final String colorHex;
  final String label;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = approverColorOf(colorHex);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 8 : 5,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: alphaOf(color, 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: alphaOf(color, 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 13, color: color),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
