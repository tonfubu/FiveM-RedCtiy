# FiveM RedCity — ESX Legacy Server

เซิร์ฟเวอร์ FiveM แบบ **ESX Legacy** (esx_core 1.13.5) ติดตั้งบนเครื่อง Ubuntu 24.04
พร้อมระบบพื้นฐานครบสำหรับ Roleplay และเชื่อมต่อฐานข้อมูล MariaDB ภายนอก

> Repo นี้เก็บเฉพาะ **ไฟล์ตั้งค่า + เอกสาร + สคริปต์** เท่านั้น
> ตัว FiveM artifact และ resources ของบุคคลที่สาม (esx_core, ESX-Legacy-Addons, oxmysql)
> ถูก `.gitignore` ไว้ และดึงจากต้นทางตอนติดตั้ง (ดูหัวข้อ "วิธีติดตั้ง")

---

## ข้อมูลระบบ

| รายการ | ค่า |
|---|---|
| Hostname | `FiveM-RedCity` |
| IP (static) | `10.10.10.163/24` (gw `10.10.10.1`) |
| OS | Ubuntu 24.04.3 LTS |
| Path ติดตั้ง | `/opt/fivem-redcity` |
| Artifact | FiveM build **25770** (recommended) |
| Framework | ESX Legacy (esx_core 1.13.5) |
| Database | MariaDB `redcity_esx` @ `10.10.10.205` |
| systemd service | `fivem-redcity.service` |
| Port เกม | `30120` TCP/UDP |
| txAdmin (option) | `http://10.10.10.163:40120` |

### โครงสร้างโฟลเดอร์บนเครื่อง

```
/opt/fivem-redcity/
├── server/                 # FiveM artifact (FXServer)        [gitignored]
├── server-data/
│   ├── server.cfg          # config หลัก (ไม่มี password)      [gitignored*]
│   ├── secrets.cfg         # DB connection + license key       [gitignored]
│   ├── secrets.cfg.example # ตัวอย่าง
│   └── resources/          # [core] [esx_addons] [standalone] [system]...  [gitignored]
├── logs/
├── backups/                # backup config + dump DB           [gitignored]
└── scripts/backup.sh
```
\* `server.cfg` ไม่มี password แต่ถูก ignore ไว้กันพลาด — ใช้ `server.cfg.example` เป็นต้นแบบ

---

## วิธีติดตั้ง (สรุปขั้นตอนที่ใช้สร้างเครื่องนี้)

```bash
# 1) เตรียมระบบ
apt update && apt -y dist-upgrade
apt install -y git curl wget unzip screen tmux tar xz-utils \
               mariadb-client build-essential qemu-guest-agent jq
mkdir -p /opt/fivem-redcity/{server,server-data/resources,logs,backups,scripts}

# 2) ดาวน์โหลด artifact (build 25770)
cd /opt/fivem-redcity/server
curl -O https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/25770-8ddccd4e4dfd6a760ce18651656463f961cc4761/fx.tar.xz
tar xJf fx.tar.xz && rm fx.tar.xz

# 3) resources
cd /opt/fivem-redcity/server-data/resources
# default system resources
git clone --depth 1 https://github.com/citizenfx/cfx-server-data tmp && cp -rn tmp/resources/* ./ && rm -rf tmp
# oxmysql
mkdir -p '[standalone]' && cd '[standalone]'
curl -LO https://github.com/overextended/oxmysql/releases/latest/download/oxmysql.zip && unzip -q oxmysql.zip && rm oxmysql.zip && cd ..
# ESX core + addons
git clone --depth 1 https://github.com/esx-framework/esx_core /tmp/esx_core && cp -r '/tmp/esx_core/[core]' ./
git clone --depth 1 https://github.com/esx-framework/ESX-Legacy-Addons /tmp/addons && cp -r '/tmp/addons/[esx_addons]' ./

# 4) ฐานข้อมูล
mysql -h 10.10.10.205 -u redpotiondb -p -e "CREATE DATABASE redcity_esx CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -h 10.10.10.205 -u redpotiondb -p redcity_esx < '/opt/fivem-redcity/server-data/resources/[esx_sql]/legacy.sql'
# แล้ว import .sql ของแต่ละ addon ที่เปิดใช้

# 5) ตั้งค่า
cp server-data/secrets.cfg.example server-data/secrets.cfg   # แล้วใส่ค่าจริง
# คัดลอก service แล้ว enable
cp systemd/fivem-redcity.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now fivem-redcity
```

---

## วิธี Start / Stop / Restart

```bash
systemctl start   fivem-redcity     # เปิด
systemctl stop    fivem-redcity     # ปิด
systemctl restart fivem-redcity     # รีสตาร์ท
systemctl status  fivem-redcity     # ดูสถานะ
systemctl enable  fivem-redcity     # เปิดอัตโนมัติหลัง reboot (ตั้งไว้แล้ว)
```

## วิธีดู Log

```bash
journalctl -u fivem-redcity -f               # ดูแบบ realtime
journalctl -u fivem-redcity --since "10 min ago"
journalctl -u fivem-redcity -n 200 --no-pager
```

## วิธีตั้งค่า Database

แก้ที่ไฟล์ **`server-data/secrets.cfg`** (อยู่บนเครื่องเท่านั้น ไม่ขึ้น git):

```cfg
set mysql_connection_string "server=10.10.10.205;uid=redpotiondb;password=YOUR_PASS;database=redcity_esx;charset=utf8mb4"
```

> ใช้รูปแบบ `key=value;` (ไม่ใช่ URL) เพื่อให้ใส่อักขระพิเศษใน password เช่น `@` ได้ตรง ๆ
> ถ้าใช้รูปแบบ URL `mysql://` ต้อง URL-encode (`@` → `%40`) มิฉะนั้น oxmysql จะ login ไม่ผ่าน

## วิธีเปลี่ยน License Key

แก้บรรทัด `sv_licenseKey` ใน **`server-data/secrets.cfg`** (เอา key จาก https://keymaster.fivem.net):

```cfg
sv_licenseKey "cfxk_xxxxxxxxxxxxxxxxxxxxx"
```
แล้ว `systemctl restart fivem-redcity`

## วิธีเพิ่ม Admin

1. ให้ผู้เล่นเข้าเกมแล้วดู license identifier:
   - ในคอนโซลเซิร์ฟเวอร์: คำสั่ง `getplayeridentifiers <id>` หรือดูใน txAdmin
2. แก้ `server-data/server.cfg` แทนค่า `CHANGE_ME`:
   ```cfg
   add_principal identifier.license:xxxxxxxxxxxxxxxxxxxx group.admin
   ```
3. `systemctl restart fivem-redcity`

## วิธี Backup

```bash
bash /opt/fivem-redcity/scripts/backup.sh
# เก็บไว้ที่ /opt/fivem-redcity/backups/backup_<วันเวลา>/ (เก็บล่าสุด 14 ชุด)
# ตั้ง cron รายวันได้:  0 4 * * *  bash /opt/fivem-redcity/scripts/backup.sh
```

---

## Resources ที่เปิดใช้งาน (ระบบพื้นฐาน)

**Core (esx_core):** es_extended, oxmysql, esx_menu_default/dialog/list, esx_identity,
esx_skin, skinchanger, esx_multicharacter, esx_inventory, esx_context, esx_notify,
esx_textui, esx_progressbar, esx_loadingscreen

**Addons:** esx_addonaccount, esx_addoninventory, esx_datastore, esx_society,
esx_status, esx_basicneeds, esx_optionalneeds, esx_billing, esx_license,
esx_jobs, esx_ambulancejob (revive), esx_vehicleshop, esx_garage

> Addon เพิ่มเติม (policejob, mechanicjob, taxijob, drugs ฯลฯ) มีอยู่ในโฟลเดอร์
> `resources/[esx_addons]` แล้ว เพียงเพิ่ม `ensure <ชื่อ>` ใน `server.cfg` และ import `.sql`

---

## txAdmin (ทางเลือก)

มี service สำรอง `fivem-txadmin.service` (ปิดไว้) สำหรับจัดการผ่านเว็บ:

```bash
systemctl stop fivem-redcity          # ปิดตัวรันแบบ direct ก่อน (กันชน port 30120)
systemctl start fivem-txadmin
journalctl -u fivem-txadmin -f         # ดู PIN สำหรับตั้งค่าครั้งแรก
# เปิดเว็บ http://10.10.10.163:40120  -> ตั้ง admin -> ชี้ data dir = server-data, cfg = server.cfg
```
> ใช้ **อย่างใดอย่างหนึ่ง** ระหว่าง `fivem-redcity` (direct) หรือ `fivem-txadmin` ไม่รันพร้อมกัน

---

## สิ่งที่ต้องใส่เอง

- `sv_licenseKey` — ใส่ค่าจริงใน `secrets.cfg` (ทำแล้วบนเครื่อง production)
- `add_principal identifier.license:CHANGE_ME group.admin` — ใส่ license ของแอดมินจริง
- `steam_webApiKey` — (ถ้าต้องการ identifier แบบ steam)
