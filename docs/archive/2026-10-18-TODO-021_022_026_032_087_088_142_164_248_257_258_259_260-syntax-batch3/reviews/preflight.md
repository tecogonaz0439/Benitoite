# 0.0.9 の事前点検（段1の前）

対象は、ブランチ `mod009/design`（HEAD `2fb8a07e`）の本ディレクトリの design.md・plan.md・decisions.md（R101〜R115）・implementation-request.md である。これらを、処理系（crates/benitoite）・tools/derive・scripts・formal/ の実態と、試作 docs/todo/sources/2026-10-17-feasibility-spikes/ と照合した。レビュー担当は Opus 5.5、日付は 2026-10-18 である。リポジトリは本書のほかに変えていない。cargo と lake のビルドは実行していない。

## 結論

**先に直すべき点あり。** 重い指摘は一つである。構築器の Lean の表現（BuilderLayout による環境の番号の付け替え）は、既存の脱糖が番号を変えないこと（`.local i ↦ .var i`）と合わず、脱糖の署名・全補題・交換・DesugarDiff まで変更を広げる。番号の空間を共有する表現へ改めれば、既存の付け替え補題がそのまま使え、L4〜L6 の規模も危険も下がる。RV1 の前に design 14.5・R108・plan L3〜L6 を直すことを推す。ほかの指摘は、計画へ一文〜数行を足せば済む。

指摘の数は、重 1・中 8・軽 13 である。

## 重

### 重1 BuilderLayout による番号の付け替えは既存の脱糖と合わず、L4〜L6 を大きく広げる

- 箇所: design 14.5「脱糖では…`BuilderLayout Γ Δ Γcore` を定義する」と、補題表の `BuilderLayout.lookup/underValue/underBuilder`。decisions R108。plan L3（Layout と束縛追加の補題）、L4（「通常のbindと生成letの変数移動をLayoutへ通す」）。
- 問題: design は、Δ を Γ と別の de Bruijn の番号空間にしている（`Expr.builderOp : BuilderOp → Nat → …` の Nat は Δ の位置）。そのうえで、Γ の位置と Δ の位置をコアの位置へ写す単射を持つ。ところが今の脱糖は、環境を引数に取らない構文上の関数である。局所変数は番号を変えずに写し（`formal/Benitoite/Surface/Desugar.lean:150` の `.local i => .ret (.var i)`）、型保存は表層とコアで同じ Γ を使う（`Surface/Lemmas/Typing.lean:370` の `HasTypeQ.desugar` は、`HasTypeQ … C Γ …` から `HasTypeCQ … C Γ …` を導く）。別の番号空間を写すには、`desugarExpr` 等の六つの相互再帰に対応表の引数を足し、構文の束縛ごとに対応を更新する必要がある。そうなると、脱糖の全場合（537 行）、脱糖を扱う 12 ファイル・186 行、`desugar_typed` の内部の言明、DesugarDiff と交換の脱糖の比較まで書き換えになる。plan L4 の 3〜6 時間には、この変更が入っていない。
- 根拠: 既存のコアの付け替え補題は `RenOk Γ Δ ξ := ∀ i a, Γ[i]? = some (some a) → Δ[ξ i]? = some (some a)`（`Release/Lemmas/Rename.lean:94`）で、`HasTypeCQ.rename`（同 223）がある。`E_Const` の脱糖でも、`ξ := id` で環境を移している（`Surface/Lemmas/Typing.lean` 380 付近）。`E_Local` は `Γ[i]? = some (some a)` を要求するので、`none` の位置は通常の変数として参照できない（`Surface/Typing.lean:85`）。Γ を伸ばす規則は少ない。B_Bind・B_BindPat・Arms・E_With・E_HandleFail の節・E_Handle の節・E_Lam だけである（Typing.lean 142・411・486・509・531 ほか）。
- 修正案: 構築器のセルを Γ の位置に `none` として置き、番号の空間を一つにする。
  - Δ は Γ の先頭にそろえた `List (Option BuilderKind)` とする。Δ の方が短くてよく、Δ を越える位置には構築器がない。
  - `builderBind` は Γ に `none`、Δ に `some k` を積む。通常の束縛は Δ に `none` を積む。lambda・lazy・節（handleFail の節を含む）は Δ を `[]` にする。それ以外の部分式（if/match の分岐・ガード、with の本体、引数、try、return）は同じ Δ を渡す。
  - `builderOp op i` は `Δ[i]? = some (some k)` を要求する。
  - 脱糖は番号を変えない。`builderBind k rest ↦ letIn (Reference.new init) (desugarBlock rest)`、`builderOp op i … ↦ … .var i …` となる。コアの環境は「Δ が `some k` の位置を `some (Reference (contents k))` に置き換えた Γ」で、表層の導出から `HasTypeCQ.rename (ξ := id)` でコアの型付けへ移れる。
  - これで、`BuilderLayout` と、その単射・移動の補題（`underValue/underBuilder`）がいらなくなる。通常の変数として参照できないこと（E0464 の規則）は、`E_Local` の既存の前提から得られる。捕捉の禁止は Δ を空にすることから得られる。
  - 交換 corpus12 の「局所番号」も、この一つの番号空間で表す。Rust の書き出しは今の局所番号の付け方を保てる。
  - R108 を改め、L3 の「Layout と束縛追加の補題」を「Δ と Γ の整列の不変条件と、コアの環境への写し」へ置き換える。この表現の選択は形式化の表し方の問題であり、Ty/Eff/Step・主定理・Builtins.Assumptions は変えない。RV1 で採否を確かめる。

## 中

### 中1 L4 の「旧内部実装との同値の橋渡し」は二重の相互帰納になる。Q のときの前例どおり、添字を足して公開名を abbrev にする

- 箇所: plan L4「必要なら旧内部実装を新内部実装との同値の橋渡しとして一時保持し」、R113、design 14.5「内部版の名前を `HasTypeBuildersQ`…」。
- 問題: 七判断（`HasTypeQ`・`HasTypesQ`・`HasEachQ`・`HasHoleArgsQ`・`HasArmsQ`・`HasClausesQ`・`HasBlockQ`。Typing.lean 82〜491）を別名で複製し、同値を相互帰納で示すと、約 500 行の定義と同値の証明が一時的に増える。しかも、構築器の本体の Δ は空ではないので、既存の補題はどのみち任意の Δ へ一般化しなければならない。
- 根拠: Q を足したときは、既存の帰納型に添字を足し、公開の `HasType` 等を `abbrev HasType … := HasTypeQ D B op Qempty` とした（Typing.lean 543〜573）。`HasTypeQ` は 14 ファイル・311 行、`HasBlockQ` は 10 ファイル・111 行で使われている。
- 修正案: 名前を変えずに、既存の七判断へ Δ の添字を直接足す。外側の入口（Program.WellTyped と checker の入口）は `[]` を渡す。橋渡しの案を消す。重1の表現と合わせれば、既存の規則の多くは Δ をそのまま渡すだけになる。

### 中2 L7 の corpus12 は、数を一つ上げるだけでは旧版の受理を壊す

- 箇所: plan L7、design 14.6、R108「包みの版4は形が変わらなければ保つ」。
- 根拠: `formal/Benitoite/Exchange/Version.lean:124-145` の `exchangeJson` は、corpus と他の形式で `current := if corpus then 11 else 4` を共有している。`version < current` なら 11/4 の欄（effParams・noFail・dictCount・handleFail 等）を拒否し、受理するのは `current` と `current-1`（corpus はさらに 9）だけである。147〜148 行の `sidecarVersion` は `corpusVersion == 11 then 4 else if ≥ 9 then 3` である。
- 問題: current を 12 にすると、corpus11 は自分の欄を拒否され、corpus10 は受理されなくなる。corpus12 には包みの版 3 を要求することになる。
- 修正案: L7 の手順に次を書く。(1) 版の判定を corpus と他の形式で分ける。(2) 受理する corpus の版を 8/9/10/11/12 と列挙する。(3) `sidecarVersion` を `≥ 11 → 4` にする。(4) 既存の test_*_exchange.py が旧版を通し続けることを L7 の完了条件にする。(5) Rust の書き出し（`tests/desugar_export/{lib,named}.rs` の `"version":11`）と `check_named.py` の版の照合を、B3 で切り替える対象として名指しする。

### 中3 二引数の型構成子の型クラスには、受理から実行まで通った前例がない

- 箇所: plan M1・L2、design 6・14.4。
- 根拠: `F[_, _]` が現れるのは、種類の検査（`typeck/traits/collect.rs` 72〜85・226〜243）と負例（`typeck/traits/tests.rs:451` の E0427）だけである。Trait.bnt の型クラスは、すべて `F[_]` か `T` である。Result を裸の型構成子として実装した例も、golden にはない。Lean では、Surface の例に高カインドの型クラスの具体例がない（`.tapp` は CheckToolsExamples の小例だけ）。
- 修正案: M1 の最初の区切りを「二引数の型構成子の型クラスの最小の正例が、型検査・辞書の脱糖・VM・交換を通る」とする。不具合が出たら段1へ戻すかどうかを相談する、と書く。L2 の Monad2Examples も、`.ctor (.data "Result")` を型クラスの対象にしたときの `Ty.WF`・`SatAll` を最初に確かめる手順にし、見込み（2〜4 時間）にこの不確実さを含める。

### 中4 K1: `resolve::BindingInfo` は存在しない。レコードは型名と構築子が一つの束縛を共有する

- 箇所: design 2.2、plan K1。
- 根拠: 実体は `resolve::Binding`（`resolve/mod.rs` 103〜120）で、宣言元の `module` を既に持つ。親型は `BindingKind::Ctor{data}`・`Field{record}` から引ける（同 33〜41）。レコードでは `BindingKind::Record` の一つの束縛が、型名と構築子を兼ねる（`resolve/lookup.rs` 305〜311 の `record_values`、346〜370 の `record_call_name`）。パターンの構成子・レコードは `resolve/shadow.rs` 176・182 で解決する。
- 問題: 束縛の種類だけで遮断すると型注釈まで拒否してしまう。また、触るファイルに shadow.rs がない。
- 修正案: opaque の印は、Data/Record の型の束縛（または collect の私有の表）に一つだけ置く。判定は「使用位置（Value・Record 構築・パターン・Field を指す Value）×束縛の種類×親型の module と使用元の module」とし、`checked_name`・`record_call_name`（lookup.rs）と shadow.rs の二箇所に置く。K1 の触るファイルに shadow.rs と、gen_skill の属性の表示（`cli/tools/skill/generate.rs:491` の extensible の扱い）を加える。式にフィールドを取り出す構文はないので、自動アクセサ・パイプ・部分適用・値化はすべて Value の位置を通る。typeck/records.rs に判定を重ねる必要は薄い。

### 中5 K2: 「全体で共有する 64 MiB」は今の定数評価の作りと合わない

- 箇所: design 5.1、plan K2。
- 根拠: 本体の中の定数の評価 `consts::warnings`（`typeck/consts.rs` 1012〜1127。generate.rs 152 から本体ごとに呼ぶ）は、検査のたびに `EvalBudget::default()` を作る（1072・1099・1120）。トップレベルの const の評価にも別の予算がある（90。上限は 278 の 64 MiB）。`eval`（399）は、const の出どころと引数の位置を返さない。
- 修正案: K2 の手順に次の三つを書く。(1) 全体の予算を置く場所と、消費する順（本体の検査順）。既存の警告の予算と分けるかも決める。(2) eval に出どころ（constOrigins）を集める追跡を足すこと。(3) 呼び出しの同定は、既存の `std_call`（174）と `standard_argument`（543）を土台にし、新しい checked_args.rs と重複させないこと。0.0.8 の挙動に頼る既存の例 `testdata/stdlib/l40-regex.bnt:24`（`Result.isError(Regex.compile("["))`）を名指しし、design 5.3 どおり動的入力の関数へ移す手順も書く。

### 中6 B1: `Benitoite.StringBuilder` 等を import できるモジュールの作り方が書かれていない

- 箇所: design 7.1、plan B1。
- 根拠: 標準モジュールは、`src/prelude/mod.rs` の `STDLIB` に置いた .bnt ソース（`include_str!`）だけで構成される。一方、構築器は「通常の型・関数ではない局所分類」であり、.bnt では宣言できない。局所の束縛の種類は `resolve/mod.rs` の `Local(LocalKind)` である。
- 修正案: B1 の触るファイルと手順に次を書く。STDLIB へ加える項目の形（doc だけの .bnt か、表だけの項目か）。import の解決と、修飾名 `StringBuilder.append` 等の解決の経路。bind の型注釈の位置だけで StringBuilder 等を解決する扱い。gen_skill の標準参照に契約を出す経路。あわせて、構築器の bind がブロックの最後の文のときの扱いを決める。Lean には `Block.lastBind` があり（Typing.lean 499）、design 14.5 は `Block.builderBind … Block` しか定めていない。E0463 で拒否するか、Unit とするかを書く。

### 中7 G1 で既存の test_derive.py の一致の検査が落ちるのに、計画に書いていない

- 箇所: plan G1・G4、R114。
- 根拠: `tools/derive/test_derive.py:734-756` の `test_json_and_property_two_modules_all_basic_types_and_containers` は、同梱の People/Address/derive.json/derive.generated.json を写し、`check()` が成功して preview の差分が空であることを求める。G1 で記録を版 2 にし、旧記録を migration_required にすると、G1〜G3 の間このテストは落ち続ける。
- 修正案: G1 で、このテストを「旧記録なら migration_required」を確かめる形へ移し、G4 で元の主張（新しい manifest を apply した後に check が成功し、差分が空）へ戻す。どちらも test-audit の作成時の関門を通し、主張を変えていた期間を results に残す。

### 中8 全比較の固定記録の件数を直す担当がない

- 箇所: plan の検査の割り当て、B3、改造末の check-formal。
- 根拠: `crates/benitoite/tests/desugar_export/exchange-manifest.json` と `routing-manifest.json` は、入力ごとの定義の件数を固定して持つ。読むのは `check_named.py`・`check_failure.py` だけなので、普通の work では食い違いが見つからない。前回は、これで check-formal を 3 回やり直した（`docs/archive/2026-10-17-…/results.md` 93〜95 行）。今回の K3・K4・M1・G3・G4・H3 は、標準ソースと生成コードの定義の数を変える。
- 修正案: 二つの manifest の更新を、上の作業の触るファイルに加える。または、最後の check-formal の前に取りまとめが作り直して差分を確かめる手順を置く。どちらでも、件数の差を項目ごとに説明させる。

## 軽

1. design 7.2 の表（Δ を引き継ぐ場所）: 「lambda・lazy・節（handleFail の節を含む）だけが空の Δ、それ以外の部分式（with の本体、match のガード、引数、try、return を含む）はすべて同じ Δ」と書く。Task は lambda を受け取るライブラリ関数で、defer やループの構文はないので、境界はこれで足りる。
2. design 14.2 の Scope の小モデル: `.one []`・`.many []`（空の幹）と空の対象は parser が作らないが、モデルでは表せる。構文の妥当性を表す述語（ラベルが空でない等）を、parser との対応の前提として定義しておく。そうすると、`one_excludes_apex` 等の具体例と対応表の前提がはっきりする。定理の真偽には影響しない。
3. design 14.2 の `mayInspect_iff`・`importAlias_preservesOwner` は、定義からほぼ自明である。文書としての役割だと明記し、L1 の時間をここに使わない。
4. design 5.2: 「静的に拒否する呼び出しは、実行時に必ず Error を返す」という不変条件を明記する。部分的に既知の Endpoint の検査（R102）が正しいことの基準になる。L1 の小モデルで、makeEndpoint について言明してもよい。
5. K2: regex 1.13 の `Error` は `#[non_exhaustive]` である。E0457/E0458 以外の将来の種類は Unknown として実行時へ残す、と決めておく（今は `error.to_string()` を切り詰めているだけ。`builtins/funcs/regex.rs` 127〜153）。
6. K2・K3: 今の typeck は builtins を参照しない。純粋な判定の本体を builtins/funcs/regex.rs と builtins/checked_scope.rs に置くと、typeck→builtins の依存が新しく生じる。ヒープと runtime に依存しない場所に置くこと、この依存を許すことを R 番号で残す。
7. K3: Rust の組み込みの関数が CheckedHost・ScopeError の値をどう作るかが書かれていない。組み込みの関数は構造化した単純な値（正規化した文字列、失敗の番号、reason）だけを返し、Scope.bnt で opaque レコードと ScopeError を組み立てる案が単純である。固定タグ（`builtins/table.rs` 95〜135）を加える案もある。どちらかを書く。
8. E0260: E02xx はすべて構文解析の段の番号である（`diag/codes.rs` 384〜418）。--doc のときだけ出る形式の誤りをこの帯に置く理由を、一言書く。
9. T1: 触るファイルに `typeck/traits/solve.rs` を加える。`ClauseBounds`（321）が、Body の表を `&NodeMap` のまま受け取る。`base::NodeMap` 自体は変えずに私有の型を作ること、今の NodeMap には `get_mut` がないことも書く。
10. T1: `typeck/decls.rs:19-22` の `Scope{params, effects: BindingMap}` も、本体ごとに作る密な表である。対象にするか、対象外とする理由を書く。
11. T3: `ITy`・`IEffect`・`Reason` は `Clone, PartialEq, Debug` だけを持つ（`infer.rs` 25・53・190）。索引のために Eq/Hash/Ord を足すか、構造の写しを鍵にするかを書く。
12. G3・G4: 言語にループはなく、maxShrinkWork は最大 1,000,000 である。縮小の駆動・mapSteps・appendSteps を末尾呼び出しで書くこと、上限の近くでスタックが溢れない回帰テストを持つことを完了条件に足す。
13. M1: 括弧付きの関数型の型引数（`Result[(function(value: A) -> B uses E), X]`）を、formatter が括弧を落とさずに保つことを確認項目に足す（`TypeExpr::Paren` は parser/types.rs 17・153 で受理する）。G1 の触るファイルには、入口の `examples/derive_inventory.rs` も書く。

## 段1（全 Lean）の定義・言明・仮定について

- 偽の言明は見つからなかった。design 14.2〜14.4 の主な言明は、定義どおりなら成り立つ。`makeHost_ok`、`make_invalidBounds_iff`（逆転を先に検査する定義で ↔ `hi < lo`）、`make_outOfRange_iff`（↔ `lo ≤ hi ∧ ¬InRange`）、`erase_*`、`flatMap` の三法則、`map_identity`・`map_composition`、`map_flatMap`、`apply_flatMap`（fs が Error なら fs 側、Ok f なら `map x f`）、`one_excludes_deep`（長さで区別できる）、`path_tree_includes_self`（`rest = []`）がそうである。試作の半開区間（`< hi`）と、Nat のポートの比較からの修正も拾えている。
- 主定理の前提・結論、公理、Builtins.Assumptions: セル操作は既存の `refNew/refGet/refSet` の組み込みの種類の仮定（`Release/Assumptions.lean` 25〜32）で足りる。`BuilderRefs.Ok` を宣言表で検査する方針なら、仮定を加える必要はない。重1の表現にすれば、コアの環境への移行は既存の `HasTypeCQ.rename` で済み、新しい外部の前提もいらない。
- 07-04 の内外の判定: opaque は名前解決で外側、内部の型表に全構成子を残すので、コアは変わらない。Scope/Range は本体の外の小証明、構築器は内側。これらは妥当である。Scope/Regex の定数拒否をソース段の責任として列を分ける扱いも妥当である。
- 区切り（L4〜L6 で lake build を保つ）: 中1の方法（既存の七判断に添字を足し、公開名を abbrev のまま残す）と重1の表現なら、L4 は「Δ を通すだけで既存の全表層が通る」状態で区切れる。L5 は Expr.builderOp を足して全読者を直す単位、L6 は Block.builderBind を足して全体を閉じる単位になる。今の Layout 案のままでは、L4 に脱糖の署名の変更が入り、区切りの規模が見込みを超えるおそれが高い。
- 試作との比較: LocalBuilder の局所の印と popHeap を採らないこと、Lowering の限定変換を本番の証明にしないこと、OpPacket（高カインドの引数を操作へ許すモデル）を取り込まないことは、design に書かれている。試作の別の文脈 `Fin n` をそのまま本番の表現に写すと、重1の問題になる。本番の脱糖は番号を変えないので、番号の空間を共有する方がよい。

## R109 と R112 への意見

- R109（doctest の JSON 報告）: 推す案（`--doc --check --report=json` だけを testCheckReport 版2にし、`--doc` なしは版1を保つ）に賛成する。ただし、実行の JSON Lines に docExample/docSummaryの行の種類を足す変更も、読み手（skill-eval のハーネス等）から見れば形式の変更である。`--version=json` の formats に版を出すか、06-01 が「未知の種類の行は無視する」と定めているかを、H2 の前に確かめる。設計者に確認。
- R112（時間の目安）: 一作業 30〜60 分を見直しの目安にとどめ、総時間を明示する方針は妥当である。ただし、幅の下側は楽観的に見える。前回の Lean は L1b が c7 まで続き、L2b は 6〜12 時間に見直した。T・G・H は S3 の見積もり（`study/riders.md` 302〜313 行）の約半分で、根拠の内訳がない。L4 は重1の表現にしたうえで 4〜8 時間、G4 は 6〜10 時間とすることを推す。S3 との差は R112 に作業ごとに書く。設計者に確認。
