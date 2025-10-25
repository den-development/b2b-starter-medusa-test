# Faz 1: Builder (Gerekli bağımlılıkları yükleme ve projeyi build etme)
FROM node:20-alpine AS builder

# Gerekli sistem paketlerini kurun (Medusa ve bazı node modülleri için)
RUN apk update && apk add python3 make g++

# Proje çalışma dizinini ayarlayın
WORKDIR /app

# Corepack'i etkinleştirin ve projede tanımlı Yarn v4 sürümünü kullanın
RUN corepack enable && corepack prepare yarn@4.4.0 --activate

# TÜM REPO İÇERİĞİNİ KOPYALA
COPY . .

# HATA AYIKLAMA: Kök dizindeki dosyaları kontrol et (Opsiyonel, hata verirse kaldırılabilir)
# RUN ls -al /app

# Satır 25: BAĞIMLILIKLARI KUR (Tüm bağımlılıkları içerir. Yarn v4 için --immutable kullanın)
# Monorepo'larda, kök dizinde paketi bulmak için package.json ve .yarnrc.yml şarttır.
RUN yarn install --immutable

# Backend klasörü içine geç
WORKDIR /app/backend

# Medusa backend'i build et
RUN yarn build


# Faz 2: Runner (Daha küçük, sadece çalıştırma ortamını içerir)
FROM node:20-alpine AS runner

# Çalışma dizinini ana app klasörüne ayarlayın
WORKDIR /app

# 1. KÖK BAĞIMLILIK DOSYALARINI BUILDER FAZINDAN KOPYALA
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/yarn.lock ./yarn.lock
# Monorepo/Yarn v4 kullanıyorsanız bu dosya olmazsa olmazdır.
COPY --from=builder /app/.yarnrc.yml ./.yarnrc.yml 

# Satır 47: Sadece üretim bağımlılıklarını kur (Yarn v4 için --production)
# Monorepo'da sadece üretim bağımlılıklarını kurmak için `--production` ve `--immutable` kullanın
RUN yarn install --immutable --production 

# 2. BUILD edilmiş kodu ve diğer gerekli dosyaları kopyala
COPY --from=builder /app/backend/dist ./backend/dist

# Diğer Gerekli Backend dosyalarını kopyala
COPY --from=builder /app/backend/src ./backend/src
COPY --from=builder /app/backend/medusa-config.js ./backend/medusa-config.js
COPY --from=builder /app/backend/.env.template ./backend/.env.template
COPY --from=builder /app/backend/package.json ./backend/package.json
COPY --from=builder /app/backend/data ./backend/data

# Başlangıçtan hemen önce backend dizinine geç
WORKDIR /app/backend

# Medusa'nın varsayılan olarak dinlediği port
ENV PORT 9000
EXPOSE 9000

# Coolify'de başlangıç komutu (Migration ve Başlatma)
CMD ["sh", "-c", "node_modules/.bin/medusa db:migrate && node_modules/.bin/medusa start"]
