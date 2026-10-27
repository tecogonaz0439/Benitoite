# X03c の結果

着手（最初の時刻取得）: **2026-10-26 23:07:43 JST**。終了（指定 work 後の点検と記録）: **2026-10-26 23:24:32 JST**。所要時間: **16分49秒**。

**状態: 案III の実装・局所比較・07-04 の更新・指定 work と最終点検を完了した。独立レビューと受け入れは取りまとめへ渡す。**

B_WORK と HEAD は `d42f988c6f90b8419b6a7e68ce1a5b046756ceb2`、ブランチは `mod012/X03c`。着手時に差分はなかった。AGENTS.md、共通依頼文、plan の前提・契約・X01〜X05・X03c の API 別の表と検査・RV-C5 後の変更、D4 の変更・D5・D17・D18・D20・D21、指定された L26〜L29S・A19〜A21・X01〜X03b の申し送り、RV-C5 を確認した。rtk・test-audit・japanese-tech-writing を適用した。

## 実装した範囲

| ファイル | 変更と目的 |
|---|---|
| `crates/benitoite/tests/desugar_export/interval/vm.rs` | 既存の一つの書き出しにシフト27宣言×4行の比較用ソースの生成を加えた。標準 call の頭を funName と primName の両方から同定し、引数をソース順に束縛してから元キーの標識を置く |
| `formal/tests/interval_shift_vm.py` | 実ソースの宣言・元キー・型・標準表を照合し、整数の域外46行を閉じた評価と VM、残る62行を独立した VM の期待へ照合する。包みの位置・具体値・到達・R0701 と評価除外を別に記録する |
| 同 `interval_vm_compare.py`・`test_interval_exchange.py` | 既存の構造と位置の照合を共用し、固定域の call と R0701 を扱う。算術・Range の閉じた比較の条件を保ち、`--vm-dir` からシフトも必ず起動する |
| 07-04 と交換の README | 厳密に比較した46行、独立照合だけの62行、包み7宣言の位置、操作・HTTP の除外と A1 の信頼の範囲を反映した |

本番 Rust・VM 本体・安全点・標準ライブラリ、Lean の定義・定理・公理・`formal/lakefile.toml` の `-M 12288` を変更していない。予算の固定表・上限・割り当て量の入力と期待、既存六入口の本文・sidecar・manifest も不変である。

## シフトの比較結果と A1 の限界

| 入力 | 件数 | 照合結果と比較の分類 |
|---|---:|---|
| 整数23宣言の域外 -1・w | **46** | 評価関係の outsideDomain、標準宣言・契約順の二引数・元キーの事象、実 VM の標識・R0701・異常終了・位置が一致した。評価関係との厳密比較に数える |
| 整数23宣言の域内 0・w−1 | **46** | 実 VM は R0701 なしで正常終了し、独立したビット列の期待値と一致した。評価器は unknownFailure なので、評価関係との比較へ加えない |
| Byte・UnsignedInteger8 の域外 -1・8 | **8** | 実 VM の標識・R0701・異常終了・位置を独立期待へ照合した。Byte のリテラルが未知で、評価器は notClosedOrFuel なので厳密比較へ加えない |
| Byte・UnsignedInteger8 の域内 0・7 | **8** | 実 VM の標識・正常終了・独立した値を照合した。同じく notClosedOrFuel として厳密比較へ加えない |
| 合計 | **108** | **評価関係との比較46行、独立照合だけ62行**。実 VM は R0701 が54行、正常値が54行。評価の除外は unknownFailure 46行と notClosedOrFuel 16行 |

w は値のビット幅である。符号付きは -1、符号なしと Byte は全ビットが1の値を渡す。量0では元の値、w−1 の左シフトでは最上位の1ビットだけが残る。符号付きの右シフトは -1、ゼロを補う右シフトは1となる。期待値は Python の独立した宣言・幅の表とこのビット列から定め、Rust の解析出力や Lean の実行結果から作っていない。左シフトで捨てるビットをあふれとする期待へ変えていない。幅の域外の行は n・a の逆順の名前付き引数とし、trace の契約順とは区別した。

[シフトの全実行・元キー・位置と除外の要約](shift-vm-summary.json)に、全108実行、元キーと標識後のキー、元位置・標識位置・演算位置を保存する。

### 包みの7宣言の R0701 の位置

| 包みの宣言 | 域外の実行数 | R0701 の文言に現れた内側の名前 | 一次位置と比較の扱い |
|---|---:|---|---|
| Integer64.shiftLeft・shiftRight・shiftRightUnsigned | 6 | Integer.shiftLeft・shiftRight・shiftRightUnsigned | すべて呼び出し元の call。厳密比較46行のうち6行 |
| UnsignedInteger.shiftLeft・shiftRight | 4 | UnsignedInteger64.shiftLeft・shiftRight | 同上。厳密比較46行のうち4行 |
| UnsignedInteger8.shiftLeft・shiftRight | 4 | Byte.shiftLeft・shiftRight | 同じ呼び出し元の call。Byte の独立照合8行のうち4行 |

包みの14実行で、一次位置が包みの本体ではなく元の call に対応することを確認した。元キーに結び付けた標識後の call の開始・終了オフセットに加え、診断のファイルが実行した比較用ソースであることを要求する。診断の文言だけを見て元 call の位置へ推定で付け替えていない。包み本体の位置を許す例外や VM の観測用フラグは加えていない。

### 比較しない範囲

域内のシフトの具体値と Byte の結果は独立した VM の観察であり、評価関係との一致の証拠ではない。Byte の具体規則や域内シフトの算法を Lean へ加えていない。未知の引数を含む入力も厳密な実行比較へ入れていない。

Process.exit・Http.Listen.listen・Http.Listen.respond・Http.Connect.send と HTTP の欄は比較しない。D4 の変更に従い、操作と HTTP の欄を固定域へ戻していない。Range と固定域の評価規則そのもの、標準束縛と出現の二表の実ソースへの由来は A1 の信頼の範囲に残る。有限の実行比較は、全入力の意味保存や元ソース全体の意味保存の証明ではない。07-04 に同じ区分を記した。

## 既存の比較と作成時の関門

既存の算術・フローは39関数・70事象、Range は37関数・68事象の実 VM 比較が成功した。Range の三欄・Error・逆転優先、独立した別個体の105の観察、標識出力の失敗 R0201 の除外も維持した。[算術の要約](arithmetic-vm-summary.json)・[Range の要約](range-vm-summary.json)を保存する。

元・標識付きの算術39+39、Range46+46、シフト108+108の計386本体について、通常予算の解析結果・候補・利用者向け警告・消費・停止を Rust と Lean で比較し、一致した。深さ・予算・番号の停止と未解析は0件である。標識の Console と、Byte のリテラル等の未対応は未対応のまま照合し、警告を消していない。[通常解析の要約](real-source-summary.json)と[五 profile の記録](profile-manifest.json)を保存する。

作成時の関門では、実交換と対象構文の評価関係・実 CLI の間の、シフトの失敗・値・到達と位置の契約を守るとした。現実的な退行は、契約順とソース順の混同、包みの名前と診断位置の混同、正常なビットの切り捨てをあふれにすること、Byte と域内の評価除外を厳密比較へ足すこと、元キーと標識後の位置の混同である。既存の静的比較と算術・Range の VM 比較はシフトの具体的な結果と包みの位置を読まないため、同じ一つの書き出しと表形式の比較へ追加した。本番の公開範囲・フラグ・テストダブルは加えていない。既存テストの削除はない。

正しい VM の観察から値・到達・失敗コード・ファイル・直接 call の位置・包みの call の位置を一箇所ずつ壊した六種類と、出現の同定を欠く call を比較器が拒否した。これら七種類の負例は正の108実行へ加えていない。

## 検査と途中の失敗

実行場所は `<repo>`。[run.py](run.py) がコマンド・終了状態・外側時間とパスを伏せた出力を保存する。Cargo は `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。局所比較は既存ビルド済みの intervalDiff を逐次起動し、Lean のビルドはここから起動していない。

| 検査 | 結果・記録 |
|---|---|
| 比較用ソースの書き出し | 終了0、5.384秒。算術80・Range96・シフト108対象演算（[記録](export-second.json)・[出力](export-second.log)） |
| 最終の局所比較 | 終了0、28.784秒、intervalDiff 183起動。シフト108行、既存算術・Range、六入力の通常解析、五 profile の独立期待値と負例（[記録](comparison-verified.json)・[出力](comparison-verified.log)） |
| 作業途中の割り当て量二件 | 両方成功、11.623秒。20,000定数は442,858,487バイト、5,000定数・1,000診断は254,972,750バイト。X03b と同じ値で上限512 MiB・256 MiB を保った（[記録](allocations.json)・[出力](allocations.log)） |
| 同じ基準・指定の dry-run | 終了0、0.097秒。fmt・examples を含む clippy・全 lib・全統合・ソース規約・生成 Skill・仕様集計・Lean 既定ビルドの8単位（[記録](dry-run.json)・[出力](dry-run.log)） |
| 指定 work | **検査本体終了0、478.969秒、8単位成功**。lib 1,332件成功・失敗0・ignored 21、全統合40ターゲット・394件成功・失敗0・ignored 10（[本体](work-check.json)・[全出力](work-check.log)） |
| 最終点検 | 終了0。6入力・757保護対象のハッシュ、Python の構文、件数、記録のパス、ZIP と索引、結果の相対リンク、git diff --check を照合した（[点検器](audit.py)・[結果](self-review.json)） |

指定 work は、同じ指定の dry-run の後に次を一度実行した。Rust のテストを変えたため、統合ターゲットを絞っていない。

```sh
scripts/check.sh --level work --base d42f988c6f90b8419b6a7e68ce1a5b046756ceb2
```

[work-check.py](work-check.py) を `/usr/bin/time -l` で包み、本体と計測器の終了状態を分けて保存した。**最大常駐量（maximum resident set size）は取得できなかった。** 検査本体の終了0の後に、計測器が `sysctl kern.clockrate: Operation not permitted` と報告して終了1になった。外側は478.998秒、real/user/sys は478.99/1378.59/79.99秒である（[外側の記録](work.json)・[出力](work.log)）。未取得を0とせず、計測だけの再実行は行っていない。指定 work の失敗と再実行はない。

最終の局所比較の指定は次である。

```sh
BENITOITE_DESUGAR_DIFF_DIR=target/interval-diff/x03c cargo test -p benitoite --test desugar_export export_interval_vm -- --nocapture
python3 -B formal/tests/test_interval_exchange.py --vm-dir target/interval-diff/x03c --rust-dir target/interval-diff/x03c/original --rust-dir target/interval-diff/x03c/instrumented --rust-dir target/interval-diff/x03c/range/original --rust-dir target/interval-diff/x03c/range/instrumented --rust-dir target/interval-diff/x03c/shifts/original --rust-dir target/interval-diff/x03c/shifts/instrumented --output target/interval-diff/x03c/comparison-verified
cargo test -p benitoite --test call_allocations constant -- --nocapture --test-threads=1
```

書き出しの初回は生成した関数名を大文字から始めたため E0201 で失敗した。先頭を shift に直し、次の書き出しは成功した。比較器の初回は標準の完全名と解決済みの宣言 ID を混同して停止した。実交換の name で役割を照合し、declaration の ID を使う形へ直した。次の起動は静的候補の期待を作る際に標準の名前対応表を渡し忘れて停止した。既存の候補照合へ表を渡して直し、その後の比較と最終の局所比較は成功した。失敗は export-first・comparison-first・comparison-second の記録に残す。Lean の定義や期待の緩和、Rust の解析精度の変更で通していない。

## 最終点検と申し送り

[audit.py](audit.py) と [work の入力ハッシュ](work-inputs.json)で、実装・文書6入力と、本番 Rust・Lean・固定表・割り当て量のテスト・lock・固定版等757保護対象を点検し、検査の前後で一致することを確認した。指定 work 後は結果と保管・点検の記録だけを更新した。

局所比較の入力・報告・実行結果2,905ファイルと相対リンク2件を、[ZIP](local-records.zip) と [SHA-256 の索引](local-records-index.json)へ保存した。[bundle.py](bundle.py) は手元のパスを伏せた bytes を読み戻して照合する。一時的な target のログだけを引用元にしていない。results・ログ・保存スクリプトに手元の絶対パスは残していない。

本番 Rust の増減は0行、Rust のテストは47行追加・4行削除、Python の比較は185行追加・5行削除である。比較用 bnt は Rust の既存テスト内で生成し、元と標識付きの本文を保管した。テスト関数の追加と既存テストの削除はない。結果記録・保管・点検のスクリプトはこの集計に含めていない。

計画の担当範囲の変更、停止条件への該当、4時間の上限による中断はない。言語の規則、Lean の定義・主要定理・公理、本番 Rust の型・署名、予算の固定表の変更を要する判断は残っていない。work の Lean は既存のキャッシュを使い、別の Lean のビルドを並行させず、背景に置いて別の作業を進めていない。別の関係状態の結果を引用して省いた検査はない。

private/ とそこを指すリンク、担当の委任、git の変更操作、コミット・取り込み・docs/todo の更新・保管・公開は行っていない。stage・change・release・check-formal.sh 全体は本枝の割り当てでは実施していない。既存六入口を含む同じ関係状態の全比較と K1 は、X04〜X05 と取りまとめへ渡す。

| 残る手順 | 担当と受け渡す内容 | 見込み |
|---|---|---|
| X03c の独立レビュー・受け入れ | 取りまとめ。比較46行と独立照合62行、包み7宣言の元位置、07-04 の A1 の限界、検査の関係状態を確認する | 不明 |
| 全比較への接続・K1・検査・レビュー・受け入れ | X04〜X05 と取りまとめ。`--vm-dir` はシフトも必須で実行する。通常解析は六つの `--rust-dir` を使い、既存六入口を含む同じ関係状態で全比較を閉じる | 計画による。今回未測定の時間は不明 |

## 取りまとめのレビュー（2026-10-26）

受け入れる。X03c の表のシフトの行のとおり、評価関係と VM を厳密に比べたのは整数の23宣言の域外の46行だけで、域内の46行と Byte・UnsignedInteger8 の16行は独立期待値とだけ照合し、比較済みの件数に含めていない。包みの7宣言の R0701 は、文言が内側の組み込みの名前、一次位置が呼び出し元の call である。07-04 に A1 の限界を記した。本番の Rust・VM・Lean の定義は変わらない。X04a へ進む。
