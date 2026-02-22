// ไฟล์ตัวช่วยสำหรับจัดการฐานข้อมูล
// รวมฟังก์ชันทั้งหมดที่เกี่ยวข้องกับการทำงานฐานข้อมูล
import 'package:final66113424/main.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:final66113424/constants/sql_commands.dart';

/// คลาสตัวช่วยรวมเมธอดสำหรับจัดการข้อมูล
class DatabaseHelper {
  /// ลบรายงานเหตุการณ์ตามรหัสรายงาน
  /// คืนค่าเป็นจริงหากลบสำเร็จ หรือเป็นเท็จหากไม่พบข้อมูลหรือลบไม่สำเร็จ
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

/// ฟังก์ชันสำหรับดึงตำแหน่งไฟล์ฐานข้อมูล
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

/// ดึงรายการรายงานทั้งหมด (เชื่อมข้อมูลหน่วยและประเภท)
/// เรียงจากใหม่ไปเก่าตามเวลา
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

/// ค้นหารายงานจากคำค้น (ค้นจากรายละเอียด ชื่อผู้แจ้ง และชื่อประเภท)
/// ใช้คำสั่งค้นหาแบบบางส่วน (ไม่สนใจตำแหน่งคำค้น)
Future<List<Map<String, dynamic>>> searchIncidentReports(String keyword) async {
  final db = await database;
  final queryKeyword = '%${keyword.trim()}%'; // ใส่ % หน้าและหลังเพื่อค้นหาแบบบางส่วน
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
    [queryKeyword, queryKeyword, queryKeyword], // ส่งค่า 3 ครั้งสำหรับ 3 เงื่อนไข
  );
}

/// ค้นหารายงานแบบละเอียด
/// รองรับการกรองด้วยคำค้น ระดับความรุนแรง จังหวัด และประเภทการทุจริต
Future<List<Map<String, dynamic>>> filterIncidents({
  String? keyword,
  String? severity,
  String? province,
  String? violationType,
}) async {
  final db = await database;
  
  // คำสั่งค้นหาพื้นฐาน
  String sql = '''
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
    WHERE 1=1
  ''';

  List<dynamic> args = [];

  // 1) กรองด้วยคำค้น (รายละเอียด ชื่อผู้แจ้ง ชื่อประเภท)
  if (keyword != null && keyword.isNotEmpty) {
    sql += ' AND (incident_report.description LIKE ? OR incident_report.reporter_name LIKE ? OR violation_type.name LIKE ?)';
    final kw = '%$keyword%';
    args.addAll([kw, kw, kw]);
  }

  // 2) กรองด้วยระดับความรุนแรง
  if (severity != null && severity.isNotEmpty && severity != 'ทั้งหมด') {
    sql += ' AND violation_type.severity = ?';
    args.add(severity);
  }

  // 3) กรองด้วยจังหวัด
  if (province != null && province.isNotEmpty && province != 'ทั้งหมด') {
    sql += ' AND polling_station.province = ?';
    args.add(province);
  }

  // 4) กรองด้วยประเภทการทุจริต
  if (violationType != null && violationType.isNotEmpty && violationType != 'ทั้งหมด') {
    sql += ' AND violation_type.name = ?';
    args.add(violationType);
  }

  // จัดลำดับผลลัพธ์
  sql += ' ORDER BY incident_report.timestamp DESC';

  return await db.rawQuery(sql, args);
}

/// ค้นหาและกรองรายงานสำหรับหน้าค้นหาและคัดกรอง
/// รองรับค้นหาแบบบางส่วนจากชื่อผู้แจ้งและรายละเอียด
/// และกรองระดับความรุนแรงผ่านการเชื่อมตารางประเภทการทุจริต
Future<List<Map<String, dynamic>>> searchAndFilterIncidents({
  String keyword = '',
  String? severity,
}) async {
  final db = await database;
  final trimmedKeyword = keyword.trim();

  String sql = '''
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
    WHERE 1=1
  ''';

  final List<dynamic> args = [];

  if (trimmedKeyword.isNotEmpty) {
    sql += '''
      AND (
        incident_report.reporter_name LIKE ?
        OR incident_report.description LIKE ?
      )
    ''';
    final likeKeyword = '%$trimmedKeyword%';
    args.addAll([likeKeyword, likeKeyword]);
  }

  if (severity != null && severity.isNotEmpty && severity != 'ทั้งหมด') {
    sql += ' AND violation_type.severity = ?';
    args.add(severity);
  }

  sql += ' ORDER BY incident_report.timestamp DESC';

  return await db.rawQuery(sql, args);
}

/// ดึงรายงานทั้งหมดเพื่อส่งออกข้อมูล
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

/// สถิติจำนวนรายงานแยกตามเขต (จัดกลุ่มตามเขต)
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

/// ดึงรายการหน่วยเลือกตั้ง 3 อันดับแรกที่มีการร้องเรียนมากที่สุด
Future<List<Map<String, dynamic>>> getTop3ComplainedPollingStations() async {
  final db = await database;
  return await db.rawQuery('''
    SELECT 
      polling_station.name AS station_name,
      COUNT(incident_report.id) AS total_complaints
    FROM incident_report
    JOIN polling_station ON incident_report.station_id = polling_station.id
    GROUP BY polling_station.id
    ORDER BY total_complaints DESC
    LIMIT 3
  ''');
}

/// ดึงรายชื่อหน่วยเลือกตั้งทั้งหมด
Future<List<Map<String, dynamic>>> getPollingStations() async {
  final db = await database;
  return await db.query(SqlCommands.pollingStation);
}

/// ดึงรายชื่อจังหวัดทั้งหมด (ไม่ซ้ำ) เรียงตามชื่อ
/// ใช้สำหรับเมนูเลือกจังหวัด (ชั้นที่ 1 ของเมนูเลือกต่อเนื่อง)
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
/// ใช้สำหรับเมนูเลือกเขต (ชั้นที่ 2 ของเมนูเลือกต่อเนื่อง)
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
/// ใช้สำหรับเมนูเลือกหน่วยเลือกตั้ง (ชั้นที่ 3 ของเมนูเลือกต่อเนื่อง)
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

/// สถิติจำนวนรายงานแยกตามระดับความรุนแรง (จัดกลุ่มตามระดับ)
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
/// หากรหัสซ้ำจะเขียนทับ (แต่โดยปกติใช้รหัสเพิ่มอัตโนมัติ)
Future<void> insertIncidentReport(Map<String, dynamic> reportData) async {
  final db = await database;
  await db.insert(
    SqlCommands.incidentReport,
    reportData,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

/// อัปเดตรายงานที่มีอยู่แล้วตามรหัสรายงาน
Future<void> updateIncidentReport(int reportId, Map<String, dynamic> reportData) async {
  final db = await database;
  await db.update(
    SqlCommands.incidentReport,
    reportData,
    where: 'id = ?',
    whereArgs: [reportId],
  );
}

/// อัปเดตข้อมูลหน่วยเลือกตั้งตามรหัสหน่วย
Future<void> updatePollingStation(int stationId, Map<String, dynamic> stationData) async {
  final db = await database;
  await db.update(
    SqlCommands.pollingStation,
    stationData,
    where: 'id = ?',
    whereArgs: [stationId],
  );
}

/// เพิ่มข้อมูลหน่วยเลือกตั้งใหม่
Future<void> insertPollingStation(Map<String, dynamic> stationData) async {
  final db = await database;
  await db.insert(
    SqlCommands.pollingStation,
    stationData,
    conflictAlgorithm: ConflictAlgorithm.abort,
  );
}

/// ตรวจสอบว่าชื่อหน่วยเลือกตั้งซ้ำกับรายการอื่นหรือไม่ (ไม่นับรหัสหน่วยของตัวเอง)
Future<bool> isDuplicatePollingStationName({
  required String stationName,
  required int excludingStationId,
}) async {
  final db = await database;
  final result = await db.rawQuery(
    '''
    SELECT COUNT(*) AS total
    FROM polling_station
    WHERE LOWER(TRIM(name)) = LOWER(TRIM(?))
      AND id != ?
  ''',
    [stationName, excludingStationId],
  );

  final total = Sqflite.firstIntValue(result) ?? 0;
  return total > 0;
}

/// นับจำนวนเรื่องร้องเรียนของหน่วยเลือกตั้งตามรหัสหน่วย
Future<int> countIncidentsByStationId(int stationId) async {
  final db = await database;
  final result = await db.rawQuery(
    '''
    SELECT COUNT(*) AS total
    FROM incident_report
    WHERE station_id = ?
  ''',
    [stationId],
  );

  return Sqflite.firstIntValue(result) ?? 0;
}

/// รีเซ็ตฐานข้อมูล: ลบข้อมูลทั้งหมดและลงข้อมูลตั้งต้นใหม่
Future<void> resetDatabase() async {
  final db = await database;

  await db.transaction((txn) async {
    await txn.delete(SqlCommands.incidentReport);
    await txn.delete(SqlCommands.violationType);
    await txn.delete(SqlCommands.pollingStation);

    for (final sql in SqlCommands.insertInitialData) {
      await txn.execute(sql);
    }
  });
}