import 'package:dio/dio.dart';

typedef Json = Map<String, dynamic>;

enum TradingProfile {
  match(
    'Manual Signal Mode',
    'prop_firm_matchtrader',
    String.fromEnvironment(
      'MATCHTRADER_ACCOUNT',
      defaultValue: 'prop_firm_matchtrader',
    ),
  ),
  core(
    'Prop EA Mode',
    'prop_firm_core',
    String.fromEnvironment('PROP_CORE_ACCOUNT', defaultValue: 'prop_firm_core'),
  ),
  deriv(
    'MT5 Bot Mode',
    'deriv_synthetics_mt5',
    String.fromEnvironment(
      'DERIV_ACCOUNT',
      defaultValue: 'deriv_synthetics_mt5',
    ),
  );

  const TradingProfile(this.label, this.profile, this.account);
  final String label, profile, account;
}

class TradingService {
  TradingService(this.profile, String token, String url, {Dio? transport})
      : dio = transport ?? Dio() {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Configure an HTTPS trading API URL.');
    }
    dio.options = BaseOptions(
      baseUrl: url.replaceFirst(RegExp(r'/+$'), ''),
      headers: {'Authorization': 'Bearer ${token.trim()}'},
      followRedirects: false,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    );
  }
  final TradingProfile profile;
  final Dio dio;
  String scope = '', login = '', server = '';
  bool get signals => scope == 'FULL_ACCESS' || scope == 'SIGNALS_ONLY';
  bool get ea => scope == 'FULL_ACCESS' || scope == 'EA_ONLY';
  String get path => '/accounts/${Uri.encodeComponent(profile.account)}';
  Future<Json> snapshot() async {
    final out = <String, dynamic>{};
    if (ea) {
      final status = (await dio.get<Json>('$path/status')).data!;
      if (status['profile'] != profile.profile) {
        throw const FormatException('Account profile mismatch.');
      }
      out['status'] = status;
      out['history'] = (await dio.get('$path/history')).data;
    }
    if (signals) {
      out['bias'] = (await dio.get(
        '/market-bias',
        queryParameters: {'account': profile.account},
      ))
          .data;
      out['alerts'] = (await dio.get('$path/alerts')).data;
    }
    return out;
  }

  Future<void> settings(Json patch) async {
    if (!ea) throw StateError('EA license required');
    await dio.patch('$path/settings', data: patch);
  }

  Future<void> flatten() async {
    if (!ea) throw StateError('EA license required');
    await dio.post('$path/commands/FLATTEN_ALL_AND_PAUSE');
  }
}
