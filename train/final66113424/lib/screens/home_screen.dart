/// หน้าจอหลักแสดงรายการแจ้งเหตุทั้งหมด (Home Screen)
/// มีฟีเจอร์: ค้นหา, ลบ, ดูรายละเอียด, เพิ่มรายงานใหม่
library;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  bool _isExporting = false;                         // สถานะกำลัง export
  String? _errorMessage;                              // ข้อความ error (ถ้ามี)
  final TextEditingController _searchController = TextEditingController(); // Controller สำหรับช่องค้นหา
  String _searchKeyword = '';                         // คำค้นปัจจุบัน
  String? _selectedZone;                              // เขตที่เลือกกรอง

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
      List<Map<String, dynamic>> reports;
      if (_selectedZone != null) {
        reports = await getReportsByZone(_selectedZone!);
        // ถ้ามี keyword ด้วย ให้กรองใน memory (หรือจะแก้ SQL ก็ได้ แต่แบบนี้ง่ายกว่าสำหรับข้อมูลน้อย)
        if (keyword.trim().isNotEmpty) {
          final kw = keyword.trim().toLowerCase();
          reports = reports.where((r) {
            return (r['description']?.toString().toLowerCase().contains(kw) ?? false) ||
                   (r['reporter_name']?.toString().toLowerCase().contains(kw) ?? false) ||
                   (r['violation_name']?.toString().toLowerCase().contains(kw) ?? false);
          }).toList();
        }
      } else {
        reports = keyword.trim().isEmpty
            ? await getIncidentReports()              // ดึงทั้งหมด
            : await searchIncidentReports(keyword);   // ค้นหาตามคำค้น
      }

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

  /// ฟังก์ชันส่งออกข้อมูลเป็น CSV
  Future<void> _exportToCSV() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
    });

    try {
      final reports = await getAllIncidentReportsForExport();
      if (reports.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีข้อมูลสำหรับส่งออก')),
        );
        setState(() {
          _isExporting = false;
        });
        return;
      }

      // สร้าง Header ของ CSV
      String csvData = 'ID,Station,Zone,Province,Violation Type,Severity,Reporter,Description,Timestamp,Evidence Type,Confidence Score\n';

      // วนลูปเพิ่มข้อมูลแต่ละแถว
      for (var row in reports) {
        // จัดการกับข้อความที่มีลูกน้ำ (,) หรือขึ้นบรรทัดใหม่ โดยครอบด้วยเครื่องหมายคำพูด ("")
        String escapeCsv(dynamic value) {
          if (value == null) return '';
          String str = value.toString();
          if (str.contains(',') || str.contains('\n') || str.contains('"')) {
            str = str.replaceAll('"', '""');
            return '"$str"';
          }
          return str;
        }

        csvData += '${escapeCsv(row['report_id'])},'
            '${escapeCsv(row['station_name'])},'
            '${escapeCsv(row['zone'])},'
            '${escapeCsv(row['province'])},'
            '${escapeCsv(row['violation_name'])},'
            '${escapeCsv(row['severity'])},'
            '${escapeCsv(row['reporter_name'])},'
            '${escapeCsv(row['description'])},'
            '${escapeCsv(row['timestamp'])},'
            '${escapeCsv(row['evidence_type'])},'
            '${escapeCsv(row['confidence_score'])}\n';
      }

      // หาตำแหน่งที่จะบันทึกไฟล์
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/incident_reports_$timestamp.csv');

      // เขียนไฟล์
      await file.writeAsString(csvData);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ส่งออกสำเร็จ'),
          content: Text('บันทึกไฟล์ CSV แล้วที่:\n${file.path}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ปิด'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await Share.shareXFiles(
                  [XFile(file.path)],
                  text: 'รายงานเหตุการณ์ทุจริตการเลือกตั้ง (CSV)',
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('แชร์ไฟล์'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการส่งออก: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  /// ฟังก์ชันแสดง Dialog เลือกเขต
  Future<void> _showFilterDialog() async {
    final zones = await getAllZones();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('กรองตามเขต'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: zones.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = _selectedZone == null;
                  return ListTile(
                    title: const Text('แสดงทั้งหมด'),
                    leading: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.deepPurple : Colors.grey,
                    ),
                    onTap: () => Navigator.pop(context, 'ALL'),
                  );
                }
                final zone = zones[index - 1];
                final isSelected = _selectedZone == zone;
                return ListTile(
                  title: Text(zone),
                  leading: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.deepPurple : Colors.grey,
                  ),
                  onTap: () => Navigator.pop(context, zone),
                );
              },
            ),
          ),
        );
      },
    ).then((selected) {
      // ถ้ามีการเลือก (หรือเลือกทั้งหมด) ให้โหลดข้อมูลใหม่
      // หมายเหตุ: ถ้า selected เป็น null อาจเกิดจากการกดปิด dialog (tap outside)
      // เราจะเช็คว่าถ้ามีการส่งค่ากลับมาจริงๆ (รวมถึงส่งค่าว่าง '' เพื่อล้าง filter)
      if (selected != null) {
        final newZone = selected == 'ALL' ? null : selected;
        if (newZone != _selectedZone) {
          setState(() {
            _selectedZone = newZone;
            _isLoading = true;
          });
          _loadReports(keyword: _searchKeyword);
        }
      }
    });
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
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = _selectedZone == null && _searchKeyword.trim().isEmpty
        ? 'ยังไม่มีรายการแจ้งเหตุ'
        : 'ไม่พบข้อมูลตามเงื่อนไขที่เลือก';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 44, color: Colors.grey),
          const SizedBox(height: 10),
          Text(message),
        ],
      ),
    );
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
              setState(() {
                _isLoading = true;
              });
              await resetDatabase();
              await _loadReports();
            },
            child: const Text('รีเซ็ตตอนนี้'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการแจ้งเหตุ'),
        actions: [
          IconButton.filledTonal(
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            tooltip: 'ส่งออกข้อมูล (CSV)',
            onPressed: _isExporting ? null : _exportToCSV,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'reset') {
                _showResetDialog();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('รีเซ็ตฐานข้อมูล'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ช่องค้นหา (TextField) และปุ่มกรอง
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.filter_alt,
                    color: _selectedZone != null ? Colors.deepPurple : Colors.grey,
                  ),
                  onPressed: _showFilterDialog,
                  tooltip: 'กรองตามเขต',
                ),
              ],
            ),
          ),
          // แสดงเขตที่เลือกกรอง (ถ้ามี)
          if (_selectedZone != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Chip(
                    label: Text('เขต: $_selectedZone'),
                    onDeleted: () {
                      setState(() {
                        _selectedZone = null;
                        _isLoading = true;
                      });
                      _loadReports(keyword: _searchKeyword);
                    },
                  ),
                ],
              ),
            ),
          // รายการ (ListView)
          Expanded(
            child: _isLoading
              ? _buildLoadingState() // แสดง loading
                : _errorMessage != null
                ? _buildErrorState() // แสดง error
                    : _incidentReports.isEmpty
                  ? _buildEmptyState() // ไม่มีข้อมูล
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
