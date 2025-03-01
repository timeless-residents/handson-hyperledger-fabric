#!/bin/bash

# Hyperledger Fabric 開発環境セットアップスクリプト
# 対象環境: Apple Silicon Mac (M1/M2/M3)

set -e

echo "Hyperledger Fabric 開発環境セットアップを開始します..."

# 必要なディレクトリの作成
mkdir -p ~/fabric-projects

# Homebrew がインストールされているか確認
if ! command -v brew &> /dev/null; then
    echo "Homebrew をインストールしています..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # PATH の設定
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "Homebrew は既にインストールされています"
    brew update
fi

# Git のインストール
if ! command -v git &> /dev/null; then
    echo "Git をインストールしています..."
    brew install git
else
    echo "Git は既にインストールされています"
fi

# Docker Desktop のインストール確認
if ! command -v docker &> /dev/null; then
    echo "Docker Desktop for Mac をインストールしてください (手動インストールが必要です)"
    echo "ダウンロード先: https://www.docker.com/products/docker-desktop/"
    read -p "Docker Desktop をインストールしたら Enter キーを押してください..."
else
    echo "Docker は既にインストールされています"
fi

# Docker の設定確認
echo "Docker の設定を確認しています..."
echo "Docker Desktop の設定で、以下のリソースが割り当てられていることを確認してください:"
echo "- CPU: 少なくとも 4 コア"
echo "- メモリ: 少なくとも 8GB"
echo "- ディスク: 少なくとも 50GB"
read -p "確認できたら Enter キーを押してください..."

# Go 言語のインストール
if ! command -v go &> /dev/null; then
    echo "Go 言語をインストールしています..."
    brew install go
    
    # Go の環境変数を設定
    echo 'export GOPATH=$HOME/go' >> ~/.zshrc
    echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin
else
    echo "Go 言語は既にインストールされています"
fi

# Node.js のインストール
if ! command -v node &> /dev/null; then
    echo "Node.js をインストールしています..."
    brew install node
else
    echo "Node.js は既にインストールされています"
    # LTS バージョンに更新
    echo "Node.js のバージョンを確認しています..."
    node_version=$(node -v)
    echo "現在のバージョン: $node_version"
    read -p "Node.js を LTS バージョンに更新しますか？ (y/n): " update_node
    if [ "$update_node" = "y" ]; then
        brew upgrade node
    fi
fi

# jq のインストール (JSON 処理用)
if ! command -v jq &> /dev/null; then
    echo "jq をインストールしています..."
    brew install jq
else
    echo "jq は既にインストールされています"
fi

# VSCode のインストール確認
if ! command -v code &> /dev/null; then
    echo "Visual Studio Code をインストールしています..."
    brew install --cask visual-studio-code
else
    echo "Visual Studio Code は既にインストールされています"
fi

# VSCode 拡張機能のインストール推奨
echo "以下の VSCode 拡張機能をインストールすることをお勧めします:"
echo "- IBM Blockchain Platform Extension"
echo "- Go extension by Go Team at Google"
echo "- Docker extension by Microsoft"
echo "- YAML extension by Red Hat"
echo "VSCode を開き、Extensions タブから手動でインストールしてください"

# Hyperledger Fabric サンプルとバイナリのダウンロード
echo "Hyperledger Fabric サンプルとバイナリをダウンロードします..."
mkdir -p ~/fabric-samples
cd ~/fabric-samples

# 既存のダウンロードをチェック
if [ -d "bin" ] && [ -d "config" ]; then
    echo "Hyperledger Fabric サンプルは既にダウンロードされています"
    read -p "再ダウンロードしますか？ (y/n): " redownload
    if [ "$redownload" = "y" ]; then
        curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.4 1.5.6
    fi
else
    curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.4 1.5.6
fi

# PATH に Fabric バイナリを追加
echo 'export PATH=$PATH:$HOME/fabric-samples/bin' >> ~/.zshrc
export PATH=$PATH:$HOME/fabric-samples/bin

echo "環境変数を設定しています..."
echo 'export FABRIC_CFG_PATH=$HOME/fabric-samples/config' >> ~/.zshrc
export FABRIC_CFG_PATH=$HOME/fabric-samples/config

echo "セットアップが完了しました！"
echo "新しいターミナルを開くか、以下のコマンドを実行して環境変数を反映させてください:"
echo "source ~/.zshrc"

echo "次のステップ:"
echo "1. Docker Desktop を起動"
echo "2. テストネットワークを起動: cd ~/fabric-samples/test-network && ./network.sh up createChannel -c mychannel -ca"
echo "3. サンプルチェーンコードをデプロイ: ./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-go -ccl go"

exit 0