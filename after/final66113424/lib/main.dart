// ไฟล์หลักของแอปสำหรับระบบแจ้งเหตุการทุจริตการเลือกตั้ง
import 'package:final66113424/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'helpers/database_helper.dart';

// ตัวแปรส่วนกลางสำหรับเก็บตัวเชื่อมต่อฐานข้อมูล (ใช้ร่วมกันทั้งแอป)
late final Future<Database> database;

/// ฟังก์ชันเริ่มต้นการทำงานของแอปพลิเคชัน
void main() async {
  // เตรียมระบบก่อนเรียกใช้งานแอป
  WidgetsFlutterBinding.ensureInitialized();
  
  // เริ่มต้นฐานข้อมูล (สร้างตารางและข้อมูลเริ่มต้น)
  await initializeDatabase();
  
  // เริ่มแอปพลิเคชัน
  runApp(const MyApp());
}

/// คลาสหลักของแอปพลิเคชัน
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Final66113424', // ชื่อแอปพลิเคชัน
      home: const HomeScreen(), // หน้าจอแรกที่เปิดขึ้นมา (รายการแจ้งเหตุ)
    );
  }
}
