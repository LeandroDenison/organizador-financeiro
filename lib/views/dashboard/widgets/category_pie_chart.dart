import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../utils/currency_formatter.dart';

class CategoryPieChart extends StatefulWidget {
  final Map<String, double> expensesByCategory;

  const CategoryPieChart({super.key, required this.expensesByCategory});

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int touchedIndex = -1;

  static const List<Color> _palette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFFEC4899), // Pink
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Violet
    Color(0xFF3B82F6), // Blue
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF64748B), // Slate
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.expensesByCategory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              const Text(
                'Nenhuma despesa registrada ainda',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final total = widget.expensesByCategory.values.fold(0.0, (s, v) => s + v);
    final entries = widget.expensesByCategory.entries.toList();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(entries.length, (i) {
                final isTouched = i == touchedIndex;
                final fontSize = isTouched ? 16.0 : 12.0;
                final radius = isTouched ? 55.0 : 45.0;
                final percentage = (entries[i].value / total) * 100;

                return PieChartSectionData(
                  color: _palette[i % _palette.length],
                  value: entries[i].value,
                  title: percentage >= 8 ? '${percentage.toStringAsFixed(0)}%' : '',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(entries.length, (i) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _palette[i % _palette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${entries[i].key}: ${CurrencyFormatter.format(entries[i].value)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}
