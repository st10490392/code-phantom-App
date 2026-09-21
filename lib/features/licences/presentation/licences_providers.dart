import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/licence_service.dart';
import '../data/mock_licence_service.dart';
import '../domain/licence.dart';

final licenceServiceProvider = Provider<LicenceService>((ref) => MockLicenceService());

final licenceListProvider = StreamProvider<List<Licence>>((ref) {
  return ref.watch(licenceServiceProvider).watchLicences();
});
