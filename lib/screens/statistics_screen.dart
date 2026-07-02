import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/stat_summary.dart';
import '../utils/formatters.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _db = AppDatabase.instance;
  Summary _summary = const Summary(income: 0, expense: 0);
  List<MonthlyTrend> _trend = [];
  List<CategoryExpenseStat> _expenseStats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await _db.getSummary();
    final trend = await _db.getMonthlyTrend();
    final expenseStats = await _db.getExpenseCategoryStats();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _trend = trend;
      _expenseStats = expenseStats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('数据统计', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _TotalPanel(summary: _summary),
          const SizedBox(height: 20),
          Text('月度收支趋势', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: _trend.isEmpty ? const _EmptyChart() : _TrendChart(data: _trend),
          ),
          const SizedBox(height: 24),
          Text('支出分类占比', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: _expenseStats.isEmpty
                ? const _EmptyChart()
                : _ExpensePieChart(data: _expenseStats),
          ),
        ],
      ),
    );
  }
}

class _TotalPanel extends StatelessWidget {
  const _TotalPanel({required this.summary});

  final Summary summary;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _TotalLine(label: '累计总收入', value: summary.income),
            const Divider(),
            _TotalLine(label: '累计总支出', value: summary.expense),
            const Divider(),
            _TotalLine(label: '历史总净结余', value: summary.balance),
          ],
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          '¥${moneyText(value)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.data});

  final List<MonthlyTrend> data;

  @override
  Widget build(BuildContext context) {
    final maxY = data
        .map((item) => item.income > item.expense ? item.income : item.expense)
        .fold<double>(0, (previous, current) => current > previous ? current : previous);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 100 : maxY * 1.2,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[index].month.substring(5),
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].income),
            ],
            isCurved: true,
            barWidth: 3,
            color: Colors.green,
          ),
          LineChartBarData(
            spots: [
              for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].expense),
            ],
            isCurved: true,
            barWidth: 3,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }
}

class _ExpensePieChart extends StatelessWidget {
  const _ExpensePieChart({required this.data});

  final List<CategoryExpenseStat> data;

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (sum, item) => sum + item.amount);
    final colors = [
      Colors.teal,
      Colors.redAccent,
      Colors.amber,
      Colors.indigo,
      Colors.pinkAccent,
      Colors.green,
      Colors.deepOrange,
      Colors.blueGrey,
    ];
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (var i = 0; i < data.length; i++)
                  PieChartSectionData(
                    value: data[i].amount,
                    title: '${(data[i].amount / total * 100).toStringAsFixed(0)}%',
                    color: colors[i % colors.length],
                    radius: 72,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      color: colors[index % colors.length],
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.categoryName)),
                    Text('¥${moneyText(item.amount)}'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '暂无统计数据',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
