# RV-A12: A08〜A12（短絡・match/guard・独立入力と別本体・予算の一致・非実行報告）の独立レビュー

2026-10-25。レビューの担当は Opus 5.5 のサブエージェント（取りまとめが依頼）。対象はコミット `c963ea19` を取り出した別の作業ディレクトリで、ソースは変えていない。再現の一時ファイルは `<tmp>` に置いた。【再現】は実際に動かして確かめた所見、【読解】は読んだだけの所見である。

## 結論

条件付きで受け入れる。健全性を壊す誤り（偽の警告、通常の受理の変化、内部の不具合）は、読んだ範囲でも試した範囲でも見つからなかった。Rust と Lean の計上も、試した 12 本のプログラムで完全に一致した。ただし、A08・A09 で加えた環境の経路は Lean から作った固定表に入っていないので、任意の上限での停止位置と分類が Lean と一致することは確かめられていない（中1）。

## 中

### 中1. 固定表が A08・A09 の環境の経路を覆っていない【読解＋一部再現】

- 場所: `a11/budget-reference.lean` 24〜58 行（`cases`）と 110 行〜（`wholeCases`）。生成した表は `testdata/interval-budget/body.tsv`・`whole.tsv`・`summary.tsv`、比較するテストは `interval/tests/budget_reference.rs`。
- 問題: 本体の 24 形のうち比較を含むのは、`short`（リテラル false の and）、`branches`（真偽の引数の if）、`match`（整数リテラル・wild・`guard false`）だけである。次の経路は、任意の上限での停止位置・分類・保存済み接頭辞を Lean の実行値と一度も比べていない。
  - 局所と定数の比較による絞り込み（`Environment::narrow`）。
  - `and` の偽・`or` の真の二環境の合流（`flow.rs` の `alternative_conditions` → `Environment::join`。Lean は `BudgetEnvironment.lean` の `condition` → `joinEnvs?`・`hull`）。
  - 条件の中の `not`、`elseIf`。
  - match の変数パターン・選択肢・範囲（`match_arm_env`・`match_select`・`match_template` と、Lean の `arm`・`replicateOnto`・`selectReverse`）。
  - guard の中の比較、定数を使う比較（`constant` の constE の追跡）。
  
  全体の表も lazy・handler・captured の 3 形だけである。
- 再現した範囲: Lean の `BudgetWhole.analyze`（既定の上限、fuel 4096）と実 CLI の `usage` を、全体の操作数・保存数・最大同時保持と警告数で比べ、12 本（or、not、and の範囲、elseIf、match の変数＋guard、選択肢 `1, 5`、or＋and の括弧、範囲＋選択肢 `1..3, 7`、guard の or、定数との比較、ラムダの捕捉、呼び出しの独立入力）がすべて一致した。例: `if x = 0 or x = 1 …` はどちらも 148/18/30。合計値だけの比較で、小さい上限での停止位置は比べていない。
- 修正案: 上の各形を `cases` に加え、同じ選び方（本体は完走する最小の上限の一つ後まで、全体は要約と一致する最小の上限の一つ後まで）で表を作り直す。`whole` と `summary` に、定数を含むモジュールと、無効でない複数のモジュールの形を加える。
- 時期: A13 の前が望ましい（A13 は同じ比較・合流の経路に幅を加える）。遅くとも X02 まで。

## 軽

### 軽2. 短絡の連なりの費用が長さのほぼ三乗で増え、40 項程度で本体の上限を超える【再現。Lean と一致】

Lean の `BudgetEnvironment.condition` の `and false`／`or true` の場合と `BudgetAnalyze.shortCircuit` は、偽の場合に各段で `condition(left, truth)` と `condition(left, !truth)` を両方計算し、短絡の各段は左辺全体を分類し直す。`x = 0 and … and x = 0` は 10 項で 3,155 操作、20 項で 17,535 操作、40 項で本体 10 万操作を超えて停止し W0401 が消える（`or` も同様）。10 項と 20 項の全体の消費は Lean と Rust で完全に一致した。実装の誤りではなく Lean の定義の性質であり、止まった本体は `bodyBudgetExceeded` に数えられる。U01 の棚卸しで長い条件の件数と停止を観察する。改善するなら Lean の駆動の変更になり、設計者の判断が要る。時期: U01（観察）、改善は後でよい。

### 軽3. 固定表の生成元が改造のディレクトリにあり、コメントが作業の ID を引いている【読解】

`interval/tests/budget_reference.rs` 4 行と `body.tsv`・`whole.tsv` の 1 行目が `a11/budget-reference.lean` を引き、`summary.tsv` は生成元（`a12a/summary-reference.lean`）を示さず、再生成器 `a11b/regenerate-reference.py` も改造のディレクトリにある。AGENTS.md「コメントと名前」に反し、改造を `docs/archive/` へ移すと表の作り直しが読み取り専用の保管に依存する。生成元の 2 本と再生成器を表のそば（例: `crates/benitoite/testdata/interval-budget/`）か `formal/` の既定ビルドの外へ移し、コメントと tsv の見出しを設計書の節と道具のパスに改める。時期: X02 まで（遅くとも改造の保管の前）。

### 軽4. スタックの深さのテストの形が、区間解析の深い経路を通らない【再現】

`pipeline.rs` の `stages_fit_the_measured_stack_*`、`examples/stack_probe/support.rs` 106〜127 行、`typeck/pattern_ext.rs` の `deep_expressions_stay_within_the_normal_stack` の形は `if true then`・真偽の照合値の match・真偽の match の入れ子で、区間解析は else 側と腕を番号付けだけで済ませる。一時的なクレートで 16 MiB のスレッドに E0208 の手前の深さを流すと、整数 match の腕の入れ子 330、`not` 980 重、`if x = 0 then` の入れ子 490、比較の else-if 990、`id(…)` の入れ子 990（8 MiB では不足）がすべて通った。測定済みの形に、比較を条件にした if／else-if、整数の照合値の match の腕と照合値、入れ子の呼び出しを加える。時期: A13〜A15 まで（幅の拡張で枠が増える前）。

### 軽5. 利用者の警告の採用順が、契約の文と違う【読解】

`interval/diagnostics.rs` 36〜47 行は親の候補をすべて先に採り、その後で各独立入力の候補を採る。契約表「警告」は「キーの surfacePreorder の昇順、同じキーでは親を先に、続いて independentRev.reverse」と定める。同じ元 NodeId が親と独立入力の両方に現れるのは定数の展開に限られ、今は出力の差は見えないが、X02 は「まとめた後の利用者の警告」を照合する。実装をキーの先行順の併合に合わせるか、契約と 02-05「警告」の文を実装の順に直す。時期: X02 まで。

### 軽6. 環境にない整数の局所参照を Integer の Top として扱い、Lean と違う【読解】

`flow.rs` の `name()` の `None if integer_type(...)`。Lean の `.local` は位置がなければ `baseUnknown`（`onlyInteger` は偽）である。今は全ての束縛が環境に登録されるので通らない見込み。Lean と同じく未知（`unsupported` は立てない）を返すか、対応の欠落として停止にする。時期: X02 まで。

### 軽7. 本体の深さ停止とその他の停止が、どの件数にも現れない【読解】

`interval/summary.rs` 226 行。本体出力が `Depth`・`Unmapped` などで止まると `coverage` は `some` だが四件数と `phaseStops` は 0 のままになる。契約には反しないが、`phaseStops` の行の「depth・other が残りの停止を数える」は本体の停止も含むように読める。06-01 と inspection.md の `phaseStops` の行に「本体出力の停止は含めない」と一文足すか、数えるなら別の欄にする。時期: 後でよい（U02・U03）。

### 軽8. 本番の欄の一部が、テストでしか読まれていない（test-audit）【読解】

`interval/mod.rs` の `phases.discovered`（名前と準備の有無の組）と `phases.pending`（名前の `String`）。本番の集計は準備の有無と件数だけを読み、名前は `whole.tsv` の比較だけが読む。X02 の比較報告で使う予定なら申し送りに明記し、使わないなら真偽と件数にする。時期: 後でよい（X02 の設計で判断）。

## 確かめて問題がなかった観点

- 健全性【再現】: 負のリテラルと範囲のパターン、逆向きの比較、MAX でのあふれと MAX−1 での非警告、`not (x <> 0 or x = 0)` の矛盾、真偽の局所変数による非絞り込み、括弧付きの除数、定数の除数、旧定数警告との重複なし。未到達の枝・return の後・ラムダ／handler の捕捉値に警告は出ず、別本体の警告は D8a どおり。常に失敗する除算の後の除算の警告は Lean の `divModNormal` が Top を返すことと一致。リポジトリの全 1,077 本の `.bnt` に `check --report=json` をかけ、異常終了・終了状態 3・JSON の欠落はなく、成功した報告で `some` なのに件数がすべて 0 の例もない。
- Lean との一致【再現】: 中1・軽2 の 14 本で全体の操作数・保存数・最大同時保持・警告数が一致。計上の写し（`readSlots`・`narrow`・`hull`・`condition`・`branch`・`armList`、独立入力の保存と復帰、`BudgetWhole.modules/definitions/runDefinition/runEntries`、A11b の `finishBody`）を Lean の定義と読み比べた。固定表は Lean の実行値から作り、Rust の計上からは作っていない。
- 報告【再現・読解】: main の報告全体と Target は同じ値。`schemaVersion` 1・2、`complete`、既存の欄は不変。`--deny-warnings` で拒否されても集計は残る。構文の誤り・型の誤りは `none`、検査の誤りで `all` になる例も文書どおり。test は Target の和、doc test は通常の入口と生成例の集約。五つの射影は `BudgetWhole` の各関数と一致。文章の報告は変わらず、警告がないことを安全と表示しない。
- 由来（案 B）【読解】: 最大 8 件、新しい位置を先頭、同じ span の重複を除く、合流の規則が仕様どおりで、予算への計上と判定への使用はない。
- 実装の規約【読解】: 新しい unwrap・expect・添字・panic・`#[allow]`・大域の状態はなく、`as` は定数の拡幅だけ。大きな分岐は `#[inline(never)]`、括弧・文列・腕・選択肢はループ。
- テスト【読解】: 公開の境界の表と内部の報告の比較を分ける理由が書かれ、RV-A07 の軽7 は対応済み。
- 文書【読解】: 06-01・06-04・02-10・06-06・02-05・inspection.md・SKILL.md は実装と一致し、01-12・07-04 の A11b の写しも Lean の差分と一致する。

Lean は `-M 12288` を付け、並べて走らせずに一つずつ実行した。
