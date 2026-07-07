import 'package:flutter_test/flutter_test.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_metadata.dart';

void main() {
  test('classifies parameter category and review relevance tags by prefix', () {
    expect(metadataForParameter('BATT_LOW_VOLT').category, 'Battery');
    expect(metadataForParameter('BATT2_LOW_VOLT').category, 'Battery');
    expect(
      metadataForParameter('BATT_LOW_VOLT').relevanceTag,
      'Power relevant',
    );
    expect(metadataForParameter('GPS_TYPE').category, 'GPS / GNSS');
    expect(metadataForParameter('GPS2_TYPE').category, 'GPS / GNSS');
    expect(
      metadataForParameter('GPS_TYPE').relevanceTag,
      'Navigation relevant',
    );
    expect(metadataForParameter('EKF_ENABLE').category, 'EKF / AHRS');
    expect(metadataForParameter('EK3_SRC1_POSXY').category, 'EKF / AHRS');
    expect(metadataForParameter('INS_GYRO_FILTER').category, 'EKF / AHRS');
    expect(
      metadataForParameter('EKF_ENABLE').relevanceTag,
      'State-estimation relevant',
    );
    expect(metadataForParameter('FS_THR_ENABLE').category, 'Failsafe');
    expect(
      metadataForParameter('FENCE_ENABLE').relevanceTag,
      'Failsafe relevant',
    );
    expect(metadataForParameter('ARMING_CHECK').category, 'Arming');
    expect(metadataForParameter('RC1_MIN').category, 'RC / Radio');
    expect(metadataForParameter('SERVO1_FUNCTION').category, 'Motors / Servo');
    expect(metadataForParameter('Q_M_SPIN_ARM').category, 'Motors / Servo');
    expect(
      metadataForParameter('MOT_SPIN_ARM').relevanceTag,
      'Actuator-output relevant',
    );
    expect(metadataForParameter('WPNAV_SPEED').category, 'Navigation');
    expect(metadataForParameter('WP_RADIUS').category, 'Navigation');
    expect(metadataForParameter('MIS_TOTAL').category, 'Mission');
    expect(metadataForParameter('DO_SET_SERVO').category, 'Mission');
    expect(metadataForParameter('SERIAL1_PROTOCOL').category, 'Communication');
    expect(
      metadataForParameter('SR1_POSITION').relevanceTag,
      'Communication relevant',
    );
    expect(metadataForParameter('UNKNOWN_PARAM').category, 'Other');
    expect(metadataForParameter('UNKNOWN_PARAM').relevanceTag, isNull);
  });
}
