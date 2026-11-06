# 全具体化への接続で必要になる許容判定

2026-11-06。再開5の接続の確認で見つけた停止点である。B_WORK は `e70794188e24de95b5bb424f9d75090f77d1c703`。範囲パラメータを持つ利用者の関数の実装を完了した記録ではない。

## 確認した範囲

現在の表層の導出 `BodyTy`、宣言の対応 `Declarations.Realizes`、`Builtins.ValueAssumptions` と、範囲深さ1でのソースの形成から、適格な全具体化の核の `TelBodyTy` が従うという言明は偽である。反例を `Surface/RangeAdmissibilityExample.lean` に置き、既定の `Surface.Examples` から import した。

反例は、任意の表を量化する言明についてのものである。合成表の実在する組込みについて、許容判定の不整合を示したものではない。また、現在の範囲のない性質1 `desugar_typed` の反例でもない。現在の `BodyTy` を使うだけでは、範囲文脈での表層の検査の代わりにならないことを示す。

## 入力と否定の証明

完全名の共通の名前空間を `Benitoite.Release.Refinement.Surface.RangeAdmissibilityExample` とする。

| 入力・宣言 | 内容 |
|---|---|
| `argument` | 引数なし、結果 Unit、潜在効果 `Read[ρ₀]` の関数型。値・型・行の変数を持たず、範囲変数だけを持つ |
| `signature` | 型引数1個、値引数なし、結果 Unit、空の効果の純粋な組込みの署名。`admits C ts` は `ts = [argument]` |
| `builtins` | `probe` に上の署名を持つ例の表。`sat` は真。実行の応答は使わない |
| `program`・`declarations` | 型・関数・操作・実装・外部宣言を持たない表。`realizes` が宣言の対応を満たす |
| `source` | `probe[argument]` の参照。型は引数なし、結果 Unit、空の効果の依存列の関数型 |
| `body`・`telescope` | 参照を返すブロックと、その結果型・空の効果の依存列 |
| 具体化 | `[RangeExpr.top]`。`RangesFit [RangeExpr.top] [.path]` を満たす |

`values` は、この表が既存の `Builtins.ValueAssumptions program` の全4欄を満たす証明である。型引数は値の変数を持たないので、値の改名と値の置換で変わらず、許容は保たれる。`surface_typed` と `body_typed` は、現在の表層の規則から、参照と本体の型付けを構成する。`code_sourceScoped` は、脱糖した本体が範囲深さ1、型・行・値の深さ0で形成されていることを示す。

一方、Top を代入した型引数の潜在効果は `Read[Top]` となり、元の `argument` と異なる。`instantiated_admits_rejected` はこの型引数を `signature.admits` が拒むことを示す。`instantiated_value_rejected` は、核の `HasTypeVQ.inv_prim` が型付きの組込み参照から取り出す `PrimitiveAdmissible.admits` と矛盾させ、**任意の結果型**での型付けを否定する。`instantiated_source_rejected` は計算から値の型付けを取り出し、`instantiated_body_rejected` は本体の型付けからその計算の型付けを取り出す。否定を型の字面の不一致だけで代用していない。

全体の証人の完全名は次である。

```lean
Benitoite.Release.Refinement.Surface.RangeAdmissibilityExample.existing_premises_insufficient
```

その言明は、上の名前空間の下で次のとおりである。

```lean
theorem existing_premises_insufficient (op : OpPrim) :
    declarations.Realizes program ∧ builtins.ValueAssumptions program ∧
    BodyTy declarations builtins op Qempty [] [] [] telescope body ∧
    (desugarBlock op .tail body).SourceScoped 1 0 0 0 ∧
    RangesFit [RangeExpr.top] [.path] ∧
    ¬ TelBodyTy program builtins StoreTy.empty Qempty [] [] []
      (rangeTel [RangeExpr.top] telescope)
      ((desugarBlock op .tail body).instR [RangeExpr.top])
```

固定した絶対パス、σ、外部の型、外部呼出し、値の篩、IO の応答に依存しない。範囲の具体化と、組込みへ渡す型引数の許容の接続だけに絞った。

## 必要な差と停止条件

`PrimitiveAdmissible.admits` は、渡す型引数を正規化した列について `s.admits` を要求する。`Builtins.ValueAssumptions` が要求する保存は値の改名と値の置換であり、範囲の具体化は含まれない。関数の `Admissible.types` が読む `B.sat` についても、同じ仮定に範囲の具体化の保存はない。後者の不成立の反例は今回は作っていない。

したがって、既存の許容判定を開いた型引数に一度適用するだけの規則から、全具体化の許容を導く補題は追加できない。`CallHeadTy` の範囲引数の欄と `FunDecl.rangeParams` の読み出しだけを広げても、この不足は埋まらない。表層の許容の前提を、範囲文脈でどのように要求するかを定める必要がある。

依頼の「止める条件」の **「型付けの規則の変更」** に従い、この許容の前提の変更を入れる前に止めた。範囲の量化を定理の署名へ足すことと、現在の単一の許容判定を全具体化の許容という前提に変えることを区別した。発行専用の節を断る例外は、この許容判定には当てなかった。新しい信頼条件で証明を埋めず、全具体化の核の型付けを表層の前提に直接要求してもいない。

## 代案・所要と実用への影響

| 案 | 必要な差 | 信頼条件・前段への影響 | 実用への影響 | 残る所要 |
|---|---|---|---|---|
| A（推す） | 開いた表層の有限の導出を設け、組込みの `admits` と関数の制約の照合を、呼出し元の範囲文脈で要求する。葉では全具体化の許容、又はそれを導く構文上の条件を確認する。範囲のない場合は元の規則への系を示す | 核・主な10言明・`ValueAssumptions` を変えない。表層の許容の前提と、その署名・性質1の場合を追加する規則変更として、取りまとめの確認を求める | 上の例の表のように、ある範囲でしか許されない型引数を、任意の範囲で許すことはできない。標準の表の各許容条件を開いた範囲で満たせるかを照合する。関数型の効果に範囲変数を書く形そのものは除かない | 許容の完全署名と最初の保存の確認30〜60分。その後の全場合・既定ビルド・全宣言の監査・照合を含む総所要は不明 |
| B | `Builtins.ValueAssumptions` に `admits`・`sat` の範囲の具体化の保存を足す | 新しい独立の信頼条件であり、核と群 C のモデルの前提を変える。今回の範囲では採らない | 主定理を使う全表に新しい条件が必要になる。今の仮定を満たす全表との互換ではない | 不明 |
| C | 関数へ渡す型・行引数から範囲変数を除く | 書ける形を狭める。今回の範囲では採らない | 関数型の中を含む U02 S9 の形が失われる | 採らないため見積もらない |

案 A は、表層の導出全体を「全具体化の核の型付け」という前提で置き換える案ではない。表層の構造的な導出の葉の許容と、子の導出から全具体化の核の型付けを得る性質1を分ける。これを今回の規則追加の範囲に含めてよいかを、取りまとめへ返す。範囲のない系と266署名の保全は、再開後も必要である。
