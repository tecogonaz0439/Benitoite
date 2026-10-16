# D8 入れ子・束縛・到達可能性の検査

## 目的と test-audit の作成時の関門

1. 主となる境界は実際の読み込み・名前解決を通した型検査の出力、CLI の実行結果、Lean と照合する独立した網羅性入力である。実際の属性と所属から得た view が、別名型・Result/Option・リスト・record の欄・lambda/lazy の内側・bind にも適用されることを守る。
2. 別名の展開後や内側の文脈で view を落とす、既知の Other を包括的とみなす、guard や選択肢の重複の扱いを変える、生成した getter/update にソース用の判定を適用する退行で失敗する。全既知構成子の後の変数分岐を含む golden は、判定の木で実行時の候補がなくなる分岐と、その周囲の生存性・VM/参照インタプリタの接続も検査する。
3. D6a の公開の判定 API のテストは、型表を直接構築しているため、属性・import・所属・別名展開との接続を守れない。型検査の既存のテストモジュールに、同じソースを同パッケージと依存の双方で検査する表を追加する。CLI の実行はこれと異なる下流の契約を守る。予算打ち切りは既存の主となる検査を維持し、重ねたテストを加えない。
4. 本番コードの公開範囲・引数・テスト専用の差し込み口は増やさない。既存の assert・期待値・ignore は維持する。

## 追加した検査と既存の主となる検査

型検査の表は 23 行を同パッケージと外部の双方で実行する。型表を書き換えず、ソースの属性、依存の package.bnt、実際の import から判定する。E0601/E0607 は反例の文字列・主位置・宣言の副位置と文言・help 全体を厳密に比較する。

| 対象 | 同パッケージ | 外部 |
|---|---|---|
| Kind と別名 Alias の既知構成子の全列挙 | 受理 | E0601 |
| 全既知構成子の後の `case other` | E0602 | 受理 |
| Result.Error・Option.Some・リスト要素・Envelope の欄の既知構成子の全列挙 | 受理 | E0601。入れ子の反例と Kind の宣言を指す |
| Result.Error の中身を変数に束縛 | 受理 | 受理 |
| Detail の既知の record 形と `..` | 受理 | E0601 |
| 全既知構成子の後のガード付き変数 | E0602 | E0601。ガード付き分岐を網羅に数えない |
| 同じ分岐の全既知構成子の後の `_` | E0608 | 受理 |
| `_` の後の変数分岐、同じ分岐の `_` の後の既知構成子 | E0602 / E0608 | 同じ E0602 / E0608 |
| Single.Only・Detail・Container 内の Single.Only を分解する bind | 受理 | E0607 |
| 変数・`_` の bind | 受理 | 受理 |
| lambda・lazy の内側の全列挙 | 受理 | E0601 |
| Detail の更新と getter | 受理 | 受理 |
| 構成子の引数不足・対象と異なる型のパターン | E0412 / E0401 | 同じ E0412 / E0401。網羅性の診断で元の誤りを隠さない |

新しい実行用の package golden は、作者側の全列挙と単一構成子の bind、外部からの全列挙に変数を続ける match、別名・Result/Option・リスト・record の欄・guard・lambda の捕捉、外部 record の構築・更新・getter を一つのプログラムで検査する。Direct/Request の両方式と VM/参照インタプリタの差分を通す。期待する十行の数値は手で定め、既知の値の分岐が将来の形のための分岐に入らないことと、偽の guard の後に変数分岐が実行されることを確認する。

coverage_export の既存の view 付き独立入力の表に、単一構成子の bind、入れ子の record の欄、全既知構成子の後のガード付き包括的分岐、選択肢の本物の重複、Option とリスト内の包括的分岐を加える。従来の 16 件を維持して 12 件を足し、28 件の境界入力と既存の乱択 10,000 件を Lean へ渡す。予算打ち切りと部分的な結果を返さない契約は、既存の patterns と pattern_ext の主となる検査をそのまま実行して確認する。

## 変更したファイルと計画との差

変更した Rust は、`src/typeck/pattern_ext.rs` のテストと `tests/coverage_export.rs` だけである。新しい package golden は `testdata/packages/d8-extensible-run` と三つの期待値に置き、依存の宣言を `d8-extensible.files/dep/` に置いた。形式化の入力一覧の `tests/desugar_export/{routing,exchange}-manifest.json`、本記録、decisions.md の R42 も更新した。

本番の判定・型・公開シグネチャ・診断・Lean の規則と証明・交換形式の版は変えていない。計画の予定ファイルへの補足は R42 の二つの manifest である。新しい一件は 8 定義（対象内 6・生成した getter 2）、match 7 件・bind 1 件として登録した。既存の manifest の各入力は、HEAD の JSON との比較で一件も変更していないことを確認した。総数の増加もこの一件分に限る。

初回の追加入力の実行では、テストの依存設定に package ブロックがなく E0917、golden に名前付きと位置による引数の混在があり E0450 になった。依存の設定を既存の package 形式へ揃え、呼び出しをすべて名前付きへ揃えた。診断の副位置を探すテスト側の条件も data と record の両方へ揃えた。これらは新しい入力の準備の修正であり、本番コードの不具合の修正はなかった。既存のテストの assert・期待値・ignore は変更していない。

## 検査の結果

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test golden --test coverage_export --test desugar_export --test random_programs` | 成功。lib 1,161 件、coverage_export 1 件、desugar_export 16 件、golden 2 件、random_programs 3 件。既存の ignore は lib 21 件と形式化用の二件。lib は 72.19 秒、golden は 57.41 秒、random_programs は 49.98 秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |

Rust の検査のログは `/private/tmp/d8-rust-tests.log`、Clippy のログは `/private/tmp/d8-clippy.log` である。新しい golden を絞った検査では、Direct/Request、VM/参照インタプリタの一件の差分、整形の一件がすべて成功した。テストの lib 全体には既存の typeck の主となる検査も含まれる。

形式化は `BENITOITE_DESUGAR_DIFF_DIR=target/desugar-diff/d8-final BENITOITE_COVERAGE_DIFF_DIR=target/coverage-diff/d8-final bash scripts/check-formal.sh` で検査した。ログは `/private/tmp/d8-formal.log`、全交換入力と報告は指定した二つのディレクトリに保持する。

| 形式化の検査 | 結果 |
|---|---|
| `lake build`（formal/。check-formal 内） | 成功。Lean の変更はなく、新しい axiom・sorry・admit・native_decide はない |
| Rust の形式化用の書き出し | coverage_export 二件、desugar_export 17 件が成功。後者は 555.20 秒 |
| `coverageDiff` | 通常 10,020 件、view 付き 10,028 件が一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 349 入力・968 定義、乱択 1,000 入力・72,778 定義が一致。静的な誤りの 386 入力は既存の分類を維持 |
| `builtinCheck` | 72,468 比較が一致。不一致・非収束 0。既存の対象外の一覧を維持 |
| `coverageProgramDiff` | 1,349 入力、match 16,416 件・bind 6,036 件、計 22,452 件が一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 一致 51,645 件。既存の対象外 19 件と Q11 一件を維持。不一致・準備の失敗 0 |
| 交換形式の独立した正負の検査 | width 四件・named 12 件・extensible 22 件が成功 |
| `surfaceCheck` と最終の六入口の照合 | 全 1,735 入力・73,746 定義・22,452 網羅性入力の識別子と件数が manifest と一致。対象範囲・診断の分類も一致 |
| 破損入力の拒否 | 既存の契約三件・hole/pipe 六件・交換形式六件を意図した理由で拒否。標準型の view の欠落と定数の所属の検査も成功 |

check-formal.sh は終了状態 0 で完了した。最終の入力別照合は 189 秒であった。本番の Rust は変更 0 行、Rust のテストは +359/-1 行である（削除一行は、独立入力の属性を付ける型の一覧を拡張した置換）。既存の assert の削除はない。

## 後の作業への申し送り

D8 の残件はない。D9 で D の文書と全ターゲット・段末の検査を行う。本作業では依頼に従い scripts/check.sh（dry-run を含む）と gc-stress の構成の検査を実行していない。コミットと docs/todo の変更も行っていない。
