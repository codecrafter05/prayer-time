import 'package:flutter/material.dart';
import 'styles.dart';

class PrayerTimeColumn extends StatelessWidget {
  final String prayer;
  final String hour;
  final String minute;

  PrayerTimeColumn({
    required this.prayer,
    required this.hour,
    required this.minute,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prayer,
          style: AppStyles.prayerRowTextStyle,
        ),
        SizedBox(height: 8),
        Text(
          '$hour:$minute',
          style: AppStyles.prayerRowTextStyle,
        ),
      ],
    );
  }
}
