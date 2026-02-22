/// คลาส SqlCommands - เก็บคำสั่ง SQL สำหรับสร้างตารางและข้อมูลเริ่มต้น
class SqlCommands {
  // ชื่อตารางในฐานข้อมูล
  static const String incidentReport = "incident_report";     // ตารางรายงานเหตุการณ์
  static const String pollingStation = "polling_station";      // ตารางหน่วยเลือกตั้ง
  static const String violationType = "violation_type";        // ตารางประเภทการทุจริต

  /// คำสั่งสร้างตาราง polling_station (หน่วยเลือกตั้ง)
  /// ประกอบด้วย: id, name (ชื่อหน่วย), district (เขต), province (จังหวัด)
  static const String createTablePollingStation =
      "CREATE TABLE $pollingStation (id INTEGER PRIMARY KEY, name TEXT, district TEXT, province TEXT)";

  /// คำสั่งสร้างตาราง violation_type (ประเภทการทุจริต)
  /// ประกอบด้วย: id, name (ชื่อประเภท), severity (ระดับความรุนแรง)
  static const String createTableViolationType =
      "CREATE TABLE $violationType (id INTEGER PRIMARY KEY, name TEXT, severity TEXT)";

  /// คำสั่งสร้างตาราง incident_report (รายงานเหตุการณ์)
  /// ประกอบด้วย: id (เพิ่มอัตโนมัติ), station_id, violation_type_id, 
  /// reporter_name (ผู้แจ้ง), description (รายละเอียด), photo_path (เส้นทางรูปภาพ),
  /// timestamp (เวลา), evidence_type (ประเภทหลักฐานที่ AI วิเคราะห์), confidence_score (ความเชื่อมั่น)
  static const String createTableIncidentReport =
      "CREATE TABLE $incidentReport (id INTEGER PRIMARY KEY AUTOINCREMENT, station_id INTEGER, violation_type_id INTEGER, reporter_name TEXT, description TEXT, photo_path TEXT, timestamp TEXT, evidence_type TEXT, confidence_score REAL)";

  /// รายการคำสั่ง INSERT สำหรับข้อมูลเริ่มต้น
  /// ประกอบด้วย:
  /// - หน่วยเลือกตั้ง 4 แห่ง (นครศรีธรรมราช)
  /// - ประเภทการทุจริต 5 แบบ (ซื้อเสียง, ขนคน, หาเสียงเกินเวลา, ทำลายป้าย, เจ้าหน้าที่ไม่เป็นกลาง)
  /// - รายงานตัวอย่าง 3 รายการ
  static const List<String> insertInitialData = [
    // ข้อมูลหน่วยเลือกตั้ง (Polling Station)
    "INSERT INTO $pollingStation (id, name, district, province) VALUES (101, 'โรงเรียนวัดพระมหาธาตุ', 'เขต 1', 'นครศรีธรรมราช')",
    "INSERT INTO $pollingStation (id, name, district, province) VALUES (102, 'เต็นท์หน้าตลาดท่าวัง', 'เขต 1', 'นครศรีธรรมราช')",
    "INSERT INTO $pollingStation (id, name, district, province) VALUES (103, 'ศาลากลางหมู่บ้านคีรีวง', 'เขต 2', 'นครศรีธรรมราช')",
    "INSERT INTO $pollingStation (id, name, district, province) VALUES (104, 'หอประชุมอำเภอทุ่งสง', 'เขต 3', 'นครศรีธรรมราช')",

    // ข้อมูลประเภทการทุจริต (Violation Type)
    "INSERT INTO $violationType (id, name, severity) VALUES (1, 'ซื้อสิทธิขายเสียง (Buying Votes)', 'High')",
    "INSERT INTO $violationType (id, name, severity) VALUES (2, 'ขนคนไปลงคะแนน (Transportation)', 'High')",
    "INSERT INTO $violationType (id, name, severity) VALUES (3, 'หาเสียงเกินเวลา (Overtime Campaign)', 'Medium')",
    "INSERT INTO $violationType (id, name, severity) VALUES (4, 'ทำลายป้ายหาเสียง (Vandalism)', 'Low')",
    "INSERT INTO $violationType (id, name, severity) VALUES (5, 'เจ้าหน้าที่วางตัวไม่เป็นกลาง (Bias Official)', 'High')",

    // ข้อมูลรายงานเหตุการณ์ตัวอย่าง (Incident Report)
    "INSERT INTO $incidentReport (id, station_id, violation_type_id, reporter_name, description, photo_path, timestamp, evidence_type, confidence_score) VALUES (1, 101, 1, 'พลเมืองดี 01', 'พบเห็นการแจกเงินบริเวณหน้าหน่วย', NULL, '2026-02-08 09:30:00', 'Money', 0.95)",
    "INSERT INTO $incidentReport (id, station_id, violation_type_id, reporter_name, description, photo_path, timestamp, evidence_type, confidence_score) VALUES (2, 102, 3, 'สมชาย ใจกล้า', 'มีการเปิดรถแห่เสียงดังรบกวน', NULL, '2026-02-08 10:15:00', 'Crowd', 0.75)",
    "INSERT INTO $incidentReport (id, station_id, violation_type_id, reporter_name, description, photo_path, timestamp, evidence_type, confidence_score) VALUES (3, 103, 5, 'Anonymous', 'เจ้าหน้าที่พูดจาชี้นำผู้ลงคะแนน', NULL, '2026-02-08 11:00:00', NULL, 0.0)"
  ];
}
