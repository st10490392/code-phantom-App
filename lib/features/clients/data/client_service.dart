import '../../../core/permissions/permission_set.dart';
import '../domain/client_profile.dart';

abstract class ClientService {
  Stream<List<ClientProfile>> watchClients();

  Future<void> setServiceAccess(String userId, PermissionSet permissions);

  Future<void> suspend(String userId);

  Future<void> reactivate(String userId);
}
