class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://mine-wadhwani-4.onrender.com';
  static const Duration connectTimeout = Duration(seconds: 90);
  static const Duration receiveTimeout = Duration(seconds: 90);

  static const String roboflowWorkflowUrl =
    'https://serverless.roboflow.com/infer/workflows/manshi-ruj/ppe-detection-nzzmi';
  static const String roboflowApiKey = '59uEY5fpNgojG3mBjNEa';

  static const String potholeModelUrl =
    'https://serverless.roboflow.com/pothole-detection-i00zy-dwqjk/1';
  static const String crackModelUrl =
      'https://serverless.roboflow.com/pavement-crack-detection-r4n7n/1';

    // AQI.in / Prana Air AQM API
  static const String aqiLoginUrl = 'https://airquality.aqi.in/api/v1/login';
  static const String aqiDevicesUrl = 'https://airquality.aqi.in/api/v1/GetAllUserDevices';
  // TODO(security): move these to a backend proxy before real deployment —
  // credentials should never ship inside a client app long-term.
  static const String aqiEmail = 'sagarwal@iitism.ac.in';
  static const String aqiPassword = '1234567';
  static const String aqmDeviceSerial = '84530304bcb6c';
}

//'https://mine-wadhwani-4.onrender.com';
