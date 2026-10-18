# 段2: 定義・言明・仮定の下書き（RV2初回の指摘修正、A2）

## 状態と読み方

2026-10-17、設計者は [decisions.md](../decisions.md) のR6で案B（名前と行の関数＋Fail列）、R13で一般の型の一致に正規形を採ると決めた。本書はその決定と、[RV2初回のレビュー全文](../reviews/RV2-initial.md) に対する設計者の回答（R14〜R17、2026-10-17）を反映した下書きである。初回の指摘は本書と計画へ反映したが、RV2全体の閉鎖はL4b後である。以下の新しい定義の停止性、補題、既存の定理への接続はすべて**未証明**である。正式なLeanへ未証明の宣言や公理として取り込まない。L1aは拡張したAPIの範囲で開始でき、R14・R15の決定はL1bの先行条件とする。

コード片は証明すべき命題と定義の設計記法であり、単独のコンパイル単位ではない。既存の型名を参照し、新設する補助名は本文で定義する。`…` を含む規則は省略した共通の引数を本文で指定する。`Goal` の定義も目標の表記であり、定理の仮定ではない。各作業は定義と証明を一緒に正式モデルへ反映し、既定の全体ビルドをsorryなしで保つ。

[L0の結果](results.md) は二案を試した当時の記録として保つ。縮小したBで検査したのは、相互帰納定義、型・行の置換の後に型だけを置換する合成、再帰的な有限支持の保存、比較からの被覆関係、Failなしの旧型での比較からの等号である。正規形を用いた一般の合成・等号は検査していない。逐次置換と合成でFail列が `[B1,B2,B3]` / `[B1,B3,B2]` となる反例は、生の列をそのまま使えない根拠として残す。案Aや商、同値関係による型付けの変換は、以後の実装の候補にしない。

## L1a: 旧表現の参照API

この作業では現行の `Eff := Atom → Bool` と規則を保つ。`Eff.mem ε a` を `ε a = true` とし、直接の関数適用をこのAPIへ移す。`mem_empty`・`mem_single`・`mem_union`・`mem_substRho` はそれぞれ空、名前一つ、論理和、現行の行置換の展開と同値であることを示す。次のAPIもこの作業で用意する。

| API | L1aでの意味と利用側の移行 |
|---|---|
| `Eff.ext` | 両辺のmemが全点で同値なら効果が等しい。効果についてのfunextをAPIの証明へ集約 |
| `Eff.ofAtoms` | 関数から効果を作る。L1b後はFail列を空にする。handled・singleEff・unionEff等の直接の関数構築を移す |
| `Eff.substAt c ts es` | 新しい署名を先に置き、L1aではcとtsを使わず現行のsubstRhoを呼ぶ。L1bでFail内の型置換とesのshiftを実装 |
| `Eff.shift k c` | L1aでは恒等。Ty.shiftからも必ずこのAPIを呼ぶ |

約700箇所の利用側と全証明の機械的な置換を終えてからL1bへ進む。`ε a` の直接の適用と効果についてのfunextは、APIの定義と補題の外に残さない。Failの生成や正規化はまだ入れない。

## L1b: Bの型・効果と正規形

### 生の表現と型の全構成子

`Atom` は現行どおり `.name (l : String)` / `.rho (i : Nat)` とする。現行のTyの構成子と契約名をすべて保ち、効果の型だけを相互帰納的なEffRへ替える。

```lean
mutual
  inductive Ty where
    | base (b : BaseTy)
    | opaque (o : OpaqueName)
    | data (d : DataName) (args : List Ty)
    | list (a : Ty)
    | fn (names : List String) (params : List Ty) (ret : Ty) (eff : EffR)
    | tvar (i : Nat)
    | reference (a : Ty)
    | lazy (a : Ty)
    | cont (b t : Ty) (eff : EffR)
    | map (k v : Ty)
    | set (a : Ty)
    | bytes
    | dict (cl : ClassName) (arg : Ty)
    | tapp (i : Nat) (args : List Ty)
    | ctor (c : TyCon)
  inductive EffR where
    | mk (atoms : Atom → Bool) (fails : List Ty)
end
abbrev Eff := EffR
```

`Eff.atoms` / `Eff.fails` は各欄の射影である。生の `.mk` とTyの構成子は再帰や証明のための表現とし、モデルへ渡す値は後述の正規化を通す。`mem` はname/rhoの関数を読み、生の値にも `memFail ε E := ∃ x ∈ ε.fails, x.norm = E.norm` と定義する。`Eff.Sub e f` はname/rhoの点ごとの包含と、`∀ E, memFail e E → memFail f E` の連言とする。`sub_norm : Eff.Sub e f ↔ Eff.Sub e.norm f.norm` を証明し、最上位の非正規な効果にも包含を使えるようにする。ReleaseではFail列の長さを制限しない。

### 型の上の固定した全順序

比較の順序は入力JSONや収集したatomsの順に依存させない。`tyCompare` は上のTy構成子の宣言順を順位0〜14に固定し、同じ構成子の欄を左から辞書式に比べる。BaseTyとTyConは現行の宣言順、Natは数値順、StringはUnicodeスカラー値列の辞書式順、Listは要素順（接頭辞は短い方が先）とする。fnの契約名列・params・ret・eff、dictのクラス名、contの両型も省略しない。EffRはatoms、failsの順に比較し、Fail列の要素はTyの比較へ再帰する。生の型の比較自体は列の順序と重複を区別する。正規化した子を比較して整列することで、代表を一意にする。

任意の関数 `Atom → Bool` に対しても数学上の全順序を定義するため、Atomに自然数の符号を固定する。案は次のとおりである。文字列のスカラー値をb=1114113進の数字 `c.toNat+1` として `strCode []=0`、`strCode(c::cs)=(c.toNat+1)+b*strCode(cs)` と符号化する。`code(name s)=2*strCode(s)`、`code(rho i)=2*i+1` とする。各桁が1以上b未満であることから単射性を証明する。文字列どうしの比較には前段の辞書式順を用い、この符号は関数の添字の順だけに使う。

二関数が異なるときは、値の異なるAtomの符号の最小値でfalseを返す方を先にする。全点で等しければ関数の外延性で等号とする。任意の関数の全点での一致の判定は計算的とはしない。非計算的な選択を使う定義は `atomsCompare` だけとする。`tyCompare`・型列の比較・`sortUnique`・`norm` はTy・Tys（型列）・EffRの構造的な相互再帰として定義し、燃料や整礎の再帰でカーネルの簡約を止めない。atomsCompareへの依存のためReleaseの操作にnoncomputableの指定が要る場合も、選択の使用箇所は増やさない。実行ファイルは後述の計算できる写しを使う。名前と行の関数の領域は有限支持へ狭めない。実行するcheckerの比較はL1cで有限支持から計算し、この定義との一致を証明する。全順序を新しい公理や `Builtins.Assumptions` の欄として与えない。

`tyCompare` / `effCompare` は型、効果、型列を同時に辿る。全順序の法則、eqとLeanの等号の同値性、相互再帰の停止をL1bで証明する。異なる関数の最小の相違点と有限構造上の辞書式比較を分けて示し、関数の符号やJSONのハッシュの一致だけから型の等号を結論しない。

証明は、Tyをラベル付きの多分木へ単射で写す方法で組み立てる。ラベルは構成子の順位・Nat・String・List String・`Atom → Bool` の和の型とし、多分木の辞書式順序の法則を一度示してから単射で引き戻す。`tyCompare_eq_iff` は写像の単射性から導く。最小の相違点はNatの整礎性で存在し、有限列の整列に必要なのは全順序である。整列順序であることは要求しない。

L1bの内部を二つの区切りにする。L1b1では表現を切り替える前に、atomsCompareの全順序と外延性、ラベル付きの木の順序と、任意の線形順序上の汎用sortUniqueの補題（`mem_sortUnique`・`sortUnique_eq_iff_mem`・冪等性）を独立モジュールに作る。ここでsorryなしの既定ビルドと状態報告を行う。L1b2で新表現へ切り替え、Tyの単射と正規化・既存証明を接続する。主作業はL1bの一つのまま、内部の区切りとして扱う。

### 正規化と不変条件

`sortUnique` は挿入ソートで `tyCompare` の昇順へ整列し、eqの要素を一つへまとめる。長さ0・1の列では比較を呼ばない。Failのない旧型と、すべての深さでFailが高々一つの型では、normのカーネルの簡約がClassical.choiceへ届かない形にする。L1b2の切り替えの冒頭で代表的なrfl/decideの例を直接確認し、終わりには既存の全例（約360箇所、レビュー時の概数）が簡約できることを確認する。`Ty.norm` は全構成子の子の型と効果を先に正規化し、契約名やほかの欄は保つ。`Eff.norm` は次の形とする。

```lean
-- Ty.norm / Eff.norm / 型列へのmapは同時再帰する。
-- Eff.norm (.mk a fs) = .mk a (sortUnique (fs.map Ty.norm))

def Ty.Canonical (t : Ty) : Prop := t.norm = t
def Eff.Canonical (e : Eff) : Prop := e.norm = e
```

`Canonical` は証明すべき表現の不変条件である。R14で設計者が認めた案(A)に従い、`Ty.WF n`・`Ty.WFList`・`Ty.VarsIn n pe`・`Ty.VarsInList` と新しい `Eff.WF n` をFail列の型の中まで再帰させ、型に埋め込んだ効果のCanonicalを要求する。ストアの整形式hΨにも、LocTyのすべての型と、`.cont b t ε R` のεについて同じ範囲・正規形の条件を持たせる。閉じた整形式の型からCanonicalを導き、`Ty.substAt_nil_of_wf` と継続の効果の空代入の恒等式を回復する。非正規な生の型に恒等式を適用しない。

型付けの最上位の効果はC_Subで任意の上位効果へ広げられるため、Canonicalを要求しない。最上位の効果の恒等式が要る箇所はEff.Subの両向きで書き直すか、その箇所の整形式からCanonicalを得る。`C_App` の型列の等号と `Ty.Le` の包含の定義を保ち、型内部の部分型や同値関係による変換規則は足さない。型付けの規則に結果の型のWFを加えるR21の決定と、型を保って最上位の効果だけを広げるC_Effの具体化（R22）を、この下書きのC_Subを保つ指定に優先する。

宣言・注釈・環境・ストア・継続の整形式と、構築・代入・更新での保存から必要な証拠を導く。R14は既存の定理の前提の意味を強める決定であり、単なる補題の追加とは扱わない。Failのない旧型はnorm_legacyで自動的に正規形となるので旧来の適用範囲は狭まらず、保証の範囲は弱まらない。07-04のeffect_soundnessにNamesWFを追加した前例とともに記録する。L1b2で01-12の写しと07-04の前提の一覧を同じ変更で更新する。この範囲内の変更はR12の停止条件に当たらず、範囲外の前提の追加は従来どおり止めて相談する。

| 操作 | 正規形を保つ定義の案 |
|---|---|
| empty / 名前一つ / 行一つ | atomsは現行どおり、failsは空。恒等の型変数も正規形 |
| singleFail E | `.mk (fun _ => false) [E.norm]` |
| union e f | atomsの点ごとの論理和、Fail列は連結してから `Eff.norm` |
| 名前の除去・handled | 通常の名前だけを扱う。残ったFail列は保持。専用Fail捕捉の残りも正規形として構築 |
| 型のshift・代入・行の具体化 | Fail内の全型も辿り、型を変更した後に整列・重複除去。行の像を連結した後も再実行 |
| TyCon.apply / Ty.applyTo / fnTy | 型構成子へ適用した結果と具体化したシグネチャを正規化。tappの種類が合わない場合も現行の扱いを保つ |
| 表層・脱糖・環境・ストア・継続 | 構築・更新した型と埋め込んだ効果の正規形を保つ。型付けの最上位の効果は正規形を要求しない |
| 交換の読み込み・書き出し | 読者で入れ子の型を正規化。checkerは読者が渡した注釈を再正規化せず位置ごとに比較し、計算した型だけをnormWithで正規化 |

以下の名前は**未証明の目標**である。rawは正規化前の構造を直接辿る補助操作を指す。

```lean
def NormIdemGoal : Prop :=
  (∀ t : Ty, t.norm.norm = t.norm) ∧
  (∀ e : Eff, e.norm.norm = e.norm)

-- Ty.norm_substAt / Eff.norm_substAt
-- normを入力と置換像の両方に入れる。右辺の最終normも省かない。
def NormSubstGoal : Prop :=
  (∀ (t : Ty) c ts es,
    (t.rawSubstAt c ts es).norm =
      (t.norm.rawSubstAt c (ts.map Ty.norm) (es.map Eff.norm)).norm) ∧
  (∀ (e : Eff) c ts es,
    (e.rawSubstAt c ts es).norm =
      (e.norm.rawSubstAt c (ts.map Ty.norm) (es.map Eff.norm)).norm)

-- 正式な公開操作はrawの結果を正規化する。
-- Ty.substAt c ts es t := (t.rawSubstAt c ts es).norm
-- Eff.substAt c ts es e := (e.rawSubstAt c ts es).norm
-- shiftも同じ構造で定義し、norm_shiftを証明する。
```

正規化がFailの意味を保つことを `norm_memFail` で示す。任意の生の型Eについて、正規化後の列にE.normが入ることと、元の列に同じ正規形を持つ要素があることを同値にする。name/rhoのmemは変えない。さらに、正規形が等しい生の型を代入した像も正規形が等しいこと、和・包含の順序/重複不変と合同性を示す。これはrawな型同士の同値関係を型付けへ持ち込む規則とは区別する。

### shift・代入・一般の合成

型変数のrawSubstAtの像は現行と同じcutoff規則を使う。`i<c` はtvar i、`i-c<ts.length` はtsの対応する型をcだけshift、それ以外はts.lengthだけ番号を詰める。tappは置換した型をTy.applyToで引数へ適用する。fnとcont自体は型変数を束縛しない。操作の節等でk個束縛するときにcutoffをc+kへ進める。

効果のrawSubstAtは、元のFail列の各型を置換し、元のatomsで選ばれる行の置換像のFailを連結する。行の像は、esの各効果をその位置の型束縛の数cだけshiftしてから使う。同じ代入を挿入した像へ再帰適用しない。name/rhoの置換は現行のEff.substRhoと同じく、`i<es.length` の行を除いて対応する像を加え、範囲外の行番号は詰めない。型引数から挿入した型の内部の効果も保持する。

一般の合成を記述する補助 `bind θ` では、θは型変数の像の関数と有限の行置換列の対（SubstEnv）である。型変数の像は型構成子の適用も現行どおり扱い、行の像は範囲外で恒等とする。binderではθを持ち上げる。合成 `compose θ φ` の各像はφでθの像を置換した正規形とする。

```lean
-- Ty.bind_comp / Eff.bind_comp の目標。bindは結果を正規化する。
def FullCompGoal : Prop :=
  (∀ (t : Ty) (θ φ : SubstEnv),
    Ty.bind φ (Ty.bind θ t) = Ty.bind (compose θ φ) t) ∧
  (∀ (e : Eff) (θ φ : SubstEnv),
    Eff.bind φ (Eff.bind θ e) = Eff.bind (compose θ φ) e)
```

有限列で行の合成像を作るときは、長さを `max es.length fs.length` とし、範囲外を行一つの恒等像で補う。型の像の関数をusと書けば各iの像は `bind (us,fs) (rowImage es i)` である。cutoff付きの有限列の置換がこのbindを実現することと、binderを持ち上げた合成、範囲・Ty.WFの保存も証明する。型変数のずらし `i ↦ if i < c then i else i + k` は狭義の単調な単射なので、rawなshiftがtyCompareを保つ `shift_compare` と、正規形を保つ `shift_canonical` を証明する。`norm_shift` はこれらの系として導く。行を含む置換では順序の逆転と重複の発生があるので、正規化の後の等号で合成を示す。Fail内の型変数をc=1,2だけずらす例とL0の反例の両側が同じ正規形になる例を補題の接続に使う。

| 補題群 | 追加の仮定・維持する結論 |
|---|---|
| `tyCompare_total` / `tyCompare_eq_iff` | 任意の生のTyで全順序と等号。有限支持を要求しない。順序の法則を仮定しない |
| `Ty.norm_idem` / `Eff.norm_idem` / `norm_memFail` | 任意の生の値で冪等・正規形・意味の保存 |
| `norm_shift` / `norm_substAt` / `bind_comp` | raw操作と正規化の交換、正規化した一般の合成。像の整形式等が必要な既存の範囲補題は元の条件を明示して維持 |
| `norm_WF` / `norm_VarsIn` / `norm_RhosIn` / `norm_support` | 正規化が、Fail内部へ広げた整形式・範囲・支持を保つ |
| `shift_compare` / `shift_canonical` | rawな型変数のずらしが順序と正規形を保つ |
| `canonical_of_failsLeOne` | すべての深さでFail列の長さが高々一つなら正規形。子の型にも同じ条件を要求し、交換の読者が出す注釈へ接続 |
| `Ty.norm_legacy` / `Eff.norm_legacy` | 全体にFailがない旧型でnormが恒等。Releaseの旧関数の支持は有限に制限しない |
| 既存のTySubst・TySubstMain・TyLemmas | 項・型の置換、LocTy/StoreTy/ContTyの更新へ上記を接続し、型の等号・進行・保存・効果の健全性を保つ。捕捉の新規則はL2b |

`Ty.Legacy` は全構成子の子がLegacy、fn/contの効果はfails=[]と定義する。`Eff.Legacy` はfails=[]とする（空なので内部のFail型もない）。これらから `norm x=x` を導く。外側の効果だけのNoFailや表層のFail列の長さ0/1から、Ty.Legacyを導く言明は置かない。

### Fail内部まで辿る定義とL1b末のビルド

再帰を広げる対象は、Ty.WF・Ty.WFList・Eff.WF、Ty.VarsIn・Ty.VarsInList・Eff.RhosIn、項の注釈のNamesWFとClosedNoEffVars、Ty.Support・Eff.Supportである。Failのエラー型の関数型・継続型の潜在効果にあるρまで調べ、閉じた状態に型変数や行変数を残さない。正規化による保存を上のnorm補題群で証明し、NamesWF・ClosedNoEffVarsにもその系を接続する。型付けの最上位の効果については、RhosIn等の範囲の条件とCanonicalを区別する。

R15で重大2の案(b)を採る。L1b2末では検査器が宣言・注釈・引数・環境の型を再帰的に調べ、Ty.Legacyでない型を一時的に拒否する。効果の入力・行の像もEff.Legacyを検査し、途中で計算した型と効果のLegacy保存を示す。`shiftTy`・`substTyAt`・`applyToTy`・`unionEff` はこの範囲で計算できる写しを使い、Releaseとの等式（shiftTy_eq等）はLegacyの条件付きで証明する。健全性11件の言明は変えず、検査成功からLegacyを導いて内部の補題へ渡す。拒否の追加だけで健全性を保ち、現在のRustが出す旧入力の受理はnorm_legacyで保つ。L1cへ有限支持上のnormWithの実装と一致の証明を残す。

六実行ファイルdesugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAllから届く呼び出しを点検する。特に `Benitoite/Surface/Check.lean` のmethNameのEff.substRho（レビュー時213行）、`SurfaceCheck/Batch.lean` のnormalizeのsubstTyAt（同102行）、`Benitoite/Surface/Desugar.lean` と `Benitoite/Exchange/Convert.lean` を計算できる写しへ接続する。非計算的なReleaseの置換・shift・union・normへの呼び出しを実行経路へ残さない。L1b2末で健全性11件と六入口を含む既定ビルド、既存のrfl/decideの全例を通す。一時的な拒否はL1cの完了時に必ず外し、後の作業へ残さない。

## L1c: 計算的な正規化・比較と既存の健全性

### 再帰的な有限支持と収集

`AtomsIn S a` は `∀ x, a x=true → x∈S` である。`Eff.Support S e` はatomsのAtomsInと、failsの全型のTy.Supportの連言とする。Ty.Supportは全構成子の子の型と効果へ再帰する。Sはname/rhoだけの有限集合であり、Fail原子そのものは登録しない。

checkerでは `atomsCompareWith S` がSを固定の符号順に調べ、型の比較 `compareWith S` も全構成子へ再帰する。`normWith S` はこの比較で整列・重複除去する計算的な正規化とする。型・効果・型列への再帰の停止を構造または明示した減少量から証明し、試作の固定燃料はそのまま採らない。燃料を使う具体化に変えるなら十分量と従来の受理範囲の保存を証明する。

```lean
-- compareWith_eq_compare / normWith_eq_norm の型の成分。
def FiniteComparisonGoal : Prop :=
  ∀ (s : List Atom) (t u : Ty), t.Support s → u.Support s →
    compareWith s t u = tyCompare t u

def FiniteNormGoal : Prop :=
  ∀ (s : List Atom) (t : Ty), t.Support s → normWith s t = t.norm

-- effEq_sound / tyEq_sound: 支持条件と位置ごとの比較成功から生の = を返す。
def EqSoundGoal : Prop :=
  (∀ s (e f : Eff), e.Support s → f.Support s →
    effEq s e f = true → e = f) ∧
  (∀ s (t u : Ty), t.Support s → u.Support s →
    tyEq s t u = true → t = u)
```

効果と型列にもFiniteComparisonGoal / FiniteNormGoalの対応する命題を置く。Sの順序・重複・余分な原子に結果が依存しないことを `compareWith_support_irrel` / `normWith_support_irrel` で示す。効果比較はname/rhoをS上で、生のFail列を位置ごとに再帰比較する。成功は生の列の等号を意味し、Canonicalを前提にしない。支持条件は入口の収集と各操作の支持保存から得る。注釈はchecker内で正規化せず、計算した型だけをnormWithで正規化する。読者の正規化とcanonical_of_failsLeOneは受理の対応と整形式のために使う。外側に与えた有限集合の外をFalseへ切り捨てて比較を成功させない。

Sを収集する範囲は宣言・シグネチャ・注釈・型引数・行引数・組み込み宣言であり、Fail内の関数型・潜在効果まで含む。入力と置換像の両方の支持から `Ty.substAt_support` / `Eff.substAt_support` を導き、shiftで型変数の番号が変わってもname/rhoの支持を失わないこと、normで支持が増えないことを示す。実際の収集がその条件を満たす `collectAtoms_support` をExchangeとcheckerへ接続する。出力の支持を信頼する仮定に追加しない。任意のRelease関数の有限支持の存在も仮定しない。

### 正規形を既存の型付けへ接続する条件

| 対象 | 未証明の接続・結論 |
|---|---|
| C_App / Ty.Le / C_Sub | 引数の型列の一致と最外部の効果の包含の既存の規則へ、位置ごとの比較から得た等号を使う。包含の範囲は広げない |
| 環境・LocTy・StoreTy・ContTy | 型の保持と代入・shift・読み出しで正規形を保つ。checkerの型だけを正規化して実行時の型との一致を省かない |
| `effSub_sound`・和・空・型の比較 | 支持と比較の成功から既存と同じ包含・生の等号を導く。Canonicalは比較補題の前提に加えない |
| `desugar_typed` / `surface_effect_soundness` | Surfaceの整形式・型付けからReleaseの整形式・型・効果、空の主効果からのIO不在を保つ。脱糖の型と型に埋め込んだ効果の正規形も導く。型付けの最上位の効果にはCanonicalを要求しない |
| 健全性11件 | `checkExpr_sound`・`checkBlock_sound`・`checkArms_sound`・`checkClauses_sound`・`checkTypes_sound`・`checkEach_sound`・`checkHoleArgs_sound`・`checkDict_sound`・`checkDicts_sound`・`checkDef_sound`・`checkImpl_sound`。各入口の既存の型付け・支持・包含の結論を維持し、支持を証明して下位の比較へ渡す |
| `checkProgram_sound` / `checkProgram_empty` | 読者が渡したプログラムの注釈を変えずに検査し、その元のプログラム全体へ上記をつなぐ。Qや捕捉の新規則はL2cで加える |

位置ごとの比較の健全性は非正規な生の型にも成り立つ。順序・重複を無視して生の列の等号を返すことはしない。読者の正規化によって集合として同じ注釈の受理をそろえ、checkProgram_soundの結論はcheckerへ渡されたプログラムについて維持する。L1b末のLegacyでない入力の一時的な拒否と内部のLegacy限定の写しを外し、normWithと支持条件付きの等式へ置き換えたことをL1cの完了条件とする。

## L1d: 旧交換入力と六入口

旧corpus8/9/10と、builtins・stdlib・coverage・coverage-programの各2/3を受け続ける。旧版に存在しないFail情報をFailなしへ、辞書数を0、通常節とNoFail条件なしへ読み替える。ただし新しい欄を旧版に混ぜた入力は拒否し、corpus8/9のtryの制限等も保つ。旧入力の型がLegacyであることとnorm_legacyを接続する。

desugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAllの六入口で、読者・型の比較・canonicalJsonの正規化を同じ定義へそろえる。順序と重複だけの不一致を作らず、従来の受理/拒否/対象外を維持する。新規の版11/4と全比較はL4bで閉じる。RustのFail列の並びをLeanのAtom符号順へ合わせる必要はなく、両辺をLeanの読者で正規化して比較する。Rustに同じ符号を実装しない。

## L2a: Fail捕捉の定義と言明の再確認

R7の方針を以下の関係として具体化する。L2aではL1の実際の定義へコード片を合わせて再レビューし、正式なLeanは変えない。共通の引数P・B・Ψと型変数の束縛文脈は現行の型付けから引き継ぐ。

| 定義 | 下書き |
|---|---|
| `Qsig` | シグネチャ全体（入れ子のfn/cont・メソッドを含む）の各usesで、明示のFailと並ぶrhoの番号を集める。本体や相互再帰の不動点から増やさない |
| `NoFail Q e` | 外側のfailsが空で、外側に現れるrhoはQに属する。潜在効果を持つ型の内部までは制限しない。閉じた状態では外側のFailもrhoもない |
| `Admissible(Qcallee,Qcaller,θ)` | 型・行の範囲（対象効果eの全ρがes.length未満、`Eff.RhosIn (· < es.length) e` を含む）と通常の制約を保ち、Qcalleeの各rhoの像が `NoFail Qcaller` を満たす。像の中のrhoはQcallerで検査する。型・行の像は正規化して使う |
| Fail操作 | 結果型Tとエラー型Eを受け、値引数v:Eから結果T・効果singleFail Eを持つraiseを構成する。実行時の操作探索は型を使わない |
| `HasFailureClause E R h U ec` | Eを境界で固定するabort節。Tだけを節の新しいrigid型にし、errorの型Eをその束縛数だけshiftする。結果Uと外側の環境も同様にshiftし、継続用0番は環境のnoneで利用不能にする。hはFailの節ちょうど一つだけに限る |
| `C_Handle_Fail` | body:U ! eb、`eb ⊆ singleFail E ∪ Rest`、`NoFail Q Rest`、境界Eの節:U ! ec、出力 `Rest ∪ ec`。節が外へ出す効果をbodyの許容効果へ足さない |
| 通常のhandle | 通常節の規則を保ち、ReleaseのHasTypeClausesでもraiseの節を拒否する。handledは普通の名前だけでFail列は空。表層・IR・checkerも混在を拒否する |

```text
K_Handle_Fail   （P・B・Ψを共通の引数として省略）
  ContTy R e k t b e0 Re
  Rest ⊆ e                 NoFail ∅ Rest
  HasFailureClause E R h t ec     ec ⊆ e
  Ty.WF 0 t
  -----------------------------------------------------------
  ContTy R (singleFail E ∪ Rest) (.handleF h :: k) t b e0 Re
```

枠の穴に許す効果にはecや外側e全体を入れない。型Eと型内部の効果のCanonicalはL1の整形式から得る。最上位のe・ec等にはCanonicalを要求しない。`handled h` のFail列が空であることは定義からの補題とし、規則の前提から外す。Releaseの状態に単一Failを課さない。

L2aでは、次の二点を実際の定義に合わせたコード片で決定し、レビューしてからL2bへ渡す。

1. **Qの置き場所**。HasTypeC等に添字Qを加える案と、定義の表にQを持たせ規則が引く案を比較する。採る判断の正確な形と、多相本体のQsigの判断をQcallerへ写す型・項代入補題（AdmissibleとnoFail_substを含む）の新しい言明を示す。閉じた状態はQ=∅とする。影響する判断と代入補題の範囲を数え、L2bの180〜360分の暫定見積もりを見直す。
2. **Fail節を選ぶE-Opとストア**。節はTだけ一つ束縛し、0番はhideContsと同じ環境のnoneで表す。raiseの型引数ts=[T,E′]からTだけを代入する規則と、二つを代入しても閉じた状態では余分な置換が無害という補題を比較して選ぶ。`Ψ κ = some (.cont b' t' ε' R')` の各型・効果・Rと、保存する `k1 ++ [.handleF h]` のContTy、CellOk、`.drop κ :: k2` のK_Dropをコード片で示す。保存継続の末尾のFail枠はK_Handle_Fail、その下はK_Emptyで型付けし、実行の解放と型保存へつなぐ。

## L2b: 捕捉の安全・代入・既存の性質

| 補題・既存定理 | 前提と結論の下書き |
|---|---|
| `noFail_subst` | `NoFail Qcallee e` と、eの全ρがes.length未満という範囲条件を含むAdmissibleから `NoFail Qcaller (Eff.subst θ e)`。外側の条件を述べ、型内部のFailを排除しない |
| `splitAt_failure_prefix` | SplitAtが最も内側のFail節を選んだとき、その内側のK1にFail枠はない。探索の定義から導く |
| `cont_no_failure_propagates` | 型の付いたK1にFail枠がなく、穴の効果にsingleFail E′が含まれるなら、K1の外側の効果にも含まれる。通常のhandledはその原子を除かない。C_Sub/Ty.Leの現行の包含にも接続 |
| `failure_clause_selected_typed` | 型の付いた閉じた状態の `raise[T,E′](v)` とそのSplitAtから、選ばれた節の境界Eについて `E′ = E` と `v:E` を導く。K1の伝播、K_Handle_Failの内側上限、NoFailから得る。注釈E′のCanonicalはR14で拡張した整形式から導く。生の注釈なら等号はE′.norm=Eまでだが、ここではE′=Eを得る。Eの一致や捕捉安全を前提にしない |
| `failure_clause_no_resume` | abort節にはその節の継続のresumeの型付けがなく、値・型の置換後も禁止を保つ。外側の許された通常の継続とは区別する |
| `fromResult_ok/error` / `toResult_return/raise` | 普通のmatch/handleの有限遷移でOk/ErrorとEの保持を示す。解放のない単純な例とし、実行一般の証明に拡大しない |
| `progress` / `preservation` / `effect_soundness` | 既存のWellFormed/WellTyped/EffectsOk・Builtins.Assumptionsと状態の型付けを引き継ぎ、Failの新しい場合を証明する。ストア・継続の型と解放の保存にも接続 |

捕捉先のEとE′が同じ正規形を表すだけで止めず、L1の正規形からLeanの等号を得て値の型を書き換える。Tの置換と境界E・外側のde Bruijn番号を区別する。Releaseの単一Failの代入保存や、型を使って内側の節を飛び越す実行は導入しない。

## L2c: Surfaceと検査器のFailの規則

Surfaceの関数・メソッド宣言は `Q=Qsig signature` を保持し、実装で条件を強めない。ラムダは期待型または明示注釈の条件で検査する。本体のhandleが追加のNoFailを必要としたら拒否する。呼び出し・値化・合流の規則はAdmissibleな具体化の**後**に正規化したFail列の長さ≤1を直接要求し、checkerもその位置で調べる。`{rho0,rho1}` に異なる二Failを渡す反例を拒否し、この制限の代入保存を定理にしない。

Failの節と通常の節の混在、abort節のresumeを拒否する。直接・高階・部分適用・穴・パイプ・別モジュール・持ち出したラムダ・別型への再raiseに正負の例を置く。新しい型付けからdesugar_typed / surface_effect_soundnessと健全性11件・checkProgram_sound/emptyの既存の結論を導く。Qの正しさはシグネチャを読む検査から導き、Rustが出したNoFailのBoolをそのまま信頼しない。

## L3a・L3b: 操作と節の辞書

操作宣言は型パラメータの制約順にdictParamsを持ち、局所の辞書の根拠は所属と番号を保持する。節の型パラメータはrigidとし、宣言された制約の辞書だけを導入する。公開の値引数の契約名と数は保ち、コアの操作はその前へ辞書引数を追加する。

節の値環境は0番を継続、続いて値引数を逆順、辞書引数を逆順、最後に外側の環境とする。辞書引数数d・値引数数nなら、宣言順の値引数jは `1+(n-1-j)`、辞書iは `1+n+(d-1-i)`、外側の番号kは `1+n+d+k` である。`instantiate (ws ++ [.loc κ])` とws=辞書++値の並びに一致することを確認する。型の束縛を増やした分、外側の型と効果内部もshiftする。通常節のresumeとFail節の予約した利用不能の0番を混同しない。

| 担当・目標 | 前提と結論の下書き |
|---|---|
| L3a `op_dicts_typed` | 宣言の型の具体化（操作に効果パラメータはなくes=[]、E0510）と、各宣言制約に対応する型の付いた辞書から、辞書を前置したRelease操作の引数列の型付けを導く |
| L3a `clause_dict_scope` | 節の局所辞書の型付けと上の環境の構築から、辞書の型と所属が正しいReleaseの局所変数の型付けを導く。外側の同番号の辞書を選ばない |
| L3a 直接操作・節の脱糖 | 通常節とFail節の区別を保ち、辞書の束縛・型の置換と脱糖が可換。既存の型保存とcheckerの結論を維持 |
| L3b 操作値の脱糖 | 具体化して選んだ辞書をラムダへ捕え、呼ぶ時点で宣言の効果を持つ。値を作る時点の効果と区別。穴・パイプ・部分適用・ソース順の引数の配置へ接続 |
| L3b 全呼び出しの保証 | 複数/上位クラス、内側ラムダ、外側と節の同番号を含む例から、desugar_typed・性質2/3・健全性11件の結論を維持 |

辞書は型クラスの既存のモデルの仮定だけを使い、未使用の辞書を省いて束縛の番号を合わせる変更はしない。辞書を渡す正しさを新しい信頼する仮定にしない。

## L4a: Characterの区間と有用性

`Dchar = [0,0xD7FF] ∪ [0xE000,0x10FFFF]` を文字の値域とする。分割の端の集合に0・0xD800・0xE000・0x110000と範囲パターンの端点およびその隣を入れてDcharを分割し、サロゲートの穴を区間に含めない。各行列の列の型に従って分割し、別の列の相関やガードによる制限を捨てない。Integerは現行どおりとする。

| 目標 | 前提と結論の下書き |
|---|---|
| `char_partition_cover` | LeanのChar（有効なスカラー値だけを持つ型）上で、任意のCharは入力とDcharの端から作った区間のいずれかに属する。各区間はDcharの内部で、同一区間では各範囲パターンの一致が一定 |
| `usefulFuelWithView_none_sound`（補題U） | 任意のviewと燃料でnone（有用でない）を返すなら、意味上も既存の行列が候補を覆う。Characterの列の場合は.otherを外し、Integerの列の場合は.otherを残す場合分けを加える。燃料切れを網羅の根拠にしない |
| 網羅性・束縛・非選択と拡張後の系 | 補題Uから既存の系を保つ。viewの将来の構成子の保証も保ち、全域の文字の後の分岐を非選択とする。整数全域は従来の判定を維持 |
| SurfaceのCheckPatternsの健全性 | 上の区間と補題Uを表層の分岐検査・脱糖の型保存へ接続。反例の表示は交換で照合し、表示全体の正しさの定理を追加しない |

L4aでは07-04「01-12 との対応」の脱糖の行にある、Character全域のリテラルの並び・範囲を01-05より広いとする記述を更新する。TODO-191後は同じ判定になるためである。

## L4b: 交換11/4とRV2の閉鎖

新規corpus11、builtins・stdlib・coverage・coverage-program各4で、効果をname/rho/failの原子列として交換する。Failは `{"kind":"fail","error":<Ty>}` とする。操作はdictParams/effectKind、節はdictCount/failureType、各行パラメータはBoolのnoFailを必須とし、通常節のfailureTypeはnullとする。型の全構成子、契約名、view、辞書の所属を保持する。

読者は入れ子の型まで正規化し、noFailをQsigから再検査する。Rust側の列順とLeanの符号順は一致を要求せず、両辺をLeanの読者で正規化する。Rustへ同じ符号を実装しない。順序と重複を変えた同じFail集合は同じ型として読む。表層の具体化後の単一FailとReleaseの複数Failを区別し、後者を一律に拒否しない。旧版と新欄の混在、不正な型引数数・番号・noFail参照・辞書数は拒否する。

六入口の独立した正負入力で新しい読者と比較の接続を確認し、L1dの旧版の受理を保つ。`l4b/exchange-contract.md` に全版と必須欄を固定する。Rustの五形式の版を切り替えるのはO2で、Fail列は空・failureTypeはnull・noFailはfalseを出し、F3で実値を接続する。L4b末は今のRustの10/3出力で全比較を一度行う。この回帰結果を新機能のRustの証拠にはしない。P1とV1が新機能と最終関係状態の全比較を担当する。

## 仮定の一覧とRV2での確認

本書は独自公理、sorry、Builtins.Assumptionsの新しい欄を追加しない。R14で了承済みの整形式・ストアWFの強化だけはR12の停止条件に当たらない。その範囲外で既存定理の前提を変更する必要が出ればR12に従って止めて相談する。一般のReleaseに有限支持や単一Failを課さず、捕捉の安全性や正規化・比較の正しさを仮定にしない。

| 適用範囲 | 言明で使う条件と、その条件を得る場所 |
|---|---|
| 数学上の順序・正規化 | 任意の生の型とname/rho関数。標準の論理と関数の外延性を使う。全順序・停止・冪等性・意味保存は証明する |
| 計算的な比較・正規化 | 再帰的な有限支持。実際の入力の収集と置換像の支持保存から導く。正規形はnormWithの正当性・構築と保存から導く |
| 比較からの `=` | 両辺の支持と位置ごとの比較の成功。Canonicalは要求しない。成功を仮定する局所補題を、実際のcheckerの成功へ接続。結論は同値関係へ弱めない |
| 整形式と正規形 | R14で了承済みのTy.WF・VarsIn・Eff.WF・ストアWFの再帰と埋め込んだ効果のCanonical。構築・検査・保存から証明し、最上位の効果には要求しない |
| Legacy補題 | 再帰的にFailがないことを定義どおり要求。旧入力の変換から導く。一般の新しい型へ要求しない |
| NoFailと代入 | Qcallee/Qcaller・Admissibleの範囲と制約。Qはシグネチャ、行の像のNoFailはcallerでの検査から得る |
| 捕捉の定理 | 既存のプログラム/状態の型付けとSplitAt。Eの一致はK1とK_Handle_Failから導く。Releaseの単一Failを要求しない |
| 辞書・文字・既存性質 | 宣言された制約と辞書の型付け、Charの有効な値域、既存のWellFormed/WellTyped/EffectsOk/Builtins.Assumptions等を明示して引き継ぐ |

RV2初回は、固定順序の定義（任意の関数と有限支持上の計算の区別を含む）、再帰的な正規化、代入との交換と一般の合成、正規形の構築から既存の型付けへの接続、11件の健全性、Q・捕捉・辞書・文字・全交換の義務に漏れがないかを確認する。L2aで捕捉規則を実際の定義へ合わせて再確認し、L4b後に証明・写し・独立入力と照合して閉じる。どの義務も、この文書が完成したことをもって証明済みとは扱わない。
