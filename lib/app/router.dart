import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/blocks/ui/block_detail_page.dart';
import '../features/blocks/ui/blocks_page.dart';
import '../features/import/ui/import_page.dart';
import '../features/vocab/ui/vocab_page.dart';

/// 两个入口就够：方块列表和导入。壳层决定导航形态。
GoRouter buildRouter() => GoRouter(
  initialLocation: '/blocks',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/blocks',
          builder: (_, _) => const BlocksPage(),
          routes: [
            GoRoute(
              path: ':code',
              builder: (_, state) =>
                  BlockDetailPage(code: state.pathParameters['code']!),
            ),
          ],
        ),
        GoRoute(path: '/vocab', builder: (_, _) => const VocabPage()),
        GoRoute(path: '/import', builder: (_, _) => const ImportPage()),
      ],
    ),
  ],
);

/// 宽屏用侧边栏，窄屏用底部导航。
class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const _destinations = [
    (path: '/blocks', label: '方块', icon: Icons.grid_view_outlined, selected: Icons.grid_view),
    (path: '/vocab', label: '词表', icon: Icons.sell_outlined, selected: Icons.sell),
    (path: '/import', label: '导入', icon: Icons.file_download_outlined, selected: Icons.file_download),
  ];

  int get _index {
    final index = _destinations.indexWhere(
      (destination) => location.startsWith(destination.path),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;

    if (wide) {
      return Scaffold(
        // 状态栏 / 灵动岛不压住侧边栏和内容。桌面上 padding 为 0，等价于不包。
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (index) =>
                    context.go(_destinations[index].path),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final destination in _destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selected),
                      label: Text(destination.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // 底部交给 NavigationBar 自己躲手势条。
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => context.go(_destinations[index].path),
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selected),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
