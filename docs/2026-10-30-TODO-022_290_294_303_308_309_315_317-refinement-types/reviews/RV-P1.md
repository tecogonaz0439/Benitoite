# RV-P1: 捨てる試作 P1（値に依存する篩型の Lean の骨格）のレビュー

2026-10-30。レビュー担当は Opus 5.5 のサブエージェント（effort medium）。対象は試作 P1 の全体（後で改造の `spikes/P1/` へ写す。下のパスはその写しの中の位置）。レビュー担当はファイルを書き換えず、報告を応答で返した。取りまとめが要点を保存した。

## 再検査で確かめたこと

- `lake env lean -M 12288` で Skeleton.lean は終了0・3.67秒・最大常駐量 834,551,808 バイト、Constants.lean は終了0・0.33秒・699,318,272 バイト。警告なし。`#print axioms` は propext・Quot.sound・Classical.choice だけ。`sorry`・`admit`・独自の `axiom` はない。
- 「実際の Release の定義で `integer8 128` が型付く」は正しい（本番の `Release/Syntax.lean` で `integer8 (n : Int)` が生の Int、`Typing.lean:528` の `V_Const` が `c.type` を無条件に与える）。

## 重大

- **S1. 逆転と置換を意味のモデル（`Ty.Mem`）で証明しており、本番の構文の導出には写せない部分がある**: `TyLe.list_inversion`（Skeleton.lean:751）は意味のモデルへ落としてから要素を取り出し、結論も意味上の `a.Subtype` である。本番の `V_Sub`（Typing.lean:577）が要るのは構文の `Ty.Le` である。また `TyLe`・`TelLe`・`Eff.Covers` の導出が移動と四種の置換で閉じることを証明していない（本番では `Ty.Le.substAt`/`subst`/`shift`、`Release/Lemmas/Basic.lean:99-109` に当たり、直接参照の中心）。調べ 5.2 の「行/型/範囲/値の置換で一原子の被覆が保たれること」の条件を P1 は閉じていない。修正案: List の逆転を構文の補題（最外の carrier の要素型どうしの `TyLe` を返す形）で示し、`TyLe.bind`/`TyLe.map`/`Eff.Covers.bind` を導出の帰納法で示す。P3 か本番の最初の作業に名指しする。
- **S2. 棚卸しが Ty.Le を素通しする文脈変更の補題を落としている**: `V_Sub`/`C_Sub` の枝を持つのに直接参照にも構造の候補にも入らない定理が Release 24件・Surface 3件ある（`HasTypeVQ.subst`（SubstTyping.lean:192）、`HasTypeCQ.subst`（同242）、`HasTypeVQ.rename`/`store`/`hide`、`q_mono`、`subst_congr`、`localRefs`、`hideBuilders_strengthen_val`（Typing.lean:724）、`HasTypeCQ.withReturn` など）。新しい部分型は `Γ;Φ` に依存するので、これらはどれも文脈を変えたときに Ty.Le の導出が保たれることを示す必要がある。修正案: 棚卸しの p1 に `V_Sub|C_Sub|\bhle\b` を加えて優先集合を作り直し、変更の種類に「Ty.Le の文脈依存化（Γ・Φ を引数に取る）」を加える。

## 中

- **M1. 変数の表現を独立の判断として扱っていない**: P1 は名前空間を型引数で分け、束縛の下で `Option V` を足す表現（well-scoped な入れ子の型）を使い、四種の置換を一つの `mem_bind` で閉じた。本番は Nat の de Bruijn の番号と `Ty.WF` である。停止性の証明で heartbeat の上限に2回達した（検査 07・09）。修正案: 計画で表現を先に決める。変えるなら構造の候補515件へ波及し、変えないなら四種の置換と移動の交換の補題を別に見込む。
- **M2. 構造的な record の欄の共変を本番の `data` の変性の根拠にしない**: 本番の `Ty` に構造的な record はなく名目型の `data d args` がある（Types.lean:44-59）。修正案: findings の「List とレコードの共変」を「List と構造的な欄の列」に改め、data の変性（関数の欄の負の出現・相互再帰）は未着手とする。
- **M3. 部分型の置換の前提が、値に依存する型・行の像を事実上除いている**: `Ty.Subtype.substitution` の `ok` は Φ' を満たすすべての ρ について `θ.pull w η' ρ = η` を要求し、型・行の像が値の変数に依存すると成り立たない。修正案: 明記し、解釈 η を ρ に依存させるか導出の置換（S1）で扱う。
- **M4. Reference・Fail の不変を生の構文の等号で定めている**: 調べ 5.1 の型の等号は正規化の後の構造の一致（`T{true}`→T、入れ子の平坦化）である。`reference_inversion` と `fail_invariant` は言明の形が変わるので修正の見込みに入れる。
- **M5. 閉包・セル・継続の「局所的な保存」はほとんど定義の展開である**: `CellState.write_keeps_contract` は `⟨rfl, hv⟩` だけ、`ClosureTwo.run_preserves`・`ContinuationOne.resume_preserves` は `Valid` の展開。`Comp` に関数適用がなく、依存する β も意味による型付けの置換の補題である。修正案: 「閉じた」を「閉じた契約の形（`ClosedTy`）を定め、局所の保存は定義から従う」に改める。有益な成果は `ClosedTy` の形と反例 `cannot_discard_captured_environment`。
- **M6. 三案の比較の論拠は文章に頼っている**: Lean が示したのは一例を表せることだけ。専用構成子案の16構成子には調べ L02 で断る `fnWhere`/`referenceWhere` まで含まれる。添字案の利点（入れ子の篩が生じず平坦化が要らない）を挙げていない。`refined` を推す結論は成り立つ（既存の構成子の引数を変えないので、既存の場合分けへの影響が一枝の追加で済む）。修正案: 本番の `Ty` の `cases`/`match` の箇所数で論拠を量で示す。
- **M7. 290〜500件の見込みの導出は質的で、上振れの要因を書いていない**: 標本を直した実績がなく、S2・M1・M2 の要因も入っていない。本体の時間を据え置くことは「下げない」意味では妥当。修正案: 計画の最初の較正として、本番の粒度で一群（`Ty.Le.substAt`/`shift` と `HasTypeVQ.subst` の `V_Sub` の枝）を直して時間を測る。

## 軽

- **L1. 定数の抽象化は 0.0.13 の保証の穴ではなく、既存の決定を改める案である**: 07-04 は幅付きの整数の範囲を型付けの前提にしないこと（772行）、対象のない Top の不透明型の定数と `shapeAt` の扱い（276・281行）を記録済みの決定としている。主定理はより広い型付けのもとでより多くのプログラムを量化しており、0.0.13 の主張は弱まっていない。設計者への報告は「0.0.14 で改める既存の決定（Q07）」とする。ただし Decimal の仮数と scale を前提にしないことは 07-04 に明記がない（記載の漏れ）。`ConstOK` の値は `decimal.rs:4-15` と一致する。P1 の最小変更には、表層のリテラルの型付けと脱糖（性質1）の範囲の前提（07-04:787 の字句の範囲検査を形式化しない、が変わる）と、対象型の定数を除いたときの ShapeOk・TargetSound・ModelTargets/ModelHttp への波及が抜けている。
- L2. main-theorems.md の `Basic.lean:88` は `Release/Lemmas/Basic.lean:88` と書く（Core にも同名の補題がある）。
- L3. `Pred` に `targetMember`・`constructorTest` がなく、ソートに boolean などがない。範囲の添字を篩の述語へ寄せるかは P1 では決まっていない。
- L4. `#print axioms` は代表の11件だけだが、警告がないことと grep から穴は残っていないと判断できる。

## 計画の入力として使ってよいもの

`Ty.refined carrier pred` と引数の列（`Tel`）、self を `none`・外側の値を `some` で区別する束縛、観測の失敗を `Option` にする論理の意味、F3 の向きと反例 `cannot_split_one_atom`、Reference と関数の構文の逆転の形（`refContent`、`fn_relation` から `TelClosure`、`names_eq`）、旧 `eq_of_not_fn` の反例、置換の合成の形、閉じた契約の形と環境を捨てる案の反例、定数の葉へ表現可能性を要求する方向、直接参照 Release 75・Surface 20 の再現、本体の時間を P1 の速さで下げない判断。

## 直してから使うもの

S1・S2・M1〜M7・L1 のとおり。

## P3 で確かめるべき残り

一原子の被覆が四種の置換で保たれることの導出の証明、構文の V_Sub と文脈に依存する Ty.Le の接続（`HasTypeVQ.subst` の `V_Sub` の枝が代表）、範囲の添字と `targetMember` の関係、対象型の定数を除いたときの shapeAt・TargetAgreement・io_exists への影響、表層のリテラルに範囲の前提を加えた場合の性質1。

## 取りまとめの対応

P1 は直さない。P3 が終わったら、上の「P3 で確かめるべき残り」が閉じたかを確かめ、閉じていなければ P3 のセッションを再開して続けさせる。S2・M1・M7 は計画の入力（棚卸しの作り直し、変数の表現の判断、最初の較正の作業）へ写す。L1 は設計者へ「0.0.14 で改める既存の決定」として報告する。
