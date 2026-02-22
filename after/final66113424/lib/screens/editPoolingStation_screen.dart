import 'package:final66113424/helpers/database_helper.dart';
import 'package:flutter/material.dart';

/// หน้าจอแสดงรายการหน่วยเลือกตั้ง เพื่อเลือกแก้ไขหรือเพิ่มใหม่
class EditPoolingStationScreen extends StatefulWidget {
  const EditPoolingStationScreen({super.key});

  @override
  State<EditPoolingStationScreen> createState() =>
      _EditPoolingStationScreenState();
}

class _EditPoolingStationScreenState extends State<EditPoolingStationScreen> {
  /// รายการหน่วยเลือกตั้งทั้งหมดจากฐานข้อมูล
  List<Map<String, dynamic>> _stations = [];

  /// สถานะโหลดข้อมูลรายการ
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  /// โหลดรายการหน่วยเลือกตั้งใหม่จากฐานข้อมูล
  Future<void> _loadStations() async {
    setState(() => _isLoading = true);
    final stations = await getPollingStations();
    setState(() {
      _stations = stations;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เลือกหน่วยเลือกตั้งที่ต้องการแก้ไข')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const StationFormScreen(),
            ),
          );
          if (added == true) {
            _loadStations();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มหน่วยเลือกตั้ง'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _stations.length,
              itemBuilder: (context, index) {
                final station = _stations[index];
                return ListTile(
                  title: Text(station['name']),
                  subtitle: Text(
                      '${station['district']} - ${station['province']}'),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StationFormScreen(station: station),
                      ),
                    );
                    _loadStations(); // Refresh list after edit
                  },
                );
              },
            ),
    );
  }
}

class StationFormScreen extends StatefulWidget {
  /// ข้อมูลหน่วยเดิม (ถ้ามี = โหมดแก้ไข, ถ้าไม่มี = โหมดเพิ่มใหม่)
  final Map<String, dynamic>? station;

  const StationFormScreen({super.key, this.station});

  @override
  State<StationFormScreen> createState() => _StationFormScreenState();
}

class _StationFormScreenState extends State<StationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  /// คำนำหน้าชื่อหน่วยที่อนุญาต
  static const List<String> _allowedStationPrefixes = [
    'โรงเรียน',
    'วัด',
    'เต็นท์',
    'ศาลา',
    'หอประชุม',
  ];
  late TextEditingController _nameController;
  late TextEditingController _districtController;
  late TextEditingController _provinceController;
  /// สถานะกำลังบันทึก ป้องกันการกดซ้ำ
  bool _isSaving = false;

  /// จริง = โหมดแก้ไข, เท็จ = โหมดเพิ่มหน่วยใหม่
  bool get _isEditMode => widget.station != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.station?['name'] ?? '');
    _districtController =
      TextEditingController(text: widget.station?['district'] ?? '');
    _provinceController =
      TextEditingController(text: widget.station?['province'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _districtController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  /// ตรวจว่าชื่อหน่วยขึ้นต้นด้วยคำนำหน้าที่กำหนดหรือไม่
  bool _hasValidStationPrefix(String stationName) {
    final normalizedName = stationName.trimLeft();
    return _allowedStationPrefixes.any(normalizedName.startsWith);
  }

  /// แสดงข้อความเตือนกรณีบันทึกไม่ได้
  void _showWarningMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// บันทึกข้อมูลหน่วยเลือกตั้ง (รองรับทั้งเพิ่มและแก้ไข)
  /// ลำดับตรวจสอบ: ตรวจฟอร์ม -> ตรวจคำนำหน้า -> ตรวจชื่อซ้ำ -> (โหมดแก้ไข) ตรวจจำนวนร้องเรียน -> บันทึก
  Future<void> _saveStation() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    final stationId = _isEditMode ? widget.station!['id'] as int : -1;
    final stationName = _nameController.text.trim();
    final district = _districtController.text.trim();
    final province = _provinceController.text.trim();

    if (!_hasValidStationPrefix(stationName)) {
      _showWarningMessage(
        'บันทึกไม่ได้: รูปแบบชื่อหน่วยไม่ถูกต้อง (ต้องขึ้นต้นด้วย โรงเรียน, วัด, เต็นท์, ศาลา หรือ หอประชุม)',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isDuplicateName = await isDuplicatePollingStationName(
        stationName: stationName,
        excludingStationId: stationId,
      );
      if (isDuplicateName) {
        _showWarningMessage('บันทึกไม่ได้: ชื่อหน่วยเลือกตั้งซ้ำกับหน่วยอื่น');
        return;
      }

      final incidentCount = await countIncidentsByStationId(stationId);
      if (_isEditMode && incidentCount > 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ยืนยันการแก้ไขข้อมูล'),
            content: Text(
              'หน่วยนี้มีประวัติร้องเรียน $incidentCount เรื่อง ยืนยันการแก้ไขข้อมูลหรือไม่?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ยืนยัน'),
              ),
            ],
          ),
        );

        if (confirmed != true) {
          return;
        }
      }

      final stationData = {
        'name': stationName,
        'district': district,
        'province': province,
      };

      if (_isEditMode) {
        await updatePollingStation(stationId, stationData);
      } else {
        await insertPollingStation(stationData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'บันทึกข้อมูลเรียบร้อย' : 'เพิ่มหน่วยเลือกตั้งเรียบร้อย'),
        ),
      );
      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'แก้ไขข้อมูลหน่วยเลือกตั้ง' : 'เพิ่มหน่วยเลือกตั้ง'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'ชื่อหน่วยเลือกตั้ง'),
                  validator: (value) =>
                      value!.isEmpty ? 'กรุณากรอกชื่อหน่วยเลือกตั้ง' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _districtController,
                  decoration: const InputDecoration(labelText: 'เขตเลือกตั้ง'),
                  validator: (value) =>
                      value!.isEmpty ? 'กรุณากรอกเขตเลือกตั้ง' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _provinceController,
                  decoration: const InputDecoration(labelText: 'จังหวัด'),
                  validator: (value) =>
                      value!.isEmpty ? 'กรุณากรอกจังหวัด' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveStation,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditMode ? 'บันทึกการแก้ไข' : 'บันทึกหน่วยเลือกตั้งใหม่'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
