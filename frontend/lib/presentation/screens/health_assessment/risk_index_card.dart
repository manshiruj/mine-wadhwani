import 'package:flutter/material.dart';
import 'package:mine_wadhwani/data/models/health_assessment/risk_index_calculator.dart';

class RiskIndexCard extends StatelessWidget {
  final RiskIndexResult result;

  const RiskIndexCard({super.key, required this.result});

  Color get _bandColor {
    switch (result.band) {
      case RiskBand.low:
        return const Color(0xFF10B981);
      case RiskBand.moderate:
        return const Color(0xFFF59E0B);
      case RiskBand.high:
        return const Color(0xFFEF4444);
      case RiskBand.critical:
        return const Color(0xFF991B1B);
    }
  }

  Color get _bandBg {
    switch (result.band) {
      case RiskBand.low:
        return const Color(0xFFD1FAE5);
      case RiskBand.moderate:
        return const Color(0xFFFFFBEB);
      case RiskBand.high:
        return const Color(0xFFFEF2F2);
      case RiskBand.critical:
        return const Color(0xFFFEE2E2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E3EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, size: 16, color: Color(0xFF1F579C)),
              const SizedBox(width: 8),
              const Text('Risk Index',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A2340))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                result.overallScore.toStringAsFixed(0),
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: _bandColor, height: 1),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 2),
                child: Text('/100', style: TextStyle(fontSize: 16, color: Color(0xFF9CA3AF))),
              ),
              const SizedBox(width: 12),
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _bandBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _bandColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  result.band.label.toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _bandColor, letterSpacing: 0.3),
                ),
              ),
            ],
          ),
          if (result.categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE0E3EA)),
            const SizedBox(height: 14),
            ...result.categories.map((c) => _categoryRow(c)),
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(RiskCategoryScore c) {
    final color = c.score >= 80
        ? const Color(0xFF10B981)
        : c.score >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              Text('${c.score.toStringAsFixed(0)}/100',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: c.score / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 3),
          Text(c.detail, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}