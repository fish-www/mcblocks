import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'blocks_providers.dart';
import 'widgets/block_detail_panel.dart';

/// 窄屏的详情页，从列表推入。
class BlockDetailPage extends ConsumerWidget {
  const BlockDetailPage({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(blockDetailProvider(code)).asData?.value;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/blocks'),
        ),
        title: Text(title?.displayName ?? code),
      ),
      // push 而不是 go：从变体跳转后要能返回上一页。
      body: BlockDetailPanel(
        code: code,
        onSelect: (next) => context.push('/blocks/$next'),
      ),
    );
  }
}
