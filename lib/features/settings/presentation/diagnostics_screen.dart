import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/network/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/data/api_auth_service.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../ea/data/api_ea_service.dart';
import '../../ea/presentation/ea_providers.dart';
import '../../scanner/data/api_scanner_service.dart';
import '../../scanner/presentation/scanner_providers.dart';
import '../../signals/data/api_signal_service.dart';
import '../../signals/presentation/signals_providers.dart';

/// On-device proof of what a build is actually connected to — added after a
/// signed staging build "looked the same" on a physical phone with no way
/// to confirm from the device alone whether that was a real (if unchanged)
/// backend response, a build that never actually reinstalled, or a real
/// wiring bug. Never shows a token, password, or any signing material —
/// only build metadata, the configured (non-secret) API host, which
/// service implementation is active per module, and the result of a single
/// unauthenticated liveness probe.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  PackageInfo? _packageInfo;
  bool _isChecking = false;
  _ConnectionCheckResult? _result;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isChecking = true;
      _result = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final data = await ref.read(apiClientProvider).checkHealth();
      setState(() {
        _result = _ConnectionCheckResult.success(
          elapsedMs: stopwatch.elapsedMilliseconds,
          backendEnv: data['env'] as String? ?? 'unknown',
          backendVersion: data['version'] as String? ?? 'unknown',
        );
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _result = _ConnectionCheckResult.failure(
          message: e is AppException ? e.message : 'Could not reach the backend.',
        );
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final environment = ref.watch(appEnvironmentProvider);
    final isMock = environment == AppEnvironment.mock;

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Section(
            title: 'Build',
            rows: [
              _Row(
                'Version',
                _packageInfo == null
                    ? '…'
                    : '${_packageInfo!.version}+${_packageInfo!.buildNumber}',
              ),
              _Row('Package', _packageInfo?.packageName ?? '…'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Environment',
            rows: [
              _Row('Target', environment.label),
              _Row('API base URL', isMock ? 'None — mock mode' : ApiConfig.baseUrl),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Data source per module',
            rows: [
              _Row('Auth', ref.read(authServiceProvider) is ApiAuthService ? 'API' : 'Mock'),
              _Row('Scanner', ref.read(scannerServiceProvider) is ApiScannerService ? 'API' : 'Mock'),
              _Row('Signals', ref.read(signalServiceProvider) is ApiSignalService ? 'API' : 'Mock'),
              _Row('EA', ref.read(eaServiceProvider) is ApiEAService ? 'API' : 'Mock'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          isMock ? _buildMockNotice() : _buildConnectionCheck(environment),
        ],
      ),
    );
  }

  Widget _buildMockNotice() {
    return const PhantomCard(
      child: Text('Mock mode has no backend to connect to — every module above is Mock.'),
    );
  }

  Widget _buildConnectionCheck(AppEnvironment environment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhantomButton(
          label: 'Test connection',
          expand: true,
          variant: PhantomButtonVariant.secondary,
          isLoading: _isChecking,
          onPressed: _isChecking ? null : _testConnection,
        ),
        if (_result != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ConnectionResultCard(result: _result!, appEnvironment: environment),
        ],
      ],
    );
  }
}

class _ConnectionCheckResult {
  const _ConnectionCheckResult.success({
    required this.elapsedMs,
    required this.backendEnv,
    required this.backendVersion,
  })  : ok = true,
        errorMessage = null;

  const _ConnectionCheckResult.failure({required String message})
      : ok = false,
        errorMessage = message,
        elapsedMs = null,
        backendEnv = null,
        backendVersion = null;

  final bool ok;
  final int? elapsedMs;
  final String? backendEnv;
  final String? backendVersion;
  final String? errorMessage;
}

class _ConnectionResultCard extends StatelessWidget {
  const _ConnectionResultCard({required this.result, required this.appEnvironment});

  final _ConnectionCheckResult result;
  final AppEnvironment appEnvironment;

  @override
  Widget build(BuildContext context) {
    if (!result.ok) {
      return PhantomCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.error, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('Unreachable: ${result.errorMessage}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error),),
            ),
          ],
        ),
      );
    }

    // The one check this screen exists for: does what this build was
    // compiled as actually match what the backend it just reached reports
    // itself as? A mismatch here (e.g. this build says Production but the
    // backend says staging) means the two were never in agreement, no
    // matter how the app's own dart-defines were set.
    final mismatch = result.backendEnv!.toLowerCase() != appEnvironment.label.toLowerCase();

    return PhantomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_outlined, color: AppColors.success, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Reachable · ${result.elapsedMs}ms',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.success),),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Backend reports: ${result.backendEnv} (v${result.backendVersion})',
              style: AppTypography.mono(fontSize: 12, color: AppColors.mutedText),),
          if (mismatch) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Mismatch: this build targets ${appEnvironment.label}, but the backend it just '
              'reached reports "${result.backendEnv}". You are not talking to the backend you '
              'think you are.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        PhantomCard(
          child: Column(children: [for (final r in rows) r]),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedText)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.mono(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
