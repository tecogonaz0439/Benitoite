# RV-L00b.13: 値の葉の独立レビュー

2026-11-01。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.13 の未コミットの作業ツリーにある `formal/` の本番の変更である。基準 `40311429` からの差分は、既存3ファイル（`Benitoite.lean`・`AtTyping.lean`・`Typing.lean`）の11行追加4行削除と、新規4ファイル（`ValueFacts`・`HeldValues`・`TargetTable`・`ModelHttp`、計499行）から成る。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.13-request.md)
- `l00b.13/` の `signatures.md`・`results.md`・`boundary.lean`・`case-inventory.txt`・`axioms-summary.json`・`inputs-sha256.json`・`public-names.json`
- `README.md`「設計者の決定」、`decisions.md` の D20・D21・D28、`plan.md` の L00b.13 の行、O030・O047・O049 の行、「計画の変更と取りまとめへの確認点」の先頭の行、`l00b.11/signatures.md` の申し送り、`l00a.06a/contracts.md`、`l00a.16a/lemmas.md`
- 本番の `Typing`・`Le`・`Context`・`TypedFacts`・`Canonical`・`Atoms`・`AtPrepare`・`AtInput`・`AtSound`・`AtTyping`・`PathResolution`・`Step`・`Syntax`・`Normalize`、旧 `TargetTable`・`ModelHttp` の定義

Lean は局所に実行した。補助のファイルはリポジトリの外（`<tmp>/rv13/`）に置いた。いずれも `cd formal && lake env lean -M 12288 <ファイル>` で実行し、全体の `lake build` は繰り返していない。

1. `boundary.lean` を再実行した。終了0、104宣言、`error` と `sorryAx` は0件である。
2. `inputs-sha256.json` の142入力は今のファイルのハッシュと全件一致する。
3. `C.lean`。環境から HasTypeVQ 29、HasTypeCQ 24、ImageOk 4、Ty.LeQ 13、Step 76、Const 16、CheckedWitness 2 を読み取った。
4. `W2.lean`。実際の `E_AtOk` の前提から `CheckedWitness` を組み立てた（`at_ok_witness`。準備の結果と URL の種類は入力）。`checkAt_absolute`、List の要素の空でない facts（`list_element_facts`）、data の欄を型の側の引数で読む版（`field_facts_by_type`）も閉じた。誤り0件である。
5. `W3.lean`。閉じた型付きの要求で `groundVal` が偽の例を作った（中1）。公理は propext・Classical.choice・Quot.sound だけである。
6. `W1.lean`。`AtPrepared` から要求の判定成功を取り出す補題を試した（中2）。private の `prepareCore` を一時の展開で読む形で、判定の枝の `groundVal` と `reqTarget` の取り出しまでは通った。結果の `target` が同じであることを示す末尾の分岐は閉じていない。その部分は読解による。
7. 公理依存の13,948宣言は再実行していない。`axioms-summary.json` の記録と、新規4ファイルの grep の結果を照合した。

## 総評

**条件付き可**である。重の所見はない。読んだ範囲で、定理を偽にする誤りと、不正な値を型付ける規則は見つからなかった。facts の逆転は最外の形で閉じておらず、V_Sub・V_Normal・V_Refine の連鎖と LeQ の推移を通す。保持要求は Top と opaque への忘却の後も同じ要求を返す。`V_CheckedRequest` の変更は D20 の範囲であり、遷移を壊さない。

条件は中の2件である。中1は、D20 の判定 `groundTy` が `.refined` を拒むので、`T{true}` を型引数に持つ閉じた型付きの要求が保持できず、At でも失敗する点である。今回の差分の誤りではなく既存の `groundTy` の定義の帰結だが、規則の前提に入ったことで型付けの範囲にも現れる。D07 との関係を決めてから受け入れるのがよい。中2は、値を作る遷移（`E_AtOk`）へ葉をつなぐ補題が L40/L50 への申し送りにないことである。境界の遷移は `E_IfT` だけで値を作らない。接続できることは `W2.lean` で確かめた。

O030・O047・O049 は、plan の L00b.13 の範囲で閉じたと判断してよい。全 canonical forms などの残りは L40/L50/L60 の範囲である。

## 観点ごとの判定

| 観点 | 判定 | 根拠 |
|---|---|---|
| 1. facts の前提 | 可 | `facts` は `toTerm? = some t` を要求し、`assume` の既定値の整数0を結論へ出さない。前提に結論を含まない |
| 1. Entails の方向と Φ | 可 | `subtype_facts` は `Ty.LeQ.assume` の `a.assume ++ lifted` から b の述語を導き、`cut` で値の事実と Γ.facts ++ Φ へ戻す。`Pred.open_lift` で持ち上げを消す |
| 1. 入れ子・連鎖 | 可 | `HasTypeVQ.assume` が V_Sub・V_Normal・V_Refine を再帰する。`Ty.assume` は全篩の述語列であり最外だけではない。境界の `integer_extracted` は二重の篩、forget/introduce/trans の後の事実を返す |
| 1. toTerm? で漏れる形 | 可 | none になるのは関数・閉包・参照等で、facts は適用されない。list/data の欄の欠落は `some (some t)` の前提で分ける |
| 1. 整数の葉 | 可（軽2） | `integer_facts` は Integer だけである。ほかの幅は `inv_const` と `facts` の合成で足りる |
| 1. List の葉 | 可（軽3） | `inv_list` は元の要素型と LeQ を返す。要素の空でない facts は `W2.lean` で合成できた |
| 1. data の欄 | 可 | `P.cons c` の値自身の構成子から cd を固定し、値の ts で具体化する。別の構成子を読まない。型の側の引数でも `Ty.subst_norm_images` で読める（`W2.lean`） |
| 2. Ty.Holds | 可 | scoped は kind を比べ、opaque は比べない。`unique_name` は名前だけを主張する。kind は valKind の証拠から返す |
| 2. LeQ.holds | 可 | 13場合を尽くす。`scoped` は Covers を返し、`scoped_forget` は opaque の枝へ移る。逆向きの LeQ の規則はない |
| 2. Covers の合成 | 可 | `RangeIx.Covers.trans` は全組合せを閉じる。最終の添字への所属は既存の `Range.Covers.sound_memK` で得られる |
| 2. 逆転の三本 | 可 | 元の範囲の所属と元の要求を保つ。`checked_without_request`・`checkedAt_without_request` は valContent の区分で、mismatch は reqTarget で否定する。同じ B で正例が成り立つので空虚でない |
| 2. 資源の opaque | 可 | ConstOK の `.opaque` の枝が valKind none かつ valContent none を要求し、`resource_opaque` は File で型付く |
| 2. `outer.WF` を要求しない判断 | 可 | `Ty.WF` の scoped と `RangeIx.WF` の fixed は True であり、`LeQ.scoped` の規則も範囲の WF を読まない。At は `AtCallAdmissible` が別に `r.WF` を要求する |
| 3. D20 の範囲 | 可（中1） | `V_CheckedRequest` と `CheckedWitness.request` の欄の置き換えは D20 の文言どおりである。`groundVal_ground` の向きがあるので閉性は失わない |
| 3. 既存の遷移 | 可 | `.checkedRequest` は Step が作らず δ だけが作る。旧の検査の δ は `groundVal` を確かめる。`E_AtOk` は `prepareCore` が `groundVal` の成功を要求する。`Val.subst`・`closeVal` は保持要求に触れない |
| 3. 主な定理と信頼条件 | 可 | 署名と本文の差分はない。量化する葉の意味の変更は results.md が明記し、L00b.15 へ申し送っている |
| 3. Ground の逆向き | 中1 | 一般の Ground から bool の成功は導けない。具体例は要求の型の中にもある |
| 4. reqTarget の固定 | 可 | `Val.reqTarget` は `parseUrlTarget` に固定され、Builtins に欄はない |
| 4. valueRun | 可 | `checkedRequest` と `checkedAt … (some req)` が同じ判定の成功から `.val req` を返す。型付きの入口は判定を証拠から取り出し、既定値の枝へ落ちない |
| 4. 旧モデルとの交換 | 可 | `groundTy_embed`・`groundVal_embed`・`valueRun_embed` は旧の定義と全構成子で一致する。AtPrepare の写しは旧 `groundTy`・`groundVal` と同じ分岐である |
| 4. 表の単射性 | 可 | Holds が名前 o を固定し、同じ関数の lookup で A が一意になる。単射は使わない |
| 4. TargetTable | 可（軽6） | RequestIn は要求の型、PathIn は none である |
| 5. 境界の正例 | 可 | 結論の型付けや Entails を入力に取らない |
| 5. 遷移で閉じるか | 条件付き（中2・軽1） | `E_IfT` は値を作らない。`after_leaf` は StateTy から型付けを取り出さず、`held_top` を再度使う |
| 5. L00b.14a の使い方 | 可 | 実観測の facts、bool からの Ground、受信後の元の型付けという形で使える |
| 6. 五つの境界 | 可 | 主な定理の前提と結論、公理、提供範囲、精密な外部状態に差分はない。利用者の書ける形は中1 |
| 6. 抜け道 | 可 | 新規4ファイルに `sorry`・`axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern` はない。一致した1件は構成子名 `.opaque` である |
| 7. 場合の数 | 可 | 手順3のとおりである。新規の逆転5本は各29、LeQ の3本は各13で、`match` の網羅で確かめられる。新規47・変更4は `public-names.json` と本文の数え上げで一致する |
| 7. 申し送り | 条件付き | 中2と軽7が不足する |
| 文書の規約 | 可 | `l00b.13/` と依頼に、手元の絶対パス、`work/` の参照、`docs/todo` へのリンクはない |

## 新しい所見

### 重

なし。

### 中

**中1. `groundTy` が `.refined` を拒むので、`T{true}` を型引数に持つ閉じた型付きの要求を保持できない**（読めば確定し、Lean で再現した）

- 箇所: `formal/Benitoite/Release/Refinement/AtPrepare.lean` の `groundTy`（13〜17行）と `prepareCore`（89行）、`Typing.lean` の `V_CheckedRequest`（176行）と `CheckedWitness.request`（393行）、`results.md`「D20 の計算可能な前提」。
- 問題: `groundTy` の `_ => false` は `.refined` にも当たる。一方で V_Con は値の `ts` を正規化せず、取りまとめの判断（RV-L00b.11 中1）は値に埋まった型引数が正規形という不変条件を置かない。したがって `Pair[String{true}, String]` の構成子の値は V_Normal で `Pair[String, String]` に型付くが、`groundVal` は偽である。この要求は V_CheckedRequest で保持できず、At は実行時に `invalidTarget` を返す。正規形が同じ二つの値で At の結果が分かれるので、D07「`T{true}` は `T`」と合わない。`results.md` は一般の Ground から判定成功を導く補題が偽であることに触れるが、要求の型の中で偽になることと、その影響を書いていない。`ModelHttp.lean` の説明の「実装の要求についてこの判定は成り立つ」も、並置体系では成り立たない。
- 反例（`W3.lean`）:

```lean
def rawStr : Ty := .refined (.base .string) .truth
def pairV : Val := .con "Pair" [rawStr, .base .string]
  [.const (.string "k"), .const (.string "v")]
-- reqRaw は boundary の req の headers を .list [pairV] にしたもの
theorem at_rejects_raw :
    ∃ _h : HasTypeV P B StoreTy.empty [] [] [] reqRaw TargetTable.clientRequestTy.norm,
      reqRaw.Ground ∧ reqRaw.reqTarget = some target ∧ groundVal reqRaw = false
theorem reqRaw_not_held (T : Ty) :
    ¬ HasTypeV P B StoreTy.empty [] [] [] (.checkedRequest target reqRaw) T
```

- 影響: 健全性は壊れない。遷移と規則は同じ判定を読むので、保存の穴にはならない。問題は完全性の側である。旧の埋め込みには refined がないので、contracts の「旧来の閉じた要求の型付けも保つ」には反しない。ただし L40 の data の検証済み変性が入ると、`Pair[String{p}, String]` のような述語が空でない型引数も `Pair[String, String]` へ広がりうる。そのときは要求の見出しの値の篩が At の失敗に変わる。Rust の処理系のソースには同等の判定が見当たらない。Rust で同じプログラムが成功するかは実行していない疑いであり、確定には L30 以降の比較が要る。
- 修正案: `groundTy` に `.refined a p => groundTy a && decide (p.WF 1)` の枝を足す案を推す。閉性は保て、旧の型には refined がないので `groundTy_embed` は変わらず、`groundVal_ground` の場合が増えるだけである。述語の WF の判定が要る。代案は `groundVal` が型引数の `norm` を読む案だが、述語が残る型は救えない。AtPrepare の実行時の判定を変えるので利用者の書ける形に触れる。D20 の細則として設計者に確かめ、受け入れの前に直すか、L40 の data の変性の前提に置くかを決めるのがよい。

**中2. 値を作る遷移へ葉をつなぐ補題が申し送りにない**（読めば確定し、接続の可否は Lean で確かめた）

- 箇所: `results.md`「義務の判定と残り」、`signatures.md`「場合の数と L40 に残す範囲」、`boundary.lean` の `actual_step`・`at_transition`。
- 問題: 境界の遷移はどちらも `E_IfT` で、同じ値を返すだけである。結論を仮定してはいないが、保持値を作る遷移を通していない。`CheckedWitness.request` を `E_AtOk` の結果に作るには次の三つが要るが、申し送りに書かれていない。
  1. `AtPrepared` と `valContent = some T` から `groundVal (closeVal cap input) = true` と `reqTarget = some t`、`target = .absolute t` を返す補題。`prepareCore` が private なので `AtPrepare.lean` の中に置く必要がある。
  2. `Val.reqTarget v = some t → t.kind = .endpoint`。`parseAuthority` が private なので `AtInput.lean` に置く。`AtCallAdmissible` は `valContent` が some の名前の kind を endpoint に限らないので、これがないと `.request` の endpoint を供給できない。この補題を置かず表の信頼条件を足すと、境界に触れる。
  3. `checkAt` の `.absolute t` の入力で結果が `t` であること（`W2.lean` の `checkAt_absolute`）。
- 確かめたこと: `W2.lean` の `at_ok_witness` は、1 と 2 を入力として `CheckedWitness P B Ψ name kind bound snapshot t (AtRequest B name v)` を閉じた。公理の追加も主定理の制限も要らない。契約の変更は不要である。
- 修正案: 上の三つを L40/L50 の O049 の義務へ足す。results.md の「実際の Step」の説明に、`E_IfT` は値を作らず `E_AtOk` と δ の接続は残りであることを書き足す。`W2.lean` の二つの補題は本番に置ける形である。

### 軽

**軽1. `after_leaf` は StateTy を読まない**（読めば確定）。`after_typed` は `held_top` の再掲であり、`after_state` から値の型付けを取り出していない。results.md の「到達後の値の型付けに射影の葉を適用する」は、状態の中の導出を読む意味にはならない。StateTy から `.ret v` の型を取り出す補題は L40 の状態の合成で扱う。説明を直すだけでよい。

**軽2. `integer_facts` は Integer だけである**（読めば確定）。D21 の各幅の整数と Byte の値は `inv_const` と `facts` で扱えるが、同じ形の葉はない。L40 の各幅の契約で足す。

**軽3. List の要素の facts の一本の入口がない**（読めば確定）。`list_facts` の結果を `member` と `subtype_facts` で合成する手順が要り、境界の要素の例は `Unit{true}` で assume が空である。`W2.lean` の `list_element_facts` は6行で閉じた。data の欄を型の側の引数で読む `field_facts_by_type` と合わせて、L40 が使うなら本番に置くとよい。

**軽4. 通常の `checked` の正例が境界にない**（読めば確定）。`checked_widen`・`inv_checked`・`checkedRequest_facts` は境界から呼ばれない。一般の証明なので結論は変わらないが、PathIn の保持値を Top へ広げて逆転する例があると、`no_request` の負例と対になる。L50 で足す。

**軽5. `checkedRequest_facts` の A は表と結ばれない**（読めば確定）。A は存在量化なので、表の型の述語を読むには `checkedRequest_content` と `facts` を別に合成する。境界の `retained_fact` は `facts` を使わず、`getD` の既定値を含む `assume` を直接使う。`req.toTerm?` は some なので誤りではない。`facts` を通す形に替えると、依頼の確認点1と揃う。

**軽6. 表の並置に `valKind` がない**（読めば確定）。`Refinement.TargetTable` は `valContent` だけを置き、境界の `B` は `valKind` を手で書く。L50 の表の具体化で旧 `TargetTable.valKind` を同じ形で並置する。

**軽7. 残りの列挙に `.atError` がない**（読めば確定）。`.atError` は `data` の型を持ち、`toTerm?` は `dataValue` を返すが、`inv_con`・`field_facts` の対象ではない。L40 の残りの「関数・Map/Set・辞書・lazy 等」に明記する。

## 取りまとめへの申し送り

| 送り先 | 内容 |
|---|---|
| 設計者 | 中1の `groundTy` の `.refined` の扱い（D07 との関係、直す時期） |
| L40/L50 | 中2の三つの補題と、O049 の義務への追記。軽2・3・7 |
| L50 | 軽4・6 |
| L00b.15 | D20/D28 の新旧対照に、`groundVal` の定義の範囲を含める |
| L30 以降の比較 | 中1の入力で Rust と Lean の結果を比べる |

## 取りまとめの追記

2026-11-01。補助の入力 `<tmp>/rv13/W2.lean`・`W3.lean` を `l00b.13/rv-13-w2.lean`・`rv-13-w3.lean` へ写した。`W1.lean` は未完なので写さない。処置は次のとおりである。

- 中1: 同じセッションで `groundTy` に `.refined` の枝を足す。理由は plan.md の 2026-11-01 の行に書いた。
- 中2: 三つの補題を `AtPrepare.lean`・`AtInput.lean` などへ置き、実際の `E_AtOk` から `CheckedWitness` を作る正例を準備の結果を入力に取らない形で通す。
- 軽1: 説明を直す。
- 軽3: `list_element_facts`・`field_facts_by_type` を本番へ置く。
- 軽5: `retained_fact` を `facts` を通す形に替える。
- 軽2・軽4・軽6・軽7: L40／L50 の義務として `l00b.13/signatures.md` に書く。
