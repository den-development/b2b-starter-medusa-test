# Faz 1: Builder (Gerekli bağımlılıkları yükleme ve projeyi build etme)
FROM node:20-alpine AS builder

# Gerekli sistem paketlerini kurun
RUN apk update && apk add python3 make g++

# Proje çalışma dizinini ayarlayın
WORKDIR /app

# **Tüm repo içeriğini kopyala** (package.json, yarn.lock, backend/, storefront/ dahil)
# Bu, yarn.lock'un kök dizinde bulunmasını sağlar.
COPY . .

# Bağımlılıkları kur (Monorepo kökündeki lock dosyasına göre)
RUN yarn install --frozen-lockfile --production=false

# Backend klasörü içine geç
WORKDIR /app/backend

# Medusa backend'i build et
RUN yarn build

# Faz 2: Runner (Daha küçük, sadece çalıştırma ortamını içerir)
FROM node:20-alpine AS runner

# Çalışma dizinini ana app klasörüne ayarlayın
WORKDIR /app

# **YALNIZCA GEREKLİ KÖK DOSYALARINI KOPYALA** (Runner fazı için)
COPY package.json yarn.lock ./
RUN yarn install --production=true --frozen-lockfile

# BUILD edilmiş kodu kopyala
COPY --from=builder /app/backend/dist ./backend/dist

# Diğer Gerekli Backend dosyalarını kopyala
COPY --from=builder /app/backend/src ./backend/src
COPY --from=builder /app/backend/medusa-config.js ./backend/medusa-config.js
COPY --from=builder /app/backend/.env.template ./backend/.env.template
COPY --from=builder /app/backend/package.json ./backend/package.json

# Başlangıçtan önce backend dizinine geç
WORKDIR /app/backend

# Medusa'nın varsayılan olarak dinlediği port
ENV PORT 9000
EXPOSE 9000

# Coolify'de başlangıç komutu
CMD ["sh", "-c", "node_modules/.bin/medusa db:migrate && node_modules/.bin/medusa start"]
