FROM chatwoot/chatwoot:latest

ENV RAILS_ENV=production
ENV NODE_ENV=production
ENV BUNDLE_PATH="/usr/local/bundle"
ENV BUNDLE_APP_CONFIG="/usr/local/bundle"
ENV PATH="/app/bin:${PATH}"

RUN chmod +x docker/entrypoints/rails.sh

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
