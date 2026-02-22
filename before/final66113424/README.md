# ระบบแจ้งเหตุการทุจริตในการเลือกตั้ง (Election Fraud Reporting System)

> **โค้ดสำหรับการสอบ Flutter Mobile Development**  
> รหัสนักศึกษา: 66113424

---

## 📋 เกี่ยวกับโปรเจกต์

แอปพลิเคชันนี้เป็นระบบสำหรับแจ้งเหตุการณ์การทุจริตในการเลือกตั้ง พัฒนาด้วย **Flutter** และใช้ฐานข้อมูล **SQLite** เก็บข้อมูลภายในเครื่อง ออกแบบมาเพื่อให้พลเมืองสามารถรายงานเหตุการณ์ต่างๆ ได้สะดวก ครอบคลุมตั้งแต่การซื้อสิทธิขายเสียง การขนคนไปลงคะแนน ไปจนถึงการหาเสียงเกินเวลา

---

## ✨ ฟีเจอร์หลัก

### 1. **Cascading Dropdown แบบ 3 ระดับ**
   - เลือก **จังหวัด** → โหลด**เขตเลือกตั้ง** → โหลด**หน่วยเลือกตั้ง**
   - รองรับทั้งโหมดเพิ่มใหม่และแก้ไข (Prefill ข้อมูลเดิมอัตโนมัติ)

### 2. **ระบบค้นหาแบบ Multi-Field Search**
   - ค้นหาพร้อมกันใน 3 ฟิลด์: **รายละเอียด**, **ชื่อผู้แจ้ง**, **ประเภทการทุจริต**
   - ใช้ SQL `LIKE` query สำหรับ partial matching

### 3. **การจัดการรูปภาพ**
   - ถ่ายรูปจากกล้อง (Camera)
   - เลือกรูปจาก Gallery
   - แสดงตัวอย่างรูปก่อนบันทึก

### 4. **Mock AI Analysis**
   - จำลองการวิเคราะห์รูปภาพด้วย AI
   - แสดงผลลัพธ์ประเภทหลักฐาน (Money, Crowd, Poster)
   - คำนวณค่าความเชื่อมั่น (Confidence Score 0.0-1.0)

### 5. **โหมดไม่ประสงค์ออกนาม**
   - สลับเป็น "Anonymous" ได้ด้วย Switch
   - ช่วยปกป้องผู้แจ้งเหตุที่ต้องการความเป็นส่วนตัว

### 6. **CRUD Operations**
   - **Create**: เพิ่มรายงานใหม่
   - **Read**: ดูรายการและรายละเอียด
   - **Update**: แก้ไขรายงานที่มีอยู่
   - **Delete**: ลบด้วย Swipe-to-Dismiss พร้อม Confirmation Dialog

### 7. **การจัดการวันที่แบบไทย**
   - แสดงวันที่เป็นภาษาไทย (เช่น "8 ก.พ. 2569 เวลา 09:30 น.")
   - แปลงปี ค.ศ. เป็น พ.ศ. อัตโนมัติ

### 8. **Severity Color Coding**
   - **High** = สีแดง
   - **Medium** = สีส้ม
   - **Low** = สีเขียว

---

## 🗂️ โครงสร้างโปรเจกต์ (lib Folder)

```
lib/
├── main.dart                    # จุดเริ่มต้นของแอป, กำหนด MaterialApp และ Theme
├── constants/
│   └── sql_commands.dart        # SQL สำหรับสร้างตาราง + ข้อมูลเริ่มต้น (Seed Data)
├── helpers/
│   └── database_helper.dart     # ฟังก์ชันจัดการฐานข้อมูล SQLite ทุกฟังก์ชัน
├── models/
│   ├── IncidentReport.dart      # Model สำหรับรายงานเหตุการณ์
│   ├── PollingStation.dart      # Model สำหรับหน่วยเลือกตั้ง
│   └── ViolationType.dart       # Model สำหรับประเภทการทุจริต
└── screens/
    ├── home_screen.dart         # หน้าจอหลัก (รายการรายงานทั้งหมด + Search Bar)
    ├── add_report_screen.dart   # หน้าจอเพิ่ม/แก้ไขรายงาน (Form + Cascading Dropdown)
    └── detail_screen.dart       # หน้าจอรายละเอียดรายงาน (แสดงข้อมูลครบ + AI Result)
```

---

## 📄 รายละเอียดไฟล์ใน `lib/`

### **1. `main.dart`**
- **หน้าที่**: จุดเริ่มต้นของแอปพลิเคชัน
- **ทำอะไร**:
  - เริ่มต้นฐานข้อมูล SQLite (`initializeDatabase()`)
  - กำหนด Theme สีม่วง (Deep Purple)
  - ตั้งค่าหน้าจอแรกเป็น `HomeScreen`

---

### **2. `constants/sql_commands.dart`**
- **หน้าที่**: เก็บคำสั่ง SQL และข้อมูลเริ่มต้น
- **ทำอะไร**:
  - กำหนดชื่อตาราง: `polling_station`, `violation_type`, `incident_report`
  - สร้างตาราง (CREATE TABLE)
  - ใส่ข้อมูลตัวอย่าง:
    - **4 หน่วยเลือกตั้ง** ในจังหวัดนครศรีธรรมราช
    - **5 ประเภทการทุจริต** (ซื้อเสียง, ขนคน, หาเสียงเกินเวลา, ทำลายป้าย, เจ้าหน้าที่ไม่เป็นกลาง)
    - **3 รายงานตัวอย่าง**

---

### **3. `helpers/database_helper.dart`**
- **หน้าที่**: ศูนย์กลางการจัดการฐานข้อมูล
- **ฟังก์ชันสำคัญ**:
  
  | ฟังก์ชัน | ทำอะไร |
  |---------|--------|
  | `initializeDatabase()` | สร้างฐานข้อมูลและตาราง ใส่ข้อมูลเริ่มต้น |
  | `getIncidentReports()` | ดึงรายงานทั้งหมด (JOIN 3 ตาราง) |
  | `searchIncidentReports(keyword)` | ค้นหาแบบ Multi-Field (LIKE query) |
  | `getDistinctProvinces()` | ดึงรายชื่อจังหวัดทั้งหมด (ไม่ซ้ำ) |
  | `getZonesByProvince(province)` | ดึงเขตตามจังหวัดที่เลือก |
  | `getPollingStationsByProvinceAndZone(...)` | ดึงหน่วยเลือกตั้งตามจังหวัด+เขต |
  | `insertIncidentReport(data)` | เพิ่มรายงานใหม่ |
  | `updateIncidentReport(id, data)` | อัปเดตรายงาน |
  | `DatabaseHelper.deleteReport(id)` | ลบรายงาน |
  | `getIncidentsBySeverity()` | สถิติตามระดับความรุนแรง |
  | `getAllIncidentReportsForExport()` | ดึงข้อมูลทั้งหมดไว้สำหรับ Export |

---

### **4. `models/IncidentReport.dart`**
- **หน้าที่**: Model สำหรับรายงานเหตุการณ์
- **ฟิลด์สำคัญ**:
  - `report_id`, `station_id`, `type_id`
  - `reporter_name`, `description`
  - `evidence_photo`, `timestamp`
  - `ai_result`, `ai_confidence`
- **เมธอด**:
  - `toMap()`: แปลง Object → Map (สำหรับบันทึกลง DB)
  - `fromMap()`: แปลง Map → Object (สำหรับดึงจาก DB)

---

### **5. `models/PollingStation.dart`**
- **หน้าที่**: Model สำหรับหน่วยเลือกตั้ง
- **ฟิลด์**: `station_id`, `station_name`, `zone`, `province`
- **เมธอด**: `toMap()`, `fromMap()`

---

### **6. `models/ViolationType.dart`**
- **หน้าที่**: Model สำหรับประเภทการทุจริต
- **ฟิลด์**: `type_id`, `type_name`, `severity`
- **เมธอด**: `toMap()`, `fromMap()`

---

### **7. `screens/home_screen.dart`**
- **หน้าที่**: หน้าจอหลักแสดงรายการรายงานทั้งหมด
- **ฟีเจอร์**:
  - **Search Bar**: ค้นหาแบบ real-time
  - **List View**: แสดงรายการทั้งหมด เรียงจากใหม่→เก่า
  - **Swipe to Delete**: ปัดซ้ายเพื่อลบ (มี Confirmation)
  - **Color Coding**: แสดงสีตาม Severity
  - **FAB (+)**: ปุ่มเพิ่มรายงานใหม่
  - **Tap to Detail**: กดดูรายละเอียด
- **ฟังก์ชันสำคัญ**:
  - `_loadReports()`: โหลดข้อมูลจาก DB
  - `_onSearchChanged()`: จัดการการค้นหา
  - `getSeverityColor()`: แปลง severity → สี
  - `formatHumanReadableDate()`: แปลงวันที่เป็นภาษาไทย

---

### **8. `screens/add_report_screen.dart`**
- **หน้าที่**: หน้าจอเพิ่ม/แก้ไขรายงาน
- **ฟีเจอร์**:
  - **Cascading Dropdown 3 ระดับ**: จังหวัด → เขต → หน่วย
  - **Prefill Mode**: ถ้าเป็นโหมดแก้ไข จะโหลดค่าเดิมทุกช่อง
  - **Anonymous Toggle**: สลับไม่ประสงค์ออกนาม
  - **Image Picker**: เลือกจาก Camera/Gallery
  - **Mock AI**: แสดง Loading Dialog 2 วินาที แล้วสุ่มผล
- **ฟังก์ชันสำคัญ**:
  - `_loadData()`: โหลดข้อมูลเริ่มต้น + Prefill
  - `_onProvinceChanged()`: จัดการเมื่อเลือกจังหวัด (โหลดเขต)
  - `_onZoneChanged()`: จัดการเมื่อเลือกเขต (โหลดหน่วย)
  - `_pickImage()`: เลือกรูปภาพ
  - `_submitData()`: บันทึกข้อมูล (Insert/Update)

---

### **9. `screens/detail_screen.dart`**
- **หน้าที่**: หน้าจอแสดงรายละเอียดรายงาน
- **ฟีเจอร์**:
  - แสดงรูปภาพหลักฐาน (ถ้ามี)
  - แสดงผล AI Analysis (Evidence Type + Confidence)
  - แสดงข้อมูลครบทุกฟิลด์
  - ปุ่มแก้ไข (Edit Icon ที่ AppBar)
- **ฟังก์ชันสำคัญ**:
  - `_buildDetailRow()`: Widget helper สร้างแถวข้อมูล

---

## 🗄️ โครงสร้างฐานข้อมูล

### **ตาราง `polling_station`**
| Field | Type | Description |
|-------|------|-------------|
| id | INTEGER | รหัสหน่วยเลือกตั้ง (PK) |
| name | TEXT | ชื่อหน่วยเลือกตั้ง |
| district | TEXT | เขตเลือกตั้ง |
| province | TEXT | จังหวัด |

### **ตาราง `violation_type`**
| Field | Type | Description |
|-------|------|-------------|
| id | INTEGER | รหัสประเภทการทุจริต (PK) |
| name | TEXT | ชื่อประเภท |
| severity | TEXT | ระดับความรุนแรง (High/Medium/Low) |

### **ตาราง `incident_report`**
| Field | Type | Description |
|-------|------|-------------|
| id | INTEGER | รหัสรายงาน (PK, AUTO INCREMENT) |
| station_id | INTEGER | FK → polling_station |
| violation_type_id | INTEGER | FK → violation_type |
| reporter_name | TEXT | ชื่อผู้แจ้ง |
| description | TEXT | รายละเอียด |
| photo_path | TEXT | เส้นทางรูปภาพ |
| timestamp | TEXT | วันที่-เวลา |
| evidence_type | TEXT | ประเภทหลักฐานจาก AI |
| confidence_score | REAL | ค่าความเชื่อมั่น (0.0-1.0) |

---

## 📦 Dependencies (pubspec.yaml)

```yaml
dependencies:
  sqflite: ^2.4.2               # SQLite Database
  path_provider: ^2.1.5         # เข้าถึง File System
  image_picker: ^1.2.1          # เลือก/ถ่ายรูป
  intl: ^0.20.2                 # จัดการวันที่
  fl_chart: ^1.1.1              # สำหรับกราฟ (อนาคต)
  shared_preferences: ^2.5.3    # เก็บข้อมูลแบบ Key-Value
  flutter_local_notifications: ^18.0.1  # Notifications
```

---

## 🚀 วิธีการรันโปรเจกต์

1. **Clone หรือดาวน์โหลดโปรเจกต์**
   ```bash
   cd final66113424
   ```

2. **ติดตั้ง Dependencies**
   ```bash
   flutter pub get
   ```

3. **รันบน Emulator หรือเครื่องจริง**
   ```bash
   flutter run
   ```

4. **(Android) หากเจอปัญหา Desugaring**
   - ไฟล์ `android/app/build.gradle.kts` มีการตั้งค่า `isCoreLibraryDesugaringEnabled = true` แล้ว

---

## 🎯 กรณีศึกษา (Use Cases)

### **Scenario 1: พลเมืองแจ้งเหตุซื้อเสียง**
1. กด FAB (+) ที่หน้าจอหลัก
2. เลือกจังหวัด → เขต → หน่วยเลือกตั้ง
3. เลือกประเภท "ซื้อสิทธิขายเสียง"
4. กรอกรายละเอียด
5. ถ่ายรูปหลักฐาน
6. กด "บันทึก"
7. รอ AI วิเคราะห์ 2 วินาที
8. กลับไปหน้าหลัก เห็นรายการใหม่

### **Scenario 2: ค้นหารายงานเกี่ยวกับ "แจกเงิน"**
1. พิมพ์ "แจกเงิน" ในช่องค้นหา
2. ระบบจะค้นหาใน description, reporter_name, violation_name
3. แสดงเฉพาะรายการที่ตรงเงื่อนไข

### **Scenario 3: แก้ไขรายงานเดิม**
1. กดที่รายการที่ต้องการ
2. กดปุ่มแก้ไข (ไอคอน Edit)
3. ระบบจะ Prefill ข้อมูลเดิมทั้งหมด (รวม Cascading Dropdown)
4. แก้ไขตามต้องการ → กด "อัปเดต"

### **Scenario 4: ลบรายงาน**
1. ปัดรายการจากขวาไปซ้าย
2. กด "ตกลง" ใน Confirmation Dialog
3. ข้อมูลถูกลบออกจากฐานข้อมูล

---

## 🔍 ฟีเจอร์ขั้นสูงที่ใช้

- ✅ **Cascading Dropdown** (3 ระดับ)
- ✅ **Multi-Field Search** (LIKE query กับ OR condition)
- ✅ **Swipe-to-Dismiss** พร้อม Confirmation
- ✅ **Prefill สำหรับโหมดแก้ไข** (รวมถึง Cascading)
- ✅ **Image Picker** (Camera + Gallery)
- ✅ **Mock AI Simulation** (Random result + Loading)
- ✅ **Thai Date Formatting** (ค.ศ. → พ.ศ.)
- ✅ **Anonymous Mode Toggle**
- ✅ **Null Safety** (รองรับ photo_path เป็น null)

---

## 👨‍💻 ผู้พัฒนา

- **รหัสนักศึกษา**: 66113424
- **วัตถุประสงค์**: โค้ดเตรียมสอบ Flutter Mobile Development
- **เวอร์ชัน Flutter**: 3.x
- **เวอร์ชัน Dart**: 3.x

---

## 📝 หมายเหตุ

- โค้ดทุกไฟล์มี **Comment ภาษาไทย** อธิบายการทำงาน
- ใช้ **SQLite** แทน Firebase เพื่อทำงาน Offline ได้
- AI Analysis เป็นแค่ **Mock (Simulation)** ไม่ได้เชื่อมต่อ AI จริง
- รองรับการแก้ไขข้อมูลแบบ **Prefill** ทุกฟิลด์รวมถึง Cascading Dropdown

---

## 🎓 สิ่งที่ได้เรียนรู้จากโปรเจกต์นี้

1. การจัดการ **SQLite Database** ใน Flutter
2. การใช้ **JOIN Query** ดึงข้อมูลจากหลายตาราง
3. การทำ **Cascading Dropdown** แบบ Dynamic
4. การใช้ **image_picker** และจัดการไฟล์รูปภาพ
5. การทำ **Search** แบบ Multi-Field ด้วย SQL LIKE
6. การจัดการ **State Management** ด้วย StatefulWidget
7. การใช้ **Navigator** สำหรับการเปลี่ยนหน้า
8. การจัดการ **Form Validation**
9. การใช้ **Dismissible Widget** สำหรับ Swipe-to-Delete
10. การจัดการ **Null Safety** ใน Dart

---

**สุดท้าย**: โปรเจกต์นี้ออกแบบมาเพื่อแสดงความเข้าใจในการพัฒนาแอป Flutter ครบวงจร ตั้งแต่การออกแบบฐานข้อมูล การจัดการ State ไปจนถึง UX/UI Design ที่ใช้งานง่าย 🚀

