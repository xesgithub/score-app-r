# 09 — แผนงาน Phase ถัดไป: ความปลอดภัยฝั่ง Admin + จัดการลิงก์กรรมการ

> สถานะ: **ยังไม่ลงมือ** — จดไว้จากการปรึกษา 2026-10-12
> ขอบเขต: ปิดช่องโหว่ที่กรรมการเข้าถึงฝั่งผู้จัดการ (admin) ได้ + จัดการลิงก์กรรมการที่หลุด
>
> 🚩 **อัปเดต 2026-10-22:** งานที่ 1–3 ในเอกสารนี้ **รวมไปทำในเวอร์ชันใหม่บน AWS รอบเดียว** พร้อมการย้าย infra (ดู `10-aws-architecture.md` §9 สรุป scope)
> - env `ADMIN_PASSWORD` ที่อ้างถึงด้านล่างว่าเก็บใน "ACA env" → บน AWS ให้เก็บใน **Secrets Manager/SSM** และ inject ผ่าน env (ดู `10` §5)
> - ส่วนที่อ้าง "ACA เป็น HTTPS อยู่แล้ว" → บน AWS ได้ HTTPS ผ่าน **CloudFront + ACM** (ดู `10` §4.2)

## บริบท / ปัญหาที่พบ

1. **หน้า/API admin เปิดโล่ง** — ใครก็ตามพิมพ์ `domain.com/admin` เข้าได้ และ `/api/admin/*` ไม่มี auth เลย
   (ยิง API ตรงด้วย curl/fetch ก็ดู/แก้ข้อมูลได้โดยไม่ต้องมีลิงก์กรรมการ)
2. **ลิงก์กรรมการหลุด** — ส่งต่อผิดคน / แชร์หลุด / อยากตัดกรรมการคนนั้นออก ยังไม่มีปุ่มจัดการที่ UI

ข้อตกลงจากการปรึกษา:
- admin **คนเดียว** → ใช้รหัสผ่านร่วมตัวเดียว (shared password) พอ ไม่ต้อง login ราย user
- หน้าผลคะแนน (`/admin/results/:id`) ให้ **เฉพาะ admin** ดู (แยกฝั่งผู้จัดการ ↔ กรรมการ)
- ฝั่ง `/judge` **ไม่แตะ**

---

## งานที่ 1 — ป้องกันฝั่ง Admin (auth)

แนวทาง: รหัสผ่าน admin ตัวเดียวจาก env + บังที่ **API layer** เป็นหลัก (ไม่ใช่แค่ซ่อน UI)

### Backend
- เพิ่ม env `ADMIN_PASSWORD` (`backend/.env` สำหรับ dev + ACA env สำหรับ prod)
- สร้าง middleware `requireAdmin` (เช่น `backend/src/auth.ts`):
  - อ่าน header `X-Admin-Password` (หรือ `Authorization: Bearer <pw>`)
  - ไม่ตรง/ไม่มี → `401`
- ครอบ `app.use('/api/admin', requireAdmin, adminRoutes)` ใน `index.ts`
- เพิ่ม `POST /api/admin/login` (ไม่ติด middleware) ให้ frontend ตรวจรหัสก่อนเก็บ
- ⚠️ จุดระวัง: `export` เปิดผ่าน `<a href>` ตรง ๆ แนบ header ไม่ได้
  → เปลี่ยนปุ่ม Export เป็น **fetch + download blob** (ไม่โชว์รหัสใน URL) [รอ confirm]

### Frontend
- `api.ts`:
  - เก็บรหัสใน storage (localStorage = จำจนกดออก / sessionStorage = หายเมื่อปิดแท็บ) [รอ confirm]
  - `req()` แนบ header `X-Admin-Password` ทุก path ที่ขึ้นต้น `/admin`
  - แก้ `importCompetition` (fetch ตรง) ให้แนบ header ด้วย
  - จัดการ `exportUrl` ตามข้อข้างบน
  - เจอ `401` → เคลียร์รหัส + เด้งกลับ gate
- สร้าง `AdminGate` ครอบ `AdminPage` + `ResultsPage` (หน้ากรอกรหัส → `/admin/login` → เก็บ → render จริง + ปุ่มออกจากระบบ)
- `/judge` ไม่แตะ

### ครอบคลุมช่องทางหลุดเข้า admin (ตรวจแล้ว)
- ลบ path เหลือ `/admin` ✅ · เดา `/admin/results/:id` ✅ · ยิง API ตรง ✅ (สำคัญสุด)
- Export ✅ · Import ✅ · Test tools (bulk) ✅ · token กรรมการใช้กับ admin ไม่ได้ ✅

### Trade-off ที่รับทราบ
- bundle JS ของหน้า admin ยัง download ได้ (ธรรมชาติ SPA) แต่ข้อมูลจริงถูกบังที่ API
- shared password รั่วแล้วใช้ได้ทุกคน — เหมาะกับ admin คนเดียว
- ต้องเสิร์ฟผ่าน HTTPS (ACA เป็น HTTPS อยู่แล้ว ✅)

---

## งานที่ 2 — Revoke / เปลี่ยนลิงก์กรรมการ

**ข่าวดี: backend พร้อมแล้วเกือบครบ** — เหลือต่อปุ่มที่ UI เป็นหลัก

### มีอยู่แล้ว (ตรวจจากโค้ด)
- `schema.prisma` → `Judge.tokenRevoked Boolean @default(false)`, `accessToken @unique`
- `routes/judge.ts` → ทุก endpoint เช็ค revoke ผ่าน `getJudgeByToken()` (token เก่าตายทันทีที่เปลี่ยน)
- `routes/admin.ts` → `POST /api/admin/judges/:id/revoke-token`
  มีแล้ว ทำ **regenerate** (ออก token ใหม่ + reset `tokenRevoked=false`) → ลิงก์เก่าใช้ไม่ได้, ลิงก์ใหม่ใช้ได้

### Gap ที่ต้องทำ
1. **Frontend ไม่มีปุ่มเรียก** — `api.ts` ยังไม่มี `regenerateToken()`, `AdminPage` ไม่มีปุ่ม
   → เพิ่ม `adminApi.regenerateToken(judgeId)` + ปุ่ม "ออกลิงก์ใหม่ / เพิกถอนลิงก์เก่า" ในรายการกรรมการ
   + confirm dialog (เตือนว่าลิงก์เดิมใช้ไม่ได้ทันที) + ปุ่มคัดลอกลิงก์ปัจจุบัน
2. **ไม่มี log** ใน endpoint `revoke-token` → เพิ่ม `logActivity` (action เช่น `judge.token_regenerate`)
3. (ทางเลือก) **disable ชั่วคราว** — endpoint `POST /judges/:id/disable-token` ตั้ง `tokenRevoked=true`
   เฉย ๆ (ตัดกรรมการออกชั่วคราวโดยไม่ออกลิงก์ใหม่) [รอ confirm ว่าต้องการไหม]

> endpoint ทั้งหมดอยู่ใต้ `/api/admin/*` → ได้รับการป้องกันจาก middleware งานที่ 1 โดยอัตโนมัติ

---

## การตัดสินใจ (สรุปแล้ว 2026-10-12)

บริบท: งานเป็น **การแข่งขันสด ใช้เวลา ~1-2 ชม.** ส่งลิงก์ให้กรรมการตัดสินช่วงนั้น จบแล้วเลิกใช้

1. **Export Excel → fetch+blob** — ปลอดภัย ไม่โชว์รหัสใน URL (ไม่ติด history/log)
2. **เก็บรหัส admin → sessionStorage** — งานสั้น + เครื่องอาจไม่ใช่ส่วนตัว ปิดแท็บแล้วรหัสหายเอง
3. **Disable token ชั่วคราว → ไม่ทำ** — งานสั้น ใช้ "ออกลิงก์ใหม่ (regenerate)" พอ ตัด disable ออกกัน UI รก
4. หมายเหตุ: ตั้งรหัส admin ให้เดายาก (ไม่ใช่ `1234`) ผู้จัดจำคนเดียว — กันกรอกผิดกลางงานสด

## ไฟล์ที่คาดว่าจะแตะ (งานที่ 1 + 2)
- `backend/src/index.ts`, `backend/src/auth.ts` (ใหม่), `backend/src/routes/admin.ts`
- `frontend/src/api.ts`, `frontend/src/main.tsx`, `frontend/src/pages/AdminPage.tsx`,
  `frontend/src/components/AdminGate.tsx` (ใหม่)
- `backend/.env` (+ `.env.example` ถ้ามี), ACA env, docs

---

## งานที่ 3 — ปรับ UI หน้าแสดงผลคะแนน (`frontend/src/pages/ResultsPage.tsx`)

> ยังไม่ลงมือ — จดไว้ 2026-10-12

### 3.1 เพิ่มสีสัน (ตอนนี้ขาวไปหมด)
- ทั้งหน้าเป็น `bg-white` + เส้นเทา อ่านยาก ไม่มีจุดเด่น
- แนวทาง: ไฮไลต์ **อันดับ 1-3** (เช่น ทอง/เงิน/ทองแดง หรือสีพื้นแถว), เพิ่มสี header ตาราง,
  แยกโซนด้วยสีพื้น/เงา, badge สถานะการแข่งขันให้มีสี (ดู `STATUS_STYLE` ใน `AdminPage.tsx` ใช้ซ้ำได้)
- คงโทนให้เข้ากับ Tailwind ที่โปรเจกต์ใช้อยู่

### 3.2 ตาราง "รายละเอียดคะแนน (กรรมการ × หัวข้อ)" — ไม่ต้องเรียงตามอันดับ
- **ปัญหา:** ตอนนี้ section นี้ใช้ตัวแปร `sorted` (เรียงตามคะแนน) เหมือนตารางอันดับ
  → ทำให้ลำดับทีมสลับไปมา ไล่หายาก
- **แก้:** section รายละเอียดให้ map จาก `data.results` (ลำดับเดิมจาก backend) แทน `sorted`
- **คงไว้:** section "อันดับ" ด้านบน ยังเรียงด้วย `sorted` ตามเดิม
- จุดแก้จริง: ในไฟล์มี `sorted.map(...)` 2 ที่ — ที่สอง(ใต้ `<h2>รายละเอียดคะแนน...`) เปลี่ยนเป็น `data.results.map(...)`


---

## ประเมินเวลา (dev + test)

> ประมาณการคร่าว ๆ สำหรับทำคนเดียว คุ้นเคย codebase · test = ทดสอบ manual + build/typecheck ผ่าน

### งานที่ 1 — ป้องกันฝั่ง Admin
| หัวข้อย่อย | dev | test | รวม |
|-----------|-----|------|-----|
| middleware `requireAdmin` + env `ADMIN_PASSWORD` | 30 น. | 15 น. | 45 น. |
| `POST /api/admin/login` + ครอบ route ใน `index.ts` | 20 น. | 10 น. | 30 น. |
| `api.ts`: แนบ header + จัดการ 401 + importCompetition | 30 น. | 15 น. | 45 น. |
| `AdminGate` (หน้ากรอกรหัส + ปุ่มออก) ครอบ 2 หน้า | 40 น. | 20 น. | 60 น. |
| Export → fetch+blob | 25 น. | 15 น. | 40 น. |
| ตั้งค่า ACA env + verify prod | 15 น. | 15 น. | 30 น. |
| **รวมงานที่ 1** | | | **~4.0 ชม.** |

ทดสอบที่ต้องครอบ: เข้า `/admin` โดยไม่มีรหัส → เด้ง gate · รหัสผิด → 401 · ยิง `/api/admin/*` ตรงโดยไม่มี header → 401 · export/import ทำงานหลังบัง · `/judge` ยังใช้ได้ปกติ

### งานที่ 2 — Revoke / เปลี่ยนลิงก์กรรมการ
| หัวข้อย่อย | dev | test | รวม |
|-----------|-----|------|-----|
| `adminApi.regenerateToken()` + ปุ่ม + confirm + copy ใน `AdminPage` | 40 น. | 20 น. | 60 น. |
| เพิ่ม `logActivity` ใน endpoint `revoke-token` | 10 น. | 10 น. | 20 น. |
| **รวมงานที่ 2** | | | **~1.3 ชม.** |

ทดสอบที่ต้องครอบ: กดออกลิงก์ใหม่ → ลิงก์เก่า 401 ทันที · ลิงก์ใหม่ใช้ได้ · log ขึ้นรายการ regenerate

### งานที่ 3 — ปรับ UI หน้าแสดงผลคะแนน
| หัวข้อย่อย | dev | test | รวม |
|-----------|-----|------|-----|
| เพิ่มสีสัน (ไฮไลต์อันดับ 1-3, สี header, badge สถานะ) | 45 น. | 15 น. | 60 น. |
| เปลี่ยน section รายละเอียดใช้ `data.results` (ไม่เรียง) | 10 น. | 10 น. | 20 น. |
| **รวมงานที่ 3** | | | **~1.3 ชม.** |

ทดสอบที่ต้องครอบ: ตารางอันดับยังเรียงถูก · section รายละเอียดลำดับคงที่ · สีแสดงผลถูกทุกสถานะ · responsive ไม่พัง

### รวมทั้งหมด
- **dev + test ประมาณ 6.5 - 7 ชม.** (≈ 1 วันทำงาน)
- หมายเหตุ: ยังไม่รวมเวลา bump version/tag/deploy (ดู `docs/07-dev-workflow.md`) และยังไม่มี unit test framework ในโปรเจกต์ (ถ้าจะเพิ่ม automated test ต้อง setup เพิ่ม — ประเมินแยก)
