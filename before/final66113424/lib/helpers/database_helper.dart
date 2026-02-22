/// ไฟล์ Helper สำหรับจัดการฐานข้อมูล SQLite
/// รวมฟังก์ชันทุกอย่างที่เกี่ยวข้องกับ Database Operations
library;
import 'package:final66113424/main.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:final66113424/constants/sql_commands.dart';

/// คลาส DatabaseHelper - รวมเมธอดสำหรับจัดการข้อมูล
class DatabaseHelper {
  /// ลบรายงานเหตุการณ์ตาม report ID
  /// คืนค่า true หากลบสำเร็จ, false หากไม่เจอข้อมูลหรือลบไม่สำเร็จ
  static Future<bool> deleteReport(int reportId) async {
    final db = await database;
    final deletedRows = await db.delete(
      SqlCommands.incidentReport,
      where: 'id = ?',
      whereArgs: [reportId],
    );
    return deletedRows > 0;
  }
}

/// ฟังก์ชันสำหรับดึง Path ของไฟล์ฐานข้อมูล
Future<String> getDatabaseFilePath() async {
  return join(await getDatabasesPath(), 'final66113424.db');
}

/// ฟังก์ชันเริ่มต้นฐานข้อมูล (เรียกครั้งแรกตอนเปิดแอป)
/// สร้างตารางทั้งหมดและใส่ข้อมูลเริ่มต้น
Future<void> initializeDatabase() async {
  database = openDatabase(
    join(await getDatabasesPath(), 'final66113424.db'),
    onCreate: (db, version) async {
      // สร้างตาราง 3 ตาราง
      await db.execute(SqlCommands.createTablePollingStation);
      await db.execute(SqlCommands.createTableViolationType);
      await db.execute(SqlCommands.createTableIncidentReport);

      // ใส่ข้อมูลเริ่มต้น (หน่วยเลือกตั้ง, ประเภทการทุจริต, รายงานตัวอย่าง)
      for (var sql in SqlCommands.insertInitialData) {
        await db.execute(sql);
      }
    },
    version: 1,
  );
}

/// ดึงรายการรายงานทั้งหมด (พร้อม JOIN ข้อมูลหน่วยและประเภท)
/// เรียงจากใหม่ไปเก่าตาม timestamp
Future<List<Map<String, dynamic>>> getIncidentReports() async {
  final db = await database;
  return await db.rawQuery('''
    SELECT 
      incident_report.id AS report_id,
      incident_report.id,
      incident_report.station_id,
      incident_report.violation_type_id,
      incident_report.description,
      incident_report.reporter_name,
      incident_report.timestamp,
      incident_report.photo_path,
      incident_report.evidence_type,
      incident_report.confidence_score,
      polling_station.name AS station_name,
      polling_station.province,
      polling_station.district,
      violation_type.name AS violation_name,
      violation_type.severity
    FROM incident_report
    JOIN polling_station ON incident_report.station_id = polling_station.id
    JOIN violation_type ON incident_report.violation_type_id = violation_type.id
    ORDER BY incident_report.timestamp DESC
  ''');
}

/// ค้นหารายงานจากคำค้น (ค้นจาก description, reporter_name, violation_name)
/// ใช้ LIKE query แบบ partial match (ไม่สนใจตำแหน่งคำค้น)
Future<List<Map<String, dynamic>>> searchIncidentReports(String keyword) async {
  final db = await database;
  final queryKeyword = '%${keyword.trim()}%'; // ใส่ % หน้าหลังเพื่อค้นแบบ partial
  return await db.rawQuery(
    '''
    SELECT 
      incident_report.id AS report_id,
      incident_report.id,
      incident_report.station_id,
      incident_report.violation_type_id,
      incident_report.description,
      incident_report.reporter_name,
      incident_report.timestamp,
      incident_report.photo_path,
      incident_report.evidence_type,
      incident_report.confidence_score,
      polling_station.name AS station_name,
      polling_station.province,
      polling_station.district,
      violation_type.name AS violation_name,
      violation_type.severity
    FROM incident_report
    JOIN polling_station ON incident_report.station_id = polling_station.id
    JOIN violation_type ON incident_report.violation_type_id = violation_type.id
    WHERE incident_report.description LIKE ?
      OR incident_report.reporter_name LIKE ?
      OR violation_type.name LIKE ?
    ORDER BY incident_report.timestamp DESC
  ''',
    [queryKeyword, queryKeyword, queryKeyword], // ส่งค่า parameter 3 ครั้งสำหรับ 3 เงื่อนไข OR
  );
}

/// ดึงรายงานทั้งหมดเพื่อ Export (ใช้สำหรับส่งออกข้อมูล CSV/JSON)
Future<List<Map<String, dynamic>>> getAllIncidentReportsForExport() async {
  final db = await database;
  return await db.rawQuery('''
    SELECT 
      incident_report.id AS report_id,
      incident_report.station_id,
      incident_report.violation_type_id,
      incident_report.reporter_name,
      incident_report.description,
      incident_report.photo_path,
      incident_report.timestamp,
      incident_report.evidence_type,
      incident_report.confidence_score,
      polling_station.name AS station_name,
      polling_station.province,
      polling_station.district AS zone,
      violation_type.name AS violation_name,
      violation_type.severity
    FROM incident_report
    JOIN polling_station ON incident_report.station_id = polling_station.id
    JOIN violation_type ON incident_report.violation_type_id = violation_type.id
    ORDER BY incident_report.timestamp DESC
  ''');
}

/// ดึงรายงานตามเขตเลือกตั้งที่ระบุ
Future<List<Map<String, dynamic>>> getReportsByZone(String targetZone) async {
  final db = await database;
  return await db.rawQuery(
    '''
    SELECT 
      incident_report.id AS report_id,
      incident_report.id,
      incident_report.station_id,
      incident_report.violation_type_id,
      incident_report.description,
      incident_report.reporter_name,
      incident_report.timestamp,
      incident_report.photo_path,
      incident_report.evidence_type,
      incident_report.confidence_score,
      polling_station.name AS station_name,
      polling_station.zone,
      polling_station.province,
      violation_type.name AS violation_name,
      violation_type.severity
    FROM incident_report
    INNER JOIN (
      SELECT id, name, province, district, district AS zone
      FROM polling_station
    ) AS polling_station ON incident_report.station_id = polling_station.id
    INNER JOIN violation_type ON incident_report.violation_type_id = violation_type.id
    WHERE polling_station.zone = ?
    ORDER BY incident_report.timestamp DESC
  ''',
    [targetZone],
  );
}

/// นับจำนวนรายงานทั้งหมด
Future<int> getTotalIncidents() async {
  final db = await database;
  final result = await db.rawQuery('SELECT COUNT(*) AS total FROM incident_report');
  return Sqflite.firstIntValue(result) ?? 0;
}

/// สถิติจำนวนรายงานแยกตามเขต (GROUP BY zone)
Future<List<Map<String, dynamic>>> getIncidentsByZone() async {
  final db = await database;
  return await db.rawQuery('''
    SELECT 
      polling_station.zone,
      COUNT(incident_report.id) AS total
    FROM incident_report
    INNER JOIN (
      SELECT id, district AS zone
      FROM polling_station
    ) AS polling_station ON incident_report.station_id = polling_station.id
    GROUP BY polling_station.zone
    ORDER BY polling_station.zone
  ''');
}

/// ดึงรายชื่อหน่วยเลือกตั้งทั้งหมด
Future<List<Map<String, dynamic>>> getPollingStations() async {
  final db = await database;
  return await db.query(SqlCommands.pollingStation);
}

/// ดึงรายชื่อจังหวัดทั้งหมด (ไม่ซ้ำ) เรียงตามชื่อ
/// ใช้สำหรับ Dropdown จังหวัด (ชั้นที่ 1 ของ Cascading Dropdown)
Future<List<String>> getDistinctProvinces() async {
  final db = await database;
  final rows = await db.rawQuery('''
    SELECT DISTINCT province
    FROM polling_station
    WHERE province IS NOT NULL AND province != ''
    ORDER BY province
  ''');
  return rows.map((row) => row['province'].toString()).toList();
}

/// ดึงรายชื่อเขตตามจังหวัดที่เลือก (ไม่ซ้ำ) เรียงตามชื่อ
/// ใช้สำหรับ Dropdown เขต (ชั้นที่ 2 ของ Cascading Dropdown)
Future<List<String>> getZonesByProvince(String province) async {
  final db = await database;
  final rows = await db.rawQuery(
    '''
    SELECT DISTINCT district AS zone
    FROM polling_station
    WHERE province = ? AND district IS NOT NULL AND district != ''
    ORDER BY zone
  ''',
    [province],
  );
  return rows.map((row) => row['zone'].toString()).toList();
}

/// ดึงหน่วยเลือกตั้งตามจังหวัดและเขตที่เลือก เรียงตามชื่อ
/// ใช้สำหรับ Dropdown หน่วยเลือกตั้ง (ชั้นที่ 3 ของ Cascading Dropdown)
Future<List<Map<String, dynamic>>> getPollingStationsByProvinceAndZone({
  required String province,
  required String zone,
}) async {
  final db = await database;
  return await db.query(
    SqlCommands.pollingStation,
    where: 'province = ? AND district = ?',
    whereArgs: [province, zone],
    orderBy: 'name ASC',
  );
}

/// สถิติจำนวนรายงานแยกตามระดับความรุนแรง (GROUP BY severity)
/// ใช้สำหรับแสดงผลในกราฟหรือสรุปข้อมูล
Future<List<Map<String, dynamic>>> getIncidentsBySeverity() async {
  final db = await database;
  return await db.rawQuery('''
    SELECT
      violation_type.severity,
      COUNT(incident_report.id) AS total
    FROM incident_report
    JOIN violation_type ON incident_report.violation_type_id = violation_type.id
    GROUP BY violation_type.severity
  ''');
}

/// ดึงรายการประเภทการทุจริตทั้งหมด
Future<List<Map<String, dynamic>>> getViolationTypes() async {
  final db = await database;
  return await db.query(SqlCommands.violationType);
}

/// เพิ่มรายงานใหม่ลงฐานข้อมูล
/// หาก id ซ้ำจะ replace ทับ (แต่จริงๆ ใช้ auto increment)
Future<void> insertIncidentReport(Map<String, dynamic> reportData) async {
  final db = await database;
  await db.insert(
    SqlCommands.incidentReport,
    reportData,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

/// อัปเดตรายงานที่มีอยู่แล้วตาม report ID
Future<void> updateIncidentReport(int reportId, Map<String, dynamic> reportData) async {
  final db = await database;
  await db.update(
    SqlCommands.incidentReport,
    reportData,
    where: 'id = ?',
    whereArgs: [reportId],
  );
}