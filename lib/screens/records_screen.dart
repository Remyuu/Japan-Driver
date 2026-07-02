import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/practice_record.dart';
import '../models/app_settings.dart';
import '../models/progress_store.dart';
import '../models/question_bank.dart';
import '../models/question_translation.dart';
import '../models/translation_language.dart';
import '../navigation_transitions.dart';
import '../providers.dart';
import '../translation_messages.dart';
import '../widgets/account_gate.dart';
import '../widgets/ruby_text.dart';

class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(accountUserProvider);
    final user = userAsync.value;
    final progress = ref
        .watch(progressControllerProvider)
        .when(
          data: (store) => store,
          error: (error, stackTrace) => ProgressStore.empty(),
          loading: ProgressStore.empty,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('解答記録'),
        leading: IconButton(
          tooltip: '戻る',
          onPressed: () => context.popOrGoBack('/'),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ),
      body: userAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AccountRequiredCard(
                    title: '解答記録にはアカウント連携が必要です',
                    message: '試験形式の解答カードは連携したアカウントに保存されます。',
                    icon: Icons.fact_check_outlined,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: progress.records.isEmpty
                        ? const _EmptyRecords()
                        : Column(
                            children: [
                              for (final record in progress.records) ...[
                                _RecordCard(record: record),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(accountUserProvider);
    final user = userAsync.value;
    final progress = ref
        .watch(progressControllerProvider)
        .when(
          data: (store) => store,
          error: (error, stackTrace) => ProgressStore.empty(),
          loading: ProgressStore.empty,
        );
    final record = progress.records
        .where((record) => record.id == recordId)
        .firstOrNull;
    final banksAsync = ref.watch(questionBanksProvider);
    final settings =
        ref.watch(settingsControllerProvider).value ?? AppSettings.defaults();

    return Scaffold(
      appBar: AppBar(
        title: const Text('解答カード'),
        leading: IconButton(
          tooltip: '戻る',
          onPressed: () => context.popOrGoBack('/records'),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ),
      body: userAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AccountRequiredCard(
                    title: '解答記録にはアカウント連携が必要です',
                    message: '解答カードを見るには先にアカウントを連携してください。',
                    icon: Icons.fact_check_outlined,
                  ),
                ),
              ),
            )
          : record == null
          ? const Center(child: Text('記録が見つかりません'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RecordSummary(record: record),
                        const SizedBox(height: 12),
                        _SavedAnswerSheet(record: record),
                        const SizedBox(height: 12),
                        banksAsync.when(
                          data: (banks) => _RecordQuestionList(
                            record: record,
                            banks: banks,
                            showRuby: settings.showRuby,
                            translationLanguages:
                                settings.enabledTranslationLanguages,
                          ),
                          loading: () => const Card(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ),
                          error: (error, stackTrace) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text('$error'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final PracticeRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/records/${Uri.encodeComponent(record.id)}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.subtitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(_formatDate(record.completedAt)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SmallPill(
                          label: record.mode == 'exam' ? '試験形式' : '練習',
                        ),
                        _SmallPill(
                          label:
                              '${record.correctCount} / ${record.totalCount}',
                        ),
                        _SmallPill(label: '間違い ${record.wrongCount}'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordSummary extends StatelessWidget {
  const _RecordSummary({required this.record});

  final PracticeRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.subtitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_formatDate(record.completedAt)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SmallPill(label: record.mode == 'exam' ? '試験形式' : '練習'),
                _SmallPill(label: '正解 ${record.correctCount}'),
                _SmallPill(label: '不正解 ${record.wrongCount}'),
                _SmallPill(label: '全${record.totalCount}問'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedAnswerSheet extends StatelessWidget {
  const _SavedAnswerSheet({required this.record});

  final PracticeRecord record;

  @override
  Widget build(BuildContext context) {
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
                    '解答カード',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${record.correctCount} / ${record.totalCount}'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < record.answers.length; i += 1)
                  _SavedAnswerCell(number: i + 1, answer: record.answers[i]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedAnswerCell extends StatelessWidget {
  const _SavedAnswerCell({required this.number, required this.answer});

  final int number;
  final PracticeRecordAnswer answer;

  @override
  Widget build(BuildContext context) {
    final isCorrect = answer.isCorrect;
    final color = isCorrect ? const Color(0xFF1D7F48) : const Color(0xFFB73A36);
    final background = isCorrect
        ? const Color(0xFFEAF6EE)
        : const Color(0xFFFBEDEC);

    return Tooltip(
      message:
          '問$number あなた：${answer.selectedAnswer.label} / 答え：${answer.correctAnswer.label}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: color, width: 1.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordQuestionList extends StatelessWidget {
  const _RecordQuestionList({
    required this.record,
    required this.banks,
    required this.showRuby,
    required this.translationLanguages,
  });

  final PracticeRecord record;
  final List<QuestionBank> banks;
  final bool showRuby;
  final List<TranslationLanguage> translationLanguages;

  @override
  Widget build(BuildContext context) {
    final questionsById = _questionsByCanonicalId(record, banks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('問題', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        for (var i = 0; i < record.answers.length; i += 1) ...[
          _RecordQuestionCard(
            number: i + 1,
            answer: record.answers[i],
            question: questionsById[record.answers[i].questionId],
            showRuby: showRuby,
            translationLanguages: translationLanguages,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Map<String, DriverQuestion> _questionsByCanonicalId(
    PracticeRecord record,
    List<QuestionBank> banks,
  ) {
    final preferredBankId = record.sessionId.split('|').first;
    final orderedBanks = [
      for (final bank in banks)
        if (bank.id == preferredBankId) bank,
      for (final bank in banks)
        if (bank.id != preferredBankId) bank,
    ];
    final result = <String, DriverQuestion>{};
    for (final bank in orderedBanks) {
      for (final question in bank.questions) {
        result.putIfAbsent(question.canonicalId, () => question);
      }
    }
    return result;
  }
}

class _RecordQuestionCard extends ConsumerWidget {
  const _RecordQuestionCard({
    required this.number,
    required this.answer,
    required this.question,
    required this.showRuby,
    required this.translationLanguages,
  });

  final int number;
  final PracticeRecordAnswer answer;
  final DriverQuestion? question;
  final bool showRuby;
  final List<TranslationLanguage> translationLanguages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCorrect = answer.isCorrect;
    final color = isCorrect ? const Color(0xFF1D7F48) : const Color(0xFFB73A36);
    final question = this.question;
    final translations =
        <TranslationLanguage, AsyncValue<QuestionTranslation?>>{};
    if (question != null) {
      for (final language in translationLanguages) {
        translations[language] = ref.watch(
          questionTranslationProvider((
            question: question,
            language: language,
            generateIfMissing: true,
          )),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '問$number',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (question == null)
              Text('問題文を読み込めませんでした（${answer.questionId}）')
            else ...[
              RubyText(
                text: question.questionText,
                rubyHtml: question.questionRubyHtml,
                showRuby: showRuby,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              for (final entry in translations.entries) ...[
                const SizedBox(height: 8),
                _RecordTranslation(
                  language: entry.key,
                  text: entry.value.value?.question,
                  isLoading: entry.value.isLoading,
                  error: entry.value.error,
                ),
              ],
              if (question.questionImageAssetPaths.isNotEmpty) ...[
                const SizedBox(height: 12),
                _RecordImageList(paths: question.questionImageAssetPaths),
              ],
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SmallPill(label: 'あなたの答え ${answer.selectedAnswer.label}'),
                _SmallPill(label: '正解 ${answer.correctAnswer.label}'),
              ],
            ),
            if (question != null && question.explanation.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('解説', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              RubyText(
                text: question.explanation,
                rubyHtml: question.explanationRubyHtml,
                showRuby: showRuby,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              for (final entry in translations.entries) ...[
                const SizedBox(height: 8),
                _RecordTranslation(
                  language: entry.key,
                  text: entry.value.value?.explanation,
                  isLoading: entry.value.isLoading,
                  error: entry.value.error,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordTranslation extends StatelessWidget {
  const _RecordTranslation({
    required this.language,
    required this.text,
    required this.isLoading,
    required this.error,
  });

  final TranslationLanguage language;
  final String? text;
  final bool isLoading;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            language.displayLabel,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (text != null)
            Text(text!)
          else if (isLoading)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 6),
                Text(language.loadingMessage),
              ],
            )
          else
            Text(translationFailureMessage(language, error)),
        ],
      ),
    );
  }
}

class _RecordImageList extends StatelessWidget {
  const _RecordImageList({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final path in paths) ...[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE3E1DC)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    path,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(path),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE3E1DC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label),
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('まだ記録がありません', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('一通り答えると、ここに解答カードが保存されます。'),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}/$month/$day $hour:$minute';
}
