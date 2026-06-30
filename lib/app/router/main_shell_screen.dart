import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/desktop_nav_rail.dart';
import '../layout/responsive_layout.dart';
import 'shell_layout.dart';

/// 메인 탭 셸: 오늘(/) · 주간(/plan/week) · 프로필(/profile) + 중앙 오늘 선택(/plan/select).
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (kDebugMode) {
          ResponsiveLayout.logDiagnostics(context, tag: 'shell', constraints: constraints);
        }

        final compact = ResponsiveLayout.isCompactForLayout(context, constraints);

        if (compact) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F6FA),
            body: SizedBox.expand(child: navigationShell),
            bottomNavigationBar: MainBottomNavigationBar(shell: navigationShell),
          );
        }

        // 노트북·데스크톱 — 변경 금지.
        return Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopNavRail(shell: navigationShell),
              Expanded(child: ShellBodySlot(child: navigationShell)),
            ],
          ),
        );
      },
    );
  }
}

class MainBottomNavigationBar extends StatelessWidget {
  const MainBottomNavigationBar({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _primaryBlue = Color(0xFF4A90E2);

  @override
  Widget build(BuildContext context) {
    final idx = shell.currentIndex;

    return Material(
      elevation: 12,
      shadowColor: Colors.black26,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: _HomeDestination(
                    selected: idx == 0,
                    onTap: () => shell.goBranch(0),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: _CenterAddButton(
                    onTap: () => context.push('/plan/select'),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: _SideDestination(
                    selected: idx == 1,
                    icon: Icons.calendar_month_rounded,
                    label: '주간',
                    onTap: () => shell.goBranch(1),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: _SideDestination(
                    selected: idx == 2,
                    icon: Icons.person_outline_rounded,
                    label: '프로필',
                    onTap: () => shell.goBranch(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeDestination extends StatelessWidget {
  const _HomeDestination({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MainBottomNavigationBar._primaryBlue : const Color(0xFF8E93A3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.home_rounded, size: 26, color: color),
          const SizedBox(height: 4),
          Text(
            '홈',
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideDestination extends StatelessWidget {
  const _SideDestination({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MainBottomNavigationBar._primaryBlue : const Color(0xFF8E93A3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterAddButton extends StatelessWidget {
  const _CenterAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MainBottomNavigationBar._primaryBlue,
      elevation: 6,
      shadowColor: MainBottomNavigationBar._primaryBlue.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
