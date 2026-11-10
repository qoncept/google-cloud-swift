# google-cloud-swift

SwiftサーバからGCPの各種サービスやFirebaseを利用するためのライブラリ。

# インストール

```swift
.package(url: "https://github.com/qoncept/google-cloud-swift.git", from: "2.0.0"),
```

# テスト

テスト用の各種モックサーバやエミュレータを立ち上げるために、docker composeを利用する。

```sh
docker compose up -d
./run_test.sh
```
