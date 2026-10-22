# Requirements Document

## Introduction

โปรเจกต์ score-app กำลังย้ายโครงสร้างพื้นฐานจาก Microsoft Azure ไปยัง AWS (ตามข้อเสนอใน `docs/08-aws-migration-proposal.md` และสถาปัตยกรรมเป้าหมายใน `docs/10-aws-architecture.md`) ฟีเจอร์นี้มีเป้าหมายเพื่อ "ทำความสะอาด" repository โดยนำไฟล์และเนื้อหาที่ผูกกับ Azure โดยเฉพาะ (Azure-only artifacts) ออกหรือปรับให้ไม่อ้างถึง Azure เป็นเป้าหมาย deploy จริงอีกต่อไป ขณะเดียวกันต้องรักษาเอกสารและทรัพยากรที่เกี่ยวกับ AWS ไว้ครบถ้วน รักษาให้โค้ดยังคอมไพล์/บิลด์ผ่าน แล้วบันทึกผลลัพธ์เป็น commit "start version" เพื่อใช้เป็นจุดตั้งต้น (baseline) สำหรับงาน AWS

ขอบเขตของฟีเจอร์นี้ครอบคลุมเฉพาะการจัดการไฟล์ภายใน repository, การสร้าง commit เพื่อความปลอดภัย (safety/pre-cleanup snapshot) ก่อนเริ่มลบ และการสร้าง commit baseline ("start version") หลังบิลด์ผ่านเท่านั้น ไม่รวมการสร้างโครงสร้างพื้นฐานบน AWS หรือการเขียน CI/CD ใหม่สำหรับ AWS (งานเหล่านั้นเป็นเฟสถัดไป)

## Glossary

- **Repository**: โครงสร้างไฟล์ทั้งหมดของโปรเจกต์ score-app ภายใต้ git ที่ root `score-app/`
- **Developer**: ผู้พัฒนาหรือ AI agent ที่สั่งและตรวจสอบการทำความสะอาด repository
- **Azure_Artifact**: ไฟล์หรือบล็อกเนื้อหาที่มีอยู่เพื่อรองรับการ deploy บน Azure โดยเฉพาะ ได้แก่ `.github/workflows/deploy.yml`, `docs/05-deployment.md`, ส่วน "Azure resources" และบรรทัด deploy ใน `AGENTS.md`, หัวข้อ deploy ที่อ้าง Azure ใน `docs/03-tech-stack.md`, เนื้อหาที่อ้าง `az`/ACA/`AZURE_CREDENTIALS` ใน `docs/07-dev-workflow.md`, คอมเมนต์ที่อ้าง Azure Files/`nobrl` ใน `Dockerfile`
- **AWS_Artifact**: ไฟล์ที่จัดทำขึ้นสำหรับเป้าหมาย AWS ได้แก่ `docs/08-aws-migration-proposal.md`, `docs/10-aws-architecture.md`, `docs/11-aws-cost-inputs.md` รวมถึงไฟล์ IaC หรือ workflow ใด ๆ ที่สร้างขึ้นเพื่อ AWS
- **Application_Code**: ซอร์สโค้ดและการตั้งค่าของแอป ได้แก่ไฟล์ภายใต้ `backend/` และ `frontend/` และ `Dockerfile`
- **Build_Process**: ขั้นตอนบิลด์ของโปรเจกต์ — `npm run build` ของ `backend/` และของ `frontend/`
- **Cleanup_Operation**: การดำเนินการทำความสะอาด Repository ตามฟีเจอร์นี้ทั้งหมด
- **Baseline_Commit**: git commit ที่บันทึกสถานะ Repository หลังทำความสะอาดเสร็จและ Build_Process ผ่าน เพื่อใช้เป็นจุดตั้งต้น (start version) ของงาน AWS
- **Safety_Commit**: git commit ที่บันทึกสถานะ Repository ปัจจุบัน (pre-cleanup snapshot) ก่อน Cleanup_Operation จะลบหรือแก้ไขไฟล์ใด ๆ เพื่อให้ rollback กลับไปยังสถานะก่อนทำความสะอาดได้ง่าย — เป็นคนละ commit กับ Baseline_Commit
- **Cleanup_Manifest**: รายการที่ Cleanup_Operation จัดทำขึ้นก่อนลงมือเปลี่ยนแปลงไฟล์ โดยแบ่งเป็นกลุ่มชัดเจน ได้แก่ กลุ่มไฟล์ที่จะ "ลบทั้งไฟล์" กลุ่มไฟล์ที่จะ "แก้ไขเฉพาะบางส่วน" (พร้อมระบุส่วนที่จะแก้) และกลุ่มไฟล์ AWS_Artifact/Application_Code ที่ "คงไว้ (ยกเว้น)"
- **Ignored_Secret_File**: ไฟล์ที่ห้าม commit และถูกกำหนดใน `.gitignore` แล้ว ได้แก่ `backend/.env` และ `backend/prisma/dev.db`

## Requirements

### Requirement 1: ระบุและจัดประเภทไฟล์ Azure เป็น Cleanup_Manifest ก่อนลบ

**User Story:** ในฐานะ Developer ฉันต้องการให้ระบุไฟล์และเนื้อหาที่เป็น Azure_Artifact ทั้งหมดออกมาเป็นรายการ (Cleanup_Manifest) ที่แยกกลุ่มชัดเจนและให้ฉันตรวจอนุมัติก่อนลงมือลบจริง เพื่อให้มั่นใจว่าจะไม่ลบไฟล์ที่เกี่ยวกับ AWS หรือไฟล์ของแอปโดยผิดพลาด

#### Acceptance Criteria

1. WHEN Cleanup_Operation เริ่มต้น THE Cleanup_Operation SHALL จัดทำ Cleanup_Manifest ที่แยกรายการออกเป็นสามกลุ่มชัดเจน ได้แก่ กลุ่ม "ลบทั้งไฟล์" กลุ่ม "แก้ไขเฉพาะบางส่วน" และกลุ่ม "คงไว้ (ยกเว้น)"
2. THE Cleanup_Operation SHALL จัดไฟล์ที่มีเนื้อหาเฉพาะ Azure ทั้งไฟล์ (`.github/workflows/deploy.yml` และ `docs/05-deployment.md`) ไว้ในกลุ่ม "ลบทั้งไฟล์" ของ Cleanup_Manifest
3. THE Cleanup_Operation SHALL จัดไฟล์ที่มีทั้งเนื้อหา Azure และเนื้อหาที่ยังใช้ได้ (`AGENTS.md`, `docs/03-tech-stack.md`, `docs/07-dev-workflow.md`, `Dockerfile`) ไว้ในกลุ่ม "แก้ไขเฉพาะบางส่วน" ของ Cleanup_Manifest พร้อมระบุส่วนที่จะแก้ในแต่ละไฟล์
4. WHERE ไฟล์ถูกจัดประเภทเป็น AWS_Artifact หรือ Application_Code THE Cleanup_Operation SHALL จัดไฟล์นั้นไว้ในกลุ่ม "คงไว้ (ยกเว้น)" ของ Cleanup_Manifest และไม่รวมในกลุ่มลบหรือแก้ไข
5. BEFORE Cleanup_Operation ลบหรือแก้ไขไฟล์ใด ๆ THE Cleanup_Operation SHALL แสดง Cleanup_Manifest ต่อ Developer เพื่อให้ตรวจและอนุมัติ
6. WHILE Developer ยังไม่อนุมัติ Cleanup_Manifest THE Cleanup_Operation SHALL ไม่ลบหรือแก้ไขไฟล์ใด ๆ

### Requirement 2: สร้าง Safety_Commit ก่อนเริ่มลบเพื่อ rollback

**User Story:** ในฐานะ Developer ฉันต้องการให้มีการ commit สถานะปัจจุบันของ Repository ไว้หนึ่งครั้งก่อนเริ่มลบหรือแก้ไขไฟล์ เพื่อให้สามารถ rollback กลับไปยังสถานะก่อนทำความสะอาดได้ง่ายหากเกิดปัญหา

#### Acceptance Criteria

1. BEFORE Cleanup_Operation ลบหรือแก้ไขไฟล์ตาม Cleanup_Manifest THE Cleanup_Operation SHALL สร้าง Safety_Commit ที่บันทึกสถานะ Repository ปัจจุบัน
2. THE Safety_Commit SHALL ใช้ข้อความ commit ตาม Conventional Commits โดยขึ้นต้นด้วย `chore:` และสื่อว่าเป็น pre-cleanup snapshot สำหรับ rollback
3. BEFORE สร้าง Safety_Commit THE Cleanup_Operation SHALL ตรวจสอบว่า Ignored_Secret_File (`backend/.env`, `backend/prisma/dev.db`) ไม่ถูก stage เข้า Safety_Commit
4. IF Ignored_Secret_File ปรากฏในรายการ stage THEN THE Cleanup_Operation SHALL นำไฟล์นั้นออกจาก stage ก่อนสร้าง Safety_Commit
5. IF working tree มีการเปลี่ยนแปลงที่ยังไม่ commit ก่อนเริ่ม Cleanup_Operation THEN THE Cleanup_Operation SHALL รายงานการเปลี่ยนแปลงนั้นต่อ Developer และรอการยืนยันก่อนรวมเข้า Safety_Commit
6. THE Cleanup_Operation SHALL บันทึกตัวอ้างอิง (commit hash หรือ ref) ของ Safety_Commit ไว้เพื่อให้ Developer ใช้ rollback กลับไปยังสถานะก่อนทำความสะอาดได้
7. THE Cleanup_Operation SHALL ไม่ push Safety_Commit เข้า main โดยอัตโนมัติ เว้นแต่ Developer อนุมัติอย่างชัดเจน

### Requirement 3: ลบ Azure_Artifact ที่เป็นไฟล์เฉพาะ Azure

**User Story:** ในฐานะ Developer ฉันต้องการให้ไฟล์ที่มีไว้เพื่อ deploy บน Azure โดยเฉพาะถูกนำออกจาก Repository เพื่อให้ repository ไม่มี CI/CD และเอกสารที่ชี้ไป Azure อีก

#### Acceptance Criteria

1. WHEN Cleanup_Operation ดำเนินการลบ THE Cleanup_Operation SHALL ลบไฟล์ `.github/workflows/deploy.yml` ออกจาก Repository
2. WHEN Cleanup_Operation ดำเนินการลบ THE Cleanup_Operation SHALL ลบไฟล์ `docs/05-deployment.md` ออกจาก Repository
3. THE Cleanup_Operation SHALL คงไฟล์ `.github/workflows/ci.yml` ไว้ใน Repository โดยไม่ลบ
4. IF ไฟล์ที่กำหนดให้ลบไม่มีอยู่ใน Repository แล้ว THEN THE Cleanup_Operation SHALL บันทึกสถานะว่าไฟล์นั้นถูกลบไปแล้วและดำเนินการขั้นตอนถัดไปต่อ

### Requirement 4: แก้ไขไฟล์ที่มีเนื้อหา Azure ปนกับเนื้อหาที่ยังใช้ได้

**User Story:** ในฐานะ Developer ฉันต้องการให้ไฟล์ที่ปนเนื้อหา Azure ถูกแก้ไขให้ไม่อ้าง Azure เป็นเป้าหมาย deploy จริง เพื่อให้เอกสารและคำแนะนำไม่ชี้นำไปยังโครงสร้างพื้นฐานเดิมที่กำลังเลิกใช้

#### Acceptance Criteria

1. WHEN Cleanup_Operation แก้ไข `AGENTS.md` THE Cleanup_Operation SHALL นำส่วน "Azure resources" และการอ้าง ACA/ACR/`AZURE_CREDENTIALS`/`az` ที่บรรยาย Azure เป็นเป้าหมาย deploy จริงออก
2. WHEN Cleanup_Operation แก้ไข `docs/03-tech-stack.md` THE Cleanup_Operation SHALL แก้หัวข้อการ deploy ให้ไม่ระบุ Azure Container Apps เป็นเป้าหมาย deploy จริง
3. WHEN Cleanup_Operation แก้ไข `docs/07-dev-workflow.md` THE Cleanup_Operation SHALL นำขั้นตอนและการอ้างที่ผูกกับ Azure (`az acr build`, `az containerapp update`, `AZURE_CREDENTIALS`, workflow "CD - Deploy to Azure Container Apps") ออก
4. WHEN Cleanup_Operation แก้ไข `Dockerfile` THE Cleanup_Operation SHALL แก้คอมเมนต์ที่อ้าง Azure Files หรือ `nobrl` ให้ไม่ผูกกับ Azure
5. WHILE Cleanup_Operation แก้ไขไฟล์ประเภท "แก้ไขเฉพาะบางส่วน" THE Cleanup_Operation SHALL คงเนื้อหาที่ไม่เกี่ยวกับ Azure ในไฟล์เดียวกันไว้ครบถ้วน
6. WHERE ไฟล์ `Dockerfile` ถูกแก้ไข THE Cleanup_Operation SHALL คงคำสั่งบิลด์และ runtime ที่จำเป็นต่อการทำงานของแอป (multi-stage build, `prisma generate`, `CMD`) ไว้โดยไม่เปลี่ยนพฤติกรรม

### Requirement 5: รักษา AWS_Artifact และโค้ดของแอปไว้ครบถ้วน

**User Story:** ในฐานะ Developer ฉันต้องการให้เอกสาร/ทรัพยากรที่เกี่ยวกับ AWS และซอร์สโค้ดของแอปไม่ถูกแตะต้องระหว่างการทำความสะอาด เพื่อรักษาเป้าหมายงาน AWS และฟังก์ชันการทำงานของแอปไว้

#### Acceptance Criteria

1. THE Cleanup_Operation SHALL คงไฟล์ `docs/08-aws-migration-proposal.md`, `docs/10-aws-architecture.md` และ `docs/11-aws-cost-inputs.md` ไว้โดยไม่ลบ
2. WHERE มีไฟล์ AWS_Artifact ที่เป็น IaC หรือ workflow สำหรับ AWS อยู่ใน Repository THE Cleanup_Operation SHALL คงไฟล์นั้นไว้โดยไม่ลบ
3. THE Cleanup_Operation SHALL ไม่แก้ไขตรรกะของ Application_Code ภายใต้ `backend/src/` และ `frontend/src/`
4. IF การแก้ไขไฟล์ใดจะกระทบต่อการทำงานของ Application_Code THEN THE Cleanup_Operation SHALL ยกเลิกการแก้ไขนั้นและรายงานต่อ Developer

### Requirement 6: ยืนยันว่าบิลด์ผ่านหลังทำความสะอาด

**User Story:** ในฐานะ Developer ฉันต้องการให้โปรเจกต์ยังบิลด์ผ่านหลังการทำความสะอาด เพื่อให้ Baseline_Commit เป็นจุดตั้งต้นที่ใช้งานได้จริง

#### Acceptance Criteria

1. WHEN Cleanup_Operation ทำความสะอาดไฟล์เสร็จ THE Build_Process SHALL บิลด์ `backend/` ผ่านโดยไม่มี error
2. WHEN Cleanup_Operation ทำความสะอาดไฟล์เสร็จ THE Build_Process SHALL บิลด์ `frontend/` ผ่านโดยไม่มี error
3. IF Build_Process ล้มเหลวหลังการทำความสะอาด THEN THE Cleanup_Operation SHALL รายงาน error ต่อ Developer และระงับการสร้าง Baseline_Commit

### Requirement 7: สร้าง Baseline_Commit "start version" หลังบิลด์ผ่าน

**User Story:** ในฐานะ Developer ฉันต้องการให้ผลลัพธ์การทำความสะอาดถูกบันทึกเป็น commit baseline ("start version") เดียวหลังบิลด์ผ่าน เพื่อเป็นจุดเริ่มต้นที่ชัดเจนสำหรับงาน AWS โดยแยกจาก Safety_Commit ที่สร้างไว้ก่อนเริ่มลบ

#### Acceptance Criteria

1. WHEN Build_Process ผ่านและ Developer อนุมัติให้ commit THE Cleanup_Operation SHALL สร้าง Baseline_Commit ที่รวมการลบและการแก้ไขไฟล์ทั้งหมดของ Cleanup_Operation
2. THE Cleanup_Operation SHALL สร้าง Baseline_Commit เป็น commit แยกต่างหากจาก Safety_Commit โดยไม่รวมสองสิ่งนี้เป็น commit เดียวกัน
3. THE Baseline_Commit SHALL ใช้ข้อความ commit ตาม Conventional Commits โดยขึ้นต้นด้วย `chore:` และสื่อว่าเป็นการนำ Azure ออกเพื่อตั้งต้น (start version) งาน AWS
4. BEFORE สร้าง Baseline_Commit THE Cleanup_Operation SHALL ตรวจสอบว่า Ignored_Secret_File (`backend/.env`, `backend/prisma/dev.db`) ไม่ถูก stage เข้า commit
5. IF Ignored_Secret_File ปรากฏในรายการ stage THEN THE Cleanup_Operation SHALL นำไฟล์นั้นออกจาก stage ก่อนสร้าง Baseline_Commit
6. THE Cleanup_Operation SHALL ไม่ push Baseline_Commit เข้า main โดยอัตโนมัติ เว้นแต่ Developer อนุมัติอย่างชัดเจน
7. WHERE Developer ยังไม่อนุมัติการ commit THE Cleanup_Operation SHALL แสดงรายการการเปลี่ยนแปลงที่เตรียมไว้โดยไม่สร้าง Baseline_Commit
