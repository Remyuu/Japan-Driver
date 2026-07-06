import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/liquid_glass.dart';
import '../models/progress_store.dart';
import '../providers.dart';
import '../widgets/account_gate.dart';
import '../widgets/app_settings_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(accountUserProvider);
    final hasAccount = userAsync.value != null;
    final progress =
        ref.watch(progressControllerProvider).value ?? ProgressStore.empty();

    void openFavorites(String stageId) {
      if (!hasAccount) {
        showAccountDialog(context, ref);
        return;
      }
      context.push('/favorites/$stageId');
    }

    void openWrongReview() {
      if (!hasAccount) {
        showAccountDialog(context, ref);
        return;
      }
      context.push('/review/wrong');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Japan Driver'),
        actions: [
          const AppSettingsButton(),
          IconButton(
            tooltip: '統計',
            onPressed: () => context.push('/stats'),
            icon: const Icon(Icons.bar_chart_rounded),
          ),
          const AccountButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: LiquidBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DashboardHero(
                      progress: progress,
                      hasAccount: hasAccount,
                      onKarimenPractice: () => context.push('/stage/karimen'),
                      onSotsukenPractice: () => context.push('/stage/sotsuken'),
                      onWrongReview: openWrongReview,
                    ),
                    const SizedBox(height: 18),
                    const LiquidSectionLabel(
                      title: '問題集',
                      subtitle: 'いまの目的に合わせて、練習モードを選びます。',
                    ),
                    const SizedBox(height: 12),
                    _StageEntryCard(
                      title: '仮免',
                      subtitle: '第一段階・仮免試験対策',
                      icon: Icons.traffic_rounded,
                      color: LiquidColors.primary,
                      progressText: hasAccount
                          ? 'お気に入り ${progress.favoritesForStage('karimen').length}問'
                          : '第1回はゲストでも利用できます',
                      onTap: () => context.push('/stage/karimen'),
                    ),
                    const SizedBox(height: 12),
                    _StageEntryCard(
                      title: '本免',
                      subtitle: '第二段階・卒業検定前対策',
                      icon: Icons.route_rounded,
                      color: LiquidColors.sky,
                      progressText: hasAccount
                          ? 'お気に入り ${progress.favoritesForStage('sotsuken').length}問'
                          : '第1回はゲストでも利用できます',
                      onTap: () => context.push('/stage/sotsuken'),
                    ),
                    const SizedBox(height: 18),
                    const LiquidSectionLabel(
                      title: '復習',
                      subtitle: '保存した問題と試験形式の記録をすぐ確認できます。',
                    ),
                    const SizedBox(height: 12),
                    _QuickActionGrid(
                      children: [
                        _QuickActionTile(
                          title: '仮免のお気に入り',
                          value: hasAccount
                              ? '${progress.favoritesForStage('karimen').length}問'
                              : '連携後',
                          icon: Icons.bookmark_outline_rounded,
                          color: LiquidColors.amber,
                          onTap: () => openFavorites('karimen'),
                        ),
                        _QuickActionTile(
                          title: '本免のお気に入り',
                          value: hasAccount
                              ? '${progress.favoritesForStage('sotsuken').length}問'
                              : '連携後',
                          icon: Icons.bookmarks_outlined,
                          color: LiquidColors.vermilion,
                          onTap: () => openFavorites('sotsuken'),
                        ),
                        _QuickActionTile(
                          title: '解答記録',
                          value: hasAccount
                              ? '${progress.records.length}件'
                              : '連携後',
                          icon: Icons.fact_check_outlined,
                          color: LiquidColors.sky,
                          onTap: () => context.push('/records'),
                        ),
                        _QuickActionTile(
                          title: '統計',
                          value: hasAccount
                              ? '${(progress.accuracy * 100).round()}%'
                              : '連携後',
                          icon: Icons.bar_chart_rounded,
                          color: LiquidColors.primary,
                          onTap: () => context.push('/stats'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.progress,
    required this.hasAccount,
    required this.onKarimenPractice,
    required this.onSotsukenPractice,
    required this.onWrongReview,
  });

  final ProgressStore progress;
  final bool hasAccount;
  final VoidCallback onKarimenPractice;
  final VoidCallback onSotsukenPractice;
  final VoidCallback onWrongReview;

  @override
  Widget build(BuildContext context) {
    final accuracy = (progress.accuracy * 100).round();

    return LiquidGlass(
      padding: const EdgeInsets.all(18),
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LiquidIconBadge(
                icon: Icons.school_outlined,
                color: LiquidColors.primary,
                size: 46,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日の練習',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasAccount
                          ? '正答率と苦手問題を見ながら、仮免から本免まで進めます。'
                          : 'アカウント連携で統計、記録、お気に入りを保存できます。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: LiquidColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 170,
                child: LiquidMetric(
                  label: '回答済み',
                  value: hasAccount
                      ? '${progress.answeredQuestionCount}問'
                      : 'ゲスト',
                  icon: Icons.done_all_rounded,
                  color: LiquidColors.primary,
                ),
              ),
              SizedBox(
                width: 170,
                child: LiquidMetric(
                  label: '正答率',
                  value: hasAccount ? '$accuracy%' : '--',
                  icon: Icons.speed_rounded,
                  color: LiquidColors.sky,
                ),
              ),
              SizedBox(
                width: 170,
                child: LiquidMetric(
                  label: '間違い',
                  value: hasAccount ? '${progress.wrongQuestionCount}問' : '--',
                  icon: Icons.error_outline_rounded,
                  color: LiquidColors.vermilion,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onKarimenPractice,
                icon: const Icon(Icons.traffic_rounded),
                label: const Text('仮免を練習'),
              ),
              FilledButton.icon(
                onPressed: onSotsukenPractice,
                icon: const Icon(Icons.route_rounded),
                label: const Text('本免を練習'),
              ),
              OutlinedButton.icon(
                onPressed: onWrongReview,
                icon: const Icon(Icons.replay_rounded),
                label: Text(
                  hasAccount
                      ? '間違えた問題を練習（${progress.wrongQuestionCount}問）'
                      : '間違えた問題を練習',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageEntryCard extends StatelessWidget {
  const _StageEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progressText,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String progressText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      enableBlur: false,
      child: Row(
        children: [
          LiquidIconBadge(icon: icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
                const SizedBox(height: 8),
                Text(
                  progressText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LiquidColors.muted(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final width = isWide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      enableBlur: false,
      child: Row(
        children: [
          LiquidIconBadge(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
