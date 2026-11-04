# L50-plan 下書き作成の結果

2026-11-04。計画担当による自己点検である。指定ブランチは `m014/l50-plan`、B_WORK は `09b0ea34fe8b68d65a4933c58a6c16b80c7de1f3`。ブランチの照合・切替・作成・コミットを含めGitの操作は行っていない。リポジトリで書いたのは[detail.md](detail.md)・本書・再開2で分けた[u02-options.md](u02-options.md)だけであり、本番のLean/Rust/設計書/plan/レビューは編集していない。Leanの補助入力だけを一時領域に作った。L50の実装・段末のレビュー・受け入れは行っていない。下書きのRV-L50-planの処置は末尾「再開1」「再開2」に記録する。

## 下書きの集計（再開2反映後）

| 対象 | 結果 |
|---|---|
| 作業単位 | L50.01〜.60、60単位 |
| 群 | A方式、B全σの被覆、CU1/single、D準備/At、E共通表/チェックδ、F純粋応答/八保存、G7IO、HModel、IModelTargets、JModelHttp、K全位置/読者、L段末、計12群 |
| 所要時間（能動時間） | 個別積上げ38時間30分〜71時間05分、中心54時間47分30秒。段の枠36.5〜84時間・中心60.25時間は維持。待ちは別 |
| 入口で控除 | C01〜C21の21作業項目。C19のEff.Allows/正規化、C20のcanonical_held、C21のIO/PathBases事象被覆を追加。既存構文/解決/被覆の構造/適格性/保持逆転/Atと発行の保存/実開始入力/条件定義/同じ要求の射影/論理と標準の葉。控除の架空の時間を置かない |
| 義務の母集団 | plan担当26行、L20残る段9行、L30残る段4行、L40残る段13行。和集合29行、planとの差O022/O034/O065 |
| 義務の分類 | 上記29＋全L共通4＝33行。技術26・記録2・他段1・共通4。各行に単位/完了判定/残る段あり。今回の実装完了/全体閉鎖0 |
| 申し送り | H01〜H31、技術24・継承5・他段2。g/casesの全有効σの9行も受ける。L40全33申し送りを再移管せず、L50への出どころを一件ずつ照合 |
| 規則と葉 | RangeExpr9対、based PathPattern4対、RangeIx4対/Atom9対、値29規則/Val25構文、Checked小モデル15葉（継承）、U1二規則/4保持経路/7位置、checkAt8葉/準備の局所23葉、接続は準備失敗15葉＋成功4経路×8葉（上限47）、AtFailure7構成子（base展開11）、At/発行5遷移、IOShape3形/Outcome3枝、実応答6読者、13範囲API＝IO7＋pure6 |
| モデル | 共通16署名。新Model3/ModelTargets15/ModelHttp7の延べ25署名行。担当25条件×3＝75欄。external3＋release1の3モデル分12欄をL60に残す。新Core全体の充足と呼ばない |
| 本番追随 | 最初の14目的は新移植13＋T07継承1。残り13、計27目的（新規候補26＋継承1）の在庫と区別。測定専用の作業なし |
| 方式の確認 | 初回の4命題に加え、レビュー入力のValidなしのF01二式を再現。F03/F04は今回も型検査までであり、将来の.02で証明する計画へ変更。F09の型検査と実表充足を区別 |
| 判断 | J50-1は内部保存をL50、公開名/完全署名/観測写しをU02確定後・L70前に分離。J50-2は未承認前提/公理/精密外部状態の停止条件で追加案なし。L40段末は2026-11-04に受け入れ済み |

## 読み取りと差の扱い

共通依頼文を最初に読み、planの指定節、L50担当の全26義務と状態、変更の全行、decisionsのD/U/DET-R、READMEの設計者の決定を確認した。前段の段末/義務/申し送り/実署名、L40各群の結果と再開、L00b.15の対照/写し、レビューのL50受渡しと取りまとめ追記、effort-ledgerを照合した。

初回はC01〜C18、再開1ではC19〜C21のファイル/名前を加え、旧Scope/Checked/Membership/Target/Model/ModelTargets/ModelHttp/TargetTableの対応を読んだ。RustはFile6入口のretained_path、http_client.rsのsend_in/start_send、http_client/checked_request.rsのretained_request/matches_endpointを読んだ。PathBases/path_bases/checkPathAt/checkPathInAt/checkRequestInAtはsrc全体で0一致（検索の終了1）であり、新σ実装の確認済みという記録にしない。

AtErrorの形は、ScopeSyntaxのtextFieldsがreprStrを使うことと、AtPrepare.prepareCoreの解析失敗が元入力を仮の値に置き換えることから、D61/公開形への対応を群Aへ置いた。再開1で内部元入力の保存をL50の範囲へ固定し、公開形の二案をU02の材料に分けた。再現条件を残していなかった字句一致の数を除き、.04の読者の棚卸しで確認する形にした。

L40群E/Gの未完は再開で閉じた最新の結果を継承した。演算子34行・構造Equality・通常decoderの接続をL50へ新しく移管していない。外側の時間を能動時間の実測として外挿せず、完了判定に実δ・全入力・応答存在・同じ対象・実読者を明記した。

## 道具と所要時間

実行したLeanは4.34.1、arm64-apple-darwin24.6.0、commit `5045d0056413266e57c625dcd7c365b10e377c52`、Releaseである。formal/lean-toolchainの固定版と一致した。下書きと自己点検の外側の時間は約30分であり、所要時間（能動時間）と待ちは分離していない。L50実装の60単位の実績へ算入しない。

## 短いLean試行

formal/で `lake env lean -M 12288 <tmp>/benitoite-l50-plan-shape.lean` を実行した。リポジトリの入力・import・生成物を書き換えていない。lake buildは実行していない。以下のソースは最終入力の全文を本書に保存したものであり、一時領域を永続の根拠として参照しない。

| 実行 | 終了・外側の時間 | 結果 |
|---|---|---|
| 初回：4命題と既存8宣言の型 | 終了1、0.246028542秒 | append_coverでsimpがFalseの枝を閉じたのに四本のbulletを残し、次の枝がずれた。unsolved goalsとNo goals to be solved。失敗時のappend_coverにはLeanのエラー回復によるsorryAxが表示された。証明済みに数えない |
| 枝の修正後 | 終了0、0.252835875秒 | 不要なcases hのbulletを除いて記号的appendを証明。4命題とも許可三公理の部分集合だけ |
| F03/F04命題型とF09定義形の追加後 | 終了0、区間全体の外側の時間は未取得 | execが1.001526333秒で継続セッションへ移り、その後の回収までの待ちを分離して記録していない。能動時間へ換算しない。4命題の証明と新しい3型の型検査が成功 |

| 証明した完全名 | 最終の#print axioms |
|---|---|
| L50PlanShape.append_cover | propext |
| L50PlanShape.shape_single | propext |
| L50PlanShape.at_current | propext、Classical.choice、Quot.sound |
| L50PlanShape.different_base | propext |

F03Type/F04TypeはPropの定義であり、これらの命題を証明した意味ではない。ModelScopeConditionsも出力の構造体の型を確かめただけで、モデルで各欄を構成した意味ではない。既存8宣言の#printではなく#checkを実行したことと、段末の全環境A-Lを区別する。

最終入力は3860 bytes、SHA-256 `cf7af8e876e5b74466f79d9ee6bbe608efbda9c75ba6a25c35b0bf40d36b4b69`。

```lean
import Benitoite.Release.Refinement.LeafInputs
import Benitoite.Release.Refinement.PathBasesLeaves
import Benitoite.Release.Refinement.ModelHttp
import Benitoite.Release.ShapeOk
namespace L50PlanShape
open Benitoite.Release.Refinement
open Benitoite.Scope.Domain

theorem append_cover (base : Word) {p q : PathPattern} (h : p.Covers q) :
    (PathPattern.atBase base p).Covers (PathPattern.atBase base q) := by
  cases p <;> cases q <;> simp only [PathPattern.Covers, PathPattern.atBase] at h ⊢
  · exact congrArg (base ++ ·) h
  · obtain ⟨r, hr⟩ := h
    exact ⟨r, by rw [hr, List.append_assoc]⟩
  · obtain ⟨r, hr⟩ := h
    exact ⟨r, by rw [hr, List.append_assoc]⟩

theorem shape_single {sg : PrimSig} {ws : List Val} {k : Kind} {p : Nat} {t : Target}
    (hs : sg.shape = .single k p) (ht : (ws[p]?).bind Val.target? = some t) :
    sg.shapeAt ws = .single k p := by simp [PrimSig.shapeAt, hs, ht]

theorem at_current {σ : PathEnv} {r : RangeExpr} {snapshot : Option PathEnv}
    {kind : Kind} {t : Target}
    (hm : SnapshotMem snapshot kind r t) (ha : SnapshotAdequate σ snapshot r) :
    r.Mem σ kind t := hm.current ha

theorem different_base (a b : PathBase) (h : a ≠ b) (p q : PathPattern) :
    ¬ (RangeExpr.based a p).Covers (.based b q) := by
  simp [RangeExpr.Covers, h]

#check HasTypeVQ.inv_checked
#check HasTypeVQ.inv_checkedAt
#check HasTypeVQ.inv_checkedRequest
#check TelClosure.apply
#check StateTyE.primitive_contract_inputs
#check StateTyE.externalRef_contract_inputs
#check ModelHttp.valueRun_checkedAt_request
#check Builtins.CoreAssumptions
#print axioms append_cover
#print axioms shape_single
#print axioms at_current
#print axioms different_base
end L50PlanShape

namespace Benitoite.Release.Refinement.L50PlanTypes
structure ModelScopeConditions (P : Program) (B : Builtins) : Prop extends
    Builtins.SubstitutionAssumptions P B,
    Builtins.ResponseAssumptions P B,
    Builtins.TargetAgreement P B where
  sig_scoped : ∀ b s, B.sig b = some s → PrimSig.Scoped P s
  sat_unconstrained : ∀ t : Ty, t.WF 0 0 0 → B.sat [] t.norm ({} : TParam)
  admits_sat : ∀ b s C ts, B.sig b = some s →
    s.admits (TypeCtx.constraints C) (Ty.normTys ts) →
    SatAll B C ts (s.tparams.map TParamDecl.constraints)
  pathBases_shape : ∀ b s, B.sig b = some s → s.kind = .pathBases →
    s.PathBasesShape B b
  io_op : ∀ b s, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    B.ShapeOk b s
  opEff_io : ∀ b s l, B.sig b = some s → s.opEff = some l →
    s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases
  effect_ops : ∀ l bs b, B.effects l = some bs → b ∈ bs →
    ∃ s, B.sig b = some s ∧ (s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) ∧
      s.opEff = some l
  state_effect : B.effects stateEff = some []
  ref_get : ∃ s, B.sig B.refGet = some s ∧ s.kind = .refGet
  ref_set : ∃ s, B.sig B.refSet = some s ∧ s.kind = .refSet
  store_shape : ∀ b s, B.sig b = some s → s.kind ≠ .pathBases → s.StoreShape
  store_admits : ∀ b s C ts, B.sig b = some s → s.kind ≠ .pure → s.kind ≠ .io →
    s.kind ≠ .exit → s.kind ≠ .pathBases → ts.length = s.tparams.length → s.admits C ts

def F03Type : Prop := ∀ {P B Ψ Q v T o k r σ},
    HasTypeVQ P B Ψ Q [] [] [] v T → T.Holds o k (.fixed r) →
    B.valKind o = some k → v.Adequate σ →
    ∃ t, v.target? = some t ∧ r.Mem σ k t

def F04Type : Prop := ∀ {P B Ψ b sg ts es rs ws a e k p σ},
    B.ShapeOk b sg → sg.shape = .single k p →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    (∀ w ∈ ws, w.Adequate σ) →
    ∃ r t, rs = [r] ∧ (ws[p]?).bind Val.target? = some t ∧
      r.Mem σ k t ∧ sg.shapeAt ws = .single k p
#check ModelScopeConditions
#check F03Type
#check F04Type
end Benitoite.Release.Refinement.L50PlanTypes
```

## 初回の文書の自己点検（再開1前）

Pythonの読み取りによる自己点検は終了0であった。検査台本は補助ファイルに書かず、その場で実行した。

- 60単位が連続し、各単位が一つの群へ所属。12群は各5単位。
- 単位の幅の合計2,390〜4,455分、中心3,422.5分。群別はA 215〜405、B 175〜320、C 205〜390、D 200〜380、E 240〜450、F 245〜480、G 200〜330、H 175〜320、I 195〜370、J 195〜360、K 185〜350、L 160〜300分。
- plan/三段末から再抽出した義務集合と、本文のP/20/30/40の入力タグが完全一致。33行に重複なし、分類26/2/1/4が一致。
- 申し送り30行に重複なし、分類23/5/2が一致。控除18、最初の移植14も一致。
- Markdown表の列数、コードブロックの開閉、相対リンク先の実在を確認。手元の絶対パス、docs/todoへのリンク、一時領域への根拠リンク、未置換の節マーカー、禁止された時間の呼び名はなし。
- 最終の大きさはdetailが100 KB未満、resultsも100 KB未満。本文を分割する追加ファイルは作成していない。

最終の既存名の所在の検査は一度終了1になった。primitive_contract_inputsを、そのimport元のLeafInputs.leanに直接宣言されているものとして照合したためである。実際の定義はApplicationInputs.leanであり、detailのC14と照合先を修正した。命題の実署名とLeanの検査結果は変わらない。修正後の自己点検は終了0である。

初回の自己点検で計算した単位の合計に誤りはなかった。手動で書いた「残る手順」の群B〜K/群Lの小計に10分ずつのずれがあり、最終点検の前に単位表の和へ合わせて修正した。検査自体の終了1ではない。


本作業ではRustのテスト、既定lake build、scripts/check.sh、全比較、ベンチマーク、LLMによる評価は実行していない。計画の下書きと許可された短い形の試行だけを行った。正式RSSは未取得（計画上の非採取）。独立レビューと受け入れは取りまとめ/設計者の担当である。

取りまとめはdetail第11節に従い、planへの転記と所見の処置の確認を経て実装を起動する。L40は受け入れ済み、U02は公開写しの前・L70前に確定する。下書きや自己点検を実装完了又は受け入れの記録にしない。

## 再開1：RV-L50-planの所見の処置

2026-11-04。開始は15:30:35 JST（06:30:35 UTC）、終了は15:43:20 JST（06:43:20 UTC）。指定の2文書だけを変更し、Gitの操作、本番Lean/Rust/設計書/plan/レビューの編集は行っていない。初回の試行ソースと自己点検の数値は履歴として保ち、現行の集計は冒頭と末尾「再開2」を正とする。

| 所見 | 処置とdetailの場所 |
|---|---|
| 中1 | 第1節にC19を追加。F02はEffectFactsの既存Eff.Allows（memによる定義）を使用し、EffectTargetsには読者だけを置く。T07は継承へ分類し、新移植13と分離。.09/.10の範囲・見込みを縮小 |
| 中2 | C20にCanonicalValuesのcanonical_held、C21にBuiltinEffectsのIO/PathBasesの事象被覆を追加。F03は四形への限定を再利用し、ConstOKでopaque定数を除き、三逆転とF01で所属を得る。.02で証明、.11は全場合と読者の照合へ縮小。O060は既存被覆とF02/F05の新接続を区別 |
| 中3 | F10・J50-1・.04/.20/.53とO097/H20/H21を修正。L50はD61の内部保存だけを行い、reprStr保存/解析失敗の仮入力置換を除く。公開名・完全署名・観測写しはU02確定後・L70前。第9節「U02に提示する公開エラーの二案」に欄名/型・照合例・OutsideScopeとの関係・写しの仮見込みを追加 |
| 軽1 | 群AはF01〜F10すべての型検査とF03/F04の証明を要求。群Dは23局所葉×8葉の全184組に三遷移又は到達不能の実定理を対応。群Kは照合の各行に実定理又は実δの完全名を要求 |
| 軽2 | F05の前提hc:CoreAssumptionsをhsh:ShapeOkへ変更。.35/.45は実表のShapeOkで適用でき、未構成のCoreを要求しない |
| 軽3 | 第7節H31にl40/g/casesの9行を個別列挙。.28はexternalRef/externalHandle/scopePattern、.53はatErrorの全有効σでのAdequateResultを受ける。F07に予定の補題名と全引数を量化する結論を記載。申し送りは31行へ更新 |
| 軽4 | H27を「25条件（sat_unconstrained/admits_satの2欄を含む）」へ修正。2欄を別加算しない |
| 軽5 | READMEの2026-11-04の設計者の決定を確認。冒頭・入口・義務・判断・起動手順をL40受け入れ済みにし、未回答の判断行を削除 |
| 軽6 | 再現条件のない字句一致のファイル数/出現数を両文書から削除。.04で検索字句と実読者を記録する形へ変更 |
| 軽7 | .57と第11節を「Leanのprivate宣言と自動生成の宣言」に変更し、ディレクトリとの混同を除く |
| 情報1 | F01のRangeExpr.Covers.memとSnapshotMem.monoはσ.Validを仮定しない強い形を採用。独立レビューの入力をそのまま再実行して確認 |

### 単位と所要時間（能動時間）の変更

単位は60、群は12で増減なし。控除は18→21項目、申し送りは30→31行（技術23→24、継承5・他段2は不変）。義務33行の分類26/2/1/4、三モデル75条件、規則と葉の母集団は変えていない。

| 単位 | 修正前 | 修正後 | 変更の理由 |
|---|---:|---:|---|
| .02 | 45〜90分 | 60〜105分 | F01の必要補助とC20を使いF03を先行証明し、F04も型検査だけで閉じない |
| .04 | 45〜90分 | 30〜60分 | 内部保存の方式とU02の材料に限定。公開形の実装を外す |
| .09 | 40〜75分 | 35〜65分 | 既存Allows/正規化を再作成しない |
| .10 | 30〜55分 | 25〜45分 | 新移植13と継承1を照合 |
| .11 | 45〜90分 | 20〜35分 | canonical_heldと.02のF03を使い全場合/実読者を照合 |
| .20 | 45〜90分 | 40〜75分 | D61の内部保存と既存読者へ限定 |
| .53 | 45〜90分 | 30〜55分 | 内部保存/全失敗/適格性の照合へ限定 |
| 全60単位 | 2,390〜4,455分 | 2,335〜4,315分 | 下端55分・上端2時間20分の減少 |

修正後の合計は**38時間55分〜71時間55分、中心55時間25分**。修正前の中心57時間2分30秒から1時間37分30秒減った。段の枠36.5〜84時間・中心60.25時間は変えない。群別の分はA 215〜390、B 165〜300、C 180〜335、D 195〜365、E 240〜450、F 245〜480、G 200〜330、H 175〜320、I 195〜370、J 195〜360、K 170〜315、L 160〜300である。

.02でF03を証明するため、必要なF01の所属補助を同じ単位で先行させる。.06〜.08はその証明を複製せず、全場合・具体化・論理/効果の読者へ接続する。F03/F04の本番証明を今回行ったとは記録しない。

J50-1の公開形の選択をL50の起動条件から外した。U02の材料の案Aは七Stringへの明示符号化（1時間30分〜3時間）、案Bは9欄recordと型付きdata（3〜6時間）である。どちらもU02確定後・L70前の写しの仮見込みで、短い代表1件から再見積もりする。独立レビュー/ビルド待ちは不明、L50の積上げへ加算していない。L70詳細化で既存枠との重複と担当を取りまとめが確認する。

### 再現と自己点検

独立レビュー[RV-L50-plan](../reviews/RV-L50-plan.md#再現の入力)に保存された入力を`formal/`から`lake env lean -M 12288 <tmp>/rv-check.lean`で再実行した。入力2,588バイト・SHA-256 `31b7bea42ecc34881cd765d26a743a46183c295a96e055172c020a94f3f16686`でレビュー記録と一致し、終了0、外側0.384189秒であった。入力の全文はレビュー内にあり、一時領域の絶対パスを根拠にしない。

既存Eff.Allows/normalization/canonical_held/io_event_coveredの実署名を確認できた。F01相当のRVL50.covers_memの公理はpropext/Quot.sound、RVL50.snapshot_monoはそれにClassical.choiceを加えたものだけであった。F03/F04/新F05の証明、既定build、work、Rustテスト、全比較は今回実行していない。正式RSSは未取得（計画上の非採取）。

文書のPython自己点検は最終状態で終了0、外側0.006673秒であった。60単位/12群の連続性と幅の和、群別と残る手順の小計、plan/三段末から再抽出した義務26/9/4/13・和集合29・共通4・分類26/2/1/4、H01〜31の分類24/5/2、控除21、T01〜14と継承T07を確認した。両文書の表の列数・コード囲み・相対リンク先と100,000バイト未満も確認した。detailは99,322バイト、SHA-256 `b1b0e6afdaaf144b1a4304a22f5545bc33945b186af0d879bc8b62858349c92c`である。初回の自己点検は起点名work/tmpを一時ディレクトリへの参照と誤検出したため終了1になり、パスの文脈を区別する条件へ修正した。独立レビューの所見の処置は下書きへ反映済みであり、修正版の独立レビューと取りまとめの受け入れは本節の自己点検に含めない。修正中のPython編集入力がUTF-8構文エラーで一度実行前に失敗し、apply_patchはハンクの順序が逆で一度失敗した。resultsの更新も置換文字列の不一致を検出して一度保存前に中断した。いずれもその呼出しによるファイル変更はなく、入力を修正して処置した。


## 再開2：再レビューの所見の処置

2026-11-04。開始は15:48:37 JST（06:48:37 UTC）。終了は本節末尾に記す。対象は[RV-L50-planの再レビュー（再開1）](../reviews/RV-L50-plan.md#再レビュー再開1)の再1中1・再1軽1〜3・情報である。指定のdetail.md/results.mdと、新しいu02-options.mdだけを変更した。Gitの照合・状態変更を含む操作、本番Lean/Rust/設計書/plan/レビューの編集は行っていない。再開1までの数値と処置は履歴として保ち、現在の集計は冒頭と本節を正とする。

| 所見 | 処置と場所 |
|---|---|
| 情報：detailの大きさ | 第9節の「U02に提示する公開エラーの二案」を[u02-options.md](u02-options.md)へ分けた。detailには要約と相対リンクを残し、F10/J50-1/H20からも分割先を参照 |
| 再1中1：既存6構成子との関係 | u02-options第2節にA/Bそれぞれ6行の対応表と、Atの7失敗から見た対応を追加。英語reference・Scope.bnt・Rustのtags/Failure/encoded/check_endpoint・実際の構築読者を照合。InvalidPattern/InvalidTargetの重複、旧reasonがAtにはないこと、port専用失敗がAtでは分かれないこと、OutsideScopeとDynamicCondition/StaticIndexの区別を明示。A/Bの横断照合例を追加。第3節で原則5と原則3/4の関係、旧構成子だけへ写す場合のD61への不足、Atの原因として旧構成子を再利用する選択肢を記載。選択はU02に残す |
| 再1軽1：群Dの母集団 | detail第2節・.18・群Dの完了条件を修正。準備失敗の終端15葉はE_AtPrepareErrorへ、成功4経路は各checkAt8葉からE_AtOk/E_AtErrorへ対応。15＋4×8＝47を上限とし、snapshotなしの拒否等で到達しない枝は実定理で排除して.18で実数を記録。23局所葉は中間判定を含む別の一覧として保持し、直積には使わない |
| 再1軽2：F04の二重計上 | 一般の依存列lookup→F03、任意pと型/値代入の扱いを.02のF04証明へ集約。.14は証明済みF04の実読者への適用・同じws/対象/要求の照合だけへ縮め、45〜90分を20〜40分へ減らした。.02は60〜105分を維持する判断とし、一般証明を.14でもう一度行わないことを両単位に明記 |
| 再1軽3：公開型・文書・後段の見込み | u02-options第4節で、末端を既存型へ写す具体案に基づき入れ子を含む新規19型を列挙。PathBasesも数える場合は共通1型を足しA=1/B=20と区別。第5節でAの公開JSONの符号表・要求5欄・整数/IP・復元・欠如/空列・版/互換・表示との分離の文書化項目を列挙。第6節でLeanの仮見込みにR30/R60/D10それぞれの影響と不明の見込みを追加。既知のLean分だけを全体の合計と呼ばない |

### 単位と所要時間（能動時間）の変更

単位は60、群は12で増減なし。今回の幅の変更は.14だけである。F04の一般証明は.02に集約するため、.02の見込みを追加で増やさず、.14で重複していた分を除いた。新しい公開型19個はBの比較材料であり、L50の新しい実装単位ではない。

| 対象 | 再開1後 | 再開2後 | 差 |
|---|---:|---:|---:|
| L50.02 | 60〜105分 | 60〜105分 | 変更なし |
| L50.14 | 45〜90分 | 20〜40分 | 下端25分・上端50分減 |
| 群C | 180〜335分 | 155〜285分（2時間35分〜4時間45分） | 下端25分・上端50分減 |
| 全60単位の下端 | 2,335分（38時間55分） | 2,310分（38時間30分） | 25分減 |
| 全60単位の上端 | 4,315分（71時間55分） | 4,265分（71時間05分） | 50分減 |
| 全60単位の中心 | 55時間25分 | 54時間47分30秒 | 37分30秒減 |

段の枠36.5〜84時間・中心60.25時間は維持する。群B〜Kは32時間15分〜59時間35分、群Aは3時間35分〜6時間30分、群Lは2時間40分〜5時間00分となる。枠との差は下端2時間、上端12時間55分、中心5時間27分30秒である。義務33行（技術26・記録2・他段1・共通4）、申し送り31行（技術24・継承5・他段2）、控除21項目、三モデル75条件に変更はない。

### U02の材料と残る判断

[u02-options.md](u02-options.md)は、A=七Stringと公開JSON規則、B=9欄recordと型付きdataを比較する。Aはエラー表現として新規の名前付き型を増やさず、Bは19型を公開する具体案である。Word/Portは既存List[String]/Integer、IPの数値はBytesへ写す前提を明示したため、公開する型の最終数を決定済みとはしない。共通のPathBases型、専用Port/原因型、追加APIの別型は別に数える。

両基本案では解析失敗の役割が旧InvalidPattern/InvalidTargetと重なり、At側には英文reasonがない。新しい詳細情報を持つ理由だけで重複の採用を確定せず、原則5と原則3/4に照らしてU02で選ぶ。旧構成子への単純写像ではD61の全欄をその値に残せない。Atの詳細を保ち、旧ScopeErrorを原因として使う案では、独立した失敗分類を除ける一方、原因の範囲/再帰の制限と公開契約を追加で定める必要がある。

Leanの公開写しはAが仮1時間30分〜3時間、Bが仮3〜6時間を保つ。Bは入れ子19型を数えた後の幅の十分性を未確認と記し、両案とも短い代表1件で見直す。R30の宣言・構築/保持・heap/stress、R60の表示/JSON・fmt、D10のreference/Skill/照合例は、それぞれ影響を列挙し時間は不明とした。したがって案全体の合計も不明である。これらをL50へ足さず、各段の詳細化時に既存枠との重複（R60内数の文書本体を含む）を取りまとめが照合する。公開形の写しはU02確定後・L70前のままとする。

### 定義の照合と自己点検

経路数はformal/Benitoite/Release/Refinement/AtPrepare.leanのAtPrepare・prepareCore・finishPreparationを読んで確認した。終端失敗の出現箇所はrvar 1＋pattern 1＋入力3＋bases 2＋finishPreparation 8＝15である。準備成功は入力のparse/reqTargetの2経路×basesのnone/有効someの2経路で4。PathResolution.checkAtの解決失敗3＋有効性2＋不所属2＋成功1＝8葉へ進むので、15＋4×8＝47を接続の上限とする。失敗終端の同じ箇所へ至る前段の分岐を繰り返して数えた全実行経路数ではない。

Step.stepRunのAt分岐とAtStateLeavesのStateTyE.at_ok_all/at_error_all/at_prepare_error_allを照合し、準備失敗は直接Error、成功ではsnapshotの一致後にcheckAtを呼ぶことを確認した。snapshotなしの成功時はfinishPreparationがbased/secrets/home/relativeを拒むため未解決の枝へ到達しない。実際の到達可能な数と実定理の対応は将来の.18の完了条件であり、今回証明したとはしない。

今回の作業は文書の処置と定義の読み取りであり、新たなLean試行、既定build、scripts/check.sh、Rustのテスト、全比較、LLM評価は実行していない。正式RSSは未取得（計画上の非採取）。自己点検は修正版の独立レビューや取りまとめ/設計者の受け入れを代行しない。

文書の読み取り自己点検（`rtk proxy python3 -`、その場の入力）は終了0、外側0.010681秒であった。60単位の連続性、12群の幅の和と群表、合計2,310〜4,265分、義務33行の分類26/2/1/4、申し送り31行の分類24/5/2、控除21項目、Leanの失敗終端15/成功4/checkAt8/上限47、A/Bそれぞれの旧6構成子対応表、Rustのタグ0〜5、Bの19型の列挙、3文書の表の列数・コード囲み・相対リンク43件（見出しも含む）・100,000バイト未満を確認した。自己点検の初回は、群の期待値をtuple、実際の値をlistとして比較したため終了1となった。両者の型を揃えて再実行し、文書の合計値に誤りはなかった。

detail.mdは97,103バイト、SHA-256 `cea2fb1ef25a5dc6b9e34c81a7b5133d5b2474329827b1e30fbb787ff44e68a8`である。

u02-options.mdは25,094バイト、SHA-256 `5c487f9d4acf85423c7b76dee3cf34402e77e259fd61963432c61470eef0bb10`である。

終了時刻の追記は、末尾のハッシュ行の文脈が一致せずapply_patchが一度保存前に失敗した。追記に切り替えた。失敗した呼出しによる既存内容の変更はない。

再開2の終了は2026-11-04 15:58:08 JST（06:58:08 UTC）。外側の経過は約10分で、能動時間と待ちは分離していない。最終追記を含む自己点検も終了0（外側0.009492秒）であった。修正版の独立レビューと取りまとめ/設計者の受け入れは未実施である。
