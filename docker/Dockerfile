# pre-build stage
FROM node:18-alpine AS node
FROM ruby:3.3.3-alpine AS pre-builder

ARG SECRET_KEY_BASE
ARG RAILS_ENV=production

# Set environment variables early
ENV SECRET_KEY_BASE=${SECRET_KEY_BASE} \
    RAILS_ENV=${RAILS_ENV} \
    NODE_ENV=production \
    BUNDLE_DEPLOYMENT="true" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_APP_CONFIG="/usr/local/bundle" \
    NPM_CONFIG_LOGLEVEL=error \
    PNPM_HOME="/root/.local/share/pnpm" \
    PATH="/root/.local/share/pnpm:$PATH"

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
    vips \
    && mkdir -p /var/app \
    && gem install bundler -v 2.5.11

# Setup Node and PNPM
COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && npm install -g pnpm@10.2.0 \
    && pnpm config set store-dir /root/.local/share/pnpm/store \
    && pnpm config set node-linker hoisted

WORKDIR /app

# Copy essential files first
COPY Gemfile Gemfile.lock ./
COPY package.json pnpm-lock.yaml ./

# Install dependencies with proper config
RUN bundle config --global frozen 1 \
    && bundle config --local without development:test \
    && bundle config --local path /usr/local/bundle \
    && bundle install -j4 --retry 3 \
    && pnpm install --prod --prefer-offline

# Copy application code
COPY . .

# Create required directories
RUN mkdir -p tmp/pids tmp/cache \
    && chmod -R 777 tmp \
    && chmod -R 777 log

# Precompile assets
RUN RAILS_LOG_TO_STDOUT=enabled bundle exec rails assets:precompile \
    && bundle exec rake vite:build \
    && rm -rf node_modules tmp/cache spec test

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

# Copy from builder
COPY --from=pre-builder /usr/local/bundle /usr/local/bundle
COPY --from=pre-builder /app /app
COPY --from=pre-builder /usr/local/bin/node /usr/local/bin/

WORKDIR /app

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
