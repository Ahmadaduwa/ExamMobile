import 'dart:io';

import 'package:flutter/material.dart';

class IncidentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;

  const IncidentDetailScreen({super.key, required this.report});

  Widget _buildPhoto(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Icon(Icons.image_not_supported, size: 42)),
      );
    }

    final file = File(photoPath);
    if (!file.existsSync()) {
      return const SizedBox(
        height: 180,
        child: Center(child: Icon(Icons.broken_image, size: 42)),
      );
    }

    return Image.file(
      file,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stationName = report['station_name']?.toString() ?? '-';
    final violationName = report['violation_name']?.toString() ?? '-';
    final reporterName = report['reporter_name']?.toString() ?? '-';
    final description = report['description']?.toString() ?? '-';
    final province = report['province']?.toString() ?? '-';
    final district = report['district']?.toString() ?? '-';
    final timestamp = report['timestamp']?.toString() ?? '-';
    final evidenceType = report['evidence_type']?.toString() ?? '-';
    final confidenceScore = report['confidence_score']?.toString() ?? '-';
    final photoPath = report['photo_path']?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดแจ้งเหตุ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPhoto(photoPath),
            const SizedBox(height: 16),
            _buildRow('หน่วยเลือกตั้ง', stationName),
            _buildRow('จังหวัด', province),
            _buildRow('เขต/อำเภอ', district),
            _buildRow('ประเภทความผิด', violationName),
            _buildRow('ผู้แจ้ง', reporterName),
            _buildRow('วันเวลา', timestamp),
            _buildRow('ผลวิเคราะห์หลักฐาน', evidenceType),
            _buildRow('ความมั่นใจ (AI)', confidenceScore),
            _buildRow('รายละเอียดเหตุการณ์', description),
          ],
        ),
      ),
    );
  }
}