# L20.5 の結果: 項の範囲と `V_Prim`（一度の切り替え）

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L20.5（plan-l10-l50「L20」の表の L20.5 の行）。担当は Claude のサブエージェント |
| B_WORK | `d95f76181f7a6f52a6df6ef1b1a7982b1ef73cea`（本線、L20.4 の取り込みの後）。作業用のディレクトリ `<wt>`、ブランチ `m013/l20.5`。git の状態は変えていない |
| 状態 | **完了**（停止の後の再開）。最初の試行で停止の表にない前提の変更などが見つかり、一度停止した（「停止の理由」S1〜S4）。取りまとめが四つの問いに推す案で答え（「回答」）、本体を再開して閉じた。既定の全入口のビルドが sorry なしで通る |
| 閉じた範囲 | 依頼の 2〜8 の全て。項 `.prim` の範囲の列、`V_Prim` の具体化、δ の範囲の列と三つの欄の量化、`inv_prim` 群・`PrimitiveAdmissible.outer`・`.substTy`、`E_OpPrim` の拡大、`sig_scoped`・`hsig` の切り替え（`PrimSig.Scoped`）、旧の像での同値、中間状態（脱糖と交換は空の列）、閉じた非 Top の値の小例、設計書。試行で `sorry` にした 12 宣言は全て証明した |
| 未完 | なし（計画の L20.5 の行の範囲）。小例の表が `Builtins.Assumptions` を満たす実例は L20.7（新版の `Model.assumptions`） |
| 適用した前提の変更の行 | 停止の表の L20.5 の行（問 18 の行 2・4・6、`TargetRangesOnly`、`hsig`）と、回答で例外として扱うと決まった S1（操作の結果の型の条件）・S3（`StoreShape` の `rkinds = []`）・S4（表層の `s.nranges = 0`。表の L40.4 の行の一部の前倒し） |
| 停止条件 | 停止の後は該当しない。`Builtins.Assumptions` の欄の追加・公理の追加・主定理の字面の変更・結論の弱化はない |

## 試行（最初の約25分）

plan「検査の割り当て」の「L の一度の切り替えの試行ビルド」の行に従い、`<wt>` の formal で排他の道具の `lake build`（既定の全入口、`-M 12288`）を回した。Lake は失敗したモジュールを import する先を検査しないので、L20.4 と同じく、壊れた宣言を直しては全体のビルドを繰り返した。機械的に直せない宣言は、件数を下の層まで数えるために、試行の中でだけ `sorry` に置き換えた（12 宣言。下の「分類」）。

当てた中心の変更（試行の形。本体でもこの形を出発点にできる）:

| 対象 | 試行の変更 |
|---|---|
| `Val.prim`（`Release/Syntax.lean`） | 範囲の列 `rs : List Scope.Domain.Range` を末尾の引数に加えた（問 5） |
| `Builtins.delta`・`ioResponse`・`Oracle` | 型引数・行引数の後に範囲の列を受け取る |
| `PrimSig.inst`・`Builtins.RangeAdmissible` | `V_Prim` から使うため、具体化の関数（`Atom.instR`・`Eff.instAtoms`・`Ty.rawInstR`・`Ty.instR`・`Eff.instR`・`Ty.instTarget`）を新しいファイル `Release/RangeInstDef.lean` に移し、`PrimSig.inst` と `Builtins.RangeAdmissible` を `Release/Typing.lean` の `Builtins` の直後に移した。`PrimSig.topRanges`（長さ `nranges` の Top の列）を加えた |
| `V_Prim` | `B.sig b = some s → B.RangeAdmissible b s rs → NamesWF (s.inst rs).names (s.inst rs).params → PrimitiveAdmissible C (s.inst rs) Q ts es → HasTypeVQ … (.prim b ts es rs) (fnTy (s.inst rs).names (s.inst rs).params (s.inst rs).ret (s.inst rs).eff ts es)` |
| `Builtins.Assumptions` | `delta_typed`・`io_typed`・`io_exists` に `rs` と `B.RangeAdmissible b s rs` を加え、引数と結果を `s.inst rs` で型付ける。`io_kind` は `rs` を量化するだけ |
| `PrimSig.Scoped`（`sig_scoped`・`hsig` が読む定義） | 範囲の変数の文脈を `s.nranges` にし、5 番目の連言に引数の位置の条件（各引数は不透明型か `Ty.VarsIn 0 …`）を加えた。`Builtins.Assumptions` と `desugar_typed` の字面は変えずに済む。`PrimSig.TargetRangesOnly`（L20.3 の `Ty.RangesIn` の形）は補題 `PrimSig.Scoped.targetRangesOnly` で取り出す |
| 遷移 | `E_Prim` などが `.prim b ts es rs` を読み、δ・応答・oracle に `rs` を渡す。`E_RefUpdate` と `step` が作る `Reference.get`・`Reference.set` の呼び出しには空の列を書いた（S3） |
| 脱糖・交換 | 空の列を書いた（S4） |

### 回ごとの件数

| 回 | 診断 | 失敗したモジュール | 未検査 | 内容 |
|---:|---:|---|---:|---|
| 1 | 3 | `Release.Subst` | 226 | 代入・改名の腕 |
| 2 | 11 | `WellFormed`・`Lemmas.Rename`・`Lemmas.Inversion` | 204 | `Val.VarsIn` の腕、`V_Prim` の場合（3）、`inv_prim` |
| 3 | 37 | `Admissible`・`RangeWF`・`Examples`・`Lemmas.Closed`・`Lemmas.Regularity` | 192 | `of_noRows`、L20.2 の同値の補題、例の表と項、`Val.VarsIn` の相互帰納（5）、正則性の `V_Prim` の腕 |
| 4 | 6 | `RangeInst` | 187 | L20.3 の同値の補題（`Scoped` の形の変更）、例の表 |
| 5〜6 | 1・1 | `Lemmas.OuterC` | 184 | `PrimitiveAdmissible.outer` |
| 7 | 11 | `Lemmas.TySubstMain`・`Surface.Desugar` | 107 | `opSig_scoped`、型代入の `V_Prim` の腕、脱糖の `.prim`（7 箇所） |
| 8 | 39 | `Lemmas.Canonical`・`Surface.Lemmas.Invariants`・`Surface.Check` | 88 | 標準形の `prim` の場合、表層の clean の不変条件、実行できる検査器（S4 の注） |
| 9 | 20 | `Canonical`・`Invariants`・`Surface.CheckTables`・`CheckCounterexamples` | 69 | 同上の残り、表の δ |
| 10 | 27 | `Exchange.Convert`・`Lemmas.PresBase`・`Invariants`・`Surface.CheckExamples` | 59 | `store_prim_inv`・`refUpdate_typed`（S3）、交換、表層の例 |
| 11 | 34 | `Exchange.Convert`・`Lemmas.PresMain`・`CheckExamples`・`Surface.Lemmas.Extensions`・`ExtensionsScoped`・`ReturnTry` | 39 | 保存の `E_Prim`・`E_IO`・`E_OpPrim`（S1）、表層の `V_Prim` の利用 |

未検査は、その回に失敗したモジュールを推移的に import するモジュールの数である（`l00.06b/tools/unchecked.py`、試行の最後の import の関係で数えた。import の閉包は 288 モジュール）。回 11 の後に未検査で残るのは 39 モジュールで、`Progress`・`StepSound`・`EffectSound`・`Theorems`・`Model`・`Membership`・表層の型の保存の補題の大半・交換の入口を含む。ビルドの時間は回ごとに 1.75〜147.55 秒だった。

### 変えた宣言の分類（回 11 の時点）

試行の差分を宣言へ対応付けた（`l00.06b/tools/decls.py` を使った。[trial/trial-decls.tsv](trial/trial-decls.tsv)）。41 ファイル、104 宣言（theorem 50、def 39、example 5、inductive 3、structure 2、abbrev 2、ほか 3）。このうち機械的でない 12 宣言を試行の中で `sorry` にした: `PrimSig.scoped_iff_old`・`sig_scoped_iff_old_of_rangeFree`（`RangeWF`）、`PrimSig.scoped_iff_scopedRanges`・`PrimSig.inst_of_scoped`・例 1（`RangeInst`）、`opSig_scoped`・`HasTypeVQ.substTy` の `V_Prim` の腕（`TySubstMain`）、`store_prim_inv`・`refUpdate_typed`（`PresBase`）、`opSig_clean`・`HasTypeQ.clean` の 2 腕（`Surface/Lemmas/Invariants`）。残りは場合・引数・表の腕の追加と、`inv_prim`・`inv_prim_app`・`PrimitiveAdmissible.outer`・`.substTy` の言明の具体化への書き換えである。

`HasTypeVQ.substTy` の `V_Prim` の腕と表層の clean の不変条件は、具体化した署名が `Ty.VarsIn 0`（型の変数と行の変数の上限を含む）を満たす補題を要する。L20.3 の `PrimSig.inst_wf_zero` は `Ty.WF` だけを与えるので、`Ty.instR`・`Eff.instR`・`Ty.instTarget` が型の変数と行の変数の上限を保つ補題を新しく置く必要がある（停止条件ではない。本体の作業）。

### 見込み

S1〜S4 の扱いが決まった後の本体は、試行の差分の上で、上の 12 宣言の証明、未検査の 39 モジュールの追随（保存・進行・`step_sound`・`Model.assumptions` の証明し直しを含む）、`fieldNew_iff_old`・`fieldNew_extend` の本番版、非 Top の小例、設計書になる。担当の推測で 3〜6 時間であり、枝の上端（3.5時間）を超え、上端の2倍（7時間）に近づく見込みがある。S4 で表層の構文に範囲の列を持たせる案を採ると、表層の側の追随（表層の型付けの規則と検査器、表層の例）が加わり、上側に寄る。代案（新しい定義を並べて一群ずつ移す方式）に切り替えるほどの差はないと考えるが、S1〜S4 の答えによる。

## 停止の理由

### S1 組み込みの操作の結果の型の範囲の変数（表にない前提の内容の変更）

- 言明: 計画は「節の添字は Top のまま、捕捉した引数を Top の型へ拡大する補題で `E_OpPrim` を閉じる」とする。`E_OpPrim` の保存（`pres_op_common`）は、呼び出しの結果の型が節の操作の型の結果に等しい（正確には `Ty.Le (Ty.subst ts [] sg.ret) a`。`a` は継続の穴の型）ことを要する。節の操作の型を Top の列で具体化した署名から取ると、呼び出しの結果の型 `(s.inst rs).ret` と節の側の `(s.inst topRanges).ret` は、署名の結果の型に範囲の変数があると一致しない。
- 理由: 節は継続 κ を `cont sg.ret …` の型で受け取り（`HasTypeClausesQ.cons`）、`resume` に `sg.ret` の型の値を渡せる（`C_Resume`）。引数と違い、結果は Top から R へ狭められない。
- 反例の形: io の項目 `b`（`opEff = some l`、`rkinds = [path]`、引数 `Scope.PathIn[rvar 0]`、結果 `Scope.PathIn[rvar 0]`）は、試行の `sig_scoped`（範囲の変数の上限と `TargetRangesOnly`）と今の `io_op`（効果は名前だけ）を満たす。`handle (let y ⇐ b[/data/**](p) in File.writeTextIn[/data/**](y, …)) with { b(x, k) ⇒ k(q) }` で、節の本体は `q : Scope.PathIn[Top]`（`valKind` が path なら V-Checked で `/etc/x` の検査済みの値も型付く）で `resume` できる。遷移の後、`y : Scope.PathIn[/data/**]` を期待する継続に `/etc/x` が渡り、状態は型付かない。したがって条件を足さなければ `preservation` は成り立たない（Lean での反例は作っていない。規則の字面からの導出である）。
- 未証明の部分: 試行の `PresMain` の `E_OpPrim` の腕（回 11）。
- 代案:
  - (a)（推す）`PrimSig.Scoped` に「組み込みの操作の項目（`opEff = some l`）の結果の型は範囲の変数を持たない」を、`TargetRangesOnly` と同じく連言で加える。`sig_scoped`・`hsig` の字面は変わらない。問22 の IO の項目（結果は `Result[String, IOError]`・`Result[Bytes, IOError]`・`Result[Unit, IOError]`・`Result[Http.Response, NetworkError]`）と既存の終了の項目（結果は型の変数）は満たす。範囲の変数を結果に持つ `checkPathIn`・`checkRequestIn`・`widenPathIn`・`widenRequestIn` は pure なので、条件の対象外である。
  - (b) `V_Prim` の前提に置く（型付けの規則を変える。L20.3 の `TargetRangesOnly` で採らなかった置き場所）。
  - (c) L20.7 の `shapeOk` に置く（L20.5 に間に合わない）。
  - (d) 節の型付けを呼び出しの R ごとにする（節の添字 S の L30.1・L30.2 の内容を前へ動かす。S を R より広く選ぶ場合も結果の型は狭められないので、(a) の条件はどのみち要る見込みである）。
- (a) を採ると、節の操作の型 `opSig` の引数を `Ty.instTarget s.topRanges` で具体化し、結果は `s.ret` のままにできる（S4 の注の計算可能性も保てる）。

### S2 `step_sound` の `horacle` の字面

- 言明: 計画の手順「δ と応答の関係が範囲の列を受け取り」のとおり `ioResponse` に `rs` を足すと、`Oracle` も `rs` を受け取る必要があり、`step_sound` の前提 `horacle : ∀ b ts es ws o, B.ioResponse b ts es ws o → B.ioResponse b ts es ws (oracle b ts es ws)` の字面が `∀ b ts es rs ws o, …` に変わる。全枝に共通する条件は、`horacle` の字面の変更を L20.6（観測）にだけ認めている。
- 理由: `step` は `oracle` を呼んで応答を選ぶので、応答の関係の引数と `oracle` の引数をそろえる必要がある。
- 代案:
  - (a)（推す）`ioResponse`・`Oracle` には範囲の列を足さず、δ にだけ足す。問5 の決定の文言は「δ は範囲の列を受け取り」であり、問18 の行 2 は `io_typed`・`io_exists` を rs について量化すること（引数と結果を `s.inst rs` で型付ける）を求めるだけなので、どちらにも合う。IO の応答は、範囲を検査済みの対象の値（引数）から読める。`horacle` と `step_sound` の字面は変わらない。L20.7 の `io_target` が R を要るなら、`io_target` の欄の中で rs を量化する。
  - (b) 計画のとおり `ioResponse` に足し、`horacle` の字面の変更（rs の量化を加えるだけ。範囲の列を見ない旧の表では内容が同じ）を L20.5 で受け入れる。L20.6 の観測の量化はその上に重ねる。

### S3 `Reference.update` の遷移が作る呼び出しの範囲の列（表にない前提の内容の変更）

- 言明: `E_RefUpdate`（と `step`）は `Reference.get[A]`・`Reference.set[A]` の呼び出しの項を作る。項が範囲の列を持つので、遷移が何かの列を書く必要がある。空の列を書くと、保存（`refUpdate_typed`）は `V_Prim` の `RangeAdmissible B.refGet sg []`、つまり `Reference.get`・`Reference.set` の項目の範囲の変数の個数 0 を要する。`store_shape`（`PrimSig.StoreShape`）は名前・型パラメータ・引数・結果・効果を固定するが、`rkinds` を固定しない。
- 代案:
  - (a)（推す）`PrimSig.StoreShape` の可変のセルと明示遅延の五つの種類に `s.rkinds = []` を加える（`store_shape` の内容の変更。旧の像の表は全項目が `rkinds = []` なので同値）。
  - (b) `E_RefUpdate` が `B.sig B.refGet = some sg` を前提に持ち、`sg.topRanges` を書く（遷移の規則の前提と項の変更。`progress` の結論の `Step` が変わる）。
  - (c) `sig_scoped` に同じ条件を置く（(a) と内容は同じで、置き場所だけが違う）。

### S4 脱糖が長さ `nranges` の Top の列を書けない（計画の手順の前提が成り立たない）

- 言明: 計画は「脱糖と交換は長さ `nranges` の Top の列を書き、表層の `V_Prim` は Top の列で具体化した署名で型付ける」とする。`desugarProgram opPrim p` は組み込みの表 `B` を受け取らないので、項目の `nranges` を知らない。`B` を渡すと `desugar_typed` の字面（`desugarProgram opPrim p`）が変わる。演算子・文字列の連結・`die` の終了の呼び出し（`opPrim` と `DieExitOk` が与える名前）も同じである。交換の読み込み（`Exchange/Convert.lean` の `fromVal`）も表を持たない。
- 試行では空の列を書いた。この場合、`desugar_typed` の証明は、表層が型付けた呼び出しの項目の `nranges = 0` を要する（試行の未検査の範囲）。
- 代案:
  - (a) 表層の項 `primName` に範囲の列を持たせ（型の情報を付けた表層の構文の一部。型引数と同じく型検査器が書く）、表層の `E_Prim` が `rs = s.topRanges` を前提にして `s.inst rs` で型付ける。脱糖は列を写す。演算子・連結・終了の項目には、表層の前提（`E_Binary`・`E_Neg`・`StringAddOk`・`DieExitOk`）に `s.nranges = 0` を加える。表層の構文・型付けの規則・実行できる検査器・表層の例が変わり、`p.WellTyped` の内容は、範囲の変数を持つ演算子の項目の表でだけ狭まる。
  - (b)（推す。L40.4・L40.5 までの中間状態として最小）脱糖と交換は空の列を書き、表層の `E_Prim` と上の四つの前提に `s.nranges = 0` を加える。表層は範囲の変数を持つ項目をまだ呼べない（L40.4・L40.5 で表層に R を入れるときに外す）。`p.WellTyped` の内容は範囲の変数を持つ項目の表でだけ狭まり、旧の像の表では変わらない。表層の `V_Prim` は「長さ 0 の Top の列で具体化した署名（= 元の署名）」で型付けることになり、計画の文言の特別な場合にあたる。
  - (c) `opPrim` の型 `OpPrim` を範囲の列も返す形に広げる（`desugar_typed` の字面は変わらないが、`OpPrim` の意味が変わる。`E_Prim` の項には別に (a) か (b) が要る）。
- いずれも `p.WellTyped`（表の L40.4 の行）の内容の変更を L20.5 で一部行うことになる。表の L20.5 の行は `hsig` だけを挙げている。
- 注（計算可能性）: 表層の実行できる検査器（`Surface/Check.lean`。`SurfaceCheck` などの入口が使う）は `opSig` を呼ぶ。`opSig` を `s.inst s.topRanges` で書くと、`Ty.instR` が非計算的な `Ty.norm` を使うので、検査器がコンパイルできなくなった（回 8 の `failed to compile definition, consider marking it as 'noncomputable'`）。S1 の (a) を採れば `opSig` を計算できる `Ty.instTarget` だけで書ける。

### 取りまとめへ返す問い

1. S1: (a)〜(d) のどれにするか（推す案 (a)）。
2. S2: (a)・(b) のどちらにするか（推す案 (a)）。
3. S3: (a)〜(c) のどれにするか（推す案 (a)）。
4. S4: (a)〜(c) のどれにするか（推す案 (b)）。どれも表の L40.4 の行の内容の一部を L20.5 へ前倒しする。

S1・S3 は `Builtins.Assumptions` の欄の内容の変更（`sig_scoped`・`store_shape` が読む定義）であり、欄の追加ではない。`Builtins.Assumptions` の欄の追加、公理の追加は、どの推す案でも要らない見込みである。

## 停止の時点の記録

以下の「停止の時点の」節は停止の報告の時点の記録であり、本体の結果は後の「回答」以降にある。停止の時点の work の記録（`work-check*.log`・`work-check-time.txt`）は、作業末の work で上書きした（値は下の表に写した）。

### 停止の時点の変更と接続

停止の時点で受け渡した状態は「`formal/` を B_WORK の内容に戻した `<wt>` に、`l20.5/` の記録だけを足した状態」である（`git status --short` は `?? docs/…/l20.5/` だけを示す）。`formal/`・設計書・01-12・07-04 は変えていない。

| 記録 | 内容 |
|---|---|
| [trial/trial-final.diff](trial/trial-final.diff) | 回 11 の時点の試行の B_WORK からの累積の差分（新しいファイル `Release/RangeInstDef.lean` を含む。12 宣言の `sorry` を含む）。`git apply --check` が通る |
| [trial/trial-01.diff](trial/trial-01.diff) | 回 1 の前の中心の変更だけの差分（新しいファイルを含まない） |
| [trial/trial-build-1.log](trial/trial-build-1.log)〜[trial-build-11.log](trial/trial-build-11.log) | 回ごとの全出力 |
| [trial/counts.tsv](trial/counts.tsv)・[trial/trial-decls.tsv](trial/trial-decls.tsv) | 回ごとの件数、変えた宣言の一覧 |
| [lake-build-restore.log](lake-build-restore.log)・[lake-build-restore-time.txt](lake-build-restore-time.txt) | B_WORK の内容に戻した後の全体のビルド |

### 停止の時点の検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 試行の全体のビルド（11回） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 全て 1 | 1.75〜147.55 秒（ビルドの `real`） | [trial/](trial/) |
| 局所の単一ファイル（試行の途中） | `cd <wt>/formal && lake env lean -M 12288 <ファイル>`（`Subst`・`RangeInst` 3回・`OuterC` 2回・`TySubstMain` 3回・`PresBase`） | 0 か 1 | 各数秒（計時なし） | 本書 |
| 戻した状態の全体のビルド | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <l20.5>/lake-build-restore.log` | 0。434 ジョブ、`Build completed successfully`。`declaration uses 'sorry'` なし | 152.41 秒（ビルド） | [lake-build-restore.log](lake-build-restore.log) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base d95f76181f7a6f52a6df6ef1b1a7982b1ef73cea --dry-run` | 0。19 ファイルの変更（全て `l20.5/` の記録）、`nothing to check: only documents changed`。`formal/` を戻したので、plan-l10-l50「work の割り当て」の見込み（`formal_build` など）とは違う | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base d95f76181f7a6f52a6df6ef1b1a7982b1ef73cea` | 0。選択なし、`selected checks passed` | 0.07 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |

停止の時点では公理の確かめを行っていない（新しい定理を置いていなかった）。

### 停止の時点の最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。排他の道具の値は待ち合わせた子孫のうち最大の一プロセスの値で、並行した lean のプロセスの合計ではない。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 戻した状態の全体のビルド（下流の全てを検査し直した） | 2650570752 | 2527.8 | 2.47 |
| 試行の回 3 | 2252111872 | 2147.7 | 2.10 |
| work の検査全体（選択なし） | 10338304 | 9.9 | 0.01 |

試行のほかの回の値は各ログの末尾にある。局所の単一ファイルの検査は計時していない（値なし。0 ではない）。`-M 12288` は変えていない。

### 停止の時点の失敗と修正

- 試行の回 1〜11 は全て終了 1 であり、上の表のとおりである。回 8 で `opSig` を具体化で書いたために表層の検査器がコンパイルできなくなり（S4 の注）、回 9 から `opSig` を B_WORK の形に戻して件数を数えた。
- 正規表現で `V_Prim` の引数を一括で足したとき、`Release/Typing.lean` の一箇所で二重に足し、`Surface/Lemmas/Typing.lean` の表層の `E_Prim` の腕に誤って足した。前者は直し、後者は回 11 まで残した（その腕は未検査の範囲）。
- 記録のログの手元の絶対パスは `<wt>`・`<repo>`・`<home>` へ置き換えた。

### 停止の時点の申し送り

1. 計画からのずれ: 本体を進めず停止した（「停止の理由」）。
2. 試行の形のうち、S1〜S4 に依らない部分（`Val.prim` の末尾の範囲の列、`PrimSig.inst`・`RangeAdmissible` の `Typing.lean` への移動と `RangeInstDef.lean`、`V_Prim` の形、三つの欄の量化、`PrimSig.Scoped` の 5 番目の連言で `TargetRangesOnly` を含める形）は、本体の出発点に使える。`PrimSig.Scoped` に連言を足すと、既存の `hs.2.2.2`（効果の条件）の利用は `hs.2.2.2.1` に変わる。
3. 具体化した署名が `Ty.VarsIn 0 s.ntys (· < s.neffs)` を満たす補題（L20.3 の `inst_wf_zero` の `VarsIn` 版）が、型代入の `V_Prim` の腕と表層の clean の不変条件に要る。
4. L20.2 の `PrimSig.scoped_iff_old`・`sig_scoped_iff_old_of_rangeFree`、L20.3 の `PrimSig.scoped_iff_scopedRanges`・`inst_of_scoped` は、`PrimSig.Scoped` の形の変更で言明に `nranges = 0` の前提が要る（範囲の変数 0 の表での新旧の `sig_scoped` の同値は、この前提のもとで示す）。
5. L20.6: S2 で (b) を採ると、`horacle` の字面の変更が L20.5 と L20.6 の二段になる。
6. L30.1・L30.2: S1 の (a) の条件は、節の添字 S を Top 以外に選ぶ場合も要る見込みである（結果の型は R から S へ広げても狭めても継続に渡せない）。
7. L40.4・L40.5・L50.1: S4 の答えにより、表層の構文・型付けと交換の読み込みが範囲の列を持つ時期が変わる。

### 停止の時点の時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 01:55 ごろ（JST、依頼文を読み始めた時刻） |
| 終了 | 02:30 ごろ（停止の報告まで） |
| 外側の所要 | 約35分 |
| 能動時間（読む） | 約7分（依頼文・計画・前の枝の結果） |
| 能動時間（試行） | 約20分（02:02〜02:21。中心の変更と 11 回の追随。ビルドの待ちを除くと約14分） |
| 能動時間（停止の整理と本書） | 約9分 |
| ビルドの回数と時間 | 試行 11 回（1.75〜147.55 秒）、戻した状態 1 回 152.41 秒、局所の単一ファイル 約10回（各数秒） |
| 待ち | 排他の道具の待ちは記録上なし。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 0.4〜3.5時間の範囲内で停止した。上端の2倍（7時間）を超えていない |

## 回答（2026-10-28、取りまとめ）

取りまとめは四つの問いのすべてに推す案で答えた（設計者は不在で、推す案で進めるよう委任されている。本線の README「設計者の不在中の作業（2026-10-28…）」と plan-l10-l50 の停止の表に記録した）。

| 問い | 答え |
|---|---|
| S1 | (a)。`PrimSig.Scoped` に「組み込みの操作の項目（`opEff = some l`）の結果の型は範囲の変数を持たない」を連言で加える。停止の表の例外として扱う。`opSig` の引数は `Ty.instTarget s.topRanges` で具体化し、結果は `s.ret` のままとして、計算できる形を保つ |
| S2 | (a)。範囲の列は δ にだけ渡し、`ioResponse`・`Oracle` には足さない。`horacle` の字面は変えない |
| S3 | (a)。`PrimSig.StoreShape` の五つの種類に `s.rkinds = []` を加える。停止の表の例外として扱う |
| S4 | (b)。L40.4・L40.5 までの中間状態として、脱糖と交換は空の範囲の列を書き、表層の `E_Prim`・`E_Binary`・`E_Neg`・`StringAddOk`・`DieExitOk` に `s.nranges = 0` を加える。旧の像の表で `p.WellTyped` が同値であることを示す |

S4 は、表の L40.4 の行（表層の側の前提 `p.WellTyped` の内容）の一部を L20.5 へ前倒しした変更である。

## 本体の結果

試行の差分（[trial/trial-final.diff](trial/trial-final.diff)）を `<wt>` に当て直して出発点にした。

### 変えた定義

| 定義（ファイル） | 変更 |
|---|---|
| `Val.prim`（`Release/Syntax.lean`） | 末尾に範囲の列 `rs : List Scope.Domain.Range` を加えた（問 5） |
| `Builtins.delta`（`Release/Typing.lean`） | 型引数・行引数の後に範囲の列を受け取る。`ioResponse`・`Oracle`（`Release/Semantics.lean`）は変えていない（S2） |
| 具体化の定義（新 `Release/RangeInstDef.lean`） | `Atom.instR`・`Eff.instAtoms`・`Ty.rawInstR`・`Ty.instR`・`Eff.instR`・`Ty.instTarget` を `Release/RangeInst.lean` から移した（定義は同じ。V-Prim が使うので `Typing.lean` より前に置く） |
| `PrimSig.inst`・`Builtins.RangeAdmissible`（`Release/Typing.lean`） | `Release/RangeInst.lean` から `Builtins` の直後へ移した（定義は同じ）。`PrimSig.topRanges`（長さ `nranges` の Top の列）を加えた |
| `opSig`（`Release/Typing.lean`） | 組み込みの操作の型の引数を `s.params.map (Ty.instTarget s.topRanges)` にした。結果は `s.ret` のまま（S1。計算できる形） |
| `HasTypeVQ.V_Prim`（`Release/Typing.lean`） | `B.sig b = some s → B.RangeAdmissible b s rs → NamesWF (s.inst rs).names (s.inst rs).params → PrimitiveAdmissible C (s.inst rs) Q ts es → HasTypeVQ … (.prim b ts es rs) (fnTy (s.inst rs).names (s.inst rs).params (s.inst rs).ret (s.inst rs).eff ts es)` |
| `Step` と `step`（`Release/Semantics.lean`） | 組み込みの呼び出しの規則が `.prim b ts es rs` を読み、δ に `rs` を渡す。`E_RefUpdate` が作る `Reference.get`・`Reference.set` の呼び出しは空の列を持つ |
| `PrimSig.Scoped`（`Release/WellFormed.lean`） | 範囲の変数の文脈を `s.nranges` にし、連言を二つ加えた: 引数の位置の条件（各引数は不透明型か `Ty.VarsIn 0 s.ntys (· < s.neffs)`。`PrimSig.TargetRangesOnly` と同じ内容）と、操作の結果の条件（`∀ l, s.opEff = some l → Ty.VarsIn 0 s.ntys (· < s.neffs) s.ret`。S1）。`sig_scoped` と `hsig` は字面を変えずにこの定義を読む |
| `Builtins.Assumptions`（`Release/Assumptions.lean`） | `delta_typed`・`io_typed`・`io_exists` に `rs` と `B.RangeAdmissible b s rs` を加え、引数と結果を `s.inst rs` で型付ける（`delta_typed` の δ は `rs` を受け取る）。`io_kind` は変えていない。欄の数は同じ |
| `PrimSig.StoreShape`（`Release/Assumptions.lean`） | 五つの種類に `s.rkinds = []` を加えた（S3） |
| 表層の `HasTypeQ`（`Surface/Typing.lean`） | `E_Prim` に前提 `s.nranges = 0` を加え、`E_Binary`・`E_Neg` の `s.neffs = 0` を `s.neffs = 0 ∧ s.nranges = 0` にした。`StringAddOk`・`DieExitOk` の `s.neffs = 0` も同じ形にした（S4） |
| 表層の検査器（`Surface/Check.lean`・`CheckPredicates.lean`） | 同じ条件を確かめる（`primName` に新しい require「primitive has range variables」、演算子・負号・die の終了・連結は既存の require に連言） |
| 脱糖（`Surface/Desugar.lean`） | 組み込みの呼び出しに空の範囲の列を書く（7 箇所） |
| 交換（`Exchange/Convert.lean`） | Release の値を書き出す `fromVal` が範囲の列を捨てる（読み込みは脱糖を通るので空の列になる） |
| 所属の補題の配置 | `Release/Lemmas/Membership.lean` の逆転・拡大・標準形の補題を、保存の証明が使うので新 `Release/Lemmas/MembershipBase.lean` へ移した（言明は同じ） |

言明を変えた既存の定理: `HasTypeVQ.inv_prim`（範囲の列と許容を返し、型は `s.inst rs`）、`inv_prim_app`（同上。許容を末尾の連言に加えた）、`PrimitiveAdmissible.outer`・`.substTy`（`s.inst rs` について）、`progress_io`（範囲の列と許容を受け取る）、`progress_prim`・`store_prim_inv`・`ClosedArgs.single`（範囲の列を持つ項）、`canonical_fn_or_raise`・`canonical_fn`（`∃ b ts es rs`）、`refUpdate_typed`・`stringAdd_typed`・`DieExitOk.app_typed`（空の列を持つ項）、`PrimSig.scoped_iff_old`・`sig_scoped_iff_old_of_rangeFree`・`PrimSig.inst_of_scoped`（前提 `nranges = 0` を加えた。下の「同値の補題」）。ほかは場合と引数の追加だけの追随である（変えた宣言の全体は `git diff` のとおり。56 ファイル）。

### 試行で `sorry` にした 12 宣言の証明

| 宣言 | 閉じ方 |
|---|---|
| `PrimSig.scoped_iff_old`・`sig_scoped_iff_old_of_rangeFree`（`RangeWF`） | 前提 `nranges = 0` を加え、文脈 0 では二つの位置の条件が自明に成り立つことで示した |
| `PrimSig.scoped_iff_scopedRanges`（`RangeInst`） | 同上 |
| `PrimSig.inst_of_scoped`（`RangeInst`） | 前提 `nranges = 0` を加えた |
| `RangeInst` の例 1 | `writeTextInSig` が新しい `PrimSig.Scoped` を満たす例に直し、引数の関数型の内側に範囲の変数を置いた項目が拒否される例を加えた |
| `opSig_scoped`（`TySubstMain`） | 具体化した引数の変数の範囲（`PrimSig.Scoped.inst_varsIn_zero`）と操作の結果の条件 |
| `HasTypeVQ.substTy` の `V_Prim` の腕（`TySubstMain`） | `PrimSig.Scoped.inst_varsIn_zero` で `fnTy_substAt` の前提を得た |
| `store_prim_inv`・`refUpdate_typed`（`PresBase`） | `StoreShape` の `rkinds = []` から範囲の列が空で、空の具体化が署名を変えないことを使った |
| `opSig_clean`・`HasTypeQ.clean` の 2 腕（`Surface/Lemmas/Invariants`） | `opSig` は具体化した引数の変数の範囲、`E_Prim`・`E_Binary` は前提 `s.nranges = 0` と `PrimSig.Scoped.vars_zero` |

既定ビルドに `sorry` は残っていない。

### 置いた定理

| ファイル | 名前 |
|---|---|
| `Release/RangeInst.lean` | `Ty.RawVarsIn`（定義。`Ty.VarsIn` から関数の型の効果の正規形の条件を除いたもの）、`Ty.VarsIn.raw`、`Ty.rawInstR_rawVarsIn`、`Ty.norm_rawVarsIn`、`Ty.instR_varsIn_zero`・`Eff.instR_varsIn_zero`（具体化した型の変数の範囲）、`Eff.instR_single`、`PrimSig.Scoped.scopedRanges`・`.targetRangesOnly`・`.inst_wf_zero`・`.inst_varsIn_zero`・`.inst_ret_of_opEff`・`.vars_zero`、`HasTypeVQ.V_PrimNil`（範囲の変数のない項目の空の列での V-Prim） |
| `Release/Lemmas/MembershipBase.lean`（新） | 移した補題のほかに `Ty.subst_opaque`、`HasTypeVQ.widen_instTarget`、`HasTypeVsQ.widen_topRanges`（捕捉した引数の Top への拡大。`E_OpPrim` の保存が使う） |
| `Release/Lemmas/PrimRanges.lean`（新） | 一般形 `Builtins.RangeFree`・`FieldNew`・`FieldOld`（定義）、`Builtins.fieldNew_iff_old`・`rangeAdmissible_congr`・`fieldNew_extend`、三つの欄の本体 `Builtins.DeltaTypedAt`・`IOTypedAt`・`IOExistsAt` と `Assumptions.delta_typed_fieldNew` ほか 2、旧の欄 `Builtins.DeltaTypedOld`・`IOTypedOld`・`IOExistsOld` との同値 `Builtins.delta_typed_iff_old`・`io_typed_iff_old`・`io_exists_iff_old`、`Builtins.RangeFree.inst_nil`、`PrimSig.vPrim_premises_iff_old`、`PrimSig.StoreShapeOld`・`storeShape_iff_old`、`opSigOld`・`opSig_eq_old`、`PrimitiveAdmissible.of_noRows_inst`、`PrimRangeExamples` の署名と小例（下の 2 節） |
| `Surface/RangeFree.lean`（新） | `Release.Builtins.RangeFree.surface_nranges`、`StringAddOkOld`・`DieExitOkOld`（定義）、`stringAddOk_iff_old`・`dieExitOk_iff_old` |

新しいファイルは全て既定の import（`formal/Benitoite.lean`）に加えた。

保存の証明の `E_OpPrim` の腕（`PresMain.lean`）は、捕捉した引数を `HasTypeVsQ.widen_topRanges` で節の操作の型の引数へ広げ、結果の型が範囲の列によらないこと（`PrimSig.Scoped.inst_ret_of_opEff`）で `pres_op_common` に渡して閉じた。`pres_op_common` の言明は変えていない。

### 同値の補題（旧の像での同値）

旧の像の表は、全ての項目が範囲の変数を持たない（`nranges = 0`）表である。

| 前提の変更 | 補題 | 前提 |
|---|---|---|
| 三つの欄の範囲の量化（問 18 の行 2） | `Builtins.fieldNew_iff_old`（一般形）、`Builtins.delta_typed_iff_old`・`io_typed_iff_old`・`io_exists_iff_old`（欄ごと）、`Builtins.fieldNew_extend`（項目を加えた表の分解） | 表が範囲の変数を持たない（`RangeFree`）。欄ごとの同値は `sig_scoped` も前提にする（空の具体化が署名を変えるかに要る）。旧の δ は範囲の列を受け取らないので、旧の欄の δ は空の範囲の列で読む |
| `V_Prim` の範囲（問 18 の行 6） | `PrimSig.vPrim_premises_iff_old`（V-Prim の前提は、範囲の列が空であることと旧の前提の組）、`HasTypeVQ.V_PrimNil` | 項目が `PrimSig.Scoped` と `nranges = 0` を満たす |
| `sig_scoped`・`hsig`（問 18 の行 4、`TargetRangesOnly`、S1） | `PrimSig.scoped_iff_old`・`sig_scoped_iff_old_of_rangeFree`・`PrimSig.scoped_iff_scopedRanges`・`sig_scopedRanges_iff`・`sig_scopedRanges_iff_old` | `nranges = 0`（前の二つは L20.5 で前提を加えた）。`sig_scoped_iff_old_of_rangeFree` の表の前提は `nranges = 0 ∧ RangesIn 0` にした |
| `store_shape`（S3） | `PrimSig.storeShape_iff_old` | `rkinds = []` |
| 節の操作の型 `opSig` | `opSig_eq_old` | 表が範囲の変数を持たない |
| 表層の `p.WellTyped`（S4） | `stringAddOk_iff_old`・`dieExitOk_iff_old`、`RangeFree.surface_nranges` | 表が範囲の変数を持たない。`E_Prim`・`E_Binary`・`E_Neg` は前提を一つ足しただけであり、旧の像の表ではその前提が常に成り立つので、旧の規則の導出と新しい規則の導出は前提の付け外しで対応する。旧の表層の型付けの相互帰納の全体を別に並べた形式の同値の定理は置いていない（L20.4 の `delta_typed` などと同じ扱い） |

### 主定理の言明と前提の内容

七つの主定理（`Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`、`Surface.desugar_typed`・`surface_effect_soundness`）の言明の字面は B_WORK と同じである（`Release/Theorems.lean`・`Surface/Theorems.lean` の差分はない。`step_sound` の `horacle` も同じ）。証明は既定のビルドで検査し直した。

| 主定理 | 前提・結論 | 変更前（B_WORK） | 変更後 | 旧の像で同値であることの補題 |
|---|---|---|---|---|
| `progress`・`preservation`・`step_sound`・`effect_soundness`・`effect_soundness_noLamNames` | `StateTy`・`HasTypeC`、`P.WellTyped B`、`B.Assumptions P` | 組み込みの呼び出しの項は範囲の列を持たない。V-Prim は表の署名で型付ける。`sig_scoped` は署名の範囲の位置を文脈 0 で読む。三つの欄は表の署名で型付けた引数を量化する。`store_shape` は `rkinds` を読まない。節の操作の型は表の署名 | 項は範囲の列を持ち、V-Prim は許容される列で具体化した署名で型付ける（範囲の変数を持つ項目の呼び出しが型付く）。`sig_scoped` は範囲の変数の個数で読み、二つの位置の条件を含む。三つの欄は範囲の列で量化し、`delta_typed` の δ は列を受け取る。`store_shape` は `rkinds = []` を含む。節の操作の型は Top の列で具体化した署名 | `delta_typed_iff_old`・`io_typed_iff_old`・`io_exists_iff_old`・`fieldNew_iff_old`・`vPrim_premises_iff_old`・`sig_scoped_iff_old_of_rangeFree`・`storeShape_iff_old`・`opSig_eq_old` |
| `Surface.desugar_typed` | 前提 `p.WellFormed`・`p.WellTyped`・`hsig`、結論のコアの `WellFormed`・`WellTyped`・`EffectsOk` | `hsig` は文脈 0 の `PrimSig.Scoped`。表層の組み込みの呼び出し・演算子・連結・終了は範囲の変数の個数を問わない | `hsig` は新しい `PrimSig.Scoped`（範囲の変数の個数で読み、二つの位置の条件を含む）。表層の `E_Prim`・`E_Binary`・`E_Neg`・`StringAddOk`・`DieExitOk` は `s.nranges = 0` を求める（`p.WellTyped` は範囲の変数を持つ項目の表でだけ狭まる）。結論の型付けは上の V-Prim で読む | `scoped_iff_old`・`stringAddOk_iff_old`・`dieExitOk_iff_old`・`vPrim_premises_iff_old` |
| `Surface.surface_effect_soundness` | 前提 `hb : B.Assumptions (desugarProgram opPrim p)` ほか | 同上 | `hb` の内容は上の `Assumptions` と同じく変わる | 上と同じ |

`Builtins.Assumptions` の欄の追加、公理の追加、結論の弱化はない。

### 問 22 の表の項目と `TargetRangesOnly`・S1 の条件

plan-l10-l50 の注「表の項目」の型（問 22 の表）から確かめた。

| 項目 | 種類 | 引数の範囲の変数の位置（`TargetRangesOnly`） | 結果の型の範囲の変数（S1 は操作の項目だけに課す） | 判定 |
|---|---|---|---|---|
| `File.readTextIn`・`readBytesIn` | io（操作 `File.Read`） | 引数 `path: Scope.PathIn[R]` は最上位の不透明型 | `Result[String, IOError]`・`Result[Bytes, IOError]`。範囲の変数なし | 満たす |
| `File.writeTextIn`・`appendTextIn`・`writeBytesIn`・`appendBytesIn` | io（操作 `File.Write`） | `path: Scope.PathIn[R]` は最上位の不透明型。`text: String`・`content: Bytes` は範囲の変数なし | `Result[Unit, IOError]`。範囲の変数なし | 満たす |
| `Http.sendIn` | io（操作 `Http.Connect`） | `request: Http.RequestIn[H,P]` は最上位の不透明型 | `Result[Http.Response, NetworkError]`。範囲の変数なし | 満たす |
| `Scope.checkPathIn` | pure | 引数は `String` 二つ（範囲の変数なし） | `Result[Scope.PathIn[R], Scope.ScopeError]`（pure なので S1 の対象外） | 満たす |
| `Http.checkRequestIn` | pure | 引数は `String`・`Integer`・`Http.ClientRequest`（範囲の変数なし） | `Result[Http.RequestIn[H,P], Http.RequestCheckError]`（対象外） | 満たす |
| `Scope.pathInValue`・`Http.requestInValue` | pure | 最上位の不透明型 | `String`・`Http.ClientRequest` | 満たす |
| `Scope.widenPathIn`・`Http.widenRequestIn` | pure | 最上位の不透明型（範囲の変数 0） | `Scope.PathIn[S]`・`Http.RequestIn[H',P']`（範囲の変数 1。対象外） | 満たす |

満たさない項目はない。形式化でも、`File.writeTextIn`・`Scope.checkPathIn`・`Scope.widenPathIn`・`Scope.pathInValue` の形の署名が新しい `PrimSig.Scoped` を満たすことを示した（`PrimRangeExamples.writeTextIn_scoped`・`checkPathIn_scoped`・`widenPathIn_scoped`・`pathInValue_scoped`）。操作の結果に範囲の変数を置いた形は拒否される（`not_scoped_opRet`）。ただし `writeTextInSig` の効果は今の `io_op` に合わせて名前だけの原子にした（範囲付きの効果 `File.Write[R]` を io の項目に置くのは L20.7 の `shapeOk`）。

### 確かめた例（`Release/Lemmas/PrimRanges.lean` の `PrimRangeExamples`）

小例の表 `PrimRangeExamples.builtins` は、`Model.builtins` に `Scope.PathIn` の種類 path と、`File.writeTextIn`・`Scope.pathInValue` の形の項目を加え、範囲の具体化の制約を何でも許す表である。

- 範囲の列 `[/data/**]` は許される（`range_admissible`）。引数 `PathIn[rvar 0]` は具体化で `PathIn[/data/**]` に、Top の列で `PathIn[Top]` になる（`example`）。
- E_Prim: `/data/a.txt` の検査済みの対象の値を受け取る純粋な呼び出し `Scope.pathInValue[;;/data/**](checked(/data/a.txt))` が型 `String` で型付き（`prim_typed`）、δ で進む（`prim_step`）。
- E_IO: `File.writeTextIn[;;/data/**](checked(/data/a.txt), "x")` が具体化した署名で型付き（`io_typed_example`）、処理する節がなければ応答の関係で進む（`io_step`）。
- E_OpPrim: 節の操作の型の引数は `[PathIn[Top], String]` であり（`opSig_writeTextIn`）、節を持つ `handle` の枠のもとで同じ呼び出しが節の本体へ進む（`opPrim_step`）。呼び出しの閉じた引数（`PathIn[/data/**]` の値を含む）は、節の操作の型の引数を持つ（`opPrim_args_widened`。保存の `E_OpPrim` の腕が使う `widen_topRanges` の実例）。

L00.06b の限界 1〜3（閉じた非 Top の値が組み込みへ渡る場合が空に成り立つこと）は、上の例で、型付いた非 Top の値が三つの規則の呼び出しに現れ、保存の証明の `E_OpPrim` の腕が非 Top の値の拡大を実際に行うことで解消した。小例の表が `Builtins.Assumptions` を満たすことは示していない（`ref_get` などの欄の実例を含む新版の `Model.assumptions` は L20.7）。したがって、小例の表に対して主定理を適用した例はまだない。

### 設計書

- 01-12「構文」: `PrimSig.Scoped` の二つの位置の条件と理由、旧の形との同値（前提 `nranges = 0`）、組み込みの呼び出しの値が範囲の列を持つこと（脱糖・交換・`Reference.update` は空の列）を書いた。L20.3 の「型付けの規則はまだ署名を具体化せず」の文を置き換えた。
- 01-12「型付け規則」の「値」: 【決定】の段落を一つ加えた（V-Prim の具体化、正則性・型代入との交換の根拠、旧の像、小例）。` ```text ` の V-Prim の規則の並びは変えていない（形式化の範囲の列は段落で書いた）。
- 01-12「実行の規則」: δ が範囲の列を受け取り、応答の関係と `Oracle` は受け取らないこと、三つの欄の量化を箇条で加えた。
- 01-12「ハンドラ」: 節は操作の型を Top の列で具体化して型付けること、`E_OpPrim` の引数の拡大、操作の結果の条件、旧の像の `opSig_eq_old` を箇条で加えた。
- 01-12「ストア」: `StoreShape` の `rkinds = []` と理由を箇条で加えた。
- 01-12「型の情報を付けた表層の構文と型付け」: 表層の五つの前提の `s.nranges = 0` と理由（脱糖が組み込みの表を受け取らない）、旧の像での同値を書いた。
- 07-04「証明する性質」: L20.2 の段落の「組み込みの関数の型に範囲の変数を置かせない」を直し、【決定】の段落を一つ加えた（性質 1〜3 の前提の内容の変わり方、`horacle` の字面が変わらないこと、旧の像での同値の補題、停止の表の例外としての扱い）。
- 07-04「形式化で仮定するもの」: 【決定】の段落を一つ加えた（三つの欄の量化、`fieldNew_iff_old`・`fieldNew_extend`、`sig_scoped` の二つの位置の条件と問 22 の項目の形、`store_shape`、欄を増やしていないこと）。
- 07-04「01-12 との対応」: 行「型付け規則・実行の規則（組み込みの呼び出しの範囲の列と V-Prim の具体化）」（Rust は未接続）を加え、L20.3 の行の「`PrimSig.Scoped`・`Builtins.Assumptions`・型付けの規則・主定理の言明は変えていない」を新しい行への参照に直した。
- 見出しは追加・改名していない（`git grep` の確認は不要）。

### 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 途中の全体のビルド（15回。回 05・06・10 は一つのモジュールだけ） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ> [モジュール]` | 1（回 01〜04・07〜09・11〜13）、0（回 05・06・10・14・15） | 各数秒〜約2分（計時なし） | [builds/](builds/) |
| 局所の単一ファイル（途中） | `cd <wt>/formal && lake env lean -M 12288 <ファイル>`（`RangeInst`・`PresBase`・`OuterC`・`TySubstMain`・`PrimRanges` 約8回・`MembershipBase`・`PresMain` ほか） | 0 か 1（直して再実行） | 各数秒（計時なし） | 本書 |
| 全体のビルド（作業末） | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <l20.5>/lake-build.log` | 0。441 ジョブ、`Build completed successfully`。`declaration uses 'sorry'` なし。警告は `Interval/` の既存のものだけ | 138.73 秒 | [lake-build.log](lake-build.log)・[lake-build-time.txt](lake-build-time.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base d95f76181f7a6f52a6df6ef1b1a7982b1ef73cea --dry-run` | 0。101 ファイルの変更。選択は `spec_tally`・`spec_examples`（01-12 の変更）と `formal_build`（`formal/Benitoite.lean`）。plan-l10-l50「work の割り当て」の見込みと一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base d95f76181f7a6f52a6df6ef1b1a7982b1ef73cea` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 9.24 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l20.5>/axioms.lean`（82件の `#print axioms`） | 0 | 0.62 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |

公理: 82件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 78、`propext`・`Quot.sound` 2、`propext` だけ 2）。`sorryAx` と独自の公理はない。対象は、旧の主定理 7件と、新しく置いた・移した・言明を変えた・証明を直した宣言 75件（`axioms.lean` の一覧。言明を変えた `inv_prim`・`inv_prim_app`・`PrimitiveAdmissible.outer`・`.substTy`・`store_prim_inv`・`refUpdate_typed`・`progress_io`・`progress_prim`・`canonical_fn_or_raise`・`canonical_fn`、証明を直した `opSig_scoped`・`HasTypeVQ.wf`・`HasTypeVQ.substTy`・`preservationE`・`pres_op_common`・`step_soundE`・`Model.assumptions` を含む）である。

Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

### 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。排他の道具の値は待ち合わせた子孫のうち最大の一プロセスの値で、並行した lean のプロセスの合計ではない。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（作業末。下流の大半を検査し直した） | 2655518720 | 2532.5 | 2.47 |
| 公理の確かめ（`lake env lean -M 12288`、`Benitoite` 全体を読み込む） | 1506787328 | 1437.0 | 1.40 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1384579072 | 1320.4 | 1.29 |

途中のビルドと局所の単一ファイルの検査は計時していない（値なし。0 ではない）。途中のビルドのログの末尾には排他の道具の値がある。`-M 12288` は変えていない。

### 失敗と修正

- 回 01〜04: `PrimSig.Scoped` の形の変更（5・6 番目の連言）による `hs.2.2.2` の利用、`StoreShape` の連言の追加、`inv_prim_app` の連言の追加の追随。`PresBase` の `by rw [hinst]; exact …` の項の改行で構文の誤りを出し、項を先に `have` で作って直した。
- 回 05〜06: `HasTypeVQ.widen_instTarget` の暗黙の引数の型が決まらず、型を明示した。帰納法の仮定の引数の順を直した。
- 回 07〜09: 進行（`canonical_fn_or_raise` の `∃ b ts es rs`、`progress_io`）、`EffectSound` の IO の補題（`Eff.instR_single` を加えた）、表層の不変条件（`rw` が `PrimSig.Scoped` の中へ届かず、`PrimSig.Scoped.vars_zero` を加えた）、表層の検査器と健全性の証明。
- 回 11〜13: `opSig_atoms`（`Ty.instTarget` が原子を変えない）、表層の `E_Prim` の利用（`HasTypeVQ.V_PrimNil`）、表と例の δ の引数、`SurfaceCheck/Validation.lean`（既定の入口 `SurfaceCheck` の表）。
- `PrimRanges.lean` の単一ファイルの検査で、`opSig_eq_old` の `match` の閉じ残し、`E_OpPrim` の例の暗黙の引数の推論の失敗（`refine` で名指しした）を直し、使っていない `simp` の引数の警告を全て消した。
- 07-04 を標準入力の Python で書き換えようとして、macOS の Python が多バイト文字で `SyntaxError: Non-UTF-8 code` を出した（L20.2・L20.3 の記録と同じ）。スクリプトをファイルに書いて実行した。結果に影響しない。
- 記録のログの手元の絶対パスは `<wt>`・`<repo>`・`<home>`・`<tmp>` へ置き換えた。

### ずれと申し送り

計画からのずれ:

1. 停止と再開（上の「停止の理由」と「回答」）。S1・S3・S4 の前提の変更は、回答で停止の表の例外として扱うと決まった。S4 は表の L40.4 の行の一部の前倒しである。
2. `PrimSig.TargetRangesOnly` の条件は、`PrimSig.Scoped` が定義される `WellFormed.lean` で `Ty.RangesIn` を使えないので、`Ty.VarsIn 0 s.ntys (· < s.neffs)` の形で `PrimSig.Scoped` に入れた（`PrimSig.Scoped.targetRangesOnly` で L20.3 の形を取り出す）。`PrimSig.Scoped` は 6 つの連言になり、既存の `hs.2.2.2`（効果の条件）は `hs.2.2.2.1` になった。
3. 新しいファイル `Release/RangeInstDef.lean`・`Release/Lemmas/MembershipBase.lean`・`Release/Lemmas/PrimRanges.lean`・`Surface/RangeFree.lean` は計画に候補の名前がなかった。`Membership.lean` の前半を `MembershipBase.lean` へ移したのは、保存の証明（`PresMain.lean`）より後に `Membership.lean` があるためである。
4. 表層の `E_Binary`・`E_Neg`・`StringAddOk`・`DieExitOk` は、新しい前提を既存の `s.neffs = 0` との連言にした（構成子の引数の数を変えずに済むため）。`E_Prim` は前提を一つ足した。
5. 表層の検査器（`Surface/Check.lean`）は `primName` に新しい require「primitive has range variables」を加えた。範囲の変数を持つ項目でだけ出る文言であり、今の交換の入力（Rust の表は範囲の変数を持たない）では出ない。演算子・負号・die の終了の文言は変えていない。
6. 三つの欄・V-Prim・表層の型付けの旧の像での同値は、欄・前提の水準の補題で示し、旧の型付けの相互帰納の全体を別に並べた形式の同値の定理は置いていない（L20.4 と同じ扱い）。

後の枝への申し送り:

7. L20.6: `ioResponse`・`Oracle` は範囲の列を受け取らない（S2）。観測を応答の関係に加えるときも、範囲の列は加えない前提で `horacle` の字面の変更は観測の分だけになる。`io_target` が R を要るなら、`io_target` の欄の中で範囲の列を量化する。
8. L20.7: `io_op` を `shapeOk` に変えると io の項目の効果に範囲付きの原子が入り、`EffectSound.lean` の IO の補題（`hio`。`Eff.instR_single` で `(s.inst rs).eff = Eff.single l` を使う）と `PresMain`・`StepSound` の `io_op` の利用を、範囲付きの原子の名前で読む形に直す必要がある。新版の `Model.assumptions` は、`PrimRangeExamples.builtins` の二つの項目の形（`writeTextIn_scoped` ほか）と `PrimitiveAdmissible.of_noRows_inst` を使える。小例の表に主定理を適用する例はこの新版の後に置ける。
9. L30.1・L30.2: 節の添字 S を Top 以外に選ぶときも、操作の結果の型の条件（S1）がそのまま使える（結果の型は具体化によらない）。`opSig` は `Ty.instTarget s.topRanges` で具体化している。S を入れるときは計算できる形（`Ty.instTarget`）を保つ。
10. L40.4・L40.5: 表層の `s.nranges = 0` の前提（`E_Prim`・`E_Binary`・`E_Neg`・`StringAddOk`・`DieExitOk`）と、脱糖が書く空の範囲の列を外し、表層に範囲の列を入れる。`desugarProgram opPrim p` は組み込みの表を受け取らないので、表層の項 `primName` に範囲の列を持たせる形（停止の理由 S4 の (a)）が候補になる。
11. L50.1: 交換の書き出し（`fromVal`）は範囲の列を捨てる。交換形式の版で範囲の列を持たせる。
12. L50.3: 比較のための写し（`PrimSig.ScopedOld`・`StoreShapeOld`・`opSigOld`・`StringAddOkOld`・`DieExitOkOld`、`ScopedRanges` と `TargetRangesOnly` の二つの形）は、旧の互換層の整理の対象である。

取りまとめへ:

13. 新しい欄の追加・公理の追加・主定理の字面の変更はない。

### 時間

| 項目 | 時刻・時間 |
|---|---|
| 再開 | 02:31（JST、回答を受けて試行の差分を当て直した時刻） |
| 終了 | 03:15 ごろ（本書の作成まで） |
| 外側の所要（再開の後） | 約44分 |
| 能動時間（本体） | 約35分（定義と証明の追随約25分、設計書約6分、本書約4分。ビルドの待ちを除く） |
| 能動時間（停止の前を含む合計） | 約70分（読む約7分、試行約20分、停止の整理約9分、本体約35分） |
| ビルドの回数と時間 | 途中の全体のビルド 15回（失敗した回は各数秒〜約2分）、作業末 1回 138.73 秒、局所の単一ファイル 約15回（各数秒） |
| 検査 | work 1回 9.24 秒（dry-run 数秒）、公理の確かめ 2回（各 0.6 秒前後。1回目は作業末のビルドの前の状態で、作業末のビルドの後にやり直した） |
| 待ち | 排他の道具の待ちは記録上なし。取りまとめの回答待ちは停止から再開まで |
| 見込みとの比較 | 回答の後の見込み 3〜6時間に対して本体の能動時間は約35分。上端の2倍（7時間）を超えていない |
