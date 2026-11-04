# RV-L40.e-boundary: L40.23 の正常返却の境界の独立レビュー

2026-11-04。対象はブランチ `m014/l40.e` の未コミットの作業木（基準 `548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8`）、担当の [l40/e/return-boundary.md](../l40/e/return-boundary.md)、`formal/Benitoite/Release/Refinement/StandardListBodies.lean`（SHA-256 `44bbe608…0800`）と `FirstReturn.lean`（`c5522fab…3d36`）。git の操作、既存のファイルの変更、`lake build` はしていない。書いたのは本書と `<tmp>` の二つの検査の入力だけである。

## 結論

| 問い | 判定 | 根拠の種類 |
|---|---|---|
| 1. 二つの反例は正しいか | 正しい。4宣言を含む写しを単独 Lean で検査し、終了0、公理は許可三つだけ。示すのは候補の境界の定義の不足であり、群 A の固定 F06 の Lean 署名や主な十言明の欠陥ではない。ただし F06 の文言の一方「`Runs` の正常結果」は字義どおりには末端の候補そのもので、文言に具体の定義が欠けている | 実行で確定（反例）／読めば確定（F06・主定理との関係） |
| 2. 継続の捕捉・resume・破棄 | 捕捉は一回だけの継続（one-shot）で、新しい場所 κ へ `k1 ++ [handleF]` を置く（deep）。resume は保存した枠を**今の**継続の前に置くので、外側の handler で再開された呼出しは元の `k` ではなく `outer ++ k_cur` で返る。破棄は `releases` だけを残す。`markPush` は冪等で、末尾呼出しは同じ mark を共有する。VM・参照インタプリタ・01-12 も同じ | 読めば確定 |
| 3. 後段は何をどの形で使うか | 要るのは「呼出しが**呼び手の枠へ**値を渡したすべての返却」についての関係である。破棄された呼出しは対象外、resume されて返った呼出しは対象。さらに、型付けで使う読者（L40.26 の `NonEmptyList.map` の篩付きの結果、D34 の公開の長さの契約）は `Def.WellTyped` 経由でしか事実を受け取れず、`Steps` 上の関係はそこへ入らない。この点は境界の選択とは別の未決の点である | 読めば確定（型付けの規則）／判断（計画の意図） |
| 4. 推す案 | 実 Step に並走する補助の有限関係で、呼出しの位置を「活性（接尾の基底 `base`）」か「保留（場所 κ と外側の枠 `outer`）」で追う案。担当の (a) と同じ系統であるが、呼出しの識別に識別子は要らず、一回だけの継続の場所 κ が識別子の役を果たすことを定義の中心に置く。能動時間は 240〜480 分（未試行）。既存の Step・Steps・Runs・主な十言明・固定 Row・安全な入口の19契約は変えず、新しい公理も要らず、提供範囲も削らない | 判断（第4節）。接尾の補題の一部は実行で確定 |
| 5. 設計者の見直しの対象か | 推す案そのものは対象外（取りまとめによる F06 の「正常返却」の具体化の承認で足りる）。ただし第3節の「型付けの読者」の問題は、固定 Row の tel・本体と R40 の実ソースに触れるので、設計者の見直しの対象として別に問うべきである | 判断 |

## 1. 反例の正否と、何の不足を示すか

### 1.1 再検査

`StandardListBodies.lean` を `<tmp>/ListBodiesCopy.lean` へ写し、末尾に `#print axioms` の2行だけを加えた（加える前の956行の SHA-256 は原本と一致）。`formal/` で `lake env lean -M 12288` により検査し、終了0、外側の時間 6.5 秒、最大常駐 1.77 GB であった。`ListModel.later_return_same_continuation`・`endpoint_length_not_contract`・`first_return_after_handler_abort`・`first_return_length_not_contract` はすべて型検査を通り、後の二つの定理の公理は `propext`・`Classical.choice`・`Quot.sound` だけである。

### 1.2 二つの導出の読み

- 第一の15歩（734行〜）: 空入力の本体は5歩で `repeatCont` において `ret []` に至る。ここは `FirstReturn` の終点でもある。続く `E_Mark` と `E_Return` で外側がその値を消費し、`Example.repeat` と `List.mapFrom` の `E_Fun` が `markPush` で同じ構造の `[mark, letF repeatTail, mark]` を組み直す（Semantics.lean 21〜23行の冪等性）。このため末端だけでは別の呼出しを区別できない。
- 第二の20歩（860行〜）: callback の `raise` に対し、`E_OpFail` が `k1 = [mark, letF, mark]`、`k2 = [letF failTail, mark]` で外側の Fail handler へ移る（`failCont` の長さ4から、継続 `drop 0 :: k2` の長さ3へ）。`E_DropRel` は `releases saved = []` を置き、場所0を `used` にする（331〜335行）。その後に同じ構造の handler と let を組み直し、空入力の別の mapFrom が `failCont` で初めて `ret []` を返す。

どちらも、再帰で同じ構造の継続を作り直せることと、Cont の等号が構造の等号であることだけに依る。担当が Program.WellTyped 等の全前提を証明していない点は記録どおりであるが、この現象は前提を満たす通常のプログラム（再帰と外側の Fail handler）でも起きると読める。全前提の下での反例の構成は、結論を変えないので要らない。

### 1.3 何の欠陥か

- 固定 F06 の Lean 署名: signatures.md「F06：標準行と本体」は Row・`Row.BodyTyped`・pure 行の量化だけを Lean の形で固定し、core 行の結果の関係には Lean の署名を持たない。したがって反例が偽にする固定の Lean 言明はない。
- F06 の文言: 「同じ本体の有限なSteps又はRunsの正常返却から結論する」の「Runs の正常結果」は、`IntervalConnection.Runs`（IntervalConnection.lean 78〜80行）が「有限 Steps と、継続 `resultCont` での `EndState`（70〜75行）の存在」であるため、字義どおりには第一の反例が否定した末端の候補である。`Runs` は存在の主張として合成に使う限り健全である（`Runs.let_normal` など）が、全称の仮定として契約を導く入力にはならない。文言に「どの返却か」の具体の定義が欠けていることが不足の本体である。
- 主な十言明: 保存・進行等は個々の Step と StateTyE についての言明で、返却の境界の概念を使わない（l00b.15/theorems.md「主な定理と量化の新旧」）。反例は当たらない。

### 1.4 第二の候補の不足は両側にある

担当の記録は「破棄された呼出しを数えてしまう」側だけを述べる。第2節の resume の規則から、もう一つの側がある。外側の handler で保留され、後で resume された呼出しは、元の `k` ではなく `outer ++ k_cur` で返る。したがって `FirstReturn k` は、その呼出しの本当の返却に一般には到達せず、関係が空のまま提供範囲（外側 handler での resume）を覆わない。`k` を固定して返却を読む候補は、どれも同じ理由で不十分である。

## 2. 実行の規則と処理系の実際

### 2.1 Lean の Step

読めば確定する事項である（`Release/Refinement/Semantics.lean`）。

- `E_Op`・`E_OpFail`・`E_OpPrim`（301〜318行）は、`SplitAt` で継続を `k1 ++ handleF :: k2` に分け、新しい場所 κ（`μ κ = none`）へ `cont (k1 ++ [handleF])` を置き、節の本体を `drop κ :: k2` で始める。handler の枠を保存側に含むので deep handler である。
- `E_Resume`（319〜322行）は `μ κ = cont k'` のとき `ret v` を `k' ++ k` で続け、κ を `used` にする。二度目は `E_ResumeErr` で `ResumeTwice` の error になる（323〜326行）。継続は一回だけ再開できる。
- 節が値で終わると `E_DropRel`（331〜335行）が `releases k' ++ k` を置き κ を `used` にする。`releases`（25〜29行）は `release` と `drop` の枠だけを残す。error・exit・escape も同じ扱いである（337〜355行）。
- `E_Lam`・`E_Fun`・`E_Meth` は `markPush` で枠を積み（80〜83・125〜139行）、`markPush` は先頭が mark なら積まない。したがって末尾位置の再帰呼出しは元の呼出しと同じ mark で返る。mapFrom/filterFrom の再帰は末尾位置にあるので、基底 `k` が mark で始まれば再帰後も同じ基底になり、そうでなければ一つの mark が内側に加わるだけである。
- 実行関数 `Step.lean` の resume と drop の枝（52・203・211・239・248行）も同じ形である。

帰結: 捕捉は呼出しの枠を一度だけ保存に移し、保存は resume か破棄でだけ変わる（他の確保は空き場所だけを使う。参照の書込み `E_RefSet` は場所の中身を検査しないが、型付きの状態では継続の場所を参照として指せない）。resume は枠を元の並びのまま、別の基底の上へ戻す。

### 2.2 01-12 と処理系

- 01-12 は「一度だけ再開できる継続をストアに加える」（593行）と E-DropRel と `releases(K)`（1049〜1069行）を同じ形で定める。
- VM の `resume`（`crates/benitoite/src/vm/dispatch/handlers.rs` 728行〜）は、`ContState::Used` なら `ContinuationResumedTwice` を返し、`Captured(segments)` を `Used` に置き換えて、底が `Handle` の枠である保存した区間を今の実行へ戻す。参照インタプリタ（`crates/benitoite/src/refinterp/eval.rs` 640〜660行）も `Store::Cont(frames)` を `Used` に置き換え、保存した枠を今のスタックの上に積む。
- したがって「一回だけ・deep・保存した枠を今の継続の上に戻す」は Lean・仕様・二つの処理系で一致している。

## 3. 後段の読者が要るもの

### 3.1 実行の関係として使う読者

S14/S15 の後段は L70（「F04〜06の全標準契約」）、R40・R10b・R50・V10（O080・O131）である（l40/detail.md「L50/L60/L70へ渡す署名」と義務の表）。いずれも、`List.map(xs, f)` の呼出しが呼び手へ値を返したときの長さ・要素型・順序を使う。読者が要る返却は、次のとおりである。

| 呼出しの経過 | 読者の扱い |
|---|---|
| 外側へ出ずに返る | 対象。返却は元の基底で起きる |
| 外側の handler で保留され、resume されて返る | 対象。返却は `outer ++ k_cur` で起き、値は保存されていた呼び手の枠へ渡る |
| 外側の handler で保留され、破棄される | 対象外。呼び手へ値は渡らない |
| callback の error・exit で終わる | 正常の関係の対象外。失敗は `listFrom_callback_failed` の枝 |
| 保留のまま実行が終わる | 返却なし。返却の存在は F06 も要求しない |

この表は、「どの基底で返るか」ではなく「同じ呼出しが呼び手へ値を渡したか」で返却を決める必要を示す。

### 3.2 型付けで使う読者（境界の選択と別の問題）

読めば確定する事項として、核の呼出し `fnRef f` の型は呼ばれる定義の `d.tel` から決まる（`Typing.lean` 169行）。L40.26 の `NonEmptyList.map` の内部契約は結果を `List[U]{0<length self ∧ length self=length xs}` とする（l40/a/safe-contracts.lean 91〜96行）。現行の実ソースはその本体で `List.map` を呼ぶ（`crates/benitoite/src/prelude/stdlib/NonEmptyList.bnt` 59〜62行）。`List.map` の行の tel は篩のない `List[U]` である（StandardListBodies.lean 56〜61行）。したがって `nonemptyMap` の `Def.WellTyped` は、`List.map` の tel が長さの篩を持つか、本体を書き換えない限り証明できない。`Steps` 上の関係は、どの境界で定義しても `Def.WellTyped` の入力にならない。

[l40/e/results.md](../l40/e/results.md) の181行は「NonEmptyList.map等でList.mapの正常関係を使う証明は境界の決定待ち」とするが、上の理由で、境界を決めてもこの読者は閉じない。利用者のプログラムが D34 の「長さ・map等の契約」を型検査で使う場合も同じで、事実は `d.tel` と主な保存（継続の型付け）を通ってしか呼び手へ届かない。計画の検討（study/refinement-full.md 686行）は「本体も検査し、List.get の Some/None と長さの契約を与え、補助関数の accumulator と添字の関係を明示して証明できる形へ直す」としており、これは型付けの経路を想定した記述と読める。

型付けの経路では、主な保存が handler・resume・破棄をすでに扱うので、返却の境界の定義そのものが要らない（Bauer と Pretnar は、代数的効果と handler の効果系について、操作的意味論の安全性を効果系に対して証明している。Logical Methods in Computer Science 10(4), 2014。arXiv:1306.6316 の要旨で確認）。ただし篩の型は長さと要素型を表せても、F06 が求める「元の要素順に観測した callback の返却列との一致」は表せない。順序の関係には、なお実行の関係が要る。

## 4. 境界の定義の候補と推す案

### 4.1 候補の比較

| 候補 | 内容 | 既存の契約への波及 | 評価 |
|---|---|---|---|
| E 末端 | `Steps` の終点が `k` で `ret` | なし | 反例1で不足 |
| F 最初の返却 | `FirstReturn k` | なし | 反例2で不足。resume された返却も覆わない（1.4） |
| G 接尾の領域 | `FirstReturn` に「途中の全状態の継続が `k` を接尾に持つ」を加える | なし | 健全だが、外側で保留された呼出しを全く覆わない。提供範囲を実質的に削る |
| A 位置の追跡（推す） | 活性（基底）と保留（κ と外側の枠）を追う補助の関係 | なし | 健全で、resume を覆い、破棄を除く |
| B 識別子付きの枠 | 実 Frame に呼出しの識別子を入れる | Syntax・Step・全保存・主な十言明・処理系 | 不要。一回だけの継続の場所 κ が識別子の役を果たす |
| L 局所の意味 | 空の継続で本体を走らせ、外側の操作を応答の神託とする（interaction tree の見方） | なし | 応答値の型付けを別に要し、大域の Steps への接続に A と同じ接尾の補題が要る。A より重い |
| T 型付けの経路 | mapFrom/map の tel に `i`・`acc`・結果の長さの篩を付け、`Def.WellTyped` と主な保存から得る | 固定 Row の tel・本体、R40 の実ソース、List.get/append の結果の篩 | 3.2 の読者には必要。順序は表せない。設計者の見直しの対象 |
| C 純粋な E に限る | handler なし又は純粋 | 提供範囲の削減 | 採らない |

### 4.2 推す案 A の要点

呼出しの「位置」を幽霊の状態として持ち、実 Step を一歩ずつ分類する。

- 活性 `active base`: 今の状態の継続が `inner ++ base` の形を持つ。基底を固定すれば `inner` は一意である（`List.append_cancel_right`）。
- 外側への捕捉: `E_Op`・`E_OpFail`・`E_OpPrim` の handler が基底の中にあると、継続は `drop κ :: k2` になる。基底を `k1' ++ handleF :: k2` と書くと、`drop κ :: k2` が基底を接尾に持つことはない。この補題（`capture_leaves_base`）を `<tmp>/SuffixCheck.lean` で `lake env lean -M 12288` により検査し、終了0であった（SHA-256 `94c3d922…b2`）。よって「内側の一歩」と「外側への捕捉」は継続の形だけで排他に分かれる。
- 保留 `suspended κ outer`: 呼出しの枠は場所 κ の `cont (inner ++ outer)` にだけある。他の一歩が `μ κ` を変えない間は保留のまま続く。`E_Resume` が κ を再開すると、新しい基底 `outer ++ k_cur` で活性に戻る。κ が resume 以外で変わる（`E_DropRel` 系で `used` になる）と、正常の終点へ進む構成子がないので、破棄された呼出しは正常の関係に現れない。
- 終点: 活性で `inner = []` かつ `ret v` の状態だけを正常の返却とする。基底での error・exit・escape は別の終点である。基底で終わりうる状態（ret・escape の run、error、exit）を「内側の一歩」から除くので、第一の反例のように返却の後へ進む導出は作れない。

量化の素描を示す（名前は仮）。

```lean
inductive Site where
  | active (base : Cont)
  | suspended (κ : Nat) (outer : Cont)

/-- 実 Step の導出に並走し、同じ呼出しの位置を追う。意味の真理や型を欄に持たない。 -/
inductive CallRun (P : Program) (B : Builtins) (σ : PathEnv) :
    Site → State → List Event → Val → Store → Cont → Prop
  | ret {base q μ v} : q.view = .ret v →
      CallRun P B σ (.active base) (.run q base μ) [] v μ base
  | inside {base s e t es v μ' b'} :
      Step P B σ s e t → (∃ i, s.frames = i ++ base) → (∃ i, t.frames = i ++ base) →
      ¬ AtBase base s → CallRun P B σ (.active base) t es v μ' b' →
      CallRun P B σ (.active base) s (e.toList ++ es) v μ' b'
  | capture {inner k1' k2 cap h s t κ μ' es v μ'' b'} :
      Step P B σ s none t → s.frames = inner ++ k1' ++ .handleF cap h :: k2 →
      t.frames = .drop κ :: k2 → t.store κ = some (.cont (inner ++ k1' ++ [.handleF cap h])) →
      CallRun P B σ (.suspended κ (k1' ++ [.handleF cap h])) t es v μ'' b' →
      CallRun P B σ (.active (k1' ++ .handleF cap h :: k2)) s es v μ'' b'
  | away {κ outer s e t es v μ' b'} :
      Step P B σ s e t → s.store κ = t.store κ → ¬ ResumesAt κ s →
      CallRun P B σ (.suspended κ outer) t es v μ' b' →
      CallRun P B σ (.suspended κ outer) s (e.toList ++ es) v μ' b'
  | resume {κ outer inner q k μ w es v μ' b'} :
      q.view = .resume (.loc κ) w → μ κ = some (.cont (inner ++ outer)) →
      CallRun P B σ (.active (outer ++ k))
        (.run (Closure.pure (.ret w)) (inner ++ outer ++ k) (μ.set κ .used)) es v μ' b' →
      CallRun P B σ (.suspended κ outer) (.run q k μ) es v μ' b'

theorem CallRun.steps : CallRun P B σ site s events v μ' b' →
    ∃ q, Steps P B σ s events (.run q b' μ') ∧ q.view = .ret v

theorem listMap_normal_relation
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hB : B.CoreAssumptions P) (hσ : σ.Valid) (lookups/表の欄 : 担当の表「現在未証明の正常関係の言明と前提」のとおり)
    (initial : StateTyE P B σ Eb s0)
    (run : CallRun P B σ (.active k) s0 events (.list ys) μ' k') :
    ∃ Ψ', StoreOk P B σ Ψ' μ' ∧ ys.length = xs.length ∧ HasTypeEachQ P B Ψ' Qempty [] [] [] ys U.norm ∧
      （順序: ys は同じ導出で観測した callback の返却列）
```

`s0` と各欄は担当の表（return-boundary.md「現在未証明の正常関係の言明と前提」）をそのまま使える。`CallRun.steps` で同じ `Steps` へ射影するので、型の部分は既存の `steps_preserved` と `list_append_reached_typed` が使える。

証明の要所は、CallRun の**分割の補題**（bind の補題）である。mapFrom の本体が callback を `letF tail :: base` の上で呼ぶとき、その下の枠は handler でないので、callback の外側への捕捉はそのまま mapFrom の外側への捕捉になる。したがって CallRun（基底 `base`）を、callback の CallRun（基底 `letF tail :: base`、終点の基底は resume 後に変わりうる）と、その後の `E_Return` 以降の CallRun に分けられる。この補題を CallRun の帰納で一度証明すれば、map/filter の i・acc・残りの帰納は、None の5歩・Some の7歩・callback・加算・append・末尾の再帰（`markPush` の場合分け）を既存の補題でつなぐだけになる。Map/Set の本体（L40.24）も同じ補題で List の関係を使える。

### 4.3 既存の契約・公理・提供範囲

- Step・Steps・Runs・主な十言明・群 A の固定 Row・安全な入口の19契約は変えない。CallRun は既定 import に加える新しい定義で、`FirstReturn` と同じく実 Step の導出を部分に持つだけである。
- 新しい公理は要らない。真偽を欄に置かず、構成子は実 Step と継続・ストアの等号だけを持つ。
- 提供範囲は削らない。任意の潜在効果と失敗を持つ callback、外側 handler での resume（基底の変更）、破棄（正常の関係から外れる）を扱う。
- 弱点: CallRun からの正常の関係は「CallRun が成り立つ返却」についての言明であり、任意の大域の Steps でその呼出しの返却が起きたとき CallRun が作れること（覆いの補題）は別に要る。読者が大域の実行から使うならこの補題も要り、同じ分類の議論で証明できる見込みである。実例として、外側の handler で resume する callback の短い導出を一つ置いて空でないことを確かめることを勧める。

### 4.4 能動時間の見込み

未試行の見込みである。

| 作業 | 見込み |
|---|---|
| 定義・射影・排他の補題（AtBase・捕捉・ResumesAt） | 40〜80分 |
| 分割の補題（基底の変化を含む CallRun の帰納） | 100〜200分 |
| map/filter の i・acc・残り・順序・要素型の帰納 | 60〜120分 |
| 覆いの補題と、外側 resume の実例 | 40〜80分 |
| 計 | 240〜480分 |

担当の (a) の見込み 150〜300 分より大きくしたのは、基底が resume で変わる分割の補題と覆いの補題を別に数えたためである。

## 5. 主な定理・書ける形・処理系への影響

- 推す案 A: 主な定理の前提と量化、利用者の書ける形、処理系の実行のいずれにも触れない。F06 の文言の「正常返却」を CallRun の正常の終点として具体化する承認は、取りまとめの判断で足りる。
- 第3節の型付けの読者: これは案 A でも案 B でも閉じない。`List.map` の結果の長さを `NonEmptyList.map` の型付けや D34 の公開の契約で使うには、mapFrom/map の tel に篩を付ける（案 T）、又は `nonemptyMap` の本体と契約の形を改める必要がある。案 T は固定 Row の tel と本体、R40 の `List.bnt` の実ソース（List.get の Some/None と添字の関係の扱いを含む）に触れ、利用者に見える契約の形を決めるので、**設計者の見直しの対象**である。L40.26 に着手する前に、この点を独立の問いとして設計者へ示すことを勧める。

## 6. 読めば確定する事項と、実行しないと分からない事項

| 区分 | 事項 |
|---|---|
| 実行で確定 | 反例の4宣言の型検査と公理（1.1）。捕捉の後の継続が基底を接尾に持たないこと（4.2） |
| 読めば確定 | 一回だけ・deep・保存した枠を今の継続へ戻す規則（2.1・2.2）。resume 後の返却が元の `k` で起きないこと（1.4）。固定 F06 に core 行の関係の Lean 署名がないこと（1.3）。`fnRef` の型が `d.tel` から決まり、`Steps` の関係が `Def.WellTyped` に入らないこと（3.2） |
| 実行しないと分からない | 分割の補題と覆いの補題が見込みの時間で閉じること。反例が Program.WellTyped 等の全前提の下でも構成できること（結論は変えないので要らない） |
| 判断 | 案 A を推すこと。案 T を設計者へ別に問うべきこと |

## 取りまとめの追記

2026-11-04。第3節の 3.2 の指摘を採った。正常時の関係は、型の篩（第4節の案 T）で表す。理由は、決定 D34 が長さの契約を型に付けることを求めており、呼出しの側がその事実を使える経路は `d.tel` だけだからである。handler の扱いは主な保存に任せ、案 A の `CallRun` は作らない。順序は篩の型で表せないので、L40 の Lean の義務から外し、R40 の実行の検査で確かめる。判断と理由は plan.md「計画の変更と取りまとめへの確認点」の 2026-11-04 の項に書いた。設計者の見直しの対象である。
