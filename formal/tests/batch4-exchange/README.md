# 交換13/5の独立入力

corpus 13と四形式のsidecar 5を六つの交換CLIへ渡す。期待コアはRustの書き出しやLeanの脱糖から生成していない。旧独立入力の通常コードは保持し、専用構築器のコアと追加例のLet・局所番号・評価順を手で列挙した。比較時にLetを除去する正規化は使わない。

```sh
python3 -B formal/tests/test_batch4_exchange.py
```

既定のlake buildで六実行ファイルをビルドしてから、リポジトリの根で実行する。CargoもLLMも起動しない。manifest.jsonはこの独立入力の版・件数・SHA-256を固定する記録であり、将来のRustの全件数ではない。

| 入口 | ファイル | 独立入力の成功件数 |
|---|---|---|
| desugarDiff | corpus | 45定義、差分0・対象外0・除外0 |
| builtinCheck | corpus・builtins | 1入力、20組み込み宣言、要約不一致0 |
| coverageDiff | coverage | 6件、燃料切れ0 |
| coverageProgramDiff | coverage-program・builtins | match 2件とbinding 1件、燃料切れ0 |
| surfaceCheck | corpus・builtins・stdlib | 1プログラム、成功 |
| surfaceCheckAll | corpus・builtins・stdlib | 44通常定義と1実装、合計45件成功、Q11の件数[1,0]も一致 |

| 定義 | 確認する契約 |
|---|---|
| fn:8・101〜106 | 旧batch2の辞書付き操作・Fail・NoFail・節の辞書。変更なし |
| fn:201〜203 | String/List/Bytesの専用宣言、copyとlength。初期化のReference呼び出しはない |
| fn:204・216・218・219 | 通常引数を一度束縛してから専用操作。Stringのappend/appendAll、Listのラムダの潜在行、Byteのappend |
| fn:205 | ΓとΔの共有番号。専用・通常・専用の三位置で外側のbound 2 |
| fn:206・211 | ifとmatchの本体から同じ専用位置を使う。cond/scrutineeのLetの分だけ番号を移す |
| fn:207 | List要素の型変数と潜在行をkindに保持 |
| fn:208・212 | 先にcopyした通常値のlambda/部分適用への捕捉。後者は穴のLetを作らない |
| fn:209・210 | 受け取った辞書と、節のclause.depth・resume・通常値・専用位置の共有番号 |
| fn:213・214・215 | 逆順の名前付き引数、外側セルを使うhandle本体と内側セルを使う節、Fail節内の宣言 |
| fn:217 | 旧版の参照先funRefを使わず、専用lengthへ移す |
| fn:220〜223 | Monad2の上位辞書とResult/UserResult。変更なし |
| fn:301〜303 | blockの値、囲む関数へのreturn、lambda末尾のblock内return |
| fn:304・305 | Integerのmin64/max64 |
| fn:306 | 逆順の二穴。直接calleeなのでLetは0個、引数はvar 0/1 |
| fn:307・308 | 展開済みSourceLocation.LocationとLog.Recordの通常レコード |
| fn:309〜313 | Log.emit/enabled、完全なハンドラ、二操作の送り直し、処理後のConsole.Writeの残存 |
| fn:314 | cの固定式・bの穴・aの固定式のソース順。固定式のLog.enabledだけLet、最後はa/b/cへ並べ替える |
| fn:315 | 間接calleeを先に評価し、固定式の後に穴の直接値を渡す |

三つの既存coverage入力を保ち、Integer全域・二範囲の全域・一点の穴を加えた。otherは未被覆値の表示を持たず、穴の表示の期待は現在の交換の `_` である。非網羅的であることを厳密に比較する。coverage-programにはInteger全域のmatchを一つ加えた。

旧batch3のcorpus.jsonは版12の拒否入力として保持する。test_batch3_exchange.pyの六入口の意味の比較は、構築器のないfn:8・101〜106・220〜223の11定義と既存coverage 3/2件に限り、その集合では末尾matchが0なので注釈を[0,0]とする。全30定義を渡した場合は「版13で再生成」の理由で拒否する。旧19構築器定義の意味の検査は本入力へ移しており、旧版を受理する互換変換はない。

旧test_batch3の必須欄・未知欄・種類・通常値化・局所番号・効果・七捕捉境界・辞書と継続・定数内構築器のassertはtest_batch4へ移した。refsの必須性はkindの必須性へ、getRefの破損はkind注記の不一致へ、専用操作のStateの拒否は通常引数のAskの効果の拒否へ対応させた。refs/newRef/getRef/setRefは新版でも全て拒否する。新版の拒否理由を厳密に照合し、存在しなくなった参照先の型検査で捕捉禁止を代用しない。named-exchangeのfn:4も、穴のLet一つだけを除いた期待コアへ移した。

Pythonの変異検査は版8〜13/sidecar2〜5の境界、版の組み合わせ、旧refs、新構成子・必須欄・余分な欄、整数の範囲とInteger64の別名、block内の捕捉とlazy内return、期待コアのLet・順序・専用参照、Logの効果の隠蔽を確認する。範囲外の整数は未使用の定数・期待コアでも入口の終了2とする。型の誤りと比較不一致は終了1で区別する。

## Rustへの引き渡し

Rustの通常出力は13/5へ切り替え済みであり、機能別の局所入力は本番parserから五形式を書き出す。以下は実装済みの入力である。局所比較の成功だけで全corpusの一致を主張しない。全件の版と件数はtests/desugar_exportのexchange-manifest.jsonとrouting-manifest.jsonで固定し、全比較は `scripts/check-formal.sh` で行い、2026-10-21の2回目（`76ed2d5e`、終了0）で完了した。最後の全入力1,789件・73,836定義・Coverage 22,482件が一致し、機能別の本番parser入力も六入口で一致した。

| 担当 | 実装済みの局所入力 | 入口の割り当て |
|---|---|---|
| T1 | Integer全域・分割全域・一点の穴の3判定 | coverageDiffとcoverageProgramDiff。Rustの資源予算は別検査 |
| T2 | 新しい穴/固定式3定義、静的な穴/固定式/パイプ3定義 | desugarDiff・builtinCheck・surfaceCheck・surfaceCheckAll |
| B2 | 専用構築器・共有番号・辞書・継続。b3の9入力52定義、表層47件 | 六入口。専用構築器5定義は手書きの期待にも比較 |
| B3 | blocksの2入力10定義、表層10件、独立Coverage1件・プログラムCoverage1件 | 六入口。ガードと説明は実行の順序/回数を別途検査 |
| G2 | g2の1入力10定義、表層10件、独立Coverage1件・プログラムCoverage1件 | 六入口。実出力の書式と位置は別のCLI検査 |
| G3 | g3の1入力8定義、表層8件、独立Coverage1件・プログラムCoverage1件 | 六入口。公開APIの結果を小モデルとも別途照合 |

check-formal.shは本独立入力を毎回実行し、Rustのb3/blocks/g2/g3も固定manifestで六入口へ渡す。旧Rust出力を新版へ黙って読み替えない。本テストの成功はJSONの読者と独立期待値の証拠であり、Rust本体の正しさ・停止性・GC・出力の一回性を証明しない。

作成時の関門: 持ち主は六つの公開交換CLIである。新タグの読捨て、旧版への混入、穴の無駄なLet、共有番号の誤り、期待コアと未使用整数の範囲検査漏れ、捕捉や効果の隠蔽を検出する。既存の旧版入力には専用コアとblock、新しい穴の期待、Logの表がなく、この境界を確かめられない。既存の非構築器のassertは保ち、構築器のassertは新版へ移した。本体にテスト用の差し込み口は追加していない。入力は有限の小例で、深い再帰や大きなリストは使わない。
