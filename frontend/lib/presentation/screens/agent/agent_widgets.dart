import 'package:flutter/material.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';

const Color kPrimary = Color(0xFF1F579C);
const Color kBg = Color(0xFFF5F7FA);

Color severityColor(String? s) => switch (s) {
      'critical' => const Color(0xFFDC2626),
      'high' => const Color(0xFFEA580C),
      'medium' => const Color(0xFFD4A017),
      _ => const Color(0xFF6B7280),
    };

String fmtDateTime(String? iso) {
  if (iso == null) return '-';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '-';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

AppBar agentAppBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) => AppBar(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      actions: actions,
      bottom: bottom,
    );

class Chip2 extends StatelessWidget {
  final String label;
  final Color color;
  const Chip2(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

/// Loads a list from the API with loading / error+retry / empty states.
class ApiListView<T> extends StatefulWidget {
  final Future<List<T>> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) itemBuilder;
  final IconData emptyIcon;
  const ApiListView(
      {super.key, required this.load, required this.itemBuilder, this.emptyIcon = Icons.inbox_outlined});

  @override
  State<ApiListView<T>> createState() => _ApiListViewState<T>();
}

class _ApiListViewState<T> extends State<ApiListView<T>> {
  late Future<List<T>> _future = widget.load();
  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text('${snap.error}', textAlign: TextAlign.center),
              ),
              TextButton(onPressed: _reload, child: Text(tr('retry'))),
            ])),
          );
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.emptyIcon, size: 48, color: kPrimary.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text(tr('nothing_here'), style: const TextStyle(color: Colors.grey)),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (c, i) => widget.itemBuilder(c, items[i], _reload),
          ),
        );
      },
    );
  }
}

// Flutter cannot paint rounded corners on a border with mixed colours, so accented cards are square.
BoxDecoration cardDecoration([Color? accent]) => accent == null
    ? BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E3EA)),
      )
    : BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: accent, width: 4),
          top: const BorderSide(color: Color(0xFFE0E3EA)),
          right: const BorderSide(color: Color(0xFFE0E3EA)),
          bottom: const BorderSide(color: Color(0xFFE0E3EA)),
        ),
      );

List<Map<String, dynamic>> dataList(dynamic responseData) =>
    (((responseData as Map)['data'] as List?) ?? []).cast<Map<String, dynamic>>();
