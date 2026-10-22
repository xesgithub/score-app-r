# ---------- Stage 1: build frontend ----------
FROM node:22-slim AS frontend
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# ---------- Stage 2: build backend ----------
FROM node:22-slim AS backend
WORKDIR /app/backend
COPY backend/package*.json ./
RUN npm ci
COPY backend/ ./
RUN npx prisma generate && npm run build

# ---------- Stage 3: runtime ----------
FROM node:22-slim AS runtime
WORKDIR /app

# openssl จำเป็นสำหรับ Prisma
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# backend: package + node_modules (prod) + compiled dist + prisma
COPY backend/package*.json ./
RUN npm ci --omit=dev
COPY --from=backend /app/backend/node_modules/.prisma ./node_modules/.prisma
COPY --from=backend /app/backend/node_modules/@prisma ./node_modules/@prisma
COPY --from=backend /app/backend/dist ./dist
COPY backend/prisma ./prisma

# frontend build -> เสิร์ฟจาก ./public
COPY --from=frontend /app/frontend/dist ./public

# ข้อมูล SQLite เก็บบน persistent volume ที่ mount ไว้ /data (AWS: EFS/EBS) — ถาวรแม้ scale-to-zero
ENV DATABASE_URL="file:/data/prod.db"
ENV PORT=8080
ENV NODE_ENV=production
EXPOSE 8080

# ตอน start: apply migration + seed (idempotent) แล้วรัน server
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/seed.js && node dist/index.js"]
