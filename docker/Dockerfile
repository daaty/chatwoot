# pre-build stage
FROM node:18-alpine as node
FROM ruby:3.3.3-alpine3.19 AS pre-builder

ARG NODE_VERSION="18.19.1"
ARG PNPM_VERSION="10.2.0"
ENV NODE_VERSION=${NODE_VERSION}
ENV PNPM_VERSION=${PNPM_VERSION}

# ARG default to production settings
ARG BUNDLE_WITHOUT="development:test"
ARG SECRET_KEY_BASE
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}
ENV SECRET_KEY_BASE=${SECRET_KEY_BASE}
ENV BUNDLER_VERSION=2.5.11

ARG RAILS_ENV=production
ENV RAILS_ENV ${RAILS_ENV}
ENV BUNDLE_PATH="/gems"
ENV NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"

# Install base dependencies
RUN apk update && apk add --no-cache \
    openssl \
    tar \
    build-base \
    tzdata \
    postgresql-dev \
    postgresql-client \
    git \
    curl \
    xz \
    musl \
    ruby-full \
    ruby-dev \
    gcc \
    make \
    musl-dev \
    openssl-dev \
    g++ \
    linux-headers \
    vips \
    && mkdir -p /var/app \
    && gem install bundler -v ${BUNDLER_VERSION}

# Setup Node and PNPM
COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && npm install -g pnpm@${PNPM_VERSION}

WORKDIR /app

# Copy essential files first
COPY Gemfile Gemfile.lock ./

# Configure bundler and install gems
RUN bundle config set --local force_ruby_platform true \
    && bundle config set deployment true \
    && bundle config set without 'development test' \
    && bundle config set path '/gems' \
    && bundle config get without \
    && bundle install -j 4 -r 3 --without development test

# Install node dependencies
COPY package.json pnpm-lock.yaml ./
RUN pnpm i

# Copy application code
COPY . /app

# Create required directories
RUN mkdir -p tmp/pids tmp/cache log \
    && chmod -R 777 tmp \
    && chmod -R 777 log

# Precompile assets in smaller chunks with optimizations
RUN SECRET_KEY_BASE=${SECRET_KEY_BASE} RAILS_LOG_TO_STDOUT=enabled bundle exec rails assets:precompile \
    && export NODE_OPTIONS="--max-old-space-size=2048 --max-http-header-size=1024 --no-experimental-fetch" \
    && export VITE_BUILD_CHUNKING=true \
    && export VITE_BUILD_MINIFY=esbuild \
    && export VITE_BUILD_SOURCE_MAP=false \
    && SECRET_KEY_BASE=${SECRET_KEY_BASE} bundle exec rake vite:build --trace \
    && rm -rf node_modules tmp/cache spec test \
    && pnpm store prune \
    && pnpm cache clean

# Final stage
FROM ruby:3.3.3-alpine

ARG SECRET_KEY_BASE
ARG RAILS_ENV=production

ENV SECRET_KEY_BASE=${SECRET_KEY_BASE} \
    RAILS_ENV=${RAILS_ENV} \
    NODE_ENV=production \
    BUNDLE_DEPLOYMENT="true" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_APP_CONFIG="/usr/local/bundle" \
    PATH="/app/bin:${PATH}"

# Install runtime dependencies
RUN apk add --no-cache \
    tzdata \
    postgresql-client \
    vips \
    && gem install bundler

# Copy from builder - update paths to match BUNDLE_PATH
COPY --from=pre-builder /gems /gems
COPY --from=pre-builder /app /app
COPY --from=pre-builder /usr/local/bin/node /usr/local/bin/

WORKDIR /app

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
