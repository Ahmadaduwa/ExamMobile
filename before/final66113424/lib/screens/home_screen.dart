/// หน้าจอหลักแสดงรายการแจ้งเหตุทั้งหมด (Home Screen)
/// มีฟีเจอร์: ค้นหา, ลบ, ดูรายละเอียด, เพิ่มรายงานใหม่
library;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_report_screen.dart';

import 'package:final66113424/helpers/database_helper.dart';
import 'detail_screen.dart';

/// ฟังก์ชันแปลง severity เป็นสี (High=แดง, Medium=ส้ม, Low=เขียว)
Color getSeverityColor(String severity) {
  if (severity == 'High') {
    return Colors.red;
  }
  if (severity == 'Medium') {
    return Colors.orange;
  }
  if (severity == 'Low') {
    return Colors.green;
  }
  return Colors.grey;
}

/// ฟังก์ชันแปลงวันที่จาก yyyy-MM-dd HH:mm:ss เป็นภาษาไทย
/// เช่น "8 ก.พ. 2569 เวลา 09:30 น."
String formatHumanReadableDate(String rawTimestamp) {
  try {
    final parsed = DateFormat('yyyy-MM-dd HH:mm:ss').parse(rawTimestamp);
    const thaiMonths = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    final monthText = thaiMonths[parsed.month - 1];
    final buddhistYear = parsed.year + 543; // แปลงเป็นปี พ.ศ.
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.day} $monthText $buddhistYear เวลา $hh:$mm น.';
  } catch (_) {
    return rawTimestamp; // หาก parse ไม่ได้ให้คืนค่าเดิม
  }
}

/// Widget หน้าจอหลัก (Stateful เพราะมีการเปลี่ยนแปลงข้อมูล)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// State สำหรับ HomeScreen
class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _incidentReports = []; // รายการรายงานทั้งหมด
  bool _isLoading = true;                            // สถานะกำลังโหลดข้อมูล
  String? _errorMessage;                              // ข้อความ error (ถ้ามี)
  final TextEditingController _searchController = TextEditingController(); // Controller สำหรับช่องค้นหา
  String _searchKeyword = '';                         // คำค้นปัจจุบัน

  @override
  void initState() {
    super.initState();
    _loadReports(); // โหลดข้อมูลครั้งแรกตอนเปิดหน้าจอ
  }

  @override
  void dispose() {
    _searchController.dispose(); // ทำลาย controller ตอนปิดหน้าจอ
    super.dispose();
  }

  /// ฟังก์ชันโหลดรายงานจากฐานข้อมูล
  /// ถ้ามี keyword จะค้นหา ไม่มีจะดึงทั้งหมด
  Future<void> _loadReports({String keyword = ''}) async {
    try {
      final reports = keyword.trim().isEmpty
          ? await getIncidentReports()              // ดึงทั้งหมด
          : await searchIncidentReports(keyword);   // ค้นหาตามคำค้น
      if (!mounted) return;
      setState(() {
        _incidentReports = reports;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString(); // เก็บข้อความ error
      });
    }
  }

  /// รีเฟรชข้อมูล (ใช้หลังจากเพิ่ม/แก้ไข/ลบ)
  void _refreshData() {
    setState(() {
      _isLoading = true;
    });
    _loadReports(keyword: _searchKeyword);
  }

  /// ฟังก์ชันเมื่อพิมพ์ค้นหา
  void _onSearchChanged(String value) {
    setState(() {
      _searchKeyword = value;
      _isLoading = true;
    });
    _loadReports(keyword: value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการแจ้งเหตุ'),
      ),
      body: Column(
        children: [
          // ช่องค้นหา (TextField)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'ค้นหา รายละเอียด/ผู้แจ้ง/ประเภท เช่น แจกเงิน',
                prefixIcon: const Icon(Icons.search),
                // ปุ่มล้างข้อความ (แสดงเมื่อมีคำค้น)
                suffixIcon: _searchKeyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // รายการ (ListView)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator()) // แสดง loading
                : _errorMessage != null
                    ? Center(child: Text('Error: $_errorMessage')) // แสดง error
                    : _incidentReports.isEmpty
                        ? const Center(child: Text('ไม่พบข้อมูลที่ค้นหา')) // ไม่มีข้อมูล
                        : ListView.builder(
                      itemCount: _incidentReports.length,
                      itemBuilder: (context, index) {
                        final report = _incidentReports[index];
                        final severity = report['severity']?.toString() ?? '';

                        // Dismissible - รองรับการ swipe ลบ
                        return Dismissible(
                          key: ValueKey(report['report_id']),
                          direction: DismissDirection.endToStart, // swipe จากขวาไปซ้าย
                          // ถามยืนยันก่อนลบ
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) {
                                    return AlertDialog(
                                      title: const Text('ยืนยันการลบ'),
                                      content: const Text('คุณแน่ใจหรือไม่ที่จะลบรายงานนี้?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogContext, false),
                                          child: const Text('ยกเลิก'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogContext, true),
                                          child: const Text('ตกลง'),
                                        ),
                                      ],
                                    );
                                  },
                                ) ??
                                false; // ถ้าปิด dialog ให้ถือว่ายกเลิก
                          },
                          // พื้นหลังตอน swipe (สีแดง + ไอคอนถังขยะ)
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          // เมื่อ dismiss จริงๆ (ลบแล้ว)
                          onDismissed: (direction) async {
                            final removedItem = report;
                            final messenger = ScaffoldMessenger.of(context);

                            // ดึง report_id มาลบ
                            final dynamic rawReportId =
                                removedItem['id'] ?? removedItem['report_id'];
                            final int? reportId = rawReportId is int
                                ? rawReportId
                                : int.tryParse(rawReportId?.toString() ?? '');

                            if (reportId == null) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('ลบไม่สำเร็จ: ไม่พบรหัสรายการ'),
                                ),
                              );
                              _refreshData();
                              return;
                            }

                            // เรียกฟังก์ชันลบจากฐานข้อมูล
                            final isDeleted =
                                await DatabaseHelper.deleteReport(reportId);

                            if (!isDeleted) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('ลบไม่สำเร็จ: ไม่พบข้อมูลในฐานข้อมูล'),
                                ),
                              );
                              _refreshData();
                              return;
                            }

                            // ลบออกจาก list ในหน้าจอ
                            if (!mounted) return;
                            setState(() {
                              _incidentReports.removeWhere(
                                (item) => (item['id'] ?? item['report_id']) == reportId,
                              );
                            });

                            // แสดง snackbar แจ้งว่าลบสำเร็จ
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('ลบรายการแล้ว')),
                            );
                          },
                          // Card ของแต่ละรายการ
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            child: ListTile(
                              // รูปภาพหลักฐาน (ถ้ามี)
                              leading: report['photo_path'] != null &&
                                      report['photo_path'].toString().isNotEmpty &&
                                      File(report['photo_path']).existsSync()
                                  ? Image.file(
                                      File(report['photo_path']),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.no_photography, size: 50),
                              // ชื่อประเภทการทุจริต (สีตาม severity)
                              title: Text(
                                '${report['violation_name']}',
                                style: TextStyle(color: getSeverityColor(severity)),
                              ),
                              // ชื่อหน่วยเลือกตั้ง + วันที่
                              subtitle: Text(
                                '${report['station_name']}\n${formatHumanReadableDate(report['timestamp']?.toString() ?? '')}',
                              ),
                              // ผล AI + confidence score
                              trailing: Text(
                                '${report['evidence_type']}\n(${(report['confidence_score'] as double).toStringAsFixed(2)})',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              // กดเข้าดูรายละเอียด
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailScreen(report: report),
                                  ),
                                );
                                _refreshData(); // รีเฟรชหลังกลับมา (อาจมีการแก้ไข)
                              },
                              isThreeLine: true,
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      // ปุ่ม + สำหรับเพิ่มรายงานใหม่
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddReportScreen()),
          );
          _refreshData(); // รีเฟรชหลังเพิ่มข้อมูลใหม่
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
