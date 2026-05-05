import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_chrome.dart';
import '../../domain/focus_log_event.dart';
import '../focus_log_providers.dart';

/// 딴생각 잠깐 적어두기: 안내 문구 · 빠른 칩 · 직접 입력 · 오늘 목록.
class ParkedThoughtsCard extends ConsumerStatefulWidget {
  const ParkedThoughtsCard({super.key});

  @override
  ConsumerState<ParkedThoughtsCard> createState() => _ParkedThoughtsCardState();
}

class _ParkedThoughtsCardState extends ConsumerState<ParkedThoughtsCard>
    with SingleTickerProviderStateMixin {
  final _textCtrl = TextEditingController();
  bool _expanded = false;

  static const _quickTags = ['할 일', '걱정', '아이디어', '연락·메시지', '기타'];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  String _formatTs(int tsMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(tsMs);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _displayLine(FocusLogEvent e) {
    final text = e.meta['text'] as String?;
    final tag = e.meta['tag'] as String?;
    if (text != null && text.isNotEmpty) {
      if (tag != null && tag.isNotEmpty) return '[$tag] $text';
      return text;
    }
    if (tag != null && tag.isNotEmpty) return '[$tag]';
    return '기록';
  }

  Future<void> _append({String? tag, String? text}) async {
    final repo = ref.read(focusLogRepositoryProvider);
    await repo.append(
      FocusLogEvent(
        type: FocusLogEventType.parkedThought,
        tsMs: DateTime.now().millisecondsSinceEpoch,
        dateKey: _todayKey(),
        meta: {
          if (tag != null && tag.isNotEmpty) 'tag': tag,
          if (text != null && text.isNotEmpty) 'text': text,
        },
      ),
    );
    ref.invalidate(focusLogEventsProvider);
  }

  Future<void> _submitText() async {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    _textCtrl.clear();
    await _append(text: t);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(focusLogEventsProvider);

    return async.when(
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: AppChrome.softCardDecoration(),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (events) {
        final today = _todayKey();
        final parked = events
            .where((e) => e.type == FocusLogEventType.parkedThought && e.dateKey == today)
            .toList()
          ..sort((a, b) => b.tsMs.compareTo(a.tsMs));

        final countLabel = parked.isEmpty ? '0' : '${parked.length}';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: AppChrome.softCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '딴생각 목록',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppChrome.heroAccentBlue,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F4FB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Text(
                            countLabel,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: const Color(0xFF2C3140),
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: const Color(0xFF2C3140),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '딴생각은 여기에 기록하고 끝나고 다시 생각할까요?',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF5C6378),
                                    height: 1.35,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '빠른 기록',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFF2C3140),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _quickTags
                                  .map(
                                    (t) => ActionChip(
                                      label: Text(t),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      onPressed: () => _append(tag: t),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '직접 적기',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFF2C3140),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _textCtrl,
                                    maxLines: 2,
                                    minLines: 1,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _submitText(),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: '한 줄만 적어도 돼요',
                                      filled: true,
                                      fillColor: const Color(0xFFF8F9FC),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppChrome.softBorder),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppChrome.softBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide:
                                            const BorderSide(color: AppChrome.heroAccentBlue, width: 1.2),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: FilledButton.tonal(
                                    onPressed: _submitText,
                                    child: const Text('추가'),
                                  ),
                                ),
                              ],
                            ),
                            if (parked.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                '오늘 적은 것',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: const Color(0xFF2C3140),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: parked.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final e = parked[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatTs(e.tsMs),
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: const Color(0xFF8A90A0),
                                                ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _displayLine(e),
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: const Color(0xFF2C3140),
                                                    height: 1.35,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              Text(
                                '오늘은 아직 없어요. 떠오르면 바로 적어두세요.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF8A90A0),
                                      height: 1.3,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}
