import 'ea_enums.dart';

class EAAccount {
  const EAAccount({
    required this.accountId,
    required this.nickname,
    required this.broker,
    required this.status,
    required this.tradingEnabled,
    required this.riskMode,
    required this.riskPercentage,
    required this.balance,
    required this.equity,
    required this.dailyProfit,
    required this.dailyDrawdown,
    required this.openTrades,
    required this.lastHeartbeat,
    required this.serverStatus,
    this.weeklyDrawdown,
  });

  final String accountId;
  final String nickname;
  final String broker;
  final EAConnectionStatus status;
  final bool tradingEnabled;
  final RiskMode riskMode;
  final double riskPercentage;
  final double balance;
  final double equity;
  final double dailyProfit;
  final double dailyDrawdown;
  final double? weeklyDrawdown;
  final int openTrades;
  final DateTime lastHeartbeat;

  /// e.g. "VPS-LON-02 · Healthy" — free text describing the hosting server.
  final String serverStatus;

  EAAccount copyWith({
    EAConnectionStatus? status,
    bool? tradingEnabled,
    RiskMode? riskMode,
    double? riskPercentage,
  }) {
    return EAAccount(
      accountId: accountId,
      nickname: nickname,
      broker: broker,
      status: status ?? this.status,
      tradingEnabled: tradingEnabled ?? this.tradingEnabled,
      riskMode: riskMode ?? this.riskMode,
      riskPercentage: riskPercentage ?? this.riskPercentage,
      balance: balance,
      equity: equity,
      dailyProfit: dailyProfit,
      dailyDrawdown: dailyDrawdown,
      weeklyDrawdown: weeklyDrawdown,
      openTrades: openTrades,
      lastHeartbeat: lastHeartbeat,
      serverStatus: serverStatus,
    );
  }

  factory EAAccount.fromJson(Map<String, dynamic> json) {
    return EAAccount(
      accountId: json['accountId'] as String,
      nickname: (json['nickname'] as String?) ?? json['accountId'] as String,
      broker: (json['broker'] as String?) ?? 'Unknown broker',
      status: EAConnectionStatus.fromWire(json['status'] as String),
      tradingEnabled: json['tradingEnabled'] as bool,
      riskMode: RiskMode.fromWire(json['riskMode'] as String),
      riskPercentage: (json['riskPercentage'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      equity: (json['equity'] as num).toDouble(),
      dailyProfit: (json['dailyProfit'] as num).toDouble(),
      dailyDrawdown: (json['dailyDrawdown'] as num).toDouble(),
      weeklyDrawdown: (json['weeklyDrawdown'] as num?)?.toDouble(),
      openTrades: json['openTrades'] as int,
      lastHeartbeat: DateTime.parse(json['lastHeartbeat'] as String),
      serverStatus: (json['serverStatus'] as String?) ?? 'Unknown',
    );
  }
}
