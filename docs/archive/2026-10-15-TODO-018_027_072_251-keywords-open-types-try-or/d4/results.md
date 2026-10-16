# D4 D の定義・言明と公理依存の確認

## 目的と変更

D1〜D3 の形式化の契約を、Rust の意味変更の前にレビューできる形へまとめた。開始時の HEAD は `c6d484392b712b86c0d1efda889046a7f7f70caa`、作業ツリーは clean だった。AGENTS.md、作業 D4 と共通の関門 K、design.md「形式化と受け渡し」、decisions.md の関係する Q/R、07-04 の前提とレビュー規約を読んだ。

| ファイル | 変更 |
|---|---|
| `d4/contracts.md`（新設） | view の受け渡し、ソース/合成照合、将来の形、変更前の前提と結論、六入口の信頼範囲の対応表と自己確認 |
| `d4/audit_axioms.py`・`axioms-summary.json`（新設） | 変更した 35 モジュールの全宣言の公理依存を採取する道具と実測。通常の検査からは参照しない |
| `d4/theorems.lean`・`theorems-axioms.txt`（新設） | 代表 40 件の直接の `#print axioms` と結果。変更していない Core/Release の最終定理も含む |
| `reviews/G2-request.md`（新設） | 所定のレビューに渡す差分、観点、自己確認の結果と、外部レビュー・設計者の合意が未了であること |
| `p2/formal.md`・`decisions.md`・この記録 | D4 の現在の対応と公理依存、R32、検査と申し送り |
| `docs/design/01-spec/01-12-core-calculus.md` | 型保存の定理の外形と、表層の型付けの前提が強まることを区別する説明へ補正 |

自己確認では、修正を要する Lean の定義・言明の不一致は見つからなかった。将来の形は判定と反例だけに加わり、現在の `Val`・`Inhabits`・コアの型付けと遷移は変わっていない。record のソース照合の条件と、getter・更新・try の合成照合を区別し、本体とその内側で同じ view を渡すことを確認した。

01-12 の「前提と結論は変わらない」という説明は、定理のシグネチャの外形が同じであることと、`p.WellTyped` の意味に `ViewExhaustive` が加わることを分ける説明へ直した。型付けの規則・定理・証明は変更していない。Rust 本体、Rust/Lean/Python の既存テスト、固定入力、manifest、診断の差分はない。

## test-audit の関門と検査の分担

`test-audit` の関門に従い、既存の検査の持ち主と今回の確認を分けた。新しい処理系のテストは加えていない。

1. 守る契約は、任意の view による受理から現在の値の網羅性・型保存を導くこと、交換境界で指定を失わないこと、公理依存を増やさないことである。前二つの主となる境界は既存の Lean 定理と六つの公開の交換 CLI である。
2. 現実的な退行は、view の渡し忘れ、合成照合への外部の制限の混入、future の実行時への追加、未知の view や旧版の新情報の黙認、証明の省略や追加公理である。前提・結論と写しの比較、公理依存の採取、既存の正負の独立入力と全件比較で確認する。
3. 動作の契約は D1〜D3 の既存の検査を再利用する。今回追加した道具は、通常の検査や同じ動作のテストを増やすものではなく、レビューで必要な公理依存の記録を採取するために使う。
4. 本番の API・フラグ・差し込み口は加えていない。改造ディレクトリを通常のビルド・検査から参照しない。既存の assert・期待値・ignore・時間制限・対象外理由は変更していない。

## 公理依存の結果と再現

D 前の `dc2c15a1` から D3 の `c6d48439` までに変わった 35 モジュールの、private と自動生成されたものも含む 7,003 宣言を Lean の環境から採取した。使う公理は `propext`・`Quot.sound`・`Classical.choice` の範囲だけで、追加の公理と `sorryAx` は 0。代表 40 件と Core/Release の最終定理にも追加公理はない。詳細と前提の意味の差は [対応表](contracts.md) に記す。

再現は先に `formal/` で `lake build` を通し、リポジトリの根で次を実行する。

```sh
python3 -B docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/d4/audit_axioms.py
```

完全な宣言ごとの結果と import ごとのログは `target/d4-review/axioms.json`・`axioms-*.log`、集計は `axioms-summary.json` に出る。`formal/` で次を実行すれば代表宣言を直接照会できる。

```sh
lake env lean ../docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/d4/theorems.lean
```

この道具は現在の `#print axioms` と同じ依存収集関数を呼ぶ。公理集合だけでは、定理の引数に置かれた組み込み動作の仮定や、表層の受理条件の意味の変化は確認できないため、対応表ではこれらを別に比較した。

## 検査

検査内容と形式化の目安約 9〜10 分を実行前に報告した。指定に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成は実行していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,156 passed、0 failed、既存の ignored 21。73.40 秒 |
| `cargo test -p benitoite --test spec_examples --test skill_docs` | 01-12 の最終の補正後に成功。spec_examples 7 件、skill_docs 8 件 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `formal/` で `lake build` | 成功。161 jobs、sorry の警告なし |
| `python3 -B …/d4/audit_axioms.py` | 成功。35 モジュール、7,003 宣言、追加の公理 0 |
| `formal/` で `lake env lean …/d4/theorems.lean` | 40 件全て成功。Core は `propext`・`Quot.sound`、Release/Surface と交換処理は標準公理三つの範囲 |
| `bash scripts/check-formal.sh` | 全工程成功、終了状態 0。Rust の coverage_export 2 件・desugar_export 15 件、独立入力の width 4 件・named 12 件・extensible 14 件、六入口の全件比較と manifest の照合が成功。全体は約 14 分で、実行前の目安約 9〜10 分を超えた |
| 既存の拡張可能な型の独立検査のサブケースの計数 | 14 件成功、130 回の CLI 呼び出し。正常 20 回、意図した拒否 110 回。既存の検査を変更せず、返された終了状態を記録して計数した |
| `git diff --check`、新規ファイルの空白、新しい文書の相対リンク・集計・Python の構文 | 成功 |

### 通常入力の六入口の件数と分類

出力は `target/desugar-diff/run-65942/` と `target/coverage-diff/run-65942/`、検査全体のログは `target/d4-review/check-formal.log` にある。D3 の結果と同じ件数・分類を維持した。

| 入口 | 結果 |
|---|---|
| desugarDiff | golden 955＋random 72,778＝73,733 定義が一致。不一致・定義の対象外・除外 0。プログラムは golden matched 346・既存の検査エラーによる除外 381、random matched 1,000 |
| builtinCheck | 1,346 プログラム、72,316 比較。不一致・非収束 0 |
| coverageDiff | 境界 20＋random 10,000＝10,020 件が一致。不一致・燃料切れ 0 |
| coverageProgramDiff | match 16,405＋binding 6,033＝22,438 件が一致。不一致・対象外・燃料切れ 0 |
| surfaceCheck | 全 1,727 入力を単独入口で照合。既存の失敗理由・scope・対象内件数が manifest と一致 |
| surfaceCheckAll | matched 51,636・outOfScope 19・q11 1。不一致・準備失敗・lazyRestriction 0 |

表層の既存の対象外 19 件は `Task.await` と `TaskGroup.spawn` の両方が 12 件、spawn だけが 6 件、await だけが 1 件である。q11 は既存の Unit の末尾照合の扱いの差一件であり、結果全体と分類理由が manifest と一致した。除外 381 件は既存の検査エラーであり、今回の指定付き型を除外へ移したものではない。

最後の `check_named.py` は入力 1,727・定義 73,733・網羅性項目 22,438 と、幅付き 3 入力・30 定義を照合した。契約の改変 3 件、hole/pipe の改変 6 件、named export の改変 6 件を意図した理由で拒否し、通常出力の 8/2/2 が六入口で一致した。

### 新版の独立入力の六入口での観測

既存の `formal/tests/test_extensible_exchange.py` の 14 件をそのまま実行し、各呼び出しの終了状態を記録した。0 は正常、1 は型の規則または独立した期待との不一致による拒否、2 は不正な交換入力の拒否である。各拒否は元のテストが理由の文字列や反例まで確認しており、終了状態だけの検査へ置き換えていない。

| 入口 | 正常 0 | 意図した拒否 1 | 不正な交換入力 2 |
|---|---:|---:|---:|
| desugarDiff | 3 | 0 | 11 |
| builtinCheck | 2 | 0 | 18 |
| coverageDiff | 7 | 0 | 12 |
| coverageProgramDiff | 2 | 2 | 14 |
| surfaceCheck | 3 | 8 | 20 |
| surfaceCheckAll | 3 | 5 | 20 |

新版の必須欄、作者/外部、record・入れ子・束縛・メソッド、属性だけの宣言、未知/閉じた型/重複の view、旧版への空・false の新欄の混入、版の組の不一致、型表の食い違いを含む。結果と計数は `target/d4-review/extensible-attempts.{log,json}` に残す。処理系のテストの追加・変更はない。

## 計画との差と申し送り

R32 の推す案に従い、所定のレビューへ渡す資料と自己確認を揃え、G2 は未完了とした。07-04 の担当は Claude Code（Opus 5.5）であり、外部の LLM の起動権限を推測していない。D5 以降でこの形式化の契約を使う前に、オーケストレータがレビューの回答と設計者の合意を記録する必要がある。自己確認と検査の成功は、その代わりにはしない。

Rust の現在の通常出力は 8/2/2、新版の独立入力は 9/3/3 である。D5 は型表とパッケージの比較の共通化から進め、属性の受理と通常出力の切り替えは D6 の担当とする。D3 の R31 で版を明示した補助書き出し二つも D6b で更新する。

`scripts/check.sh` と gc-stress の構成は、依頼どおりオーケストレータが最後に実行する。コミットと `docs/todo/` の変更は行っていない。
