import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/progress_store.dart';
import '../models/question_bank.dart';
import '../navigation_transitions.dart';
import '../providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banksAsync = ref.watch(questionBanksProvider);
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
      body: banksAsync.when(
        data: (banks) => _StatsContent(banks: banks, progress: progress),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.banks, required this.progress});

  final List<QuestionBank> banks;
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    final allIds = {
      for (final bank in banks)
        for (final question in bank.questions) question.canonicalId,
    };
    final accuracy = (progress.accuracy * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatBox(
                      label: '回答済み',
                      value:
                          '${progress.answeredQuestionCount}/${allIds.length}',
                    ),
                    _StatBox(label: '正答率', value: '$accuracy%'),
                    _StatBox(
                      label: '間違い',
                      value: '${progress.wrongQuestionCount}',
                    ),
                    _StatBox(label: '回答数', value: '${progress.totalAttempts}'),
                  ],
                ),
                const SizedBox(height: 20),
                Text('問題集', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final bank in banks) ...[
                  _BankProgress(bank: bank, progress: progress),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BankProgress extends StatelessWidget {
  const _BankProgress({required this.bank, required this.progress});

  final QuestionBank bank;
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    final ids = bank.questions.map((question) => question.canonicalId).toSet();
    final answered = ids
        .where((id) => progress.byQuestion.containsKey(id))
        .length;
    final wrong = ids.where(progress.isWrong).length;
    final value = ids.isEmpty ? 0.0 : answered / ids.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${bank.title} / ${bank.subtitle}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('$answered/${ids.length}'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: value),
            const SizedBox(height: 8),
            Text('間違い $wrong'),
          ],
        ),
      ),
    );
  }
}
