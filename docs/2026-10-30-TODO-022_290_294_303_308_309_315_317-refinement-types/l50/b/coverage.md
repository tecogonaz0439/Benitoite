# 全入力と全場合の照合

本番の完全名の先頭は `Benitoite.Release.Refinement`。下表は有限な例から閉鎖を推測したものではない。先に一般定理の量化と全構成子の分岐を確認し、例は受け入れと拒否の読者として使う。

## 起点の付加

`PathPattern.covers_atBase` を再利用する。Word の長さを量化し、base と末尾を具体列に展開しない。新しい `PathPattern.Covers.mem_atBase` を RangeExpr の based の実読者が使う。

| outer/inner | exact | tree |
|---|---|---|
| exact | 同じ幹を付加後も等号で保持 | 元から不成立。付加後も不成立 |
| tree | 任意の残りの列と append の結合則 | 任意の残りの列と append の結合則 |

受理3形と拒否1形の適用例は全 Word を量化する。based の読者は任意の PathBase を受けるので root/cwd/home/work/tmp の全5構成子を含む。lookup が none のときは内側の所属自体が不成立、some w のときは同じ w の付加を読む。

## RangeExpr の9対

`RangeExpr.Covers.mem` の型は全 outer/inner、全 σ/k/t と所属の証拠を量化し、σ.Valid を要求しない。Top を先に処理した後、残る構成子の9対を分岐する。

| outer/inner | absolute | based | secrets |
|---|---|---|---|
| absolute | 旧 Range.Covers.sound を使用。内部の4×4は継承 | Top のみ。Top以外は被覆不成立 | Top のみ。Top以外は被覆不成立 |
| based | 被覆不成立 | 起点等号と4パターン対。lookup none/someを分岐 | 被覆不成立 |
| secrets | 被覆不成立 | 被覆不成立 | 同じ一覧の所属を保持 |

ScopeCoverage の読者は Top の任意 inner、absolute の任意 r/s、based の任意起点・パターン、secrets の任意 σ の所属を使う。secrets が some ps の場合の所属は、ps のいずれかの path 原子への所属である。none と some [] は所属を持たない。起点 a≠b の場合は、同じ σ で lookup a=lookup b なら、任意の k/t について based b q の所属から based a q の所属が従う一方、based a q による based b q の静的な被覆は成立しない。この読者は、lookup の等号を所属の保存に使い、起点の不等号を静的な被覆の拒否に使う。完全性の逆向きは追加しない。

## snapshot と具体化

| 場合 | 一般証拠と読者 |
|---|---|
| snapshot=none | 内側はabsoluteに限られる。SnapshotMem.monoは外側もabsoluteに保つ。任意のσへのcurrentは拡大後のabsoluteから供給 |
| snapshot=some σ | 元のValidと所属を維持。同じsnapshotのmonoからcurrentへ |
| RangeIx fixed/fixed | 既存Covers.instと新しいCovers.inst_memで全範囲・全列・全σの所属を移す |
| RangeIx fixed/rvar | 静的な被覆は不成立 |
| RangeIx rvar/fixed | 静的な被覆は不成立 |
| RangeIx rvar/rvar | 同じ変数に限る。lookup someなら同じ固定範囲、noneなら同じ変数を保持 |

`RangeIx.Covers.inst_mem` は、内側の具体化が fixed r で r に対象が属するとき、外側の具体化も fixed s となり同じ対象が属することを示す。rs[i]?=none の全列・全iについて rvar の維持と全 fixed r の拒否を同じ例で示す。Topへの代用はない。

`Pred.member_mono` は全η/k/a/r/sの二値の解釈を量化し、observeAsの全構成子を分岐する。対象の観測では同じsnapshotにSnapshotMem.monoを適用する。k の3構成子 path/host/endpoint の読者を置き、`Pred.member_inst_mono` は全RangeIx・全具体化列へ渡す。部分評価の成功をこの命題へ含めない。a.observe η が snapshotなしの任意の対象 t を返す場合、basedのevalWithはnoneであり、false又はtrueへ置き換えない。

## Atom の9対と効果

| outer/inner | name-fixed | name-rvar | rho |
|---|---|---|---|
| name-fixed | 同名とRangeExprの被覆 | 不成立 | 不成立 |
| name-rvar | 不成立 | 同名・同変数 | 不成立 |
| rho | 不成立 | 不成立 | 同変数 |

既存Atom.CoversとatomCovers_instRが全9対を扱う。新しいAtom.covers_fixed_iffは、全原子aと固定原子の被覆を同名の固定原子と範囲の被覆へ逆転する。Eff.Covers.allowsは、任意Γ/Φの一原子の証人をこの逆転へ渡し、RangeExpr.Covers.memから同じσの許容を得る。Γ/Φを空に限定しない。Fail側の構造的条件は既存Coversの一部のまま保つ。

全bindの二経路、union/empty/row、Top、型だけの置換は[移植表](transplants.md)に対応する。元の名前原子の範囲だけを具体化し、型/値の像は任意である。行の像はそのまま読む。Failの重複を含む型列から対象の許容を得ない例、短い範囲列の拒否、行像を再具体化しない例がある。既存allows_normを利用し、生のrawBindだけを後段の入口にしない。

EffectTargets末尾の読者は、群Aのobs_allowedから同じ呼出し・応答・対象・σの許容を得て、Eff.Covers.allowsでupperへ渡す。NamesWFは同じPrimSig.Scopedから供給する。実表7IO・三モデル・全到達の主定理の閉鎖は主張しない。
