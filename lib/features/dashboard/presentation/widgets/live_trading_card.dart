import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/app_exceptions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/phantom_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../live_feed/data/live_feed_service.dart';
import '../../../live_feed/domain/live_feed_event.dart';
import '../../../live_feed/presentation/live_feed_providers.dart';
import '../../../trading_status/domain/trading_status.dart';
import '../../../trading_status/presentation/trading_status_providers.dart';
import 'trading_control_row.dart';

/// The dashboard's live-trading section: what the operator's daemon reports
/// right now, straight from the trading bridge. Every row reads a real field;
/// a value the bridge did not report renders as "Unavailable", never as a
/// plausible-looking default.
///
/// Shown only when the account has EA access — a client without EA access has
/// no trading state to look at. Controls are gated separately in
/// `TradingControlRow`.
class LiveTradingCard extends ConsumerWidget {
  const LiveTradingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(tradingStatusProvider);
    final positions = ref.watch(openPositionsProvider);
    final performance = ref.watch(tradingPerformanceProvider);
    final feedStatus = ref.watch(liveFeedStatusProvider).value ?? LiveFeedStatus.unconfigured;
    final events = ref.watch(liveFeedEventsProvider).value ?? const <LiveFeedEvent>[];
    final user = ref.watch(currentUserProvider);

    return PhantomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Live trading', style: Theme.of(context).textTheme.titleMedium)),
              StatusBadge(label: _feedLabel(feedStatus), color: feedStatus == LiveFeedStatus.live ? AppColors.success : AppColors.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _statusSection(context, status),
          const SizedBox(height: AppSpacing.lg),
          _positionsSection(context, positions),
          if (performance.value != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _PerformanceRow(performance: performance.value as TradingPerformance),
          ],
          if (events.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Recent feed events', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            for (final event in events.take(4)) _FeedRow(event: event),
          ],
          if (user != null) ...[
            const SizedBox(height: AppSpacing.lg),
            TradingControlRow(isOwner: user.isOwner, permissions: user.permissions),
          ],
        ],
      ),
    );
  }

  String _feedLabel(LiveFeedStatus status) => switch (status) {
        LiveFeedStatus.live => 'Feed live',
        LiveFeedStatus.connecting => 'Feed connecting',
        LiveFeedStatus.reconnecting => 'Feed reconnecting',
        LiveFeedStatus.unavailable => 'Feed down',
        LiveFeedStatus.unauthenticated => 'No SIGNALS key',
        LiveFeedStatus.unconfigured => 'No bridge',
      };

  Widget _statusSection(BuildContext context, AsyncValue<TradingStatus> status) {
    final value = status.value;
    if (value != null) return _StatusRows(status: value);
    if (status.hasError) {
      final error = status.error;
      return Text(
        error is AppException ? error.message : 'The trading bridge could not be reached.',
        style: const TextStyle(color: AppColors.warning),
      );
    }
    return const Text('Checking the trading bridge…', style: TextStyle(color: AppColors.mutedText));
  }

  Widget _positionsSection(BuildContext context, AsyncValue<List<LivePosition>> positions) {
    final rows = positions.value;
    if (rows == null) {
      return Text(
        positions.hasError ? 'Positions could not be read.' : 'Loading positions…',
        style: TextStyle(
          color: positions.hasError ? AppColors.warning : AppColors.mutedText,
        ),
      );
    }
    if (rows.isEmpty) {
      return Text('No open positions.', style: AppTypography.mono(fontSize: 12, color: AppColors.mutedText));
    }
    return Column(children: [for (final p in rows.take(8)) _PositionRow(position: p)]);
  }
}


class _StatusRows extends StatelessWidget {
  const _StatusRows({required this.status});

  final TradingStatus status;

  @override
  Widget build(BuildContext context) {
    final mt5 = switch (status.mt5Connected) {
      null => 'Unavailable',
      true => 'Connected',
      false => 'Disconnected',
    };
    final licence = switch (status.eaLicensed) {
      null => 'Unavailable',
      true => 'Valid',
      false => 'Invalid',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(context, 'MT5 terminal', mt5),
        _row(context, 'Trading', status.paused ? 'Paused' : 'Running'),
        _row(context, 'Scanner', status.scanMode == null ? 'Unavailable' : 'Scanning (${status.scanMode})'),
        _row(context, 'Open positions', status.openPositions == null ? 'Unavailable' : '${status.openPositions}'),
        _row(context, 'Daemon licence', licence),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      key: ValueKey('$label:$value'),
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(value, style: AppTypography.mono(fontSize: 12)),
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  const _PositionRow({required this.position});

  final LivePosition position;

  @override
  Widget build(BuildContext context) {
    final r = position.floatingR;
    return Padding(
      key: ValueKey('position-${position.ticket}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${position.symbol} ${position.direction} · ${position.volume} lots',
              style: AppTypography.mono(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // No client-side P&L: the bridge reports favourable R only when MT5
          // answers a tick, and a null there is displayed as exactly that.
          Text(
            r == null ? 'no price' : '${r >= 0 ? '+' : ''}${r.toStringAsFixed(2)}R',
            style: AppTypography.mono(
              fontSize: 12,
              color: r == null ? AppColors.mutedText : (r >= 0 ? AppColors.success : AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  const _PerformanceRow({required this.performance});

  final TradingPerformance performance;

  @override
  Widget build(BuildContext context) {
    final pf = performance.profitFactor;
    return Text(
      '${performance.totalTrades} trades · ${performance.winRatePercent.toStringAsFixed(0)}% win · '
      '${performance.netR.toStringAsFixed(2)}R net · PF ${pf == null ? 'unbounded' : pf.toStringAsFixed(2)}',
      style: AppTypography.mono(fontSize: 12, color: AppColors.mutedText),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.event});

  final LiveFeedEvent event;

  @override
  Widget build(BuildContext context) {
    final label = switch (event) {
      final SignalEvent e => '${e.symbol} ${e.direction} ${e.kind}',
      final TradeEvent e => e.message ?? 'Trade event (${e.kind})',
      final ControlEvent e => 'Trading ${e.paused ? 'paused' : 'running'}',
      final LicenseEvent e => 'Licence ${e.serviceType} updated',
      final PushEvent e => 'Device ${e.action}',
      final HelloEvent e => 'Subscribed (${e.service})',
    };
    return Padding(
      key: ValueKey(event.dedupeKey),
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(label, style: AppTypography.mono(fontSize: 12), overflow: TextOverflow.ellipsis),
    );
  }
}
