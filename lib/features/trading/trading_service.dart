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
  String get path => '/accounts/${Uri.encodeComponent(profile.account)}';
  Future<Json> snapshot() async {
    final status = (await dio.get<Json>('$path/status')).data!;
    if (status['profile'] != profile.profile) {
      throw const FormatException(
        'Account is bound to a different trading profile.',
      );
    }
    final parts = await Future.wait([
      dio.get('/market-bias', queryParameters: {'account': profile.account}),
      dio.get('$path/alerts'),
      dio.get('$path/history'),
    ]);
    return {
      'status': status,
      'bias': parts[0].data,
      'alerts': parts[1].data,
      'history': parts[2].data,
    };
  }

  Future<void> settings(Json patch) async {
    await dio.patch('$path/settings', data: patch);
  }

  Future<void> flatten() async {
    await dio.post('$path/commands/FLATTEN_ALL_AND_PAUSE');
  }
}
