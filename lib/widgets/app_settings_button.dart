import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/liquid_glass.dart';
import '../models/app_settings.dart';
import '../providers.dart';

class AppSettingsButton extends ConsumerWidget {
  const AppSettingsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: '設定',
      onPressed: () => showAppSettingsDialog(context),
      icon: const Icon(Icons.settings_outlined),
    );
  }
}

void showAppSettingsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (context) {
      return Consumer(
        builder: (context, ref, child) {
          final settings =
              ref.watch(settingsControllerProvider).value ??
              AppSettings.defaults();
          final controller = ref.read(settingsControllerProvider.notifier);

          return LiquidDialogPanel(
            maxWidth: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const LiquidIconBadge(
                      icon: Icons.tune_rounded,
                      color: LiquidColors.primary,
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '設定',
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
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('明るい'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('暗い'),
                    ),
                  ],
                  selected: {settings.darkMode},
                  onSelectionChanged: (values) {
                    controller.setDarkMode(values.single);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('自動で次の問題へ'),
                  value: settings.autoAdvance,
                  onChanged: controller.setAutoAdvance,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ふりがなを表示'),
                  value: settings.showRuby,
                  onChanged: controller.setShowRuby,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('显示中文翻译'),
                  value: settings.showChinese,
                  onChanged: controller.setShowChinese,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show English translation'),
                  value: settings.showEnglish,
                  onChanged: controller.setShowEnglish,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hiển thị bản dịch tiếng Việt'),
                  value: settings.showVietnamese,
                  onChanged: controller.setShowVietnamese,
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
