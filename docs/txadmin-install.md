# txAdmin — ติดตั้งและใช้งาน (FiveM RedCity ESX Legacy)

เซิร์ฟเวอร์รันผ่าน **txAdmin** (เว็บจัดการ port 40120) ซึ่ง spawn ตัวเกม FXServer
(port 30120) เป็น process ลูก — ใช้ systemd service เดียว: `fivem-redcity.service`

เครื่องนี้ถูก **provision แบบ headless** ผ่าน `TXHOST_*` env vars (txAdmin v8) จึง:
- สร้าง master admin อัตโนมัติ (ไม่ต้องใช้ PIN)
- auto-deploy ชี้ไป server-data เดิม และ **auto-start เกมบน 30120** ทันทีตอน boot

## ข้อมูล

| รายการ | ค่า |
|---|---|
| txAdmin URL (LAN) | http://10.10.10.163:40120 |
| Game port | 30120 TCP/UDP |
| txAdmin version | v8.0.1 (artifact build 25770) |
| Service | `fivem-redcity.service` (txAdmin mode) |
| Env file | `/opt/fivem-redcity/txAdmin.env` (chmod600, gitignored) |
| txData | `/opt/fivem-redcity/txData` |
| Server Data | `/opt/fivem-redcity/server-data` |
| CFG | `server.cfg` (exec `secrets.cfg`) |
| Admin user | `redcityadmin` (รหัสผ่านอยู่กับเจ้าของ ไม่ขึ้น git) |
| Fallback (direct) | `fivem-redcity-direct.service` (disabled) |

## การ login เว็บ

1. เปิด **http://10.10.10.163:40120**
2. login ด้วย user `redcityadmin` + รหัสผ่านที่ตั้งไว้
   - ถ้าลืมรหัส: แก้ `TXHOST_DEFAULT_ACCOUNT` ใน `txAdmin.env` (สร้าง hash ใหม่ด้วย
     `htpasswd -bnBC 11 "" 'NewPass' | tr -d ':\n' | sed 's/^$2y$/$2b$/'`)
     แล้วลบ `txData/admins.json` + `systemctl restart fivem-redcity`
3. เกม start อัตโนมัติอยู่แล้ว (autoStart=true ใน `txData/default/config.json`)

## การ provision (headless) — ทำไว้แล้ว

`txAdmin.env` (โหลดผ่าน `EnvironmentFile=` ใน unit):
```dotenv
TXHOST_DATA_PATH=/opt/fivem-redcity/txData
TXHOST_TXA_PORT=40120
TXHOST_IGNORE_DEPRECATED_CONFIGS=true
TXHOST_DEFAULT_ACCOUNT=redcityadmin::<bcrypt-hash>
TXHOST_DEFAULT_DB<HOST|PORT|USER|PASS|NAME>=...
TXHOST_DEFAULT_CFXKEY=<cfx key>
```
การ deploy server ทำผ่าน `txData/default/config.json`:
```json
{ "version": 2,
  "general": { "serverName": "RedCity ESX" },
  "server": { "dataPath": "/opt/fivem-redcity/server-data",
              "cfgPath": "server.cfg", "onesync": "on", "autoStart": true } }
```

## คำสั่งจัดการ

```bash
systemctl start|stop|restart fivem-redcity
systemctl status fivem-redcity
journalctl -u fivem-redcity -f          # log realtime
ss -tulpn | grep -E '30120|40120'       # เช็ค port
```

## เปลี่ยนกลับไปรันแบบ direct (ไม่ใช้ txAdmin)

```bash
systemctl disable --now fivem-redcity
systemctl enable  --now fivem-redcity-direct
```

## หมายเหตุ

- onesync ถูกจัดการโดย txAdmin (`config.json` server.onesync="on") — ใน `server.cfg`
  บรรทัด `set onesync on` ถูก txAdmin comment ไว้โดยตั้งใจ (ปกติ ESX ยังได้ onesync)
- ห้าม commit `txData/` และ `txAdmin.env` (มี hash/รหัส DB/cfx key) — `.gitignore` แล้ว
