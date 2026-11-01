# l20/detail.md への反映の依頼

2026-11-02。取りまとめが反映する内容であり、担当は detail.md を変更していない。

## S02・S12.9 の署名

十の移送の前提の ClosedTypeSubstInput と RowTransport の間に、TypeSubstCode を入れる。完全な定義・十四署名は signatures.md の r1 と、既定ビルド内の TypeSubstContracts.lean を正とする。

TypeSubstCode es source は `es = [] ∨ ∃ nr nt ne nv, source nr nt ne nv`。source は値・計算の SourceScoped、列の scopedValues、腕の scopedArms、節の scopedClauses とする。At は任意の bases・pattern・input に同じ深さの SourceScoped を要求する。TelArgs は実引数列、TelBody は本体の SourceScoped を読む。三つの恒等と一つの True の成分は変更しない。ClosedTypeSubstInput の九欄はそのままとする。

SourceScoped の深さの存在は実行時専用構文を除く条件であり、像の形成・kind・制約・Q の条件を代わりに担うものではない。SourceScoped の定義を変えていない。C_ResumeL の源は resume の継続値が loc なので、その SourceScoped は False である。

## L20.40・.44・.57

WF000 の「閉じた型」を、行置換でも不変と扱う説明を直す。行像が空なら元の型の正規形になるが、自由な rho は WF000 に含まれ得る。V_LocRef・V_LocLazy・C_ResumeL・V_Closure は、行像が空なら本番の四 case 補題で閉じ、非空なら SourceScoped の矛盾で除外する。四補題は TypeSubstFormation.lean にある。

V_Closure は直接の RuntimeShape の不一致だけでなく、Sub・Normal・Refine を含む置換後の型付けが不可能な例を r1-closure.lean で確認した。元の型付けは成立し、新しい TypeSubstCode はその源を拒否する。

## 四経路の供給

E_Fun は Program.WellFormed.defs の Def.Scoped から本体の SourceScoped を取る。Def.WellTyped 自体に SourceScoped はない。本体の型付けは Program.WellTyped.defs から取る。E_Meth は Program.WellFormed.impls の ImplDecl.Scoped と実際の classes/methods の lookup から取る。E_Op・E_OpFail は行像が [] であり、本体の SourceScoped を要求しない。r1-paths.lean に保存した。

## 中1: V_Prim の交換に残る条件

r1-primitive.lean は、行変数を内部の関数型に持つ引数、neffs=0、eff=empty の pure 署名を作る。PrimitiveAdmissible・SignatureInstance・SourceScoped の源と V_Prim の導出が存在するが、外の行像 [empty] に対する Tel の交換の等号は偽である。StoreShape の pure 枝は True。IO の ShapeOk と StoreShape も、この境界外の行を持つ引数型を除かない。独立した CoreAssumptions の充足例は構成しておらず、この入力だけから S02 全体の否定を宣言しない。

本番の定義は変更していない。取りまとめへの候補は、PrimitiveAdmissible に `sourceTelRows : s.tel.RowsIn (· < es.length)` を加える構造条件である。rowCount から s.neffs の境界と等しくなる。これを採ると V_Prim と BuiltinArgs が読む入力の中身が変わるので、型付けの規則の新しい変更として先に判断が要る。CoreAssumptions に新しい欄を足していない。

直接の構成・移送は PrimitiveAdmissible.norm/map、ShiftMap.primitive、TypeCtxMap.primitive、TypedImages.primitive、ReferencePreservation の参照組み込みの具体化。元の対応と実表の根拠は Legacy の入力と表の対応、および L60 での各実署名の全 Tel の照合へ波及する。Narrowing・V_Prim の呼出し・BuiltinArgs.normalized はこの条件を読む。既存の eff の sourceRows と sourceQ だけから供給済みとしない。

StoreShape の pure 枝や ShapeOk を強めて全署名の条件を Core の既存欄から得る案も、信頼条件の意味を強める変更になる。独立の新しい信頼条件で埋めず、取りまとめが構造条件とその供給元を決めるまで、この修正の実装は行わない。

## 検査の指定

文書変更に伴う spec_tally と spec_examples を work の選択へ含める。初回 A3b の formal_build だけの指定は、この二つを省略した計画からのずれである。レビューの実行結果とは別に、r1 の work で三つを実行する。
