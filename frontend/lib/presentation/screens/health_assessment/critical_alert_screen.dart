import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mine_wadhwani/data/models/health_assessment/critical_condition_checker.dart';

class CriticalAlertScreen extends StatefulWidget {
  final CriticalAlert alert;
  static const String emergencyNumber = '9335536412'; // TODO: same as HomePage — replace with real number before deployment

  const CriticalAlertScreen({super.key, required this.alert});

  @override
  State<CriticalAlertScreen> createState() => _CriticalAlertScreenState();
}

class _CriticalAlertScreenState extends State<CriticalAlertScreen> {
  final FlutterTts _tts = FlutterTts();
  Timer? _repeatTimer;
  Timer? _holdTimer;
  double _holdProgress = 0;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _startAlarm();
  }

  Future<void> _startAlarm() async {
    // Vibration: strong repeating pattern until dismissed.
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      Vibration.vibrate(pattern: [500, 800, 500, 800], repeat: 0);
    }

    // Speech: announce immediately, then repeat every 8 seconds
    // in case the inspector didn't hear it the first time.
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.42);
    await _tts.setVolume(1.0);
    _speakAlert();
    _repeatTimer = Timer.periodic(const Duration(seconds: 8), (_) => _speakAlert());
  }

  void _speakAlert() {
    _tts.speak('Critical alert. ${widget.alert.reason}. Zone: ${widget.alert.zone}.');
  }

  void _stopAlarm() {
    _repeatTimer?.cancel();
    Vibration.cancel();
    _tts.stop();
  }

  void _startHold() {
    _holdTimer?.cancel();
    setState(() => _holdProgress = 0);
    const tick = Duration(milliseconds: 50);
    const totalMs = 2000; // 2-second deliberate hold
    int elapsed = 0;
    _holdTimer = Timer.periodic(tick, (timer) {
      elapsed += tick.inMilliseconds;
      setState(() => _holdProgress = elapsed / totalMs);
      if (elapsed >= totalMs) {
        timer.cancel();
        _dismiss();
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    setState(() => _holdProgress = 0);
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _stopAlarm();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _callEmergency() async {
    final uri = Uri.parse('tel:${CriticalAlertScreen.emergencyNumber}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void dispose() {
    _stopAlarm();
    _holdTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // prevent back-button from silently dismissing a real emergency
      child: Scaffold(
        backgroundColor: const Color(0xFF991B1B),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Icon(Icons.warning_rounded, color: Colors.white, size: 56),
                const SizedBox(height: 12),
                const Text(
                  'CRITICAL ALERT',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.alert.reason,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, height: 1.3),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Text(widget.alert.zone, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton.icon(
                    onPressed: _callEmergency,
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 24),
                    label: const Text('CALL EMERGENCY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF991B1B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTapDown: (_) => _startHold(),
                  onTapUp: (_) => _cancelHold(),
                  onTapCancel: () => _cancelHold(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _holdProgress.clamp(0, 1),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const Text(
                          'Hold to dismiss — false alarm',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}