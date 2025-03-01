# 6. 応用シナリオ

このセクションでは、Hyperledger Fabricの実用的なユースケースとその実装例を紹介します。これらの例を参考に、独自のブロックチェーンアプリケーションを開発することができます。

## 1. サプライチェーン管理

### ユースケース概要

サプライチェーン管理は、Hyperledger Fabricの最も一般的な応用分野の一つです。複数の企業や組織が関わるサプライチェーンでは、透明性と信頼性の確保が重要な課題です。

主な機能：
- 製品のライフサイクル追跡
- 所有権の移転記録
- 品質証明書の管理
- リコールなどの緊急時対応
- コンプライアンス証明

### 実装例

#### アセットの定義

```go
// Product は追跡する製品を表します
type Product struct {
    ID             string            `json:"id"`
    Name           string            `json:"name"`
    Manufacturer   string            `json:"manufacturer"`
    ManufactureDate string           `json:"manufactureDate"`
    Type           string            `json:"type"`
    Owner          string            `json:"owner"`
    Status         string            `json:"status"` // "製造中", "出荷済", "卸売業者", "小売業者", "販売済"
    Location       string            `json:"location"`
    Certificates   map[string]string `json:"certificates"`
    History        []HistoryItem     `json:"history"`
}

// HistoryItem は製品の履歴項目を表します
type HistoryItem struct {
    Timestamp string `json:"timestamp"`
    Location  string `json:"location"`
    Action    string `json:"action"`
    Actor     string `json:"actor"`
}
```

#### 主要機能の実装

1. **製品登録**:

```go
func (s *SmartContract) CreateProduct(ctx contractapi.TransactionContextInterface, id string, name string, manufacturer string, manufactureDate string, productType string) error {
    exists, err := s.ProductExists(ctx, id)
    if err != nil {
        return err
    }
    if exists {
        return fmt.Errorf("製品 %s は既に存在します", id)
    }

    // 現在の時刻を取得
    timestamp, err := s.GetTimestamp(ctx)
    if err != nil {
        return err
    }

    historyItem := HistoryItem{
        Timestamp: timestamp,
        Location:  manufacturer + " 工場",
        Action:    "製造",
        Actor:     manufacturer,
    }

    product := Product{
        ID:             id,
        Name:           name,
        Manufacturer:   manufacturer,
        ManufactureDate: manufactureDate,
        Type:           productType,
        Owner:          manufacturer,
        Status:         "製造中",
        Location:       manufacturer + " 工場",
        Certificates:   make(map[string]string),
        History:        []HistoryItem{historyItem},
    }

    productJSON, err := json.Marshal(product)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(id, productJSON)
}
```

2. **所有権移転**:

```go
func (s *SmartContract) TransferProduct(ctx contractapi.TransactionContextInterface, id string, newOwner string, location string) error {
    product, err := s.ReadProduct(ctx, id)
    if err != nil {
        return err
    }

    // 現在の時刻を取得
    timestamp, err := s.GetTimestamp(ctx)
    if err != nil {
        return err
    }

    historyItem := HistoryItem{
        Timestamp: timestamp,
        Location:  location,
        Action:    "所有権移転: " + product.Owner + " から " + newOwner + " へ",
        Actor:     ctx.GetClientIdentity().GetID(),
    }

    product.Owner = newOwner
    product.Location = location
    product.Status = s.DetermineStatus(newOwner, product.Status)
    product.History = append(product.History, historyItem)

    productJSON, err := json.Marshal(product)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(id, productJSON)
}

func (s *SmartContract) DetermineStatus(owner string, currentStatus string) string {
    if strings.Contains(strings.ToLower(owner), "wholesaler") {
        return "卸売業者"
    } else if strings.Contains(strings.ToLower(owner), "retailer") {
        return "小売業者"
    } else if strings.Contains(strings.ToLower(owner), "customer") {
        return "販売済"
    }
    return currentStatus
}
```

3. **品質証明書の追加**:

```go
func (s *SmartContract) AddCertificate(ctx contractapi.TransactionContextInterface, id string, certType string, certValue string) error {
    product, err := s.ReadProduct(ctx, id)
    if err != nil {
        return err
    }

    // 現在の時刻を取得
    timestamp, err := s.GetTimestamp(ctx)
    if err != nil {
        return err
    }

    historyItem := HistoryItem{
        Timestamp: timestamp,
        Location:  product.Location,
        Action:    "証明書追加: " + certType,
        Actor:     ctx.GetClientIdentity().GetID(),
    }

    // 証明書を追加
    product.Certificates[certType] = certValue
    product.History = append(product.History, historyItem)

    productJSON, err := json.Marshal(product)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(id, productJSON)
}
```

4. **製品履歴の取得**:

```go
func (s *SmartContract) GetProductHistory(ctx contractapi.TransactionContextInterface, id string) (*Product, error) {
    productJSON, err := ctx.GetStub().GetState(id)
    if err != nil {
        return nil, fmt.Errorf("製品 %s の取得に失敗しました: %v", id, err)
    }
    if productJSON == nil {
        return nil, fmt.Errorf("製品 %s は存在しません", id)
    }

    var product Product
    err = json.Unmarshal(productJSON, &product)
    if err != nil {
        return nil, err
    }

    return &product, nil
}
```

5. **トレーサビリティクエリ**:

```go
func (s *SmartContract) QueryProductsByManufacturer(ctx contractapi.TransactionContextInterface, manufacturer string) ([]*Product, error) {
    queryString := fmt.Sprintf(`{"selector":{"manufacturer":"%s"}}`, manufacturer)
    return s.QueryProducts(ctx, queryString)
}

func (s *SmartContract) QueryProducts(ctx contractapi.TransactionContextInterface, queryString string) ([]*Product, error) {
    resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()

    var products []*Product
    for resultsIterator.HasNext() {
        queryResult, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }

        var product Product
        err = json.Unmarshal(queryResult.Value, &product)
        if err != nil {
            return nil, err
        }
        products = append(products, &product)
    }

    return products, nil
}
```

### クライアントアプリケーション例

Node.jsを使用したサプライチェーン管理アプリケーションの例：

```javascript
const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');

async function main() {
    try {
        // ウォレットのパスとゲートウェイ接続プロファイルの読み込み
        const walletPath = path.join(process.cwd(), 'wallet');
        const wallet = await Wallets.newFileSystemWallet(walletPath);
        const ccpPath = path.resolve(__dirname, '..', 'connection-profile.json');
        const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

        // ゲートウェイの作成と接続
        const gateway = new Gateway();
        await gateway.connect(ccp, { 
            wallet, 
            identity: 'manufacturer', 
            discovery: { enabled: true, asLocalhost: true } 
        });

        // チャネルとコントラクトの取得
        const network = await gateway.getNetwork('mychannel');
        const contract = network.getContract('supplychain');

        // 製品の作成
        await contract.submitTransaction(
            'CreateProduct',
            'PROD001',
            '高級腕時計',
            'LuxuryWatch Co.',
            '2023-01-15',
            '腕時計'
        );
        console.log('製品が作成されました');

        // 製品の確認
        const productBuffer = await contract.evaluateTransaction('ReadProduct', 'PROD001');
        const product = JSON.parse(productBuffer.toString());
        console.log(`製品情報: ${JSON.stringify(product, null, 2)}`);

        // 所有権の移転
        await contract.submitTransaction(
            'TransferProduct',
            'PROD001',
            'GlobalDistributors Inc.',
            '東京物流センター'
        );
        console.log('所有権が移転されました');

        // 証明書の追加
        await contract.submitTransaction(
            'AddCertificate',
            'PROD001',
            '品質検査証明書',
            'QC-2023-123456'
        );
        console.log('証明書が追加されました');

        // 更新された製品情報の取得
        const updatedProductBuffer = await contract.evaluateTransaction('ReadProduct', 'PROD001');
        const updatedProduct = JSON.parse(updatedProductBuffer.toString());
        console.log(`更新された製品情報: ${JSON.stringify(updatedProduct, null, 2)}`);

        // ゲートウェイの切断
        gateway.disconnect();

    } catch (error) {
        console.error(`エラーが発生しました: ${error}`);
        process.exit(1);
    }
}

main();
```

## 2. 資産トークン化（トークナイゼーション）

### ユースケース概要

実物資産（不動産、美術品、商品など）をデジタルトークンとして表現し、その所有権や権利を分散型台帳上で管理・取引するシステムです。

主な機能：
- 資産のトークン化
- 所有権の部分的な移転
- トークン取引の記録
- 配当や利益の分配
- 資産評価の更新

### 実装例

#### アセットの定義

```go
// Token は資産トークンを表します
type Token struct {
    ID             string  `json:"id"`
    Name           string  `json:"name"`
    Description    string  `json:"description"`
    TotalShares    int     `json:"totalShares"`
    ValuePerShare  float64 `json:"valuePerShare"`
    AssetType      string  `json:"assetType"` // "不動産", "美術品", "商品" など
    DocumentHash   string  `json:"documentHash"` // 法的文書のハッシュ
    Status         string  `json:"status"` // "アクティブ", "凍結", "清算済" など
    Shareholders   map[string]int `json:"shareholders"` // 所有者とその持分
    TransactionHistory []TransactionRecord `json:"transactionHistory"`
}

// TransactionRecord はトークン取引の記録を表します
type TransactionRecord struct {
    TxID        string  `json:"txId"`
    Timestamp   string  `json:"timestamp"`
    FromOwner   string  `json:"fromOwner"`
    ToOwner     string  `json:"toOwner"`
    ShareAmount int     `json:"shareAmount"`
    PricePerShare float64 `json:"pricePerShare"`
}
```

#### 主要機能の実装

1. **トークンの作成**:

```go
func (s *SmartContract) CreateToken(ctx contractapi.TransactionContextInterface, id string, name string, description string, totalShares int, initialValuePerShare float64, assetType string, documentHash string) error {
    exists, err := s.TokenExists(ctx, id)
    if err != nil {
        return err
    }
    if exists {
        return fmt.Errorf("トークン %s は既に存在します", id)
    }

    // クライアントIDの取得
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }

    // 新規トークンの作成
    shareholders := make(map[string]int)
    shareholders[clientID] = totalShares // 作成者が最初の所有者

    token := Token{
        ID:               id,
        Name:             name,
        Description:      description,
        TotalShares:      totalShares,
        ValuePerShare:    initialValuePerShare,
        AssetType:        assetType,
        DocumentHash:     documentHash,
        Status:           "アクティブ",
        Shareholders:     shareholders,
        TransactionHistory: []TransactionRecord{},
    }

    tokenJSON, err := json.Marshal(token)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(id, tokenJSON)
}
```

2. **トークンの取引**:

```go
func (s *SmartContract) TransferShares(ctx contractapi.TransactionContextInterface, tokenID string, toOwner string, shareAmount int, pricePerShare float64) error {
    token, err := s.ReadToken(ctx, tokenID)
    if err != nil {
        return err
    }

    // クライアントIDの取得
    fromOwner, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }

    // 所有する株式数のチェック
    ownedShares, exists := token.Shareholders[fromOwner]
    if !exists || ownedShares < shareAmount {
        return fmt.Errorf("十分な株式を所有していません")
    }

    // 現在の時刻を取得
    timestamp, err := s.GetTimestamp(ctx)
    if err != nil {
        return err
    }

    // トランザクションの記録
    txID := ctx.GetStub().GetTxID()
    transaction := TransactionRecord{
        TxID:           txID,
        Timestamp:      timestamp,
        FromOwner:      fromOwner,
        ToOwner:        toOwner,
        ShareAmount:    shareAmount,
        PricePerShare:  pricePerShare,
    }

    // 所有者の更新
    token.Shareholders[fromOwner] -= shareAmount
    if token.Shareholders[fromOwner] == 0 {
        delete(token.Shareholders, fromOwner)
    }

    if _, exists := token.Shareholders[toOwner]; exists {
        token.Shareholders[toOwner] += shareAmount
    } else {
        token.Shareholders[toOwner] = shareAmount
    }

    // 取引履歴の更新
    token.TransactionHistory = append(token.TransactionHistory, transaction)

    // トークン価値の更新
    token.ValuePerShare = pricePerShare

    tokenJSON, err := json.Marshal(token)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(tokenID, tokenJSON)
}
```

3. **価値の更新**:

```go
func (s *SmartContract) UpdateTokenValue(ctx contractapi.TransactionContextInterface, tokenID string, newValuePerShare float64) error {
    token, err := s.ReadToken(ctx, tokenID)
    if err != nil {
        return err
    }

    // 権限チェック（簡易版）
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }

    // この例では、トークン作成者のみが価値を更新できると仮定
    if token.Shareholders[clientID] != token.TotalShares && len(token.Shareholders) > 1 {
        return fmt.Errorf("トークン価値の更新権限がありません")
    }

    token.ValuePerShare = newValuePerShare

    tokenJSON, err := json.Marshal(token)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(tokenID, tokenJSON)
}
```

4. **配当の分配**:

```go
func (s *SmartContract) DistributeDividends(ctx contractapi.TransactionContextInterface, tokenID string, totalDividend float64) error {
    token, err := s.ReadToken(ctx, tokenID)
    if err != nil {
        return err
    }

    // 権限チェック
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }
    
    // この例では、一定数以上の株式を持つ人が配当を出せると仮定
    minSharesRequired := token.TotalShares / 10 // 10%以上
    if token.Shareholders[clientID] < minSharesRequired {
        return fmt.Errorf("配当分配の権限がありません")
    }

    // 各株主への配当額を計算して記録
    // 実際のお金の移動はオフチェーンで行う必要があります
    dividend := make(map[string]float64)
    for shareholder, shares := range token.Shareholders {
        proportion := float64(shares) / float64(token.TotalShares)
        dividend[shareholder] = totalDividend * proportion
    }

    // 配当イベントの発行
    eventPayload, err := json.Marshal(dividend)
    if err != nil {
        return err
    }
    
    err = ctx.GetStub().SetEvent("DividendDistributed", eventPayload)
    if err != nil {
        return err
    }

    return nil
}
```

## 3. 不動産取引システム

### ユースケース概要

不動産取引は、高額な資産の所有権移転を伴う複雑なプロセスであり、多くの関係者（売主、買主、仲介業者、銀行、公証人、政府機関など）が関わります。Hyperledger Fabricを使用して、このプロセスを効率化・透明化できます。

主な機能：
- 物件登録と所有権の証明
- 取引プロセスの追跡
- デジタル契約書の管理
- エスクローサービス
- 取引履歴の維持

### 実装例

#### アセットの定義

```go
// RealEstate は不動産物件を表します
type RealEstate struct {
    ID             string  `json:"id"` // 物件固有ID
    Address        string  `json:"address"`
    PropertyType   string  `json:"propertyType"` // "住宅", "商業", "工業" など
    Area           float64 `json:"area"` // 平方メートル
    Description    string  `json:"description"`
    Owner          string  `json:"owner"` // 現在の所有者のID
    RegistryNumber string  `json:"registryNumber"` // 法的登記番号
    Value          float64 `json:"value"` // 評価額
    Status         string  `json:"status"` // "利用可能", "売出中", "売却済", "所有権移転中"
    Documents      map[string]string `json:"documents"` // ドキュメントタイプとそのハッシュ
    TransactionHistory []PropertyTransaction `json:"transactionHistory"`
}

// PropertyTransaction は不動産取引を表します
type PropertyTransaction struct {
    TxID          string  `json:"txId"`
    Timestamp     string  `json:"timestamp"`
    FromOwner     string  `json:"fromOwner"`
    ToOwner       string  `json:"toOwner"`
    TransactionType string `json:"transactionType"` // "売却", "賃貸", "相続" など
    Price         float64 `json:"price"`
    Status        string  `json:"status"` // "開始", "契約", "支払い完了", "所有権移転", "完了", "キャンセル"
    Approvals     map[string]bool `json:"approvals"` // 各関係者の承認状態
}
```

#### 主要機能の実装

1. **物件登録**:

```go
func (s *SmartContract) RegisterProperty(ctx contractapi.TransactionContextInterface, id string, address string, propertyType string, area float64, description string, registryNumber string, value float64) error {
    exists, err := s.PropertyExists(ctx, id)
    if err != nil {
        return err
    }
    if exists {
        return fmt.Errorf("物件 %s は既に登録されています", id)
    }

    // クライアントIDの取得
    owner, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }

    // 新規物件の作成
    property := RealEstate{
        ID:               id,
        Address:          address,
        PropertyType:     propertyType,
        Area:             area,
        Description:      description,
        Owner:            owner,
        RegistryNumber:   registryNumber,
        Value:            value,
        Status:           "利用可能",
        Documents:        make(map[string]string),
        TransactionHistory: []PropertyTransaction{},
    }

    propertyJSON, err := json.Marshal(property)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(id, propertyJSON)
}
```

2. **取引開始**:

```go
func (s *SmartContract) StartPropertyTransaction(ctx contractapi.TransactionContextInterface, propertyID string, buyerID string, price float64, transactionType string) (string, error) {
    property, err := s.ReadProperty(ctx, propertyID)
    if err != nil {
        return "", err
    }

    // 所有者の確認
    owner, err := s.GetClientID(ctx)
    if err != nil {
        return "", err
    }
    if property.Owner != owner {
        return "", fmt.Errorf("この物件の所有者ではありません")
    }

    // 物件が利用可能か確認
    if property.Status != "利用可能" {
        return "", fmt.Errorf("この物件は現在、取引を開始できる状態ではありません")
    }

    // 現在の時刻を取得
    timestamp, err := s.GetTimestamp(ctx)
    if err != nil {
        return "", err
    }

    // トランザクションID取得
    txID := ctx.GetStub().GetTxID()

    // 承認マップの初期化
    approvals := make(map[string]bool)
    approvals[owner] = true      // 売主は自動承認
    approvals[buyerID] = false   // 買主はまだ承認していない
    // 他の関係者（銀行、公証人など）も必要に応じて追加

    // 新規取引の記録
    transaction := PropertyTransaction{
        TxID:            txID,
        Timestamp:       timestamp,
        FromOwner:       owner,
        ToOwner:         buyerID,
        TransactionType: transactionType,
        Price:           price,
        Status:          "開始",
        Approvals:       approvals,
    }

    property.Status = "売出中"
    property.TransactionHistory = append(property.TransactionHistory, transaction)

    propertyJSON, err := json.Marshal(property)
    if err != nil {
        return "", err
    }

    err = ctx.GetStub().PutState(propertyID, propertyJSON)
    if err != nil {
        return "", err
    }

    return txID, nil
}
```

3. **取引の承認**:

```go
func (s *SmartContract) ApproveTransaction(ctx contractapi.TransactionContextInterface, propertyID string, transactionID string) error {
    property, err := s.ReadProperty(ctx, propertyID)
    if err != nil {
        return err
    }

    // トランザクションの検索
    var targetTx *PropertyTransaction
    for i, tx := range property.TransactionHistory {
        if tx.TxID == transactionID {
            targetTx = &property.TransactionHistory[i]
            break
        }
    }

    if targetTx == nil {
        return fmt.Errorf("指定されたトランザクションが見つかりません")
    }

    // クライアントIDの取得
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }

    // 承認権限の確認
    if _, exists := targetTx.Approvals[clientID]; !exists {
        return fmt.Errorf("このトランザクションの承認権限がありません")
    }

    // 承認状態の更新
    targetTx.Approvals[clientID] = true

    // すべての関係者が承認したか確認
    allApproved := true
    for _, approved := range targetTx.Approvals {
        if !approved {
            allApproved = false
            break
        }
    }

    // すべて承認済みの場合、ステータスを更新
    if allApproved {
        targetTx.Status = "契約"
        // 必要に応じて他のステータス更新
    }

    propertyJSON, err := json.Marshal(property)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(propertyID, propertyJSON)
}
```

4. **所有権移転**:

```go
func (s *SmartContract) FinalizeTransaction(ctx contractapi.TransactionContextInterface, propertyID string, transactionID string) error {
    property, err := s.ReadProperty(ctx, propertyID)
    if err != nil {
        return err
    }

    // トランザクションの検索
    var targetTx *PropertyTransaction
    for i, tx := range property.TransactionHistory {
        if tx.TxID == transactionID {
            targetTx = &property.TransactionHistory[i]
            break
        }
    }

    if targetTx == nil {
        return fmt.Errorf("指定されたトランザクションが見つかりません")
    }

    // 権限チェック（簡易版）
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }

    // この例では、公証人や政府機関など特定の権限を持つ人のみが最終化できると仮定
    if clientID != "notary" && clientID != "gov_agent" {
        return fmt.Errorf("取引を最終化する権限がありません")
    }

    // トランザクションステータスのチェック
    if targetTx.Status != "支払い完了" {
        return fmt.Errorf("支払いが完了していないため、取引を最終化できません")
    }

    // 所有権の移転
    property.Owner = targetTx.ToOwner
    property.Status = "利用可能"
    targetTx.Status = "完了"

    // 現在の時刻を取得
    timestamp, err := s.GetTimestamp(ctx)
    if err != nil {
        return err
    }
    
    // 所有権移転のイベント発行
    transferEvent := map[string]string{
        "propertyID": propertyID,
        "fromOwner": targetTx.FromOwner,
        "toOwner": targetTx.ToOwner,
        "timestamp": timestamp,
    }
    
    eventJSON, err := json.Marshal(transferEvent)
    if err != nil {
        return err
    }
    
    err = ctx.GetStub().SetEvent("OwnershipTransferred", eventJSON)
    if err != nil {
        return err
    }

    propertyJSON, err := json.Marshal(property)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(propertyID, propertyJSON)
}
```

## 4. アイデンティティ管理

### ユースケース概要

分散型のアイデンティティ管理システムでは、ユーザーが自身のデジタルアイデンティティを制御し、必要に応じて第三者に証明することができます。

主な機能：
- デジタルIDの作成と管理
- 検証可能な資格情報の発行
- 選択的な情報開示
- 資格情報の検証
- アクセス権限の管理

### 実装例

#### アセットの定義

```go
// DigitalIdentity はユーザーのデジタルIDを表します
type DigitalIdentity struct {
    ID            string `json:"id"` // DID (Decentralized Identifier)
    PublicKey     string `json:"publicKey"`
    Controller    string `json:"controller"` // IDの所有者
    Created       string `json:"created"`
    Updated       string `json:"updated"`
    Status        string `json:"status"` // "アクティブ", "取り消し済", "期限切れ"
    ServiceEndpoints map[string]string `json:"serviceEndpoints"` // サービスエンドポイント
}

// Credential は検証可能な資格情報を表します
type Credential struct {
    ID            string `json:"id"`
    Type          string `json:"type"` // 資格情報のタイプ
    Issuer        string `json:"issuer"` // 発行者のDID
    Subject       string `json:"subject"` // 対象者のDID
    IssuanceDate  string `json:"issuanceDate"`
    ExpirationDate string `json:"expirationDate"`
    Claims        map[string]interface{} `json:"claims"` // 実際の資格情報内容
    Proof         string `json:"proof"` // デジタル署名
    Status        string `json:"status"` // "有効", "取り消し済", "期限切れ"
}
```

#### 主要機能の実装

1. **デジタルIDの作成**:

```go
func (s *SmartContract) CreateDigitalIdentity(ctx contractapi.TransactionContextInterface, did string, publicKey string) error {
    exists, err := s.IdentityExists(ctx, did)
    if err != nil {
        return err
    }
    if exists {
        return fmt.Errorf("デジタルID %s は既に存在します", did)
    }

    // クライアントIDの取得
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }

    // 現在の時刻を取得
    timestamp, err := s.GetTimestamp(ctx)
    if err != nil {
        return err
    }

    identity := DigitalIdentity{
        ID:               did,
        PublicKey:        publicKey,
        Controller:       clientID,
        Created:          timestamp,
        Updated:          timestamp,
        Status:           "アクティブ",
        ServiceEndpoints: make(map[string]string),
    }

    identityJSON, err := json.Marshal(identity)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(did, identityJSON)
}
```

2. **資格情報の発行**:

```go
func (s *SmartContract) IssueCredential(ctx contractapi.TransactionContextInterface, credentialID string, credentialType string, subjectDID string, expirationDate string, claimsJSON string) error {
    // 発行者のDIDを取得
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }

    // 発行者のデジタルIDが有効か確認
    issuerIdentity, err := s.ReadIdentity(ctx, clientID)
    if err != nil {
        return err
    }
    if issuerIdentity.Status != "アクティブ" {
        return fmt.Errorf("発行者のデジタルIDが有効ではありません")
    }

    // 対象者のデジタルIDが有効か確認
    subjectIdentity, err := s.ReadIdentity(ctx, subjectDID)
    if err != nil {
        return err
    }
    if subjectIdentity.Status != "アクティブ" {
        return fmt.Errorf("対象者のデジタルIDが有効ではありません")
    }

    // 現在の時刻を取得
    timestamp, err := s.GetTimestamp(ctx)
    if err != nil {
        return err
    }

    // クレームのパース
    var claims map[string]interface{}
    err = json.Unmarshal([]byte(claimsJSON), &claims)
    if err != nil {
        return fmt.Errorf("クレームのJSONパースに失敗しました: %v", err)
    }

    // 証明の生成（実際にはオフチェーンで署名を行う必要があります）
    // ここでは簡易的な例として、発行者のDIDと現在時刻のハッシュを使用
    proofData := fmt.Sprintf("%s:%s:%s", clientID, subjectDID, timestamp)
    proof := fmt.Sprintf("sha256:%x", sha256.Sum256([]byte(proofData)))

    credential := Credential{
        ID:             credentialID,
        Type:           credentialType,
        Issuer:         clientID,
        Subject:        subjectDID,
        IssuanceDate:   timestamp,
        ExpirationDate: expirationDate,
        Claims:         claims,
        Proof:          proof,
        Status:         "有効",
    }

    credentialJSON, err := json.Marshal(credential)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(credentialID, credentialJSON)
}
```

3. **資格情報の検証**:

```go
func (s *SmartContract) VerifyCredential(ctx contractapi.TransactionContextInterface, credentialID string) (bool, error) {
    credentialJSON, err := ctx.GetStub().GetState(credentialID)
    if err != nil {
        return false, fmt.Errorf("資格情報の取得に失敗しました: %v", err)
    }
    if credentialJSON == nil {
        return false, fmt.Errorf("資格情報 %s は存在しません", credentialID)
    }

    var credential Credential
    err = json.Unmarshal(credentialJSON, &credential)
    if err != nil {
        return false, err
    }

    // 資格情報のステータスチェック
    if credential.Status != "有効" {
        return false, nil
    }

    // 有効期限のチェック
    currentTime := time.Now().Format(time.RFC3339)
    if credential.ExpirationDate < currentTime {
        // 期限切れの場合はステータスを更新
        credential.Status = "期限切れ"
        updatedCredentialJSON, err := json.Marshal(credential)
        if err != nil {
            return false, err
        }
        err = ctx.GetStub().PutState(credentialID, updatedCredentialJSON)
        if err != nil {
            return false, err
        }
        return false, nil
    }

    // 発行者の検証
    issuerIdentity, err := s.ReadIdentity(ctx, credential.Issuer)
    if err != nil {
        return false, err
    }
    if issuerIdentity.Status != "アクティブ" {
        return false, nil
    }

    // 実際の署名検証はオフチェーンで行うべき
    // ここでは簡易的な実装として「有効」という結果を返す
    return true, nil
}
```

4. **資格情報の取り消し**:

```go
func (s *SmartContract) RevokeCredential(ctx contractapi.TransactionContextInterface, credentialID string, reason string) error {
    credential, err := s.ReadCredential(ctx, credentialID)
    if err != nil {
        return err
    }

    // 権限チェック - 発行者のみ取り消し可能
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }
    if credential.Issuer != clientID {
        return fmt.Errorf("この資格情報を取り消す権限がありません")
    }

    // ステータスの更新
    credential.Status = "取り消し済"

    // 取り消し情報の記録
    // 実際のシステムでは、取り消しの理由やタイムスタンプなども保存するとよい
    revocationInfo := map[string]string{
        "reason": reason,
        "timestamp": time.Now().Format(time.RFC3339),
        "revokedBy": clientID,
    }
    
    // イベント発行
    revocationJSON, err := json.Marshal(revocationInfo)
    if err != nil {
        return err
    }
    
    err = ctx.GetStub().SetEvent("CredentialRevoked", revocationJSON)
    if err != nil {
        return err
    }

    credentialJSON, err := json.Marshal(credential)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(credentialID, credentialJSON)
}
```

## 5. 投票システム

### ユースケース概要

透明で改ざん防止された投票システムは、選挙やコーポレートガバナンスに適しています。

主な機能：
- 投票者の登録と認証
- 投票の匿名性確保
- 投票の実施と記録
- 投票結果の集計
- 投票の検証可能性

### 実装例

#### アセットの定義

```go
// Election は投票イベントを表します
type Election struct {
    ID            string    `json:"id"`
    Title         string    `json:"title"`
    Description   string    `json:"description"`
    StartTime     string    `json:"startTime"`
    EndTime       string    `json:"endTime"`
    Candidates    []string  `json:"candidates"`
    EligibleVoters []string `json:"eligibleVoters"` // 投票権を持つIDのリスト
    Status        string    `json:"status"` // "準備中", "実施中", "終了", "集計済"
    Result        map[string]int `json:"result"` // 各候補の得票数
    TotalVotes    int       `json:"totalVotes"`
    Creator       string    `json:"creator"` // 選挙作成者
}

// Vote は投票を表します
type Vote struct {
    ElectionID    string    `json:"electionId"`
    VoteID        string    `json:"voteId"` // 投票のユニークID（匿名性のため）
    CandidateID   string    `json:"candidateId"`
    Timestamp     string    `json:"timestamp"`
    Proof         string    `json:"proof"` // 投票の証明（匿名で検証可能）
}
```

#### 主要機能の実装

1. **選挙の作成**:

```go
func (s *SmartContract) CreateElection(ctx contractapi.TransactionContextInterface, id string, title string, description string, startTime string, endTime string, candidatesJSON string) error {
    exists, err := s.ElectionExists(ctx, id)
    if err != nil {
        return err
    }
    if exists {
        return fmt.Errorf("選挙ID %s は既に存在します", id)
    }

    // 候補者リストのパース
    var candidates []string
    err = json.Unmarshal([]byte(candidatesJSON), &candidates)
    if err != nil {
        return fmt.Errorf("候補者リストのJSONパースに失敗しました: %v", err)
    }

    // クライアントIDの取得
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }

    // 選挙の結果マップ初期化
    result := make(map[string]int)
    for _, candidate := range candidates {
        result[candidate] = 0
    }

    election := Election{
        ID:            id,
        Title:         title,
        Description:   description,
        StartTime:     startTime,
        EndTime:       endTime,
        Candidates:    candidates,
        EligibleVoters: []string{}, // 初期状態では空
        Status:        "準備中",
        Result:        result,
        TotalVotes:    0,
        Creator:       clientID,
    }

    electionJSON, err := json.Marshal(election)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(id, electionJSON)
}
```

2. **投票者の登録**:

```go
func (s *SmartContract) RegisterVoters(ctx contractapi.TransactionContextInterface, electionID string, votersJSON string) error {
    election, err := s.ReadElection(ctx, electionID)
    if err != nil {
        return err
    }

    // 権限チェック
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }
    if election.Creator != clientID {
        return fmt.Errorf("この選挙の管理権限がありません")
    }

    // 選挙が準備中であることを確認
    if election.Status != "準備中" {
        return fmt.Errorf("選挙はすでに開始されているため、投票者を追加できません")
    }

    // 投票者リストのパース
    var newVoters []string
    err = json.Unmarshal([]byte(votersJSON), &newVoters)
    if err != nil {
        return fmt.Errorf("投票者リストのJSONパースに失敗しました: %v", err)
    }

    // 投票者の追加（重複チェック付き）
    votersMap := make(map[string]bool)
    for _, voter := range election.EligibleVoters {
        votersMap[voter] = true
    }
    
    for _, voter := range newVoters {
        if !votersMap[voter] {
            election.EligibleVoters = append(election.EligibleVoters, voter)
            votersMap[voter] = true
        }
    }

    electionJSON, err := json.Marshal(election)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(electionID, electionJSON)
}
```

3. **選挙の開始と終了**:

```go
func (s *SmartContract) StartElection(ctx contractapi.TransactionContextInterface, electionID string) error {
    election, err := s.ReadElection(ctx, electionID)
    if err != nil {
        return err
    }

    // 権限チェック
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }
    if election.Creator != clientID {
        return fmt.Errorf("この選挙の管理権限がありません")
    }

    // ステータスチェック
    if election.Status != "準備中" {
        return fmt.Errorf("選挙はすでに開始されているか終了しています")
    }

    // 投票者が登録されているか確認
    if len(election.EligibleVoters) == 0 {
        return fmt.Errorf("選挙を開始するには、少なくとも1人の投票者が必要です")
    }

    // 現在時刻の取得
    currentTime := time.Now().Format(time.RFC3339)
    
    // 選挙開始時間の更新（オプション）
    election.StartTime = currentTime
    election.Status = "実施中"

    // イベント発行
    event := map[string]string{
        "electionID": electionID,
        "action": "start",
        "timestamp": currentTime,
    }
    
    eventJSON, err := json.Marshal(event)
    if err != nil {
        return err
    }
    
    err = ctx.GetStub().SetEvent("ElectionStatusChanged", eventJSON)
    if err != nil {
        return err
    }

    electionJSON, err := json.Marshal(election)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(electionID, electionJSON)
}

func (s *SmartContract) EndElection(ctx contractapi.TransactionContextInterface, electionID string) error {
    election, err := s.ReadElection(ctx, electionID)
    if err != nil {
        return err
    }

    // 権限チェック
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }
    if election.Creator != clientID {
        return fmt.Errorf("この選挙の管理権限がありません")
    }

    // ステータスチェック
    if election.Status != "実施中" {
        return fmt.Errorf("選挙は実施中ではありません")
    }

    // 現在時刻の取得
    currentTime := time.Now().Format(time.RFC3339)
    
    // 選挙終了時間の更新
    election.EndTime = currentTime
    election.Status = "終了"

    // イベント発行
    event := map[string]string{
        "electionID": electionID,
        "action": "end",
        "timestamp": currentTime,
    }
    
    eventJSON, err := json.Marshal(event)
    if err != nil {
        return err
    }
    
    err = ctx.GetStub().SetEvent("ElectionStatusChanged", eventJSON)
    if err != nil {
        return err
    }

    electionJSON, err := json.Marshal(election)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(electionID, electionJSON)
}
```

4. **投票の実施**:

```go
func (s *SmartContract) CastVote(ctx contractapi.TransactionContextInterface, electionID string, candidateID string) (string, error) {
    election, err := s.ReadElection(ctx, electionID)
    if err != nil {
        return "", err
    }

    // 選挙が実施中であることを確認
    if election.Status != "実施中" {
        return "", fmt.Errorf("選挙は現在、投票を受け付けていません")
    }

    // 投票者IDの取得
    voterID, err := s.GetClientID(ctx)
    if err != nil {
        return "", err
    }

    // 投票権があるか確認
    hasRight := false
    for _, voter := range election.EligibleVoters {
        if voter == voterID {
            hasRight = true
            break
        }
    }
    if !hasRight {
        return "", fmt.Errorf("この選挙の投票権がありません")
    }

    // 候補者の存在確認
    candidateExists := false
    for _, candidate := range election.Candidates {
        if candidate == candidateID {
            candidateExists = true
            break
        }
    }
    if !candidateExists {
        return "", fmt.Errorf("指定された候補者 %s は存在しません", candidateID)
    }

    // 二重投票のチェック
    // 実際のシステムでは、投票者の匿名性を保ちつつ二重投票を防ぐ仕組みが必要
    // ここでは簡易的な実装として投票IDとハッシュを使用
    
    // 現在の時刻を取得
    timestamp, err := s.GetTimestamp(ctx)
    if err != nil {
        return "", err
    }

    // 投票IDの生成（匿名性のため、投票者IDは直接使用しない）
    voteData := fmt.Sprintf("%s:%s:%s", electionID, voterID, timestamp)
    voteID := fmt.Sprintf("%x", sha256.Sum256([]byte(voteData)))
    
    // 投票の証明生成
    proofData := fmt.Sprintf("%s:%s:%s", voteID, candidateID, timestamp)
    proof := fmt.Sprintf("%x", sha256.Sum256([]byte(proofData)))

    // 投票の記録
    vote := Vote{
        ElectionID:   electionID,
        VoteID:       voteID,
        CandidateID:  candidateID,
        Timestamp:    timestamp,
        Proof:        proof,
    }

    voteJSON, err := json.Marshal(vote)
    if err != nil {
        return "", err
    }

    // 投票を保存
    voteKey := fmt.Sprintf("VOTE_%s", voteID)
    err = ctx.GetStub().PutState(voteKey, voteJSON)
    if err != nil {
        return "", err
    }

    // 投票一覧に追加（実際のシステムでは、投票と投票者の紐付けは避けるべき）
    // この例では簡易的に、投票者がどの選挙に投票したかの記録を別途保存
    voterElectionKey := fmt.Sprintf("VOTER_ELECTION_%s_%s", voterID, electionID)
    err = ctx.GetStub().PutState(voterElectionKey, []byte(voteID))
    if err != nil {
        return "", err
    }

    // イベント発行
    voteEvent := map[string]string{
        "electionID": electionID,
        "voteID": voteID,
        "timestamp": timestamp,
    }
    
    eventJSON, err := json.Marshal(voteEvent)
    if err != nil {
        return "", err
    }
    
    err = ctx.GetStub().SetEvent("VoteCast", eventJSON)
    if err != nil {
        return "", err
    }

    return voteID, nil
}
```

5. **投票結果の集計**:

```go
func (s *SmartContract) TallyVotes(ctx contractapi.TransactionContextInterface, electionID string) error {
    election, err := s.ReadElection(ctx, electionID)
    if err != nil {
        return err
    }

    // 権限チェック
    clientID, err := s.GetClientID(ctx)
    if err != nil {
        return err
    }
    if election.Creator != clientID {
        return fmt.Errorf("この選挙の管理権限がありません")
    }

    // ステータスチェック
    if election.Status != "終了" {
        return fmt.Errorf("選挙はまだ終了していないか、すでに集計されています")
    }

    // 投票の集計
    // 実際のシステムでは、すべての投票をクエリする効率的な方法が必要
    // ここでは簡易的な実装として、投票キーの命名規則を使用
    
    // 選挙結果の初期化
    for _, candidate := range election.Candidates {
        election.Result[candidate] = 0
    }
    election.TotalVotes = 0

    // 投票データのクエリ（実際のシステムではより効率的な方法が必要）
    // CouchDBを使用している場合はリッチクエリを使用可能
    queryString := fmt.Sprintf(`{"selector":{"electionID":"%s"}}`, electionID)
    resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
    if err != nil {
        return err
    }
    defer resultsIterator.Close()

    // 各投票を集計
    for resultsIterator.HasNext() {
        queryResult, err := resultsIterator.Next()
        if err != nil {
            return err
        }

        var vote Vote
        err = json.Unmarshal(queryResult.Value, &vote)
        if err != nil {
            continue // エラーのある投票はスキップ
        }

        if vote.ElectionID == electionID {
            election.Result[vote.CandidateID]++
            election.TotalVotes++
        }
    }

    // 選挙ステータスを更新
    election.Status = "集計済"

    // イベント発行
    resultEvent := map[string]interface{}{
        "electionID": electionID,
        "totalVotes": election.TotalVotes,
        "result": election.Result,
    }
    
    eventJSON, err := json.Marshal(resultEvent)
    if err != nil {
        return err
    }
    
    err = ctx.GetStub().SetEvent("ElectionTallied", eventJSON)
    if err != nil {
        return err
    }

    electionJSON, err := json.Marshal(election)
    if err != nil {
        return err
    }

    return ctx.GetStub().PutState(electionID, electionJSON)
}
```

## 次のステップ

これらの応用例を参考に、独自のブロックチェーンアプリケーションを設計・開発してください。各ユースケースは、実際のビジネス要件に合わせてカスタマイズすることが重要です。より高度な機能や改善点については、以下を検討してください：

1. **セキュリティ強化**
   - より堅牢な権限管理
   - 暗号化やゼロ知識証明の導入
   - プライバシー保護メカニズムの実装

2. **パフォーマンス最適化**
   - 効率的なデータ構造の選択
   - インデックス作成とクエリの最適化
   - 並列処理の導入

3. **ユーザー体験の向上**
   - 使いやすいフロントエンドの開発
   - モバイルアプリとの連携
   - 通知システムの構築

4. **インテグレーション**
   - 既存システムとの統合
   - APIの提供
   - 外部データソースとの連携

Hyperledger Fabricの可能性を最大限に活用し、信頼性の高い分散アプリケーションを構築してください。
