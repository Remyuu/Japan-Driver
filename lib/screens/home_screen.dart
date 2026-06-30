import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Japan Driver'),
        actions: [
          IconButton(
            tooltip: '統計',
            onPressed: () => context.push('/stats'),
            icon: const Icon(Icons.bar_chart_rounded),
          ),
          const _AccountButton(),
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
                    title: '仮免前',
                    subtitle: '第一段階・仮免試験対策',
                    onTap: () => context.push('/stage/karimen'),
                  ),
                  const SizedBox(height: 12),
                  _StageEntryCard(
                    title: '卒検前',
                    subtitle: '第二段階・卒業検定前対策',
                    onTap: () => context.push('/stage/sotsuken'),
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

class _AccountButton extends ConsumerWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(accountUserProvider);
    final user = userAsync.value;

    return IconButton(
      tooltip: user == null ? 'Googleでログイン' : user.label,
      onPressed: () => _showAccountDialog(context, ref),
      icon: user?.photoUrl == null
          ? const Icon(Icons.account_circle_outlined)
          : CircleAvatar(
              radius: 13,
              backgroundImage: NetworkImage(user!.photoUrl!),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
    );
  }

  Future<void> _showAccountDialog(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final repository = ref.read(accountRepositoryProvider);
            final userAsync = ref.watch(accountUserProvider);
            final user = userAsync.value;

            Future<void> signIn() async {
              try {
                await repository.signInWithGoogle();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } catch (error) {
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error.toString())));
              }
            }

            Future<void> signOut() async {
              await repository.signOut();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }

            return Dialog(
              alignment: Alignment.topRight,
              insetPadding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'アカウント',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: '閉じる',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!repository.isConfigured) ...[
                        const Text('Googleログインの設定が必要です。'),
                        const SizedBox(height: 12),
                      ] else if (userAsync.isLoading) ...[
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 12),
                      ] else if (user == null) ...[
                        FilledButton.icon(
                          onPressed: signIn,
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Googleでログイン'),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: user.photoUrl == null
                                  ? null
                                  : NetworkImage(user.photoUrl!),
                              child: user.photoUrl == null
                                  ? const Icon(Icons.person_outline_rounded)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  if (user.email != null)
                                    Text(
                                      user.email!,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: signOut,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('ログアウト'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
