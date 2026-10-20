# 0.0.10 の事前点検（段1の前）

対象は、ブランチ `mod010/design`（HEAD `18de1b05d8637362a2a4a46080de69d96753df48`）にある本ディレクトリの design.md・plan.md・decisions.md（63問のA、B17、R101〜R116）・implementation-request.md・bench-targets.json である。これらを、処理系（crates/benitoite）・tools/derive・tools/bench/compare・scripts/check.sh・formal/ の実態と照合した。本書は、実装前の事前点検と、Lean 先行の段の定義・言明・仮定のレビューを兼ねる。レビュー担当は Opus 5.5、日付は 2026-10-19 である。

formal/ で既定の `lake build` を実行し、成功した（273 jobs、キャッシュ済み）。リポジトリは本書のほかに変えていない。cargo のビルドとテストは実行していない。

## 結論

**先に直すべき点あり。** 重い指摘は一つである。design 3.3・12.2 と plan L3/L4 は、コアで通常変数と局所参照を別の番号空間にし、表層の Γ/Δ からの二つの写像を脱糖の内部に持つ。今の脱糖は環境を引数に取らない構文上の関数であり、局所変数の番号を変えない（`.local i ↦ .ret (.var i)`）。0.0.9 の事前点検の重1と同じ種類の問題であり、脱糖の署名と性質1の全補題に変更を広げる。表層と同じく番号の空間を一つにすれば、脱糖の番号付けと環境の対応はそのまま使える。L1 より前に design 3.3・12.2、R101 の補足、plan の内部契約表 L3/L4・作業 L4 の手順を直すことを推す。

中の指摘は四つある。191 の有界の Integer と構築器の length の結果がかみ合わない点、関数値と遅延の本体から専用の場所を除く規則が定義案にない点、`Expr.Exits` に block の場合がない点、B2/B3/G2 の work 行が全統合ターゲットを heap-verify と gc-stress で走らせる点である。どれも計画へ数行を足せば直せる。

指摘の数は、重 1・中 4・軽 10 である。

191 の有界化は、第二の重い形式化にはならない見込みである。組み込みの関数の結果 δ は `Builtins.delta` として抽象化されている。Release の意味論には整数を自ら作る規則がない（`Release/Semantics.lean` に `.integer` の出現がない）。値としての `Const.integer` の使用は約 60 か所（主に `Release/Coverage.lean`、例、交換）にとどまる。全域の判定も、Character の有界の区間の扱い（`Shape.interval`）を流用できる。ただし中1のとおり、248 の length が加わると、意味論の中で整数を作る最初の規則になる。

## 重

### 重1 コアの番号空間を分けると、環境を取らない脱糖と合わず、L4 の範囲が大きく広がる

- 箇所: design 3.3「コアの通常変数と局所参照は別の番号空間とする。表層のΓ/Δから、通常位置だけのΓへの写像と構築器位置だけのΔへの写像を脱糖の内部に持つ」、design 12.2 の `builder_env_project_lookup/up`、plan の内部契約表 L3/L4「通常番号と局所番号の射影を分け」、作業 L4 の手順「Γ/Δから通常/局所の番号への二つの写像とlookup/up/renameを先に閉じる」。
- 問題: 今の脱糖は六つの相互再帰（`desugarExpr`・`desugarExprs`・`desugarHoleArgs`・`desugarArms`・`desugarClauses`・`desugarBlock`）で、環境を引数に取らない（`formal/Benitoite/Surface/Desugar.lean:147〜151`）。局所変数は `.local i => .ret (.var i)`、構築器の操作は `builderFinish op (i + ms.length) refs` と、表層と同じ番号をそのまま使う。0.0.9 は表層で番号の空間を共有し（`Surface/Builders.lean` の `BuilderCtx.Aligned`。Δ は Γ の先頭にそろえ、構築器の位置は Γ で `none`）、コアの環境は `fillBuilders Γ Δ`（構築器の位置を Reference の型で埋めるだけで長さを変えない）とした。コアで番号の空間を分けると、表層の `.local i` を「i より内側にある構築器の数」だけ詰めた番号へ写す必要が生じる。その数は Δ に依存するので、脱糖の六関数に対応表の引数を足し、束縛ごとに更新しなければならない。そうなると、脱糖の全場合、`HasTypeQ.desugar` 系の全補題、交換の脱糖の比較（DesugarDiff と Rust の `tests/desugar_export`）の番号付けまで書き換えになる。plan L4 の 8〜16 時間には、この変更が入っていない。
- 根拠: コアの環境は既に `List (Option Ty)` であり、`none` の位置を持てる。`V_Var` は `Γ[i]? = some (some a)` を要求するので（`Release/Typing.lean:313`）、`none` の位置は通常の値として読めない。既存の付け替えと置き換えの補題も、`some (some a)` の位置にだけ義務を課す（`Release/Lemmas/Rename.lean:94` の `RenOk`）。
- 修正案: コアでも表層と同じく番号の空間を一つにする。design の `LocalRef := bound Nat | loc Nat` と `builderLet`/`builderOp` の構造はそのまま使える。
  - `builderLet k body` は通常の束縛と同じく番号を一つ束縛する。コアの Γ には `none`、コアの Δ（Γ の先頭にそろえる）には `some k` を積む。通常の束縛は Δ に `none` を積み、lam・lazy・節の本体は Δ を `[]` にする。
  - `LocalRef.bound i` は `.var i` と同じ番号の空間を使い、`Δ.kindAt i = some k` を要求する。
  - 付け替え `Comp.rename ξ` は `bound i` も `bound (ξ i)` へ写す。`builderLet` の一歩は、番号 0 を `loc ℓ` へ置き換え、1 以上を一つ詰める。置き換えは、既存の `Comp.subst`（`σ : Nat → Val`）の LocalRef の場合を「`σ i = .var j` なら `bound j`、`σ i = .loc ℓ` なら `loc ℓ`」とすれば `instantiate [.loc ℓ]` で表せる。B2 の「通常の`.loc`を流用して普通の値へ戻せる入口を作らない」を字句どおり守るなら、LocalRef 用の写像 ρ を σ と並べて持つ専用の置き換えにしてもよい。どちらでも、Γ の番号 0 が `none` なので、通常の値の位置に専用の場所は入らない。
  - 脱糖は `builderBind k rest ↦ builderLet k (desugarBlock rest)`、`builderOp op i args ↦ sequence ms (fun vs => builderOp k op (.bound (i + ms.length)) vs)` となり、番号を変えない。表層からコアへの環境の対応は、Γ・Δ とも恒等になる。`fillBuilders` と、design 12.2 の `builder_env_project_lookup/up` はいらない。`local_rename_typed`・`local_subst_typed`・`ordinary_subst_local_typed` は、既存の付け替え・置き換えの補題に LocalRef の場合を足す形に統合できる。
  - Rust の書き出しは、0.0.9 と同じ局所番号の付け方（構築器の束縛も一つの番号に数える）を保てる。Rust の `core_ir::BuilderId` を `VarId` と別にする plan B2 の内部契約は、名前で識別する Rust の表現の話であり、そのまま使える。
  - design 3.3 の該当段落、12.2 の補題表、R101 の補足（決定ではなく C1 の推す案なので、R の続きの番号で表し方を改める）、plan の内部契約表 L3/L4 と作業 L4 の手順・見込みを直す。この選択は形式化の表し方であり、Ty/Eff・主定理・Builtins.Assumptions を変えない（全体で引き継ぐ決定3の「表し方の変更」に当たる）。
  - 付記: 値の型付け（`HasTypeVQ`）は Δ を持たなくてよい。値の中の計算は lam の本体だけで、その Δ は常に `[]` だからである。Δ を足すのは計算・節・分岐の判断だけで済む。

## 中

### 中1 有界の Integer の下では、構築器の length の結果を抽象の内容から作れない

- 箇所: design 3.1 の `byteLength`/`length` の型（`-> Integer`）、design 3.3 の `BuilderContents := string String | list Ty (List Val) | bytes (List Nat)`、design 12.2「長さ/UTF-8/容量/GCは物理実装との照合へ分ける」、design 6.2・12.5 の `Integer64Value`、plan L1→L3 の順序。
- 問題: L1 で `Const.integer` を `{ n : Int // min64 ≤ n ∧ n ≤ max64 }` にした後、L3 で length の一歩を加える。0.0.9 の length は標準の純粋な関数（`BuilderRefs.lengthRef`、δ）へ委ねていたので、意味論は整数を作らなかった。新しい案では、length の一歩が内容の長さから `.const (.integer ⟨len, h⟩)` を作る。内容に上限がない抽象モデルでは `len ≤ max64` を示せず、進行（progress）の証明で length の一歩を作れない。
- 根拠: `Release/Semantics.lean` には整数を作る規則がない。`BuilderOp.result .length k = .base .integer`（`Surface/BuilderSyntax.lean`）。Rust 側は論理上限 `MAX_STRING_BYTES = 1_073_741_824`・`MAX_LIST_LEN = 16_777_216`（`runtime/mod.rs:18・20`）を確保前に検査し、超えれば `ValueTooLarge`/R0902 で停止する。
- 修正案: 次のどちらかを design 12.2 に書き、L3 の手順へ入れる。設計者に確認。
  - A（推す）: Lean にも論理上限を置く。`BuilderCellOk` に「長さ ≤ 種類ごとの上限」を含め、append/appendAll が上限を超えるときは実行時エラーの状態（`.error [rValueTooLarge] k σ` のような新しい報告）へ進む規則にする。上限は max64 より十分小さいので、length は有界の定数を作れる。R0902 の意味とも一致し、Builtins.Assumptions も主定理の形も変えない。ただし進行の場合分けが一つ増え、`builder_step_no_event` の対象にエラーの一歩が入る。
  - B: length を、0.0.9 と同じく組み込みの関数の呼び出し（δ）として表す。抽象の内容をいったん通常の値へ写してから長さを求める形になり、copy と同じ費用の意味になる。意味論は単純だが、長さの意味が Rust の実装（O(1)）と離れる。
  - どちらも採らずに長さを切り詰めると、Rust と異なる意味を Lean に置くことになるので採らない。

### 中2 関数値と遅延の本体から専用の場所を除く規則が、定義案にない

- 箇所: design 3.3「通常値のlam/lazy/節は、内側で束縛したものを除き自由な局所参照を持たない条件を型付けから導く。単にΔを空にするだけで実行場所の捕捉を許さない」、design 12.2 の `builder_value_no_free_local : HasTypeV ... v A -> vに自由な局所参照がない`、12.3 の `local_steps_invariant`。
- 問題: 実行時の `loc ℓ` は Ψ の専用セルの型で型付けする（design 3.3）。lam の本体を「Δ = [] と同じ Ψ」で検査するだけなら、本体に `builderOp k op (loc ℓ) vs` を含む lam も型が付く。そのため `builder_value_no_free_local` は、今の定義案のままでは偽である。型付けの前に `bound` が lam の中に現れないことは Δ = [] から言えるが、置き換えの後の状態で同じ性質を保つには、lam・lazy の規則自体が `loc` を禁じていなければならない。遅延のセル（`CellOk` の `.thunk m`。`Release/Semantics.lean` の CellOk）も同じである。
- 修正案: design 12.2 の定義の一覧に、次を明記する。
  - lam・lazy の本体（と、通常の値へ入る計算すべて）は、専用セルを隠したストアの型（例: `Ψ.hideBuilders`）か、`loc` を許さない印のある判断で検査する。`CellOk` の `.thunk` も同じ判断を使う。
  - 「隠した Ψ での型付け ⇒ 元の Ψ での型付け」の弱化の補題を足す（lam を呼んだ後や遅延を強制した後の実行は、元の Ψ で型付けする）。
  - `builder_value_no_free_local` と `local_steps_invariant` の「通常値の非出現」は、この規則から導く。保存（preservation）の安全性だけならこの規則がなくても成り立つが、B2 の「通常値へ変換できない識別子」という保証の根拠になるのはこの規則である。

### 中3 `Expr.Exits` に block の場合がなく、Rust と Lean の受理が食い違う

- 箇所: design 2.1「必ず抜ける式と到達不能文の解析をblockの内部へ通し」、design 12.6、plan L5。
- 問題: Lean の `Expr.Exits` は `returnE`・`ite`・`elseIf`・`paren`・`matchE`・`withE` だけを辿り、ほかは False である（`formal/Benitoite/Surface/Syntax.lean:474〜486`）。`E_Lam` は `body.Exits ∨ r = .base .unit` を要求する（`Surface/Typing.lean:337`）。Rust が block の内部まで「必ず抜ける」を辿ると、たとえば本体の最後が `block … return x end block` のラムダを Rust は受理し、Lean は拒否する。この食い違いは、最後の check-formal 全体で初めて見つかる。
- 修正案: L5 の手順に「`Expr.Exits` に `.block body => body.Exits` を加え、`BuilderFree`・`Scoped`・`AtomsIn`・`SingleFail` と同じく相互帰納の全述語に block の場合を足す」と書く。design 12.6 の「Scoped/AtomsIn/SingleFail/BuilderFree/捕捉の相互帰納」にも Exits を加える。到達不能の判定（E0439）は Rust の外側の検査なので、Lean では Exits だけで足りる。

### 中4 B2・B3・G2 の work 行は、全統合ターゲットを heap-verify と gc-stress で走らせる

- 箇所: plan「各作業のwork」の B2・B3・G2 行（`--only …,heap_local,stress_local,… --test '*'`）、見込み「10〜30分」。
- 問題: scripts/check.sh は、`--test` の一覧を tests_related・heap_local・stress_local の三つに同じく渡す（`run_units` の `targets`、`scripts/check.sh:513〜518`。heap_local は `cargo test -p benitoite --no-default-features --features "$features" "${targets[@]}"`、stress_local は同じ指定に `,gc-stress`）。`--test '*'` と組み合わせると、全統合ターゲットを heap-verify と gc-stress で各一回実行する。これは change の `test_heap_all`・`test_stress` に近い量であり、各 work で三回繰り返すことになる。0.0.9 では gc-stress の一件に 6 時間を超えた実績がある（decisions の全体で引き継ぐ決定4）。重い検査を最後へ集める決定とも合わない。
- 修正案: B2・B3・G2 の行は tests_related だけを `'*'` で実行し、heap_local・stress_local は外す。根・保持先の確認は、既にある「workに含める補完」の行（`cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep,heap-verify <filter>` と gc-stress の版）に、関係する統合ターゲットを名指しで足す（例: B2 は `--test vm_handlers --test vm_lazy --test vm_reference_cells --test verify`、G2 は `--test io_modes --test vm_handlers`）。check.sh の一回の起動では対象を分けられないので、補完は直接の cargo コマンドで書く。T4 の行も golden を gc-stress で走らせるので、見込みを quick の実測で確かめてから固定する。

## 軽

### 軽1 `drop_local_silent` と「通常セル不変」は、OrdinaryStoreEq の定義を絞らないと偽になる

- 箇所: design 12.2 の `OrdinaryStoreEq`（「同じ場所の通常のセルは同じ」）、12.3 の `drop_local_silent : 構築器だけの保持の破棄 -> ev = none ∧ OrdinaryStoreEq σ σ'`、12.2 末尾の「純粋なプログラムの通常セル不変の系」。
- 問題: 未再開の継続の破棄は `E_DropRel` であり、`σ.set κ .used` で継続のセルを書き換え、`releases k'` を継続の前へ積む（`Release/Semantics.lean:289〜292`）。純粋な計算でも、遅延の強制は `.thunk` のセルを `.done` に書き換える。「通常のセル」に継続や遅延のセルを含めると、どちらの言明も偽になる。
- 修正案: OrdinaryStoreEq を「`.val` のセル（Reference のセル）が同じ」と定義する。`drop_local_silent` は「`releases k' = []` のとき、`σ' = σ.set κ .used` かつ事象なし」と書く。

### 軽2 191 の表層のリテラルとパターンの表し方を決めておく

- 箇所: design 6.2・12.5「表層の正の整数リテラル/パターンの大きさはmax64以下…」、plan L1。
- 問題: 今は `Literal.integer (n : Nat)`・`Pattern.integer (n : Nat)`・`Pattern.negInt (n : Nat)`・`Expr.negInt (n : Nat)` であり（`Surface/Syntax.lean:53・117・118`、Expr の `negInt`）、`Literal.toConst` は全域の関数である。有界の Const へ写すには、構文に上限の証明を持たせるか、型付けの規則に `n ≤ max64` の前提を足すかを選ぶ必要がある。後者は WellTyped の意味を狭める（Rust は E0408 で既に拒否しているので実害はないが、停止条件の「旧プログラムを未証明の条件で除外」に当たるかの判断が要る）。
- 修正案: 構文に上限を持たせる（大きさの部分型、または `Nat` と証明の組）。交換の読者（`Exchange/Convert.lean`）が範囲を検査して作る。脱糖は全域のまま、型付けの規則も変えずに済む。型付けの前提にするなら設計者に確認。

### 軽3 L1 の「触るファイル」に、型の変更で壊れる読者が抜けている

- 箇所: plan 作業 L1。
- 問題: `Const.integer` の型を変えると、既定の import 全体が L1 の中で壊れる。値として使う箇所は `Release/Coverage.lean`（21 か所。L2 の対象だが L1 でもビルドを保つ必要がある）、`Release/Examples.lean`、`Surface/Desugar.lean`（`negInt`、`dieFailure` の `.integer 1`）、`Surface/{Examples,CheckToolsExamples,CheckCounterexamples,CheckExamples,Monad2Examples,BuilderExamples}.lean`、`Release/Model.lean`、`Exchange/{Convert,Syntax}.lean`、`CoverageDiff/Main.lean` などにある。`Release/Coverage.lean:1999〜2000` の `decide` の例は、全域の範囲の判定結果が変わる。
- 修正案: L1 の触るファイルを「`Const.integer` の全読者（上の一覧）」とし、Coverage の例は L1 では旧の結果のまま通し、L2 で期待値を変えると書く。

### 軽4 corpus 13 の形と版の判定の分岐を、L7 の手順に具体的に書く

- 箇所: design 12.8、R103、plan L7。
- 問題: 今の `exchangeJson` は corpus 8〜12・sidecar 2〜4 を受け、corpus 12 だけが構築器の欄（`builderBind`・`builderOp`・`refs`・`newRef`・`getRef`・`setRef`）を許す。`sidecarVersion` は `corpusVersion >= 11 → 4` である（`Exchange/Version.lean:125〜148`）。新しい表層では BuilderRefs（Reference の new/get/set と純粋な関数の参照）がいらなくなる見込みだが、design は表層の `BuilderRefs` と `refs.Ok` を消すかを明記していない。
- 修正案: L4/L7 に次を書く。(1) 表層の `Expr.builderOp`・`Block.builderBind` から `refs` を外すか（外す案を推す）。(2) 受ける版を corpus 8〜13・sidecar 2〜5 とし、`sidecarVersion` を 13 → 5、11/12 → 4 とする。(3) corpus 12 の構築器の欄は「版13で再生成」の理由で拒否し、構築器を含まない corpus 12 は範囲検査の後に受ける。(4) 既存の `test_*_exchange.py` が旧版を通し続けることを L7 の完了条件にする。(5) Rust の書き出し（`tests/desugar_export` の版）を B2 で切り替える対象として名指しする。

### 軽5 G6 で直す現役の参照が、計画の一覧より多い

- 箇所: plan 作業 G6「AGENTS.md・関係README、必要ならscripts/check/・07-03・workflow」。
- 問題: `tools/named-arguments-migrate/` を名指しする現役の箇所は、`scripts/check.sh:247`（python_syntax の glob）・`323`（分類）・`501`（dry-run の表示）、`tools/source-migrate/README.md:53〜54`、`tools/try-actions-migrate/migrate.py:39`（除外の一覧）、`docs/design/07-quality/07-03-compiler-testing.md:353`、`AGENTS.md:53` である。移動後に python_syntax の glob が一致しないと、bash は glob を文字のまま残し、`ast.parse` が失敗する。
- 修正案: G6 の触るファイルに上の各箇所を名指しで加える。check.sh を変えるので、policy_selftest（G6 の行に既にある）で三つのシェルの構文も確かめる。

### 軽6 B2 は見込みを超える公算が大きいので、続きの区切りを先に決める

- 箇所: plan 作業 B2（5〜8 時間）、R113。
- 問題: B2 は typeck・core_ir・lower_ir・ir/check・decision・desugar・bytecode の全読者・VM・参照評価・交換を一度に切り替える。R113 は未接続の命令を完了にしない方針で一度の切り替えを選んでいるが、L3/L4 と違い、続きへ渡す区切りが決まっていない。
- 修正案: L3/L4 と同じく、「既定の経路を切り替えない追加（型・命令・検証器・参照評価の独自ストア）を先に入れてビルドとテストを保つ区切り」と「既定の経路の一度の切り替え」を B2 の中の続き（b2c2）として明記する。作業の数は増やさない。

### 軽7 T1 の触るファイルに予算の定数がない

- 箇所: plan 作業 T1。
- 問題: 網羅性の予算 `MAX_COVERAGE_WORK = 1 << 20` は `src/typeck/limits.rs:9` にある。R102 の新しい三つの上限もここに置くのが自然である。
- 修正案: T1 の触るファイルに `src/typeck/limits.rs` を加える。

### 軽8 構築器の標準ソースの説明文が「Every operation uses State.」のまま残る

- 箇所: plan 作業 B2、design 13.3。
- 問題: `prelude/stdlib/StringBuilder.bnt` などの先頭の `//!` に「Every operation uses State.」とある。この説明は gen_skill の生成物（同梱 Skill の標準ライブラリの参照）へ入る。
- 修正案: B2 の手順に、三つの構築器の `.bnt` の説明文を新しい規則へ直し、同じ変更で gen_skill を作り直すことを名指しする。

### 軽9 L1 の `B_WORK` が今の HEAD と違う

- 箇所: implementation-request.md「L1の基準 `B_WORK`」、plan の基準表。
- 問題: 依頼文は `d3657abd`（C2 開始時）を L1 の基準とするが、C2 の文書は `18de1b05` としてコミット済みであり、本書の修正も加わる。処理系と formal/ に差分はないので検査の選択は変わらないが、work の基準のコミットとしては古い。
- 修正案: RV1 の修正を取り込んだコミットの完全な ID を L1 の B_WORK として依頼文に記入する（依頼文の「変わったなら実装開始前に基準を改訂する」に従う）。

### 軽10 本書と RV1 の関係

- 箇所: plan「レビュー（Opus、5回）」の RV1（reviews/RV1.md）。
- 問題: 本書は、RV1 が見る範囲（design 12節、定義・型・命令・区切り、目標JSON）を含む。0.0.9 では preflight.md と RV1.md を別に置いた。
- 修正案: 本書を RV1 として数えるか、修正の後に RV1 を別に行うかを決める。設計者に確認。

## Lean の言明ごとの判定

「正しい」は、今の定義と主な定理の前提・結論を変えずに成り立つ見込みであることを表す。証明済みという意味ではない。

| 言明（design の節） | 判定 | 理由 |
|---|---|---|
| `Release.progress`（12.1） | 正しい（中1の対応が要る） | 専用セルの反転を足せばよい。length の一歩は、中1の A か B を採らないと有界の定数を作れない |
| `Release.preservation`（12.1） | 正しい | StoreOk/CellOk に専用セルを足し、置き換えは重1の共有番号で既存の補題へ統合できる。`K_Let` などの枠は `HasTypeC … [] …` のまま、`loc` を Ψ で型付けすればよい |
| `Release.effect_soundness`・`noLamNames` 版（12.1） | 正しい | 専用操作の一歩は事象を伴わない。`K_Drop` の State の条件は捕捉した継続の効果に State があるときだけなので、構築器だけの継続の破棄は純粋な計算でも型が付く |
| `Surface.desugar_typed`（性質1）（12.1） | 正しい（重1の表し方なら） | 共有番号なら表層からコアへの環境の対応は恒等で、番号を変えない脱糖のままでよい。別の番号空間の案では、脱糖の署名と全補題の変更が要る |
| `Surface.surface_effect_soundness`（12.1） | 正しい | 純粋な main の言明は変わらない |
| `CheckSound` の公開11件と program（12.1） | 正しい（中3の対応が要る） | block の場合を足す。Exits に block がないと、Rust と受理が食い違う |
| Coverage の補題U・網羅性/選ばれない分岐の系（12.1・12.5） | 正しい | 型が Integer の値は正準形から `.const (.integer n)` で、n は部分型により有界である。全値への追加の不変条件はいらない |
| `HasTypeCL`・`HasTypeC := HasTypeCL []`（12.2） | 正しい | Q の前例と同じく添字を足して公開名を空の入口にする。値の判断には Δ はいらない（重1の付記） |
| `LocalScoped`・`NoFreeBuilders`（12.2） | 正しい | 共有番号では、番号の範囲の述語に LocalRef の場合を足す形になる |
| `BuilderCellOk`（12.2） | 仮定が要る | 中1の A を採るなら、長さの上限を含める必要がある。List の要素は Ψ で型付けする |
| `OrdinaryStoreEq`（12.2） | 定義の精密化が要る | `.val` のセルに限らないと、遅延の更新と継続の破棄で偽になる（軽1） |
| `local_rename_typed`・`local_subst_typed`・`ordinary_subst_local_typed`（12.2） | 正しい | 共有番号では既存の付け替え・置き換えの補題に LocalRef の場合を足すだけになる |
| `builder_env_project_lookup/up`（12.2） | 不要にする | 別の番号空間の案に固有の補題であり、共有番号では環境の写像が恒等になる（重1） |
| `builder_value_no_free_local`（12.2） | 今の定義案のままでは偽 | lam の本体を同じ Ψ で検査すると `loc` を含む lam に型が付く。lam・lazy の規則が `loc` を禁じる形が要る（中2） |
| `builder_step_no_event`（12.2） | 正しい | 中1の A を採るなら、上限超過のエラーの一歩も事象なしに含める |
| `builder_step_frame`（12.2） | 正しい | 専用操作は `.val` のセルを変えない（軽1の定義の下で） |
| `builder_copy_contents`（12.2） | 正しい | 抽象の不変内容を通常の値として返すだけである |
| `builder_store_extend`・`cont_local_store_weaken`（12.3） | 正しい | 既存の `StoreTy.Sub` による弱化と同じ形である |
| `capture_local_valid`・`resume_local_valid`（12.3） | 正しい | 継続のセルの枠は `ContTy` を Ψ で型付けし、専用セルは単調に残る。一回の再開の規則は変えない |
| `drop_local_silent`（12.3） | 書いたままでは偽 | `E_DropRel` は継続のセルを `.used` にする。`releases k' = []` と `σ' = σ.set κ .used` の形で書く（軽1） |
| `local_steps_invariant`（12.3） | 仮定が要る | 「通常値の非出現」は中2の規則（lam・lazy・遅延のセル）を定義に入れて初めて導ける |
| `snapshot_structure_stable`（12.3） | 正しい | Lean の値は不変なので、ほぼ定義から従う |
| `Integer64Value.toInt_bounds`（12.5） | 正しい | 部分型の定義から従う |
| `integer_atoms_partition`・`integer_full_no_other`・`integer_shapes_complete`（12.5） | 正しい | Character の有界区間の扱いを流用できる。`other` はガードなしの行の和が全域のときだけ空になる |
| `E_Block`・`Desugar(.block body) = desugarBlock body`（12.6） | 正しい | `pos` をそのまま最後の式へ渡すのは既存の if/match と同じで、末尾の block の中の return は `E_ReturnTail` で関数の戻り値型を要求する。lazy・ガードの中では R が none なので return は型が付かない |
| `block_desugar_typed`（12.6） | 正しい | 既存の Block の場合の系になる。Exits を含む相互帰納の全述語に block の場合を足す（中3） |
| `hole_args_plan_typed/scoped`（12.6） | 正しい | 直接の穴の参照は、固定式の Let の総数だけずらせばよい。今の `desugarHoleArgs` は穴ごとに `.ret (.var j)` を Let にしている（`Surface/Desugar.lean:374〜378`） |
| `checkLength_success_iff`・`checkLength_invalid_first`・`checkLength_projection`（12.7） | 正しい | design 7.1 の失敗の優先順（負の minimum か maximum < minimum を先に InvalidBounds）と一致する |
| `checkIndex_success_iff`・`checkIndex_failure_iff`・`checkedIndex_get_eq`（12.7） | 正しい | 失敗は OutOfBounds の一種類で、添字と長さを持つ |
| `nonEmpty_from_to`・`nonEmpty_head_tail`・`nonEmpty_map`（12.7） | 正しい | map は純粋な f の小モデルである。効果を伴う map の順序は、実装の照合で確かめる |
| 191 の I1/I2 の停止条件（6.2・12.5） | 閉じる見込み | δ は抽象であり、主定理・公理・Builtins.Assumptions を増やさない。中1の length だけが例外である |

## 確かめた事実（食い違いなし）

- 診断の番号: E0467・R0907 は `src/diag/codes.rs` で未使用である。design が再利用する E0213・E0214・E0216・E0218・E0301・E0326・E0339・E0340・E0401・E0402・E0408・E0416・E0439・E0451・E0463〜E0466・E0501・E0506・E0509・E0512・E0601・E0602・E0609・E0705・E0706・E1010・L0112・R0902・R0904・R0905・W0401・W0402 は、記述どおりの意味で表にある。R0906 までが使用済みで、R0907 は次の番号である。
- 命令の番号: `Opcode` の末尾は `Resume = 90`（`src/bytecode/instr.rs:75`）であり、91〜95 は空いている。
- 定数・型: `MAX_STRING_BYTES = 1_073_741_824`・`MAX_LIST_LEN = 16_777_216`（`runtime/mod.rs:18・20`）、`ResourceError::ValueTooLarge`、`HostData`（`runtime/heap/value.rs:309`）・`Trace`・`SlotOps`・`host_mut`（`runtime/heap/ctx.rs`）、`resolve::builders::BuilderId(pub BindingId)` と `BuilderOp`、契約名 `builder`/`text`/`texts`/`values`/`bytes`、`MAX_TREE_WORK = 600_000` と定義ごとの 4 倍、`in_io_all`、`check --report=json` の `schemaVersion: 1` と `basis: declaredUpperBound`、`ExternalRuntime::new(interrupt)`・`external::stats::ExecutionOptions`・`run_program_with_externals`/`run_test_with_externals`、tools/derive の `GENERATOR_VERSION = '2.0.0-syntax-batch3'`・`INVENTORY_VERSION = 2`・`HASH_VERSION = 2` は、design・plan の前提どおりである。
- 検査: plan が名指しする check.sh の単位名と、統合ターゲット（interrupt_process・external_signals・io_modes・l13_external_commands・coverage_export・desugar_export・named_arguments・verify・golden・random_programs・vm_handlers・vm_lazy・vm_reference_cells・call_allocations・declarations・checked_args・test_command・runtime_builtins・stdlib_doc_examples・property_library・skill_docs・fmt_command）はすべて実在する。compare の `--tier targets`・`--targets`・`--quick`・`--alloc`・`--estimate-from`・`--samples`・`--confirm-full` も実在する。
- 互換性: 追跡中の `.bnt` と、処理系・リファレンス・Skill・道具の中に、識別子 `block` の使用は見つからなかった。改造の文書から docs/todo へのリンクはない。
- 決定との一致: B17 の文法・診断・形式化の方針、I1〜I4、R11、R20、R103 は design・plan と一致している。重1・中1〜中3は、決定（A）を変えずに表し方と定義を補うものである。
