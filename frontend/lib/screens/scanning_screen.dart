import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../snapcity_theme.dart';
import '../widgets.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen(
      {super.key, required this.imagePath, required this.onComplete});

  final String imagePath;
  final VoidCallback onComplete;

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  int step = 0;
  late final List<Timer> timers;

  @override
  void initState() {
    super.initState();
    timers = [
      Timer(const Duration(milliseconds: 550), () => setState(() => step = 1)),
      Timer(const Duration(milliseconds: 1050), () => setState(() => step = 2)),
      Timer(const Duration(milliseconds: 1600), () => setState(() => step = 3)),
      Timer(const Duration(milliseconds: 2250), widget.onComplete),
    ];
  }

  @override
  void dispose() {
    for (final timer in timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const checks = [
      'Detecting issue',
      'Checking location',
      'Finding similar reports',
      'Building case'
    ];
    return Stack(
      children: [
        Positioned.fill(
          child: widget.imagePath.startsWith('assets/')
              ? Image.asset(widget.imagePath, fit: BoxFit.cover)
              : Image.file(File(widget.imagePath), fit: BoxFit.cover),
        ),
        Positioned.fill(
            child: ColoredBox(color: Colors.black.withOpacity(.38))),
        Align(
          alignment: Alignment.bottomCenter,
          child: AppCard(
            radius: 22,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI scan in progress',
                    style: TextStyle(
                        color: SnapColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                for (var i = 0; i < checks.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Icon(
                            i <= step
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: i <= step
                                ? SnapColors.success
                                : SnapColors.muted,
                            size: 20),
                        const SizedBox(width: 10),
                        Text('${checks[i]}...',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
