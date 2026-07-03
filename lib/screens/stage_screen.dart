import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../account_access.dart';
import '../design/liquid_glass.dart';
import '../models/practice_draft.dart';
import '../models/progress_store.dart';
import '../models/question_bank.dart';
import '../navigation_transitions.dart';
import '../providers.dart';
import '../widgets/account_gate.dart';

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
        body: LiquidBackground(child: _StageMenuContent(config: config)),
      );
    }

    final banksAsync = ref.watch(questionBanksProvider);
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
        title: Text(config.title),
        leading: IconButton(
          tooltip: '戻る',
          onPressed: () => context.popOrGoBack('/stage/${config.id}'),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ),
      body: LiquidBackground(
        child: banksAsync.when(
          data: (banks) => _StageDetailContent(
            config: config,
            section: section,
            banks: banks,
            progress: progress,
            canTrackProgress: user != null && !userAsync.isLoading,
            onAccountRequired: () => showAccountDialog(context, ref),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('$error')),
        ),
      ),
    );
  }
}

class _StageMenuContent extends ConsumerWidget {
  const _StageMenuContent({required this.config});

  final _StageConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(accountUserProvider);
    final hasAccount = userAsync.value != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StageHeader(config: config),
                const SizedBox(height: 18),
                const LiquidSectionLabel(
                  title: '練習モード',
                  subtitle: '一問一答、試験形式、項目別、苦手問題から選びます。',
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;
                    final width = isWide
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final section in _StageSection.values)
                          SizedBox(
                            width: width,
                            child: _StageSectionOption(
                              section: section,
                              isLocked:
                                  !hasAccount &&
                                  section != _StageSection.oneToOne,
                              onTap: () {
                                if (!hasAccount &&
                                    section != _StageSection.oneToOne) {
                                  showAccountDialog(context, ref);
                                  return;
                                }
                                context.push(
                                  '/stage/${config.id}/${section.id}',
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.config, this.section});

  final _StageConfig config;
  final _StageSection? section;

  @override
  Widget build(BuildContext context) {
    final isKarimen = config.id == 'karimen';
    final color = isKarimen ? LiquidColors.primary : LiquidColors.sky;

    return LiquidGlass(
      padding: const EdgeInsets.all(18),
      strong: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiquidIconBadge(
            icon: isKarimen ? Icons.traffic_rounded : Icons.route_rounded,
            color: color,
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  config.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: LiquidColors.muted(context),
                  ),
                ),
                if (section != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StageMiniChip(
                        icon: section!.icon,
                        label: section!.title,
                        color: color,
                      ),
                      _StageMiniChip(
                        icon: Icons.fact_check_outlined,
                        label: section!.subtitle,
                        color: LiquidColors.amber,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageMiniChip extends StatelessWidget {
  const _StageMiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: LiquidColors.isDark(context) ? 0.22 : 0.12,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageDetailContent extends StatelessWidget {
  const _StageDetailContent({
    required this.config,
    required this.section,
    required this.banks,
    required this.progress,
    required this.canTrackProgress,
    required this.onAccountRequired,
  });

  final _StageConfig config;
  final _StageSection section;
  final List<QuestionBank> banks;
  final ProgressStore progress;
  final bool canTrackProgress;
  final VoidCallback onAccountRequired;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StageHeader(config: config, section: section),
                const SizedBox(height: 18),
                _ModeSection(
                  title: section.title,
                  subtitle: section.subtitle,
                  children: _options(context),
                ),
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
          draft: canTrackProgress
              ? progress.drafts[practiceSessionId(
                  bankId: bank.id,
                  mode: feedbackMode,
                  workbookNumber: number,
                )]
              : null,
          isLocked:
              !canTrackProgress &&
              !canGuestStartPractice(
                bankId: bank.id,
                isInstantFeedback: feedbackMode == 'instant',
                workbookNumber: number,
                chapterNumber: null,
                rangeStep: null,
              ),
          onTap:
              !canTrackProgress &&
                  !canGuestStartPractice(
                    bankId: bank.id,
                    isInstantFeedback: feedbackMode == 'instant',
                    workbookNumber: number,
                    chapterNumber: null,
                    rangeStep: null,
                  )
              ? onAccountRequired
              : () => context.push(
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
          draft: canTrackProgress
              ? progress.drafts[practiceSessionId(
                  bankId: curriculum.id,
                  mode: 'instant',
                  chapterNumber: chapter.number,
                )]
              : null,
          isLocked: !canTrackProgress,
          onTap: canTrackProgress
              ? () => context.push(
                  '/practice/${curriculum.id}?chapter=${chapter.number}&mode=instant&stage=${config.id}&section=${section.id}',
                )
              : onAccountRequired,
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
        draft: canTrackProgress
            ? progress.drafts[practiceSessionId(
                bankId: difficult.id,
                mode: 'instant',
                rangeStep: config.rangeStep,
              )]
            : null,
        isLocked: !canTrackProgress,
        onTap: canTrackProgress
            ? () => context.push(
                '/practice/${difficult.id}?rangeStep=${config.rangeStep}&mode=instant&stage=${config.id}&section=${section.id}',
              )
            : onAccountRequired,
      ),
    ];
  }

  String _summary(Iterable<DriverQuestion> questions) {
    final ids = questions.map((question) => question.canonicalId).toSet();
    if (!canTrackProgress) {
      return '${ids.length}問 / 進捗保存はアカウント連携後';
    }
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

  IconData get icon {
    return switch (this) {
      _StageSection.oneToOne => Icons.bolt_outlined,
      _StageSection.exam => Icons.timer_outlined,
      _StageSection.curriculum => Icons.view_list_outlined,
      _StageSection.difficult => Icons.psychology_alt_outlined,
    };
  }

  Color get color {
    return switch (this) {
      _StageSection.oneToOne => LiquidColors.primary,
      _StageSection.exam => LiquidColors.vermilion,
      _StageSection.curriculum => LiquidColors.sky,
      _StageSection.difficult => LiquidColors.amber,
    };
  }

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
  const _StageSectionOption({
    required this.section,
    required this.onTap,
    required this.isLocked,
  });

  final _StageSection section;
  final VoidCallback onTap;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          LiquidIconBadge(icon: section.icon, color: section.color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  section.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: LiquidColors.muted(context),
                  ),
                ),
                if (isLocked) ...[
                  const SizedBox(height: 8),
                  Text(
                    'アカウント連携後に利用できます',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: LiquidColors.vermilion,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            isLocked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
          ),
        ],
      ),
    );
  }
}

class _ModeSection extends StatelessWidget {
  const _ModeSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiquidSectionLabel(title: title, subtitle: subtitle),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 780;
            final width = isWide
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final child in children)
                  SizedBox(width: width, child: child),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PracticeOption extends StatelessWidget {
  const _PracticeOption({
    required this.label,
    required this.meta,
    required this.onTap,
    this.isLocked = false,
    this.draft,
  });

  final String label;
  final String meta;
  final VoidCallback onTap;
  final PracticeDraft? draft;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final lockedMeta = meta.replaceAll(' / 進捗保存はアカウント連携後', '');
    final metaText = isLocked
        ? '$lockedMeta / アカウント連携後に利用できます'
        : draft == null
        ? meta
        : '$meta / 続きから 問${draft!.currentIndex + 1}';
    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          LiquidIconBadge(
            icon: isLocked
                ? Icons.lock_outline_rounded
                : draft == null
                ? Icons.play_circle_outline_rounded
                : Icons.history_rounded,
            color: isLocked
                ? LiquidColors.vermilion
                : draft == null
                ? LiquidColors.primary
                : LiquidColors.amber,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  metaText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LiquidColors.muted(context),
                  ),
                ),
              ],
            ),
          ),
          if (draft != null) ...[
            const SizedBox(width: 8),
            const _ContinueBadge(),
          ],
          const SizedBox(width: 6),
          Icon(
            isLocked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
          ),
        ],
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
        color: LiquidColors.amber.withValues(
          alpha: LiquidColors.isDark(context) ? 0.22 : 0.14,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LiquidColors.amber.withValues(alpha: 0.30)),
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
        title: '仮免',
        subtitle: '第一段階・仮免試験対策',
        oneToOneBankId: 'karimen_1to1',
        examBankId: 'karimen_test',
        curriculumBankId: 'curriculum_stage1',
        rangeStep: 1,
        difficultLabel: '第一段階',
      ),
      'sotsuken' => const _StageConfig(
        id: 'sotsuken',
        title: '本免',
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
