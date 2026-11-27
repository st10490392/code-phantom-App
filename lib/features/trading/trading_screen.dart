import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/permissions/permission.dart';
import '../auth/presentation/auth_providers.dart';
import 'trading_service.dart';
import 'license_controller.dart';
import 'license_forms.dart';

class TradingScreen extends ConsumerWidget {
  const TradingScreen({super.key, this.controls = false});
  final bool controls;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final license = ref.watch(licenseProvider);
    final api = license.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(controls ? 'EA controls' : 'Market signals'),
        actions: [
          if (api != null)
            TextButton(
              onPressed: () => ref.read(licenseProvider.notifier).clear(),
              child: const Text('Change license'),
            ),
        ],
      ),
      body: license.isLoading
          ? const Center(child: CircularProgressIndicator())
          : api == null
              ? ActivationForm(restoreError: license.hasError)
              : _AccountView(
                  key: ObjectKey(api),
                  profile: api.profile,
                  service: api,
                  controls: controls,
                ),
    );
  }
}

class _AccountView extends ConsumerStatefulWidget {
  const _AccountView({
    super.key,
    required this.profile,
    required this.service,
    required this.controls,
  });
  final TradingService service;
  final bool controls;
  final TradingProfile profile;
  @override
  ConsumerState<_AccountView> createState() => _AccountState();
}

class _AccountState extends ConsumerState<_AccountView> {
  @override
  void initState() {
    super.initState();
    api = widget.service;
    controls = widget.controls;
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (ModalRoute.of(context)?.isCurrent == true) refresh();
    });
    refresh();
  }

  TradingService? api;
  Json? data;
  String? error;
  bool busy = false, controls = false;
  Timer? timer;
  @override
  void dispose() {
    timer?.cancel();

    super.dispose();
  }

  String message(Object e) {
    if (e is FormatException) return e.message;
    if (e is DioException && e.response != null) {
      return 'Trading API returned HTTP ${e.response!.statusCode}. Check account access and settings.';
    }
    return 'Trading API unavailable. Check your connection.';
  }

  Future<void> refresh({Future<void> Function()? change}) async {
    if (busy || api == null) return;
    setState(() => busy = true);
    try {
      if (change != null) await change();
      final updated = await api!.snapshot();
      if (mounted) {
        setState(() {
          data = updated;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = message(e);
          data = null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(String label, String field, num current) async {
    String input = current.toString();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextFormField(
          initialValue: input,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => input = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final n = double.tryParse(input);
              if (n != null && n.isFinite && n > 0) {
                Navigator.pop(ctx, n);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (mounted && value != null) {
      await refresh(change: () => api!.settings({field: value}));
    }
  }

  Future<void> flatten() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Flatten all and pause?'),
        content: Text(
          'Flatten positions and pause execution for ${widget.profile.account}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Flatten and pause'),
          ),
        ],
      ),
    );
    if (mounted && ok == true) await refresh(change: () => api!.flatten());
  }

  Widget heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
  String val(dynamic x) => x?.toString() ?? '—';
  List<Widget> market(Json snap) {
    final bias = snap['bias'] as Json;
    final alerts = snap['alerts'] as List;
    return [
      for (final item in bias.entries) ...[
        heading('${item.key} · ${val(item.value['direction'])}'),
        if (item.value['stale'] == true) const Text('Market data stale'),
        for (final t in ((item.value['trends'] as Json?) ?? {}).entries)
          Text(
            '${t.key}  ${t.value['direction']} · Close ${t.value['close']} · EMA ${t.value['ema']}',
          ),
        for (final l in ((item.value['liquidity'] as Json?) ?? {}).entries)
          Text('${l.key} high ${l.value['high']} · low ${l.value['low']}'),
        if (item.value['ai']
            case {
              'confidence': final num score,
              'commentary': final String note
            }
            when item.value['stale'] != true &&
                item.value['ai']['available'] != false) ...[
          Text('AI confidence: ${(score * 100).toStringAsFixed(1)}%'),
          Text('AI market direction: $note'),
        ] else
          const Text('AI assessment unavailable'),
      ],
      heading('Setup alerts'),
      if (alerts.isEmpty) const Text('No setup alerts yet.'),
      for (final a in alerts.reversed)
        ListTile(
          title: Text('${a['symbol']} · ${a['side']} · ${a['strategy']}'),
          subtitle: Text(
              '${stamp(a['opened_at'])}\nEntry ${a['entry']} · SL ${a['stop']} · ${[
            'partialtrail',
            'be',
          ].contains(a['exit_rule']) ? '1R milestone' : 'TP'} ${a['target']}'),
        ),
    ];
  }

  String stamp(dynamic seconds) => seconds is num
      ? DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000).round(),
          isUtc: true,
        ).toIso8601String()
      : '';
  List<Widget> risk(Json snap, bool allowed) {
    final s = snap['status'] as Json, c = s['config'] as Json;
    final fields = {
      if (c['risk_amount_usd'] == null)
        'risk_pct': 'Risk per trade (%)'
      else
        'risk_amount_usd': 'Risk per trade (USD)',
      if (c['daily_loss_cap_usd'] == null)
        'daily_loss_cap_pct': 'Daily loss cap (%)'
      else
        'daily_loss_cap_usd': 'Daily loss cap (USD)',
      'max_dd_cap_pct': 'Maximum drawdown (%)',
    };
    return [
      heading('Account status'),
      Text(
        'Broker execution requested: ${s['broker_execution_requested'] == true ? 'yes' : 'no'} ? Shadow ledger',
      ),
      Text('Equity ${s['equity']} · Floating P&L ${s['floating_pnl']}'),
      Text(
        'Daily loss ${s['daily_loss_pct']}% · Drawdown ${s['drawdown_pct']}%',
      ),
      Text(
        'Lock: ${s['locked'] ?? 'None'} · News pause: ${s['news_pause'] ?? 'None'}',
      ),
      for (final field in fields.entries)
        ListTile(
          title: Text(field.value),
          trailing: Text(val(c[field.key])),
          onTap: allowed && !busy
              ? () => edit(field.value, field.key, c[field.key] as num)
              : null,
        ),
      for (final setup in c['setups'])
        SwitchListTile(
          title: Text('${setup['symbol']} · ${setup['strategy']}'),
          value: setup['enabled'] == true,
          onChanged: !allowed || busy
              ? null
              : (v) => refresh(
                    change: () => api!.settings({
                      'setups': [
                        {
                          'symbol': setup['symbol'],
                          'strategy': setup['strategy'],
                          'enabled': v,
                        }
                      ],
                    }),
                  ),
        ),
      if (allowed)
        OutlinedButton(
          onPressed: busy ? null : flatten,
          child: const Text('Flatten all and pause'),
        ),
      for (final group in ['positions', 'history']) ...[
        heading(group == 'positions' ? 'Open positions' : 'Trade history'),
        if ((group == 'positions' ? s[group] : snap[group]).isEmpty)
          const Text('None'),
        for (final p
            in (group == 'positions' ? s[group] : snap[group]).reversed)
          ListTile(
            title: Text('${p['symbol']} · ${p['side']} · ${p['volume']}'),
            subtitle: Text(
              'Entry ${p['entry']} · SL ${p['stop']} · Target ${p['target']}${p['reason'] == null ? '' : '\n${p['reason']} · P&L ${p['net_pnl']}'}',
            ),
          ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(hasPermissionProvider(Permission.eaControl));
    final locked = controls ? !widget.service.ea : !widget.service.signals;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Account · ${widget.profile.account}'),
        ...[
          Wrap(
            children: [
              ChoiceChip(
                label: const Text('Market Direction & Signals'),
                selected: !controls,
                onSelected: (_) => setState(() => controls = false),
              ),
              ChoiceChip(
                label: const Text('Bot & Risk Controls'),
                selected: controls,
                onSelected: (_) => setState(() => controls = true),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: busy ? null : () => refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (busy) const LinearProgressIndicator(),
        ],
        if (error != null) Text(error!),
        if (locked) const Text('Locked for this license scope.'),
        if (!locked && data != null) ...[
          if (data!['status']?['paper_mode'] == true)
            const Text('Shadow account ledger'),
          if (controls) ...[
            if (allowed) StartForm(api: widget.service, onStarted: refresh),
            ...risk(data!, allowed),
          ] else
            ...market(data!),
        ],
      ],
    );
  }
}
