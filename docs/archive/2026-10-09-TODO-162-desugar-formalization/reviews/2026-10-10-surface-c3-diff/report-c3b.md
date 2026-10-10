C3b の実装を完了しました。**`scripts/check-formal.sh` は終了状態 0、不一致 0 で成功しました。** `lake build`、公理の確認、fmt、Clippy も完了しています。共通検査は、C3a と同じ HTTP テストのソケットの bind が実行環境に拒否されて停止しました。コミットはしていません。

## 1. 変えたファイル・作ったファイルと行数

行数は変更後のファイル全体です。追加・削除は HEAD との差分です。

| ファイル | 行数 | 追加 | 削除 |
|---|---:|---:|---:|
| [Surface/Syntax.lean](formal/Benitoite/Surface/Syntax.lean) | 223 | 3 | 0 |
| [Surface/Typing.lean](formal/Benitoite/Surface/Typing.lean) | 300 | 4 | 1 |
| [Surface/WellFormed.lean](formal/Benitoite/Surface/WellFormed.lean) | 77 | 1 | 1 |
| [Surface/Desugar.lean](formal/Benitoite/Surface/Desugar.lean) | 201 | 3 | 1 |
| [Surface/Examples.lean](formal/Benitoite/Surface/Examples.lean) | 495 | 10 | 0 |
| [Surface/Lemmas/Invariants.lean](formal/Benitoite/Surface/Lemmas/Invariants.lean) | 217 | 1 | 0 |
| [Surface/Lemmas/Scoped.lean](formal/Benitoite/Surface/Lemmas/Scoped.lean) | 166 | 1 | 0 |
| [Surface/Lemmas/Typing.lean](formal/Benitoite/Surface/Lemmas/Typing.lean) | 348 | 1 | 0 |
| [Exchange/Syntax.lean](formal/Benitoite/Exchange/Syntax.lean) | 354 | 5 | 0 |
| [Exchange/Convert.lean](formal/Benitoite/Exchange/Convert.lean) | 260 | 2 | 0 |
| [tests/desugar_export/exchange.rs](crates/benitoite/tests/desugar_export/exchange.rs) | 937 | 6 | 0 |
| [c3-diff-results.md](docs/2026-10-09-TODO-162-desugar-formalization/c3-diff-results.md) | 229 | 63 | 0 |
| **合計** | | **100** | **3** |

新規のソースファイルはありません。公理確認用の一時ファイル `formal/AxiomsC3b.lean` は作成し、確認後に削除しました。

## 2. 足した要素と規則、Rust の書き出しの直し

表層の構文に **`Surface.Expr.negFloat (x : Float)`** を加えました。括弧を挟まず Float リテラルへ単項の `-` を適用した式を表し、`x` は符号反転前の値です。

| 項目 | 加えた規則 |
|---|---|
| 型付け | `E_NegFloat`。型は `Float`、エフェクトは `Eff.empty` |
| 番号の範囲条件 | `True` |
| `Exits` | `False` |
| 脱糖 | `.ret (.const (.float (-x)))` |

型の不変条件、脱糖の範囲保存、脱糖の型保存の各証明に `E_NegFloat` の場合を加えました。**二つの定理の言明、`Benitoite.Release` の定義と証明、組み込みの関数の仮定は変更していません。**

`Examples.lean` には `-1.25` と `-0.0` の脱糖の例を加え、どちらも `rfl` で証明しました。さらに、`#guard` で `-0.0` の脱糖結果のビットが **`0x8000000000000000`** になることを確認しています。

交換形式には `negFloat(bits)` を加えました。Rust の書き出しは、直接の負号の式の ID に型検査が記録した **符号込みの `lit_values` の Float 値**を使い、そのビットを十進の文字列として出力します。Lean への変換では `floatFromBits` による往復検査の後に符号を戻して表層の `negFloat` を作り、脱糖で符号を反転します。コアを比較する正規化は追加していません。

整数の `-n` の扱いは維持しています。括弧を挟む `-(1.0)` と一般の式への負号は既存の `neg` の呼び出しを使い、Decimal は C6 の範囲のままです。Rust の本番の型検査・脱糖は変更していません。

## 3. `scripts/check-formal.sh` の最終の出力（数と内訳）と時間

実行したコマンドは次のとおりです。

```sh
BENITOITE_DESUGAR_DIFF_DIR="$PWD/target/desugar-diff/c3b" /bin/bash scripts/check-formal.sh
```

最終の集計は以下です。**終了状態 0、不一致 0** です。

| 入力 | 単位 | 一致 | 不一致 | 対象外 | 除外（検査の誤り） |
|---|---|---:|---:|---:|---:|
| ゴールデン | プログラム | 154 | 0 | 104 | 265 |
| ゴールデン | 関数 | 320 | 0 | 135 | 0※ |
| 無作為 | プログラム | 1,000 | 0 | 0 | 0 |
| 無作為 | 関数 | 2,621 | 0 | 0 | 0 |

※ 検査で除外した入力からは型検査済みの定義を取得していないため、関数単位の除外は計数していません。

Rust の書き出しの出力は次のとおりです。

```text
desugar export: 1185 exported, 73 out of scope, 265 excluded (check error); 1523 inputs; 36.906s
test export_desugar_corpus ... ok
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 37.14s
```

対象外の内訳は C3a と同じです。複数の要素を含む関数・プログラムがあるため、行の合計は対象外の総数とは一致しません。無作為入力の内訳はすべて 0 です。

| 要素 | ゴールデンの関数数 | ゴールデンのプログラム数 |
|---|---:|---:|
| field | 22 | 17 |
| interpolation | 22 | 22 |
| try | 52 | 44 |
| record | 21 | 18 |
| handler | 22 | 20 |
| resume | 17 | 16 |
| user operation | 13 | 13 |
| with | 27 | 24 |
| lazy | 5 | 5 |
| constant reference | 8 | 7 |
| alternative | 4 | 4 |
| list pattern | 7 | 7 |
| guard | 5 | 5 |
| range pattern | 3 | 3 |
| Rigid | 2 | 2 |
| typeclass method | 29 | 26 |
| record pattern | 4 | 4 |
| spread | 2 | 2 |
| class_constraints | 10 | 5 |
| TypeArg.Head | 4 | 3 |
| App | 1 | 1 |
| Decimal literal | 1 | 1 |

C3a の不一致 6 プログラムのうち、5 件は一致になりました。残る `testdata/test/values.bnt` は、修正対象の `standard` 関数が一致した一方、別の `records` 関数が対象外なので、プログラム単位では対象外になりました。このため、一致プログラムは 149 → 154、対象外は 103 → 104 です。対象外の関数数は 135 のままです。

| 段 | 時間 |
|---|---:|
| `lake build` | 7 秒 |
| `lake build desugarDiff` | 3 秒 |
| Rust の書き出し（cargo を含む） | 38 秒 |
| Lean の比較 | 1 秒 |
| **段の時間の合計** | **49 秒** |

時間はスクリプトの `$SECONDS` による秒単位の測定です。結果と全出力は以下に保存しています。

- [corpus.json](target/desugar-diff/c3b/corpus.json)
- [report.json](target/desugar-diff/c3b/report.json) — `mismatches` は空
- [check-formal-c3b.log](target/desugar-diff/check-formal-c3b.log)

## 4. 新しく見つかった不一致と、その分類と直し方

**なし。**

C3a で **(b) Lean の定義の誤り（対応漏れ）**と分類した 6 関数・16 箇所は、`negFloat` の構文・規則・交換形式を加えてすべて解消しました。

最終検査では、(a) Rust の脱糖の誤り、(b) Lean の定義の誤り、(c) 正規化の不足は、いずれも 0 件です。既存の差分検査が修正前の不一致を検出済みであり、同じ入力で修正後の一致を確認できたため、Rust の退行テストは重ねて追加していません。

## 5. `#print axioms` の出力と、検査の結果

`formal/README.md` の手順にある 11 定理について確認しました。

```text
'Benitoite.Core.progress' depends on axioms: [propext, Quot.sound]
'Benitoite.Core.preservation' depends on axioms: [propext, Quot.sound]
'Benitoite.Core.effect_soundness' depends on axioms: [propext, Quot.sound]
'Benitoite.Core.step_sound' depends on axioms: [propext, Quot.sound]
'Benitoite.Core.step_complete' depends on axioms: [propext, Quot.sound]
'Benitoite.Release.progress' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Release.preservation' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Release.effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Release.step_sound' depends on axioms: [propext, Quot.sound]
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

二つの Surface の定理に現れる公理は、指定された三つだけです。`sorryAx` や新しい公理はありません。

| 検査 | 結果 |
|---|---|
| `lake build` | 成功、63 jobs、`sorry` の警告なし |
| `lake build desugarDiff` | 成功、16 jobs |
| `cargo fmt --check` | 成功 |
| `cargo clippy -p benitoite --all-targets` | 成功 |
| `scripts/check.sh --base HEAD --dry-run` | `rust`・`formal` を選択 |
| `scripts/check.sh --base HEAD` | fmt・Clippy 成功後、HTTP テストの bind 拒否で停止 |
| `scripts/check.sh --base HEAD --only formal` | 成功 |
| `git diff --check` | 成功 |

共通検査で失敗したのは、`runtime::io::http::tests::stopping_an_exchange_with_a_pending_or_dispatched_release_closes_without_waiting` です。[runtime/io/http/tests.rs:298](crates/benitoite/src/runtime/io/http/tests.rs:298) の `TcpListener::bind(("127.0.0.1", 0))` が `PermissionDenied: Operation not permitted` を返しました。ライブラリテストの結果は **789 成功・1 失敗・16 ignored、39.01 秒**です。

この失敗で共通検査が停止したため、後続の GC 強制テスト、仮置きの許可、Skill の生成物の検査には到達していません。ユーザー指定に従い、ソケットの bind を許す別の環境での共通検査をオーケストレータに引き継ぎます。全出力は [check-c3b.log](target/desugar-diff/check-c3b.log) に保存しました。