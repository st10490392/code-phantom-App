import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../auth/presentation/auth_providers.dart';
import 'license_controller.dart';
import 'license_forms.dart';
import 'trading_service.dart';

class OwnerLicenses extends ConsumerStatefulWidget {
  const OwnerLicenses({super.key});
  @override
  ConsumerState<OwnerLicenses> createState() => _OwnerState();
}

class _OwnerState extends ConsumerState<OwnerLicenses> {
  final master = TextEditingController();
  TradingService? api;
  String account = '',
      scope = 'SIGNALS_ONLY',
      created = '',
      error = '',
      expiry = '';
  bool busy = false;
  List rows = [];
  @override
  void dispose() {
    api?.dio.close(force: true);
    master.dispose();
    super.dispose();
  }

  Future<void> run([Future<void> Function()? change]) async {
    if (busy || ref.read(currentUserProvider)?.isOwner != true) return;
    setState(() => busy = true);
    try {
      api ??= TradingService(TradingProfile.match, master.text, tradingUrl);
      if (change != null) await change();
      final r = await api!.dio.get<List>('/admin/licenses');
      if (mounted) {
        setState(() {
          rows = r.data!;
          master.clear();
          error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = apiError(e);
          if (rows.isEmpty) {
            api?.dio.close();
            api = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> action(Json row, String verb) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$verb license?'),
        content: Text('${row['account']} · ${row['id']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(verb),
          ),
        ],
      ),
    );
    if (mounted && ok == true) {
      await run(() async {
        await api!.dio.post(
          '/admin/licenses/${row['id']}/${verb == 'Revoke' ? 'revoke' : 'reset'}',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(currentUserProvider)?.isOwner != true) {
      return const Scaffold(
        body: Center(child: Text('Owner access required.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Trading licenses')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (api == null) ...[
            TextField(
              controller: master,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Owner master credential',
              ),
            ),
            FilledButton(
              onPressed: busy ? null : () => run(),
              child: const Text('Unlock'),
            ),
          ] else ...[
            TextField(
              decoration: const InputDecoration(
                labelText: 'Registered engine account',
              ),
              onChanged: (v) => account = v.trim(),
            ),
            DropdownButton<String>(
              value: scope,
              items: [
                for (final s in ['SIGNALS_ONLY', 'EA_ONLY', 'FULL_ACCESS'])
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) => setState(() => scope = v!),
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Optional expiration (ISO 8601 with timezone)',
              ),
              onChanged: (v) => expiry = v.trim(),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                        final r = await api!.dio.post<Json>(
                          '/admin/licenses',
                          data: {
                            'account': account,
                            'scope': scope,
                            if (expiry.isNotEmpty) 'expires_at': expiry,
                          },
                        );
                        created = r.data!['license_key'];
                      }),
              child: const Text('Generate key'),
            ),
            if (created.isNotEmpty) ...[
              const Text('New key · shown once'),
              SelectableText(created),
              Wrap(
                children: [
                  TextButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: created)),
                    child: const Text('Copy'),
                  ),
                  TextButton(
                    onPressed: () =>
                        SharePlus.instance.share(ShareParams(text: created)),
                    child: const Text('Share'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => created = ''),
                    child: const Text('Hide'),
                  ),
                ],
              ),
            ],
            for (final row in rows)
              ListTile(
                title: Text("${row['account']} · ${row['scope']}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Device: ${row['device'] ?? 'Unbound'}\nMT5: ${row['login'] ?? '—'} · ${row['server'] ?? '—'}\n${row['revoked'] == 1 ? 'Revoked' : 'Issued'}",
                    ),
                    if (row['revoked'] != 1)
                      Wrap(
                        children: [
                          TextButton(
                            onPressed:
                                busy ? null : () => action(row, 'Unbind'),
                            child: const Text('Unbind'),
                          ),
                          TextButton(
                            onPressed:
                                busy ? null : () => action(row, 'Revoke'),
                            child: const Text('Revoke'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
          if (error.isNotEmpty) Text(error),
        ],
      ),
    );
  }
}
