import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../helpers/database_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalIncidents = 0;
  List<Map<String, dynamic>> _incidentsByZone = [];
  List<Map<String, dynamic>> _incidentsBySeverity = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final total = await getTotalIncidents();
      final byZone = await getIncidentsByZone();
      final bySeverity = await getIncidentsBySeverity();

      if (mounted) {
        setState(() {
          _totalIncidents = total;
          _incidentsByZone = byZone;
          _incidentsBySeverity = bySeverity;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
            const SizedBox(height: 10),
            const Text('โหลดข้อมูลไม่สำเร็จ'),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 44, color: Colors.grey),
          SizedBox(height: 10),
          Text('ยังไม่มีข้อมูลสถิติ'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สถิติการแจ้งเหตุ'),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _totalIncidents == 0
                  ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // สรุปจำนวนทั้งหมด
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Text(
                              'จำนวนการแจ้งเหตุทั้งหมด',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_totalIncidents',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const Text('รายการ'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // กราฟวงกลม: สัดส่วนความรุนแรง
                    const Text(
                      'สัดส่วนตามระดับความรุนแรง',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: _incidentsBySeverity.isEmpty
                          ? const Center(child: Text('ไม่มีข้อมูล'))
                          : PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: _incidentsBySeverity.map((data) {
                                  final severity = data['severity'] as String;
                                  final count = data['total'] as int;
                                  return PieChartSectionData(
                                    color: _getSeverityColor(severity),
                                    value: count.toDouble(),
                                    title: '$count',
                                    radius: 50,
                                    titleStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                    // Legend สำหรับกราฟวงกลม
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _incidentsBySeverity.map((data) {
                        final severity = data['severity'] as String;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                color: _getSeverityColor(severity),
                              ),
                              const SizedBox(width: 4),
                              Text(severity),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // กราฟแท่ง: จำนวนเหตุการณ์แยกตามเขต
                    const Text(
                      'จำนวนเหตุการณ์แยกตามเขต',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 250,
                      child: _incidentsByZone.isEmpty
                          ? const Center(child: Text('ไม่มีข้อมูล'))
                          : BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: _incidentsByZone.fold<double>(
                                        0, (max, e) => (e['total'] as int) > max ? (e['total'] as int).toDouble() : max) +
                                    2,
                                barTouchData: BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        if (value.toInt() >= 0 && value.toInt() < _incidentsByZone.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              _incidentsByZone[value.toInt()]['zone'].toString(),
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      getTitlesWidget: (value, meta) {
                                        if (value % 1 == 0) {
                                          return Text(value.toInt().toString());
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barGroups: _incidentsByZone.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final data = entry.value;
                                  return BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: (data['total'] as int).toDouble(),
                                        color: Colors.deepPurple,
                                        width: 16,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
