# Faz 1: Builder (Tüm repoyu al ve kökte bağımlılıkları kur)
FROM node:20-alpine AS builder

# Gerekli sistem paketlerini kurun (Medusa için)
RUN apk update && apk add python3 make g++

# 1. Monorepo Kök Dizinini Ayarla
# Tüm repoyu kopyalamak için çalışma dizinini /app olarak ayarla
WORKDIR /app

# 2. Corepack/Yarn v4'ü etkinleştir
RUN corepack enable && corepack prepare yarn@4.4.0 --activate

# 3. TÜM REPO İÇERİĞİNİ KOPYALA
# package.json, yarn.lock, .yarnrc.yml ve backend/ klasörleri /app içine kopyalanır.
COPY . .

# 4. Bağımlılıkları Monorepo Kökünde Kur
# Bu, tüm Workspaces'in bağımlılıklarını /app/node_modules içine kuracaktır.
RUN yarn install --immutable

# 5. Medusa Backend klasörü içine geç
WORKDIR /app/backend

# 6. Medusa backend'i build et
# Artık /app/backend içindeyiz, yarn build komutu bu alt paketi build edecektir.
RUN yarn build


# Faz 2: Runner (Sadece production bağımlılıklarını ve build edilmiş kodu içerir)
FROM node:20-alpine AS runner

# 1. Çalışma dizinini Runner'da bağımlılıkları kurmak için root'a ayarla
WORKDIR /app

# 2. Kök Bağımlılık Dosyalarını Kopyala
# Bu, Runner'ın production bağımlılıklarını kurabilmesi için gereklidir.
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/yarn.lock ./yarn.lock
COPY --from=builder /app/.yarnrc.yml ./.yarnrc.yml || true

# 3. Runner'da sadece production bağımlılıklarını kur
# node_modules klasörü /app/node_modules içine kurulur.
RUN yarn install --immutable --production 

# 4. BUILD edilmiş backend klasörünü kopyala
# Bu komut, /app/backend klasörünü ve içindeki build çıktılarını (/app/backend/dist) kopyalar.
COPY --from=builder /app/backend /app/backend

# 5. Başlangıçtan önce çalışma dizinini tekrar backend'e ayarla
# Medusa uygulaması buradan başlatılmalıdır.
WORKDIR /app/backend

# Medusa'nın varsayılan olarak dinlediği port
ENV PORT 9000
EXPOSE 9000

# Coolify'de başlangıç komutu (Migration ve Başlatma)
# node_modules /app'de olduğu için, /app/node_modules/.bin/medusa'yı çalıştırıyoruz.
CMD ["sh", "-c", "node_modules/.bin/medusa db:migrate && node_modules/.bin/medusa start"]
