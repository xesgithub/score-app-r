# 🏆 score-app (ชื่อชั่วคราว)

![version](https://img.shields.io/badge/version-0.6.0-blue)
![frontend](https://img.shields.io/badge/frontend-React%20%2B%20TS%20%2B%20Vite-61DAFB)
![backend](https://img.shields.io/badge/backend-Node%20%2B%20Express%20%2B%20Prisma-3178C6)
![db](https://img.shields.io/badge/db-SQLite-003B57)
![deploy](https://img.shields.io/badge/deploy-AWS%20ECS%20Fargate-FF9900)

ระบบเว็บสำหรับ **ให้คะแนนการแข่งขัน** — กรรมการหลายคนให้คะแนนแยกกัน (มองไม่เห็นกัน) แล้วระบบรวมคะแนนถ่วงน้ำหนักและจัดอันดับ

> เวอร์ชันปัจจุบัน: **v0.6.0** — เพิ่มเครื่องมือทดสอบ (สร้าง/ลบ กรรมการและทีมจำนวนมากเร็ว ๆ)
>
> ☁️ **หมายเหตุ:** ระบบกำลังย้ายจาก Azure → **AWS** (ECS Fargate + EFS) — ดู `docs/08`, `docs/10`, `docs/11`

## 📑 สารบัญ

- [เอกสาร (Spec)](#-เอกสาร-spec)
- [Tech Stack](#-tech-stack)
- [โครงสร้าง](#-โครงสร้าง)
- [การรัน (development)](#-การรัน-development)
- [สูตรคะแนน](#-สูตรคะแนน)
- [การใช้ Git](#-การใช้-git)
- [Versioning](#-versioning)

## 📚 เอกสาร (Spec)

- [`docs/01-requirements.md`](docs/01-requirements.md) — 📋 ความต้องการ
- [`docs/02-design.md`](docs/02-design.md) — 🗂️ data model, สูตรคะแนน, API
- [`docs/03-tech-stack.md`](docs/03-tech-stack.md) — 🧰 เทคโนโลยี + deploy
- [`docs/04-live-workflow.md`](docs/04-live-workflow.md) — 🗺️ workflow present สด (แผนอนาคต)
- [`docs/06-design-log-and-scorelock.md`](docs/06-design-log-and-scorelock.md) — 📜 ดีไซน์ Activity Log + ระบบล็อกคะแนน (รายทีม/ทั้งชุด)
- [`docs/07-dev-workflow.md`](docs/07-dev-workflow.md) — 🔄 ขั้นตอน dev → release → deploy + CI/CD
- [`docs/08-aws-migration-proposal.md`](docs/08-aws-migration-proposal.md) — ☁️ ข้อเสนอย้ายไป AWS (เชิงนโยบาย + แผน UAT/cut-over)
- [`docs/09-next-phase-security.md`](docs/09-next-phase-security.md) — 🔐 แผน phase ถัดไป: admin login + จัดการลิงก์กรรมการ
- [`docs/10-aws-architecture.md`](docs/10-aws-architecture.md) — 🏗️ สถาปัตยกรรม AWS (ECS Fargate + EFS) + design decisions + trade-off
- [`docs/11-aws-cost-inputs.md`](docs/11-aws-cost-inputs.md) — 💰 ข้อมูลประกอบการทำ cost สำหรับ Presale (Bill of Materials + usage pattern)

## 🧰 Tech Stack

- Frontend: React + TypeScript + Vite + Tailwind CSS
- Backend: Node.js + Express + TypeScript
- ORM/DB: Prisma + SQLite (สลับไป PostgreSQL ได้)

## 📁 โครงสร้าง

```
score-app/
├─ backend/     # Express API + Prisma
├─ frontend/    # React app
└─ docs/        # เอกสาร spec
```

## ▶️ การรัน (development)

### วิธีง่ายสุด (Windows) — ใช้ไฟล์ .bat
```
1) ดับเบิลคลิก  setup.bat   (ครั้งแรกครั้งเดียว: ติดตั้ง deps + สร้าง DB + seed)
2) ดับเบิลคลิก  dev.bat     (เปิด backend + frontend ในหน้าต่างแยก)
```
- Backend: http://localhost:4000
- Frontend: http://localhost:5173/admin

### หรือรันเองด้วยคำสั่ง
```bash
# 1) Backend
cd backend
npm install
npx prisma migrate dev
npm run seed        # ใส่ข้อมูลตัวอย่าง
npm run dev         # http://localhost:4000

# 2) Frontend (อีก terminal)
cd frontend
npm install
npm run dev         # http://localhost:5173
```

## 🧮 สูตรคะแนน

- แต่ละหัวข้อให้คะแนนเป็นจำนวนเต็ม 0–5
- น้ำหนักหัวข้อรวมกัน = 100%
- คะแนนกรรมการต่อทีม = Σ (คะแนนหัวข้อ × น้ำหนัก%) → เต็ม 5
- คะแนนสุดท้ายของทีม = เฉลี่ยคะแนนจากกรรมการทุกคน

## 🌱 การใช้ Git

Repo: **https://github.com/xesgithub/score-app** (private) · branch หลัก = `main`

### ขั้นตอนประจำวัน (ทำงานคนเดียว)
```bash
git status              # ดูว่ามีอะไรเปลี่ยน
git add .               # เตรียมไฟล์ที่จะ commit
git commit -m "feat: เพิ่มหน้าจัดอันดับ"
git push                # ส่งขึ้น GitHub
```

### รูปแบบข้อความ commit (Conventional Commits)
ใช้ prefix นำหน้าเพื่อให้อ่านประวัติง่าย:

| prefix | ใช้เมื่อ | ตัวอย่าง |
|--------|----------|----------|
| `feat:` | เพิ่มฟีเจอร์ใหม่ | `feat: export คะแนนเป็น PDF` |
| `fix:` | แก้บั๊ก | `fix: คำนวณค่าเฉลี่ยผิดเมื่อกรรมการไม่ครบ` |
| `docs:` | แก้เอกสารอย่างเดียว | `docs: อัปเดตวิธีติดตั้ง` |
| `chore:` | งานจิปาถะ (bump version, ลง deps) | `chore: bump 0.3.0` |
| `refactor:` | ปรับโค้ดโดยพฤติกรรมเหมือนเดิม | `refactor: แยก service คำนวณคะแนน` |
| `deploy:` | งานเกี่ยวกับ deploy | `deploy: ปรับ resource ECS Fargate` |

### ⚠️ ไฟล์ที่ห้าม commit
ถูกกันไว้ใน `.gitignore` แล้ว — **อย่านำออก**:
- `backend/.env` — ค่า secret / config
- `backend/prisma/dev.db` — ฐานข้อมูล SQLite (ข้อมูลจริง/ตัวอย่าง)

> 💡 ก่อน commit ทุกครั้ง ดู `git status` ให้แน่ใจว่าไม่มี `.env` หรือไฟล์ `.db` หลุดเข้าไป

### ออก release ใหม่
```bash
# 1) อัปเดต VERSION + CHANGELOG.md แล้ว commit
git commit -m "chore: bump 0.3.0"
# 2) ติด tag ตาม semver
git tag v0.3.0
git push --tags
```

## 🏷️ Versioning

ใช้ [Semantic Versioning](https://semver.org/) — ดูประวัติที่ [`CHANGELOG.md`](CHANGELOG.md)
