import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Japan Driver'),
        actions: [
          IconButton(
            tooltip: '統計',
            onPressed: () => context.push('/stats'),
            icon: const Icon(Icons.bar_chart_rounded),
          ),
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
