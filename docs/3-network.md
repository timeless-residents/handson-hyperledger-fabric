# 3. ネットワーク構築

このセクションでは、Hyperledger Fabricのテストネットワークを構築し、基本的な操作方法を学びます。

## テストネットワークの概要

Fabric Samplesに含まれる`test-network`は、Hyperledger Fabricの機能を学習するための基本的なネットワーク環境です。このネットワークは以下のコンポーネントで構成されています：

- 2つの組織（Org1とOrg2）、各組織に1つのピア
- 1つのオーダリングサービス
- Certificate Authority（CA）サーバー

## 1. テストネットワークの起動

### 基本的な起動

テストネットワークを起動するには、以下のコマンドを実行します：

```bash
cd ~/fabric-samples/test-network
./network.sh up
```

### CAを有効にして起動

Certificate Authority（CA）を有効にして起動するには：

```bash
./network.sh up -ca
```

### Fabricのバージョンを指定して起動

特定のバージョンのFabricを使用して起動するには：

```bash
./network.sh up -ca -s couchdb -i 2.4.1
```

このコマンドは、Fabric 2.4.1を使用し、状態データベースとしてCouchDBを有効にします。

## 2. チャネルの作成

Hyperledger Fabricのチャネルは、特定の参加者間でのプライベートな通信を可能にします。テストネットワークでチャネルを作成するには：

```bash
./network.sh createChannel -c mychannel
```

別のチャネル名を指定する場合：

```bash
./network.sh createChannel -c channel1
```

## 3. ネットワーク構成の確認

### 実行中のコンテナの確認

```bash
docker ps
```

以下のようなコンテナが実行されているはずです：
- `peer0.org1.example.com`
- `peer0.org2.example.com`
- `orderer.example.com`
- CA有効時: `ca_org1`、`ca_org2`、`ca_orderer`

### ネットワーク設定の確認

組織の設定ファイルを確認：

```bash
ls -la organizations/peerOrganizations/org1.example.com/
ls -la organizations/peerOrganizations/org2.example.com/
```

ここには、MSP（Membership Service Provider）設定、証明書、秘密鍵などが保存されています。

## 4. 環境変数の設定

Fabricコマンドを実行するための環境変数を設定します。まず、Org1のピアと通信するための設定：

```bash
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
```

Org2のピアと通信するには、以下の変数を変更します：

```bash
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
```

## 5. チャネル操作

### チャネルへの参加確認

チャネルへの参加を確認するには：

```bash
# Org1のピアで確認
peer channel list
```

出力例：
```
Channels peers has joined:
  mychannel
```

### チャネル情報の取得

チャネルの詳細情報を取得：

```bash
peer channel getinfo -c mychannel
```

### チャネル設定の取得

```bash
peer channel fetch config channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c mychannel --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

## 6. アンカーピアの設定

各組織のアンカーピアを設定することで、組織間の通信が可能になります。

Org1のアンカーピアを設定：

```bash
./network.sh setAnchorPeer -o 1 -c mychannel
```

Org2のアンカーピアを設定：

```bash
./network.sh setAnchorPeer -o 2 -c mychannel
```

## 7. CouchDBの使用（オプション）

デフォルトでは、テストネットワークはLevelDBを使用しますが、リッチクエリをサポートするCouchDBを有効にすることもできます：

```bash
./network.sh down
./network.sh up -s couchdb
./network.sh createChannel -c mychannel
```

CouchDBのUIにアクセスするには、ブラウザで以下のURLを開きます：
- Org1: http://localhost:5984/_utils/
- Org2: http://localhost:7984/_utils/

ユーザー名とパスワードはどちらも「admin/adminpw」です。

## 8. ネットワークのモニタリング

### ログの確認

各コンポーネントのログを確認するには：

```bash
# ピアのログ
docker logs peer0.org1.example.com
docker logs peer0.org2.example.com

# オーダラーのログ
docker logs orderer.example.com

# CAのログ
docker logs ca_org1
```

### コンテナへの接続

コンテナの内部を調査するには：

```bash
docker exec -it peer0.org1.example.com bash
```

## 9. ネットワークの停止

作業が終わったら、ネットワークを停止します：

```bash
./network.sh down
```

これにより、すべてのコンテナが停止・削除され、生成されたアーティファクトが削除されます。

## 10. 複数のチャネルを持つネットワーク（アドバンスド）

複数のチャネルを作成するには：

```bash
./network.sh up
./network.sh createChannel -c channel1
./network.sh createChannel -c channel2
```

異なるチャネルでチェーンコードをデプロイするには、`-c`フラグでチャネル名を指定します。

## トラブルシューティング

### ネットワークの起動に失敗する場合

1. Dockerが正しく動作していることを確認します：
```bash
docker version
```

2. 既存のネットワークとDockerリソースをクリーンアップします：
```bash
./network.sh down
docker system prune -a
docker volume prune
```

3. Dockerが十分なリソース（メモリ、CPU）を持っていることを確認します。

### チャネル作成に失敗する場合

1. ネットワークが正常に起動していることを確認します：
```bash
docker ps
```

2. ログを確認して問題を特定します：
```bash
docker logs orderer.example.com
```

3. ネットワークを再起動してチャネルを再作成します：
```bash
./network.sh down
./network.sh up
./network.sh createChannel -c mychannel
```

### ポートの競合が発生する場合

すでに使用されているポートがある場合（7050, 7051, 9051など）、以下のコマンドで使用中のポートを確認し、該当するプロセスを終了します：

```bash
lsof -i :7050
lsof -i :7051
lsof -i :9051
```

## ネットワーク構成の応用例

### 組織の追加

実際の本番環境では、ネットワークに新しい組織を追加することがあります。これをシミュレートするテスト方法：

```bash
cd ~/fabric-samples/test-network
./network.sh up -ca
./network.sh createChannel -c mychannel

# Org3を追加するスクリプトを実行
cd addOrg3
./addOrg3.sh up -c mychannel
```

これにより、既存のネットワークにOrg3が追加され、mychannelに参加します。

### 高度なネットワーク構成

より複雑なネットワークを構築する場合は、`configtx.yaml`と`docker-compose.yaml`ファイルをカスタマイズします：

```bash
# 設定ファイルのコピー
mkdir -p ~/fabric-custom-network
cp -r ~/fabric-samples/test-network/* ~/fabric-custom-network/
cd ~/fabric-custom-network

# configtx.yamlを編集して組織やチャネルを定義
nano configtx/configtx.yaml

# docker-compose.yamlを編集してノード構成をカスタマイズ
nano docker/docker-compose-test-net.yaml
```

## 実用的なヒント

### スクリプトの利用

繰り返し行う操作は、スクリプトにまとめておくと便利です：

```bash
#!/bin/bash
# start-network.sh

# ネットワークの起動
cd ~/fabric-samples/test-network
./network.sh down
./network.sh up -ca -s couchdb
./network.sh createChannel -c mychannel

# 環境変数の設定
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

echo "Network is up and running."
```

### 設定の保存

よく使う環境変数設定をファイルに保存しておくと便利です：

```bash
# org1.sh
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# org2.sh
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
```

使用時は：
```bash
source org1.sh
```

## 次のステップ

ネットワークの構築と操作方法を理解したら、次は[チェーンコード開発](4-chaincode.md)に進み、スマートコントラクトの開発とデプロイ方法を学びましょう。
