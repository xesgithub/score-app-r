# AGENTS.md — คู่มือสำหรับ AI agent ที่ทำงานกับ repo นี้

> อ่านไฟล์นี้ก่อนเริ่มงาน เพื่อทำตาม convention เดียวกันเวลาผู้ใช้สั่งสั้น ๆ

## โปรเจกต์
score-app — ระบบให้คะแนนการแข่งขัน (กรรมการหลายคนให้คะแนนแยกกัน แล้วรวม/จัดอันดับ)
- **Frontend:** React + TS + Vite + Tailwind (`frontend/`)
- **Backend:** Node + Express + TS + Prisma + SQLite (`backend/`)
- **Deploy (เป้าหมาย):** Docker image เดียว บน **AWS** — ECS Fargate (scale-to-zero) + SQLite บน EFS/EBS; image บน ECR
  - สถานะ: อยู่ระหว่างย้ายจาก Azure → AWS (ดู `docs/08-aws-migration-proposal.md`, `docs/10-aws-architecture.md`). IaC = AWS CDK (TypeScript) ใน `deploy/aws/` (จะสร้างในเฟส implement)
- เอกสารทั้งหมดอยู่ใน `docs/` (เริ่มที่ `README.md`)

## เมื่อผู้ใช้สั่ง "deploy" / "ขึ้น prod" / "ออก release"
> ⚠️ ระบบ CD อัตโนมัติสำหรับ AWS (`deploy-aws.yml` + CDK) ยังไม่ถูกสร้าง — ดูแผนใน `docs/10-aws-architecture.md` §5, §7
1. **Bump version ให้ครบทุกไฟล์:** `VERSION`, `backend/package.json`, `frontend/package.json`, `README.md` (badge + บรรทัด "เวอร์ชันปัจจุบัน"), `CHANGELOG.md` (SemVer)
2. Build ให้ผ่านทั้ง frontend + backend ก่อนเสมอ
3. Commit (`feat:`/`fix:` + `chore: bump X.Y.Z`) → tag `vX.Y.Z` → `git push origin main` + `git push origin --tags`
4. **ปลายทาง:** การ push tag `v*` จะ trigger CD (AWS) ให้ build image → push ECR → `cdk deploy` → smoke test (เมื่อ pipeline AWS พร้อม)
5. Verify: `https://<fqdn>/api/version` ต้องขึ้นเวอร์ชันใหม่

## CI/CD (ดู `docs/07-dev-workflow.md`)
- **CI** (`.github/workflows/ci.yml`): ปรับเป็น **manual เท่านั้น** (`workflow_dispatch`) ระหว่างย้าย Azure → AWS เพื่อประหยัด Actions minutes — build/typecheck. กดรันเองจาก Actions. เปิด auto (push/PR) อีกครั้งได้เมื่อระบบนิ่ง
- **CD** (AWS, `deploy-aws.yml` — จะสร้างในเฟส implement): รันเมื่อ **push tag `v*`** หรือกด Run เอง — build image + push ECR + `cdk deploy` + smoke test
- CI/CD **แยกกัน** (ผู้ใช้ต้องการแบบนี้) — CD ไม่รอ CI

## AWS resources (ดู `docs/10-aws-architecture.md`, `docs/11-aws-cost-inputs.md`)
- Region: `ap-southeast-7` (Bangkok)
- Compute: ECS Fargate (0.25 vCPU / 0.5 GB · 1 task · scale-to-zero)
- Storage: EFS/EBS สำหรับ SQLite `/data/prod.db` · Image: ECR `score-app:vN`
- Secrets: Secrets Manager/SSM (`ADMIN_PASSWORD`, `DATABASE_URL`)
- CI/CD auth: GitHub Actions OIDC → IAM role (ไม่เก็บ access key ถาวร)
- IaC: AWS CDK (TypeScript) ใน `deploy/aws/`

## กฎเหล็ก / ข้อควรระวัง
- **ห้าม commit** `backend/.env`, `backend/prisma/dev.db` (gitignore แล้ว) — เช็ค `git status` ก่อน commit
- **ห้าม push ตรงเข้า main โดยไม่ได้รับอนุญาต** / อย่า deploy ตอนกรรมการกำลังกรอกคะแนน
- **migration Prisma** apply อัตโนมัติตอน container start — ไม่ต้องทำใน pipeline
- Build ต้องผ่านก่อน commit/deploy เสมอ

## เอกสารอ้างอิง
- `docs/01-requirements.md` · `docs/02-design.md` (data model/API) · `docs/03-tech-stack.md`
- `docs/04-live-workflow.md`
- `docs/06-design-log-and-scorelock.md` (Log + ล็อกคะแนน) · `docs/07-dev-workflow.md` (dev/release flow)
- `docs/08-aws-migration-proposal.md` · `docs/09-next-phase-security.md` · `docs/10-aws-architecture.md` · `docs/11-aws-cost-inputs.md` (AWS)
