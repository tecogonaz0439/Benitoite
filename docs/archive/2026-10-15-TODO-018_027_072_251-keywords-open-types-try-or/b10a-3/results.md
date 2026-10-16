# B10a-3 実装結果

## 目的と変更

本番の die の受理を有効にせず、型付きの処置を corpus 10 へ書き出す。型表・網羅性は3を維持する。

- `tests/desugar_export/exchange.rs`: 裸の try・明示 return・Die を別のタグに写す。Die は成功型、構成子、確定済みの辞書、標準束縛のメソッドと exit、入力、任意の説明を保持する。説明なしは null とする。入力の後に説明を辿る。組み込みの終了エフェクトは Lean と同じ `Process.Exit` に写し、表層・コア・型と操作の表を揃える。コアでは報告の付加情報だけを投影で除き、説明・表示の let と exit の公開の引数を保持する。
- `tests/desugar_export.rs` と `named.rs`: 通常の全出力・短い入力を corpus 10 に揃える。`check_named.py` の width の版・最終の出力文と、exchange/routing manifest も揃える。分類・件数・対象外理由は維持する。`coverage_export.rs` は既に網羅性3だけを出力しており、変更は不要である。
- `src/lib.rs` と `tests/desugar_export/lib.rs`: cfg(test) だけで実際の交換器を共有する。既存の解析・型検査・脱糖・独立した IR check を使い、Result/Option の Die、裸／明示 return の計9例を、独立入力の型付き表層の処置・ヘッダ・辞書と期待コアに照合する。標準のクラス・メソッドは解決済みの BindingId、exit は組み込みの表に照合する。入力と説明のラムダの効果を両方出力する別の入力も置く。末尾 return 自身の注釈は従来の Unit であり、独立入力の任意の末尾注釈とは比較しない。
- `formal/tests/try-exchange/`: 引数名だけをソースの小文字名へ合わせる。既存の11定義・期待コア・正負の検査は維持する。01-12・07-04 は現在の接続範囲と内部報告の投影を記す。

## test-audit の作成時の関門

1. 交換器の出力を主な境界とし、Return/Die の区別、辞書と標準参照、説明の保持、期待コアへの投影、入力と説明のラムダの走査を守る。
2. Die を Return として出す、説明を落とす、局所名で標準参照を選ぶ、入力と説明の走査順を変える、内部報告付き App を unsupported にする退行を捕まえる。
3. 本番 parser が Die を拒否する間、通常の統合入力はこの分岐へ達しない。B4 の手書き JSON だけでは Rust の出力を検査できず、B10a-2 の IR の比較だけでは交換時の欠落を捕まえない。同じ期待コアを共有し、既存の Return と Die の正負の検査は減らさない。実装前に `typed_try_exchange_matches_independent_corpus_ten` が暫定拒否 `die exchange output is not connected` で失敗することを確認した（`/tmp/b10a3-first.log`）。
4. 既存の cfg(test) の parser と型・脱糖の入口を使う。本番の API・フラグ・CLI オプションは追加しない。交換器の複製や処理系の段の置き換えも行わない。

## 検査

最初の Rust の一式は lib 1,191件・coverage_export 1件・desugar_export 16件・golden 2件・spec_examples 7件が成功した。その後、比較内の効果名の付け替えを外すと二つの交換テストが失敗することを確認し（`/tmp/b10a3-effect-before.log`）、R69 の交換器の修正を行った。最終ツリーの再検査の結果を以下に記録する。

| 最終ツリーの検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test desugar_export --test coverage_export --test golden --test spec_examples` | 成功。lib 1,191件（既存の長い21件は既定で未実行）、coverage_export 1件、desugar_export 16件、golden 2件、spec_examples 7件。lib 158.99秒、golden 99.32秒 |
| `cargo clippy --workspace --all-targets` | 成功。10.12秒 |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |
| `bash scripts/check-formal.sh` | 最後まで成功。lake build と六つの実行ファイルのビルド、独立入力46件、通常の全出力、破損入力の拒否と最終 manifest の照合が成功 |

通常の desugar_export と coverage_export が既定で実行しない全コーパスの検査は、check-formal.sh の `--include-ignored` で実行する。scripts/check.sh（dry-run を含む）と gc-stress の構成は依頼に従って実行しない。


形式化の出力は `target/desugar-diff/b10a3-final-20261016/` と `target/coverage-diff/b10a3-final-20261016/` に置いた。全コーパスの書き出しは785.203秒、最後の個別照合は207秒だった。include-ignored の desugar_export は17件、coverage_export は2件が成功した。独立した width 4件・named 12件・extensible 22件・try 8件、計46件も成功した。

| 六入口 | 結果 |
|---|---|
| coverageDiff | 通常10,020件・view付き10,028件が一致。不一致・fuelExhausted 0 |
| desugarDiff | golden 349入力・random 1,000入力が一致。全1,736入力中、対象1,349入力・既存の検査エラー387入力・範囲外0入力を維持 |
| builtinCheck | 対象1,349入力、summary 比較72,468件。不一致・非収束0 |
| coverageProgramDiff | match 16,417件・bind 6,036件、計22,453件が一致。不一致・範囲外・fuelExhausted 0 |
| surfaceCheckAll | 51,645件一致。不一致・準備失敗・lazyRestriction 0。既存の対象外19件・q11 1件を維持 |
| surfaceCheck と最終 manifest | 全1,736入力・73,746定義・22,453 coverage entries の対応が一致。corpus 10・型表3・網羅性3と六入口の件数・分類が一致 |

契約の破損3件、hole/pipe の破損6件、名前付きの破損6件を意図した理由で拒否した。独立した Die の必須欄・版・辞書・メソッド・exit・説明の破損も既存の Python の検査で拒否した。対象内の件数・対象外理由を下方修正していない。Lean の定義・証明は変更せず、lake build が成功し、新しい sorry・axiom・admit・native_decide はない。

ログは `/private/tmp/b10a3-rust-tests-final.log`・`b10a3-clippy.log`・`b10a3-formal.log` に置いた。シェルからの全1,736件の routing の比較でも、version 9→10 以外に差がないことを確認した。本番コードは cfg(test) の交換器共有の宣言7行だけを追加し、実行時の経路は変更していない。テストの交換器・準備と入力・検査の期待値を更新し、既存のテストと assert は削除していない。

## 計画との差と申し送り

R67（独立入力の引数名と交換器の共有）・R68（routing の版と内部報告の投影）・R69（終了エフェクトの交換名）を decisions.md に記録した。診断のコード・文言・位置・終了状態は変更していない。テストの既存の assert・時間制限・分類は維持し、Lean の規則・証明も変更していない。

本番の die の受理と、通常のソース読み込みから Rust の出力・Lean の六入口までの一貫した比較は B11 に残す。R64/R66 の乱択差分の既知の時間制限の未達は、この枝では再実行・変更していない。B10 の親の完了確認・測定、B10a/G5 の親の完了と G5b の所定レビューは、この枝の自己確認で完了扱いにはしない。コミットと docs/todo の変更は行っていない。
