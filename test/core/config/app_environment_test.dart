import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/config/app_environment.dart';

void main() {
  group('AppEnvironment.fromString', () {
    test('recognizes staging (and its "stage" alias)', () {
      expect(AppEnvironment.fromString('staging'), AppEnvironment.staging);
      expect(AppEnvironment.fromString('STAGING'), AppEnvironment.staging);
      expect(AppEnvironment.fromString('stage'), AppEnvironment.staging);
    });

    test('still recognizes development/dev and production/prod', () {
      expect(AppEnvironment.fromString('development'), AppEnvironment.development);
      expect(AppEnvironment.fromString('dev'), AppEnvironment.development);
      expect(AppEnvironment.fromString('production'), AppEnvironment.production);
      expect(AppEnvironment.fromString('prod'), AppEnvironment.production);
    });

    test('anything unrecognized (including empty) falls back to mock, never staging/production', () {
      expect(AppEnvironment.fromString(''), AppEnvironment.mock);
      expect(AppEnvironment.fromString('whatever'), AppEnvironment.mock);
    });

    test('staging and production are distinct values, not aliases of each other', () {
      expect(AppEnvironment.staging, isNot(AppEnvironment.production));
      expect(AppEnvironment.staging.label, 'Staging');
      expect(AppEnvironment.production.label, 'Production');
    });
  });
}
