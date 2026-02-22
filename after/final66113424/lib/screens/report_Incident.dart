/// หน้าจอสำหรับเพิ่ม/แก้ไข รายงานการแจ้งเหตุ
/// รองรับเมนูเลือกต่อเนื่อง จังหวัด → เขต → หน่วยเลือกตั้ง (3 ระดับ)
library;
import 'dart:io';

import 'package:final66113424/helpers/classifier.dart';
import 'package:final66113424/helpers/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// วิดเจ็ตหน้าจอเพิ่ม/แก้ไขรายงาน
class ReportIncidentScreen extends StatefulWidget {
  final Map<String, dynamic>? existingReport; // ข้อมูลเดิม (ถ้าเป็นโหมดแก้ไข)

  const ReportIncidentScreen({super.key, this.existingReport});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

/// สถานะสำหรับหน้าจอเพิ่ม/แก้ไขรายงาน
class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  // คีย์ของฟอร์มสำหรับการตรวจสอบข้อมูล
  final _formKey = GlobalKey<FormState>();

  // ตัวควบคุมข้อความสำหรับช่องกรอก
  final _reporterNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // ข้อมูลสำหรับเมนูเลือกต่อเนื่อง (3 ระดับ)
  List<String> _provinces = []; // รายชื่อจังหวัดทั้งหมด
  List<String> _zones = []; // รายชื่อเขตตามจังหวัดที่เลือก
  List<Map<String, dynamic>> _pollingStations =
      []; // รายชื่อหน่วยตามจังหวัด+เขตที่เลือก
  List<Map<String, dynamic>> _violationTypes = []; // ประเภทการทุจริตทั้งหมด

  // ค่าที่เลือกจากเมนู
  String? _selectedProvince; // จังหวัดที่เลือก
  String? _selectedZone; // เขตที่เลือก
  int? _selectedStationId; // รหัสหน่วยเลือกตั้งที่เลือก
  int? _selectedViolationTypeId; // รหัสประเภทการทุจริตที่เลือก

  // ข้อมูลอื่นๆ
  File? _imageFile; // ไฟล์รูปภาพที่เลือก
  bool _isSubmitting = false; // สถานะกำลังส่งข้อมูล
  bool _isAnonymous = false; // สถานะไม่ประสงค์ออกนาม
  String? _aiLabel; // ผลลัพธ์จากปัญญาประดิษฐ์ (ป้ายชื่อ)
  double? _aiConfidence; // ผลลัพธ์จากปัญญาประดิษฐ์ (ค่าความมั่นใจ)

  final ImagePicker _picker = ImagePicker(); // ตัวเลือกรูปภาพ
  final Classifier _classifier = Classifier(); // ตัววิเคราะห์ภาพ

  @override
  void initState() {
    super.initState();
    _loadData(); // โหลดข้อมูลเบื้องต้น (จังหวัด, ประเภทการทุจริต, prefill ถ้าเป็นโหมดแก้ไข)
  }

  /// ฟังก์ชันโหลดข้อมูลเบื้องต้นจากฐานข้อศูล
  /// - ดึงรายชื่อจังหวัดและประเภทการทุจริต
  /// - เติมข้อมูลเดิมถ้าเป็นโหมดแก้ไข (รวมทั้งจังหวัด/เขต/หน่วยแบบต่อเนื่อง)
  Future<void> _loadData() async {
    final provinces = await getDistinctProvinces(); // ดึงจังหวัดทั้งหมด
    final violations = await getViolationTypes(); // ดึงประเภทการทุจริตทั้งหมด

    // ตรวจสอบว่าเป็นโหมดแก้ไขหรือไม่
    final existingReport = widget.existingReport;
    final existingProvince = existingReport?['province']?.toString();
    final existingZone = existingReport?['district']?.toString();
    final stationIdRaw = existingReport?['station_id'];
    final violationTypeIdRaw = existingReport?['violation_type_id'];

    // แปลงรหัสเป็นจำนวนเต็ม (รองรับทั้งจำนวนเต็มและข้อความ)
    final int? stationId = stationIdRaw is int
        ? stationIdRaw
        : int.tryParse(stationIdRaw?.toString() ?? '');
    final int? violationTypeId = violationTypeIdRaw is int
        ? violationTypeIdRaw
        : int.tryParse(violationTypeIdRaw?.toString() ?? '');

    // ถ้าเป็นโหมดแก้ไข ให้เติมข้อมูลเดิม
    if (existingReport != null) {
      final existingReporterName =
          existingReport['reporter_name']?.toString() ?? '';
      _isAnonymous =
          existingReporterName == 'Anonymous'; // ตรวจสอบว่าเป็นโหมดไม่ประสงค์ออกนามหรือไม่
      _reporterNameController.text = existingReporterName;
      _descriptionController.text =
          existingReport['description']?.toString() ?? '';

      // โหลดรูปภาพเดิม (ถ้ามี)
      final photoPath = existingReport['photo_path']?.toString();
      if (photoPath != null && photoPath.isNotEmpty) {
        final photoFile = File(photoPath);
        if (photoFile.existsSync()) {
          _imageFile = photoFile;
        }
      }
      
      // โหลดผลวิเคราะห์เดิมถ้ามี
       _aiLabel = existingReport['evidence_type']?.toString();
       _aiConfidence = existingReport['confidence_score'] is num 
          ? (existingReport['confidence_score'] as num).toDouble() 
          : null;
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

    // อัปเดตค่าสถานะทั้งหมดพร้อมกัน
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

  /// ฟังก์ชันเมื่อเลือกจังหวัด (ชั้นที่ 1 ของเมนูเลือกต่อเนื่อง)
  /// จะรีเซ็ตเขตและหน่วยเลือกตั้ง แล้วโหลดเขตใหม่
  Future<void> _onProvinceChanged(String? province) async {
    setState(() {
      _selectedProvince = province;
      _selectedZone = null; // รีเซ็ตเขต
      _selectedStationId = null; // รีเซ็ตหน่วย
      _zones = []; // ล้างรายการเขต
      _pollingStations = []; // ล้างรายการหน่วย
    });

    if (province == null || province.isEmpty) return;

    // โหลดเขตตามจังหวัดที่เลือก
    final zones = await getZonesByProvince(province);
    if (!mounted) return;
    setState(() {
      _zones = zones;
    });
  }

  /// ฟังก์ชันเมื่อเลือกเขต (ชั้นที่ 2 ของเมนูเลือกต่อเนื่อง)
  /// จะรีเซ็ตหน่วยเลือกตั้ง แล้วโหลดหน่วยใหม่
  Future<void> _onZoneChanged(String? zone) async {
    setState(() {
      _selectedZone = zone;
      _selectedStationId = null; // รีเซ็ตหน่วย
      _pollingStations = []; // ล้างรายการหน่วย
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

  /// ฟังก์ชันเลือกรูปภาพจากกล้องหรือแกลเลอรี
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final file = File(image.path);
        setState(() {
          _imageFile = file;
          _aiLabel = null; // ล้างผลวิเคราะห์เดิมเมื่อเลือกรูปใหม่
          _aiConfidence = null;
        });
        
        // วิเคราะห์รูปด้วยปัญญาประดิษฐ์อัตโนมัติ
        _processImage(file);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _processImage(File image) async {
    // แสดงหน้าต่างระหว่างวิเคราะห์ภาพ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI กำลังวิเคราะห์...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      // เริ่มวิเคราะห์ภาพ
      final results = await _classifier.classifyImage(image);
     
      Navigator.pop(context); // ปิดหน้าต่างรอวิเคราะห์

      if (results.isNotEmpty) {
        final topResult = results.first;
        final String label = topResult['label'].toString();
        // ใช้หมวดหมู่จากตัววิเคราะห์ถ้ามี
        final String? category = topResult['category']; 
        final double confidence = topResult['confidence'];

        setState(() {
          _aiLabel = label;
          _aiConfidence = confidence;
        });

        int? newViolationId;
        
        // ลำดับความสำคัญที่ 1: ใช้หมวดหมู่จากตัววิเคราะห์
        if (category != null && category != 'ไม่ระบุ') {
           if (category == 'ซื้อสิทธิขายเสียง') {
             newViolationId = 1; // ซื้อสิทธิขายเสียง
           } else if (category == 'ขนคนไปลงคะแนน') {
             newViolationId = 2; // ขนคนไปลงคะแนน
           } else if (category == 'แจกสิ่งของ') {
             // จัดเป็นรหัส 1 เพื่อให้ใกล้กับประเภทที่มีอยู่มากที่สุด
             // แม้จะพิจารณารหัส 3 ได้ในบางบริบท แต่เลือกแบบง่ายเพื่อความสอดคล้อง
             newViolationId = 1; 
           }
        } 
        
        // ลำดับความสำคัญที่ 2: ถ้าไม่มีหมวดหมู่ ให้จับจากคำสำคัญ
        if (newViolationId == null) {
            final lowerLabel = label.toLowerCase();
            if (lowerLabel.contains('wallet') || lowerLabel.contains('purse') || lowerLabel.contains('envelope')) {
              newViolationId = 1;
            } else if (lowerLabel.contains('minibus') || lowerLabel.contains('cab')) {
              newViolationId = 2;
            } else if (lowerLabel.contains('water bottle') || lowerLabel.contains('cup')) {
               newViolationId = 1; // จัดกลุ่มเดียวกับการให้สิ่งของหรือซื้อเสียง
            }
        }

        if (newViolationId != null) {
           setState(() {
             _selectedViolationTypeId = newViolationId;
           });
           
           String msg = 'AI ตรวจพบ "$label"';
           if (category != null && category != 'ไม่ระบุ') {
             msg += ' ($category)';
           }
           msg += ' -> เลือกประเภทความผิดให้อัตโนมัติ';
           
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(msg)),
           );
        }
      }
    } catch (e) {
      if(mounted && Navigator.canPop(context)) Navigator.pop(context); // ปิดหน้าต่างรอวิเคราะห์เมื่อเกิดข้อผิดพลาด
      debugPrint('AI Error: $e');
    }
  }

  /// แสดงแผงล่างให้เลือกรูปจากแกลเลอรีหรือกล้อง
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
  /// - ตรวจสอบข้อมูลในฟอร์ม
  /// - จำลองการวิเคราะห์ภาพด้วยปัญญาประดิษฐ์ (รอ 2 วินาที)
  /// - เรียกฟังก์ชันเพิ่มหรือแก้ไขรายงาน
  Future<void> _submitData() async {
    if (_isSubmitting) return; // ป้องกันการส่งซ้ำ
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });
      
      // เวลาบันทึก - ถ้าเป็นโหมดแก้ไขให้ใช้ค่าเดิม ไม่ต้องสร้างใหม่
      final timestamp = widget.existingReport?['timestamp']?.toString() ??
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // สร้างข้อมูลแบบแผนที่เพื่อบันทึกลงฐานข้อมูล
      final newReport = {
        'station_id': _selectedStationId,
        'violation_type_id': _selectedViolationTypeId,
        'reporter_name': _isAnonymous
            ? 'Anonymous'
            : _reporterNameController.text.trim(),
        'description': _descriptionController.text,
        'photo_path': _imageFile?.path, // อาจว่างได้
        'timestamp': timestamp,
        'evidence_type': _aiLabel,      // ผลจากปัญญาประดิษฐ์
        'confidence_score': _aiConfidence ?? 0.0,  // ค่าความเชื่อมั่น
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
              // เมนูเลือกจังหวัด (ชั้นที่ 1)
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

              // เมนูเลือกเขตเลือกตั้ง (ชั้นที่ 2) - ขึ้นกับจังหวัด
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

              // เมนูเลือกหน่วยเลือกตั้ง (ชั้นที่ 3) - ขึ้นกับเขต
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

              // เมนูเลือกประเภทการทุจริต
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

              // สวิตช์ไม่ประสงค์ออกนาม
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

              // ช่องกรอกชื่อผู้แจ้ง (ปิดเมื่อไม่ประสงค์ออกนาม)
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

              // ช่องกรอกรายละเอียด (หลายบรรทัด)
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
              // ปุ่มเพิ่มรูปหลักฐาน (กล้อง/แกลเลอรี)
              ElevatedButton.icon(
                onPressed: () => _showPicker(context),
                icon: const Icon(Icons.camera_alt),
                label: const Text('เพิ่มรูปหลักฐาน'),
              ),
              const SizedBox(height: 20),

              // ปุ่มบันทึก/อัปเดต
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitData,
                child: Text(widget.existingReport == null ? 'บันทึก' : 'อัปเดต'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}