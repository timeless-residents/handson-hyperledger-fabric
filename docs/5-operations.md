# 5. 運用管理

このセクションでは、Hyperledger Fabricネットワークの運用管理、モニタリング、トラブルシューティングについて説明します。

## 1. ネットワーク管理の基本

### コンポーネントの状態確認

```bash
# Dockerコンテナの状態確認
docker ps

# 特定のコンテナの詳細情報
docker inspect peer0.org1.example.com

# ネットワークの状態確認
docker network ls
docker network inspect fabric_test
```

### ログの確認と分析

```bash
# ピアのログ確認
docker logs -f peer0.org1.example.com

# オーダラーのログ確認
docker logs -f orderer.example.com

# CAサーバーのログ確認
docker logs -f ca_org1

# 特定のキーワードでフィルタリング
docker logs peer0.org1.example.com | grep ERROR
```

### 設定ファイルの管理

主要な設定ファイルの場所：

- ピア設定: `fabric-samples/config/core.yaml`
- オーダラー設定: `fabric-samples/config/orderer.yaml`
- チャネル設定: `fabric-samples/config/configtx.yaml`

設定を変更する場合は、オリジナルをバックアップしてから編集します：

```bash
cd ~/fabric-samples/config
cp core.yaml core.yaml.bak
nano core.yaml
```

## 2. チャネル管理

### チャネル情報の取得

```bash
# チャネルの一覧取得
peer channel list

# チャネルの詳細情報
peer channel getinfo -c mychannel
```

### チャネル設定の更新

チャネル設定を更新するプロセス：

1. 現在の設定を取得：

```bash
peer channel fetch config channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c mychannel --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

2. 設定をJSONに変換：

```bash
configtxlator proto_decode --input channel-artifacts/config_block.pb --type common.Block | jq .data.data[0].payload.data.config > channel-artifacts/config.json
```

3. 変更を加えたJSONを作成（例：バッチタイムアウトの変更）：

```bash
jq '.channel_group.groups.Orderer.values.BatchTimeout.value.timeout = "2s"' channel-artifacts/config.json > channel-artifacts/modified_config.json
```

4. 設定の差分を計算：

```bash
configtxlator proto_encode --input channel-artifacts/config.json --type common.Config > channel-artifacts/original_config.pb
configtxlator proto_encode --input channel-artifacts/modified_config.json --type common.Config > channel-artifacts/modified_config.pb
configtxlator compute_update --channel_id mychannel --original channel-artifacts/original_config.pb --updated channel-artifacts/modified_config.pb > channel-artifacts/config_update.pb
```

5. 更新を適用：

```bash
configtxlator proto_decode --input channel-artifacts/config_update.pb --type common.ConfigUpdate | jq . > channel-artifacts/config_update.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"mychannel", "type":2}},"data":{"config_update":'$(cat channel-artifacts/config_update.json)'}}}' | jq . > channel-artifacts/config_update_in_envelope.json
configtxlator proto_encode --input channel-artifacts/config_update_in_envelope.json --type common.Envelope > channel-artifacts/config_update_in_envelope.pb
peer channel update -f channel-artifacts/config_update_in_envelope.pb -c mychannel -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

### 組織の追加

新しい組織をチャネルに追加する手順（テストネットワークの例）：

```bash
cd ~/fabric-samples/test-network
./network.sh up createChannel -c mychannel -ca

# Org3を追加
cd addOrg3
./addOrg3.sh up -c mychannel
```

## 3. ブロックチェーンデータの管理

### ブロック情報の取得

```bash
# 最新のブロックを取得
peer channel fetch newest channel-artifacts/newest_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c mychannel --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# 特定のブロック番号を取得
peer channel fetch 1 channel-artifacts/block_1.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c mychannel --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

### ブロック内容の確認

```bash
configtxlator proto_decode --input channel-artifacts/newest_block.pb --type common.Block | jq . > channel-artifacts/newest_block.json
```

### トランザクション履歴の確認

```bash
# チェーンコードのクエリを使用
peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'
```

## 4. 証明書と鍵の管理

### 証明書の確認

```bash
# 組織の証明書確認
ls -la organizations/peerOrganizations/org1.example.com/msp/cacerts/

# ピアの証明書確認
ls -la organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp/signcerts/
```

### 証明書の更新

証明書の有効期限が切れる前に更新する必要があります：

```bash
# CAを使用して新しい証明書を生成
fabric-ca-client enroll -u https://admin:adminpw@localhost:7054 --caname ca-org1 -M ${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp --tls.certfiles ${PWD}/organizations/fabric-ca/org1/tls-cert.pem
```

### 鍵の保護

秘密鍵の安全な管理：

1. 適切なファイル権限の設定：
   ```bash
   chmod 600 organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore/*
   ```

2. 本番環境ではハードウェアセキュリティモジュール（HSM）の使用を検討

## 5. モニタリングとログ管理

### プロメテウスとグラファナの設定

Hyperledger Fabricのメトリクスをモニタリングするために、プロメテウスとグラファナを設定します：

1. `docker-compose-prometheus.yaml`ファイルの作成：

```yaml
version: '2.1'

networks:
  fabric_test:
    external: true

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - --config.file=/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
    networks:
      - fabric_test

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    networks:
      - fabric_test
    depends_on:
      - prometheus
```

2. `prometheus.yml`の設定：

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'fabric'
    static_configs:
      - targets: ['peer0.org1.example.com:9443', 'peer0.org2.example.com:9443', 'orderer.example.com:9443']
```

3. モニタリングの開始：

```bash
docker-compose -f docker-compose-prometheus.yaml up -d
```

4. グラファナにアクセス（http://localhost:3000）し、ダッシュボードを設定

### ELKスタックによるログ管理

Elasticsearch、Logstash、Kibanaを使用したログ収集と分析：

1. `docker-compose-elk.yaml`の作成：

```yaml
version: '2.1'

networks:
  fabric_test:
    external: true

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.12.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
    ports:
      - "9200:9200"
    networks:
      - fabric_test

  logstash:
    image: docker.elastic.co/logstash/logstash:7.12.0
    container_name: logstash
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
    ports:
      - "5000:5000"
    networks:
      - fabric_test
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:7.12.0
    container_name: kibana
    ports:
      - "5601:5601"
    networks:
      - fabric_test
    depends_on:
      - elasticsearch
```

2. Logstashパイプラインの設定：

```
input {
  tcp {
    port => 5000
    codec => json
  }
}

filter {
  json {
    source => "message"
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "fabric-logs-%{+YYYY.MM.dd}"
  }
}
```

3. Fabricノードのログドライバーを設定：

```yaml
logging:
  driver: "gelf"
  options:
    gelf-address: "tcp://localhost:5000"
    tag: "peer0.org1.example.com"
```

## 6. バックアップと復旧

### 台帳データのバックアップ

1. コンテナを停止：

```bash
cd ~/fabric-samples/test-network
./network.sh down
```

2. データボリュームのバックアップ：

```bash
docker volume ls | grep fabric
docker volume create --name fabric_data_backup
docker run --rm -v fabric_peer0.org1.example.com:/source -v fabric_data_backup:/dest alpine cp -a /source/. /dest
```

### 設定ファイルのバックアップ

重要な設定ファイルをバックアップ：

```bash
mkdir -p backups/config
cp -r ~/fabric-samples/config backups/config/
cp -r ~/fabric-samples/test-network/organizations backups/organizations/
```

### 証明書のバックアップ

```bash
mkdir -p backups/crypto
cp -r ~/fabric-samples/test-network/organizations backups/crypto/
```

### 復旧手順

1. データボリュームの復元：

```bash
docker run --rm -v fabric_data_backup:/source -v fabric_peer0.org1.example.com:/dest alpine cp -a /source/. /dest
```

2. ネットワークの再起動：

```bash
cd ~/fabric-samples/test-network
./network.sh up
```

## 7. 障害対応と復旧

### よくある問題と解決策

#### ピアが同期しない

問題: ピアがブロックチェーンと同期しない

解決策:
```bash
# ピアのログを確認
docker logs -f peer0.org1.example.com

# ピアの再起動
docker stop peer0.org1.example.com
docker start peer0.org1.example.com

# チャネル参加状態の確認
peer channel list
```

#### トランザクションが失敗する

問題: トランザクションがコミットされない

解決策:
```bash
# エンドースメントポリシーの確認
peer chaincode query -C mychannel -n qscc -c '{"Args":["GetTransactionByID","mychannel","txid"]}'

# 再度トランザクションを送信
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C mychannel -n basic --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"function":"CreateAsset","Args":["asset3","田中","300","2023-01-03"]}'
```

#### オーダラーが停止する

問題: オーダリングサービスが応答しない

解決策:
```bash
# オーダラーのログを確認
docker logs -f orderer.example.com

# オーダラーの再起動
docker stop orderer.example.com
docker start orderer.example.com

# システムチャンネルの状態確認
peer channel fetch config channel-artifacts/sys_config.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c system-channel --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

### 障害復旧計画

1. バックアップの定期的な取得
2. 障害発生時の連絡フロー確立
3. 復旧手順のドキュメント化と定期的な訓練
4. フェイルオーバー手順の確立

## 8. ネットワークのアップグレード

### Fabric バージョンのアップグレード

1. 新しいバージョンの確認：

```bash
# Fabric の最新バージョンを確認
curl -sSL https://hyperledger.github.io/fabric/latest_release | grep -o "v[0-9]\.[0-9]\.[0-9]"
```

2. 環境のバックアップ

3. 新しいバイナリのダウンロード：

```bash
cd ~/fabric-samples
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.0 1.5.0
```

4. 既存のネットワークの停止：

```bash
cd ~/fabric-samples/test-network
./network.sh down
```

5. 新しいバージョンでネットワークを起動：

```bash
./network.sh up createChannel -c mychannel -ca -i 2.5.0
```

### 新機能の追加

1. CouchDBの有効化：

```bash
./network.sh down
./network.sh up createChannel -c mychannel -ca -s couchdb
```

2. TLS設定の更新：

```bash
# core.yamlの編集
nano ~/fabric-samples/config/core.yaml
# tls.enabledをtrueに設定
```

## 9. セキュリティ管理

### TLSの設定確認

```bash
# TLS証明書の確認
ls -la organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/

# TLS設定の確認
grep -A 10 "tls:" ~/fabric-samples/config/core.yaml
```

### アクセス制御の設定

1. ポリシーの確認：

```bash
# チャネルアクセスポリシーの確認
configtxlator proto_decode --input channel-artifacts/config_block.pb --type common.Block | jq .data.data[0].payload.data.config.channel_group.groups.Application.policies
```

2. MSP設定の確認：

```bash
ls -la organizations/peerOrganizations/org1.example.com/msp/admincerts/
```

### セキュリティ監査

1. ログの監査：

```bash
docker logs peer0.org1.example.com | grep "access denied"
```

2. 権限の確認：

```bash
# ファイル権限の確認
ls -la organizations/peerOrganizations/org1.example.com/msp/keystore/
```

## 10. パフォーマンスチューニング

### リソース割り当ての最適化

Docker コンテナへのリソース割り当て：

```yaml
services:
  peer0.org1.example.com:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 1G
        reservations:
          cpus: '0.25'
          memory: 512M
```

### ブロック設定の最適化

`configtx.yaml`でのブロックパラメータの調整：

```yaml
Orderer: &OrdererDefaults
  BatchTimeout: 1s
  BatchSize:
    MaxMessageCount: 100
    AbsoluteMaxBytes: 10 MB
    PreferredMaxBytes: 2 MB
```

### キャッシュ設定

`core.yaml`でのキャッシュパラメータ：

```yaml
peer:
  gossip:
    pvtData:
      pushAckTimeout: 3s
      btlPullMargin: 10
      transientstoreMaxBlockRetention: 1000
      skipPullingInvalidTransactionsDuringCommit: false
  couchDBConfig:
    cacheSize: 64
```

## 次のステップ

運用管理の基本を理解したら、次は[応用シナリオ](6-use-cases.md)に進み、Hyperledger Fabricの実用的なユースケースと実装例を学びましょう。
