# 作業 S02a の結果

2026-10-25。基準 B_WORK と開始時の HEAD はともに `31cadf6344cbb8bd0e4494fd38d8e9101a761d55`、ブランチは `mod012/S02a` である。開始時の作業ツリーは未コミット差分・未追跡ファイルともになかった。git の変更操作は行っていない。

## 変更

| 対象 | 変更と確認 |
|---|---|
| `crates/benitoite/Cargo.toml` | Wasmtime を `=49.0.4` へ更新。`default-features = false` と `runtime`・`component-model`・`std`・`cranelift` を維持 |
| `Cargo.lock`・`fuzz/Cargo.lock` | 各27パッケージを更新。Wasmtime 関連14件（pulley の2件を含む）は49.0.4、Cranelift 13件は0.136.4。追加・削除や無関係なパッケージの更新はない |
| `src/external/text.rs` | 非公開エラーの文言を49.0.4のソースと照合し、コメントの版と根拠を更新。実際の分類条件はそのままで一致する |
| `src/external/tests.rs` | 既存の非同期拒否テスト一件を、例外・future・stream・非同期 lift/lower の五入力の表へ拡張。不正な入力を別の理由で拒否して通ることを避けるため、機能を許す wasmparser の検証器で各入力の妥当性も確認 |
| 設計書02-09・03-01・03-10 | 現在の版と出典を49.0.4へ更新し、実際の機能制限を03-10へ記載。過去の Fuzzy の実測は49.0.2の記録として維持 |

直接依存の wasmparser／wasm-encoder は0.258.3のままで、Wasmtime 49.0.4の配布 manifest も wasmparser 0.258.3を要求する。ルートの lock にある0.261.0の両クレートは既存の開発用依存であり、今回追加・更新していない。TLS の三修正版（rustls 0.23.46、rustls-webpki 0.103.16、webpki-root-certs 1.0.10）も二つの lock で維持した。外部取得元はすべて `registry+https://github.com/rust-lang/crates.io-index` のままである。

## 更新前の検査結果の引用

計画の更新前の確認には [S01 の結果](../s01/results.md)を引用し、T-W を重ねて実行していない。適用する時点は、S02a の manifest・lock・ソースを変更する前である。今回の更新後へ S01 の結果を引用したものではない。

| 引用の欄 | 確認内容 |
|---|---|
| 元の状態と記録 | S01 の基準・記録時の HEAD は `73d12d068d55aa55e342520c51f9fba9e7913bbf`。TLS を更新した未コミット状態で work を実行し、最終変更を `d0ef480ed244ea7dcda8dc938d002f71a4ccf4e2` が保存している。元のコマンド・件数・終了・時間・環境制限は `s01/results.md` にある |
| 引用先の状態 | HEAD `31cadf6344cbb8bd0e4494fd38d8e9101a761d55`。着手前は差分も未追跡入力もない。空の未コミット差分・空の未追跡入力の SHA-256 はともに `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| ソース・入力・設定 | `git diff d0ef480ed244ea7dcda8dc938d002f71a4ccf4e2 HEAD -- Cargo.toml Cargo.lock fuzz/Cargo.toml fuzz/Cargo.lock rust-toolchain.toml .cargo crates scripts deny.toml tools` は空。外部関数のソース、全テストと testdata の WAT・バイナリ・期待値、生成物、二つの lock、Cargo の構成、検査器と道具の入力は一致する |
| 外側の変更と影響 | S01 後の変更は改造の記録、区間解析の Lean、用語集、01-12、07-04だけである。外部関数の検査はこれらを読まず、Benitoite の検査器・外部ゲスト・CLI・生成器・Cargo 設定に変更はない。仕様全体や Lean の検査成功をこの引用で主張しない |
| 実行の範囲 | 元の `/usr/bin/time -l scripts/check.sh --level work --base 73d12d068d55aa55e342520c51f9fba9e7913bbf`。既定の lib 全件1271成功・失敗0・ignore 21、全統合40ターゲット378成功・失敗0・ignore 10。このうち外部関数の lib 133件、external_signals 3件、golden 2件も成功。フィルタを加えた別実行ではない |
| ツール・構成 | Rust 1.98.1、aarch64 macOS、既定の gc-mark-sweep。`rust-toolchain.toml` と全 Cargo 設定・検査スクリプトが同一。S02a の確認時は rustc `1.98.1 (48a229cea 2026-09-01)`、cargo `1.98.1 (797e8a9bc 2026-08-05)` |
| 終了と時間 | 元の検査本体0、682.44秒。`time -l` は `sysctl kern.clockrate` の拒否で終了1となり、最大常駐量は取得不能だった。環境制限を機能の成功で代用していない |
| 判断 | S02a 実装担当、2026-10-25。上記の入力の一致から、更新前の外部関数の回帰結果だけに引用できると判断した。更新後は本作業の work で改めて確認する |

入力の一致を確認した git の木・blob の ID は次のとおりで、S01 の保存版と S02a の開始版の両方で同じである。ディレクトリの木は、その下のソース・テスト・生成物・入力をまとめて識別する。

| 入力 | git の ID |
|---|---|
| `.cargo/` | `58a42301b2639c32d35fb90f0264ef3d895a0344` |
| `crates/` | `1d6902c1d20c014b30a2e980c34ce459f85c7806` |
| `scripts/` | `4c3b511415a9acd120ada298cc7aaece143518eb` |
| `tools/` | `6e508853d044af2459f7378a5208ffbe69debc42` |
| `Cargo.toml` | `0ff029fa33be0046ed2db025bccaa7ac624c0f79` |
| `Cargo.lock` | `b4452e9842c3661f5112871fbbe558ecee5b99bc` |
| `fuzz/Cargo.toml` | `ebcc0392ceea3d29ea8f4135cabefd153d467593` |
| `fuzz/Cargo.lock` | `30d762b85f9b99bc9d16821058665aa9f2705f86` |
| `deny.toml` | `2679dba7e6b38c3c2081e7ff8c889ccb73011930` |
| `rust-toolchain.toml` | `ef662bfeacd20bb55871ebb11e2aae21c7edde6a` |

## 上流の根拠と機能の境界

2026-10-25に49.0.4の配布ソースと `v49.0.4` の一次資料を照合した。配布物の `.cargo_vcs_info.json` が示すコミットは `2c2970205fe05d6bbf15b9bff6f1e67874b2db5c` である。

| 設計書の記述 | 照合した49.0.4の根拠と結果 |
|---|---|
| 03-01の C の例外とライセンス | 配布 `Cargo.toml` の機能・license、`build.rs::build_c_helpers` と `src/runtime/vm/helpers.c`、タグの LICENSE。選択した構成では小さな C の補助をビルドし、ライセンスは `Apache-2.0 WITH LLVM-exception` |
| 03-01の共有状態 | `module/registry.rs::GLOBAL_CODE`、`vm/sys/std_tls.rs::TLS`、`vm.rs::PAGE_SIZE`、`store/data.rs::NEXT_ID`。選択していない非同期の TLS を使う構成には広げていない |
| シグナルと Mach ports | `signals.rs` の `foreach_handler`・`trap_handler`・`lazy_per_thread_init`、`machports.rs` の `TrapHandler::new`・`sigbus_handler`・`lazy_per_thread_init`、`config.rs` の既定値。既存の行アンカー72・131・459、75・133・496、312は引き続き該当する。Linux の記述はソースの確認であり、Linux での実行検査ではない |
| 02-09の同期呼び出し・転送・分類 | `component/func.rs` と `func/typed.rs` の call/post-return、`values.rs` の持ち上げ、`component/store.rs` の hostcall fuel、`func/options.rs` の局所予算と非公開エラー、`limits.rs` と `store.rs::bump_resource_counts` |
| 03-10の名前と ABI | `NameMap::get` の完全一致優先、`Component::get_export_index`、`types.rs` の配置と `types_builder.rs::FlatType::join`。平らな型の合流のリンクを実際の定義へ補足した |
| 03-10の統計 | `Store::hostcall_fuel()` は設定値を返す。持ち上げの消費は局所予算へ保存され、失敗した部分の残量をこの API から取得できない。WasmStr の UTF-16/Compact UTF-16 の計数も維持 |

一次資料のリンクは同じ変更で02-09・03-01・03-10へ反映した。既知の修正範囲は [49.0.4 のリリース](https://github.com/bytecodealliance/wasmtime/releases/tag/v49.0.4)とも照合した。特定の攻撃用入力をすべて再現したという記録にはしない。

最小ゲストの五入力は、すべて機能を許す wasmparser では検証成功し、Benitoite の本番の検査入口では以下のとおりである。

| 入力 | 実際の結果 |
|---|---|
| コアの例外の tag・throw・try_table | E1004。注記に `exceptions proposal not enabled` |
| 非同期の関数と canon lift | E1004。注記に `async component functions require the component model async feature` |
| future u8 の型 | E1004。注記に `` `future` requires the component model async feature `` |
| stream u8 の型 | E1004。注記に `` `stream` requires the component model async feature `` |
| 非同期の関数を canon lower するコンポーネント | E1004。非同期の関数型の検証で拒否されるため、実行には進まない |

D24/D29の例外の既定値に関する見込みと、実際の構成を区別する。49.0.2と49.0.4の `config.rs` はともに例外の既定を Wasmtime の Cargo 機能 `gc` に連動させており、この設定に差はない。Benitoite はこれを含まず、更新後の実ゲストは上述のとおり拒否された。更新前の例外ゲスト自体は本作業では実行しておらず、更新前後の実測比較とはしない。`wasm_exceptions(false)` を追加せず、`gc`・`async`・WASI も追加していない。規則や構成を変えて通す作業には広げていない。

二つの manifest × `aarch64-apple-darwin`・`x86_64-unknown-linux-musl`・`aarch64-unknown-linux-musl` の六グラフを、`cargo tree --manifest-path <manifest> --locked --target <target> --edges features --invert wasmtime` で確認した。六回とも終了0、合計1.259秒。解決する Wasmtime の機能は `component-model`・`cranelift`・`once_cell`・`runtime`・`std`・`wasmtime-jit-icache-coherence`・`wasmtime-unwinder` であり、直接指定した四機能とその内部依存だけである。Linux のビルドや実行の成功は主張しない。

## コマンドと検査

依存更新は `cargo update -p wasmtime --precise 49.0.4` と `cargo update --manifest-path fuzz/Cargo.toml -p wasmtime --precise 49.0.4` を順に実行し、両方とも終了0。外側の時間は未計測である。取得には `cargo fetch --locked` を使った。

サンドボックスで書ける一時領域を `<scratch>` とし、S01 の取得済み index・source/cache の読み取り用リンクを一時領域へ複写して、`CARGO_HOME=<scratch>/cargo` を使用した。新しい27クレートはその領域へ取得した。追跡する Cargo 設定やツールチェーンは変更していない。

局所検査では、更新直後の既存の非同期拒否テスト一件が成功した。拡張中の `cargo test -p benitoite --lib fixed_engine_features -- --nocapture` は終了101で二件失敗した。一件は例外を受理するとの誤った仮定、もう一件は診断の `require` と `requires` の差をテストで厳しすぎる文字列と照合したためである。実際の機能の既定値と拒否理由に期待を直した。その後、機能を許す検証器による入力検査が、同期の関数を非同期 lower する不正な準備入力を検出した（終了101）。関数も非同期にした有効な入力へ修正した。最終の `cargo test -p benitoite --lib component_proposals_follow_the_fixed_engine_features -- --nocapture` は終了0、一件のテストで五入力が成功した（テスト本体0.35秒、外側の時間は未計測）。この試行は Wasmtime の不具合の修正ではない。

作業末は、基準を変えずに次の指定を実行した。`--test` を省き、全統合を対象とした。

| コマンド・確認 | 終了と結果 | 外側の時間・最大常駐量 |
|---|---|---|
| `scripts/check.sh --level work --base 31cadf6344cbb8bd0e4494fd38d8e9101a761d55 --dry-run` | 0。fmt、lint_default、lib_default、全統合の tests_related、source_rules、skill_generated、spec_tally、licenses を選択 | 外側の時間とメモリは未計測 |
| `/usr/bin/time -l scripts/check.sh --level work --base 31cadf6344cbb8bd0e4494fd38d8e9101a761d55` | 検査本体0。`selected checks passed` に到達。計時ラッパーは下記の理由で1 | 562.505秒（9分22.505秒）。`time -l` の maximum resident set size は取得不能。補助計測は **3,870,883,840 bytes** |
| `python3 <scratch>/check-docs.py`（変更した設計書三章と本記録の相対リンク・フェンス・末尾空白・非公開/絶対パスへのリンク不在、`git diff --check`） | 0 | 約0.02秒。メモリは未計測 |

work は一度実行し、次をすべて通過した。検査後に Rust・manifest・lock の再変更はない。

- examples を含む clippy、fmt、規約、Skill の再生成照合、仕様集計の自己検査と集計、ライセンス。
- 既定の lib 全件は1271成功・失敗0・既存の ignore 21。外部関数の lib 133件も成功。
- 全統合40ターゲットは378成功・失敗0・既存の ignore 10。external_signals は3件、golden は2件、HTTP の l32_http_client は9件、http_exchange_release は3件成功。

型付き・動的・補助・stateful の呼び出し、同期 call/post-return、R0904〜R0906・R0601・中断の既存テストを更新前と同じ構成で通した。`object_count_limits_are_resource_failures` は、実ゲストのコアインスタンス・メモリ・表の三つについて、必要数17・上限16の失敗をそれぞれ対応する資源の不足へ分類した。`typed_transfer_limits_apply_to_arguments_and_results` は、引数のない関数の戻り値の実際の持ち上げでも受け渡しの上限1024で停止し、上限2048では成功した。この失敗の分類が依存する非公開の原因は、49.0.4でも `too much data is being copied between the host and the guest: fuel allocated for hostcalls has been exhausted` に完全一致する。数の上限は `resource limit exceeded: {desc} count too high at {new}` の固定した接頭辞と必要数を読む。ソースの照合だけでなく、これらの実失敗で従来の分類を確認した。一般のトラップ、燃料枯渇、メモリ、epoch の中断、post-return 後の状態と次回の初期化のテストも成功した。期待値・ignore・時間制限は緩めていない。

`/usr/bin/time -l` は検査完了後に `sysctl kern.clockrate: Operation not permitted` と表示し、最大常駐量を取得せず終了1となった。シェルで検査本体の終了0を別ファイルへ保存し、計時ツールの終了と分けた。補助計測は、この work と計時ラッパーを実行した親 Python の `getrusage(RUSAGE_CHILDREN).ru_maxrss` による子プロセスの累積最大常駐量であり、プロセス全体の同時使用量の合計ではない。メモリの計測だけのために全件検査を反復していない。

## 更新後の勧告照合（T-S）

`cargo deny --version` は終了0、`cargo-deny 0.20.2`。ルートの `deny.toml` を一時領域へ写し、`[advisories]` の `db-path` だけを追記した。対象構成は元の三構成のまま、追跡する設定と ignore は変更していない。DB は二照合の際にそれぞれ更新した。

| 対象 | コマンド | 生の終了・照合結果 | 外側の時間 | 取得日時（UTC） |
|---|---|---|---|---|
| ワークスペース | `cargo deny --config <scratch>/deny.toml --locked check advisories` | 0、`advisories ok`。検出0件 | 1.036秒 | 2026-10-24T16:49:11.602925+00:00 |
| fuzz | `cargo deny --manifest-path fuzz/Cargo.toml --config <scratch>/deny.toml --locked check advisories` | 0、`advisories ok`。検出0件 | 0.919秒 | 2026-10-24T16:49:12.639164+00:00 |

両方とも DB は `https://github.com/RustSec/advisory-db`、コミット `21d909e4c8bd4e14c7aea58bf980c881a0053ab1` だった。初回の既知19件、S01後に残った Wasmtime の `RUSTSEC-2026-0353`〜`0364`・`0378`・`0379` の14件は検出されず、新しい勧告もなかった。これは取得不能を0件とした結果ではない。対象構成に現れない webpki-root-certs は両 lock の1.0.10を別に確認した。

| 照合した入力 | SHA-256 |
|---|---|
| `crates/benitoite/Cargo.toml` | `34e09ac63460b350dfd6f7b9aed6adb794e49a641414e1679e8f7a0c97679a52` |
| `Cargo.lock` | `f63fed7d012a331fb653d1f5e7e17a8833dc15ac7c3423ae447b45003968b0d2` |
| `fuzz/Cargo.lock` | `0cca6d39a47673bbb1e4bf42722983a7c7bdbf2cfbe9f75df46163e26842dc0c` |
| 元の `deny.toml` | `810721145d1a767d1011e2359a6d38460a075f9f911d3923c7e1b92d4c65cde1` |

二照合は `/usr/bin/time -l` で包み、検査本体の終了を別ファイルへ保存した。計時ラッパーは二回とも `sysctl kern.clockrate: Operation not permitted` で終了1となり、maximum resident set size は取得不能だった。補助計測の `getrusage(RUSAGE_CHILDREN).ru_maxrss` は二照合を含む子プロセスの累積最大値 **77,479,936 bytes** であり、二回目だけの値ではない。

## 計画からのずれと申し送り

- 例外の既定値に関する見込みを実構成と上流ソースで訂正した。受理範囲・機能指定・言語規則は変更していない。
- テストは既存の一件を表へ拡張し、総数を増やしていない。持ち主は本番のパイプラインによる外部コンポーネントの検証であり、公開フラグやテスト専用の本番経路は追加していない。Rust 本体の変更はコメント2行の増加、テストは40行の増加である。
- 型付き・動的・補助・stateful の経路、同期 call/post-return、R0904〜R0906・R0601・中断の結果は本作業の work で確認した。S01の引用を更新後の証拠にはしていない。
- 取っ手の専用上限100,000・分類・統計の接続と境界確認は S02b。短い性能比較は計画どおり S02b 後に取りまとめが担当する。
- `formal/`・01-12・07-04 は変更も検査もしていない。言語の規則や Lean の定理・公理に関する判断を要する点はなかった。
- 独立レビューと S 作業群の受け入れは取りまとめの担当である。
- 作業中に未追跡の `reviews/RV-C1R.md` が現れた。別作業の文書として扱い、本担当では読まず、編集していない。
