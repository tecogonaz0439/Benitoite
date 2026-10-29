# IF20.02 の結果

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | IF20.02、情報フロー制御（information-flow control）の Http の入口と出口の棚卸し |
| 状態 | 棚卸しと扱いの候補の記録を完了した。候補の採択・本番実装・独立レビュー・設計者の受け入れは行っていない |
| B_WORK | `a522a3bbc1bfd217adc4d30dea2010a2e955f410` |
| HEAD | `a522a3bbc1bfd217adc4d30dea2010a2e955f410`（`git rev-parse HEAD` で取得） |
| 閉じた範囲 | Http の公開関数 16 件と組み込み登録 9 件、クライアントとサーバの各欄・通信段階 50 行、追従・成否・自動応答・警告・明示／暗黙の解放の経路 |
| 未完の範囲 | IFC-D3・D4・D6・D8 の回答による候補の確定、U-H01〜U-H08 の設計・本番接続・実行確認。担当の自己確認までであり、後続の独立レビュー・設計者の受け入れは別である |

## 変更と接続

[inventory/http.md](../inventory/http.md)を新規作成し、[file.md の欄の定義と数え方](../inventory/file.md#表の欄と数え方)を参照させた。公開関数の母集団と、要求・応答の各欄や通信段階の母集団を分け、標準宣言と組み込みを二重に数えていない。非公開の `serveLoop`、誤りの射影・Show、レコードの構成子とアクセサ、暗黙の解放は補助経路として残した。

現行の自動追従と、判断 7・8 の非追従の範囲付き送信を区別した。`Http.sendIn` は候補名であり、同じ要求と実効 host/port を保持する型契約との対応までを記録した。本 HEAD に新操作がないことも確認し、未接続を成功と扱っていない。host/port だけから HTTPS origin・用途・認証の欄を導かず、応答や成否の分類と完全性の契約は IFC-D3 等の回答待ちとした。

クライアントの追従は固定依存 `ureq 3.4.2` と `ureq-proto 0.6.4` のソースまで読んだ。Authorization・Cookie・Content-Length の除去と他の欄の保持、メソッドの変更／追従不可、元の非空本文を再送する分岐が確認されないこと、最終 URI の拡張を言語の Response に戻さないことを分けて記録した。読んだ依存のソースは [dependency-sources.json](dependency-sources.json)に版・相対位置・SHA-256 を保存した。これはネットワーク実行による検証ではない。

作成したファイルは `inventory/http.md` と `if20.02/` の本結果・依存ソースの識別記録・dry-run のログだけである。本番ソース・現行設計書・生成物・依存・固定版を変えていない。`private/`・`docs/todo/` と、それらを指すスキルのリンク先は読んでいない。git の状態を変える操作は行わず、読み取り用のコマンドだけを使った。公開の `japanese-tech-writing` と `rtk` のスキルを読んだ。文書へ手元の絶対パスは記録していない。

## 件数と扱いの候補

| 集計 | 件数と根拠 |
|---|---|
| 公開の明示的な関数 | 16 件。Listen の操作 4、Connect の操作 1、通常の State の組み込み 2、効果を持たない公開宣言の組み込み 2、言語内の通常の関数 7 |
| 非公開の関数を含む宣言 | 17 件。`serveLoop` 1 件を別に数えた |
| Http の組み込み登録 | 9 件。`http_server::DECLS` 7、`http_client::DECLS` 1、`http_util::DECLS` 1。対応する公開宣言との不一致は見つからなかった |
| 公開操作の方向 | 入口だけ 1、出口だけ 0、両方 8、内部の派生 7。入口を含む 9、出口を含む 8 |
| 公開操作の候補 | 契約を設ける 7、保守的（秘密の結びとする）0、未対応で拒否 9、未確認 0。旧 send/get は追従先の全欄の照合が未接続、サーバ側は資源・自動応答・解放の契約が未設計であることを拒否候補の理由とした |
| 各欄と通信の方向 | C01〜C21・R01〜R08・S01〜S21 の 50 行。入口だけ 21、出口だけ 18、両方 7、内部の派生 4。入口を含む 28、出口を含む 25 |
| 各欄と通信の候補 | 契約を設ける 14、保守的（秘密の結びとする）11、未対応で拒否 25、未確認 0。一般の応答・誤り・成否・時間切れ等を保守的な候補にした |
| 未確認事項 | U-H01〜U-H08 の 8 件。上の分類候補の未採択と、根拠・接続・実行確認の残りを区別した |

公開操作と各欄の行は合算しない。`requestOf` は効果なしの公開宣言であり、Rust の本体は `state fn` である。`listenerPort` は OS の `local_addr` の読み取りなので入口と数えた。純粋な補助関数は外部の新しい入口ではなく、既存の分類を保つ内部の派生と数えた。

## 検査

依頼で指定された次の work の dry-run を一回だけ実行した。対象は B_WORK からの差分と未追跡ファイルの選択・理由の表示であり、cargo のビルド・テスト、Lean、LLM を呼ぶ評価は実行していない。

```sh
scripts/check.sh --level work --base a522a3bbc1bfd217adc4d30dea2010a2e955f410 --dry-run
```

実行結果は [標準出力](work-dry-run.stdout.txt)・[標準エラー](work-dry-run.stderr.txt)・[終了・時間・常駐量](work-dry-run.measurement.json)に保存した。

| 選択と理由 | 終了状態 | 外側の所要 |
|---|---|---|
| 文書だけの変更 5 ファイルと分類され、`nothing to check: only documents changed`。選択された検査は 0 件 | 0。標準エラーは空 | 0.088293209 秒 |

5 ファイルは、実行時点の `inventory/http.md`、本結果、依存ソースの識別記録、実行前に開いた標準出力・標準エラーのログである。計測 JSON は実行後に増えた。後の変更も同じ指定範囲の文書・ログだけである。dry-run は一度で終え、再実行していない。選択の成功を実検査の成功として数えない。

## 最大常駐量

IF20.01 で外側の `/usr/bin/time -l` がサンドボックスの sysctl 拒否で失敗した申し送りに従い、初めから同枝の代替方法を使う。Python の `subprocess.run` で上の同じコマンドを待ち、`time.monotonic()` の差と `resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss` を別に採取する。macOS の原値はバイトとして記録し、MiB と GiB へ換算する。

原値は **10,108,928 バイト**であり、**9.640625 MiB、0.0094146728515625 GiB** である。これは OS の time が表示した値ではなく、同じ OS の getrusage による補助計測である。この測定プロセスの子について OS が報告する最大値であり、並行する全プロセスの RSS の合計、作業全体や Rust・Lean のビルドの最大値を表さない。取得不能を 0 とした値ではない。

## 検索と読解

宣言と実装の場所を確かめるために使った主な検索を示す。`rtk proxy` を付けた呼び出しも同じ検索式である。外の依存は `<cargo-registry>` で手元の場所を伏せた。

```sh
rg --files crates/benitoite/src/builtins/funcs docs/design/03-interop
rg -n 'Http|http|NetworkError' crates/benitoite/src/builtins/funcs/mod.rs crates/benitoite/src/runtime/io crates/benitoite/src/prelude/stdlib/Network
rg -n '^\s*(public )?function |name = ".*Http\.|pub const DECLS|NetworkError' crates/benitoite/src/prelude/stdlib/Network/Http.bnt crates/benitoite/src/builtins/funcs/http_server.rs crates/benitoite/src/builtins/funcs/http_client.rs crates/benitoite/src/builtins/funcs/http_util.rs crates/benitoite/src/prelude/stdlib/Trait.bnt
rg -n '^pub|^fn |^const|Failure|warning|shutdown|response_bytes|reject|retry' crates/benitoite/src/runtime/io/http.rs
rg -n 'execute_job|accept_completion|Worker|cancel|http::|HttpExchange' crates/benitoite/src/runtime/io/ops.rs crates/benitoite/src/runtime/io/resources.rs crates/benitoite/src/vm/dispatch/tasks/io.rs
rg -n 'Http|Request|Response|ClientRequest|network_error' crates/benitoite/src/builtins/funcs/mod.rs crates/benitoite/src/builtins/table.rs crates/benitoite/src/prelude/mod.rs
rg -n '^name = "ureq|^version = "3\.4\.2|ureq' Cargo.lock crates/benitoite/Cargo.toml
rg --files <cargo-registry> -g 'run.rs' -g 'redirect.rs' -g 'config.rs' -g 'lib.rs'
rg -n 'redirect|Redirect|authorization|cookie|history|ResponseUri|location|timeout' <cargo-registry>/ureq-3.4.2/src/run.rs <cargo-registry>/ureq-3.4.2/src/config.rs <cargo-registry>/ureq-proto-0.6.4/src/client/redirect.rs
rg -n 'fn need_request_body|fn is_redirect_retaining_status|HOST|host' <cargo-registry>/ureq-proto-0.6.4/src/ext.rs <cargo-registry>/ureq-proto-0.6.4/src/client/prepare.rs
rg -n 'Host|HOST|take_request|new_uri_from_location' <cargo-registry>/ureq-proto-0.6.4/src/client/amended.rs
rg -n 'dry.run|mkdir|target/|LOG|log_dir|check_policy|python' scripts/check.sh
rg -c '^\s*(public )?function ' crates/benitoite/src/prelude/stdlib/Network/Http.bnt
rg -c 'name = ".*Http\.' crates/benitoite/src/builtins/funcs/http_server.rs crates/benitoite/src/builtins/funcs/http_client.rs crates/benitoite/src/builtins/funcs/http_util.rs
```

改造の文書では `rg -n` で decisions の判断と IFC-D3/4/6/8、plan の IF20、study の Http・認証・応答・成否・暗黙の流れを検索し、該当節を `cat`・`sed -n` で読んだ。現行設計書では 00-01、03-07、03-09、01-07、07-01 の該当節を読み、Http の宣言、client と redirect_body、server と util、NetworkError の本体を読んだ。IO 実行器・資源・VM は、仕事・完了・取り消しと解放の関係部分を読んだ。依存ソースは追従・既定値・追加ヘッダー・Host・本文・期限の関係部分を読んだ。

読み取り用の git コマンドは `git rev-parse HEAD`・`git status --short`・`git status --short --untracked-files=all`・`git diff --name-only a522a3bbc1bfd217adc4d30dea2010a2e955f410 --` を用いた。後半の状態確認では `GIT_OPTIONAL_LOCKS=0` を指定した。文書作成後に Python で表の ID と各欄を読み出し、公開操作と各欄の行の件数・方向・候補を数え直した。これは文書の集計であり、本番の検査や実行ではない。

末尾二つの検索は、宣言全体 17 件と登録 7/1/1 件を返した。公開宣言から非公開の `serveLoop` を除いた名前の集合と H01〜H16 の名前は一致し、差は双方 0 件であった。16 行と 50 行は全て共通の 8 欄を持ち、文書内の相対リンクの参照先ファイルに欠落は見つからなかった。最終の git の読解では追跡済みの差分はなく、新規 6 ファイルだけが指定範囲にあること、HEAD が上の完全 ID のままであることを確認した。

## 失敗と修正

外部一次資料として docs.rs の固定版のソース四ページを取得しようとしたが、Web の道具は全て `Internal Error`・`not accessible via this tool` を返した。同版のローカルの Cargo registry ソースを読めたため、確認の根拠はそちらとし、Web 取得成功と記録していない。

一回の道具の呼び出しは JavaScript の構文誤りで実行前に拒否された。シェルの読解と文書の修正を分けて再送し、ソースや git の状態への変更はなかった。初稿の各欄の集計は、表を読み直した結果に合わせて方向を 21/18/7/4、候補を 14/11/25/0 に修正した。公開操作 16 件の集計は変わっていない。

実検査は起動していないため、処理系のテストの成功・失敗の報告はない。dry-run は初回で終了 0、再実行なしであった。

## ずれと申し送り

依頼の文書作業に限り、変更可能な範囲と禁止された読解・実行を守った。固定依存のローカルソースの追加読解と、その識別用ハッシュを保存した。計時は IF20.01 の代替方法を初めから使う指定どおりである。候補は設計者の回答待ちであり、担当は decisions や現行設計書へ転記していない。

| 後続 | 申し送り |
|---|---|
| IF20.03 | 環境変数と外部コマンドによる HTTP を別の入口・出口として数える。C の proxy None を、外部環境全体への非依存と扱わない |
| IF20.04 | Request/Response/ClientRequest の欄、header の Some/None、pathSegments・JSON・NetworkError の射影と Show の分類を表示・ログへ保つ。誤りの文言への混入を未確認のまま公開へ落とさない |
| IF20.05 | TimedOut・Ok/Error・状態と、InputTooLarge・ArgumentOutOfDomain・ResponseSentTwice・ReleasedResourceUsed、解放失敗を die・診断・終了状態へつなぐ。accept の資源不足の stderr 警告を含める |
| IF20.06 | Task の取り消しと開始済みの通信、待ち・ハンドラの非再開、サーバの自動応答と資源の解放、外部コマンド/WASM の先を照合する。機密ファイルの送信で IF20.01 の入力分類を緩めない |
| IF10 / IF30・取りまとめ | 回答後に非機密化の値・成否・用途と、未信頼を保つ完全性の契約を確定する。任意 URL 全体を固定 API と同じ契約にしない。U-H01〜U-H08 を担当先で追う |
| R30・取りまとめ | 新操作の取り込み後、同じ検査済み要求・実効 host/port・非追従・proxy・実対象の対応と、3xx の応答・誤りを再照合する。候補名を採択済みと書かない |

後続の独立レビューと設計者の受け入れの時期・所要は不明であり、本枝の完了範囲に含めていない。長い実検査や測定を追加せず、未確認を再現済みの不具合としても扱っていない。

## 時間

| 区分 | 記録 |
|---|---|
| 開始の時計 | 2026-10-27 18:03:36 JST（09:03:36 UTC）。AGENTS.md とスキルの初回読解後の最初の時計であり、その前の短い読解を含む正確な着手時刻ではない |
| 完了時の時計 | 2026-10-27 18:16:39 JST（09:16:39 UTC）。文書・集計・dry-run の記録と変更範囲を読み直した時点。この時刻と自己確認結果の転記が続く |
| 外側の所要 | 最初の時計から 13 分 3 秒と、上の転記の短い時間。初回の時計より前の読解を含む全所要は正確には取得していない |
| 能動時間 | 個別の計時なし。読解・文書作成・集計・自己確認を含む。全所要との差を厳密に算出できない |
| 検査・測定・待ち | 指定の dry-run 一回、0.088293209 秒。ビルド・テスト・性能測定・LLM 評価・設計者の回答待ちはなし |
| 上端の 2 倍と区切り | 見込みの上端 1 時間の 2 倍を超えていない。時間超過による中断はない |
