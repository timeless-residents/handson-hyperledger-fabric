# Hyperledger Fabric ハンズオンガイド

このリポジトリは、Hyperledger Fabricのハンズオンガイドを提供します。M系MacOSを使用し、VSCodeでの開発環境を前提としています。基本的なネットワーク構築から、チェーンコードの開発・デプロイ、運用管理まで、段階的に学ぶことができます。

## 概要

Hyperledger Fabricは、エンタープライズ向けの許可型ブロックチェーンフレームワークです。本ガイドでは、Hyperledger Fabricの基本概念から実際の開発・運用まで、実践的なハンズオン形式で解説します。

主な特徴：
- モジュラー設計による柔軟なアーキテクチャ
- プラグイン可能なコンセンサスプロトコル
- プライバシーと機密性の管理機能
- チャネルによる分離されたトランザクション台帳
- スマートコントラクト（チェーンコード）の多言語サポート

## 前提条件

このハンズオンガイドを実行するには、以下の環境が必要です：

- Apple Silicon搭載 Mac（M1/M2/M3）
- macOS 12.0以上
- Docker Desktop for Mac（Apple Silicon対応版）
- Git
- Visual Studio Code
- Go言語（1.16以上）
- Node.js（14.x以上）

## クイックスタート

### 1. リポジトリのクローン

```bash
git clone https://github.com/timeless-residents/hyperledger-fabric-guide.git
cd hyperledger-fabric-guide
```

### 2. 環境のセットアップ

```bash
# 必要なツールのインストール
./scripts/setup.sh

# Fabric サンプルとバイナリのダウンロード
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.4 1.5.6
```

### 3. テストネットワークの起動

```bash
cd fabric-samples/test-network
./network.sh up createChannel -c mychannel -ca
```

### 4. サンプルチェーンコードのデプロイ

```bash
./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-go -ccl go
```

### 5. チェーンコードの操作

```bash
# 環境変数の設定
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# 台帳の初期化
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C mychannel -n basic --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"function":"InitLedger","Args":[]}'

# 全アセットの取得
peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'
```

## ドキュメント構成

- [1. 概要](docs/1-overview.md) - Hyperledger Fabricの基本概念と主要コンポーネント
- [2. 環境構築](docs/2-setup.md) - 開発環境の構築と設定
- [3. ネットワーク構築](docs/3-network.md) - テストネットワークの構築と設定
- [4. チェーンコード開発](docs/4-chaincode.md) - スマートコントラクトの開発とデプロイ
- [5. 運用管理](docs/5-operations.md) - ネットワークの運用とモニタリング
- [6. 応用シナリオ](docs/6-use-cases.md) - 実用的なユースケースとサンプル実装

## サンプルコード

`sample-chaincode`ディレクトリには、以下のサンプルチェーンコードが含まれています：

- **asset-transfer** - 基本的な資産転送機能を実装したチェーンコード
- **supply-chain** - サプライチェーン管理のためのチェーンコード
- **identity-management** - アイデンティティ管理の実装例

各サンプルには、README.mdファイルと実装コードが含まれています。

## トラブルシューティング

よくある問題とその解決策については、[トラブルシューティングガイド](docs/troubleshooting.md)を参照してください。

## 貢献方法

このプロジェクトへの貢献を歓迎します。貢献方法については[CONTRIBUTING.md](CONTRIBUTING.md)を参照してください。

## ライセンス

このプロジェクトは[Apache License 2.0](LICENSE)の下で公開されています。

## 参考リソース

- [Hyperledger Fabric 公式ドキュメント](https://hyperledger-fabric.readthedocs.io/)
- [Fabric サンプルリポジトリ](https://github.com/hyperledger/fabric-samples)

---

**注意**: このガイドは教育目的で作成されています。本番環境での使用には、セキュリティやパフォーマンスの追加検討が必要です。