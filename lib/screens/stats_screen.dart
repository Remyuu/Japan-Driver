import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/liquid_glass.dart';
import '../models/progress_store.dart';
import '../models/question_bank.dart';
import '../navigation_transitions.dart';
import '../providers.dart';
import '../widgets/account_gate.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(accountUserProvider);
    final user = userAsync.value;
    final banksAsync = ref.watch(questionBankSummariesProvider);
    final progress = ref
        .watch(progressControllerProvider)
        .when(
          data: (store) => store,
          error: (error, stackTrace) => ProgressStore.empty(),
          loading: ProgressStore.empty,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('統計'),
        leading: IconButton(
          tooltip: '戻る',
          onPressed: () => context.popOrGoBack('/'),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ),
      body: LiquidBackground(
        child: userAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : user == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: AccountRequiredCard(
                      title: '統計にはアカウント連携が必要です',
                      message: '回答数、正答率、間違い復習、解答記録は連携したアカウントに保存されます。',
                      icon: Icons.bar_chart_rounded,
                    ),
                  ),
                ),
              )
            : banksAsync.when(
                data: (banks) =>
                    _StatsContent(banks: banks, progress: progress),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(child: Text('$error')),
              ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.banks, required this.progress});

  final List<QuestionBankSummary> banks;
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    final allIds = {
      for (final bank in banks)
        for (final questionId in bank.questionIds) questionId,
    };
    final accuracy = (progress.accuracy * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatsHero(
                  answered: progress.answeredQuestionCount,
                  total: allIds.length,
                  accuracy: accuracy,
                  wrong: progress.wrongQuestionCount,
                  attempts: progress.totalAttempts,
                ),
                const SizedBox(height: 18),
                _StatsActionRow(progress: progress),
                const SizedBox(height: 18),
                const LiquidSectionLabel(
                  title: '問題集ごとの進捗',
                  subtitle: '回答済み、間違い、完了率をまとめて確認できます。',
                ),
                const SizedBox(height: 12),
                for (final bank in banks) ...[
                  _BankProgress(bank: bank, progress: progress),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsHero extends StatelessWidget {
  const _StatsHero({
    required this.answered,
    required this.total,
    required this.accuracy,
    required this.wrong,
    required this.attempts,
  });

  final int answered;
  final int total;
  final int accuracy;
  final int wrong;
  final int attempts;

  @override
  Widget build(BuildContext context) {
    final completion = total == 0 ? 0.0 : answered / total;

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
                icon: Icons.bar_chart_rounded,
                color: LiquidColors.primary,
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$accuracy%',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      '現在の正答率',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: LiquidColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$answered/$total',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: completion,
              backgroundColor: LiquidColors.hairline(context),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 170,
                child: LiquidMetric(
                  label: '回答数',
                  value: '$attempts',
                  icon: Icons.touch_app_outlined,
                  color: LiquidColors.sky,
                ),
              ),
              SizedBox(
                width: 170,
                child: LiquidMetric(
                  label: '間違い',
                  value: '$wrong',
                  icon: Icons.error_outline_rounded,
                  color: LiquidColors.vermilion,
                ),
              ),
              SizedBox(
                width: 170,
                child: LiquidMetric(
                  label: '回答済み',
                  value: '$answered問',
                  icon: Icons.done_all_rounded,
                  color: LiquidColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsActionRow extends StatelessWidget {
  const _StatsActionRow({required this.progress});

  final ProgressStore progress;

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
            SizedBox(
              width: width,
              child: _StatsActionTile(
                title: '間違い復習',
                value: '${progress.wrongQuestionCount}問',
                icon: Icons.replay_rounded,
                color: LiquidColors.vermilion,
                onTap: () => context.push('/review/wrong'),
              ),
            ),
            SizedBox(
              width: width,
              child: _StatsActionTile(
                title: '解答記録',
                value: '${progress.records.length}件',
                icon: Icons.fact_check_outlined,
                color: LiquidColors.sky,
                onTap: () => context.push('/records'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatsActionTile extends StatelessWidget {
  const _StatsActionTile({
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
      padding: const EdgeInsets.all(16),
      enableBlur: false,
      child: Row(
        children: [
          LiquidIconBadge(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
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

class _BankProgress extends StatelessWidget {
  const _BankProgress({required this.bank, required this.progress});

  final QuestionBankSummary bank;
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    final ids = bank.questionIds.toSet();
    final answered = ids
        .where((id) => progress.byQuestion.containsKey(id))
        .length;
    final wrong = ids.where(progress.isWrong).length;
    final value = ids.isEmpty ? 0.0 : answered / ids.length;

    return LiquidGlass(
      padding: const EdgeInsets.all(16),
      enableBlur: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LiquidIconBadge(
                icon: Icons.menu_book_outlined,
                color: value >= 0.8
                    ? LiquidColors.success
                    : LiquidColors.primary,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bank.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: LiquidColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$answered/${ids.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: LiquidColors.hairline(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '間違い $wrong',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: wrong == 0
                  ? LiquidColors.muted(context)
                  : LiquidColors.vermilion,
            ),
          ),
        ],
      ),
    );
  }
}
