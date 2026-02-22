// หน้าจอรายการแจ้งเหตุส่วนตัว
// แสดงข้อมูลจากฐานข้อมูลพร้อมรูปตัวอย่างและรองรับการลบ
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:final66113424/helpers/database_helper.dart';
import 'package:final66113424/screens/incidentDetail_screen.dart';

/// วิดเจ็ตหน้ารายการแจ้งเหตุ (มีการโหลดและลบข้อมูล)
class IncidentlistScreen extends StatefulWidget {
  const IncidentlistScreen({super.key});

  @override
  State<IncidentlistScreen> createState() => _IncidentlistScreenState();
}

class _IncidentlistScreenState extends State<IncidentlistScreen> {
  /// รายการรายงานที่โหลดจากฐานข้อมูล
  List<Map<String, dynamic>> _reports = [];

  /// สถานะโหลดข้อมูล
  bool _isLoading = true;

  /// ข้อความข้อผิดพลาด (ถ้ามี)
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  /// โหลดรายงานทั้งหมดมาแสดงบนหน้าจอ
  Future<void> _loadReports() async {
    try {
      final reports = await getIncidentReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// ยืนยันก่อนลบ แล้วลบรายการตามรหัสรายงาน
  Future<void> _confirmAndDelete(Map<String, dynamic> report) async {
    final rawId = report['id'] ?? report['report_id'];
    final reportId = rawId is int ? rawId : int.tryParse(rawId.toString());
    if (reportId == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: const Text('กรุณายืนยันความแน่ใจก่อนลบรายการนี้'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ลบ'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    final deleted = await DatabaseHelper.deleteReport(reportId);
    if (!mounted) return;

    if (deleted) {
      setState(() {
        _reports.removeWhere((item) {
          final itemRawId = item['id'] ?? item['report_id'];
          final itemId =
              itemRawId is int ? itemRawId : int.tryParse(itemRawId.toString());
          return itemId == reportId;
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบข้อมูลสำเร็จ')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถลบข้อมูลได้')),
      );
    }
  }

  Future<void> _openReportDetail(Map<String, dynamic> report) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentDetailScreen(report: report),
      ),
    );

    if (!mounted) return;
    await _loadReports();
  }

  /// สร้างรูปย่อของหลักฐาน (รองรับกรณีรูปหายหรือไม่มีรูป)
  Widget _buildThumbnail(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) {
      return Container(
        width: 64,
        height: 64,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported),
      );
    }

    final file = File(photoPath);
    if (!file.existsSync()) {
      return Container(
        width: 64,
        height: 64,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image),
      );
    }

    return Image.file(
      file,
      width: 64,
      height: 64,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการแจ้งเหตุส่วนตัว'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('เกิดข้อผิดพลาด: $_errorMessage'))
              : _reports.isEmpty
                  ? const Center(child: Text('ยังไม่มีรายการแจ้งเหตุ'))
                  : ListView.separated(
                      itemCount: _reports.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        final stationName =
                            report['station_name']?.toString() ?? '-';
                        final violationName =
                            report['violation_name']?.toString() ?? '-';
                        final reporterName =
                            report['reporter_name']?.toString() ?? '-';
                        final timestamp = report['timestamp']?.toString() ?? '-';
                        final photoPath = report['photo_path']?.toString();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          onTap: () => _openReportDetail(report),
                          leading: _buildThumbnail(photoPath),
                          title: Text(
                            stationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                violationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$reporterName • $timestamp',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'ลบรายการ',
                            onPressed: () => _confirmAndDelete(report),
                          ),
                        );
                      },
                    ),
    );
  }
}
