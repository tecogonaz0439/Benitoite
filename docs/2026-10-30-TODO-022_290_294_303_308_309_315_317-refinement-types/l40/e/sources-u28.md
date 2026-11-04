# 全標準行と具体の応答・本体の接続

2026-11-04。通常型、追加する関係、実標準表全体の充足を分けて記録する。全328行の原署名は既存の[数値側](api-numeric.json)と[コレクション側](api-collections.json)を保持し、現在の判定を[sources-r1-u28.json](sources-r1-u28.json)に置く。原候補の分類は[api-connections-r1-u28.json](api-connections-r1-u28.json)、再収集は[catalog-u28.py](catalog-u28.py)による。

## 全328行の判定

母集団は23モジュール・328公開APIであり、244 builtinと84 coreに分かれる。coreのうち51行は四モジュールの別名ラッパーである。原引数名、型引数の制約、結果、効果、呼先を変更していない。

| 判定 | 行数 | 証拠の範囲 |
|---|---:|---|
| 純粋応答の通常契約 | 143 | 81整数・12整数変換・10Byte/Character・3Float分類・6Decimal・5長さ・4List列操作・2Bytes変換・既存Map/Set20。原署名の全ts/es/rs/ws/Ψ/a/eから同じ具体δの存在・型・Ground・AdequateResult・exit排除を得る |
| 通常coreの局所BodyTyped | 6 | List.map/filterの2本と既存Map/Set.map/filterの4本。同じComp/Rowを同じ有限P/Bで型付ける |
| 通常契約が独立に未完 | 179 | 100 builtin、Decimal.fromFloatの実bits由来parsed供給、51別名ラッパー、その他core27。正常境界の保留を理由に完了へ繰り上げない |

143行に対する追加関係は、同じ入力・応答を読む109行と、床演算の局所的な関係14行を分ける。既存Map/Set20行の縮約・射影・更新・集合演算の証拠は再実装せず収集する。これらの局所的な証拠を全APIの閉鎖数としない。全API・全O行の全体閉鎖はともに0である。

`StandardSignatureExamples` は143実名について、原ソースの署名から生成したPrimSig全欄と有限表の署名・実名の等号を検査する。型パラメータ、keyを含むadmits、引数名と型、結果、効果、範囲、kindを含む。生成器は[schema-u28.py](schema-u28.py)である。Map/Setのkeyを型引数の個数だけへ置き換えていない。原ソースと有限表の対応であり、RustとLeanの実行全比較ではない。

## 数値部分表と全引数の接続

各純粋行は、BuiltinArgsの型・行・範囲引数の個数を実署名から読み、HasTypeTelArgsQの同じ実値による後続の開き方を逆転する。終端のa/eとの同一性を残し、閉じた値のcanonical formsとConstOKから実定数を回収する。出力のTypedや正常値を前提にしない。具体表のF06を示すためにCoreAssumptions.delta_typedを使うこともない。

| 接続 | 同じ入力・δ・応答に保持する関係 |
|---|---|
| min/max14 | 同じ二値の一方を選び、数学上のmin/maxと一致する |
| 整数変換12 | Someの数の同一性と対象幅、Noneの域外、小幅の全域拡大とu64のOptionの差 |
| 床14 | tdiv/tmodの同じ符号補正、q*b+rの分解、0除算、補正結果の幅外、正常値の同一性。床剰余は商の表現外だけではoverflowしない |
| absolute7 | 正常値の数学上の絶対値・非負性・幅、overflow iff 符号付き最小値、符号なし型は元の同じ値を返す |
| 整数bitwise/shift46 | 同じ幅のビット列と符号の復元、wrapする数学値、同じIntegerのcountとその域外err。論理右シフトは符号付き四幅だけ |
| Byte8・Character2 | Byteの0〜255、Some/Noneと数の同一性、同じInteger/code射影、Characterのscalar範囲。Byteの実UInt8演算とshift countの正常・域外 |
| Float分類3 | 同じbitsのNaN、Float32の正負二つの無限大のorと同じ述語。全bit丸め・表記の算法は追加しない |
| Decimal6 | 同じPの五モード、places域外と係数overflow、正常値の96bit仮数/scale再検査、同じscaleのabsolute、整数からの同値、TowardZero、u64変換の整数性・Some/None |

床の商のoverflowを「符号付き最小値÷−1」だけに整理する一般化は今回行っていない。現在の言明は、実際の符号補正結果が対象幅の外にあることと同じerrとの同値である。元の.29〜35が受け持つ区間計算・警告・returned/failed・最初の失敗の対応も開始していない。

Decimal.fromFloatは原署名の全引数から同じFloat bits・Option[Decimal]・空効果を回収し、既存の任意parsedの再検査出口の型・Ground・AdequateResult・exit排除まで接続した。parsedを原署名の引数へ追加せず、新しい供給関数も置いていない。同じbitsに由来するparsedを実表へ供給する接続は独立未完である。

## 列と通常本体

Listのlength/isEmpty/prepend/append/concatenate/reverseは、一つのvalue型引数Tの注釈・Ordinary・kindと、元の要素型からTへの部分型関係を保持する。返す要素のGroundとAdequateは、元の引数自身又は引数Listの要素から得る。List列の同一性とn+1/n+m/n、Stringの異なる二長、Bytesの同じbyte列と同長を、同じδの応答へ接続する。countReplyの表現外errを残し、有限列へ一律のInteger上限を仮定しない。

Bytes.fromList/toListには、既存の導入・射影helperへ同じ列を渡す二実名の部分δを置いた。型付きListの各ByteからConstOKを回収し、UInt8列へ戻す。出力の型付けを与える供給関数で置き換えていない。

凍結したStandardListBodies.listIndexAddSigはa/b、実Rust演算子はleft/rightである。StandardActualListBodiesは既存の同じmapFrom/filterFrom/map/filterのCompとRowを、実left/rightのV_Prim/C_Appで直接型付ける。一つのBで異なる二lookupを同時に仮定せず、fnNamesの改名や部分型変換も使わない。元の.23の宣言・正常関係・使用部分、FirstReturn、二反例は変更していない。既存Map/Setの4本も再実装せず収集する。

## API一覧の外にある演算子と等値

[operators-r1-u28.json](operators-r1-u28.json)はRustのOPERATORS全107実名を、原型・引数名・結果・効果・型/行/範囲引数へ展開する。再収集と73行の全欄対応の生成は[operators-u28.py](operators-u28.py)による。

| 対象 | 判定 |
|---|---|
| 整数の加減乗21・負号4 | 実left/right/valueの全BuiltinArgsから同じintegerDeltaへ接続し、同じ算術値・幅・overflowを保持 |
| 整数七幅、Byte、Character、Float二幅、Decimalの四比較48 | 全BuiltinArgsから同じδと同じ二値の比較述語、Boolean・Ground・AdequateResult・exit排除へ接続 |
| 残る107中34 | 実名の全入力応答契約は独立未完。整数div/mod14、Float二幅の算術等10、Decimal算術等5、String5。新しい算法は実装しない |
| `%eq`/`%ne` | 全Equality型を許す一value型引数・Equality制約・left/right・Boolean・空row/rangeの署名を維持。12scalar領域×2名は元の篩付きTのまま既存δへ接続する条件付きpartial |

等値のscalar-domain条件は、全BuiltinArgsから回収した同じTに対するscalarTypeCoreの条件である。Tの注釈・Ordinary・Equalityのsatを保持し、型引数を基本型へ置き換えない。List/data/Bytes/Map/Set等の構造Equalityについて、同じ全入力から実δの構造走査・型・Ground・AdequateResult・exit排除を示す言明は未証明である。狭い署名への代入、常時err、Typedを返す供給関数では補わない。

## 境界と後段への供給

全S01〜S36の原契約・API行・供給先・残りは[relations-r1-u28.json](relations-r1-u28.json)に置く。API外のrecord/decode、内部safe19、対象付きFile6/Http.sendInも別欄で含める。

正常返却の境界待ちは公開7行だけである。List.map/filter、Map.map/filter、Set.map/filter、NonEmptyList.mapの正常関係が、凍結した同じ呼出しの正常返却関係を使う。内部mapFrom/filterFromの2本とdecodeの通常処理への接続は328の外で保持する。

S31だけを持つList.fold/forEach/any/all/find、Map.fold/forEach、Set.fold/forEachの9行は、実本体への静的な適用とBodyTypedが独立に未完である。固定契約にない動的関係を理由に境界待ちへ移していない。NonEmptyListのmap以外4行も、現行nominalの原署名・公開ラベル、内部精密契約と表現変換を分け、独立未完とする。内部safe19の全注釈と本体9本は保持し、精密getter9本の静的未証明を今回の通常応答で閉じない。

L60へ渡すのは、具体に証明したδと本体の契約だけである。L50の対象付きFile/Http、R40の生成器・NonEmpty別名変換、R50の実ID/ABI/鍵・値の交換は元の境界として残す。未実装100 API、51別名と他core27、fromFloatの実供給、構造Equalityを後段へ移してL40完了にしない。

## 検査の境界と根拠

test-auditの作成時の関門を適用した。所有する契約は、原Source/実名/署名と、全型付き引数から同じ応答又は同じComp/Rowへ至る接続である。引数ラベル、結果・効果、型/行/範囲の個数、ConstOK、Option.None、Ground/Adequate、count域外、呼先を取り違える退行を捕まえる。群Dの具体値の局所補題だけでは、全BuiltinArgsと実表の同一性に届かない。新しい実行時フラグ、型付け済み返却値の供給、信頼条件、Rustの重複テストは追加していない。

原Source、RustのDeclared型の出どころ・引数名・Equality/演算子スキーマ・RoundingMode構成子の必要な原文とSHAは[source-evidence-u28.json](source-evidence-u28.json)に保存する。Rustの登録型・ABI・鍵の実行全比較を行ったとは数えない。

全検査はrun-r1.pyを通し、formal/の対象なし既定ビルド又は同所の-M12288付き単独Leanを使う。元の.26の対象指定build23件は取り消さず、追加逸脱0と分ける。全private/生成宣言の公理監査・全体verify-r1・独立レビュー・受け入れは、局所検査の成功から結論しない。
