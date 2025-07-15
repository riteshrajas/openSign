# ---------------------------
# Stage 1: Download Fonts and PDFium
# ---------------------------
FROM ruby:3.2-alpine3.19 AS download

WORKDIR /fonts

RUN apk add --no-cache fontforge wget tar

# Download required fonts and PDFium binary
RUN wget https://github.com/satbyy/go-noto-universal/releases/download/v7.0/GoNotoKurrent-Regular.ttf && \
    wget https://github.com/satbyy/go-noto-universal/releases/download/v7.0/GoNotoKurrent-Bold.ttf && \
    wget https://github.com/impallari/DancingScript/raw/master/fonts/DancingScript-Regular.otf && \
    wget https://cdn.jsdelivr.net/gh/notofonts/notofonts.github.io/fonts/NotoSansSymbols2/hinted/ttf/NotoSansSymbols2-Regular.ttf && \
    wget https://github.com/Maxattax97/gnu-freefont/raw/master/ttf/FreeSans.ttf && \
    wget https://github.com/impallari/DancingScript/raw/master/OFL.txt && \
    wget -O pdfium-linux.tgz "https://github.com/docusealco/pdfium-binaries/releases/latest/download/pdfium-linux-$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/').tgz" && \
    mkdir -p /pdfium-linux && \
    tar -xzf pdfium-linux.tgz -C /pdfium-linux

# Merge FreeSans with Symbols
RUN fontforge -lang=py -c \
  'font1 = fontforge.open("FreeSans.ttf"); \
   font2 = fontforge.open("NotoSansSymbols2-Regular.ttf"); \
   font1.mergeFonts(font2); \
   font1.generate("FreeSans.ttf")'

# ---------------------------
# Stage 2: Compile JS/CSS with Webpack
# ---------------------------
FROM ruby:3.2-alpine3.19 AS webpack

WORKDIR /app

ENV RAILS_ENV=production \
    NODE_ENV=production

# Install dependencies for native gems and frontend build
RUN apk add --no-cache \
  nodejs \
  yarn \
  git \
  build-base \
  ruby-dev \
  openssl-dev \
  libffi-dev \
  mysql-dev \
  mariadb-dev \
  postgresql-dev \
  pkgconfig

# Install gems
COPY Gemfile Gemfile.lock ./
RUN gem install bundler:2.5.3 && bundle install --without development test

# Install Node modules
COPY package.json yarn.lock ./
RUN yarn install

# Copy frontend source and config
COPY bin/shakapacker ./bin/shakapacker
COPY config/webpack config/webpack
COPY config/shakapacker.yml config/shakapacker.yml
COPY postcss.config.js tailwind.*.config.js ./
COPY app/javascript app/javascript
COPY app/views app/views

# Build webpack assets
RUN chmod +x ./bin/shakapacker && ./bin/shakapacker

# Verify Shakapacker dependencies
RUN yarn list --depth=0 && yarn check --verify-tree

# Debugging step: Check Shakapacker script
RUN ls -l ./bin/shakapacker && cat ./bin/shakapacker

# Ensure executable permissions
RUN chmod +x ./bin/shakapacker && ./bin/shakapacker

# ---------------------------
# Stage 3: Final Runtime Image
# ---------------------------
FROM ruby:3.2-alpine3.19 AS app

WORKDIR /app

ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD=/lib/libgcompat.so.0 \
    OPENSSL_CONF=/app/openssl_legacy.cnf

# Add Alpine edge community repo and runtime deps
RUN echo "@edge https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk add --no-cache \
    sqlite-dev mariadb-dev libpq-dev \
    vips-dev@edge libheif@edge vips-heif@edge \
    gcompat ttf-freefont openssl

# Clean out default FreeSans to avoid conflicts
RUN mkdir /fonts && rm -f /usr/share/fonts/freefont/FreeSans.otf

# Enable OpenSSL legacy provider
RUN echo $'.include = /etc/ssl/openssl.cnf\n\
[provider_sect]\ndefault = default_sect\nlegacy = legacy_sect\n\
[default_sect]\nactivate = 1\n\
[legacy_sect]\nactivate = 1' > /app/openssl_legacy.cnf

# Install native build dependencies (TEMPORARILY)
RUN apk add --no-cache \
  build-base \
  ruby-dev \
  openssl-dev \
  libffi-dev \
  mysql-dev \
  postgresql-dev \
  pkgconfig

# Install gems
COPY Gemfile Gemfile.lock ./
RUN gem install bundler:2.5.3 && bundle install --without development test

# Remove build deps to slim image
# RUN apk del build-base ruby-dev openssl-dev libffi-dev mysql-dev postgresql-dev pkgconfig && \
#     rm -rf ~/.bundle /usr/local/bundle/cache


# Copy app code
COPY bin bin
COPY app app
COPY config config
COPY db/migrate db/migrate
COPY log log
COPY lib lib
COPY public public
COPY tmp tmp
COPY LICENSE README.md Rakefile config.ru .version ./
COPY .version ./public/version

# Copy fonts and PDFium from download stage
COPY --from=download /fonts/GoNotoKurrent-Regular.ttf /fonts/
COPY --from=download /fonts/GoNotoKurrent-Bold.ttf /fonts/
COPY --from=download /fonts/DancingScript-Regular.otf /fonts/
COPY --from=download /fonts/OFL.txt /fonts/
COPY --from=download /fonts/FreeSans.ttf /usr/share/fonts/freefont/
COPY --from=download /pdfium-linux/lib/libpdfium.so /usr/lib/libpdfium.so
COPY --from=download /pdfium-linux/licenses/pdfium.txt /usr/lib/libpdfium-LICENSE.txt

# Copy compiled assets from webpack stage
COPY --from=webpack /app/public/packs ./public/packs

# Link fonts directory to public
RUN ln -s /fonts /app/public/fonts

# Precompile bootsnap cache
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# Runtime working directory
WORKDIR /data/docuseal
ENV WORKDIR=/data/docuseal

EXPOSE 3000

CMD ["/app/bin/bundle", "exec", "puma", "-C", "/app/config/puma.rb", "--dir", "/app"]
