# google-cloud-swift

SwiftサーバからGCPの各種サービスやFirebaseを利用するためのライブラリ。

# インストール

```swift
.package(url: "https://github.com/qoncept/google-cloud-swift.git", from: "2.0.0"),
```

# テスト

ローカルにエミュレータのGCP環境を立ち上げるためにdocker composeを利用する。

```sh
docker compose up -d
./run_test.sh
```

# Firebase Cloud Messaging

`FirebaseAdmin` の `Messaging` で FCM HTTP v1 にメッセージを送信できる。
FCM API を有効にし、送信権限のある認証情報を設定する。
サービスアカウント JSON は秘密情報として管理する。

```swift
import FirebaseAdmin
import FoundationEssentials

let client = try GCPClient(credentialFactory: .json(data: serviceAccountJSON))
let messaging = try Messaging(client: client, projectID: "example-project")
let message = Message(
    target: .token(registrationToken),
    notification: .init(title: "Hello", body: "You have a new message"),
    data: ["payload": "example"],
    android: .init(priority: .high, ttl: "120s")
)
let name = try await messaging.send(message)
try await client.shutdown()
```

`projectID` は認証情報に含まれている場合は省略できる。宛先には `.topic` と
`.condition` も指定できる。`validateOnly: true` は配信せずにリクエストを検証する。
HTTP エラーは `MessagingError` として返される。`isUnregistered` は FCM が
`UNREGISTERED` と明示した場合にのみ真になる。トークンの削除などの対応は
呼び出し元で行う。Android の TTL は `"120s"` のような protobuf duration 形式で、
FCM の上限は 4 週間。省略時は FCM の既定値が使われる。
