/// Execution transport is deliberately separate from strategy selection.
///
/// API contracts and MT5 CFDs are different products even when they reference
/// the same underlying market. The strategy layer produces a normalized trade
/// intent; an approved adapter decides how that intent is executed.
enum AntagonisticExecutionRoute {
  derivApi,
  mt5Cfd,
}

extension AntagonisticExecutionRouteLabel on AntagonisticExecutionRoute {
  String get label => switch (this) {
        AntagonisticExecutionRoute.derivApi => 'Deriv API',
        AntagonisticExecutionRoute.mt5Cfd => 'MT5 CFD',
      };

  String get description => switch (this) {
        AntagonisticExecutionRoute.derivApi =>
          'Direct authenticated Deriv contract execution. No Windows MT5 terminal required.',
        AntagonisticExecutionRoute.mt5Cfd =>
          'CFD execution through a logged-in Deriv MT5 terminal on an always-on host.',
      };
}
