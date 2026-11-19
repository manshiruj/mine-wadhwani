import 'package:mine_wadhwani/data/models/drone_analysis_result.dart';

class RoadDefectResult {
  final List<Detection> potholeDetections;
  final List<Detection> crackDetections;
  final DateTime analyzedAt;

  const RoadDefectResult({
    required this.potholeDetections,
    required this.crackDetections,
    required this.analyzedAt,
  });

  List<Detection> get allDetections => [...potholeDetections, ...crackDetections];

  int get potholeCount => potholeDetections.length;
  int get crackCount => crackDetections.length;
  bool get hasDefects => potholeCount > 0 || crackCount > 0;

  String get summary {
    if (!hasDefects) return 'No defects detected';
    final parts = <String>[];
    if (potholeCount > 0) parts.add('$potholeCount pothole${potholeCount == 1 ? '' : 's'}');
    if (crackCount > 0) parts.add('$crackCount crack${crackCount == 1 ? '' : 's'}');
    return '${parts.join(', ')} detected';
  }
}