#!/bin/bash

# Script para configurar replicação MySQL Master-Slave
# Uso: ./setup-replication.sh

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configurações
MASTER_HOST="mysql-master"
MASTER_PORT="3306"
SLAVE1_HOST="mysql-slave1"
SLAVE1_PORT="3306"
SLAVE2_HOST="mysql-slave2"
SLAVE2_PORT="3306"
ROOT_PASSWORD="rootpassword"
REPL_USER="replicator"
REPL_PASSWORD="replicatorpassword"

echo -e "${GREEN}=== Configurando Replicação MySQL ===${NC}"

# Função para executar comandos MySQL
execute_mysql() {
    local host=$1
    local port=$2
    local command=$3
    mysql -h $host -P $port -u root -p$ROOT_PASSWORD -e "$command"
}

# Função para aguardar MySQL estar pronto
wait_for_mysql() {
    local host=$1
    local port=$2
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}Aguardando MySQL em $host:$port estar pronto...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if execute_mysql $host $port "SELECT 1" > /dev/null 2>&1; then
            echo -e "${GREEN}MySQL em $host:$port está pronto!${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Tentativa $attempt/$max_attempts - Aguardando...${NC}"
        sleep 2
        ((attempt++))
    done
    
    echo -e "${RED}Erro: MySQL em $host:$port não ficou pronto após $max_attempts tentativas${NC}"
    exit 1
}

# Aguardar todos os containers estarem prontos
wait_for_mysql $MASTER_HOST $MASTER_PORT
wait_for_mysql $SLAVE1_HOST $SLAVE1_PORT
wait_for_mysql $SLAVE2_HOST $SLAVE2_PORT

echo -e "${GREEN}=== Configurando Master ===${NC}"

# Criar usuário de replicação no master
echo "Criando usuário de replicação..."
execute_mysql $MASTER_HOST $MASTER_PORT "CREATE USER IF NOT EXISTS '$REPL_USER'@'%' IDENTIFIED BY '$REPL_PASSWORD';"
execute_mysql $MASTER_HOST $MASTER_PORT "GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%';"
execute_mysql $MASTER_HOST $MASTER_PORT "FLUSH PRIVILEGES;"

# Obter posição do binlog
echo "Obtendo posição do binlog..."
MASTER_STATUS=$(execute_mysql $MASTER_HOST $MASTER_PORT "SHOW MASTER STATUS\G")
BINLOG_FILE=$(echo "$MASTER_STATUS" | grep "File:" | awk '{print $2}')
BINLOG_POS=$(echo "$MASTER_STATUS" | grep "Position:" | awk '{print $2}')

echo "Binlog File: $BINLOG_FILE"
echo "Binlog Position: $BINLOG_POS"

# Configurar Slave 1
echo -e "${GREEN}=== Configurando Slave 1 ===${NC}"
execute_mysql $SLAVE1_HOST $SLAVE1_PORT "STOP SLAVE;"
execute_mysql $SLAVE1_HOST $SLAVE1_PORT "CHANGE MASTER TO
    MASTER_HOST='$MASTER_HOST',
    MASTER_PORT=$MASTER_PORT,
    MASTER_USER='$REPL_USER',
    MASTER_PASSWORD='$REPL_PASSWORD',
    MASTER_LOG_FILE='$BINLOG_FILE',
    MASTER_LOG_POS=$BINLOG_POS;"
execute_mysql $SLAVE1_HOST $SLAVE1_PORT "START SLAVE;"

# Configurar Slave 2
echo -e "${GREEN}=== Configurando Slave 2 ===${NC}"
execute_mysql $SLAVE2_HOST $SLAVE2_PORT "STOP SLAVE;"
execute_mysql $SLAVE2_HOST $SLAVE2_PORT "CHANGE MASTER TO
    MASTER_HOST='$MASTER_HOST',
    MASTER_PORT=$MASTER_PORT,
    MASTER_USER='$REPL_USER',
    MASTER_PASSWORD='$REPL_PASSWORD',
    MASTER_LOG_FILE='$BINLOG_FILE',
    MASTER_LOG_POS=$BINLOG_POS;"
execute_mysql $SLAVE2_HOST $SLAVE2_PORT "START SLAVE;"

# Verificar status da replicação
echo -e "${GREEN}=== Verificando Status da Replicação ===${NC}"

echo -e "${YELLOW}Status do Slave 1:${NC}"
execute_mysql $SLAVE1_HOST $SLAVE1_PORT "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_Error)"

echo -e "${YELLOW}Status do Slave 2:${NC}"
execute_mysql $SLAVE2_HOST $SLAVE2_PORT "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_Error)"

# Teste de replicação
echo -e "${GREEN}=== Testando Replicação ===${NC}"

# Inserir dados no master
echo "Inserindo dados de teste no master..."
execute_mysql $MASTER_HOST $MASTER_PORT "CREATE DATABASE IF NOT EXISTS test_replication;"
execute_mysql $MASTER_HOST $MASTER_PORT "USE test_replication; CREATE TABLE IF NOT EXISTS test_table (id INT AUTO_INCREMENT PRIMARY KEY, message VARCHAR(255), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
execute_mysql $MASTER_HOST $MASTER_PORT "USE test_replication; INSERT INTO test_table (message) VALUES ('Teste de replicação - $(date)');"

# Aguardar replicação
echo "Aguardando replicação..."
sleep 5

# Verificar se dados foram replicados
echo "Verificando replicação no Slave 1:"
execute_mysql $SLAVE1_HOST $SLAVE1_PORT "USE test_replication; SELECT * FROM test_table ORDER BY created_at DESC LIMIT 1;"

echo "Verificando replicação no Slave 2:"
execute_mysql $SLAVE2_HOST $SLAVE2_PORT "USE test_replication; SELECT * FROM test_table ORDER BY created_at DESC LIMIT 1;"

echo -e "${GREEN}=== Configuração Concluída! ===${NC}"
echo -e "${YELLOW}Master: $MASTER_HOST:$MASTER_PORT${NC}"
echo -e "${YELLOW}Slave 1: $SLAVE1_HOST:$SLAVE1_PORT${NC}"
echo -e "${YELLOW}Slave 2: $SLAVE2_HOST:$SLAVE2_PORT${NC}"
echo -e "${YELLOW}phpMyAdmin: http://localhost:8080${NC}"
echo -e "${YELLOW}ProxySQL: localhost:6033${NC}"