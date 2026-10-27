# RV-A07: A01〜A07（区間解析の土台と W0401/W0402 の接続）の独立レビュー

2026-10-25。レビューの担当は Opus 5.5 のサブエージェント（取りまとめが依頼）。対象はコミット `e61a5b09` を取り出した別の作業ディレクトリで、ソースは変えていない。再現の一時ファイルは `<tmp>` に置いた。【再現】は実際に動かして確かめた所見、【読解】は読んだだけの所見である。

## 結論

条件付きで受け入れてよい。健全性を壊す誤り（実行の意味に照らして偽の警告、Integer64 以外の型での警告、通常の受理の変化、拒否、内部の不具合）は、読んだ範囲でも試した範囲でも見つからなかった。一方で、定数の扱いと由来（補助位置）の計上の二点で、Rust の実装が Lean の定義と計画の契約から外れている。どちらも X02 の照合（Rust の警告と消費が Lean と一致すること）を成り立たなくする。

## 中

### 中1. 定数参照の扱いが、Lean の constE と計画の契約から外れている【再現】

- 場所: `crates/benitoite/src/typeck/interval/flow.rs` 674–693 行（`name()` の `BindingKind::Const`）、`interval/mod.rs` 233 行（値の解析を `BodySource::Function` に限る条件）。
- 問題: Rust は定数参照を、型が Integer なら評価済みの値表から一点の区間として読み、それ以外の型は Unknown にする。定数の埋め込み本体も、定数の定義そのものも、値の解析にかけない。
- Lean と計画の定め: `formal/Benitoite/Interval/BudgetAnalyze.lean` 66 行は `.constE _ child => expr fuel (clearLocals env) child` であり、埋め込み本体を空の局所環境で解析する。01-12 の 1663・1845 行も同じ規則を書いている。plan.md「識別」の行は「constEの埋め込み本体も子とし、局所位置を空にした親の解析で読む」と定める。「解析入力と出力」の行は、Item::Const を Block.last に包んだ定義として解析の入力に含める。
- 違いの現れ方:
  - (a) 真偽の定数の枝で、Lean が警告しない位置に警告が出る（再現）。`const debug: Boolean = false` の後、`bind z <- 0` と `return if debug then 10 div z else 1 end if` を書くと、Rust は W0401 を出す。Lean では tested.boolean が (true,false) になり、`BudgetScan.branch` が真の枝を到達しないと判定するので、警告は出ない。A07 の完了条件「新規未到達警告なし」と、契約表の「未到達の判定は各入力が持つ事実に対して行い」に反する。
  - (b) Lean が保証しない警告を Rust が出す（再現）。`const k: Integer = 3 - 3` の後に `bind z <- k` と `return 10 div z` を書くと、Rust は値表の 0 から W0401 を出す。Lean では減算が未対応なので k の区間は Top になり、警告しない。意味の上では誤りではないが、Lean の健全性定理の外にある警告であり、X02 の照合では不一致になる。
  - (c) 定数の定義の中の候補を作らない。`const c: Boolean = 1 > 2 and (10 div 0 = 1)` は現在も受理される。A08 で短絡を接続すると、Lean はこの定義の中で W0401 の候補を作り、Rust は作らない。`save_candidate` は `type_owner == definition.binding` で出現を探すので、そのままでは埋め込み本体の中の候補を Unmapped として止まる。
- 修正案: Lean に合わせる（`name()` の Const の場合に元の値式を空の局所環境で同じ予算の中で解析し、定数の定義も flow にかけ、埋め込み本体の中の候補を元の NodeId でまとめるテストを足す）か、値表から読むことを設計の判断として残し、02-05 に Lean との違いと X02 から除く理由を書き、真偽の定数も値表から読む。
- 時期: 方針は A08 の前、実装は遅くとも A11 まで。

### 中2. 由来（補助位置）の計上が Lean の予算付きの解析にない【読解】

- 場所: `flow.rs` 799–803 行（束縛ごとの `origins.binding`）、522–526 行（比較）、311–326 行（if の合流）、578–604 行（候補の補助位置の保存）、`interval/origins.rs` 全体。
- 問題: Rust は束縛・比較・合流のたびに `Operation::Origin` を一回計上し、`Item::Auxiliary` の一時項目を確保する。候補を保存するときは、補助位置を一件ずつ保存項目として確保する。Lean の `Budget.lean` には `.origin` と `auxiliary` の欄があるが、`BudgetAnalyze`・`BudgetEnvironment` はどちらも計上しない（`.origin` を使うのは `BudgetExamples.lean` の charge の例だけ）。
- 影響: 本体・全体の操作数と最大同時保持が Lean と系統的に食い違い、止まる位置も変わる。補助位置の確保に失敗すると候補ごと捨てて止まるが、Lean はその候補を保存する。束縛の値が整数でなくても由来の項目を作るので、予算を余計に消費する。
- 既知との関係: 取りまとめが A11 へ送った四点には含まれていない。D16 は「由来の一箇所」「補助位置の一件」を計上の単位としており、Rust は D16 に従っている。足りないのは Lean の側である。
- 修正案: D16 に揃えて Lean の BudgetAnalysis に由来の計上を足す（L の作業）か、X02 で由来の分を比較から除く規則を決める。Rust 側では、整数の位置（`Slot::Integer` を書く束縛）にだけ由来を作るのが妥当である。
- 時期: 方針の記録は A08 の前、一致させるのは A11 まで。

## 軽

### 軽3. 実行しない位置にも警告が出る（設計上は許した限界）【再現】

- 例1: `return if x = 0 then 1 else if x = 0 then 10 div x else 2 end if` で W0401 が出る。Lean の `excludePoint` も端点しか除かないので Lean と一致し、D6 の条件付きの意味にも反しない。U01 の棚卸しの観察対象に挙げ、02-05「単一比較とifの合流」に「穴を表せないため、実行しない枝でも警告しうる」と一文で書く（U01 まで）。
- 例2: `if not (z = 0) then 10 div z` で z=[0,0] のとき警告が出る。not は A08 の範囲であり、A08 の完了条件の表に「not で到達しない枝に新しい警告を出さない」の行を加える（A08）。

### 軽4. 02-05 に古い一文が残っている【読解】

`docs/design/02-impl/02-05-typechecker.md` 162 行の「比較による絞り込み・新しい診断はこの入口の処理に含まない」は、A06・A07 の後の実装と食い違う。削るか「`Prepared` は値域の解析の全体の完了を表さない」だけを残す（U02 まで）。

### 軽5. 診断の値を処理の関数の中に直接書いている【読解】

`interval/diagnostics.rs` 84 行の `.arg("ty", "Integer")` と 68–70 行の `format!("[{lo},{hi}]")`。AGENTS.md「文言」は型板に埋める値をモジュールの `text` にまとめると定める。型名は既存の型の表示で書き出し、区間の書式は `interval::text` の定数に移す（A13 まで）。

### 軽6. 深さの fuel が名前のない数値になっている【読解】

`typeck/decls.rs` 874 行の `4096`。名前付きの定数にし、根拠（parser の MAX_DEPTH=1000 との関係）と交換で fuel を明示する契約を一行のコメントで書く（A11 まで）。

### 軽7. テスト専用の本番の欄と、重なる統合テスト（test-audit）【読解】

- `BodyReport.coverage`・`usage` は `#[cfg(test)]` にしたが、`Report.remaining`・`body_entry_stops`・`first_entry_stop`・`whole`・`bodies` も本番では書くだけで、読むのは `interval/tests.rs` だけである。A12 で報告に接続する前提を申し送りに明記するか、扱いを揃える。
- `tests/cli_process.rs` の `local_interval_warnings_keep_json_locations_and_deny_exit` は、既存のゴールデン（JSON の補助位置）、既存の CLI テスト（deny-warnings の終了 2）、`tests/declarations.rs` の新しい表のテスト（区間の注記と元の位置）と重なる。declarations の表か既存の deny のテストの表へ寄せる（A12 まで）。

## 確かめて問題がなかった観点

- 加算・div・mod・六比較・不等値の端点の除去・左右の反転・到達判定の後の読み直し・条件に正常な真偽がない場合・baseThen・abrupt・baseDiscard・構造のパターンの Top は、Lean の対応する定義と一致する。
- 新しい候補は左右がどちらも Integer（Integer64）の二項演算からだけ作る。幅付きの型と型変数は除外され、型の別名でも正しく判定する【再現】。到達しない枝、正常値のない子、return の後、ラムダ・match・未対応の形の内側には新しい警告を出さない【再現】。
- shadow、別名へのコピー（逆向きの絞り込みなし）、block と枝の差分の巻き戻し、if の後に絞り込みを残さないこと【再現・読解】。
- 警告が増えるだけで check の終了は 0、`--deny-warnings` では 2【再現】。解析の誤りはすべて Coverage::Stopped に退き、診断も拒否も作らない。新しい unwrap・expect・添字・panic はない。
- 実装の索引の固定、`finalize_zonked` の切り出し、関数の誤りで入力を無効へ戻す位置、診断の並べ替え【再現】。
- 旧定数警告の優先と (NodeId, 原因, 一次位置) の鍵の一致、W0401・W0402 の文言と D19 の一致、skill の生成物、補助位置の上限 8。
- 予算の上限（D16）、charge と reserve の原子性、本体の上限の先の報告、全体の停止の後の扱い、一時項目の確保と返却の釣り合い。本体・全体の上限に達する大きな入力でも停止前の警告が残り異常終了しない【再現】。
- 990 段の else if の連なり（全段に到達する形）が 4 MiB のスタックで通る【再現】。既存の `stages_fit_the_measured_stack_through_deep_branches` の else-if の形は先頭が `if true` なので区間解析は辿らない（測定の穴だが余裕は確かめた）。
- `as`、大域の状態、コメントの根拠、`#[allow]` の表、設計書 02-05・02-10・01-04 の規範（軽4 と中1 を除く）。
