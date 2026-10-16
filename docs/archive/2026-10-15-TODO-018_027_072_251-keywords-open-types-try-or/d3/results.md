# D3 corpus 9 と型表・網羅性 3 の入口

## 目的と変更

D2c の本体ごとの view を、独立した JSON 入力から六入口へ渡す。開始時の HEAD は `b0f31a2baffc3087a139ff061e5b38f67ddf3efd`、作業ツリーは clean だった。D3・共通の関門 K、design.md「形式化と受け渡し」、R8〜R10・R12、D2c の定義と検査の記録を読み、現在の値・型保存の前提と結論を保つ範囲を自己確認した。

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Exchange/Syntax.lean`・`Version.lean`（新設） | corpus 9 の `Input.dataTypes`・`SurfaceDef.coverageView`、版の検査、旧版だけの閉じた既定、指定先の存在・属性・一意性の検査 |
| `formal/Benitoite/Exchange/Builtins.lean` | 型表 3 の `DataEntry` の属性・型表示、record の印とフィールドの対応 |
| `formal/Benitoite/Exchange/Convert.lean`・`CheckInput.lean` | Program と Materials の関数・実装メソッドごとの指定、corpus と型表の対応。上位辞書の合成単位を関数として扱わない |
| `formal/{CoverageDiff,CoverageProgramDiff}/Main.lean` | 網羅性 3 の case/match/binding の指定、型表示、再帰・到達不能・束縛・燃料の監査への同じ view の接続 |
| `formal/DesugarDiff/Main.lean`・`BuiltinCheck/Main.lean`・`SurfaceCheck/{Main,Batch}.lean` | 新旧の版と必須欄の入口、版の組と全宣言の対応、単独の関数と全件の本体ごとの検査 |
| `formal/tests/named-exchange/{corpus,builtins,stdlib,coverage,coverage-program}.json`・`README.md`、`test_named_exchange.py` | 固定入力を 9/3/3 へ更新。期待コアと全既存 assert は保持。Python は冒頭の版の説明だけ更新 |
| `formal/tests/width-exchange.json`・`test_width_exchange.py` | 版の固定値を 9/3/3 にし、入力を新版の必須欄で構築。幅の全既存 assert は保持 |
| `formal/tests/extensible-exchange/`（新設）・`test_extensible_exchange.py`（新設） | 属性・型表示と本体ごとの指定の独立した正負の入力。既存の六入口の呼び出しを共有 |
| `crates/benitoite/tests/desugar_export.rs`・`tests/desugar_export/named.rs` | 新版の固定入力を型枠にしていた補助テスト二つを、既存のテスト内の input 構築へ変更。Rust の現在の版を明示し、期待コアと assert を保持 |
| `scripts/check-formal.sh` | 独立した拡張可能な型の交換テストを追加 |
| `docs/design/01-spec/01-12-core-calculus.md`・`07-quality/07-04-formal-semantics.md` | 接続済みの交換契約と、Rust の未接続範囲の写し |
| 改造ディレクトリの `decisions.md`・`p2/formal.md`・この記録 | R30、定義・言明の対応、検査と申し送り |

Rust の本番実装と書き出しの版は変えていない。補助テスト二つの暗黙の固定入力への依存だけを外した（R31）。corpus 8・型表 2・網羅性 2 は、新版の欄がない閉じた互換入力として受理する。新版の欄を空・false にして旧版へ混ぜた入力も拒否する。網羅性 2 の `RawDecl.typeName` は旧来からある欄であり、保つ。

## test-audit の作成時の関門

1. 主となる公開境界は六つの交換 CLI である。JSON の必須情報を捨てずに正式モデルへ接続する契約を守る。型付けの規則そのものを各層で重ねて検査しない。
2. 属性だけの宣言の欠落、未知・閉じた型・重複した view、型表との食い違い、旧版へ混ぜた新しい情報の黙認、本体ごとの指定の取り違え、record・入れ子・リストの型表示の消失を捕まえる。単独の関数、全件の関数・メソッド、網羅性の両入口が同じ指定を使うことも確かめる。
3. 既存の named/width の検査は契約名と幅を守るが、属性・view の情報を持たない。既存の assert・期待コアは維持し、固定入力に新版の欄を加えた。新しい正負の入力は一つの共有する入力群と表形式の Python の検査にまとめ、持ち主の境界を増やしていない。
4. テスト専用の公開 API・フラグ・差し込み口は加えていない。追加した JSON の欄と変換は、本番の交換 CLI が使う。期待コアを Lean の脱糖や Rust の書き出しから生成していない。

新しい独立検査は 14 件である。既存の named 12 件・width 4 件を減らしていない。新しい入力を構築する途中の型・束縛・反例の不一致は厳密な理由で検出し、正式モデルの定義を読んで入力を修正した。既存の診断の仕様変更、assert の削除、期待値の緩和、ignore・時間制限・対象外理由の変更はない。Rust の本番コードの差分は 0 行である。補助テストの入力の構築だけを変更し、既存の assert は保持する。

## 検査

検査内容と形式化の所要時間を実行前に報告した。指定に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成は実行しない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,156 passed、0 failed、既存の ignored 21。74.86 秒 |
| `cargo test -p benitoite --test spec_examples --test skill_docs` | 成功。spec_examples 7 件、skill_docs 8 件 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `formal/` で `lake build` | 成功。161 jobs。sorry の警告なし |
| `python3 -I formal/tests/test_named_exchange.py`・`test_width_exchange.py`・`test_extensible_exchange.py` | 最終の独立入力で 12＋4＋14 件が成功 |
| `cargo test -p benitoite --test desugar_export export_named_ -- --nocapture` | R31 の修正後に 5 件成功。既存の manifest の版・四入口の比較も二つの補助入力それぞれで成功 |
| `bash -n scripts/check-formal.sh` | 成功 |
| `bash scripts/check-formal.sh` | 修正後の全工程の再実行が成功、終了状態 0。Rust の coverage_export 2 件、desugar_export 15 件、Python 4＋12＋14 件と六入口の比較を通過 |
| `git diff --check` | 最終の記録を含め成功 |

最初の `check-formal.sh` は、全 1,727 入力・73,733 定義・22,438 網羅性項目まで一致し、最後の補助入力の版の照合で失敗した。R31 に従い直し、Rust の検査と補助入力の厳密な比較を通してから、スクリプト全体を再実行し、全工程が終了状態 0 で完了した。新しい axiom・sorry・admit・native_decide、定理の弱化は加えていない。

Rust の本番コードは差分 0 行、テストは 12 行増・22 行減である。Lean の交換・CLI は 225 行増・62 行減、Python の交換テストは 296 行増・6 行減である。新しい固定 JSON は別に追加している。旧 named の五つの固定入力は、新しい欄と版を除くと開始時の JSON と完全に等しい。既存の Python の全 assert は AST の比較でも同一であり、Rust の差分で既存 assert を消していない。

### 六入口の件数と分類

最終の出力は `target/desugar-diff/run-63417/` と `target/coverage-diff/run-63417/` にある。検査のログは前者の `d3-*.log` に保存した。D2c の全件の件数・分類と一致し、対象外理由・破損入力の拒否も維持している。

| 入口 | 結果 |
|---|---|
| desugarDiff | golden 955＋random 72,778＝73,733 定義が一致。不一致・定義の対象外・除外は 0。プログラムは golden matched 346・既存の検査エラーによる除外 381、random matched 1,000 |
| builtinCheck | 1,346 プログラム、72,316 比較。不一致・非収束 0 |
| coverageDiff | 境界 20＋random 10,000＝10,020 件が一致。不一致・燃料切れ 0 |
| coverageProgramDiff | match 16,405＋binding 6,033＝22,438 件が一致。不一致・対象外・燃料切れ 0 |
| surfaceCheck | 全 1,727 入力を単独の入口から照合し、個別の型検査と分類理由を維持 |
| surfaceCheckAll | matched 51,636・outOfScope 19・q11 1。不一致・準備失敗・lazyRestriction は 0 |

`check_named.py` は幅付き 3 入力・30 定義、通常の全入力・定義・網羅性項目を固定 manifest と照合した。契約の改変 3 件、hole/pipe の改変 6 件、named export の改変 6 件を意図した理由で拒否した。Rust の通常出力は 8/2/2 のままであり、9/3/3 の独立入力は同じ六入口へ渡して検査している。

## 計画との差と申し送り

交換欄の配置と、型表を受け取らない脱糖の入口の検証を R30 の推す案で補った。新版の固定入力を型枠としていた Rust の補助書き出し二つも、厳密な版の検査で失敗したため、R31 の推す案で依存を外した。既存の CLI の引数は保ち、Rust の所属パッケージの解決を Lean で再実装していない。型表を使う入口では全宣言の四欄と順序を照合する。入力が持つ属性や view と原ソースの対応は書き出し側の責務であり、ここで保証するのは交換情報の整合と、その情報に対する正式モデルの検査である。

D3 では型付け規則・定理・証明を変えていない。D4 で定義・言明と公理依存の所定のレビューを行う。先行作業の自己確認を外部レビューや設計者の合意とは扱わない。D6b は補助書き出し二つの明示した corpus の版も更新する。この記録と `formal/tests/extensible-exchange/README.md` の欄配置に従い、Rust の全出力・manifest・版の照合を 9/3/3 へ揃える。D3 ではそれを先取りしていない。

`scripts/check.sh` と gc-stress の構成は、依頼どおりオーケストレータが最後に実行する。コミットと `docs/todo/` の変更は行っていない。
