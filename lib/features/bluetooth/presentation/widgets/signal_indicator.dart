import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/rssi.dart';

/// Four bars showing the signal strength of a peripheral.
class SignalIndicator extends StatelessWidget {
  const SignalIndicator({super.key, required this.rssi});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    final bars = Rssi.bars(rssi);
    final color = switch (bars) {
      4 => AppTheme.statusGood,
      3 => AppTheme.primaryInk,
      2 => AppTheme.statusWarning,
      _ => AppTheme.statusCritical,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var level = 1; level <= 4; level++)
          Container(
            width: 3,
            height: 4.0 + level * 3,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: level <= bars ? color : AppTheme.gridline,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}
