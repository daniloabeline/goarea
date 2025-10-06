# MySQL Cluster - Guia Completo

## 📋 Índice
1. [Visão Geral](#visão-geral)
2. [Tipos de Cluster MySQL](#tipos-de-cluster-mysql)
3. [Arquiteturas e Configurações](#arquiteturas-e-configurações)
4. [Requisitos de Hardware e Software](#requisitos-de-hardware-e-software)
5. [Procedimentos de Deploy](#procedimentos-de-deploy)
6. [Monitoramento e Gerenciamento](#monitoramento-e-gerenciamento)
7. [Troubleshooting](#troubleshooting)
8. [Boas Práticas](#boas-práticas)

---

## 🎯 Visão Geral

### O que é MySQL Cluster?
MySQL Cluster é uma tecnologia de banco de dados que oferece alta disponibilidade, escalabilidade e performance através de diferentes arquiteturas de cluster. Permite que múltiplos servidores MySQL trabalhem juntos como um único sistema.

### Benefícios Principais
- **Alta Disponibilidade**: Redundância automática e failover
- **Escalabilidade**: Adição de nós sem downtime
- **Performance**: Distribuição de carga e paralelização
- **Consistência**: Transações ACID distribuídas
- **Tolerância a Falhas**: Continuidade de serviço mesmo com falhas

---

## 🏗️ Tipos de Cluster MySQL

### 1. MySQL NDB Cluster (MySQL Cluster)
- **Tipo**: In-memory database cluster
- **Uso**: Aplicações que requerem alta disponibilidade e baixa latência
- **Características**: Dados armazenados em memória, replicação síncrona

### 2. MySQL InnoDB Cluster
- **Tipo**: Baseado em Group Replication
- **Uso**: Aplicações tradicionais que precisam de alta disponibilidade
- **Características**: Replicação assíncrona, consistência eventual

### 3. MySQL Galera Cluster (Percona XtraDB Cluster)
- **Tipo**: Multi-master synchronous replication
- **Uso**: Aplicações que precisam de escrita em múltiplos nós
- **Características**: Replicação síncrona, multi-master

---

## ⚙️ Arquiteturas e Configurações

### MySQL NDB Cluster

#### Componentes Principais
- **Management Node (ndb_mgmd)**: Gerencia o cluster
- **Data Node (ndbd)**: Armazena os dados
- **SQL Node (mysqld)**: Interface SQL para aplicações
- **API Node**: Conecta aplicações diretamente ao cluster

#### Configuração Mínima
```
Management Node: 1 servidor
Data Nodes: 2+ servidores (recomendado 4+)
SQL Nodes: 2+ servidores
```

### MySQL InnoDB Cluster

#### Componentes
- **MySQL Servers**: Instâncias MySQL com Group Replication
- **MySQL Router**: Roteamento de conexões
- **MySQL Shell**: Ferramenta de gerenciamento

#### Configuração Mínima
```
MySQL Servers: 3+ servidores (1 primário + 2 secundários)
MySQL Router: 2+ servidores (opcional, mas recomendado)
```

### MySQL Galera Cluster

#### Componentes
- **Galera Nodes**: Servidores MySQL com Galera WSREP
- **Load Balancer**: Distribuição de carga (opcional)

#### Configuração Mínima
```
Galera Nodes: 3+ servidores (recomendado número ímpar)
Load Balancer: 1+ servidor (opcional)
```

---

## 💻 Requisitos de Hardware e Software

### Requisitos de Software

#### MySQL NDB Cluster
- **MySQL Cluster**: 8.0+ (recomendado 8.0.33+)
- **Sistema Operacional**: Linux (Ubuntu 20.04+, CentOS 8+, RHEL 8+)
- **Memória**: Mínimo 4GB RAM por nó
- **CPU**: Mínimo 2 cores por nó

#### MySQL InnoDB Cluster
- **MySQL Server**: 8.0+ com Group Replication
- **MySQL Router**: 8.0+
- **MySQL Shell**: 8.0+
- **Sistema Operacional**: Linux, Windows, macOS

#### MySQL Galera Cluster
- **Percona XtraDB Cluster**: 8.0+
- **MariaDB Galera**: 10.6+
- **Sistema Operacional**: Linux (recomendado)

### Requisitos de Hardware por Tamanho de Cluster

#### Pequeno (Desenvolvimento/Teste)
```
Servidores: 3-4
CPU: 2-4 cores por servidor
RAM: 8-16GB por servidor
Storage: 100-500GB SSD
Rede: 1Gbps
```

#### Médio (Produção)
```
Servidores: 5-8
CPU: 4-8 cores por servidor
RAM: 16-32GB por servidor
Storage: 500GB-2TB SSD
Rede: 10Gbps
```

#### Grande (Enterprise)
```
Servidores: 10+
CPU: 8-16 cores por servidor
RAM: 32-128GB por servidor
Storage: 2TB+ NVMe SSD
Rede: 25Gbps+
```

---

## 🚀 Procedimentos de Deploy

### MySQL NDB Cluster - Deploy Passo a Passo

#### 1. Preparação do Ambiente
```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependências
sudo apt install -y wget curl gnupg2 software-properties-common

# Adicionar repositório MySQL
wget https://dev.mysql.com/get/mysql-apt-config_0.8.24-1_all.deb
sudo dpkg -i mysql-apt-config_0.8.24-1_all.deb
sudo apt update
```

#### 2. Instalação dos Componentes
```bash
# Instalar MySQL Cluster
sudo apt install -y mysql-cluster-community-server mysql-cluster-community-client

# Instalar MySQL Server (para SQL nodes)
sudo apt install -y mysql-server
```

#### 3. Configuração do Management Node
```bash
# Criar diretório de configuração
sudo mkdir -p /var/lib/mysql-cluster

# Configurar config.ini
sudo tee /var/lib/mysql-cluster/config.ini > /dev/null <<EOF
[ndbd default]
NoOfReplicas=2
DataMemory=80M
IndexMemory=18M

[ndb_mgmd]
NodeId=1
HostName=mgmt-server
DataDir=/var/lib/mysql-cluster

[ndbd]
NodeId=2
HostName=data1-server
DataDir=/var/lib/mysql-cluster

[ndbd]
NodeId=3
HostName=data2-server
DataDir=/var/lib/mysql-cluster

[mysqld]
NodeId=4
HostName=sql1-server

[mysqld]
NodeId=5
HostName=sql2-server
EOF

# Iniciar management node
sudo ndb_mgmd --config-file=/var/lib/mysql-cluster/config.ini
```

#### 4. Configuração dos Data Nodes
```bash
# Criar diretório de dados
sudo mkdir -p /var/lib/mysql-cluster

# Iniciar data node
sudo ndbd --connect-string=mgmt-server:1186
```

#### 5. Configuração dos SQL Nodes
```bash
# Configurar my.cnf
sudo tee /etc/mysql/mysql.conf.d/ndbcluster.cnf > /dev/null <<EOF
[mysqld]
ndbcluster
ndb-connectstring=mgmt-server:1186

[mysql_cluster]
ndb-connectstring=mgmt-server:1186
EOF

# Reiniciar MySQL
sudo systemctl restart mysql
```

### MySQL InnoDB Cluster - Deploy Passo a Passo

#### 1. Instalação do MySQL Server
```bash
# Instalar MySQL 8.0
sudo apt install -y mysql-server

# Configurar MySQL
sudo mysql_secure_installation
```

#### 2. Configuração do Group Replication
```bash
# Editar my.cnf
sudo tee -a /etc/mysql/mysql.conf.d/mysqld.cnf > /dev/null <<EOF
# Group Replication
server_id=1
gtid_mode=ON
enforce_gtid_consistency=ON
log_bin=mysql-bin
binlog_checksum=NONE
log_slave_updates=ON
binlog_format=ROW
master_info_repository=TABLE
relay_log_info_repository=TABLE
transaction_write_set_extraction=XXHASH64
loose-group_replication_group_name="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
loose-group_replication_start_on_boot=off
loose-group_replication_local_address="192.168.1.10:33061"
loose-group_replication_group_seeds="192.168.1.10:33061,192.168.1.11:33061,192.168.1.12:33061"
loose-group_replication_bootstrap_group=off
EOF

# Reiniciar MySQL
sudo systemctl restart mysql
```

#### 3. Configuração do Cluster
```bash
# Instalar MySQL Shell
wget https://dev.mysql.com/get/mysql-apt-config_0.8.24-1_all.deb
sudo dpkg -i mysql-apt-config_0.8.24-1_all.deb
sudo apt update
sudo apt install -y mysql-shell

# Conectar e configurar cluster
mysqlsh
\c root@localhost:3306
dba.configureInstance('root@localhost:3306')
var cluster = dba.createCluster('myCluster')
cluster.addInstance('root@192.168.1.11:3306')
cluster.addInstance('root@192.168.1.12:3306')
```

### MySQL Galera Cluster - Deploy Passo a Passo

#### 1. Instalação do Percona XtraDB Cluster
```bash
# Adicionar repositório Percona
wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb
sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb
sudo apt update

# Instalar Percona XtraDB Cluster
sudo apt install -y percona-xtradb-cluster-server
```

#### 2. Configuração do Primeiro Nó
```bash
# Editar my.cnf
sudo tee /etc/mysql/mysql.conf.d/galera.cnf > /dev/null <<EOF
[galera]
wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_cluster_name="my_galera_cluster"
wsrep_cluster_address="gcomm://"
wsrep_node_name="node1"
wsrep_node_address="192.168.1.10"
wsrep_sst_method=xtrabackup-v2
wsrep_sst_auth="sstuser:sstpass"
EOF

# Iniciar primeiro nó
sudo systemctl start mysql@bootstrap
```

#### 3. Configuração dos Outros Nós
```bash
# Editar my.cnf
sudo tee /etc/mysql/mysql.conf.d/galera.cnf > /dev/null <<EOF
[galera]
wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_cluster_name="my_galera_cluster"
wsrep_cluster_address="gcomm://192.168.1.10,192.168.1.11,192.168.1.12"
wsrep_node_name="node2"
wsrep_node_address="192.168.1.11"
wsrep_sst_method=xtrabackup-v2
wsrep_sst_auth="sstuser:sstpass"
EOF

# Iniciar nó
sudo systemctl start mysql
```

---

## 📊 Monitoramento e Gerenciamento

### Comandos Úteis

#### MySQL NDB Cluster
```bash
# Verificar status do cluster
ndb_mgm -e "SHOW"

# Verificar status dos nós
ndb_mgm -e "ALL STATUS"

# Verificar logs
ndb_mgm -e "CLUSTERLOG INFO"

# Backup do cluster
ndb_mgm -e "START BACKUP"
```

#### MySQL InnoDB Cluster
```bash
# Verificar status do cluster
mysqlsh
\c root@localhost:3306
dba.getCluster().status()

# Verificar instâncias
dba.getCluster().describe()

# Verificar logs
dba.getCluster().listRouters()
```

#### MySQL Galera Cluster
```sql
-- Verificar status do cluster
SHOW STATUS LIKE 'wsrep%';

-- Verificar nós do cluster
SHOW STATUS LIKE 'wsrep_cluster_size';

-- Verificar sincronização
SHOW STATUS LIKE 'wsrep_local_state_comment';
```

### Ferramentas de Monitoramento

#### Prometheus + Grafana
```yaml
# docker-compose.yml para monitoramento
version: '3.8'
services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

#### MySQL Enterprise Monitor
- Interface web para monitoramento
- Alertas automáticos
- Análise de performance
- Backup e recovery

---

## 🔧 Troubleshooting

### Problemas Comuns

#### 1. Nó não consegue se conectar ao cluster
```bash
# Verificar conectividade de rede
ping mgmt-server
telnet mgmt-server 1186

# Verificar logs
tail -f /var/log/mysql/error.log
tail -f /var/lib/mysql-cluster/ndb_1_out.log
```

#### 2. Falha na sincronização
```sql
-- Verificar status de replicação
SHOW SLAVE STATUS\G

-- Verificar logs binários
SHOW BINARY LOGS;

-- Verificar variáveis de replicação
SHOW VARIABLES LIKE '%replication%';
```

#### 3. Performance degradada
```sql
-- Verificar processos ativos
SHOW PROCESSLIST;

-- Verificar locks
SHOW ENGINE INNODB STATUS;

-- Verificar configurações de buffer
SHOW VARIABLES LIKE '%buffer%';
```

### Scripts de Diagnóstico

#### Verificação de Saúde do Cluster
```bash
#!/bin/bash
# cluster_health_check.sh

echo "=== MySQL Cluster Health Check ==="
echo "Data: $(date)"
echo

# Verificar status dos serviços
echo "1. Status dos Serviços:"
systemctl status mysql
echo

# Verificar conectividade
echo "2. Conectividade de Rede:"
ping -c 3 mgmt-server
echo

# Verificar logs de erro
echo "3. Últimos Erros:"
tail -20 /var/log/mysql/error.log | grep -i error
echo

# Verificar uso de recursos
echo "4. Uso de Recursos:"
free -h
df -h
echo

# Verificar status do cluster (se aplicável)
echo "5. Status do Cluster:"
ndb_mgm -e "SHOW" 2>/dev/null || echo "NDB Cluster não disponível"
echo

echo "=== Fim da Verificação ==="
```

---

## ✅ Boas Práticas

### Segurança
- Use SSL/TLS para conexões
- Configure firewalls adequadamente
- Implemente autenticação forte
- Mantenha backups criptografados
- Monitore tentativas de acesso

### Performance
- Configure buffers adequadamente
- Use índices apropriados
- Monitore queries lentas
- Implemente cache quando necessário
- Otimize configurações de rede

### Backup e Recovery
- Faça backups regulares
- Teste procedimentos de recovery
- Mantenha backups em locais seguros
- Documente procedimentos
- Automatize quando possível

### Monitoramento
- Configure alertas proativos
- Monitore métricas de performance
- Acompanhe logs de sistema
- Implemente dashboards
- Documente incidentes

---

## 📚 Recursos Adicionais

### Documentação Oficial
- [MySQL Cluster Documentation](https://dev.mysql.com/doc/refman/8.0/en/mysql-cluster.html)
- [MySQL InnoDB Cluster](https://dev.mysql.com/doc/refman/8.0/en/mysql-innodb-cluster.html)
- [Percona XtraDB Cluster](https://www.percona.com/doc/percona-xtradb-cluster/8.0/)

### Ferramentas Recomendadas
- **MySQL Workbench**: Interface gráfica
- **MySQL Shell**: Linha de comando avançada
- **Percona Toolkit**: Ferramentas de administração
- **ProxySQL**: Proxy de banco de dados
- **HAProxy**: Load balancer

### Comunidade
- [MySQL Forums](https://forums.mysql.com/)
- [Percona Community](https://www.percona.com/community/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/mysql-cluster)

---

*Este guia foi criado para fornecer uma visão abrangente sobre MySQL Cluster. Para implementações específicas, consulte a documentação oficial e considere consultar especialistas em banco de dados.*