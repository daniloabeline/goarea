# Guia Completo: Clusters MySQL

## Índice
1. [O que é um Cluster MySQL](#o-que-é-um-cluster-mysql)
2. [Tipos de Arquiteturas](#tipos-de-arquiteturas)
3. [Requisitos e Especificações](#requisitos-e-especificações)
4. [Boas Práticas](#boas-práticas)
5. [Configuração do Zero](#configuração-do-zero)
6. [Monitoramento e Manutenção](#monitoramento-e-manutenção)
7. [Troubleshooting](#troubleshooting)

## O que é um Cluster MySQL

Um cluster MySQL é uma configuração de múltiplos servidores MySQL que trabalham em conjunto para fornecer:
- **Alta Disponibilidade**: Continuidade do serviço mesmo com falhas
- **Escalabilidade**: Capacidade de processar mais carga
- **Redundância**: Proteção contra perda de dados
- **Balanceamento de Carga**: Distribuição de consultas entre servidores

## Tipos de Arquiteturas

### 1. Master-Slave (Replicação Simples)
```
Master (Escrita) → Slave (Leitura)
```

**Características:**
- Um servidor master para escritas
- Um ou mais slaves para leituras
- Replicação assíncrona
- Failover manual

**Vantagens:**
- Simples de configurar
- Boa para separar leitura/escrita
- Backup automático via slave

**Desvantagens:**
- Falha do master = indisponibilidade
- Replicação com delay
- Failover manual

### 2. Master-Master (Replicação Bidirecional)
```
Master A ↔ Master B
```

**Características:**
- Ambos servidores podem receber escritas
- Replicação bidirecional
- Conflitos de dados possíveis

**Vantagens:**
- Maior disponibilidade
- Escrita em ambos os servidores

**Desvantagens:**
- Complexidade de conflitos
- Risco de inconsistência
- Configuração complexa

### 3. MySQL Cluster (NDB)
```
Management Node
    ↓
Data Nodes (Múltiplos)
    ↓
SQL Nodes (Múltiplos)
```

**Características:**
- Cluster nativo do MySQL
- Dados distribuídos entre nós
- Replicação síncrona
- Failover automático

**Vantagens:**
- Alta disponibilidade
- Escalabilidade horizontal
- Failover automático

**Desvantagens:**
- Complexidade alta
- Requisitos de hardware específicos
- Curva de aprendizado

### 4. MySQL InnoDB Cluster (Group Replication)
```
Primary Node
    ↓
Secondary Nodes (Múltiplos)
```

**Características:**
- Replicação síncrona
- Consenso automático
- Failover automático
- MySQL 5.7+

**Vantagens:**
- Alta disponibilidade
- Consistência forte
- Failover automático
- Mais simples que NDB

## Requisitos e Especificações

### Hardware Mínimo

#### Para Desenvolvimento/Teste
- **CPU**: 2 cores
- **RAM**: 4GB
- **Disco**: 20GB SSD
- **Rede**: 1Gbps

#### Para Produção (Médio)
- **CPU**: 8 cores
- **RAM**: 32GB
- **Disco**: 500GB SSD (RAID 10)
- **Rede**: 10Gbps

#### Para Produção (Alto Volume)
- **CPU**: 16+ cores
- **RAM**: 128GB+
- **Disco**: 2TB+ SSD (RAID 10)
- **Rede**: 25Gbps+

### Software
- **MySQL**: 8.0+ (recomendado)
- **Sistema Operacional**: Linux (Ubuntu 20.04+, CentOS 8+, RHEL 8+)
- **Docker**: Para ambientes containerizados
- **Kubernetes**: Para orquestração

### Requisitos de Rede
- **Latência**: < 1ms entre nós
- **Largura de Banda**: Mínimo 1Gbps
- **Conectividade**: Redundância de rede
- **Firewall**: Portas MySQL abertas (3306, 33061, 33062)

## Boas Práticas

### 1. Planejamento
- **Análise de Carga**: Entenda padrões de leitura/escrita
- **RTO/RPO**: Defina objetivos de recuperação
- **Teste de Failover**: Simule falhas regularmente
- **Backup Strategy**: Implemente backup automático

### 2. Configuração
- **Sincronização de Relógio**: Use NTP em todos os nós
- **Configuração Consistente**: Mesmo my.cnf em todos os nós
- **Logs Binários**: Habilite para replicação
- **SSL/TLS**: Criptografe conexões entre nós

### 3. Monitoramento
- **Métricas de Performance**: CPU, RAM, I/O, conexões
- **Status da Replicação**: Lag, erros, conectividade
- **Alertas**: Configure notificações automáticas
- **Logs**: Centralize logs de todos os nós

### 4. Segurança
- **Usuários Dedicados**: Crie usuários específicos para replicação
- **Senhas Fortes**: Use senhas complexas
- **Firewall**: Restrinja acesso por IP
- **Backup Seguro**: Criptografe backups

### 5. Manutenção
- **Atualizações**: Teste em ambiente de desenvolvimento
- **Limpeza de Logs**: Automatize limpeza de binlogs
- **Índices**: Monitore e otimize índices
- **Estatísticas**: Mantenha estatísticas atualizadas

## Configuração do Zero

### Opção 1: Docker Compose (Desenvolvimento)

#### 1. Estrutura de Arquivos
```
mysql-cluster/
├── docker-compose.yml
├── master/
│   ├── my.cnf
│   └── init.sql
├── slave1/
│   └── my.cnf
└── slave2/
    └── my.cnf
```

#### 2. docker-compose.yml
```yaml
version: '3.8'

services:
  mysql-master:
    image: mysql:8.0
    container_name: mysql-master
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_REPLICATION_USER: replicator
      MYSQL_REPLICATION_PASSWORD: replicatorpassword
    ports:
      - "3306:3306"
    volumes:
      - ./master/my.cnf:/etc/mysql/my.cnf
      - ./master/init.sql:/docker-entrypoint-initdb.d/init.sql
      - mysql_master_data:/var/lib/mysql
    command: --server-id=1 --log-bin=mysql-bin --binlog-format=ROW
    networks:
      - mysql-cluster

  mysql-slave1:
    image: mysql:8.0
    container_name: mysql-slave1
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
    ports:
      - "3307:3306"
    volumes:
      - ./slave1/my.cnf:/etc/mysql/my.cnf
      - mysql_slave1_data:/var/lib/mysql
    command: --server-id=2 --relay-log=mysql-relay-bin
    depends_on:
      - mysql-master
    networks:
      - mysql-cluster

  mysql-slave2:
    image: mysql:8.0
    container_name: mysql-slave2
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
    ports:
      - "3308:3306"
    volumes:
      - ./slave2/my.cnf:/etc/mysql/my.cnf
      - mysql_slave2_data:/var/lib/mysql
    command: --server-id=3 --relay-log=mysql-relay-bin
    depends_on:
      - mysql-master
    networks:
      - mysql-cluster

volumes:
  mysql_master_data:
  mysql_slave1_data:
  mysql_slave2_data:

networks:
  mysql-cluster:
    driver: bridge
```

#### 3. Configuração Master (master/my.cnf)
```ini
[mysqld]
server-id = 1
log-bin = mysql-bin
binlog-format = ROW
gtid-mode = ON
enforce-gtid-consistency = ON
sync-binlog = 1
innodb-flush-log-at-trx-commit = 1

# Configurações de Performance
innodb-buffer-pool-size = 1G
innodb-log-file-size = 256M
max-connections = 200

# Configurações de Replicação
expire-logs-days = 7
max-binlog-size = 100M
```

#### 4. Configuração Slave (slave1/my.cnf e slave2/my.cnf)
```ini
[mysqld]
server-id = 2  # 3 para slave2
relay-log = mysql-relay-bin
read-only = 1
gtid-mode = ON
enforce-gtid-consistency = ON

# Configurações de Performance
innodb-buffer-pool-size = 1G
max-connections = 200

# Configurações de Replicação
log-slave-updates = 1
relay-log-recovery = 1
```

#### 5. Script de Inicialização (master/init.sql)
```sql
-- Criar usuário para replicação
CREATE USER 'replicator'@'%' IDENTIFIED BY 'replicatorpassword';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;

-- Criar banco de teste
CREATE DATABASE testdb;
USE testdb;
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inserir dados de teste
INSERT INTO users (name, email) VALUES 
('João Silva', 'joao@email.com'),
('Maria Santos', 'maria@email.com');
```

### Opção 2: Instalação Manual (Produção)

#### 1. Preparação do Sistema
```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar MySQL
sudo apt install mysql-server mysql-client -y

# Configurar MySQL
sudo mysql_secure_installation
```

#### 2. Configuração Master
```bash
# Editar configuração
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf

# Adicionar configurações de replicação
[mysqld]
server-id = 1
log-bin = /var/log/mysql/mysql-bin.log
binlog-format = ROW
gtid-mode = ON
enforce-gtid-consistency = ON
```

#### 3. Configuração Slave
```bash
# Editar configuração
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf

# Adicionar configurações de replicação
[mysqld]
server-id = 2
relay-log = /var/log/mysql/mysql-relay-bin.log
read-only = 1
gtid-mode = ON
enforce-gtid-consistency = ON
```

#### 4. Configurar Replicação
```sql
-- No Master
CREATE USER 'replicator'@'%' IDENTIFIED BY 'senha_forte';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;

-- Verificar posição do binlog
SHOW MASTER STATUS;

-- No Slave
CHANGE MASTER TO
    MASTER_HOST='ip_do_master',
    MASTER_USER='replicator',
    MASTER_PASSWORD='senha_forte',
    MASTER_AUTO_POSITION=1;

-- Iniciar replicação
START SLAVE;

-- Verificar status
SHOW SLAVE STATUS\G
```

### Opção 3: MySQL InnoDB Cluster (Group Replication)

#### 1. Instalar MySQL Shell
```bash
# Ubuntu/Debian
wget https://dev.mysql.com/get/mysql-apt-config_0.8.24-1_all.deb
sudo dpkg -i mysql-apt-config_0.8.24-1_all.deb
sudo apt update
sudo apt install mysql-shell -y
```

#### 2. Configurar Primeiro Nó
```sql
-- Configurar Group Replication
SET PERSIST group_replication_group_name = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
SET PERSIST group_replication_start_on_boot = ON;
SET PERSIST group_replication_local_address = "192.168.1.10:33061";
SET PERSIST group_replication_group_seeds = "192.168.1.10:33061,192.168.1.11:33061,192.168.1.12:33061";
SET PERSIST group_replication_bootstrap_group = ON;

-- Iniciar Group Replication
START GROUP_REPLICATION;
SET PERSIST group_replication_bootstrap_group = OFF;
```

#### 3. Adicionar Nós Adicionais
```sql
-- Configurar outros nós
SET PERSIST group_replication_group_name = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
SET PERSIST group_replication_start_on_boot = ON;
SET PERSIST group_replication_local_address = "192.168.1.11:33061";
SET PERSIST group_replication_group_seeds = "192.168.1.10:33061,192.168.1.11:33061,192.168.1.12:33061";

-- Iniciar Group Replication
START GROUP_REPLICATION;
```

## Monitoramento e Manutenção

### 1. Scripts de Monitoramento

#### Verificar Status da Replicação
```sql
-- Verificar status do slave
SHOW SLAVE STATUS\G

-- Verificar se está replicando
SELECT * FROM performance_schema.replication_connection_status;

-- Verificar lag de replicação
SELECT 
    CHANNEL_NAME,
    SERVICE_STATE,
    COUNT_TRANSACTIONS_RETRIES,
    LAST_ERROR_NUMBER,
    LAST_ERROR_MESSAGE
FROM performance_schema.replication_connection_status;
```

#### Monitorar Performance
```sql
-- Conexões ativas
SHOW PROCESSLIST;

-- Status do InnoDB
SHOW ENGINE INNODB STATUS;

-- Estatísticas de replicação
SELECT * FROM performance_schema.replication_applier_status;
```

### 2. Scripts de Backup
```bash
#!/bin/bash
# backup-mysql.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/mysql"
DB_NAME="meu_banco"

# Criar diretório de backup
mkdir -p $BACKUP_DIR

# Backup completo
mysqldump --single-transaction --routines --triggers \
    --master-data=2 --gtid $DB_NAME > $BACKUP_DIR/backup_$DATE.sql

# Backup binlog
mysqlbinlog --start-datetime="$(date -d '1 day ago')" \
    /var/log/mysql/mysql-bin.* > $BACKUP_DIR/binlog_$DATE.sql

# Comprimir
gzip $BACKUP_DIR/backup_$DATE.sql
gzip $BACKUP_DIR/binlog_$DATE.sql

# Limpar backups antigos (manter 7 dias)
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete
```

### 3. Scripts de Failover
```bash
#!/bin/bash
# failover-mysql.sh

MASTER_HOST="192.168.1.10"
SLAVE_HOST="192.168.1.11"

# Verificar se master está respondendo
if ! mysql -h $MASTER_HOST -e "SELECT 1" > /dev/null 2>&1; then
    echo "Master não está respondendo. Iniciando failover..."
    
    # Promover slave a master
    mysql -h $SLAVE_HOST -e "STOP SLAVE; RESET MASTER;"
    
    # Atualizar configuração de aplicação
    # (implementar lógica específica da aplicação)
    
    echo "Failover concluído. Slave promovido a master."
else
    echo "Master está funcionando normalmente."
fi
```

## Troubleshooting

### Problemas Comuns

#### 1. Replicação Parada
```sql
-- Verificar erros
SHOW SLAVE STATUS\G

-- Reiniciar replicação
STOP SLAVE;
START SLAVE;

-- Se necessário, resetar
STOP SLAVE;
RESET SLAVE;
CHANGE MASTER TO ...;
START SLAVE;
```

#### 2. Lag de Replicação
```sql
-- Verificar lag
SELECT 
    CHANNEL_NAME,
    SERVICE_STATE,
    COUNT_TRANSACTIONS_RETRIES
FROM performance_schema.replication_connection_status;

-- Otimizar configurações
SET GLOBAL slave_parallel_workers = 4;
SET GLOBAL slave_parallel_type = 'LOGICAL_CLOCK';
```

#### 3. Conflitos de Dados
```sql
-- Verificar conflitos
SELECT * FROM performance_schema.replication_applier_status_by_worker;

-- Resolver conflitos manualmente
-- (depende do tipo de conflito)
```

### Logs Importantes
- `/var/log/mysql/error.log` - Log de erros
- `/var/log/mysql/mysql-bin.*` - Binlogs
- `/var/log/mysql/mysql-relay-bin.*` - Relay logs

### Comandos Úteis
```bash
# Verificar status do MySQL
systemctl status mysql

# Reiniciar MySQL
systemctl restart mysql

# Ver logs em tempo real
tail -f /var/log/mysql/error.log

# Verificar configuração
mysql --help --verbose | grep -A 1 'Default options'
```

## Conclusão

Este guia fornece uma base sólida para entender e implementar clusters MySQL. Lembre-se de:

1. **Teste sempre** em ambiente de desenvolvimento primeiro
2. **Monitore constantemente** o status da replicação
3. **Mantenha backups** atualizados e testados
4. **Documente** todas as configurações e procedimentos
5. **Treine a equipe** nos procedimentos de failover

Para ambientes de produção, considere usar ferramentas como:
- **ProxySQL** para balanceamento de carga
- **Orchestrator** para gerenciamento de topologia
- **Prometheus + Grafana** para monitoramento
- **Ansible** para automação de configuração