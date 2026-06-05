# txAdmin — ติดตั้งและใช้งาน (FiveM RedCity ESX Legacy)

เซิร์ฟเวอร์รันผ่าน **txAdmin** (เว็บจัดการที่ port 40120) ซึ่งจะ spawn ตัวเกม
FXServer (port 30120) เป็น process ลูก — ใช้ systemd service เดียว: `fivem-redcity.service`

## ข้อมูล

| รายการ | ค่า |
|---|---|
| txAdmin URL (LAN) | http://10.10.10.163:40120 |
| Game port | 30120 TCP/UDP |
| txAdmin version | v8.0.1 (artifact build 25770) |
| Service | `fivem-redcity.service` (txAdmin mode) |
| txData | `/opt/fivem-redcity/txData` |
| Server Data | `/opt/fivem-redcity/server-data` |
| CFG | `/opt/fivem-redcity/server-data/server.cfg` |
| Fallback (direct) | `fivem-redcity-direct.service` (disabled) |

## การ setup ครั้งแรก (ผ่านเว็บ)

1. เปิด **http://10.10.10.163:40120**
2. ใส่ **PIN** ที่ขึ้นใน console (ดูด้วย `journalctl -u fivem-redcity | grep -A1 "PIN"`)
   - PIN จะ rotate ทุกครั้งที่ restart service ถ้าหมดอายุให้ `systemctl restart fivem-redcity` แล้วดึงใหม่
3. สร้าง **master account** (ตั้ง username + password ของ txAdmin) — การ Link Cfx.re เป็นทางเลือก
4. ตั้งชื่อ server: **FiveM RedCity ESX Legacy**
5. เลือก **"Open an existing server data folder"** (import existing) แล้วชี้:
   - Server Data Folder = `/opt/fivem-redcity/server-data`
   - CFG File = `server.cfg`
6. กด Save → txAdmin จะ start ตัวเกมบน port 30120
7. เปิด **Settings → Restarter / Autostart** ให้ auto start (ค่า default เปิดอยู่)

> server.cfg เดิม + secrets.cfg (DB + license key) ถูกใช้ตามเดิม — ไม่ต้องกรอก DB/license ซ้ำ

## คำสั่งจัดการ

```bash
systemctl start   fivem-redcity     # เปิด (txAdmin + เกม)
systemctl stop    fivem-redcity     # ปิด
systemctl restart fivem-redcity     # รีสตาร์ท
systemctl status  fivem-redcity
journalctl -u fivem-redcity -f      # ดู log realtime
```

ดู port:
```bash
ss -tulpn | grep -E '30120|40120'
```

## เปลี่ยนกลับไปรันแบบ direct (ไม่ใช้ txAdmin)

```bash
systemctl disable --now fivem-redcity
systemctl enable  --now fivem-redcity-direct
```

## หมายเหตุ

- ConVar `txAdminPort` ขึ้น warning ว่า deprecated (จะถูกถอดใน update ถัดไป) — ใช้ได้ปกติกับ
  build 25770; อนาคตให้ย้ายไปใช้ env `TXHOST_TXA_PORT=40120` แทน
- ห้าม commit `txData/` (มี secret/credentials ของ txAdmin) ขึ้น git — อยู่ใน `.gitignore` แล้ว
