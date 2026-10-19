# 交換12/4の独立入力

corpus 12と四つのsidecar 4を、六つの本番CLIへ渡す。準備の宣言表と最初の七定義はbatch2-exchangeと同じ契約であり、構築器と二引数クラスの23定義を加えた。期待コアをRustの書き出しやLeanの脱糖から生成していない。JSONの並び順を手で数え、letと番号を列挙した。

| 定義 | 照合する契約 |
|---|---|
| fn:8, fn:101〜106 | 既存の辞書付き操作、Fail、NoFail、節の辞書の七定義 |
| fn:201〜203 | String/List/Bytesの宣言、copyとlength、初期化の内部let |
| fn:204 | 通常引数一回、get・add・set、後続copyの順序 |
| fn:205 | セル・通常値・セルの交互配置。Γ=[cell2, snapshot, cell1]でcopy 2 |
| fn:206, fn:211 | if/matchの本体でも同じセルを参照 |
| fn:207 | 型変数と潜在行を持つListの要素型。全参照先へ型を保持 |
| fn:208, fn:212 | 先にcopyした通常値のlambda/部分適用への捕捉 |
| fn:209 | 受け取った通常辞書。宣言後のΓ=[cell, x, dict]、辞書位置2、長さ3 |
| fn:210 | 節内の宣言と通常bindをまたぐclauseのdepth・resume・local |
| fn:213 | right→leftのソース順で評価し、left/rightの契約順に渡す |
| fn:214 | handle本体は外側セル、節は自分のセルを使いresume 1 |
| fn:215 | Fail節の内側の新しいセルの受理 |
| fn:216 | StringのappendAllのjoin→add→setと引数一回 |
| fn:217 | 純粋な参照先funRefの宣言照合とlengthの展開 |
| fn:218 | List.appendのlambda引数とlambdaEffectsの行の保持 |
| fn:219 | Byte一個をBytesへ変換してから連結・set |
| fn:220 | Monad2→Applicative2→Functor2の上位辞書と逆順の名前付き引数 |
| fn:221 | メソッド値化が辞書を捕えるlambdaと潜在行を保持 |
| fn:222, fn:223 | Result/UserResultの二引数型へのpureの具体化。受け取った辞書を使う |

fn:210の節の初期Γは[resume, value, dict]で長さ3、セルの宣言とIntegerのbindの後は[Integer, cell, resume, value, dict]で長さ5である。clause.outer=0、arity=1、dictCount=1、constraint=0、depth=2とし、辞書位置4、resume位置2、通常値位置3を参照する。コアではdiscardのletも増えるため、再開の引数を評価した後のresumeは4となる。初期値の内部letは後続Γへ残らない。各位置・depthを一つ誤る変異を拒否する。

Pythonは正例をまず受理し、専用名の通常値化、外側セルのlambda/lazy/節/Fail節への捕捉、部分適用の固定引数・callee・partialCon、returnとタスク用関数へ渡すlambdaでの捕捉を拒否理由とともに検査する。レコードへの穴という別の拒否へ逃げないようpartialConにはPosPairを使う。型保存だけで捕捉禁止を代用しない。未知の深い位置に新欄を混ぜた旧版、必須欄や余分な欄、定数本体の専用構文、Monad2の上位辞書とエラー型の破損も確認する。

coverageの三件とcoverage-programの二件はbatch2の独立期待を保つ。新しい構築器の構文はこの二形式へ追加しない。Result/UserResultのpureは受け取った辞書のシグネチャと脱糖の比較であり、実装の法則や実行結果の証明ではない。それらは本体のMonad2ExamplesとResultLawsで別に確かめる。

```sh
python3 -B formal/tests/test_batch3_exchange.py
python3 -B formal/tests/test_batch3_exchange.py --rust-dir target/formal-batch3/b3
```

既定はこの独立入力だけを読む。--rust-dirはT3/M1/B3で書き出した五形式すべてを必須とし、欠落・空の定義・除外・対象外・不一致を失敗にする。実ソースの入力別の定義数と表層・網羅性の件数は、crates/benitoite/tests/desugar_export/batch3/manifest.jsonと照合する。T3/M1は出力先の末尾のt3/m1で選び、それ以外はB3の9入力52定義・表層47件を要求する。入力を減らして別の集合の成功に見せ掛けることはできない。Cargoは起動しない。

Rustの交換器は版12へ専用情報を保持し、check_batch3.pyがstringCopy/listCopy/bytesLength/interleaved/typeRowの五定義をfn:201/202/203/205/207へ照合する。型と行の実ソースにはE0418に従って未使用のcallback引数を置く。比較用の写しだけにその頭を補い、末尾returnの続きの注釈は双方の元の値を確認してからRustのUnitにそろえる。参照名は既知の標準名の固定表で対応させ、変換元と期待コアの全体を比較する。節の辞書とresume、受け取った辞書は実ソースの番号も別に固定している。check-formal.shは既定と--rust-dirの両方、および実ソース照合を呼ぶ。本番全件の比較を実施する担当と時期は改造の計画に従う。

test-auditの作成時の関門: 持ち主は交換の公開CLIであり、守る契約は新情報の保持と版境界、番号・型・効果・辞書・捕捉の受理/拒否である。現実の退行は新タグの読捨て、corpus11への誤った補完、セルを数えない局所番号、境界へ空Δを渡し忘れる変換、引数やlambdaEffectsの欠落である。既存の交換テストには専用構文がなく、これらを捕まえられない。本番の差し込み口やテストダブルは追加していない。
