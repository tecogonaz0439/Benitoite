# 開いた範囲文脈のリストの展開と文字列補間

群 E の追随のうち、リストの展開・文字列補間を受け持つ。B_WORK は `601a52cae1ffc9bbef9be71e3b56c83f0afdfa4d`。本番の変更は新しい `Surface/CheckOpenInterpolation.lean` だけである。

## 時刻と検査

| 単位 | 初回取得（JST） | 終了（JST） | 外側の時間 |
|---|---|---|---:|
| 展開・連結・補間の移植と四つの健全性の接続 | 2026-11-06 20:16:48 | 2026-11-06 20:29:41 | 12分53秒（依存の実装・検査枠の待ちを含む） |

初回取得以前の調査は未計測である。能動時間と待ちを分けていない。最大常駐量は未取得（計画上の非採取）。

`formal/` から `lake env lean -M 12288 -o <生成物> Benitoite/Release/Refinement/Surface/CheckOpenInterpolation.lean` を実行した。初回の局所検査は20:29:30〜20:29:41 JSTの区間内で終了0・警告0であった。生出力は0バイト、SHA-256 は `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` である。現ソースは26,288バイト、SHA-256 は `fd739087bed973c0b1e8584b95de31f1a7cd3b17a3bde6e59ccb92c1f0266b80` である。

単独 Lean はこの検査だけを行い、ほかの担当の検査枠の受渡し後に一つずつ実行した。終了時に検査枠を群 E の取りまとめへ返した。既定ビルド・公理監査・verify は起動していない。

## 実装と接続

名前の共通の接頭辞は `Benitoite.Release.Refinement.Surface.CheckOpen.` である。

| 計算 | 健全性 | 結論 |
|---|---|---|
| `checkSpreadAt` | `checkSpreadAt_sound` | `OpenSurface.SpreadTy` |
| `checkJoinAt` | `checkJoinAt_sound` | `OpenSurface.JoinTy` |
| `checkJoinPartsAt` | `checkJoinPartsAt_sound` | `OpenSurface.JoinPartsTy` |
| `checkInterpAt` | `checkInterpAt_sound` | `OpenSurface.InterpTy` |

各結論は `q.formation.rangeKinds` を範囲文脈に持つ。検査する型と効果・元の値の位置・追加する束縛・経路条件は、元の展開と補間の規則に合わせる。型付けの規則・核・旧 checker は変更していない。

実引数・呼出しの頭は `CheckOpenArguments.elems`・`valsTel`・`head` で検査し、それぞれの健全性へ接続する。組込みの表の選択は `q.builtinSource` であり、実際の表は `q.B` に一致する。注釈は `CheckOpen.annotation` が `AnnotationR` を返す。`OpenSound q` の継承した有限支持と許容の計算の対応を使い、型付けや全具体化の証明を新しい入力の欄にしない。

ソースの頭の型・行の引数の支持と、前置する辞書の支持は、元の `Check.source_head_inputs`・`source_head_dictionaries` を再利用した。同じ言明と同じ証明を新しい名前で重ねて置いていない。四つの新しい検査の本番の読者は、開いた式の展開と文字列補間の規則の再検査・健全性である。

## 差と申し送り

| 対象 | 差 | 範囲のない場合 |
|---|---|---|
| 展開・連結・補間の検査と健全性 | 範囲文脈を明示する新しい入口を追加し、表層の開いた導出へ接続する | 元の検査と健全性はそのまま保持する |
| 前段の固定署名・主な10言明・公開の利用者の関数の契約 | 差なし | 同じ |
| 止める条件 | 該当する変更なし | 新しい公理・信頼条件・提供範囲の削減を加えていない |

新しい独立の受理例はこの担当から追加しない。実入口の受理例は群 E の取りまとめが用意し、この四つの検査の読者とともに既定ビルドで検査する。既定 import、01-12・07-04 の写し、生成宣言と private を含む公理監査、記録の照合は取りまとめが受け持つ。
