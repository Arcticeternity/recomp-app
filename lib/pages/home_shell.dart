import 'package:flutter/material.dart';

import '../app_state.dart';
import 'calculate_page.dart';
import 'calendar_page.dart';
import 'cycle_page.dart';
import 'guide_page.dart';
import 'today_page.dart';

/// 主界面：底部导航 5 个 Tab。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayPage(state: widget.state),
      CalculatePage(state: widget.state),
      CyclePage(state: widget.state),
      GuidePage(state: widget.state),
      CalendarPage(state: widget.state),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), label: '今日'),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), label: '计算'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), label: '周期'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '指南'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: '日历'),
        ],
      ),
    );
  }
}
