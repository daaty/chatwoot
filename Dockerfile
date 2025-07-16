# Dockerfile for production deployment
# This file is used by platforms that expect a Dockerfile in the root directory

# Use the same Dockerfile from docker directory
FROM ruby:3.3.3-alpine3.19 AS base

# Copy the actual Dockerfile content
COPY docker/Dockerfile.production /tmp/Dockerfile.production

# Use multi-stage build approach
FROM ruby:3.3.3-alpine3.19 AS pre-builder

ARG NODE_VERSION="23.7.0"
ARG PNPM_VERSION="10.2.0"
ENV NODE_VERSION=${NODE_VERSION}
ENV PNPM_VERSION=${PNPM_VERSION}

# ARG default to production settings
ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.11

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES ${RAILS_SERVE_STATIC_FILES}

ARG RAILS_ENV=production
ENV RAILS_ENV ${RAILS_ENV}

# Node.js memory settings
ARG NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"
ENV NODE_OPTIONS ${NODE_OPTIONS}

ENV BUNDLE_PATH="/gems"

# Install system dependencies
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
  && mkdir -p /var/app \
  && gem install bundler

# Install Node.js
RUN apk add --no-cache nodejs npm
RUN npm install -g pnpm@${PNPM_VERSION}

# Set PNPM environment
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

WORKDIR /app

# Copy dependency files
COPY Gemfile Gemfile.lock ./
COPY package.json pnpm-lock.yaml ./

# Install dependencies
RUN apk add --no-cache build-base musl ruby-full ruby-dev gcc make musl-dev openssl openssl-dev g++ linux-headers xz vips
RUN bundle config set --local force_ruby_platform true

# Install Ruby gems
RUN if [ "$RAILS_ENV" = "production" ]; then \
  bundle config set without 'development test'; bundle install -j 4 -r 3; \
  else bundle install -j 4 -r 3; \
  fi

# Install Node.js dependencies
RUN pnpm i

# Copy application code
COPY . /app

# Create log directory
RUN mkdir -p /app/log

# Build assets for production
RUN if [ "$RAILS_ENV" = "production" ]; then \
  chmod +x /app/docker/entrypoints/optimize-build.sh && \
  /app/docker/entrypoints/optimize-build.sh && \
  rm -rf spec node_modules tmp/cache; \
  fi

# Generate git SHA
RUN git rev-parse HEAD > /app/.git_sha 2>/dev/null || echo "unknown" > /app/.git_sha

# Clean up
RUN rm -rf /gems/ruby/3.3.0/cache/*.gem \
  && find /gems/ruby/3.3.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete 2>/dev/null || true \
  && rm -rf .git \
  && rm -f .gitignore

# Final stage
FROM ruby:3.3.3-alpine3.19

ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.11

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES ${RAILS_SERVE_STATIC_FILES}

ARG BUNDLE_FORCE_RUBY_PLATFORM=1
ENV BUNDLE_FORCE_RUBY_PLATFORM ${BUNDLE_FORCE_RUBY_PLATFORM}

ARG RAILS_ENV=production
ENV RAILS_ENV ${RAILS_ENV}
ENV BUNDLE_PATH="/gems"

# Node.js memory settings
ARG NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"
ENV NODE_OPTIONS ${NODE_OPTIONS}

# Install runtime dependencies
RUN apk update && apk add --no-cache \
  build-base \
  openssl \
  tzdata \
  postgresql-client \
  imagemagick \
  git \
  vips \
  && gem install bundler

# Copy from build stage
COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app

WORKDIR /app

# Make scripts executable
RUN chmod +x /app/docker/entrypoints/rails.sh

# Set default environment variables for production
ENV NODE_ENV=production
ENV INSTALLATION_ENV=docker
ENV POSTGRES_HOST=postgres
ENV POSTGRES_USERNAME=postgres
ENV POSTGRES_PASSWORD=postgres_password
ENV POSTGRES_PORT=5432
ENV REDIS_URL=redis://redis:6379

EXPOSE 3000

# Default entrypoint
ENTRYPOINT ["docker/entrypoints/rails.sh"]
CMD ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0"]
