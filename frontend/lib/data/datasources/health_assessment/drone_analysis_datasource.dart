import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/error/exceptions.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/data/models/drone_analysis_result.dart';

abstract class DroneAnalysisDataSource {
  Future<DroneAnalysisResult> analyzeImage(Uint8List imageBytes);
}

/// Real implementation — sends the image to our backend, which proxies Roboflow's
/// PPE model (API key stays server-side). Works on mobile and web.
class DroneRemoteAnalysisDataSource implements DroneAnalysisDataSource {
  final ApiClient _client;
  DroneRemoteAnalysisDataSource({ApiClient? client})
      : _client = client ?? sl<ApiClient>();

  @override
  Future<DroneAnalysisResult> analyzeImage(Uint8List imageBytes) async {
    try {
      final res = await _client.post(
        '/api/v1/drone/analyze-ppe',
        data: {'image': base64Encode(imageBytes)},
      );
      final result = droneResultFromRoboflow(res.data as Map<String, dynamic>);
      debugPrint('PPE: ${result.detections.length} detections, tags ${result.hazardTags}');
      return result;
    } on ServerException catch (e) {
      throw DroneAnalysisException('Analysis failed: ${e.message}');
    } catch (e) {
      debugPrint('PPE PARSE ERROR: $e');
      throw DroneAnalysisException('Something went wrong during analysis.');
    }
  }
}

/// Mock implementation — kept for offline testing/demo fallback.
class MockDroneAnalysisDataSource implements DroneAnalysisDataSource {
  final _random = Random();

  static const List<String> _possibleHazards = [
    'Unsecured Equipment',
    'Obstruction on Haul Path',
    'Missing Barricade',
    'Loose Debris',
  ];

  @override
  Future<DroneAnalysisResult> analyzeImage(Uint8List imageBytes) async {
    await Future.delayed(const Duration(seconds: 2));

    if (_random.nextDouble() < 0.08) {
      throw DroneAnalysisException('Analysis failed. Please retry.');
    }

    final workersDetected = 3 + _random.nextInt(5);
    final workersWithPpe = _random.nextInt(workersDetected + 1);
    final shuffled = List<String>.from(_possibleHazards)..shuffle(_random);
    final hazardTags = shuffled.take(_random.nextInt(3)).toList();

    return DroneAnalysisResult(
      workersDetected: workersDetected,
      workersWithPpe: workersWithPpe,
      hazardTags: hazardTags,
      confidenceScore: 0.75 + _random.nextDouble() * 0.2,
      analyzedAt: DateTime.now(),
    );
  }
}

class DroneAnalysisException implements Exception {
  final String message;
  DroneAnalysisException(this.message);
  @override
  String toString() => message;
}