# Tech Stack & Project Structure — โปรแกรมให้คะแนนการแข่งขัน (score-app)

> เอกสารฉบับร่าง v0.1 — 2026-09-29 (อัปเดตส่วน deploy: ย้าย Azure → AWS)
> เป้าหมายหลัก: **ฟรี (open-source, ไม่มีค่า license)** และ **ย้ายง่าย (portable, ไม่ล็อก vendor)**

## 1. 🎯 หลักการเลือกเทคโนโลยี

1. **ฟรีทั้งหมด** — ใช้ open-source ล้วน ไม่มีค่าใช้จ่ายด้าน license
2. **ย้ายง่าย** — แพ็กด้วย Docker → ยกไปรันบนเครื่อง/คลาวด์ไหนก็ได้ ไม่ต้องแก้โค้ด
3. **ไม่ผูก vendor** — หลีกเลี่ยง managed service เฉพาะเจ้า (เช่น DynamoDB, Firebase) ใช้มาตรฐานเปิด (PostgreSQL/SQLite)
4. **ภาษาเดียวทั้ง stack** — TypeScript ทั้ง frontend/backend ลดภาระการดูแล

## 2. 🧰 เทคโนโลยีที่เลือก

| ส่วน | เทคโนโลยี | เหตุผล |
|------|-----------|--------|
| Frontend | **React + TypeScript + Vite** | นิยม, ฟรี, ชุมชนใหญ่, build เป็น static ไฟล์ ย้ายง่าย |
| UI | **Tailwind CSS** | เบา, responsive ง่าย (รองรับมือถือ/แท็บเล็ตของกรรมการ) |
| Backend | **Node.js + Express + TypeScript** | ฟรี, เบา, ภาษาเดียวกับ frontend |
| ORM | **Prisma** | สลับ PostgreSQL/SQLite ได้ด้วย config เดียว → ย้ายง่ายจริง |
| Database | **PostgreSQL** (prod) / **SQLite** (พกพา/เล็ก) | open-source, มาตรฐานเปิด, dump/restore ย้ายข้อมูลง่าย |
| Auth (Admin) | **JWT** (jsonwebtoken) | ไม่พึ่ง service ภายนอก |
| Auth (Judge) | **access token ในลิงก์** | ไม่ต้องมีระบบสมาชิก |
| Export | **exceljs** (xlsx/csv), **pdfmake** (pdf) | ฟรี ทำงานฝั่ง server |
| Container | **Docker + Docker Compose** | หัวใจของการย้ายง่าย — ยกทั้งชุดไปรันที่ไหนก็ได้ |

> ทางเลือกที่เบากว่านี้ถ้าต้องการเรียบง่ายสุด: ใช้ **SQLite** ไฟล์เดียว + backend เสิร์ฟ static frontend ในโปรเซสเดียว → ได้ไฟล์รันเดียวจบ ย้ายแค่ก๊อปโฟลเดอร์

## 3. 🚀 การ Deploy (เป้าหมาย: AWS — ECS Fargate + EFS)

> รายละเอียดครบใน [`10-aws-architecture.md`](10-aws-architecture.md) · เชิงนโยบาย/แผนย้ายใน [`08-aws-migration-proposal.md`](08-aws-migration-proposal.md)
> สถานะ: อยู่ระหว่างย้ายจาก Azure → AWS (ยังไม่ลงมือ implement IaC)

Deploy ปลายทางบน **AWS ECS Fargate**:
- แพ็กเป็น **Docker image เดียว** (backend เสิร์ฟทั้ง API + frontend static)
- Image build/เก็บบน **ECR** (Elastic Container Registry)
- ข้อมูล **SQLite บน EFS/EBS** (mount `/data`) → ข้อมูลถาวรแม้ scale-to-zero
- **scale-to-zero** (0 task เมื่อไม่มีงาน) ประหยัดค่าใช้จ่าย; **1 task เท่านั้น** (ข้อจำกัดของ SQLite ตัวเขียนเดียว)
- HTTPS + โดเมนคงที่ผ่าน **CloudFront + ACM** (แนะนำ — ดู `10` §4.2)
- IaC = **AWS CDK (TypeScript)** ใน `deploy/aws/` · CI/CD auth = **OIDC**

**เหมาะกับ use case จริง** (กรรมการ+admin < 10, ทีม ≤ 20 — โหลดต่ำ) SQLite เพียงพอ

> **หมายเหตุประวัติ:** ระบบเคยรันบน **Azure Container Apps** (ACR + Azure Files) ก่อนย้ายมา AWS ตามนโยบายองค์กร
> โครงสร้างยังคง portable (Docker + Prisma) — ย้าย cloud หรือ PostgreSQL ได้โดยแก้เล็กน้อย

**ทางเลือกอื่นที่ยังทำได้ (portable):**
- Self-host / โน้ตบุ๊กในงาน — `docker build` + `docker run` ให้กรรมการต่อ WiFi วงเดียวกัน
- ย้าย DB ไป PostgreSQL/RDS (ถ้าโหลดสูง/ต้องหลาย replica) — เปลี่ยน provider ใน Prisma

## 4. 📁 โครงสร้างโปรเจกต์ (จริง)

```
score-app/
├─ docs/                      # เอกสาร spec
│  ├─ 01-requirements.md
│  ├─ 02-design.md
│  ├─ 03-tech-stack.md
│  ├─ 04-live-workflow.md     # แผนอนาคต (ยังไม่ทำ)
│  ├─ 08-aws-migration-proposal.md   # แผนย้ายไป AWS
│  ├─ 10-aws-architecture.md         # สถาปัตยกรรม AWS (ECS Fargate + EFS)
│  └─ 11-aws-cost-inputs.md          # ข้อมูล cost สำหรับ Presale
├─ backend/
│  ├─ src/
│  │  ├─ index.ts             # entry: Express + เสิร์ฟ frontend static + /api/health,/api/version
│  │  ├─ prisma.ts            # PrismaClient singleton
│  │  ├─ scoring.ts           # สูตรคำนวณคะแนน/อันดับ
│  │  ├─ excel.ts             # export/import Excel (exceljs)
│  │  ├─ token.ts             # สร้าง access token กรรมการ
│  │  ├─ seed.ts              # seed ข้อมูลตัวอย่าง (idempotent, ใช้ตอน start บน prod)
│  │  └─ routes/
│  │     ├─ admin.ts          # competitions/criteria/competitors/judges/results/export/import/delete
│  │     └─ judge.ts          # session/scores (auth ด้วย access token)
│  ├─ prisma/
│  │  ├─ schema.prisma        # data model + binaryTargets (native, debian-openssl-3.0.x)
│  │  ├─ migrations/
│  │  └─ seed.ts              # seed สำหรับ dev (ts-node)
│  └─ package.json
├─ frontend/
│  ├─ src/
│  │  ├─ main.tsx             # router + VersionFooter
│  │  ├─ api.ts               # เรียก backend (/api)
│  │  ├─ components/
│  │  │  └─ VersionFooter.tsx
│  │  └─ pages/
│  │     ├─ AdminPage.tsx     # ตั้งค่า + ตารางการแข่งขัน + export/import/ลบ
│  │     ├─ ResultsPage.tsx   # ผล/อันดับ + export
│  │     └─ JudgePage.tsx     # ตารางกรอกคะแนน (ปุ่ม 0–5)
│  ├─ package.json
│  └─ vite.config.ts          # dev proxy /api -> :4000
├─ Dockerfile                 # multi-stage: build frontend+backend -> image เดียว
├─ .dockerignore
├─ VERSION                    # เลขเวอร์ชัน (semver)
├─ CHANGELOG.md
└─ README.md
```

> หมายเหตุ: ไม่มี `docker-compose.yml` — deploy เป็น Docker image เดียวบน ECS Fargate (backend เสิร์ฟ frontend static)

## 5. 🔧 ตัวแปรสภาพแวดล้อม (.env.example)

```
# เลือกชนิดฐานข้อมูล: postgresql หรือ sqlite
DATABASE_URL="postgresql://user:pass@db:5432/scoreapp"
# หรือ SQLite (พกพา): DATABASE_URL="file:./data/scoreapp.db"

JWT_SECRET="change-me"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD_HASH="..."     # bcrypt hash

APP_BASE_URL="http://localhost:5173"   # ใช้ประกอบลิงก์กรรมการ
```

## 6. 🗓️ แผนการพัฒนา (เฟส)

1. **เฟส 1 — โครงหลัก:** data model + admin สร้างการแข่งขัน/หัวข้อ/ผู้เข้าแข่ง/กรรมการ + ลิงก์กรรมการ
2. **เฟส 2 — การให้คะแนน:** หน้ากรรมการ กรอก+auto-save, บังคับความเป็นส่วนตัว
3. **เฟส 3 — รวมผล:** คำนวณ, breakdown, อันดับ, หน้าผลฝั่ง admin
4. **เฟส 4 — export & polish:** CSV/Excel/PDF, responsive, validation ครบ
5. **เฟส 5 (ภายหลัง):** real-time progress, trimmed mean, หลายรอบ/สาย, แสดงผลจอใหญ่

## 7. ✅ เหตุผลสรุป (ตอบโจทย์ฟรี + ย้ายง่าย)

- ไม่มีค่า license ทุกส่วน → **ฟรี**
- แพ็ก Docker Compose ชุดเดียว + Prisma สลับ DB ได้ → **ย้ายเครื่อง/ย้ายคลาวด์โดยไม่แก้โค้ด**
- รองรับ SQLite mode → กรณีเล็ก ยกไฟล์เดียวก็ย้ายได้เลย
- ไม่พึ่ง managed service เฉพาะเจ้า → **ไม่ล็อก vendor**
