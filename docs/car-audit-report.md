# รายงาน Audit Car Resources — RAPTUMGAMER `[car]` pack

ตรวจสอบและ deploy car pack จาก `FiveM RAPTUMGAMER-01\Parallel\resources\[car]`
ขึ้น server **10.10.10.163** ที่ `resources/[cars]/` (ESX Legacy / artifact 25770)

## สรุปภาพรวม
| รายการ | ค่า |
|---|---|
| โฟลเดอร์ทั้งหมด | 93 (92 มี manifest + 1 orphan) |
| รถ/ยานพาหนะ (spawn names) | 130 |
| ขนาดรวม source | 1.85 GB (ไฟล์ใหญ่สุด 22.6 MB, ไม่มีเกิน 50/100 MB) |
| Manifest เดิม | 100% `__resource.lua` (deprecated) → **แปลงเป็น `fxmanifest.lua` แล้ว 90 ตัว** |
| ความปลอดภัย | ✅ 0 script แปลก / 0 webhook / 0 token / 0 obfuscated / 0 client-server.lua |
| **Deploy แล้ว** | **86 resources** (ensure) ที่ `resources/[cars]/` ขนาด 1.8 GB |

## ผลการจัดหมวด (A/B/C/D)
- 🟢 **A ใช้ได้ทันที: 83** — สมบูรณ์ มี stream+meta+spawn ไม่ชนใคร
- 🟡 **B ต้องเลือกก่อน: 7** — spawn name ซ้ำ (เปิดได้ทีละตัวต่อกลุ่ม)
- 🔴 **C ใช้ไม่ได้: 3** — carhitman, carvip (manifest อ้างไฟล์ที่ไม่มี, 0 MB), nero2 (มี stream แต่ไม่มี manifest) → **ไม่ deploy**
- ⚫ **D อันตราย: 0**

## Spawn name ที่ชนกัน (เลือกเปิดทีละตัว)
| spawn ที่ชน | resources | เปิดใช้ | ปิด (comment) |
|---|---|---|---|
| huntley, massacro, thrust | avenadmin / avenhitman / avendora | **avenadmin** | avenhitman, avendora |
| doc, jsred, tm | js / xmas | **js** | xmas |
| drchiron, mcdr, rmoddr | helicopterair / helicoptermc | **helicoptermc** | helicopterair |

## Add-on vs Replace
- Add-on ~84 (spawn เฉพาะตัว: fenyr, regera, senna, ageraone ฯลฯ)
- Replace 6: accord17→asterope, avenadmin/avenhitman/avendora→huntley/massacro/thrust, brickade→brickade, PoliceGT350R→t55a/riot

## สิ่งที่ทำตอน deploy
1. คัดออก: carhitman, carvip, nero2 (เสีย) + ไฟล์ขยะ z-link.txt (37), *.lnk, template *.png/.bmp/.jpg
2. แปลง `__resource.lua` → `fxmanifest.lua` (เพิ่ม `fx_version 'cerulean'` + `game 'gta5'`, ลบ `client_script "client.lua"` ที่อ้างไฟล์ไม่มี)
3. แก้ปัญหา UTF-8 BOM ที่ทำให้ FiveM parse manifest ไม่ได้ (`unexpected symbol near '<239>'`)
4. แยกไฟล์ `cars.cfg` (86 ensure + 4 comment) ให้ `server.cfg` exec
5. ทดสอบ: โหลดครบ 86, 0 failures, conflict ตัวที่ comment ไม่โหลด, server stable

## ควร optimize (texture ใหญ่)
fastNfurious 131MB (pack 8 คัน), fastun 55MB, r1v2018/m2/rs777 ~46MB, ageraone 31MB — บีบ .ytd ถ้า client กระตุก

## หมายเหตุ
- ไฟล์รถ (.yft/.ytd ~1.8GB) **ไม่ถูก commit ขึ้น git** (อยู่ใน `.gitignore: server-data/resources/`) — deploy ตรงเข้า server เท่านั้น
- รายการ ensure เต็มอยู่ใน `server-data/cars.cfg`; ข้อมูล audit ต่อคันใน `docs/car-audit.csv`
