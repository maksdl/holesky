#!/bin/bash

# Создаем структуру папок
mkdir -p ~/holesky-node/{execution,consensus}/data && cd ~/holesky-node

# Создаем docker-compose.yml
cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  execution:
    image: ethereum/client-go:stable
    container_name: ethereum-execution-holesky
    restart: unless-stopped
    command:
      - "--holesky"
      - "--datadir=/data"
      - "--syncmode=snap"
      - "--txlookuplimit=0"
      - "--cache=1024"
      - "--http"
      - "--http.addr=0.0.0.0"
      - "--http.port=8545"
      - "--http.api=eth,net,web3"
      - "--http.vhosts=*"
      - "--http.corsdomain=*"
      - "--authrpc.addr=0.0.0.0"
      - "--authrpc.port=8551"
      - "--authrpc.vhosts=*"
      - "--authrpc.jwtsecret=/jwtsecret/jwt.hex"
    ports:
      - "8547:8545"
      - "8552:8551"
    volumes:
      - ./execution/data:/data
      - ./execution/jwtsecret:/jwtsecret
    networks:
      - holesky-net

  consensus:
    image: sigp/lighthouse:latest
    container_name: ethereum-consensus-holesky
    restart: unless-stopped
    command:
      - "lighthouse"
      - "beacon_node"
      - "--network=holesky"
      - "--datadir=/data"
      - "--http"
      - "--http-address=0.0.0.0"
      - "--http-port=5052"
      - "--checkpoint-sync-url=https://holesky.beaconstate.info"
      - "--execution-endpoint=http://execution:8551"
      - "--execution-jwt=/jwtsecret/jwt.hex"
    ports:
      - "9001:9000"
      - "5053:5052"
    volumes:
      - ./consensus/data:/data
      - ./execution/jwtsecret:/jwtsecret
    depends_on:
      - execution
    networks:
      - holesky-net

networks:
  holesky-net:
    driver: bridge
EOF

# Генерируем JWT-секрет
mkdir -p ./execution/jwtsecret
openssl rand -hex 32 > ./execution/jwtsecret/jwt.hex

# Открываем порты в firewall (если ufw)
if command -v ufw &> /dev/null; then
  sudo ufw allow 8547/tcp   # JSON-RPC
  sudo ufw allow 8552/tcp   # Auth-RPC
  sudo ufw allow 9001/tcp   # P2P
  sudo ufw allow 5053/tcp   # Beacon API
  echo "Порты 8547, 8552, 9001 и 5053 открыты в firewall"
fi

# Запускаем ноду
docker compose up -d

# Получаем IP-адрес
IP_ADDR=$(hostname -I | awk '{print $1}')

# Выводим итоговую информацию
echo -e "\n\n=== УСТАНОВКА ЗАВЕРШЕНА ==="
echo -e "\nRPC endpoints:"
echo "http://${IP_ADDR}:8547"
echo "http://${IP_ADDR}:5053"
echo -e "\nКоманды для логов:"
echo "docker logs -f ethereum-execution-holesky"
echo "docker logs -f ethereum-consensus-holesky"
