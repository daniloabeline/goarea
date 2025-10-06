#!/bin/bash

# Script para monitorar replicação MySQL
# Uso: ./monitor-replication.sh [--continuous]

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
MASTER_HOST="mysql-master"
SLAVE1_HOST="mysql-slave1"
SLAVE2_HOST="mysql-slave2"
ROOT_PASSWORD="rootpassword"

# Função para executar comandos MySQL
execute_mysql() {
    local host=$1
    local command=$2
    mysql -h $host -u root -p$ROOT_PASSWORD -e "$command" 2>/dev/null
}

# Função para verificar status de um slave
check_slave_status() {
    local slave_host=$1
    local slave_name=$2
    
    echo -e "${BLUE}=== Status do $slave_name ===${NC}"
    
    # Verificar se MySQL está respondendo
    if ! execute_mysql $slave_host "SELECT 1" > /dev/null 2>&1; then
        echo -e "${RED}❌ $slave_name não está respondendo${NC}"
        return 1
    fi
    
    # Obter status da replicação
    local status=$(execute_mysql $slave_host "SHOW SLAVE STATUS\G")
    
    if [ -z "$status" ]; then
        echo -e "${RED}❌ $slave_name não está configurado como slave${NC}"
        return 1
    fi
    
    # Extrair informações importantes
    local io_running=$(echo "$status" | grep "Slave_IO_Running:" | awk '{print $2}')
    local sql_running=$(echo "$status" | grep "Slave_SQL_Running:" | awk '{print $2}')
    local behind_master=$(echo "$status" | grep "Seconds_Behind_Master:" | awk '{print $2}')
    local last_error=$(echo "$status" | grep "Last_Error:" | awk '{print $2}')
    local master_host=$(echo "$status" | grep "Master_Host:" | awk '{print $2}')
    local master_port=$(echo "$status" | grep "Master_Port:" | awk '{print $2}')
    
    # Status do IO Thread
    if [ "$io_running" = "Yes" ]; then
        echo -e "${GREEN}✅ IO Thread: $io_running${NC}"
    else
        echo -e "${RED}❌ IO Thread: $io_running${NC}"
    fi
    
    # Status do SQL Thread
    if [ "$sql_running" = "Yes" ]; then
        echo -e "${GREEN}✅ SQL Thread: $sql_running${NC}"
    else
        echo -e "${RED}❌ SQL Thread: $sql_running${NC}"
    fi
    
    # Lag de replicação
    if [ "$behind_master" = "NULL" ]; then
        echo -e "${YELLOW}⚠️  Lag: Não disponível${NC}"
    elif [ "$behind_master" -eq 0 ]; then
        echo -e "${GREEN}✅ Lag: $behind_master segundos (sincronizado)${NC}"
    elif [ "$behind_master" -lt 60 ]; then
        echo -e "${YELLOW}⚠️  Lag: $behind_master segundos${NC}"
    else
        echo -e "${RED}❌ Lag: $behind_master segundos (alto)${NC}"
    fi
    
    # Erro da última execução
    if [ -n "$last_error" ] && [ "$last_error" != "NULL" ]; then
        echo -e "${RED}❌ Último Erro: $last_error${NC}"
    else
        echo -e "${GREEN}✅ Sem erros${NC}"
    fi
    
    # Informações de conexão
    echo -e "${BLUE}📡 Master: $master_host:$master_port${NC}"
    
    echo ""
}

# Função para verificar performance
check_performance() {
    echo -e "${BLUE}=== Performance ===${NC}"
    
    # Conexões ativas no master
    local master_connections=$(execute_mysql $MASTER_HOST "SHOW STATUS LIKE 'Threads_connected';" | grep "Threads_connected" | awk '{print $2}')
    echo -e "${YELLOW}🔗 Conexões ativas (Master): $master_connections${NC}"
    
    # QPS (Queries Per Second)
    local qps=$(execute_mysql $MASTER_HOST "SHOW STATUS LIKE 'Queries';" | grep "Queries" | awk '{print $2}')
    echo -e "${YELLOW}📊 Total de Queries: $qps${NC}"
    
    # Uptime
    local uptime=$(execute_mysql $MASTER_HOST "SHOW STATUS LIKE 'Uptime';" | grep "Uptime" | awk '{print $2}')
    local uptime_hours=$((uptime / 3600))
    echo -e "${YELLOW}⏱️  Uptime: ${uptime_hours}h${NC}"
    
    echo ""
}

# Função para verificar logs de erro
check_error_logs() {
    echo -e "${BLUE}=== Logs de Erro (últimas 10 linhas) ===${NC}"
    
    # Verificar logs do master
    echo -e "${YELLOW}Master:${NC}"
    docker logs mysql-master --tail 10 2>&1 | grep -i error || echo "Nenhum erro encontrado"
    
    # Verificar logs dos slaves
    echo -e "${YELLOW}Slave 1:${NC}"
    docker logs mysql-slave1 --tail 10 2>&1 | grep -i error || echo "Nenhum erro encontrado"
    
    echo -e "${YELLOW}Slave 2:${NC}"
    docker logs mysql-slave2 --tail 10 2>&1 | grep -i error || echo "Nenhum erro encontrado"
    
    echo ""
}

# Função para testar replicação
test_replication() {
    echo -e "${BLUE}=== Teste de Replicação ===${NC}"
    
    # Inserir dados de teste
    local test_message="Teste de monitoramento - $(date '+%Y-%m-%d %H:%M:%S')"
    execute_mysql $MASTER_HOST "USE test_replication; INSERT INTO test_table (message) VALUES ('$test_message');"
    
    echo -e "${YELLOW}Dados inseridos no master: $test_message${NC}"
    
    # Aguardar replicação
    sleep 3
    
    # Verificar se foi replicado
    local slave1_count=$(execute_mysql $SLAVE1_HOST "USE test_replication; SELECT COUNT(*) FROM test_table WHERE message = '$test_message';" | tail -1)
    local slave2_count=$(execute_mysql $SLAVE2_HOST "USE test_replication; SELECT COUNT(*) FROM test_table WHERE message = '$test_message';" | tail -1)
    
    if [ "$slave1_count" -eq 1 ]; then
        echo -e "${GREEN}✅ Dados replicados no Slave 1${NC}"
    else
        echo -e "${RED}❌ Dados NÃO replicados no Slave 1${NC}"
    fi
    
    if [ "$slave2_count" -eq 1 ]; then
        echo -e "${GREEN}✅ Dados replicados no Slave 2${NC}"
    else
        echo -e "${RED}❌ Dados NÃO replicados no Slave 2${NC}"
    fi
    
    echo ""
}

# Função principal
main() {
    echo -e "${GREEN}=== Monitor de Replicação MySQL ===${NC}"
    echo -e "${YELLOW}Timestamp: $(date)${NC}"
    echo ""
    
    # Verificar status dos slaves
    check_slave_status $SLAVE1_HOST "Slave 1"
    check_slave_status $SLAVE2_HOST "Slave 2"
    
    # Verificar performance
    check_performance
    
    # Verificar logs de erro
    check_error_logs
    
    # Testar replicação
    test_replication
    
    echo -e "${GREEN}=== Monitoramento Concluído ===${NC}"
}

# Verificar se deve executar continuamente
if [ "$1" = "--continuous" ]; then
    echo -e "${YELLOW}Executando monitoramento contínuo (Ctrl+C para parar)${NC}"
    while true; do
        clear
        main
        sleep 30
    done
else
    main
fi