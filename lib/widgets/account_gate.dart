import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/liquid_glass.dart';
import '../providers.dart';

class AccountButton extends ConsumerWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(accountUserProvider);
    final user = userAsync.value;

    return IconButton(
      tooltip: user == null ? 'Googleで連携' : user.label,
      onPressed: () => showAccountDialog(context, ref),
      icon: user?.photoUrl == null
          ? const Icon(Icons.account_circle_outlined)
          : CircleAvatar(
              radius: 13,
              backgroundImage: NetworkImage(user!.photoUrl!),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
    );
  }
}

class AccountRequiredCard extends ConsumerWidget {
  const AccountRequiredCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.lock_outline_rounded,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(accountRepositoryProvider);
    final userAsync = ref.watch(accountUserProvider);

    return LiquidGlass(
      padding: const EdgeInsets.all(20),
      strong: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LiquidIconBadge(icon: icon, color: LiquidColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: LiquidColors.muted(context),
            ),
          ),
          const SizedBox(height: 16),
          if (!repository.isConfigured)
            const Text('Googleログインの設定が必要です。')
          else if (userAsync.isLoading)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            FilledButton.icon(
              onPressed: () => _signIn(context, ref),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Googleで連携'),
            ),
        ],
      ),
    );
  }
}

Future<void> showAccountDialog(BuildContext context, WidgetRef ref) {
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
            final signedIn = await _signIn(context, ref);
            if (context.mounted && signedIn) {
              Navigator.of(context).pop();
            }
          }

          Future<void> signOut() async {
            await repository.signOut();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }

          return LiquidDialogPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'アカウント連携',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
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
                  Text(
                    'Googleログインの設定が必要です。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: LiquidColors.muted(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (userAsync.isLoading) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 12),
                ] else if (user == null) ...[
                  Text(
                    '統計・解答記録・コメント・お気に入りは連携後に利用できます。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: LiquidColors.muted(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: signIn,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Googleで連携'),
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
                              style: Theme.of(context).textTheme.titleSmall,
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
          );
        },
      );
    },
  );
}

Future<bool> _signIn(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(accountRepositoryProvider).signInWithGoogle();
    return true;
  } catch (error) {
    if (!context.mounted) {
      return false;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
    return false;
  }
}
