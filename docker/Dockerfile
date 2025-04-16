# pre-build stage
FROM node:18-alpine AS node
FROM ruby:3.3.3-alpine AS pre-builder

ARG SECRET_KEY_BASE
ENV SECRET_KEY_BASE=${SECRET_KEY_BASE}

# Set environment variables
ENV NODE_VERSION="18.19.1" \
    PNPM_VERSION="10.2.0" \
    BUNDLE_WITHOUT="development:test" \
    BUNDLER_VERSION="2.5.11" \
    RAILS_SERVE_STATIC_FILES="true" \
    RAILS_ENV="production" \
    NODE_ENV="production" \
    VITE_RUBY_ENV="production" \
    NODE_OPTIONS="--max-old-space-size=4096" \
    BUNDLE_PATH="/gems" \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
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
    && gem install bundler -v ${BUNDLER_VERSION}

# Setup Node and PNPM
COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && npm install -g pnpm@${PNPM_VERSION}

WORKDIR /app

# Install Ruby dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local force_ruby_platform true \
    && bundle install --jobs=${BUNDLE_JOBS} --retry=${BUNDLE_RETRY} $([ "$RAILS_ENV" = "production" ] && echo "--without development test")

# Install Node dependencies
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --prod --frozen-lockfile --ignore-scripts

# Copy application code
COPY . /app

# Create required directories and set permissions
RUN mkdir -p /app/log /app/tmp/pids /app/tmp/cache \
    && chmod -R 777 /app/log /app/tmp

# Build assets for production
RUN RAILS_LOG_TO_STDOUT=enabled bundle exec rake assets:precompile \
    && bundle exec rake vite:build \
    && rm -rf spec node_modules tmp/cache

# Generate git SHA
RUN git rev-parse HEAD > /app/.git_sha \
    && rm -rf /gems/ruby/3.3.0/cache/*.gem \
    && find /gems/ruby/3.3.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete \
    && rm -rf .git .gitignore

# Final stage
FROM ruby:3.3.3-alpine

ARG SECRET_KEY_BASE
ENV SECRET_KEY_BASE=${SECRET_KEY_BASE} \
    RAILS_ENV="production" \
    NODE_ENV="production" \
    BUNDLE_PATH="/gems" \
    PATH="/app/bin:${PATH}"

# Install runtime dependencies
RUN apk add --no-cache \
    tzdata \
    postgresql-client \
    vips \
    && gem install bundler

# Copy required files from builder
COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app
COPY --from=pre-builder /app/.git_sha /app/.git_sha
COPY --from=pre-builder /usr/local/bin/node /usr/local/bin/

WORKDIR /app

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
