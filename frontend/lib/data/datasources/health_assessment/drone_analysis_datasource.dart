// import 'dart:convert';
// import 'dart:io';
// import 'dart:math';
// import 'package:dio/dio.dart';
// import 'package:flutter/foundation.dart';
// import 'package:mine_wadhwani/core/constants/api_constants.dart';
// import 'package:mine_wadhwani/data/models/drone_analysis_result.dart';

// abstract class DroneAnalysisDataSource {
//   Future<DroneAnalysisResult> analyzeImage(String imagePath);
// }

// /// Real implementation — calls our Roboflow PPE-detection workflow.
// class DroneRemoteAnalysisDataSource implements DroneAnalysisDataSource {
//   final Dio _dio = Dio(
//     BaseOptions(
//       connectTimeout: const Duration(seconds: 30),
//       sendTimeout: const Duration(seconds: 30),
//       receiveTimeout: const Duration(seconds: 30),
//     ),
//   );

//   @override
//   Future<DroneAnalysisResult> analyzeImage(String imagePath) async {
//     try {
//       final bytes = await File(imagePath).readAsBytes();
//       final base64Image = base64Encode(bytes);

//       final response = await _dio.post(
//         ApiConstants.roboflowWorkflowUrl,
//         data: {
//           'api_key': ApiConstants.roboflowApiKey,
//           'inputs': {
//             'image': {'type': 'base64', 'value': base64Image},
//           },
//         },
//         options: Options(headers: {'Content-Type': 'application/json'}),
//       );

//       final data = response.data as Map<String, dynamic>;

//       final Map<String, dynamic> result;
//       if (data['outputs'] is List && (data['outputs'] as List).isNotEmpty) {
//         result = (data['outputs'] as List).first as Map<String, dynamic>;
//       } else {
//         result = data;
//       }

//       final predictionsBlock = result['predictions'] as Map<String, dynamic>?;
//       final predictions =
//           (predictionsBlock?['predictions'] as List<dynamic>?) ?? [];

//       debugPrint('ROBOFLOW: ${predictions.length} detections found');

//             final imageInfo = predictionsBlock?['image'] as Map<String, dynamic>?;
//       final imgWidth = ((imageInfo?['width'] as num?) ?? 0).toDouble();
//       final imgHeight = ((imageInfo?['height'] as num?) ?? 0).toDouble();

//       final detectionList = predictions
//           .map((p) => Detection.fromJson(p as Map<String, dynamic>))
//           .toList();

//       final personCount = predictions
//           .where((p) => (p['class'] as String?)?.toLowerCase() == 'person')
//           .length;

//       final helmetCount = predictions
//           .where((p) =>
//               (p['class'] as String?)?.toLowerCase().contains('helmet') == true)
//           .length;

//       final compliantCount = helmetCount > personCount ? personCount : helmetCount;
//       final totalWorkers = personCount;

//       final hazardTags = <String>[];
//       if (totalWorkers > 0 && compliantCount < totalWorkers) {
//         final missing = totalWorkers - compliantCount;
//         hazardTags.add('Missing Helmet ($missing worker${missing == 1 ? '' : 's'})');
//       }

//       final avgConfidence = predictions.isEmpty
//           ? 0.0
//           : predictions
//                   .map((p) => (p['confidence'] as num).toDouble())
//                   .reduce((a, b) => a + b) /
//               predictions.length;

//       return DroneAnalysisResult(
//         workersDetected: totalWorkers,
//         workersWithPpe: compliantCount,
//         hazardTags: hazardTags,
//         confidenceScore: avgConfidence,
//         imagePath: imagePath,
//         analyzedAt: DateTime.now(),
//         detections: detectionList,
//         imageWidth: imgWidth,
//         imageHeight: imgHeight,
//       );
//     } on DioException catch (e) {
//       debugPrint('ROBOFLOW ERROR TYPE: ${e.type}');
//       debugPrint('ROBOFLOW ERROR MESSAGE: ${e.message}');
//       debugPrint('ROBOFLOW UNDERLYING ERROR: ${e.error}');
//       throw DroneAnalysisException('Analysis failed: ${e.message}');
//     } catch (e) {
//       debugPrint('ROBOFLOW PARSE ERROR: $e');
//       throw DroneAnalysisException('Something went wrong during analysis.');
//     }
//   }
// }

// /// Mock implementation — kept for offline testing/demo fallback.
// class MockDroneAnalysisDataSource implements DroneAnalysisDataSource {
//   final _random = Random();

//   static const List<String> _possibleHazards = [
//     'Unsecured Equipment',
//     'Obstruction on Haul Path',
//     'Missing Barricade',
//     'Loose Debris',
//   ];

//   @override
//   Future<DroneAnalysisResult> analyzeImage(String imagePath) async {
//     await Future.delayed(const Duration(seconds: 2));

//     if (_random.nextDouble() < 0.08) {
//       throw DroneAnalysisException('Analysis failed. Please retry.');
//     }

//     final workersDetected = 3 + _random.nextInt(5);
//     final workersWithPpe = _random.nextInt(workersDetected + 1);
//     final shuffled = List<String>.from(_possibleHazards)..shuffle(_random);
//     final hazardTags = shuffled.take(_random.nextInt(3)).toList();

//     return DroneAnalysisResult(
//       workersDetected: workersDetected,
//       workersWithPpe: workersWithPpe,
//       hazardTags: hazardTags,
//       confidenceScore: 0.75 + _random.nextDouble() * 0.2,
//       imagePath: imagePath,
//       analyzedAt: DateTime.now(),
//     );
//   }
// }

// class DroneAnalysisException implements Exception {
//   final String message;
//   DroneAnalysisException(this.message);
//   @override
//   String toString() => message;
// }

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