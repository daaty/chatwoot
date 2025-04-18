#!/bin/bash
set -e

# Este script é executado após a inicialização do PostgreSQL
# Ele modifica o arquivo pg_hba.conf para permitir conexões sem senha

# Caminho para o arquivo de configuração do PostgreSQL
PG_HBA_CONF="/var/lib/postgresql/data/pg_hba.conf"

# Aguardar até que o PostgreSQL inicie e o arquivo pg_hba.conf seja criado
until [ -f "$PG_HBA_CONF" ]
do
  echo "Aguardando a criação do arquivo pg_hba.conf..."
  sleep 1
done

echo "Configurando autenticação do PostgreSQL para 'trust'..."

# Substituir a autenticação scram-sha-256 por trust
sed -i 's/scram-sha-256/trust/g' "$PG_HBA_CONF"

# Recarregar a configuração do PostgreSQL
pg_ctl -D "$PGDATA" reload

echo "Configuração de autenticação do PostgreSQL atualizada com sucesso!"