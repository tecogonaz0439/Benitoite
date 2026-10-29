# TLS の証明書検証による追加対象の調査

## 結論と停止

sendIn の HTTPS 接続に使う固定した証明書検証器は、macOS の SecTrust によるネットワーク取得を無効にしていない。同じ SecTrust の経路を使う最小試行で、検証器がループバックの別 endpoint から中間証明書を取得することを確認した。保持 endpoint 一つに対象を限ることは、HTTP の非追従と proxy の無効化だけでは閉じられない。計画の追加対象の停止条件に該当するため、取りまとめへ報告し、追加の試験と本番の編集を停止した。

これは本番の sendIn を実行した反例ではない。実測したのは同じ SecTrust API の証明書評価経路であり、明示したメモリ内の root anchor だけを信頼する条件を使った。固定した verifier の本番の経路は OS の root を使うため、この差を明記する。本番の TLS の接続を制御した受け手へ送り、追加接続を観測したとは報告しない。

## ソースの根拠

相対識別子・SHA-256・照合箇所を [sectrust-aia-sources.json](sectrust-aia-sources.json) に保存した。資料は固定したローカル registry と手元の macOS SDK であり、外部から取得していない。

| 一次資料 | 確認した内容 |
|---|---|
| `ureq-3.4.2/src/tls/rustls.rs` の RootCerts::PlatformVerifier の分岐 | `rustls_platform_verifier::Verifier::new(provider)` を証明書検証器として設定する |
| `rustls-platform-verifier-0.7.1/src/verification/apple.rs` の verify_certificate | SSL の policy を作り、SecTrust を構築する。日付・渡された OCSP 応答・任意の anchor を設定して evaluate_with_error を呼ぶ。network_fetch_allowed を false にしない |
| 同 apple.rs のテスト用 root を設定する前のコメント | テスト用 root の設定も、失効情報のオンライン取得や root のダウンロードを制限するものではないと説明する |
| `security-framework-3.7.0/src/trust.rs` の get_network_fetch_allowed・set_network_fetch_allowed・evaluate_with_error | Security.framework の対応する API を呼ぶ。評価のラッパーがネットワーク取得を無効化する処理はない |
| SDK `Security.framework/Headers/SecTrust.h`、260〜289行 | Set/GetNetworkFetchAllowed の説明は、SSL policy を含む評価で欠けた中間証明書のネットワーク取得が既定で有効であり、false の明示で無効になると定める |
| 同 SecTrust.h、405〜425行 | EvaluateWithError の説明は、評価に中間証明書の取得や失効検査によるネットワークアクセスが含まれうると定める |

R30.3 の対象の単位の契約は、DNS と OS のアドレス変換前の名前または IP と port である。証明書に記載された別の HTTP URL への取得を、保持した endpoint と同じ対象に数える決定はない。これを DNS の複数解決先やソケットの族と同じ例外として広げない。

## 最小試行と観測

[sectrust-aia.py](sectrust-aia.py) は root・intermediate・leaf の三証明書を一時生成する。leaf の AIA の取得先は `http://127.0.0.1:<port>/intermediate-<unique>.der` 一つだけであり、OCSP・CRL・外部名の取得先を含めない。leaf だけを評価へ渡し、root はメモリ内の anchor として設定する。`SecTrustSetAnchorCertificatesOnly(true)` でこの root だけを使い、OS の信頼ストアを変更しない。ループバックだけに受け手を開き、中間証明書を返す。

[sectrust-aia.c](sectrust-aia.c) は SecTrustCreateWithCertificates、SecPolicyCreateSSL、SecTrustGetNetworkFetchAllowed、SecTrustEvaluateWithError を使う。対照として先に明示 false の評価を行い、その後に既定の設定で同じ leaf を評価した。[実測](sectrust-aia.json) は以下のとおりである。

| 設定 | 既定値の照会 | 評価時の値 | 評価の結果 | ループバック AIA の受信 |
|---|---:|---:|---|---|
| 明示 false | status 0、allowed 1 | allowed 0 | false、error -25318 | 0件 |
| 既定 | status 0、allowed 1 | allowed 1 | true、error 0 | GET 1件、User-Agent `com.apple.trustd/3.0` |

実行は `python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r30.4/sectrust-aia.py` 一度で、終了0であった。生成・clang・二評価を含む台本内の外側の時間は0.605274583秒、評価の外側は false が0.229943833秒、既定が0.016136375秒である。証明書の SHA-256 も実測の JSON に残した。

この試行の受け手と証明書の取得 URL はループバックだけである。外部への通信、OS の信頼ストアの変更、依存と git の変更、新しい CARGO_TARGET_DIR の設定は行っていない。中間証明書を自動取得できることを確認した段階で停止し、OCSP の再現、全プラットフォームの調査、本番の証明書検証方式の変更は行っていない。生成した秘密鍵・証明書・実行ファイルは `target/r30.4/` 内の TemporaryDirectory に置き、試行の終了時に削除した。

## 公開入力を保存した同じ対照の再実行

レビューの根拠入力を残すため、同じ対照を [sectrust-aia-preserve.py](sectrust-aia-preserve.py) から一度だけ再実行した。本番 HTTPS や別の検証方式の試験へ範囲を広げていない。初回の台本・出力・入力ハッシュと資料の記録はそのまま保った。初回の証明書はハッシュだけを保存し、実体は一時領域の終了時に削除済みである。

再実行の公開入力は [sectrust-aia-preserved/](sectrust-aia-preserved/) の root.der・intermediate.der・leaf.der と intermediate.cnf・leaf.cnf である。秘密鍵は含めていない。[別ラベルの実測](sectrust-aia-preserved.json) は初回と同じ結果で、明示 false は allowed 0・失敗 -25318・AIA GET 0件、既定は allowed 1・成功・AIA GET 1件であった。再実行の台本内の外側時間は0.360410209秒、終了0である。

公開入力の SHA-256 は別ラベルの実測へ、台本と結果の SHA-256・初回資料のハッシュ照合・target の一時残件0は [sectrust-aia-preserved-state.json](sectrust-aia-preserved-state.json) へ保存した。秘密鍵と実行ファイルは再実行でも target の一時領域から出さず、終了時に削除した。追加の試験と本番編集はここで停止した。

## 未完と判断を要する範囲

sendIn の HTTP の要求保持・Host・非追従・proxy の確認と、HTTPS の証明書検証に伴う追加対象の排除を分ける。後者は未完である。証明書の検証を弱める、HTTPS の受理を変える、追加対象を型の観測から除く、といった変更は行わない。対象の契約を保つ証明書検証方式とプラットフォームごとの実装を、設計者が判断する必要がある。OS の root を使う本番評価を追加で試し、外部の root 取得が起こりうる試験へ広げることもしない。
