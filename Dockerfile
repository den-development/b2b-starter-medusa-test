# Faz 1: Builder (Gerekli bağımlılıkları yükleme ve projeyi build etme)
FROM node:20-alpine AS builder

# Gerekli sistem paketlerini kurun (Medusa ve bazı node modülleri için)
RUN apk update && apk add python3 make g++

# Proje çalışma dizinini ayarlayın
WORKDIR /app

# Corepack'i etkinleştirin ve projede tanımlı Yarn v4 sürümünü kullanın
# Bu, "packageManager": "yarn@4.4.0" hatasını çözer.
RUN corepack enable && corepack prepare yarn@4.4.0 --activate

# TÜM REPO İÇERİĞİNİ KOPYALA
# Bu, kök dizindeki package.json, yarn.lock ve backend/ klasörlerini içerir.
COPY . .

# Bağımlılıkları kur (root'taki yarn.lock'a göre)
RUN yarn install --frozen-lockfile --production=false

# Backend klasörü içine geç
WORKDIR /app/backend

# Medusa backend'i build et
RUN yarn build


# Faz 2: Runner (Daha küçük, sadece çalıştırma ortamını içerir)
FROM node:20-alpine AS runner

# Çalışma dizinini ana app klasörüne ayarlayın
WORKDIR /app

# 1. Corepack/Yarn v4'ü runner imajında da etkinleştir (Build için değil, çalıştırma komutları için)
# RUN corepack enable  # Node 20'de varsayılan olduğu için bu satır gereksiz olabilir.

# 2. KÖK BAĞIMLILIK DOSYALARINI BUILDER FAZINDAN KOPYALA
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/yarn.lock ./yarn.lock

# 3. Sadece üretim bağımlılıklarını kur
# (Zaten builder'dan node_modules kopyalamadık, bu yüzden tekrar kurmalıyız)
RUN yarn install --production=true --frozen-lockfile

# 4. BUILD edilmiş kodu ve diğer gerekli dosyaları kopyala
COPY --from=builder /app/backend/dist ./backend/dist

# Diğer Gerekli Backend dosyalarını kopyala (src, config, vb.)
COPY --from=builder /app/backend/src ./backend/src
COPY --from=builder /app/backend/medusa-config.js ./backend/medusa-config.js
COPY --from=builder /app/backend/.env.template ./backend/.env.template
COPY --from=builder /app/backend/package.json ./backend/package.json
COPY --from=builder /app/backend/data ./backend/data  # Seed data/SQLite için

# Başlangıçtan hemen önce backend dizinine geç
WORKDIR /app/backend

# Medusa'nın varsayılan olarak dinlediği port
ENV PORT 9000
EXPOSE 9000

# Coolify'de başlangıç komutu (Migration ve Başlatma)
# Node_modules root'ta olduğu için "node_modules/.bin/" kullanıyoruz.
CMD ["sh", "-c", "node_modules/.bin/medusa db:migrate && node_modules/.bin/medusa start"]
