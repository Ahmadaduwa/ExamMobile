// ไฟล์หลักของแอปพลิเคชัน Flutter สำหรับระบบแจ้งเหตุการทุจริตการเลือกตั้ง
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'helpers/database_helper.dart';

import 'screens/main_screen.dart';

// ตัวแปร Global สำหรับเก็บ Database Instance (ใช้ร่วมกันทั้งแอป)
late final Future<Database> database;

/// ฟังก์ชัน main - จุดเริ่มต้นการทำงานของแอปพลิเคชัน
void main() async {
  // เตรียมการทำงานของ Flutter สำหรับ async operation ก่อน runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // เริ่มต้นฐานข้อมูล (สร้างตารางและข้อมูลเริ่มต้น)
  await initializeDatabase();
  
  // เริ่มแอปพลิเคชัน
  runApp(const MyApp());
}

/// คลาส MyApp - Widget หลักของแอปพลิเคชัน
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Final66113424', // ชื่อแอปพลิเคชัน
      theme: ThemeData(
        // ธีมสีของแอป (สีม่วงเป็นหลัก)
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MainScreen(), // หน้าจอแรกที่เปิดขึ้นมา (รายการแจ้งเหตุ)
    );
  }
}
