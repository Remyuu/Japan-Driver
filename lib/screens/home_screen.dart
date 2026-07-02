import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/progress_store.dart';
import '../providers.dart';
import '../widgets/account_gate.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Japan Driver'),
        actions: [
          IconButton(
            tooltip: '統計',
            onPressed: () => context.push('/stats'),
            icon: const Icon(Icons.bar_chart_rounded),
          ),
          const AccountButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '問題集',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 18),
                  _StageEntryCard(
                    title: '仮免',
                    subtitle: '第一段階・仮免試験対策',
                    onTap: () => context.push('/stage/karimen'),
                  ),
                  const SizedBox(height: 12),
                  _StageEntryCard(
                    title: '本免',
                    subtitle: '第二段階・卒業検定前対策',
                    onTap: () => context.push('/stage/sotsuken'),
                  ),
                  const SizedBox(height: 20),
                  Text('お気に入り', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Card(
                    child: Column(
                      children: [
                        _FavoriteEntry(
                          title: '仮免',
                          count: hasAccount
                              ? progress.favoritesForStage('karimen').length
                              : null,
                          onTap: () => openFavorites('karimen'),
                        ),
                        const Divider(height: 1, color: Color(0xFFE3E1DC)),
                        _FavoriteEntry(
                          title: '本免',
                          count: hasAccount
                              ? progress.favoritesForStage('sotsuken').length
                              : null,
                          onTap: () => openFavorites('sotsuken'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _StageEntryCard(
                    title: '解答記録',
                    subtitle: '保存した解答カード',
                    onTap: () => context.push('/records'),
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

class _FavoriteEntry extends StatelessWidget {
  const _FavoriteEntry({
    required this.title,
    required this.count,
    required this.onTap,
  });

  final String title;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.bookmark_outline_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(count == null ? 'アカウント連携後に利用できます' : '$count問'),
                ],
              ),
            ),
            Icon(
              count == null
                  ? Icons.lock_outline_rounded
                  : Icons.chevron_right_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _StageEntryCard extends StatelessWidget {
  const _StageEntryCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(subtitle),
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
