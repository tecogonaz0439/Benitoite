# RV3 段3（O1・O2）と段4（F1〜F3）のレビュー

対象: `git diff 8604e358..28f25745`（san_benito）。判断 R71〜R85、計画の O1〜F3、各作業の results.md を参照した。全体を精読せず、Lean の規則との対応、実行時の安全、テストの期待の変更、交換形式、規約に絞って読んだ。重いビルドと全件のテストは走らせていない。既存の `target/debug/benitoite`（F3 の取り込みの直前のビルド）で、小さな入力を `check` して挙動を確かめた。

## 判定

**軽い直しの後に進んでよい（直しを P1 の最初に含めればよい）。**

表層の型検査は、確かめた範囲で Lean の規則（R60・R61）と一致していた。確かめた規則は、単一 Fail、署名だけから導く NoFail、Fail 節がちょうど一つであること、通常節との混在の拒否、resume の拒否、E の未確定（E0517）、具体化した行の NoFail である。辞書の実行時の経路も、規約と設計どおりに既存のレジスタ・閉包・継続を根として使っている。ただし、独立したコア IR 検査器の Fail の handle に、検査が一つ欠けている（中1）。表層の検査と脱糖が正しい間は表に出ないが、検査器が独立して守るべき性質である。直しは一行と退行テスト一件で済むので、P1 の最初に含めればよい。

## 指摘

### 中1 独立 IR 検査器が Fail の handle で「本体の残りの効果 ⊆ handle の効果」を検査しない

- ファイル: `crates/benitoite/src/ir/check.rs` 1137〜1149 行（`fn handle` の `if let Some(error_ty) = failure` の分岐）
- 問題: 通常の handle の分岐（1151〜1155 行）は `body.eff ⊆ comp.eff ∪ handled` を検査する。一方、Fail の分岐は `rest = body.eff − failures` を作り、`body.eff ⊆ rest ∪ {E}` だけを検査する。rest は body.eff から作るので、この包含は E 以外の Fail の混入を見つける以外には常に成り立つ。rest の NoFail（行が Q に含まれること）は検査するが、**rest が handle 全体の効果 `comp.eff` に含まれることをどこでも検査しない**。節の効果 ⊆ comp.eff は `clause` が検査するが、本体の側は抜けている。Lean の規則（R60「外側の最小効果は Rest と節の効果の和」）と、02-06 の「Fail の handle の効果は、本体の効果から固定 E の Fail だけを除き、節の効果を加える」に、検査器が対応していない。
- 失敗の筋書き: 脱糖の `handle_effect`（`ir/desugar/effects.rs`）か低位 IR の変換に退行が入り、Fail の handle の `comp.eff` から本体の `Console.Write` などが落ちたとする。親の計算は handle の小さい `comp.eff` だけを見て包含を検査し、定義の本体の効果も宣言の範囲に収まる。すると検査器は誤りを報告せず、宣言にない効果を行う定義が `check_program` を通る。表層の型検査器は正しいので、利用者のソースからこの状態は作れない。崩れるのは、脱糖と低位 IR の退行を捕まえるという検査器の役割である。
- 修正案: Fail の分岐で、rest を upper へ移す前に `self.effects(handle.body.origin, &rest, &comp.eff);` を加える。`failure_clause_error_type_kind_and_unavailable_continuation_are_checked`（同ファイルのテスト）に変異を一つ加える。本体が `Console.Write` などを行う Fail の handle を desugar し、handle の `comp.eff` からその名前を除いて、`check_program` が誤りを返すことを確かめる。Lean と規則の文言は変えない。

### 軽1 同じ `Failure.Fail[E]` を `uses` に二度書いても診断がない

- ファイル: `crates/benitoite/src/typeck/effects/declarations.rs` 20〜22 行（`check_uses` で Fail を重複の検査から外す `continue`）
- 問題: ほかのエフェクトを `uses` に重ねて書くと E0419 になる（例: `uses Console.Write, Console.Write`）。ところが `uses Failure.Fail[String], Failure.Fail[String]` は、`EffectSet::insert_failure` の重複除去で黙って一つになり、診断が出ない。確認した入力: Console の重複には E0419 が出て、Fail の重複には何も出ない。型が異なる場合は E0514 になるので、健全性の問題ではない。同じ役割の書き方の扱いが揃っていない（設計原則 5）、診断の一貫性の問題である。
- 失敗の筋書き: LLM が `uses Failure.Fail[String], Rest, Failure.Fail[String]` のような重複を生成しても検査を通り、利用者に見せる権限の説明にも残らない。後で片方の型だけを直すと、そこで初めて E0514 になる。
- 修正案: Fail を `continue` で外すのをやめる。型を `ty` で解決し、同じ型が二度現れたら E0419 を報告する（型が異なる場合は従来どおり `uses` の側で E0514）。golden を一件加える。Lean の規則には影響しない（効果の集合の表現の問題であるため）。

### 軽2 vm_handlers の既存の事例の全件を `if true then … else 0 end if` で包んだ

- ファイル: `crates/benitoite/tests/vm_handlers.rs` 202〜206 行
- 問題: 既存の約 25 件の事例は、以前は `bind answer <- {expression}` の形で、handle などを束縛の右辺に直接置いて実行していた。O1 以降は全件が `if true then` の分岐の中で実行される。期待値と assert は変えていないので、期待を緩めてはいない。ただし、検査するプログラムの形が変わった。末尾の位置、結果のレジスタの割り当て、`handle` の枠の位置が変わるので、元の形でだけ現れるコード生成の退行を、この表では捕まえられなくなった。
- 失敗の筋書き: handle の結果を束縛へ直接書き込む経路（`fg.result(target)` の最適化など）に退行が入っても、全事例が if の合流を経るので、この表が失敗しない。
- 修正案: 包む処理は、新しく加えた `operation_dictionaries::CASES` と `typed_failure::CASES` のうち、式の位置に文の並びを要するものだけに限る。既存の `cases` は元の形で実行する。両方の形で実行してもよい。

### 軽3（観察）型検査の時間が二次になりうる箇所

- ファイル: `crates/benitoite/src/typeck/solve.rs` 707〜725 行（`equal_function_effects` の `self.effects.contains`）、1319 行（解く手順のループの各回で `propagate_effects` を呼ぶ）、1803 行（`propagate_effects` のループの各回で `self.effects.clone()`）
- 問題: `equal_function_effects` は、Failure を使わないプログラムも含め、関数型を単一化するたびに制約の列全体を線形に探す。比べるのは `IEffect`・`Reason`・`ITy` の深い等値である。`propagate_effects` は、Failure を読み込んだプログラムで、解く手順のループの各回とその内側の不動点のループの各回に、制約の列を丸ごと複製する。正しさの問題ではないが、ラムダと高階関数の多い本体で、型検査の時間が制約数の二乗で伸びうる。
- 修正案: 段の後の短い測定（スキル benchmark）で、型検査の時間を開始版と比べる。差が出たら、重複の判定を `HashSet` か索引に置き換え、Fail の伝播を変化した制約だけに限る。測定で差がなければ、このまま進めてよい。

### 軽4（観察）`finalize_failure_type` が再帰し、各段で zonk し直す

- ファイル: `crates/benitoite/src/typeck/solve.rs` 476 行〜
- 問題: 型の構造は AST から作る中間の表現なので、再帰で辿ること自体は規約の範囲内である。ただし、各段で `self.zonk(t)` が部分木全体を複製するので、深さ d の型で O(d²) になる。型の深さの上限は 1000 なので、上限近くのエラー型では時間と処理系のスタックを余分に使う。ほかの zonk の経路は、明示の積み重ねと予算を使っている。
- 修正案: 根で一度だけ `zonk_checked` を行ってから構造を写すか、`finalize` の既存の明示的な積み重ねの経路を使う。深さが上限近くのエラー型の lib テストを一件加えてもよい。急がない。

## 確かめて問題がなかった点

- **単一 Fail と NoFail の検査位置（R60・R61）**: 呼び出しと値化での具体化（`context.rs` の `instantiate` の `require_no_fail`）、式の結果の型と元の効果の事後検査（`check_single_failures`）、期待型の受け入れ（R81、`failure_rows_valid`）、効果の包含の解決時に不変の型として単一化すること（`propagate_effects`）、宣言の `uses` 内の複数の型（E0514）。golden は if・else if・パイプ・部分適用・期待型・結果型・注釈・関数値・効果の合流を揃えている。試した入力: 署名の Q にない行 R を `toResult` の Rest へ流すと E0515。高階の `apply` を経由しても、リストに格納した関数を経由しても E0515 と E0514 になり、抜け道は見つからなかった。
- **NoFail は署名だけから導く**: `Scheme::signature_no_fail` を宣言の時点で計算し、本体からは追加しない。メソッドは `check_methods` でクラスの Q との一致を要求する。IR 検査器も `scheme.no_fail == signature_no_fail()` を再検査する。
- **Fail の節**: 節がちょうど一つであること（E0518、混在も同じ）、resume の拒否（E0516）、E の未確定（E0517）、型引数 1 番（E）の固定と 0 番（T）だけを剛な型にすること。この扱いは型検査・脱糖・IR 検査器の三つで一致していた。IR 検査器は、Fail の節の継続を環境に入れないこと、節の種類と操作の印が一致すること、E が外側で整形式であることも検査する。
- **main と @test**: Fail は E0506 で拒否される。CLI の契約抽出（`cli/inspection.rs`）は、Fail と NoFail が残っていれば内部エラーとして止める。許可名の表に Fail は入らない。
- **辞書の実行時の経路**: PERFORM は辞書・値引数の順にレジスタの区画へ並べ、引数数の検査は辞書の数と値引数の数の和で行う（`codegen/emit.rs`、`desugar/decls.rs` の `arity`）。節の原型の引数は、辞書・値引数・継続の順である。捕捉の解析（`analysis.rs`）と参照実行器（`eval.rs`、`index.rs`）も同じ順で束縛する。VM・ランタイム・ヒープは変更していない。辞書は通常のレジスタ、閉包の環境、継続の区画を根として保持されるので、安全点を越える裸の値はない。局所の heap-verify と gc-stress（O1 と F2）も記録にある。
- **節の辞書の所属**: `DictExpr::Clause` を節のノード番号で区別し、入れ子の節の終了時に脱糖の局所表から除く。IR 検査器は、辞書の数・順序・クラス・重複した束縛を、宣言から再計算して検査する（変異のテスト 6 件）。
- **解放と非捕捉**: 既存の非再開の drop の経路を使う。Writer の解放の順序と回数、エラー値が安全点を越えること、解放の失敗を Result.Error へ変えないこと、実行時エラー（`1 div 0`）を捕捉しないことは、vm_handlers の新しいテストが検査する。子のタスクが親の失敗ハンドラを使うと実行時の R0502 になる点は、静的な拒否ではない。ただし 01-11 に決定として書かれており、既存の引き継ぎの制限と一貫している。
- **テストの期待の変更**: 既存の期待を変えたのは、parser の型クラスの制約の拒否の 2 例だけである（`syntax/parser/effects.rs` のテスト）。R72 のとおり、受理と、AST に制約が残ることの検査へ変えた。型構成子のパラメータの拒否（E0510）と位置・案内の assert は残っている。`named_arguments.rs` は表を外側のループへ移し、制約付き操作の事例を加えただけで、元の 5 件の期待は同じである。`vm_lazy.rs` は事例と import の追加だけである。既存の golden の変更と削除はない（testdata の変更はすべて追加）。そのほかは軽2の形の変更がある。
- **交換形式 11/4**: `routing-manifest.json` は 1,741 件の版の更新だけで、件数・分類・理由は変えていない。`exchange-manifest.json` は版の更新と `batch2Failure` の追加だけである。`check_named.py` は版の数字だけを変えた。旧 corpus 10 との比較（`desugar_export/lib.rs`）は残っている。`neffs=0` を assert したうえで `effParams=[]` を補うだけなので、O2 の止まる条件（旧入力の比較を失わない）は満たしている。
- **formal/**: 段2の閉鎖（results.md の記録）による `native_decide` から `rfl` への置き換えと、`satB_unconstrained` の追加だけで、規則・定理・公理は変えていない。`lake build` の実行も記録されている。
- **規約**: 本体のコードに新しい `unwrap`・`expect`・`panic`・`#[allow]`・大域の状態・`unsafe` はない（いずれもテストの中だけ）。診断の文言は `diag::codes` と各モジュールの `text` にまとめてある。IR 検査器の英文は内部の誤りの説明なので、規約の対象外である。
- **文書**: 01-02・01-06・01-07・01-09・01-10・01-11・02-05・02-06・02-08・02-09・03-06、英語リファレンス、Skill の生成物の記述は実装と一致していた（`Benitoite.Unofficial.Failure` で取り込むこと、R83 の注釈による E の指定）。例外は中1で、02-06 が述べる検査を IR 検査器が行っていない。設計書を直すのではなく、実装を合わせればよい。

## 補足（指摘ではない）

- 処理されない場所に置いたラムダの Fail の型が未確定のままだと、Unit として確定する（例: `bind g <- lambda(x) return Failure.raise(error: x) end lambda` は通る）。未確定の型の既存の既定値の扱いと同じで、handle の E の未確定は E0517 で拒否するので、健全性には影響しない。
- `failure_type` の型引数の番号 1 を、型検査・脱糖・IR 検査器の三箇所に直接書いている。`FAILURE.scheme()` の並び（T、E）と結び付いているので、将来この並びを変えるときは三箇所を同時に直す。
