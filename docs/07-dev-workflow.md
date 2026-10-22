# Dev & Release Workflow — score-app

> เอกสารนี้บันทึก **ขั้นตอนการทำงานมาตรฐาน** ตั้งแต่แก้โค้ด → ออก release → deploy
> ใช้อ้างอิงเวลาสั่งงาน (คน หรือ AI agent) จะได้ทำตามแบบแผนเดียวกัน
>
> ⚠️ **สถานะ:** ระบบกำลังย้ายจาก Azure → AWS ส่วน **CD (deploy) สำหรับ AWS ยังไม่ถูกสร้าง** (ดูแผนใน `docs/10-aws-architecture.md` §5, §7). ขั้นตอน CI ด้านล่างใช้งานได้จริงแล้ว

## 1. ภาพรวม CI/CD

| Workflow | ไฟล์ | Trigger | ทำอะไร |
|----------|------|---------|--------|
| **CI** | `.github/workflows/ci.yml` | **manual เท่านั้น** (`workflow_dispatch`) — ชั่วคราวระหว่างย้าย AWS | build + typecheck (frontend + backend) + `prisma validate` |
| **CD** (AWS, จะสร้าง) | `.github/workflows/deploy-aws.yml` | push tag `v*` **หรือ** กด Run workflow เอง | build image → push **ECR** → `cdk deploy` → smoke test |

**หลักการสำคัญ:**
- **CI กับ CD แยกกัน** — push โค้ดปกติ **ไม่ deploy** (รันแค่ CI)
- **CD ต้องตั้งใจสั่ง** — deploy เกิดเฉพาะเมื่อออก tag หรือกดปุ่มเอง (กัน deploy หลุดระหว่างงานจริง)
- image tag = ชื่อ git tag (เช่น `v0.6.0`) เพื่อ traceable; ถ้ากดรันเองแบบไม่ใส่ tag จะได้ `manual-<run#>`
- **auth แบบ OIDC** — GitHub Actions assume IAM role ผ่าน OIDC (ไม่เก็บ access key ถาวรเป็น secret)

## 2. ตารางสรุป: ทำอะไร → เกิดอะไร

| การกระทำ | CI | CD (deploy) |
|-----------|----|-----|
| `git push` เข้า main | ⏸️ ไม่รัน (manual) | ❌ ไม่รัน |
| เปิด PR เข้า main | ⏸️ ไม่รัน (manual) | ❌ ไม่รัน |
| `git tag vX.Y.Z && git push --tags` | ❌ | ✅ deploy image `vX.Y.Z` (เมื่อ pipeline AWS พร้อม) |
| กด "Run workflow" (Actions → CI) | ✅ build/typecheck | ❌ |
| กด "Run workflow" (Actions → CD) | ❌ | ✅ deploy image `manual-<run#>` (เมื่อ pipeline AWS พร้อม) |

## 3. ขั้นตอนแก้โค้ดปกติ (ไม่ release)
```bash
git add <files>
git commit -m "feat: ..."   # ใช้ Conventional Commits (ดู README)
git push                     # CI เป็น manual แล้ว — กด Run workflow (Actions → CI) เองถ้าต้องการตรวจ
```

## 4. ขั้นตอนออก Release + Deploy (ทำเมื่อพร้อม deploy จริง)

1. **Bump version** ให้ครบทุกไฟล์ (ต้องตรงกันหมด):
   - `VERSION`
   - `backend/package.json` (`version`)
   - `frontend/package.json` (`version`)
   - `README.md` (badge + บรรทัด "เวอร์ชันปัจจุบัน")
   - `CHANGELOG.md` (เพิ่มหัวข้อเวอร์ชันใหม่)
2. **Commit + tag + push:**
   ```bash
   git add -A
   git commit -m "feat: ..." -m "chore: bump X.Y.Z"
   git tag vX.Y.Z
   git push origin main
   git push origin --tags        # ← ตัวนี้ทำให้ CD เริ่ม deploy
   ```
3. CD จะ build image `score-app:vX.Y.Z` → push ECR → `cdk deploy` (ECS Fargate) → smoke test อัตโนมัติ
4. ตรวจผลที่ Actions หรือ `https://<fqdn>/api/version` ต้องขึ้นเวอร์ชันใหม่

> **Semantic Versioning:** ฟีเจอร์ใหม่ (compatible) = minor (`0.x.0`); แก้บั๊ก = patch (`0.0.x`); breaking = major

## 5. Deploy โดยไม่ออก tag (เช่น hotfix ทดสอบ)
- ไปที่ GitHub → **Actions** → workflow CD (AWS) → **Run workflow**
- ได้ image `manual-<run#>` (ไม่ผูกเวอร์ชัน — ใช้เฉพาะกรณีเร่งด่วน/ทดสอบ)

## 6. Manual deploy จากเครื่อง (fallback ถ้า CD ใช้ไม่ได้)
- build + push image ขึ้น ECR แล้ว `cdk deploy` จาก `deploy/aws/` (รายละเอียดจะเพิ่มเมื่อ IaC AWS พร้อม — ดู `docs/10-aws-architecture.md`)

## 7. ข้อควรระวัง
- **อย่า deploy ตอนกรรมการกำลังกรอกคะแนน** (task เก่า/ใหม่รันซ้อนช่วงเปลี่ยน)
- **migration Prisma** apply อัตโนมัติตอน container start (`prisma migrate deploy` ใน Dockerfile) — ไม่ต้องทำใน pipeline
- **auth CI/CD:** ใช้ OIDC (IAM role) — ไม่ต้องเก็บ secret รหัสลับถาวร (ดู `docs/10-aws-architecture.md` §4.5)
- **ห้าม commit** `backend/.env`, `backend/prisma/dev.db` (gitignore ไว้แล้ว)

## 8. (ทางเลือก) เพิ่มด่านอนุมัติก่อน deploy
ถ้าต้องการให้ CD **รอกดอนุมัติก่อน** deploy จริง: ตั้ง GitHub **Environment `production`** + Required reviewers
แล้วผูก job ใน workflow CD กับ environment นั้น (ยังไม่ได้ทำ — เปิดเป็นตัวเลือกไว้)
