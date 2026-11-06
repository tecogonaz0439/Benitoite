# 全具体化の葉の有限な形成

I.2 を受け持つ。B_WORK は `601a52cae1ffc9bbef9be71e3b56c83f0afdfa4d`。群 D の表層の新しい補助と `RangeStandard` だけを変更し、核・他群・既存の信頼条件を変更していない。

## 時刻と局所検査

| 単位 | 開始（JST） | 終了（JST） | 外側の時間 |
|---|---|---|---:|
| 七つの葉の有限な形成、標準表の導入、受理例と範囲の有限検査 | 2026-11-06 20:03:27 | 2026-11-06 20:14:23 | 10分56秒 |
| 固定 Top の被覆と単相の外部の条件への補足 | 2026-11-06 20:18:46 | 2026-11-06 20:24:51 | 6分05秒（検査枠の待ちを含む） |

`formal/` から `lake env lean -M 12288 -o <当該モジュールの生成物> <ソース>` を一つずつ実行した。最終ソースの `OpenLeafFormation`・`RangeStandard`・`OpenRangeFormationCheck`・`RangeLeafExamples` は、いずれも終了0・警告0であった。既定ビルド・公理監査・verify はこの担当から起動しない。検査枠は終了時に群 E の担当へ渡した。最大常駐量は未取得（計画上の非採取）。能動時間と待ちを分けていない。

初稿の局所検査では、空の具体化の `map id`、依存列の `WF` と型の `WF` の対応、行の原子の写像、例の構造の証明の不足を直した。成功後の例の未使用の `simp` 引数も除いた。これらは局所の証明の修正であり、型付け規則や信頼条件の変更ではない。大きい具体値の評価と証明用設定の追加はない。

## 七つの全称の葉

名前の共通の接頭辞は `Benitoite.Release.Refinement.Surface.` である。以下の構造の各欄は、型の構文・有限列・宣言の署名に関する条件であり、全具体化の型付けの証明を格納しない。

| 葉 | 一度だけ検査する有限の条件 | 全具体化を導く補題 | 群 E の有限な検査との接点 |
|---|---|---|---|
| `OpenSurface.Primitive` | `OpenLeafFormation.PrimitiveCheck`。型の個数・元の型引数の正規形の許容・範囲深さ `ks.length` の型と行の `WF`・通常値であること・行の個数・宣言の行と Q の上限・NoFail の行の照合・依存列の行の上限 | 標準表では `RangeStandard.primitive_of_check`。任意の表で範囲閉の型引数なら `OpenLeafFormation.primitive_of_closed`。前者は `admits_instR` を実際に読む | `wfTy`・`wfEff` の範囲深さを呼出し元へ合わせ、既存の許容の Bool と行・Q の検査から `PrimitiveCheck` の各欄を供給する |
| `OpenSurface.Satisfies` | 元の開いた型の正規形に対する `SatAll` | 標準表では `RangeStandard.satisfies_of_check` → `sat_range_norm` → `sat_instR`。任意の表で範囲閉の型引数なら `OpenLeafFormation.satisfies_of_closed` | 既存の `satAll` の有限の照合。範囲閉の側は `OpenRangeFormationCheck.ty atoms 0` も検査する |
| `OpenSurface.Admits` | `OpenLeafFormation.AdmitsCheck`。元の `SatAll` と、範囲深さを呼出し元に合わせた型・行の形成、行・Q・NoFail の条件 | 標準表では `RangeStandard.admits_of_check` → `satisfies_of_check`。任意の表で範囲閉の型引数なら `OpenLeafFormation.admits_of_closed` | `PrimitiveCheck` と同じ形成と行の検査、制約の照合を関数のパラメータ列へ適用する |
| `OpenSurface.Signature` | `OpenLeafFormation.SignatureCheck`。依存列の範囲深さ `ks.length` の `WF`、型と行の `AnnotationR`、型引数の kind、行内部の kind、具体化した結果の `AnnotationR` | `OpenLeafFormation.SignatureCheck.sound` | 開いた注釈の有限な形成、型引数と行引数の kind の検査。全具体化の結果を入力へ要求しない |
| `OpenSurface.MethodRows` | `OpenLeafFormation.MethodRowsCheck`。行の個数、範囲深さ `ks.length` の行の `WF`、宣言の行と Q の上限、NoFail の行の照合 | `OpenLeafFormation.MethodRowsCheck.sound` | 行引数の有限な形成と既存の行・Q・NoFail の検査 |
| `OpenSurface.ExternalAdmits` | 外部署名の `tparams = []` と元の `ExternalCallAdmissible` | `OpenLeafFormation.external_of_check` | 外部署名の有限検査と既存の外部呼出し許容。単相の個数の条件から型引数列が空であることを導き、具体化による不変性を使う |
| `OpenSurface.RangesAdmit` | 標準表では `RangeArguments` と `RangeStandard.RangeCheck`。後者は全 Top、一引数の対象操作、又は widen の二つの添字の `RangeIx.Covers`（又は外側が固定 Top）の三形。任意の表では固定範囲だけの元の `RangeAdmissible` | 標準表では `RangeStandard.ranges_of_check`。任意の表で固定範囲だけなら `OpenLeafFormation.ranges_of_fixed` | 種類列との要素ごとの照合、名前の有限な比較、固定範囲の被覆又は同じ範囲変数の照合。未束縛の変数を Top へ替えて受理しない |

`primitive_at`・`admits_at` は一つの具体化での補助であり、標準表の導入と範囲閉の導入の証明が読む。これらを新しい信頼条件にせず、許容の部分はそれぞれ `admits_instR` 又は範囲閉性による正規形の等号から供給する。`SignatureCheck.sound` は、注釈と依存列の形成保存、型・行の具体化と範囲具体化の交換を読む。核の本体の型付けを要求する欄はない。

## 範囲の深さの有限な検査

`OpenRangeFormationCheck` を追加した。`ix nr` は固定範囲と範囲変数の深さを検査する。相互の `ty`・`tys`・`eff`・`tel` は、型の添字を構造的に辿り、効果の原子は有限支持 `atoms` を走査する。`ix_spec` と各 `_sound` が、それぞれ `RangeIx.WF` と `RangesScoped` を結論にする。効果に現れる名前の原子の添字は、型・行の `WF` だけでは検査されないため、この有限な範囲の検査を区別する。

群 E の `CheckOpenFormation` は注釈の `AnnotationR` を供給し、`CheckOpenLeaves` はこの範囲の有限検査と既存の形成・kind・許容・NoFail の計算を組み合わせて上表の構造を供給する。群 E への実際の接続の完了は、その担当の局所検査と群末の既定ビルドで判定する。

## 非空の型引数を持つ受理例

`RangeLeafExamples.list_length_reference` は、標準の `List.length` の型引数に `.opaque "Scope.PathIn" (.rvar 0)` を一つ渡す参照を、`OpenSurface.HasTypeQ` で受理する。`RangeStandard.primitive_of_check`・`ranges_of_check`・`OpenLeafFormation.SignatureCheck.sound` を実際に適用する。型引数列が空の場合の例と異なり、標準表の許容の保存と具体化後の署名の全欄を本番の導入補題へ通す。

例の作成時の関門は次のとおりである。

| 関門 | 答え |
|---|---|
| 守る境界 | 標準の組込みの非空の型引数へ自由な範囲変数を含む型を渡したとき、有限の形成から実際の表層の型付けへ接続すること |
| 捕まえる退行 | `admits_instR` を葉へ接続せず、型引数列が空の場合だけで許容の導入を済ませること |
| 既存の例との差 | `Http.widenRequestIn` への転送は型引数が空であり、この接続を確かめない |
| 検査用の差し込み口 | 追加しない。標準の lookup と既存の `OpenSurface.CallHeadTy.prim`・`E_Prim` を使う |

## 差と止めずに進めた変更

既存の規則・Step・主な10言明・前段の固定署名に差はない。追加した構造と補題は、既存の全称の葉を作るための有限な証拠を明示する。新しい独立の信頼条件と、表全体へ要求する条件はない。

| 対象 | 反例又は理由 | 選んだ案 | 退けた案 | 範囲のない場合 |
|---|---|---|---|---|
| 葉の供給の公開補助 | 元の `admits_instR`・`sat_instR` だけでは `Primitive` の全欄や正規化した型引数の許容が得られた形になっていなかった | 深さ付きの有限な形成を構造に分け、標準表の保存と合成して既存の葉を結論する | 表全体へ新たな保存の信頼条件を要求すること | 既存の規則を変更しない。深さ0と空の具体化では元の各欄を読む |
| 範囲の許容の有限な形成 | 標準の widen の範囲の許容は被覆を読み、単なる種類の一致だけでは得られない | 既存の `RangeIx.Covers` 又は外側の固定 Top を有限に照合し、既存の `.inst` 又は `RangeExpr.top_covers` で全具体化へ移す | 種類の一致だけで標準の範囲の許容を受けること | 固定範囲では元の `RangeExpr.Covers` であり、元の許容から `ranges_of_fixed` も使える |

本担当から取りまとめに新たな判断を求める点はない。既定 import、01-12・07-04 の写し、全宣言の公理監査と群末の照合は取りまとめ側の作業へ渡す。

20:18:46 JST の追加: widen の内側に範囲変数、外側に固定 Top を渡す形も `RangeExpr.top_covers` により許容するよう `RangeCheck` を広げた。この追加と、外部の導入を単相の条件だけへ弱める補足は、20:24:51 JST までに `OpenLeafFormation` → `RangeStandard` → `RangeLeafExamples` の順で再検査し、いずれも終了0・警告0であった。所要は順に0.855秒・0.940秒・0.987秒で、生出力はいずれも0バイトである。補足以後、証明と設定を変更していない。
