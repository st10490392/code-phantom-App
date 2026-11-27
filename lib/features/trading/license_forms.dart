import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'license_controller.dart';
import 'trading_service.dart';

String apiError(Object error) {
  if (error is FormatException) return error.message;
  if (error is DioException) {
    final detail = error.response?.data;
    if (detail is Map && detail['detail'] is String) return detail['detail'];
    return 'Request failed (${error.response?.statusCode ?? 'offline'}). Check the connection and entered values.';
  }
  return 'Request could not be completed.';
}

class ActivationForm extends ConsumerStatefulWidget {
  const ActivationForm({super.key, required this.restoreError});
  final bool restoreError;
  @override
  ConsumerState<ActivationForm> createState() => _ActivationState();
}

class _ActivationState extends ConsumerState<ActivationForm> {
  TradingProfile profile = TradingProfile.match;
  String keyText = '', login = '', server = '', message = '';
  bool busy = false;
  Future<void> submitActivation() async {
    setState(() => busy = true);
    try {
      await ref
          .read(licenseProvider.notifier)
          .activate(profile, keyText, login, server);
    } catch (e) {
      if (mounted) setState(() => message = apiError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.restoreError)
            const Text(
              'Saved license could not be verified. Reconnect or activate a key.',
            ),
          DropdownButton<TradingProfile>(
            value: profile,
            items: [
              for (final p in TradingProfile.values)
                DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: busy ? null : (v) => setState(() => profile = v!),
          ),
          TextField(
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'License key'),
            onChanged: (v) => keyText = v,
          ),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'MT5 account ID (EA licenses)',
            ),
            onChanged: (v) => login = v,
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Exact MT5 broker server (EA licenses)',
            ),
            onChanged: (v) => server = v,
          ),
          if (message.isNotEmpty) Text(message),
          FilledButton(
            onPressed: busy ? null : submitActivation,
            child: const Text('Activate license'),
          ),
        ],
      );
}

class StartForm extends StatefulWidget {
  const StartForm({required this.api, required this.onStarted, super.key});
  final TradingService api;
  final Future<void> Function() onStarted;
  @override
  State<StartForm> createState() => _StartState();
}

class _StartState extends State<StartForm> {
  late String login = widget.api.login, server = widget.api.server;
  late bool fixed = widget.api.profile == TradingProfile.deriv;
  late String risk = fixed ? '5' : '0.25', daily = fixed ? '20' : '2', dd = '5';
  String feedback = '';
  bool demo = false, busy = false;
  Future<void> start() async {
    final values = [risk, daily, dd].map(double.tryParse).toList();
    if (login.trim().isEmpty ||
        server.trim().isEmpty ||
        values.any((x) => x == null || !x.isFinite || x <= 0)) {
      setState(
        () => feedback =
            'Enter the broker binding and positive finite risk limits.',
      );
      return;
    }
    if (demo && !server.toLowerCase().contains('demo')) {
      setState(() => feedback = 'Choose a Demo server for broker dispatch.');
      return;
    }
    if (demo) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Request demo broker execution?'),
          content: Text(
            'The connected bridge can place orders on $login at $server.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Start demo EA'),
            ),
          ],
        ),
      );
      if (!mounted || ok != true) return;
    }
    setState(() => busy = true);
    try {
      final r = await widget.api.dio.post<Json>(
        '/ea/register-and-start',
        data: {
          'mt5_account_id': login.trim(),
          'mt5_server': server.trim(),
          'risk_mode': fixed ? 'fixed_usd' : 'percent',
          'risk_value': values[0],
          'daily_loss_cap': values[1],
          'max_dd_cap': values[2],
          'demo_live_execution': demo,
        },
      );
      if (mounted) {
        setState(
          () => feedback = r.data?['requires_connected_bridge'] == true
              ? 'Registered. Broker execution requires the matching connected bridge.'
              : 'Registered for paper execution.',
        );
      }
      if (mounted) await widget.onStarted();
    } catch (e) {
      if (mounted) setState(() => feedback = apiError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(String label, String initial, ValueChanged<String> change) =>
      TextFormField(
        initialValue: initial,
        onChanged: change,
        decoration: InputDecoration(labelText: label),
      );
  @override
  Widget build(BuildContext context) => ExpansionTile(
        title: const Text('EA setup & start'),
        children: [
          field('MT5 account ID', login, (v) => login = v),
          field('Broker server', server, (v) => server = v),
          DropdownButton<bool>(
            value: fixed,
            items: const [
              DropdownMenuItem(value: false, child: Text('Percentage risk')),
              DropdownMenuItem(value: true, child: Text('Fixed USD risk')),
            ],
            onChanged: (v) => setState(() => fixed = v!),
          ),
          field('Trade risk (${fixed ? 'USD' : '%'})', risk, (v) => risk = v),
          field(
            'Daily loss cap (${fixed ? 'USD' : '%'})',
            daily,
            (v) => daily = v,
          ),
          field('Maximum drawdown (%)', dd, (v) => dd = v),
          SwitchListTile(
            title: const Text('Request demo broker execution'),
            value: demo,
            onChanged: widget.api.profile == TradingProfile.match
                ? null
                : (v) => setState(() => demo = v),
          ),
          if (feedback.isNotEmpty) Text(feedback),
          FilledButton(
            onPressed: busy ? null : start,
            child: const Text('Start EA'),
          ),
        ],
      );
}
