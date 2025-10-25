# Faz 1: Builder (Bu faz doğru çalışıyor)
FROM node:20-alpine AS builder
RUN apk update && apk add python3 make g++

WORKDIR /app
# 1. TÜM REPO İÇERİĞİNİ KOPYALA
COPY . .

# 2. BAĞIMLILIKLARI KUR (Kök yarn.lock'a göre)
RUN yarn install --frozen-lockfile --production=false

# Backend klasörü içine geçip build et
WORKDIR /app/backend
RUN yarn build

# Faz 2: Runner (Daha küçük, sadece çalıştırma ortamını içerir)
FROM node:20-alpine AS runner

# Çalışma dizinini ana app klasörüne ayarlayın
WORKDIR /app

# **1. KÖK BAĞIMLILIK DOSYALARINI BUILDER FAZINDAN KOPYALA**
# Bu, yarn.lock'un runner imajına dahil edilmesini sağlar
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/yarn.lock ./yarn.lock
COPY --from=builder /app/node_modules ./node_modules
# Not: node_modules'u kopyalayarak yarn install'ı atlayabiliriz, ama Medusa'da
# bazı native modüller yeniden kuruluma ihtiyaç duyabilir. En güvenlisi kopyalayıp tekrar kurmak.

# Alternatif ve Daha Temiz Yol: Kök bağımlılıklarını yeniden kur
# Runner Fazında sadece üretim bağımlılıklarını kurmak için.
# COPY --from=builder /app/package.json ./package.json
# COPY --from=builder /app/yarn.lock ./yarn.lock
RUN yarn install --production=true --frozen-lockfile

# BUILD edilmiş kodu kopyala
COPY --from=builder /app/backend/dist ./backend/dist

# Diğer Gerekli Backend dosyalarını kopyala (src, config, vb.)
COPY --from=builder /app/backend/src ./backend/src
COPY --from=builder /app/backend/medusa-config.js ./backend/medusa-config.js
COPY --from=builder /app/backend/.env.template ./backend/.env.template
COPY --from=builder /app/backend/package.json ./backend/package.json
COPY --from=builder /app/backend/data ./backend/data  # Seed data için

# Başlangıçtan hemen önce backend dizinine geç
WORKDIR /app/backend

# Medusa'nın varsayılan olarak dinlediği port
ENV PORT 9000
EXPOSE 9000

# Coolify'de başlangıç komutu (Migration ve Başlatma)
CMD ["sh", "-c", "node_modules/.bin/medusa db:migrate && node_modules/.bin/medusa start"]
