#!/bin/sh

echo "-------------- Optimizing build process for Chatwoot --------------"

# Configurar NODE_OPTIONS para aumentar a memória disponível
export NODE_OPTIONS="--max-old-space-size=4096"

# Limpar caches antigos para liberar memória
rm -rf /app/tmp/cache/*
rm -rf /app/node_modules/.cache
rm -rf /app/node_modules/.vite

# Usar o arquivo de configuração otimizado para vite
export VITE_CONFIG_PATH=/app/vite.config.production.ts

# Executar a compilação dos assets em etapas separadas para evitar problemas de memória
echo "-------------- Compilando assets em etapas --------------"
SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled bundle exec rake assets:clobber
SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled bundle exec rake assets:precompile --trace

echo "-------------- Build concluído com sucesso --------------"
