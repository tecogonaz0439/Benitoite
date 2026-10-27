# 作業 S02b の結果

2026-10-25。基準 B_WORK と開始時の HEAD はともに `542d9a345507424c6354b6b9372b17ff58fafcd1`、ブランチは `mod012/S02b`。開始時の差分と未追跡ファイルはなかった。git の変更操作と private/ の読み取りは行っていない。

## 停止と申し送り

**S02b は未完了であり、診断契約の再計画を要するため停止した。** [plan.md](../plan.md)「作業群 S02」の S02b 行と直後の説明、および [decisions.md](../decisions.md) D28 は、必要数を取得できず診断の契約を変える場合、取りまとめへ戻すことを求めている。

更新済みの Wasmtime 49.0.4 と現在の共通 `new_store` を使い、実コンポーネントで超過を再現した。超過の原因は数を含まない文字列であり、`Trap` の公開の列挙型にも該当しない。現行の `ResourceError::ExternalObjects` は `size: u64` を必須にし、R0906 の本文も必要数を必須にするため、原因から得た情報だけではこの契約を満たせない。`size` に上限や上限+1を代入する変更は行っていない。

本番コード、既存テスト、設計書、生成物、依存と二つの lock に最終差分はない。調査用モジュールの一時的な接続は元のバイト列へ戻した。本ディレクトリの再現資料と本記録だけを追加した。

取りまとめへ渡す具体案は、既存の `ExternalObjects` の必須欄を保ち、取っ手用に `ExternalComponentHandles { function, component, limit }` を加える案である。R0906 に必要数を要求しない文言の variant を加え、本文を ``the external function `{function}` exceeded the limit of {limit} component handles`` とする。実装時は、次の接続を同じ作業で閉じる必要がある。この案は未採用・未実装である。

- 専用定数100,000を共通 `new_store` の `set_max_component_handles` に渡す。`reset_limits` では変更せず、stateful の生存数を保つ。
- 49.0.4の原因文言の完全一致で分類し、広い部分一致や失敗後のゲストの呼び直しを使わない。adapter の補助報告との優先関係も確認する。
- 診断の提供側、統計の `reached_limits.component_handles`、02-09・02-10・03-10をそろえる。未知の資源名を既存 `ExternalObjects` へ渡すだけの変更では、統計ありで Internal へ変わる。
- 実取っ手の境界・drop後の再利用を正式な一つのテストへまとめる。統計あり/なし、stateful の複数呼び出し、任意トラップの誤分類防止、燃料・メモリ・中断との分類の優先を確認する。指定の全 lib・全統合・clippy・fmt を work で実行し、独立レビューを経て受け入れる。

別案は `ExternalObjects.size` を `Option<u64>` にして R0906 の variant を選ぶ方法であるが、既存の四資源の保持形式と利用箇所も変わる。取っ手に限定した追加の方が変更範囲を小さく保てると考える。どちらも診断契約の変更なので、この担当では選択していない。

## 実ゲストの再現

入力は [handles.wat（正式テストへ移動）](../../../../crates/benitoite/testdata/external/component-handles.wat)、調査コードは `probe.rs`（再開後に正式テストへ移して削除）、最終の生出力は [probe-output.txt](probe-output.txt)。ゲスト内の `canon resource.new` と `canon resource.drop` を使い、ホスト側のテストダブルを使っていない。小さい上限を渡す本番の設定を追加せず、現在の既定100,000個を使った。

| 操作 | 結果 |
|---|---|
| 共通 `new_store` が返す上限 | `max_component_handles() == 100000` |
| 同じ Store で99,999個を作る | 成功、ゲストの生存数99,999 |
| 同じ Store でもう1個を作る | 成功、生存数100,000 |
| 同じ Store で最後の1個を drop して1個を作る | 成功、生存数100,000 |
| 同じ Store でもう1個を作る | 失敗。原因列は下記の一件だけ |
| 本番の `external::call` から100,001個を要求、統計なし | `Stop::Runtime(ExternalTrap)`。報告の提供側 `stop_diagnostic` まで通し、kind Runtime・R0601を確認 |
| 別の実行で同じ要求、統計あり | 同じ Runtime・R0601。`reached_limits` は空であり、資源の不足としてはまだ数えられていない |

Wasmtime が返した `Error` の `Debug` と唯一の原因の `Display` は、ともに次の文言だった。公開の `Trap` への `downcast_ref` は `None`、原因の `Debug` はこの文字列を引用した形だった。

```text
cannot allocate another handle: store handle limit exceeded
```

報告の本文は ``the external function `testFn` trapped: cannot allocate another handle: store handle limit exceeded``、注記に ``component `wasm/test.wasm`, function `allocate` `` が付いた。CLI のプロセスを起動した検査ではなく、本番の外部呼び出し入口と報告の提供側を通した観測である。失敗した Store に対して診断のための呼び直しはしていない。

上限直下・上限・drop後の再利用の三操作は、同じ Wasmtime Store で実行した。正式な stateful 経路を複数回呼ぶ検査は未実施であり、これをその代わりと扱わない。計画の10秒を超える境界テストには該当せず、最終の調査テスト本体は0.04秒だった。

test-audit の作成時の関門では、外部の資源超過の分類を観察すること、一般トラップへの退行と統計による Internal 化を捕まえること、既存のコアの数と表の要素数のテストでは取っ手の超過を通らないこと、公開の設定や本番の差し込み口を増やさないことを確認した。今回のコードは現状の分類を確認する調査用であり、R0601を正しい将来の契約とする回帰テストとしては登録していない。

## API と原因の確認

取得済みの49.0.4の配布ソースを確認した。`runtime/component/store.rs` の `Store::set_max_component_handles` は上限を設定し、`max_component_handles` は設定値を返す。`runtime/vm/component/handle_table.rs` の `HandleCounter` は内部の `live` と `limit` を保持する。`HandleTable::insert` は `counter.live >= counter.limit` のとき文字列で `bail!` し、原因に必要数を入れない。成功した挿入で増やし、removeで減らす。上記の実測もこの定義に一致した。

照合した上流の箇所は [49.0.4 の Store API](https://github.com/bytecodealliance/wasmtime/blob/v49.0.4/crates/wasmtime/src/runtime/component/store.rs) と [49.0.4 の handle_table.rs](https://github.com/bytecodealliance/wasmtime/blob/v49.0.4/crates/wasmtime/src/runtime/vm/component/handle_table.rs) である。Web取得は失敗したため、確認の根拠はタグのWeb表示ではなく、S02aが取得した49.0.4の配布ソースと今回の実行である。取っ手の個数を返す公開のAPIや公開の専用エラー型は、これらの定義と呼び出し先にはなかった。

## コマンドと検査

Rust 1.98.1、Cargo 1.98.1、aarch64 macOS、既定構成。サンドボックス内で取得済みの依存を使用するため、`CARGO_HOME=<tmp>/benitoite-s02a/cargo` を指定した。追跡する Cargo 設定とツールチェーンは変更していない。

調査コードは `external::runtime::tests` の子として一時接続した。再現する場合は、`runtime.rs` の既存の `mod tests` 内、先頭の `#![allow(...)]` の後に、`#[path = "<probe.rs の絶対パス>"] mod s02b_probe;` を一時的に加え、下表の局所コマンドを実行した後にその二行を除く。`handles.wat` は `probe.rs` と同じディレクトリに置く。本番への公開項目やフラグは要しない。

| コマンド・試行 | 終了・結果 | 外側の時間・最大常駐量 |
|---|---|---|
| `cargo test -p benitoite --lib s02b_probe_component_handle_limit -- --nocapture` 初回 | 101。調査用 mod を既存の内部属性より前に置いた誤りと、調査コードの廃止済み `post_return` の警告でコンパイル失敗。接続を内部属性の後へ移し、不要な呼び出しを除いた | 未計測。依存の初回ビルドを含む |
| 同じ局所コマンド、修正後 | 0。1件成功、失敗0、ignore 0、1292件はフィルタ対象外。本番の分類が `ExternalTrap` であることを確認 | 外側は未計測。Cargoの表示はビルド13.01秒、テスト本体0.03秒 |
| `/usr/bin/time -l` で同じ局所コマンドを実行（報告の提供側までの確認を追加した最終版） | 検査本体0。1件成功、失敗0、ignore 0、1292件は対象外。計時ラッパーは1 | 8.603秒。`time -l` は `sysctl kern.clockrate: Operation not permitted` で maximum resident set size を取得不能。別途 `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` は **2,421,440,512 bytes** |

最終の局所実行は、`/usr/bin/time -l /bin/sh -c '"$@"; task_status=$?; printf "%s\n" "$task_status" > "$TASK_STATUS_FILE"; exit "$task_status"' sh cargo test -p benitoite --lib s02b_probe_component_handle_limit -- --nocapture` で包み、検査本体と計時ラッパーの終了状態を分けて保存した。`TASK_STATUS_FILE` は一時領域の出力先である。記録した8.603秒はPythonの単調時計による外側の時間である。

本番の接続を元へ戻した後の作業末の確認結果を、この下に記す。S02bの実装を受け入れる検査ではなく、停止時点で残した調査資料に対する確認である。R0904〜R0906・R0601・中断の正式な回帰一式、statefulと統計の新契約の検査、S02b後のshortと独立レビューは未実施。実装・workは再計画後のS02b担当、short・独立レビュー・受け入れは取りまとめの担当である。

| 作業末のコマンド | 終了・結果 | 外側の時間・最大常駐量 |
|---|---|---|
| `scripts/check.sh --level work --base 542d9a345507424c6354b6b9372b17ff58fafcd1 --dry-run` | 0。変更4ファイルを文書だけと分類し、検査対象なし | 未計測 |
| `/usr/bin/time -l scripts/check.sh --level work --base 542d9a345507424c6354b6b9372b17ff58fafcd1`（局所検査と同じ終了状態の保存用ラッパーを使用） | 検査本体0、`nothing to check: only documents changed`。全 lib・全統合・clippy・fmt は実行されていない。計時ラッパーは1 | 0.071秒。`time -l` の maximum resident set size は同じ sandbox の拒否で取得不能。補助の `ru_maxrss` は8,290,304 bytes |
| `git diff --check`、本番ソース・既存テスト・依存・設計書の最終差分なし、追加した Markdown の相対リンク・フェンス・末尾空白の確認 | 0 | 外側の時間・メモリは未計測 |

計画からの差は、S02bの診断契約の停止条件に該当したため、実装と正式な回帰検査へ進まず再現と提案を渡した点である。Leanは変更せず、ビルドしていない。取りまとめによる診断契約の再計画後に再開する。


## 再開と実装（2026-10-25）

上の停止記録は前回の調査時点の記録である。D28 の同日の追記で取っ手専用の保持形式と文言が採用されたため、依頼に従って再開した。今回の基準 B_WORK と開始時の HEAD はともに `d142e5a0ecd4cce22b0af25b9be2c0d265772a77`、ブランチは `mod012/S02b`。開始時の差分・未追跡ファイルはなかった。

共通の `new_store` に専用定数 100,000 と `set_max_component_handles` を接続した。呼び出しごとの `reset_limits` では設定と生存数を戻さず、stateful の Store の寿命で制限する。49.0.4 の原因の文言の完全一致で分類し、`ExternalComponentHandles { function, component, limit }` から必要数を要求しない R0906 を作る。既存の `ExternalObjects` の必須欄は保持した。中断・燃料・専用のメモリと表の制限を先に扱い、取っ手の超過は補助の報告より優先する。診断のためのゲストの再呼び出しは加えていない。

統計は `reached_limits.component_handles` に起動全体と関数別の回数を記録する。02-09・02-10・03-10 と診断表を更新し、00-04 に D28 の用語「コンポーネントの取っ手」の行を加え、`gen_skill` で同梱の診断資料を再生成した。言語の規則、Lean、依存、二つの lock、保持・GC の方式は変更していない。git の変更操作、private/ とそれを指すスキルの読み取りは行っていない。

### テストの関門と調査資料の整理

主テストは `external::runtime::tests::component_handle_limit_is_preserved_across_calls_and_drop` とし、実ゲストから外部の呼び出し・報告・統計の境界を通す。守る契約は取っ手の上限直下・上限・drop 後の再利用と、stateful の複数呼び出しを越える制限、および統計の有無によらない R0906 の分類である。既存のコア資源数のテストでは取っ手の超過を通らず、R0601 への退行と統計の未知の資源名による Internal 化を検出できないため追加した。公開のフラグ・設定・本番の差し込み口は増やしていない。準備済みの宣言表で動的・stateful・実生成器の補助の三経路を選び、同じ入力で統計あり／なしを確認する。

修正前のコードにこのテストを接続し、報告の kind が期待する Resource ではなく Runtime となって失敗することを確認した。修正後は成功した。任意トラップの誤分類を防ぐため、既存の `failures_and_fresh_instances` の表に、上限の原因文言を関数名に含む `unreachable` の行を加えた。中断・燃料・メモリ・既存の数の制限は既存の持ち主のテストで確認する。取っ手の超過との優先は `failure` と `has_priority_failure` の順序の読みで確かめ、同時の超過を起こすテストはない。テストの削除や期待値・大きさ・ignore・時間制限の緩和はない。

調査用 `handles.wat` は `crates/benitoite/testdata/external/component-handles.wat` へ移し、`probe.rs` は正式な主テストへ置き換えて本ディレクトリから削除した。`probe-output.txt` は、修正前の Wasmtime の原因列と R0601 の分類を示す停止時の生記録として残す。上の記録の WAT のリンクだけ移動先へ直し、削除した調査コードへのリンクを文字の記述に変えた。

### 再開後のコマンドと検査

Rust/Cargo は 1.98.1、aarch64 macOS、既定構成。取得済みの依存を使うため `CARGO_HOME=<tmp>/benitoite-s02a/cargo` を指定した。外側の時間を測っていない局所コマンドは未計測と記す。計時ラッパーは検査の終了状態を別ファイルへ保存し、`/usr/bin/time -l` 自体の終了と区別する。

| コマンド・試行 | 終了と結果 | 外側の時間・最大常駐量 |
|---|---|---|
| `cargo test -p benitoite --lib component_handle_limit_is_preserved_across_calls_and_drop -- --nocapture`（修正前、2回目は生出力の確認） | いずれも101。1件失敗。実ゲストの取っ手の超過が Runtime となり、Resource の期待に失敗 | 未計測。テスト本体0.03秒／0.00秒 |
| 同じ局所コマンド（診断と統計の修正後） | 0、1件成功。動的・stateful と統計あり／なしを確認 | 未計測。Cargo のビルド17.61秒、テスト本体0.04秒 |
| `cargo test -p benitoite --lib external::runtime::tests -- --nocapture`（補助経路・任意トラップの行を追加後） | 0、24件成功、失敗0、ignore 0。新しい主テストと、中断・燃料・メモリ・受け渡し・既存 R0906・通常トラップを含む | 未計測。テスト本体1.48秒。10秒を超える境界テストではない |
| `cargo test -p benitoite --lib external::adapter::report_tests -- --nocapture` | 0だが対象0件。ファイル名をモジュール名と誤認した指定であり、成功の証拠にしない | 未計測 |
| `cargo test -p benitoite --lib external::adapter::runtime::tests -- --nocapture`（指定修正後） | 0、3件成功、失敗0、ignore 0。実生成器の通常トラップ・燃料・メモリ・数の上限と補助の報告を確認 | 未計測。テスト本体0.04秒 |
| `cargo run -p benitoite --example gen_skill` | 0。診断資料だけに差分あり | 未計測。Cargo のビルド14.19秒 |
| `cargo fmt --all` | 0 | 未計測 |

作業末の work と文書点検の結果は、後掲「作業末の検査と修正」に記す。

### 勧告の二照合（T-S）

`cargo-deny 0.20.2` を使い、ルート設定の写しに書き込み先の `advisories.db-path` だけを加えた `<tmp>/benitoite-s02b/deny.toml` を両方へ明示した。ignore は追加していない。ルート設定の三対象 `aarch64-apple-darwin`・`x86_64-unknown-linux-musl`・`aarch64-unknown-linux-musl` を照合し、機能の選択は cargo-deny の既定とした。対象や機能を選ぶ追加フラグは付けていない。DB は今回取得・更新した `https://github.com/RustSec/advisory-db`、コミット `21d909e4c8bd4e14c7aea58bf980c881a0053ab1`。時刻はコマンド開始時刻（UTC）であり、この二コマンド中に取得・更新した。

| 対象・コマンド | 日時（UTC）・lock の SHA-256 | 状態・生の終了・外側の時間 |
|---|---|---|
| `cargo deny --config <tmp>/benitoite-s02b/deny.toml --locked check advisories` | 2026-10-24 17:33:43、`f63fed7d012a331fb653d1f5e7e17a8833dc15ac7c3423ae447b45003968b0d2` | **照合済み・検出0件**、IDなし。生の終了0、0.983秒 |
| `cargo deny --manifest-path fuzz/Cargo.toml --config <tmp>/benitoite-s02b/deny.toml --locked check advisories` | 2026-10-24 17:33:44、`0cca6d39a47673bbb1e4bf42722983a7c7bdbf2cfbe9f75df46163e26842dc0c` | **照合済み・検出0件**、IDなし。生の終了0、0.835秒 |

いずれも出力は `advisories ok`。計時ラッパーは1となり、`time -l` の最大常駐量は sandbox による `sysctl kern.clockrate: Operation not permitted` で取得不能。補助の `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` は二実行を含むプロセス累計の最大として 77,660,160 bytes だった。S01/S02a から依存は変更せず、今回の DB では最初の19件を含む依存の勧告の残りを検出していない。特定の攻撃入力の再現やツールチェーン全体の無影響を、この照合の結果とは扱わない。


### 作業末の検査と修正

基準と全統合の指定を固定した work を一度実行した。初回は `golden::testdata_components_match_their_text` が失敗した。正式な WAT を `testdata/external/` へ移す際、隣接する `.wasm` も要る既存の入力契約を見落としたことが原因である。`golden_suite` 本体は成功した。

`wasm-tools` が環境になかったため、ロック済みの `wat` クレートのコンパイル済み rlib と一時的な Rust の小プログラムから `wat::parse_file` を呼び、`component-handles.wasm`（376 bytes）だけを生成した。実際のコマンドは `rustc --edition=2024 --crate-name compile_wat <tmp>/benitoite-s02b/compile-wat.rs --extern wat=target/debug/deps/libwat-223259a67eb5af79.rlib -L dependency=target/debug/deps -o <tmp>/benitoite-s02b/compile-wat` と、生成した実行ファイルの実行である。既存の入力や期待値は書き換えていない。修正後の一致検査がこのバイナリと WAT の同一性を確認した。

修正後は、失敗した `golden` と、初回の停止により未実行だった30統合ターゲットおよび三つの後続単位だけを名指しし、先に同じ指定の dry-run を確認した。fmt・clippy・lib と先行9統合ターゲットは成功済みで、バイナリの追加によって古くならないため重ねていない。work 開始後に加えた用語集の行と原語の併記は実行入力を変えないため、文書点検で確認した。

| コマンド | 終了と結果 | 外側の時間・最大常駐量 |
|---|---|---|
| `scripts/check.sh --level work --base d142e5a0ecd4cce22b0af25b9be2c0d265772a77 --dry-run`（最終の初回選択） | 0。変更14ファイルから fmt・lint_default・lib_default・tests_related（全統合）・source_rules・skill_generated・spec_tally を選択 | 外側は未計測 |
| `/usr/bin/time -l` で上記の dry-run を除いた work を実行 | 検査本体1。fmt・clippy 成功、lib は1,272件成功・失敗0・ignore 21件。先行9統合ターゲット成功。golden は本体成功・入力一致の1件失敗。後続単位は未実行 | **284.396秒**。`time -l` の最大常駐量は取得不能。補助の `ru_maxrss` は **2,447,360,000 bytes** |
| 下記の修正後の指定に `--dry-run` を追加 | 0。golden と未実行30統合ターゲット、source_rules・skill_generated・spec_tally の部分選択を確認 | 外側は未計測 |
| `/usr/bin/time -l` で下記の修正後の指定を実行 | **検査本体0**。31統合ターゲット、ソース規約、Skill の生成照合、仕様の集計とその自己検査がすべて成功 | **314.959秒**。`time -l` の最大常駐量は取得不能。補助の `ru_maxrss` は **523,190,272 bytes** |
| `python3 <tmp>/benitoite-s02b/check-docs.py` と `git diff --check` | 0。変更した Markdown 6ファイルの相対リンク511件・アンカー34件、フェンス・末尾空白・公開文書への非公開リンクの混入を点検。見出しの改名なし | 約0.04秒。メモリは未計測 |

文書点検の最初の一時スクリプトは、用語集のインラインコードの `...` をリンクと誤認して止まった。コード内をリンクの走査から除くように点検器を直し、上表の確認を通した。文書のリンク切れではなく、点検器の誤検出であった。

修正後の実行は次のコマンドである。検査単位として部分選択であるが、初回の成功分と合わせ、Cargo の対象一覧40件と実行結果の対象集合が一致することを照合した。最終の統合検査は **378件成功・失敗0・ignore 10件** である。

```sh
scripts/check.sh --level work \
  --base d142e5a0ecd4cce22b0af25b9be2c0d265772a77 \
  --only tests_related,source_rules,skill_generated,spec_tally \
  --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process \
  --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json \
  --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers \
  --test l32_http_client --test named_arguments --test network_faults --test open_062 \
  --test open_062_http --test package_command --test property_library --test random_programs \
  --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples \
  --test spec_examples --test stdlib_doc_examples --test test_command --test verify \
  --test vm_handlers --test vm_lazy --test vm_reference_cells
```

計時ラッパーは両方とも1。`/usr/bin/time -l` の `sysctl kern.clockrate: Operation not permitted` によるもので、検査の終了状態は `/bin/sh -c '"$@"; task_status=$?; printf "%s\n" "$task_status" > "$TASK_STATUS_FILE"; exit "$task_status"' sh <検査コマンド>` の形で別に保存した。上表の時間は Python の単調時計による外側の時間、最大常駐量の補助値は `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` である。

### 最終の差分と申し送り

本番 Rust は追加55行・削除10行（差し引き45行増）、正式な Rust テストは追加101行・削除0行。正式な WAT は29行を移動し、対応するバイナリを加えた。調査用 Rust 94行を削除した。これらの行数は空行とコメントを含む。既存テストの削除、テストだけの本番 API・フラグ・ラッパーの追加はない。

計画からの差は、正式入力のバイナリ不足を作業末の検査が検出したため、生成して失敗した対象と未実行分を再実行した点、および用語集の行を規約に従って補った点である。D28 の採用済みの契約を越える判断や、保持・GC の変更は要しなかった。取っ手の原因の一次資料は取得済みの49.0.4の配布ソース（`runtime/component/store.rs` と `runtime/vm/component/handle_table.rs`）で再確認し、Web 表示の取得は今回も失敗したため、Web から取得したとは扱っていない。

**S02b の実装と担当する検査は完了した。** 独立レビュー、S02b 後の B0 との short、後続 S 作業と受け入れは取りまとめの担当である。Lean のビルド、段・改造・公開候補の検査、short、コミット・取り込み・push はこの担当では行っていない。

2026-10-25、SR: 本文の一時パスと `probe-output.txt` のリポジトリの絶対パスを `<tmp>`・`<repo>` に置換した。生記録のパス以外の出力は変更していない。
