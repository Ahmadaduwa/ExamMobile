/// หน้าจอหลักแสดงรายการแจ้งเหตุทั้งหมด
/// มีฟีเจอร์: ค้นหา, ลบ, ดูรายละเอียด, เพิ่มรายงานใหม่
library;
import 'package:flutter/material.dart';
import 'package:final66113424/helpers/database_helper.dart';
import 'report_Incident.dart';
import 'editPoolingStation_screen.dart';
import 'incidentList_screen.dart';
import 'searchFilter_screen.dart';

/// วิดเจ็ตหน้าจอหลัก (มีการเปลี่ยนแปลงข้อมูล)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// สถานะของหน้าจอหลัก
class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _top3Stations = [];
  int _totalIncidents = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final total = await getTotalIncidents();
      final top3 = await getTop3ComplainedPollingStations();
      
      if (mounted) {
        setState(() {
          _totalIncidents = total;
          _top3Stations = top3;
          _isLoading = false;
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

  Future<void> _showResetDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('รีเซ็ตฐานข้อมูล'),
        content: const Text('การดำเนินการนี้จะลบข้อมูลทั้งหมดและลงข้อมูลตั้งต้นใหม่'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (!mounted) return;
              setState(() => _isLoading = true);
              await resetDatabase();
              await _loadDashboardData();
            },
            child: const Text('รีเซ็ตตอนนี้'),
          ),
        ],
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) => _loadDashboardData()); // รีเฟรชข้อมูลเมื่อย้อนกลับ
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            onPressed: _showResetDialog,
            tooltip: 'รีเซ็ตฐานข้อมูล',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('ข้อมูลสรุป'),
                      const SizedBox(height: 10),
                      Text('การแจ้งเหตุทั้งหมด: $_totalIncidents เรื่อง'),
                      const SizedBox(height: 8),
                      const Text('3 อันดับหน่วยเลือกตั้งที่ถูกร้องเรียนสูงสุด:'),
                      const SizedBox(height: 6),
                      if (_top3Stations.isEmpty)
                        const Text('- ไม่มีข้อมูล -')
                      else
                        ..._top3Stations.asMap().entries.map((entry) {
                          final index = entry.key + 1;
                          final station = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '$index) ${station['station_name']} - ${station['total_complaints']} ครั้ง',
                            ),
                          );
                        }),
                      const SizedBox(height: 20),
                      const Text('เมนูหลัก'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _navigateTo(const ReportIncidentScreen()),
                        child: const Text('แจ้งเหตุ (Report Incident)'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _navigateTo(const EditPoolingStationScreen()),
                        child: const Text('แก้ไขหน่วยเลือกตั้ง (Edit Polling Station)'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _navigateTo(const IncidentlistScreen()),
                        child: const Text('รายการแจ้งเหตุ (Incident List)'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _navigateTo(const SearchFilterScreen()),
                        child: const Text('ค้นหา (Search & Filter)'),
                      ),
                    ],
                  ),
                ),
    );
  }
}

