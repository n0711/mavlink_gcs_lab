const parameterCategoryAll = 'All categories';
const parameterReviewTagAll = 'All tags';
const parameterReviewTagNone = 'No tag';

const parameterCategories = [
  parameterCategoryAll,
  'Battery',
  'GPS / GNSS',
  'EKF / AHRS',
  'Failsafe',
  'Arming',
  'RC / Radio',
  'Motors / Servo',
  'Navigation',
  'Mission',
  'Communication',
  'Other',
];

const parameterReviewTags = [
  parameterReviewTagAll,
  'Power relevant',
  'Navigation relevant',
  'State-estimation relevant',
  'Failsafe relevant',
  'Arming relevant',
  'Radio/control-input relevant',
  'Actuator-output relevant',
  'Communication relevant',
  parameterReviewTagNone,
];

class ParameterMetadata {
  const ParameterMetadata({required this.category, this.relevanceTag});

  final String category;
  final String? relevanceTag;
}

ParameterMetadata metadataForParameter(String name) {
  final normalized = name.trim().toUpperCase();

  if (_startsWithAny(normalized, const ['BATT_', 'BAT_']) ||
      RegExp(r'^BATT?\d_').hasMatch(normalized)) {
    return const ParameterMetadata(
      category: 'Battery',
      relevanceTag: 'Power relevant',
    );
  }
  if (_startsWithAny(normalized, const ['GPS_', 'GNSS_']) ||
      RegExp(r'^GPS\d_').hasMatch(normalized)) {
    return const ParameterMetadata(
      category: 'GPS / GNSS',
      relevanceTag: 'Navigation relevant',
    );
  }
  if (_startsWithAny(normalized, const ['EKF_', 'AHRS_', 'INS_']) ||
      RegExp(r'^EK\d?_').hasMatch(normalized)) {
    return const ParameterMetadata(
      category: 'EKF / AHRS',
      relevanceTag: 'State-estimation relevant',
    );
  }
  if (_startsWithAny(normalized, const ['FS_', 'FENCE_'])) {
    return const ParameterMetadata(
      category: 'Failsafe',
      relevanceTag: 'Failsafe relevant',
    );
  }
  if (normalized.startsWith('ARMING_')) {
    return const ParameterMetadata(
      category: 'Arming',
      relevanceTag: 'Arming relevant',
    );
  }
  if (_startsWithAny(normalized, const ['RC_', 'RSSI_']) ||
      RegExp(r'^RC\d').hasMatch(normalized)) {
    return const ParameterMetadata(
      category: 'RC / Radio',
      relevanceTag: 'Radio/control-input relevant',
    );
  }
  if (_startsWithAny(normalized, const ['SERVO_', 'MOT_', 'Q_M_']) ||
      RegExp(r'^SERVO\d').hasMatch(normalized)) {
    return const ParameterMetadata(
      category: 'Motors / Servo',
      relevanceTag: 'Actuator-output relevant',
    );
  }
  if (_startsWithAny(normalized, const ['NAV_', 'WP_', 'WPNAV_'])) {
    return const ParameterMetadata(
      category: 'Navigation',
      relevanceTag: 'Navigation relevant',
    );
  }
  if (_startsWithAny(normalized, const ['MIS_', 'MISSION_', 'DO_'])) {
    return const ParameterMetadata(category: 'Mission');
  }
  if (_startsWithAny(normalized, const [
        'SERIAL_',
        'MAV_',
        'SR0_',
        'SR1_',
        'SR2_',
        'SR3_',
      ]) ||
      RegExp(r'^SERIAL\d').hasMatch(normalized) ||
      RegExp(r'^SR\d_').hasMatch(normalized)) {
    return const ParameterMetadata(
      category: 'Communication',
      relevanceTag: 'Communication relevant',
    );
  }

  return const ParameterMetadata(category: 'Other');
}

bool _startsWithAny(String value, List<String> prefixes) {
  for (final prefix in prefixes) {
    if (value.startsWith(prefix)) return true;
  }
  return false;
}
