/// Server-authoritative capability codes for Antagonistic Trader.
///
/// These constants mirror the CodePhantom backend catalog. The APK may use
/// them to decide what to request/render, but the backend remains the security
/// boundary and must independently authorize every protected operation.
abstract final class AntagonisticEntitlements {
  static const String appAccess = 'app.antagonistic.access';
  static const String syntheticsAccess = 'antagonistic.synthetics.access';
  static const String syntheticsExecution =
      'antagonistic.synthetics.execution';

  /// Founder/private research entitlement. Deliberately not granted by the
  /// Antagonistic synthetics licence plan.
  static const String orderFlowAccess = 'antagonistic.orderflow.access';
}
