# Faz 1: Builder
FROM node:20-alpine AS builder

# Gerekli sistem paketlerini kurun
RUN apk update && apk add python3 make g++

# KÖK WORKDIR'I MEDUSA PROJE KLASÖRÜ OLARAK AYARLAYIN
# Bütün operasyonlar /app/backend içinde gerçekleşecek.
WORKDIR /app/backend

# Corepack'i etkinleştirin
RUN corepack enable && corepack prepare yarn@4.4.0 --activate

# TÜM REPO İÇERİĞİNİ KOPYALA
# Bu, /app/backend'in içine kopyalanacak. (Paket ve diğer dosyalar)
COPY . /app/backend

# package.json ve yarn.lock'ın /app/backend içinde olduğunu varsayarak
RUN yarn install --immutable

# Medusa backend'i build et
RUN yarn build


# Faz 2: Runner
FROM node:20-alpine AS runner

# KÖK WORKDIR'I YİNE MEDUSA PROJE KLASÖRÜ OLARAK AYARLAYIN
WORKDIR /app/backend

# 1. KÖK BAĞIMLILIK DOSYALARINI BUILDER FAZINDAN KOPYALA
COPY --from=builder /app/backend/package.json ./package.json
COPY --from=builder /app/backend/yarn.lock ./yarn.lock
# .yarnrc.yml kopyalanması (Yarn v4 için kritik)
COPY --from=builder /app/backend/.yarnrc.yml ./.yarnrc.yml || true

# Sadece üretim bağımlılıklarını kur (WORKDIR zaten /app/backend)
RUN yarn install --immutable --production

# 2. BUILD edilmiş kodu ve diğer gerekli dosyaları kopyala
COPY --from=builder /app/backend/dist ./dist

# Diğer Gerekli Backend dosyalarını kopyala
COPY --from=builder /app/backend/src ./src
COPY --from=builder /app/backend/medusa-config.js ./medusa-config.js
COPY --from=builder /app/backend/.env.template ./.env.template
COPY --from=builder /app/backend/data ./data

# Medusa'nın varsayılan olarak dinlediği port
ENV PORT 9000
EXPOSE 9000

# Başlangıç komutu
CMD ["sh", "-c", "node_modules/.bin/medusa db:migrate && node_modules/.bin/medusa start"]
