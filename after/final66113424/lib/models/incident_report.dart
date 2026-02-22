/// คลาสแบบจำลองข้อมูลรายงานเหตุการณ์ (Incident Report)
/// ใช้เก็บข้อมูลการแจ้งเหตุการทุจริตในการเลือกตั้ง
class IncidentReport {
  final int report_id;         // รหัสรายงาน
  final int station_id;        // รหัสหน่วยเลือกตั้ง
  final int type_id;           // รหัสประเภทการทุจริต
  final String reporter_name;  // ชื่อผู้แจ้ง
  final String description;    // รายละเอียดการแจ้งเหตุ
  final String evidence_photo; // เส้นทางรูปภาพหลักฐาน
  final String timestamp;      // เวลาที่แจ้ง
  final String ai_result;      // ผลการวิเคราะห์จาก AI
  final double ai_confidence;  // ค่าความเชื่อมั่นของ AI (0.0-1.0)

  /// ตัวสร้างสำหรับสร้างข้อมูล IncidentReport
  const IncidentReport({
    required this.report_id,
    required this.station_id,
    required this.type_id,
    required this.reporter_name,
    required this.description,
    required this.evidence_photo,
    required this.timestamp,
    required this.ai_result,
    required this.ai_confidence,
  });

  /// แปลง Object เป็น Map เพื่อบันทึกลงฐานข้อมูล
  Map<String, dynamic> toMap(){
    return {
      'report_id': report_id,
      'station_id': station_id,
      'type_id': type_id,
      'reporter_name': reporter_name,
      'description': description,
      'evidence_photo': evidence_photo,
      'timestamp': timestamp,
      'ai_result': ai_result,
      'ai_confidence': ai_confidence,
    };
  }

  /// สร้าง Object จาก Map ที่ดึงมาจากฐานข้อมูล
  factory IncidentReport.fromMap(Map<String, dynamic> map){
    return IncidentReport(
      report_id: map['report_id'],
      station_id: map['station_id'],
      type_id: map['type_id'],
      reporter_name: map['reporter_name'],
      description: map['description'],
      evidence_photo: map['evidence_photo'],
      timestamp: map['timestamp'],
      ai_result: map['ai_result'],
      ai_confidence: map['ai_confidence'] as double,
    );
  }
}