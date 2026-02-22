/// คลาสแบบจำลองข้อมูลหน่วยเลือกตั้ง (Polling Station)
/// ใช้เก็บข้อมูลสถานที่เลือกตั้งต่างๆ
class PollingStation {
  final int station_id;       // รหัสหน่วยเลือกตั้ง
  final String station_name;  // ชื่อหน่วยเลือกตั้ง
  final String zone;          // เขตเลือกตั้ง
  final String province;      // จังหวัด

  /// ตัวสร้างสำหรับสร้างข้อมูล PollingStation
  const PollingStation({
    required this.station_id,
    required this.station_name,
    required this.zone,
    required this.province,
  });
  
  /// แปลง Object เป็น Map เพื่อบันทึกลงฐานข้อมูล
  Map<String, dynamic> toMap(){
    return {
      'station_id': station_id,
      'station_name': station_name,
      'zone': zone,
      'province': province,
    };
  }

  /// สร้าง Object จาก Map ที่ดึงมาจากฐานข้อมูล
  factory PollingStation.fromMap(Map<String, dynamic> map){
    return PollingStation(
      station_id: map['station_id'],
      station_name: map['station_name'],
      zone: map['zone'],
      province: map['province'],
    );
  }
}