# B2 の結果

基準は開始時の`git merge-base HEAD san_benito`で得た`8425c221c7e240011a052d47fa43e8101a6295ea`である。コミットとdocs/todoの変更は行わない。

## 実装

構築器の既定経路を、Referenceへの展開からBuilderLet/BuilderOp、下位IR、命令91〜95、B1の実Hostへ切り替えた。通常値に構築器を加えず、Listの要素型はコアの検査に残す。通常引数をソース順に一度だけ評価し、専用の宣言と操作自体はStateを加えない。通常Referenceと解放のState、明示した関数のuses Stateは保つ。

Protoのbuilder_slots/builder_sites/builder_inputs、CallFrameの専用Slot配列を追加した。handle/handleFailの本体へ同じHostを渡し、通常のCaptureSourceへは加えない。専用の生存情報で親と本体を別々に整理し、保存・再開・未再開の破棄とタスク取消は既存の枠のTrace/Discardへ接続した。専用欄を呼び出し枠の資源計数へ含め、末尾呼び出しでも古い専用欄と計数を解放する。通常束縛と専用宣言の連なりは、コア検査・下位化・コード生成でループとして扱う。

独立参照評価は独自の場所の表と不変の内容の置換を使い、VMのHost操作を呼ばない。検証器は種類・定義と支配・範囲・個数・専用入力の親子と重複、本体の通常値としての持ち出しを検査する。逆アセンブルとbytecode_statsも専用欄・操作表・入力を示す。

型付き表層と交換から旧refsを除き、Rustの書き出しをcorpus 13/sidecar 5へ切り替えた。標準構築器の説明と生成Skill、設計01-06/07/08/12・02-05〜09・07-04を更新した。01-10の通常リソースの解放規則は変更していない。

## 入力の大きさとテストの関門

新規のリスト入力は長さ3以下、構築結果は4要素以下、文字列の反復8以下、handleの入れ子2以下であり、Kのstressの上限にも収まる。タスク取消は、子が構築器の生成後にreadyを書いてから親を進める。子の長いsleepを実時間で待たず取消で終える。大きさ自体を検査する新規テストや新しいignoreはない。

専用コアの手書き入力は三種類の実命令・Host・外側の構築器とhandle本体の共有を検査し、表層の検査はStateの扱い・引数の一回評価・handleFailと早期returnの接続を検査する。どちらも固定した期待内容を使い、VMと独立参照評価を照合する。参照評価が対象にしないタスク取消はVMだけで検査する。Miri用の小さい実命令の検査では、待つ枠の専用根の生存と、最後の使用後に枠を残したままHostが回収されること、終了後の枠の計数0を確かめる。内部の補助関数の呼び出し方や、ソースの字面の一致を期待にはしない。

## 検査の経過

workはplanのB2行と補完行、lintとPythonはR176に従う。基準と指定を固定したdry-runは成功した。作業末のコマンド・終了状態・外側の時間は、[commands.jsonl](commands.jsonl)と下表に保存した。途中は関連するコンパイルと局所テストだけを実行した。

最初のclippyは新しいテスト補助のCompKindのワイルドカードで失敗した。既知の全構成子を明記し、lintの許可は追加しなかった。最初のworkはlibで失敗した。新命令の準備に使う専用入力付きのhandle本体をmainに置いていたため、持ち出し禁止の検証に拒否された。その準備をmainを持たない原型の検査へ直し、既存assertと新5命令の検査を保った。

次のworkではlib全件が成功したが、全統合のnamed_argumentsの旧State拒否2件が失敗した。局所操作が純粋になる意味の変更に合わせ、通常引数のReference.getがStateを必要とする入力へ替え、E0501の期待は維持した。局所操作だけなら受理する対照を加えた。実行結果・診断・合成順序を検査する既存のassertは保ち、期待値の緩和とignoreの追加はない。旧refsの書き出し補助を廃止した際、その補助内のBindingKind::Fnのassert一箇所も除いた。専用構築器の新経路には、そのassertが検査する通常関数の参照先自体がないためである（R172）。既存のReferenceの合成順序とデータ依存の検査もassertを保ち、明示したReferenceの計算へ移した（R174）。

失敗の修正後は古くなったlint/fmt・失敗したlib・未実行の統合ターゲットと残りのworkだけを実行した。すでに成功した統合ターゲットとlib全件を重ねていない。既定構成ではlib 1,236件、全統合、通常doc 17件とcompile_fail 17件、release_stack 10件、規約・生成物・集計・Python構文が成功した。既存のlibのignore 21件は通常の実行の対象外のままである。

補完もすべて成功し、B2の完了条件を満たした。既定構成の全統合は40ターゲット317件であり、Cargoの対象一覧とも照合して欠落0を確認した。既存のignore 9件はそのままとした。特殊構成のVM局所libの既存ignoreは各6件である。

| 検査 | 終了状態と結果 | 外側の時間 |
|---|---|---|
| 最初のwork（fmt成功、lib失敗） | 1、テスト準備を修正 | 79.652秒 |
| lib再検査と全統合の途中まで | 1、lib成功後に旧State拒否2件を修正 | 260.202秒 |
| workの残りの18統合ターゲットと他の単位 | 0 | 236.453秒 |
| 最後の全ターゲットclippy | 0 | 6.996秒 |
| 最後のfmt --check | 0 | 2.349秒 |
| VM局所lib / heap-verify | 0、160件 | 41.306秒 |
| VM局所lib / heap-verify + gc-stress | 0、160件 | 41.170秒 |
| 指定4統合 / heap-verify | 0、9件 | 163.515秒 |
| 指定4統合 / heap-verify + gc-stress | 0、9件 | 82.435秒 |
| 取消の待機確認追加後 / heap-verify | 0、1件 | 10.403秒 |
| 取消の待機確認追加後 / heap-verify + gc-stress | 0、1件 | 10.043秒 |
| check-heap.sh全体 | 0 | 626.445秒 |
| 既定のlake build | 0、sorry追加なし | 0.511秒 |
| 交換の互換性・manifestとRust入力の比較 | 0、7件と六入口 | 8.185秒 |

check-heapはMiriの通常構成58件、対象ごとの確保51件、到達可能性比較50件が成功した。Miriの既存ignoreは各1件、最後の比較の既存ignoreは2件である。最後の比較はBENITOITE_HEAP_RANDOM_CASES=20000、各320操作であり、通常の局所libの24系列と区別する。上表の626.445秒はPythonのmonotonicによるコマンド全体の外側の実測であり、Miriのテスト内部に表示される時間ではない。

最終点検では、取消の検査が子のHostを生成しただけで通らないよう、子のsleepが実際に要求を出したことをassertへ加えた。当該1件を通常構成と二つの特殊構成で確認し、lint/fmtも更新した。通常構成のその局所実行は外側の時間未計測（テスト本体0.10秒）であり、上表の補完二構成は外側を計測した。実装・BNT入力・Miriが実行する関数に変更はなく、成功済みの全lib・統合全件・Miriを重ねなかった。

局所交換の比較器の外側のmonotonicは1.543秒である。最後の差分の空白検査も成功した。検査後の文書の整備では、01-12と07-04に残るRust旧版12・未接続の記述を、13/5と局所52定義の成功へそろえた。規則・証明・コード例の変更はない。Rustコードは本番826行増、テスト838行増である（生成物・文書・Python・BNTは除く）。


## 局所交換と計画との差

`cargo test -p benitoite --test desugar_export export_batch3_builders`で9入力52定義を13/5として生成した。`python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/b3 --report <D>/b2c2/exchange-results.json`は六入口で一致し、構築器5定義はL7のbatch4の手書きの表層と期待コアにも一致した。[局所交換の報告](exchange-results.json)へ入力ハッシュと各入口の件数を保存した。`python3 -B formal/tests/test_batch3_exchange.py --rust-dir target/formal-batch3/b3`の互換性・manifestの7件も成功した。formal内のPythonの読者を変えたため、既定の`lake build`も成功を確認した。Leanの定義・定理・仮定は変えていない。

小さい追加判断はdecisionsのR172〜R176に記した。範囲を広げた機能はない。blockの構文、ガード/説明のblockを使う観測はB3へ残す。版全体の形式化比較、change/release、性能の測定、版上げと英日の利用者文書はそれぞれの後続作業の担当であり、この局所の成功で完了とはしない。
