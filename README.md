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
