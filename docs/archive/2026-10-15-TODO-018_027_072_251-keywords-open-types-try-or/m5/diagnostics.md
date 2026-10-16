# M5 時点の診断変更の照合

M5 自身による診断コード・主文・help・主/副位置・終了状態の変更は0件である。移行を含む A〜M4 の変更と、その詳細の記録を以下へ対応付けた。主文・位置・help の厳密な対応は各作業の表と現在の golden を正とし、ここでは実装済みの変更範囲と元の誤りの保持先を確認する。

CLI の静的検査の失敗は終了状態2、既定の die は1である。P2・D6c・B7 等の初期の記録にある「静的検査の終了状態1」は R22 と B11 で訂正済みであり、現在の終了状態として読み替えない。

| 条件 | 旧→M5 時点 | 位置・案内・理由と元の検査の保持先 |
|---|---|---|
| die を名前に使う | 受理→E0216 | 名前の die が主、rename help。予約語を一語追加。既存の非予約語の受理と名前の拒否表を保持。[A1](../a1/results.md) |
| 普通の return 直後の物理改行 | 継続または他の構文の診断→E0201 | 主文 `expected an expression, found a newline`、主位置は改行、副位置は return、help は ``start the return value on the same physical line as `return` ``。値は同じ行で書き始める R13 に対応。値を始めた後の継続・短い lambda の拒否は維持。[A4 の全文の表](../a4/results.md#診断の対応) |
| 拡張可能な型の外部の分解 | 従来の網羅判定→E0601/E0607 または包括的分岐の受理 | 現在の反例と将来の形を区別し、宣言の副位置と包括的な分岐の help を追加。既存の閉じた型の判定、真の重複 E0602/E0608 を保持。[D6a](../d6a/results.md)、[D6c](../d6c/results.md#診断の対応) |
| @extensible | E0801→適切な data/record では受理。不正な引数 E0817、非文字列 E0220、位置 E0802、重複 E0803 | 属性全体または不正な引数が主、重複のみ最初の属性を副。引数除去の案内と、既存の未知属性・不正位置の拒否を維持。[D6c の全文の表](../d6c/results.md#診断の対応) |
| 処置への値と明示形の後の継続 | E0201 等→E0258/E0259 | 主文はそれぞれ ``invalid failure action after `try` ``、``parenthesize an explicit `try` expression before continuing it``。不正な値/継続が主、値なしの return/括弧の案内。Boolean or、裸の operand、guard/lazy の禁止は保持。[B7](../b7/results.md#診断の対応)、[B11](../b11/results.md#診断と報告の対応) |
| die の説明の直接の return/try/resume、効果・型・Show | 新構文に E0218/E0509/E0511/E0401/E0705/E0706 を適用 | 説明式・脱出の語・処置が主。E0511 は説明の括弧を副、pure String の案内。既存の lazy/guard、通常の型/効果/辞書の誤りを保持。[B10a-1 の対応表](../b10a-1/results.md#診断の対応) |
| 本番の try … or die | E0201→受理 | 単独の die は E0201、or return die は E0258 の拒否として保持。Return の E0440/1/2 を変えず、die の Exit 不足は E0501/2、import の不足と Process.Exit の案内を追加。Process の別名は E0339 のまま。[B11](../b11/results.md#診断と報告の対応)、R63/R74 |
| die の実行報告・test runner | 追加した処置の失敗を報告 | 主文 `explicit failure exit`、try の位置、説明と原因。状態1、転送後の一回の報告と後続の解放/flush の補足。通常 exit・Result.Error・Assert・中断の分類を保持。[B11](../b11/results.md#診断と報告の対応)、[B12](../b12/results.md) |
| `?` の修正例 | E0211→E0211、help だけ明示形へ | 次の表のとおり。計画の E0201 question は実際には E0211（R78）。[M3](../m3/results.md#診断の対応) |

| E0211 の項目 | 旧 | 新 |
|---|---|---|
| 主文 | `` `?` is not an operator in Benitoite `` | 同じ |
| help | ``write `try` before the expression, such as `try parse(text)` `` | ``write `try` before the expression, such as `try parse(text) or return` `` |
| 主位置 | unknown_symbol.bnt 5行3列、offset 77〜78 | 同じ |
| 副位置・notes・edits | なし | 同じ |
| 終了状態 | 2 | 2 |
| 保持する誤り | unknown_symbol の入力と E0211 の拒否 | 同じ。既存 golden と、parser の help 全文・件数・編集なしの assert |

M5 では P1 の裸の golden 254関連ファイルが完全一致し、M3 の修正後の全入力のハッシュも一致した。E0211 の unknown_symbol は裸の try の入力ではなく、M3 で個別に確認した診断の修正例である。期待値の一括生成、比較の緩和、ignore への変更はない。

E0908 の複数の変更の案内は M6、0.0.6 の版と固定ハッシュは M6a/M7 に残る。これらを M5 時点の実装済みの診断変更には数えない。
