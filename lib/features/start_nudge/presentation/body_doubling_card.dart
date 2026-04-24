import 'package:flutter/material.dart';

/// 바디 더블링: 같은 시간대에 “함께 있다”는 느낌만 줄 수 있는 자리표시자.
/// 추후 라이브 세션/친구 매칭으로 확장.
class BodyDoublingCard extends StatelessWidget {
  const BodyDoublingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.groups_2_outlined),
        title: const Text('바디 더블링 (예정)'),
        subtitle: const Text('조용한 같이 집중 방 — 다음 버전에서 연결할 수 있어요.'),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('MVP에서는 안내 카드만 표시돼요.')),
          );
        },
      ),
    );
  }
}
