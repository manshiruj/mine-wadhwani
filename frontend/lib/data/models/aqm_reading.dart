/// Fields are nullable: real aqi.in devices only report the sensors they have.
class AqmReading {
  final double? pm25;
  final double? pm10;
  final double? pm1;
  final double? tvoc;
  final double? co;
  final double? co2;
  final double? h2s;
  final double? methane;
  final double? temperature;
  final double? humidity;
  final int? noise;
  final int? aqiUs;
  final String? deviceName;
  final String? lastUpdated;
  final DateTime fetchedAt;

  const AqmReading({
    this.pm25,
    this.pm10,
    this.pm1,
    this.tvoc,
    this.co,
    this.co2,
    this.h2s,
    this.methane,
    this.temperature,
    this.humidity,
    this.noise,
    this.aqiUs,
    this.deviceName,
    this.lastUpdated,
    required this.fetchedAt,
  });

  factory AqmReading.fromJson(Map<String, dynamic> json) {
    double? d(String k) => (json[k] as num?)?.toDouble();
    return AqmReading(
      pm25: d('pm25'),
      pm10: d('pm10'),
      pm1: d('pm1'),
      tvoc: d('tvoc'),
      co: d('co'),
      co2: d('co2'),
      h2s: d('h2s'),
      methane: d('methane'),
      temperature: d('temperature'),
      humidity: d('humidity'),
      noise: (json['noise'] as num?)?.round(),
      aqiUs: (json['aqiUs'] as num?)?.round(),
      fetchedAt: DateTime.now(),
    );
  }

  /// Builds from backend `/api/v1/aqm/latest` data:
  /// `{ devicename, last_updated, sensors: { "PM25": {value, unit}, "CO2(ppm)": {...} } }`.
  factory AqmReading.fromAqiIn(Map<String, dynamic> data) {
    final sensors = (data['sensors'] as Map?)?.cast<String, dynamic>() ?? {};
    // aqi.in names look like "PM25", "CO2(ppm)", "Temp(cel)"; match on the part before "(".
    // First sensor wins, so "Temp(cel)" is not overwritten by the uncalibrated "Temp(orignal)".
    final byName = <String, double?>{};
    for (final e in sensors.entries) {
      if (e.key.toLowerCase().contains('(fer)')) continue; // skip °F twin of Temp(cel)
      byName.putIfAbsent(e.key.toLowerCase().replaceAll(' ', '').split('(').first,
          () => ((e.value as Map?)?['value'] as num?)?.toDouble());
    }
    double? pick(List<String> names) {
      for (final n in names) {
        if (byName[n] != null) return byName[n];
      }
      return null;
    }

    return AqmReading(
      pm25: pick(['pm25', 'pm2.5']),
      pm10: pick(['pm10']),
      pm1: pick(['pm1']),
      tvoc: pick(['tvoc']),
      co: pick(['co']),
      co2: pick(['co2']),
      h2s: pick(['h2s']),
      methane: pick(['ch4', 'methane']),
      temperature: pick(['temp']),
      humidity: pick(['hum', 'humidity']),
      noise: pick(['noise', 'sound'])?.round(),
      aqiUs: pick(['aqi-us'])?.round(),
      deviceName: data['devicename'] as String?,
      lastUpdated: data['last_updated'] as String?,
      fetchedAt: DateTime.now(),
    );
  }
}
