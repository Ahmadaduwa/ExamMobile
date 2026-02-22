/// หน้าจอแสดงรายละเอียดของรายงานแจ้งเหตุ (Detail Screen)
/// แสดงข้อมูลครบถ้วน พร้อมรูปภาพและผลการวิเคราะห์ของ AI
library;
import 'dart:io';
import 'package:flutter/material.dart';
import 'add_report_screen.dart';

/// Widget หน้าจอรายละเอียด (ไม่มี state เปลี่ยนแปลง)
class DetailScreen extends StatelessWidget {
  final Map<String, dynamic> report; // ข้อมูลรายงานที่จะแสดง

  const DetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดการแจ้งเหตุ'),
        actions: [
          // ปุ่มแก้ไข (navigate ไปหน้า AddReportScreen แบบ Edit mode)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddReportScreen(existingReport: report),
                ),
              );
              // กลับไปหน้าก่อนหลังแก้ไขเสร็จ เพื่อให้ HomeScreen รีเฟรช
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. รูปภาพหลักฐาน (ถ้ามี)
            if (report['photo_path'] != null &&
                report['photo_path'].toString().isNotEmpty &&
                File(report['photo_path']).existsSync())
              Image.file(
                File(report['photo_path']),
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              )
            else
              Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey[300],
                child: const Icon(Icons.no_photography,
                    size: 64, color: Colors.grey),
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Card แสดงผลการวิเคราะห์ของ AI
                  Card(
                    color: Colors.blue.shade50,
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.analytics, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Analysis Result:',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Type: ${report['evidence_type']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  'Confidence: ${(report['confidence_score'] as double).toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. ข้อมูลทั่วไป (ประเภท, ความรุนแรง, สถานที่, จังหวัด, วันที่, ผู้แจ้ง)
                  _buildDetailRow(
                      context, 'หัวข้อความผิด', report['violation_name']),
                  _buildDetailRow(context, 'ระดับความรุนแรง', report['severity'],
                      isHighlighted: true),
                  const Divider(),
                  _buildDetailRow(context, 'สถานที่', report['station_name']),
                  _buildDetailRow(context, 'จังหวัด',
                      '${report['province']} ${report['district'] ?? ""}'),
                  const Divider(),
                  _buildDetailRow(context, 'วันที่แจ้ง', report['timestamp']),
                  _buildDetailRow(context, 'ผู้แจ้ง', report['reporter_name']),
                  const SizedBox(height: 16),
                  
                  // รายละเอียดเพิ่มเติม
                  Text(
                    'รายละเอียดเพิ่มเติม',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      report['description'] ?? '-',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget helper สร้างแถวข้อมูล (label + value)
  /// isHighlighted = true จะแสดงสีแดง
  Widget _buildDetailRow(BuildContext context, String label, String? value,
      {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isHighlighted ? Colors.red : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
