import '../../../core/network/api_client.dart';
import '../domain/ea_account.dart';
import '../domain/ea_enums.dart';
import 'ea_services.dart';

/// Account monitoring only. The EA remains on its VPS and no commands are
/// issued by this app while strategy validation is pending.
class ApiEAService implements EAService, EAAccountService, EAControlService {
  ApiEAService(this._client);
  final ApiClient _client;

  @override
  Future<List<EAAccount>> listAccounts() async {
    final response = await _client.get('/ea/accounts', query: {'limit': 200});
    final rows = response['data'] as List<dynamic>;
    return Future.wait(rows.map((row) => _withStatus(row as Map<String, dynamic>)));
  }

  @override
  Future<EAAccount> getAccount(String accountId) async {
    final response = await _client.get('/ea/accounts/${Uri.encodeComponent(accountId)}');
    return _withStatus(response['data'] as Map<String, dynamic>);
  }

  @override
  Stream<EAAccount> watchAccount(String accountId) async* {
    yield await getAccount(accountId);
    yield* Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) => getAccount(accountId));
  }

  Future<EAAccount> _withStatus(Map<String, dynamic> account) async {
    final id = account['id'] as String;
    final response = await _client.get('/ea/accounts/${Uri.encodeComponent(id)}/status');
    final metrics = response['data'] as Map<String, dynamic>;
    final heartbeat = metrics['last_heartbeat_at'] as String?;
    final isRecent = heartbeat != null &&
        DateTime.now().difference(DateTime.parse(heartbeat)).inMinutes < 5;
    return EAAccount(
      accountId: id,
      nickname: account['account_label'] as String? ?? id,
      broker: account['broker'] as String? ?? 'Unknown broker',
      status: isRecent ? EAConnectionStatus.online : EAConnectionStatus.offline,
      tradingEnabled: account['trading_enabled'] as bool? ?? false,
      riskMode: RiskMode.fromWire(account['risk_mode'] as String? ?? ''),
      riskPercentage: _number(account['risk_percentage']),
      balance: _number(metrics['balance']),
      equity: _number(metrics['equity']),
      dailyProfit: _number(metrics['daily_pl']),
      dailyDrawdown: _number(metrics['drawdown_percentage']),
      openTrades: metrics['open_trades_count'] as int? ?? 0,
      lastHeartbeat: heartbeat == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(heartbeat),
      serverStatus: isRecent ? 'Connected' : 'No recent heartbeat',
    );
  }

  double _number(Object? value) =>
      value == null ? 0 : value is num ? value.toDouble() : double.parse(value as String);

  Never _paused() => throw StateError('EA controls are paused until backtests pass.');

  @override
  Future<void> pauseTrading(String accountId) async => _paused();
  @override
  Future<void> resumeTrading(String accountId) async => _paused();
  @override
  Future<void> setRiskMode(String accountId, RiskMode mode) async => _paused();
  @override
  Future<void> setRiskPercentage(String accountId, double percentage) async => _paused();
  @override
  Future<void> disableNewEntries(String accountId) async => _paused();
  @override
  Future<void> emergencyStop(String accountId) async => _paused();
}
