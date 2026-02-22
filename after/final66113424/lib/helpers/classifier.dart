/// ไฟล์ตัวช่วยสำหรับประมวลผลภาพด้วย TensorFlow Lite
/// ใช้โมเดล MobileNetV2 เพื่อช่วยวิเคราะห์หลักฐานภาพประกอบการแจ้งเหตุ
library;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// คลาสสำหรับโหลดโมเดล AI และทำนายประเภทภาพ
class Classifier {
  /// ตัวประมวลผลโมเดล TFLite
  Interpreter? _interpreter;

  /// รายการ label ที่ตรงกับ output index ของโมเดล
  List<String>? _labels;

  /// ตัวสร้างเริ่มต้นสำหรับโหลดโมเดลและ labels
  Classifier() {
    _loadModel();
    _loadLabels();
  }

  /// โหลดไฟล์โมเดลจาก assets
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/mobilenet_v2.tflite');
      print('Model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  /// โหลดไฟล์ labels จาก assets เพื่อแปลผลลัพธ์ของโมเดล
  Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n').where((item) => item.isNotEmpty).toList();
      print('Labels loaded successfully');
    } catch (e) {
      print('Error loading labels: $e');
    }
  }

  /// รับไฟล์ภาพและส่งคืนผลทำนายที่น่าเชื่อถือสูงสุด 3 อันดับ
  /// รูปแบบผลลัพธ์: label, confidence, category
  Future<List<Map<String, dynamic>>> classifyImage(File imageFile) async {
    // ถ้ายังโหลดโมเดลไม่เสร็จ ให้ลองโหลดซ้ำอีกครั้งก่อน
    if (_interpreter == null || _labels == null) {
      print('Interpreter or labels not loaded');
     
      await _loadModel();
      await _loadLabels();
      if (_interpreter == null || _labels == null) {
        return [];
      }
    }

    try {
      // อ่านไฟล์และถอดรหัสภาพ
      final imageData = imageFile.readAsBytesSync();
      final image = img.decodeImage(imageData);
      if (image == null) {
        print('Failed to decode image');
        return [];
      }

      // ปรับขนาดภาพให้ตรงกับ input ของโมเดล (224x224)
      final resizedImage = img.copyResize(image, width: 224, height: 224);

      // เตรียม Tensor input รูปแบบ [1, 224, 224, 3]
      var input = List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) => List.filled(3, 0.0))));
      
      // แปลงค่าสีเป็น normalized [-1, 1]
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
         
          input[0][y][x][0] = (pixel.r - 127.5) / 127.5;
          input[0][y][x][1] = (pixel.g - 127.5) / 127.5;
          input[0][y][x][2] = (pixel.b - 127.5) / 127.5;
        }
      }

      // สร้าง output tensor ตาม shape ที่โมเดลกำหนด
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final outputAttributes = outputShape.reduce((a, b) => a * b);
      
      var output = List.filled(1 * outputAttributes, 0.0).reshape(outputShape);

      // รันการทำนายผล
      _interpreter!.run(input, output);

      final outputList = output[0] as List<double>;
      final List<Map<String, dynamic>> result = [];

      // เรียง index ตามค่าความมั่นใจจากมากไปน้อย
      final List<int> sortedIndices = List.generate(outputList.length, (index) => index)
        ..sort((a, b) => outputList[b].compareTo(outputList[a]));

      // ดึงผลลัพธ์ top-3 แล้วจับคู่เป็นหมวดที่ระบบใช้งาน
      for (int i = 0; i < 3; i++) {
        final int index = sortedIndices[i];
        if (index < _labels!.length) {
          final String label = _labels![index];
          final double confidence = outputList[index];

          // กรองผลลัพธ์ที่ความมั่นใจต่ำมาก
          if (confidence > 0.01) {
             String category = 'ไม่ระบุ';
             final lowerLabel = label.toLowerCase();
             
             if (lowerLabel.contains('wallet') || lowerLabel.contains('purse') || lowerLabel.contains('envelope')) {
               category = 'ซื้อสิทธิขายเสียง';
             } else if (lowerLabel.contains('minibus') || lowerLabel.contains('cab')) {
               category = 'ขนคนไปลงคะแนน';
             } else if (lowerLabel.contains('water bottle') || lowerLabel.contains('cup') || lowerLabel.contains('poster')) {
               category = 'แจกสิ่งของ';
             }
             
             result.add({
               'label': label, 
               'confidence': confidence, 
               'category': category
             });
          }
        }
      }
      return result;

    } catch (e) {
      // กรณีเกิดข้อผิดพลาดระหว่างการทำนายผล ให้คืนรายการว่าง
      print('Error during classification: $e');
      return [];
    }
  }
}

