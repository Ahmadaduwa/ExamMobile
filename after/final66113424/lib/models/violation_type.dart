/// คลาสแบบจำลองข้อมูลประเภทการทุจริต (Violation Type)
/// ใช้เก็บข้อมูลประเภทความผิดต่างๆ ในการเลือกตั้ง
class ViolationType {
  final int type_id;        // รหัสประเภทการทุจริต
  final String type_name;   // ชื่อประเภทการทุจริต
  final String severity;    // ระดับความรุนแรง (High, Medium, Low)

  /// ตัวสร้างสำหรับสร้างข้อมูล ViolationType
  const ViolationType({
    required this.type_id,
    required this.type_name,
    required this.severity,
  });

  /// แปลง Object เป็น Map เพื่อบันทึกลงฐานข้อมูล
  Map<String, dynamic> toMap(){
    return {
      'type_id': type_id,
      'type_name': type_name,
      'severity': severity,
    };
  }

  /// สร้าง Object จาก Map ที่ดึงมาจากฐานข้อมูล
  factory ViolationType.fromMap(Map<String, dynamic> map){
    return ViolationType(
      type_id: map['type_id'],
      type_name: map['type_name'],
      severity: map['severity'],
    );
  }
}