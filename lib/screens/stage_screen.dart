import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/practice_draft.dart';
import '../models/progress_store.dart';
import '../models/question_bank.dart';
import '../navigation_transitions.dart';
import '../providers.dart';

class StageScreen extends ConsumerWidget {
  const StageScreen({super.key, required this.stageId, this.sectionId});

  final String stageId;
  final String? sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = _StageConfig.byId(stageId);
    if (config == null) {
      return const _MissingStage();
    }
    final section = sectionId == null ? null : _StageSection.byId(sectionId!);
    if (sectionId != null && section == null) {
      return const _MissingStage();
    }

    if (section == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(config.title),
          leading: IconButton(
            tooltip: '戻る',
            onPressed: () => context.popOrGoBack('/'),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ),
        body: _StageMenuContent(config: config),
      );
    }

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
        title: Text(config.title),
        leading: IconButton(
          tooltip: '戻る',
          onPressed: () => context.popOrGoBack('/stage/${config.id}'),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ),
      body: banksAsync.when(
        data: (banks) => _StageDetailContent(
          config: config,
          section: section,
          banks: banks,
          progress: progress,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
    );
  }
}

class _StageMenuContent extends StatelessWidget {
  const _StageMenuContent({required this.config});

  final _StageConfig config;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(config.subtitle),
                const SizedBox(height: 18),
                Card(
                  child: Column(
                    children: [
                      for (
                        var i = 0;
                        i < _StageSection.values.length;
                        i += 1
                      ) ...[
                        _StageSectionOption(
                          section: _StageSection.values[i],
                          onTap: () => context.push(
                            '/stage/${config.id}/${_StageSection.values[i].id}',
                          ),
                        ),
                        if (i != _StageSection.values.length - 1)
                          const Divider(height: 1, color: Color(0xFFE3E1DC)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StageDetailContent extends StatelessWidget {
  const _StageDetailContent({
    required this.config,
    required this.section,
    required this.banks,
    required this.progress,
  });

  final _StageConfig config;
  final _StageSection section;
  final List<QuestionBank> banks;
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config.subtitle),
                const SizedBox(height: 18),
                _ModeSection(title: section.title, children: _options(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  QuestionBank _bank(String id) => banks.firstWhere((bank) => bank.id == id);

  List<Widget> _options(BuildContext context) {
    return switch (section) {
      _StageSection.oneToOne => _workbookOptions(
        context,
        bank: _bank(config.oneToOneBankId),
        feedbackMode: 'instant',
      ),
      _StageSection.exam => _workbookOptions(
        context,
        bank: _bank(config.examBankId),
        feedbackMode: 'exam',
      ),
      _StageSection.curriculum => _chapterOptions(context),
      _StageSection.difficult => _difficultOptions(context),
    };
  }

  List<Widget> _workbookOptions(
    BuildContext context, {
    required QuestionBank bank,
    required String feedbackMode,
  }) {
    final numbers = {
      for (final question in bank.questions)
        if (question.workbookDisplayNo != null) question.workbookDisplayNo!,
    }.toList()..sort();

    return [
      for (final number in numbers)
        _PracticeOption(
          label: '第$number回',
          meta: _summary(
            bank.questions.where(
              (question) => question.workbookDisplayNo == number,
            ),
          ),
          draft:
              progress.drafts[practiceSessionId(
                bankId: bank.id,
                mode: feedbackMode,
                workbookNumber: number,
              )],
          onTap: () => context.push(
            '/practice/${bank.id}?workbook=$number&mode=$feedbackMode&stage=${config.id}&section=${section.id}',
          ),
        ),
    ];
  }

  List<Widget> _chapterOptions(BuildContext context) {
    final curriculum = _bank(config.curriculumBankId);
    return [
      for (final chapter in curriculum.chapters)
        _PracticeOption(
          label: '${chapter.number}. ${chapter.name}',
          meta: _summary(
            curriculum.questions.where(
              (question) => question.chapterNumbers.contains(chapter.number),
            ),
          ),
          draft:
              progress.drafts[practiceSessionId(
                bankId: curriculum.id,
                mode: 'instant',
                chapterNumber: chapter.number,
              )],
          onTap: () => context.push(
            '/practice/${curriculum.id}?chapter=${chapter.number}&mode=instant&stage=${config.id}&section=${section.id}',
          ),
        ),
    ];
  }

  List<Widget> _difficultOptions(BuildContext context) {
    final difficult = _bank('difficult');
    return [
      _PracticeOption(
        label: config.difficultLabel,
        meta: _summary(
          difficult.questions.where(
            (question) => question.rangeStep == config.rangeStep,
          ),
        ),
        draft:
            progress.drafts[practiceSessionId(
              bankId: difficult.id,
              mode: 'instant',
              rangeStep: config.rangeStep,
            )],
        onTap: () => context.push(
          '/practice/${difficult.id}?rangeStep=${config.rangeStep}&mode=instant&stage=${config.id}&section=${section.id}',
        ),
      ),
    ];
  }

  String _summary(Iterable<DriverQuestion> questions) {
    final ids = questions.map((question) => question.canonicalId).toSet();
    final answered = ids
        .where((id) => progress.byQuestion.containsKey(id))
        .length;
    final wrong = ids.where(progress.isWrong).length;
    return '${ids.length}問 / 回答済み $answered / 間違い $wrong';
  }
}

enum _StageSection {
  oneToOne(id: 'one-to-one', title: '一問一答', subtitle: '選ぶとすぐに答え合わせ'),
  exam(id: 'exam', title: '試験形式', subtitle: '30分でまとめて答える'),
  curriculum(id: 'curriculum', title: '項目別問題', subtitle: '章ごとに練習'),
  difficult(id: 'difficult', title: 'みんな苦手問題', subtitle: '間違えやすい問題');

  const _StageSection({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;

  static _StageSection? byId(String id) {
    for (final section in values) {
      if (section.id == id) {
        return section;
      }
    }
    return null;
  }
}

class _StageSectionOption extends StatelessWidget {
  const _StageSectionOption({required this.section, required this.onTap});

  final _StageSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(section.subtitle),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _ModeSection extends StatelessWidget {
  const _ModeSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < children.length; i += 1) ...[
                  children[i],
                  if (i != children.length - 1)
                    const Divider(height: 1, color: Color(0xFFE3E1DC)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeOption extends StatelessWidget {
  const _PracticeOption({
    required this.label,
    required this.meta,
    required this.onTap,
    this.draft,
  });

  final String label;
  final String meta;
  final VoidCallback onTap;
  final PracticeDraft? draft;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    draft == null
                        ? meta
                        : '$meta / 続きから 問${draft!.currentIndex + 1}',
                  ),
                ],
              ),
            ),
            if (draft != null) ...[
              const SizedBox(width: 8),
              const _ContinueBadge(),
            ],
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _ContinueBadge extends StatelessWidget {
  const _ContinueBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2F6F73)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text('続き'),
      ),
    );
  }
}

class _StageConfig {
  const _StageConfig({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.oneToOneBankId,
    required this.examBankId,
    required this.curriculumBankId,
    required this.rangeStep,
    required this.difficultLabel,
  });

  final String id;
  final String title;
  final String subtitle;
  final String oneToOneBankId;
  final String examBankId;
  final String curriculumBankId;
  final int rangeStep;
  final String difficultLabel;

  static _StageConfig? byId(String id) {
    return switch (id) {
      'karimen' => const _StageConfig(
        id: 'karimen',
        title: '仮免前',
        subtitle: '第一段階・仮免試験対策',
        oneToOneBankId: 'karimen_1to1',
        examBankId: 'karimen_test',
        curriculumBankId: 'curriculum_stage1',
        rangeStep: 1,
        difficultLabel: '第一段階',
      ),
      'sotsuken' => const _StageConfig(
        id: 'sotsuken',
        title: '卒検前',
        subtitle: '第二段階・卒業検定前対策',
        oneToOneBankId: 'sotsuken_1to1',
        examBankId: 'sotsuken_test',
        curriculumBankId: 'curriculum_stage2',
        rangeStep: 2,
        difficultLabel: '第二段階',
      ),
      _ => null,
    };
  }
}

class _MissingStage extends StatelessWidget {
  const _MissingStage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Japan Driver')),
      body: const Center(child: Text('問題集が見つかりません')),
    );
  }
}
