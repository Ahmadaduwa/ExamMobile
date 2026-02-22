/// หน้าจอสำหรับเพิ่ม/แก้ไข รายงานการแจ้งเหตุ
/// รองรับ Cascading Dropdown จังหวัด → เขต → หน่วยเลือกตั้ง (3 ระดับ)
library;
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:final66113424/helpers/database_helper.dart';

/// Widget หน้าจอเพิ่ม/แก้ไขรายงาน (Stateful)
class AddReportScreen extends StatefulWidget {
  final Map<String, dynamic>? existingReport; // ข้อมูลเดิม (ถ้าเป็นโหมดแก้ไข)

  const AddReportScreen({super.key, this.existingReport});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

/// State สำหรับ AddReportScreen
class _AddReportScreenState extends State<AddReportScreen> {
  // Form key สำหรับการ validate
  final _formKey = GlobalKey<FormState>();
  
  // Controllers สำหรับ TextField
  final _reporterNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // ข้อมูลสำหรับ Cascading Dropdown (3 ระดับ)
  List<String> _provinces = [];                      // รายชื่อจังหวัดทั้งหมด
  List<String> _zones = [];                          // รายชื่อเขตตามจังหวัดที่เลือก
  List<Map<String, dynamic>> _pollingStations = [];  // รายชื่อหน่วยตามจังหวัด+เขตที่เลือก
  List<Map<String, dynamic>> _violationTypes = [];   // ประเภทการทุจริตทั้งหมด
  
  // ค่าที่เลือกจาก Dropdown
  String? _selectedProvince;          // จังหวัดที่เลือก
  String? _selectedZone;              // เขตที่เลือก
  int? _selectedStationId;            // ID หน่วยเลือกตั้งที่เลือก
  int? _selectedViolationTypeId;      // ID ประเภทการทุจริตที่เลือก
  
  // ข้อมูลอื่นๆ
  File? _imageFile;                   // ไฟล์รูปภาพที่เลือก
  bool _isSubmitting = false;         // สถานะกำลังส่งข้อมูล
  bool _isAnonymous = false;          // สถานะไม่ประสงค์ออกนาม

  final ImagePicker _picker = ImagePicker(); // ตัวเลือกรูปภาพ

  @override
  void initState() {
    super.initState();
    _loadData(); // โหลดข้อมูลเบื้องต้น (จังหวัด, ประเภทการทุจริต, prefill ถ้าเป็นโหมดแก้ไข)
  }

  /// ฟังก์ชันโหลดข้อมูลเบื้องต้นจากฐานข้อศูล
  /// - ดึงรายชื่อจังหวัดและประเภทการทุจริต
  /// - Prefill ข้อมูลเดิมถ้าเป็นโหมดแก้ไข (รวมทั้งจังหวัด/เขต/หน่วย cascading)
  Future<void> _loadData() async {
    final provinces = await getDistinctProvinces();        // ดึงจังหวัดทั้งหมด
    final violations = await getViolationTypes();          // ดึงประเภทการทุจริตทั้งหมด

    // ตรวจสอบว่าเป็นโหมดแก้ไขหรือไม่
    final existingReport = widget.existingReport;
    final existingProvince = existingReport?['province']?.toString();
    final existingZone = existingReport?['district']?.toString();
    final stationIdRaw = existingReport?['station_id'];
    final violationTypeIdRaw = existingReport?['violation_type_id'];

    // แปลง ID เป็น int (รองรับทั้ง int และ String)
    final int? stationId = stationIdRaw is int
        ? stationIdRaw
        : int.tryParse(stationIdRaw?.toString() ?? '');
    final int? violationTypeId = violationTypeIdRaw is int
        ? violationTypeIdRaw
        : int.tryParse(violationTypeIdRaw?.toString() ?? '');

    // ถ้าเป็นโหมดแก้ไข ให้ prefill ข้อมูลเดิม
    if (existingReport != null) {
      final existingReporterName = existingReport['reporter_name']?.toString() ?? '';
      _isAnonymous = existingReporterName == 'Anonymous'; // ตรวจสอบว่าเป็น Anonymous หรือไม่
      _reporterNameController.text = existingReporterName;
      _descriptionController.text = existingReport['description']?.toString() ?? '';

      // โหลดรูปภาพเดิม (ถ้ามี)
      final photoPath = existingReport['photo_path']?.toString();
      if (photoPath != null && photoPath.isNotEmpty) {
        final photoFile = File(photoPath);
        if (photoFile.existsSync()) {
          _imageFile = photoFile;
        }
      }
    }

    // ดึงเขตตามจังหวัดที่เลือก (ถ้ามี)
    final zones = (existingProvince != null && existingProvince.isNotEmpty)
        ? await getZonesByProvince(existingProvince)
        : <String>[];

    // ดึงหน่วยเลือกตั้งตามจังหวัด+เขตที่เลือก (ถ้ามี)
    final stations = (existingProvince != null &&
            existingProvince.isNotEmpty &&
            existingZone != null &&
            existingZone.isNotEmpty)
        ? await getPollingStationsByProvinceAndZone(
            province: existingProvince,
            zone: existingZone,
          )
        : <Map<String, dynamic>>[];

    // อัปเดต state ทั้งหมดพร้อมกัน
    setState(() {
      _provinces = provinces;
      _zones = zones;
      _pollingStations = stations;
      _violationTypes = violations;
      _selectedProvince = existingProvince;
      _selectedZone = existingZone;
      _selectedStationId = stationId;
      _selectedViolationTypeId = violationTypeId;
    });
  }

  /// ฟังก์ชันเมื่อเลือกจังหวัด (ชั้นที่ 1 ของ Cascading Dropdown)
  /// จะรีเซ็ตเขตและหน่วยเลือกตั้ง แล้วโหลดเขตใหม่
  Future<void> _onProvinceChanged(String? province) async {
    setState(() {
      _selectedProvince = province;
      _selectedZone = null;            // รีเซ็ตเขต
      _selectedStationId = null;       // รีเซ็ตหน่วย
      _zones = [];                     // ล้าง list เขต
      _pollingStations = [];           // ล้าง list หน่วย
    });

    if (province == null || province.isEmpty) return;

    // โหลดเขตตามจังหวัดที่เลือก
    final zones = await getZonesByProvince(province);
    if (!mounted) return;
    setState(() {
      _zones = zones;
    });
  }

  /// ฟังก์ชันเมื่อเลือกเขต (ชั้นที่ 2 ของ Cascading Dropdown)
  /// จะรีเซ็ตหน่วยเลือกตั้ง แล้วโหลดหน่วยใหม่
  Future<void> _onZoneChanged(String? zone) async {
    setState(() {
      _selectedZone = zone;
      _selectedStationId = null;   // รีเซ็ตหน่วย
      _pollingStations = [];       // ล้าง list หน่วย
    });

    if (zone == null || zone.isEmpty || _selectedProvince == null) return;

    // โหลดหน่วยเลือกตั้งตามจังหวัด+เขตที่เลือก
    final stations = await getPollingStationsByProvinceAndZone(
      province: _selectedProvince!,
      zone: zone,
    );
    if (!mounted) return;
    setState(() {
      _pollingStations = stations;
    });
  }

  /// ฟังก์ชันเลือกรูปภาพจาก Camera หรือ Gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  /// แสดง Bottom Sheet ให้เลือกรูปจาก Gallery หรือ Camera
  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('แกลเลอรี (Gallery)'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('กล้องถ่ายรูป (Camera)'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// ฟังก์ชันส่งข้อมูล (บันทึกลงฐานข้อมูล)
  /// - Validate form
  /// - Mock AI วิเคราะห์รูป (รอ 2 วินาที)
  /// - เรียก insertIncidentReport หรือ updateIncidentReport
  Future<void> _submitData() async {
    if (_isSubmitting) return; // ป้องกัน double submit
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      // แสดง Loading Dialog (แสดงว่า AI กำลังวิเคราะห์)
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('AI กำลังวิเคราะห์รูปภาพ...')),
            ],
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 2)); // รอ AI วิเคราะห์ 2 วินาที

      // Mock AI Result - สุ่มผลสักประเภทและค่า confidence
      final evidenceTypes = ['Money', 'Crowd', 'Poster'];
      final random = Random();
      final aiResult = evidenceTypes[random.nextInt(evidenceTypes.length)];
      final confidence = random.nextDouble();

      // Timestamp - ถ้าเป็นโหมดแก้ไขให้ใช้เดิม ไม่ใช่ให้สร้างใหม่
      final timestamp = widget.existingReport?['timestamp']?.toString() ??
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // สร้าง Map ข้อมูลเพื่อบันทึกลงฐานข้อมูล
      final newReport = {
        'station_id': _selectedStationId,
        'violation_type_id': _selectedViolationTypeId,
        'reporter_name': _isAnonymous
            ? 'Anonymous'
            : _reporterNameController.text.trim(),
        'description': _descriptionController.text,
        'photo_path': _imageFile?.path, // อาจเป็น null ได้
        'timestamp': timestamp,
        'evidence_type': aiResult,      // ผลจาก AI
        'confidence_score': confidence,  // ค่าความเชื่อมั่น
      };

      // เลือกเพิ่มหรือแก้ไข
      if (widget.existingReport == null) {
        await insertIncidentReport(newReport); // เพิ่มใหม่
      } else {
        // แก้ไขข้อมูลเดิม
        final reportIdRaw = widget.existingReport!['id'] ?? widget.existingReport!['report_id'];
        final int? reportId = reportIdRaw is int
            ? reportIdRaw
            : int.tryParse(reportIdRaw?.toString() ?? '');
        if (reportId != null) {
          await updateIncidentReport(reportId, newReport); // อัปเดต
        }
      }

      // ปิด Loading Dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingReport == null ? 'บันทึกสำเร็จ' : 'แก้ไขข้อมูลสำเร็จ'),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        Navigator.pop(context); // กลับไปหน้าก่อน
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingReport == null ? 'แจ้งเหตุทุจริต' : 'แก้ไขข้อมูลแจ้งเหตุ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dropdown จังหวัด (ชั้นที่ 1)
              DropdownButtonFormField<String>(
                key: ValueKey('province_${_selectedProvince ?? ''}'),
                decoration: const InputDecoration(labelText: 'จังหวัด'),
                initialValue: _selectedProvince,
                items: _provinces
                    .map(
                      (province) => DropdownMenuItem<String>(
                        value: province,
                        child: Text(province),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  _onProvinceChanged(value);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณาเลือกจังหวัด';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dropdown เขตเลือกตั้ง (ชั้นที่ 2) - ขึ้นกับจังหวัด
              DropdownButtonFormField<String>(
                key: ValueKey('zone_${_selectedProvince ?? ''}_${_selectedZone ?? ''}'),
                decoration: const InputDecoration(labelText: 'เขตเลือกตั้ง'),
                initialValue: _selectedZone,
                items: _zones
                    .map(
                      (zone) => DropdownMenuItem<String>(
                        value: zone,
                        child: Text(zone),
                      ),
                    )
                    .toList(),
                onChanged: (_selectedProvince == null || _selectedProvince!.isEmpty)
                    ? null
                    : (value) {
                        _onZoneChanged(value);
                      },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณาเลือกเขต';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dropdown หน่วยเลือกตั้ง (ชั้นที่ 3) - ขึ้นกับเขต
              DropdownButtonFormField<int>(
                key: ValueKey('station_${_selectedZone ?? ''}_${_selectedStationId ?? ''}'),
                decoration: const InputDecoration(labelText: 'หน่วยเลือกตั้ง'),
                initialValue: _selectedStationId,
                items: _pollingStations.map((station) {
                  final stationName = station['name']?.toString() ?? '-';
                  final stationZone = station['district']?.toString() ?? '-';
                  return DropdownMenuItem<int>(
                    value: station['id'] as int,
                    child: Text('$stationName ($stationZone)'),
                  );
                }).toList(),
                onChanged: (_selectedZone == null || _selectedZone!.isEmpty)
                    ? null
                    : (value) {
                        setState(() {
                          _selectedStationId = value;
                        });
                      },
                validator: (value) {
                  if (value == null) {
                    return 'กรุณาเลือกหน่วยเลือกตั้ง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dropdown ประเภทการทุจริต
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'ประเภทการทุจริต'),
                initialValue: _selectedViolationTypeId,
                items: _violationTypes.map((type) {
                  return DropdownMenuItem<int>(
                    value: type['id'] as int,
                    child: Text(type['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedViolationTypeId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'กรุณาเลือกประเภทการทุจริต';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Switch ไม่ประสงค์ออกนาม (Anonymous)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ไม่ประสงค์ออกนาม'),
                value: _isAnonymous,
                onChanged: (value) {
                  setState(() {
                    _isAnonymous = value;
                    if (_isAnonymous) {
                      _reporterNameController.text = 'Anonymous';
                    } else if (_reporterNameController.text == 'Anonymous') {
                      _reporterNameController.clear();
                    }
                  });
                },
              ),

              const SizedBox(height: 8),

              // TextField ชื่อผู้แจ้ง (ปิดถ้าเป็น Anonymous)
              TextFormField(
                controller: _reporterNameController,
                enabled: !_isAnonymous,
                decoration: const InputDecoration(labelText: 'ชื่อผู้แจ้ง'),
                validator: (value) {
                  if (_isAnonymous) {
                    return null;
                  }
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกชื่อผู้แจ้ง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // TextField รายละเอียด (multiline)
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'รายละเอียด'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกรายละเอียด';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // แสดงรูปภาพที่เลือก (ถ้ามี)
              if (_imageFile != null)
                Image.file(
                  _imageFile!,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              const SizedBox(height: 8),
              // ปุ่มเพิ่มรูปหลักฐาน (Camera/Gallery)
              ElevatedButton.icon(
                onPressed: () => _showPicker(context),
                icon: const Icon(Icons.camera_alt),
                label: const Text('เพิ่มรูปหลักฐาน'),
              ),
              const SizedBox(height: 20),

              // ปุ่มบันทึก/อัปเดต
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitData,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  widget.existingReport == null ? 'บันทึก' : 'อัปเดต',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}