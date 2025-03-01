# 4. チェーンコード開発

このセクションでは、Hyperledger Fabricのスマートコントラクト（チェーンコード）の開発、デプロイ、呼び出し方法について説明します。

## チェーンコードの概要

チェーンコードは、Hyperledger Fabricにおけるスマートコントラクトの実装です。ブロックチェーン台帳とのやり取りを定義する、分散アプリケーションロジックです。以下の言語で開発可能です：

- Go（推奨）
- Node.js
- Java

このガイドでは、主にGo言語を使用してチェーンコードを開発します。

## 1. チェーンコードの基本構造

Go言語によるチェーンコードの基本構造は以下の通りです：

```go
package main

import (
	"fmt"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract は契約を実装する構造体です
type SmartContract struct {
	contractapi.Contract
}

// Init はチェーンコードの初期化関数です（オプション）
func (s *SmartContract) Init(ctx contractapi.TransactionContextInterface) error {
	return nil
}

// YourFunction はチェーンコードのカスタム関数です
func (s *SmartContract) YourFunction(ctx contractapi.TransactionContextInterface, param1 string, param2 string) (string, error) {
	// ビジネスロジックを実装
	return "結果", nil
}

func main() {
	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		fmt.Printf("Error creating chaincode: %s", err.Error())
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting chaincode: %s", err.Error())
	}
}
```

## 2. 台帳とのやり取り

チェーンコードでは、`ctx.GetStub()`メソッドを使って台帳とやり取りします：

```go
// CreateAsset は新しい資産を作成します
func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, id string, value string) error {
	// 既に存在するか確認
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return fmt.Errorf("台帳の読み取りに失敗しました: %v", err)
	}
	if assetJSON != nil {
		return fmt.Errorf("資産 %s は既に存在します", id)
	}

	// 新しい資産を作成
	asset := Asset{
		ID:    id,
		Value: value,
	}
	assetJSON, err = json.Marshal(asset)
	if err != nil {
		return err
	}

	// 台帳に保存
	return ctx.GetStub().PutState(id, assetJSON)
}

// ReadAsset は資産を読み取ります
func (s *SmartContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("台帳の読み取りに失敗しました: %v", err)
	}
	if assetJSON == nil {
		return nil, fmt.Errorf("資産 %s は存在しません", id)
	}

	var asset Asset
	err = json.Unmarshal(assetJSON, &asset)
	if err != nil {
		return nil, err
	}
	return &asset, nil
}
```

## 3. サンプルチェーンコードの作成

アセット転送の基本的なチェーンコードを作成してみましょう：

```bash
mkdir -p ~/fabric-samples/chaincode/asset-transfer
cd ~/fabric-samples/chaincode/asset-transfer
```

`asset-transfer.go`ファイルを作成：

```go
package main

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// AssetTransfer チェーンコードの実装
type AssetTransfer struct {
	contractapi.Contract
}

// Asset はブロックチェーンに保存する資産を表します
type Asset struct {
	ID             string `json:"ID"`
	Owner          string `json:"Owner"`
	Value          int    `json:"Value"`
	CreationDate   string `json:"CreationDate"`
	LastUpdateDate string `json:"LastUpdateDate"`
}

// InitLedger は台帳に初期データを追加します
func (s *AssetTransfer) InitLedger(ctx contractapi.TransactionContextInterface) error {
	assets := []Asset{
		{ID: "asset1", Owner: "山田", Value: 100, CreationDate: "2023-01-01", LastUpdateDate: "2023-01-01"},
		{ID: "asset2", Owner: "佐藤", Value: 200, CreationDate: "2023-01-02", LastUpdateDate: "2023-01-02"},
	}

	for _, asset := range assets {
		assetJSON, err := json.Marshal(asset)
		if err != nil {
			return err
		}

		err = ctx.GetStub().PutState(asset.ID, assetJSON)
		if err != nil {
			return fmt.Errorf("台帳への書き込みに失敗しました: %v", err)
		}
	}

	return nil
}

// CreateAsset は新しい資産を作成します
func (s *AssetTransfer) CreateAsset(ctx contractapi.TransactionContextInterface, id string, owner string, value int, creationDate string) error {
	exists, err := s.AssetExists(ctx, id)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("資産 %s は既に存在します", id)
	}

	asset := Asset{
		ID:             id,
		Owner:          owner,
		Value:          value,
		CreationDate:   creationDate,
		LastUpdateDate: creationDate,
	}
	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(id, assetJSON)
}

// ReadAsset は指定されたIDの資産を返します
func (s *AssetTransfer) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("台帳の読み取りに失敗しました: %v", err)
	}
	if assetJSON == nil {
		return nil, fmt.Errorf("資産 %s は存在しません", id)
	}

	var asset Asset
	err = json.Unmarshal(assetJSON, &asset)
	if err != nil {
		return nil, err
	}

	return &asset, nil
}

// UpdateAsset は既存の資産を更新します
func (s *AssetTransfer) UpdateAsset(ctx contractapi.TransactionContextInterface, id string, owner string, value int, updateDate string) error {
	asset, err := s.ReadAsset(ctx, id)
	if err != nil {
		return err
	}

	asset.Owner = owner
	asset.Value = value
	asset.LastUpdateDate = updateDate

	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(id, assetJSON)
}

// DeleteAsset は指定された資産を削除します
func (s *AssetTransfer) DeleteAsset(ctx contractapi.TransactionContextInterface, id string) error {
	exists, err := s.AssetExists(ctx, id)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("資産 %s は存在しません", id)
	}

	return ctx.GetStub().DelState(id)
}

// AssetExists は資産が存在するかどうかを確認します
func (s *AssetTransfer) AssetExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, fmt.Errorf("台帳の読み取りに失敗しました: %v", err)
	}

	return assetJSON != nil, nil
}

// GetAllAssets は台帳のすべての資産を返します
func (s *AssetTransfer) GetAllAssets(ctx contractapi.TransactionContextInterface) ([]*Asset, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var assets []*Asset
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var asset Asset
		err = json.Unmarshal(queryResponse.Value, &asset)
		if err != nil {
			return nil, err
		}
		assets = append(assets, &asset)
	}

	return assets, nil
}

// TransferAsset は資産を新しい所有者に転送します
func (s *AssetTransfer) TransferAsset(ctx contractapi.TransactionContextInterface, id string, newOwner string) error {
	asset, err := s.ReadAsset(ctx, id)
	if err != nil {
		return err
	}

	asset.Owner = newOwner
	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(id, assetJSON)
}

func main() {
	assetChaincode, err := contractapi.NewChaincode(&AssetTransfer{})
	if err != nil {
		fmt.Printf("Error creating asset-transfer chaincode: %v", err)
		return
	}

	if err := assetChaincode.Start(); err != nil {
		fmt.Printf("Error starting asset-transfer chaincode: %v", err)
	}
}
```

## 4. チェーンコードのパッケージング

チェーンコードの依存関係を管理するために、Go Modulesを初期化します：

```bash
cd ~/fabric-samples/chaincode/asset-transfer
go mod init github.com/yourusername/asset-transfer
go mod tidy
```

チェーンコードをパッケージ化します（テストネットワークが起動していることを確認してください）：

```bash
cd ~/fabric-samples/test-network
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/

peer lifecycle chaincode package asset-transfer.tar.gz --path ../chaincode/asset-transfer --lang golang --label asset_transfer_1.0
```

## 5. チェーンコードのインストールとデプロイ

### Org1へのインストール

```bash
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode install asset-transfer.tar.gz
```

### Org2へのインストール

```bash
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode install asset-transfer.tar.gz
```

### パッケージIDの取得

```bash
# Org1に戻す
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode queryinstalled
```

出力からパッケージIDをコピーします（例：`asset_transfer_1.0:a123...`）：

```bash
export CC_PACKAGE_ID=asset_transfer_1.0:a123...  # 実際のIDに置き換え
```

### チェーンコード定義の承認

Org1による承認：

```bash
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name asset-transfer --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

Org2による承認：

```bash
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name asset-transfer --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

### 承認状態の確認

```bash
peer lifecycle chaincode checkcommitreadiness --channelID mychannel --name asset-transfer --version 1.0 --sequence 1 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --output json
```

出力例：
```json
{
    "approvals": {
        "Org1MSP": true,
        "Org2MSP": true
    }
}
```

### チェーンコード定義のコミット

```bash
peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name asset-transfer --version 1.0 --sequence 1 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
```

### コミット状態の確認

```bash
peer lifecycle chaincode querycommitted --channelID mychannel --name asset-transfer --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

## 6. チェーンコードの呼び出し

### 台帳の初期化

```bash
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C mychannel -n asset-transfer --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"function":"InitLedger","Args":[]}'
```

### 全アセットの取得

```bash
peer chaincode query -C mychannel -n asset-transfer -c '{"Args":["GetAllAssets"]}'
```

### 特定のアセットの取得

```bash
peer chaincode query -C mychannel -n asset-transfer -c '{"Args":["ReadAsset","asset1"]}'
```

### 新しいアセットの作成

```bash
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C mychannel -n asset-transfer --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"function":"CreateAsset","Args":["asset3","田中","300","2023-01-03"]}'
```

### アセットの更新

```bash
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C mychannel -n asset-transfer --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"function":"UpdateAsset","Args":["asset1","鈴木","150","2023-01-10"]}'
```

### アセットの転送

```bash
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C mychannel -n asset-transfer --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"function":"TransferAsset","Args":["asset2","高橋"]}'
```

### アセットの削除

```bash
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C mychannel -n asset-transfer --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"function":"DeleteAsset","Args":["asset3"]}'
```

## 7. サンプルチェーンコードのデプロイ（簡易方法）

Fabric Samplesには、サンプルチェーンコードをデプロイするための便利なスクリプトが含まれています：

```bash
cd ~/fabric-samples/test-network
./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-go -ccl go
```

これにより、基本的なアセット転送チェーンコードがデプロイされます。

## 8. チェーンコード開発のベストプラクティス

### エラー処理

適切なエラーハンドリングを実装し、意味のあるエラーメッセージを返すようにします：

```go
if asset == nil {
    return nil, fmt.Errorf("資産 %s は存在しません", id)
}
```

### トランザクションの検証

入力パラメータを検証して、無効なトランザクションを防ぎます：

```go
if len(id) == 0 {
    return fmt.Errorf("資産IDは必須です")
}
if value < 0 {
    return fmt.Errorf("価値は0以上である必要があります")
}
```

### プライベートデータの使用

機密情報を保護するためにプライベートデータコレクションを使用することを検討します：

```go
// プライベートデータコレクションに保存
err = ctx.GetStub().PutPrivateData("collectionName", id, assetJSON)
```

### イベントの発行

重要なアクションが実行されたときにイベントを発行します：

```go
err = ctx.GetStub().SetEvent("AssetCreated", []byte(id))
```

### リッチクエリの実装（CouchDBの場合）

CouchDBを使用している場合、JSONクエリを使用してリッチクエリを実装できます：

```go
func (s *SmartContract) QueryAssetsByOwner(ctx contractapi.TransactionContextInterface, owner string) ([]*Asset, error) {
    queryString := fmt.Sprintf(`{"selector":{"Owner":"%s"}}`, owner)
    return getQueryResultForQueryString(ctx, queryString)
}
```

## 9. チェーンコードのテスト

### 単体テスト

チェーンコードの単体テストを作成します。`asset-transfer_test.go`ファイルを作成：

```go
package main

import (
	"testing"
	
	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

// モックの実装
type MockStub struct {
	mock.Mock
	shim.ChaincodeStubInterface
}

func (ms *MockStub) GetState(key string) ([]byte, error) {
	args := ms.Called(key)
	return args.Get(0).([]byte), args.Error(1)
}

func (ms *MockStub) PutState(key string, value []byte) error {
	args := ms.Called(key, value)
	return args.Error(0)
}

type MockContext struct {
	contractapi.TransactionContextInterface
	stub *MockStub
}

func (mc *MockContext) GetStub() shim.ChaincodeStubInterface {
	return mc.stub
}

// テストケース
func TestCreateAsset(t *testing.T) {
	var assetTransfer = new(AssetTransfer)
	
	// モックの設定
	mockStub := new(MockStub)
	mockContext := new(MockContext)
	mockContext.stub = mockStub
	
	// 新しいアセットのテスト
	mockStub.On("GetState", "asset1").Return([]byte{}, nil)
	mockStub.On("PutState", "asset1", mock.Anything).Return(nil)
	
	err := assetTransfer.CreateAsset(mockContext, "asset1", "所有者1", 100, "2023-01-01")
	require.NoError(t, err)
	
	// 既存アセットのテスト
	mockStub.On("GetState", "asset2").Return([]byte(`{"ID":"asset2"}`), nil)
	
	err = assetTransfer.CreateAsset(mockContext, "asset2", "所有者2", 200, "2023-01-02")
	require.Error(t, err)
	require.Contains(t, err.Error(), "既に存在します")
	
	mockStub.AssertExpectations(t)
}
```

テストの実行：

```bash
cd ~/fabric-samples/chaincode/asset-transfer
go test -v
```

### 統合テスト

テストネットワークで実際にチェーンコードをデプロイして、エンドツーエンドでテストします。

## 10. チェーンコードのアップグレード

チェーンコードを更新して新しいバージョンをデプロイする手順：

1. 新バージョンのパッケージング：

```bash
cd ~/fabric-samples/test-network
peer lifecycle chaincode package asset-transfer_v2.0.tar.gz --path ../chaincode/asset-transfer --lang golang --label asset_transfer_2.0
```

2. 新バージョンのインストール（両組織）：

```bash
# Org1
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode install asset-transfer_v2.0.tar.gz

# Org2
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode install asset-transfer_v2.0.tar.gz
```

3. パッケージIDの取得：

```bash
# Org1に戻す
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode queryinstalled
```

4. 新バージョンの承認（シーケンス番号を増やす）：

```bash
export CC_PACKAGE_ID=asset_transfer_2.0:abc123...  # 新しいIDに置き換え

# Org1
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name asset-transfer --version 2.0 --package-id $CC_PACKAGE_ID --sequence 2 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Org2
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name asset-transfer --version 2.0 --package-id $CC_PACKAGE_ID --sequence 2 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

5. 新バージョンのコミット：

```bash
peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name asset-transfer --version 2.0 --sequence 2 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
```

## 11. プライベートデータコレクション

機密データを扱う場合は、プライベートデータコレクションを使用します。

プライベートデータコレクションの定義ファイル `collections_config.json`：

```json
[
    {
        "name": "assetCollection",
        "policy": "OR('Org1MSP.member', 'Org2MSP.member')",
        "requiredPeerCount": 1,
        "maxPeerCount": 3,
        "blockToLive": 100000,
        "memberOnlyRead": true
    },
    {
        "name": "assetPrivateDetails",
        "policy": "OR('Org1MSP.member')",
        "requiredPeerCount": 0,
        "maxPeerCount": 3,
        "blockToLive": 3,
        "memberOnlyRead": true
    }
]
```

プライベートデータを使用するチェーンコードの例：

```go
// CreateAssetPrivateData はプライベートデータでアセットを作成します
func (s *SmartContract) CreateAssetPrivateData(ctx contractapi.TransactionContextInterface, id string) error {
    // パブリックデータの保存
    asset := Asset{
        ID: id,
        Public: "public value",
    }
    assetJSON, err := json.Marshal(asset)
    if err != nil {
        return err
    }
    err = ctx.GetStub().PutState(id, assetJSON)
    if err != nil {
        return err
    }

    // プライベートデータの保存
    privateData := map[string]interface{}{
        "owner": "private owner",
        "value": "sensitive value",
    }
    privateDataJSON, err := json.Marshal(privateData)
    if err != nil {
        return err
    }
    
    return ctx.GetStub().PutPrivateData("assetPrivateDetails", id, privateDataJSON)
}
```

プライベートデータコレクションでチェーンコードをデプロイする場合：

```bash
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name asset-transfer --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --collections-config ../chaincode/asset-transfer/collections_config.json
```

## 次のステップ

チェーンコードの開発とデプロイ方法を理解したら、次は[運用管理](5-operations.md)に進み、Hyperledger Fabricネットワークの運用とモニタリング方法を学びましょう。
