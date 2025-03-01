# 2. 環境構築

このセクションでは、M系Mac OS（Apple Silicon搭載のMac）でHyperledger Fabric開発環境を構築する手順を説明します。

## 前提条件

- Apple Silicon搭載Mac（M1/M2/M3）
- macOS 12.0以上
- 管理者権限
- インターネット接続

## 1. 必要なツールのインストール

### Homebrewのインストール

Homebrewは、macOSのパッケージマネージャーで、必要なツールをインストールするために使用します。

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

インストール後、以下のコマンドを実行して、Homebrewを`PATH`に追加します：

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc
```

### Gitのインストール

```bash
brew install git
```

### Docker Desktopのインストール

Docker Desktopは、Hyperledger Fabricのコンテナを実行するために必要です。

1. [Docker Desktop for Mac（Apple Silicon）](https://www.docker.com/products/docker-desktop/)をダウンロードしてインストールします。
2. インストール後、Docker Desktopを起動します。
3. Docker Desktopの設定で、以下のリソースを割り当てることを推奨します：
   - CPUコア: 4コア以上
   - メモリ: 8GB以上
   - ディスク: 50GB以上

### Go言語のインストール

Hyperledger Fabricのチェーンコード開発にはGo言語が推奨されています。

```bash
brew install go
```

環境変数の設定：

```bash
echo 'export GOPATH=$HOME/go' >> ~/.zshrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
source ~/.zshrc
```

### Node.jsとnpmのインストール

アプリケーション開発用にNode.jsとnpmをインストールします：

```bash
brew install node
```

### jqのインストール

jqはJSON処理用のコマンドラインツールで、Fabricコマンドで役立ちます：

```bash
brew install jq
```

### Visual Studio Codeのインストール

推奨開発環境としてVSCodeをインストールします：

```bash
brew install --cask visual-studio-code
```

## 2. VSCode拡張機能のインストール

VSCodeを開き、以下の拡張機能をインストールします：

1. **IBM Blockchain Platform Extension**
   - ブロックチェーンネットワークの管理とチェーンコードの開発・デバッグ用
   - 拡張機能マーケットプレイスで「Blockchain」を検索

2. **Go extension**
   - Go言語開発用
   - 拡張機能マーケットプレイスで「Go」を検索

3. **Docker extension**
   - Dockerコンテナの管理用
   - 拡張機能マーケットプレイスで「Docker」を検索

4. **YAML extension**
   - 設定ファイル編集用
   - 拡張機能マーケットプレイスで「YAML」を検索

## 3. Hyperledger Fabricサンプルとバイナリのダウンロード

Hyperledger Fabricのサンプルとバイナリをダウンロードします：

```bash
mkdir -p ~/fabric-samples
cd ~/fabric-samples
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.4 1.5.6
```

このコマンドは以下を実行します：
- Fabricサンプルのダウンロード
- Fabricバイナリのダウンロード
- Fabricのドキュメントのダウンロード

## 4. 環境変数の設定

Fabricのバイナリを使用するために、以下の環境変数を設定します：

```bash
echo 'export PATH=$PATH:$HOME/fabric-samples/bin' >> ~/.zshrc
echo 'export FABRIC_CFG_PATH=$HOME/fabric-samples/config' >> ~/.zshrc
source ~/.zshrc
```

## 5. Docker環境の確認

Docker環境が正しく動作していることを確認します：

```bash
docker version
docker-compose version
```

両方のコマンドが正常に実行され、バージョン情報が表示されることを確認します。

## 6. セットアップスクリプトの使用（オプション）

このガイドには、上記の手順を自動化するセットアップスクリプトが含まれています。使用するには：

```bash
./scripts/setup.sh
```

## 7. デモネットワークの検証

環境がセットアップされたことを確認するため、テストネットワークを起動してみましょう：

```bash
cd ~/fabric-samples/test-network
./network.sh up
```

このコマンドは、2つの組織と1つのオーダリングサービスで構成される基本的なFabricネットワークを起動します。

正常に起動すると、以下のようなメッセージが表示されます：

```
Creating network "fabric_test" with the default driver
Creating orderer.example.com    ... done
Creating peer0.org2.example.com ... done
Creating peer0.org1.example.com ... done
```

テストが終わったら、ネットワークを停止します：

```bash
./network.sh down
```

## トラブルシューティング

### Dockerコンテナの起動に失敗する場合

1. Docker Desktopが起動していることを確認します
2. リソース設定（CPU、メモリ、ディスク）を確認します
3. 以下のコマンドでDocker環境をリセットしてみます：

```bash
docker system prune -a
```

### バイナリのインストールに失敗する場合

1. インターネット接続を確認します
2. プロキシ設定を確認します（必要な場合）
3. スクリプトを再実行します：

```bash
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.4 1.5.6
```

### テストネットワークの起動に失敗する場合

1. ネットワークを停止し、Docker環境をクリーンアップします：

```bash
cd ~/fabric-samples/test-network
./network.sh down
docker volume prune
```

2. 再度ネットワークを起動します：

```bash
./network.sh up
```

## 次のステップ

環境のセットアップが完了したら、次は[ネットワーク構築](3-network.md)に進み、テストネットワークの構築と設定方法を学びましょう。
