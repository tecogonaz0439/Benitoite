# L07d の結果

2026-10-24。基準 B_WORK と開始時の HEAD は `15eff5aaf629d6790b9b2a2da82ecc51d6ac9950`、依頼されたブランチは `mod012/L07d` である。開始時の作業ディレクトリに差分はなかった。

L07d の実装と指定の work 検査を完了した。六比較・not・全 Block 形・ite/elseIf/ifOnly の評価規則と、正常な子や選んだ枝からの条件付きの導出存在を追加し、trace のキーの範囲・一意性の証明を拡張した。中心命題の言明と公理は変更していない。C0 の受け入れは完了しておらず、定義・言明・仮定の独立レビューと受け入れは取りまとめへ渡す。

## 変更と申し送り

- `formal/Benitoite/Interval/Eval.lean` に `EvalBlock` を追加し、`EvalPartial` と相互帰納にした。Block の key は最初の式の番号であり、容器自身に番号を割り当てない。`blockSize` と `advanceKey` により、右辺の部分木の大きさだけ続きの番号を進める。比較・条件・枝のキーは L07c の `childKey` から決まり、未選択の枝の番号も詰め直さない。
- bind と shadow は正常な右辺の値を新しい先頭位置に追加する。builder は `none` を追加し、discard・式文は環境を保つ。末尾の束縛・discard・パターン束縛は正常値だけを Unit に変え、失敗と return を保つ。途中の失敗・return の後には、後続の文・右オペランド・枝を評価する前提を置かない。
- パターンの局所位置の関係 `PatternLocals` は、var では右辺の値一つ、wild では空列、それ以外では束縛数だけを要求して各位置を任意の通常値とする。`patternLocals_length` は追加位置数が表層の束縛数と一致することを示す。これは既存の `patternSlots` に合わせた構造の抽象化であり、実際の照合・射影や、構造内の値との一致は証明していない。末尾の `lastPat` も構造の照合を抽象化する。
- `add_derivation_exists`・`divMod_derivation_exists`・`compare_derivation_exists` は、子が正常な整数を返すとき、親の結果とその事象を含む trace を持つ導出の存在を示す。拒否される算術も含む。not、三つの if、bind/shadow の導出をつなぐ補題も追加した。環境を制限しない補題なので、型どおりの環境にも適用できる。型付けから土台の全式の導出存在を導く定理は追加していない。
- `eval_trace_keys` と新しい `block_trace_keys` は全評価規則を相互帰納で扱い、キーの範囲と一意性を示す。`eval_divMod_event` と新しい `block_divMod_event` も相互帰納にし、Block や分岐内の除算の事象が検査付き除算に由来することを示す。L07c のキー衝突の独立例はそのまま通る。
- `formal/Benitoite/Interval/Flow.lean` の `Comparison`・`Comparison.Holds`・判定可能性・`Comparison.ofBinOp` を、名前と定義を保って Eval へ移した。`integerConstant_sound`・`atomRange_sound` は、相互帰納の評価関係に合わせて、式の部分木の大きさによる再帰の証明に直した。両定理の言明と解析の規則は変更していない。新定義は既に既定 import に含まれる Eval の中にあり、import の追加は不要だった。
- 01-12「区間解析の対象構文の評価関係」に定義・評価順・束縛位置・キー・導出存在の言明を写し、07-04 の同節・「01-12 との対応」・形式化の範囲の表を更新した。実際の構造の照合と全入力の導出存在、非整数の算術・比較などの規則のない形、短絡・match・幅付き整数・同定済み API の表層への接続を証明済みと扱っていない。
- L07b は、新しい評価規則に対して正常値所属と警告健全性の二定理を接続する。キーの一意性から引数と解析区間の対応までは結論しない。`EvalPartial` と `EvalBlock` が相互帰納になったため、両方の規則を合成する証明には相互帰納の補題または対応する再帰を用いる。
- X03 は、導出を構成できた入力と未構成・規則のない形を区別して VM と比較する。特に構造の照合は今回の関係で抽象化しており、構造の内部の値との一致をこの証明から引用しない。全入力の導出存在と、脱糖・Release・Rust/VM との意味の一致は未証明である。

## 実行した検査

lake は `formal/`、check.sh と git の読み取りはリポジトリの根で実行した。成功した実行の外側時間は `/usr/bin/time -p` による。`rtk proxy` は出力を変更せずに通す。

| コマンド | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `rtk proxy lake build Benitoite.Interval.Eval Benitoite.Interval.Flow Benitoite.Interval.Analyze` | 0 | 4.48秒 | 最後の Lean 変更後の局所ビルド。依存する Environment・Arithmetic と既存例・新しい独立例も成功。警告なし |
| `rtk proxy lake env lean /private/tmp/l07d-before.lean` | 0 | 0.82秒 | 基準版の Eval を別名前空間へ読み取り専用で取り出し、not・Integer64 の lt・block・ifOnly の具体入力に導出がないことを確認。警告なし |
| `rtk proxy lake env lean /private/tmp/l07d-axioms.lean` | 0 | 0.37秒 | 新設・変更した16定理の `#print axioms` を確認。依存は Lean 標準の propext・Classical.choice・Quot.sound のみ |
| `rtk proxy scripts/check.sh --level work --base 15eff5aaf629d6790b9b2a2da82ecc51d6ac9950 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.01秒 | spec_tally・spec_examples・formal_build の三単位だけを選択 |
| `rtk proxy scripts/check.sh --level work --base 15eff5aaf629d6790b9b2a2da82ecc51d6ac9950 --only formal_build,spec_examples,spec_tally` | 0 | 15.76秒 | 指定の work を一度実行。仕様集計の自己検査・集計、仕様例7件、既定 lake build と sorry の拒否が成功 |
| `rtk proxy git diff --check` | 0 | 未計測 | 空白の誤りなし |

仕様例は成功7件・失敗0件・ignored 0件である。仕様集計の初回リリース完了条件に未記入はない。「テスト参照のない節」の表示を Lean の形式化の失敗とは扱っていない。指定の work 検査に失敗・再実行はない。Rust の全 lib・stage・change・release・Rust/Lean 全比較・VM 比較はこの作業では実行していない。

局所の証明調整では、同じ Eval・Flow・Analyze のターゲットのビルドを反復し、構成子の型推論、相互帰納型に対する通常の induction、依存する添字の除去、キーの範囲の単純化、独立例の型推論の誤りで終了1となった試行がある。相互帰納の補題と部分木の大きさによる再帰、明示的な型・値・キーで修正した。最初の lake の実行ディレクトリを誤った試行は formal/ に直した。これらの途中の外側時間は未計測であり、最後の成功を表に記した。

一時ファイルの確認にも、比較用の正規表現が次の補題まで含めた誤り、ファイルの生成前に起動した入力不在、基準版の再現資料で let の導入と通常の仮定の導入を取り違えた誤り、不要な simp/dsimp による終了1の試行があった。比較範囲を定義本文に限定し、一時入力を生成してから検査し、let を展開した後に評価導出を仮定する形へ直した。最終の成功した入力には追加の公理・sorry・解析器の代用品はない。期待値・大きさ・ignore・時間制限・検査範囲は緩めていない。

## 契約と独立例の点検

`Reached`・`NormalSoundness`・`WarningSoundness` の定義本文は、基準版との文字列比較で一致した。`integerConstant_sound`・`atomRange_sound` の言明も一致した。旧主定理、Release、Builtins、`Builtins.Assumptions` に変更はなく、新しい公理の宣言はない。

`test-audit` の作成時の関門では、評価関係の値・失敗・return・trace と束縛位置を独立した契約とした。基準版には今回の形の評価規則がなく、既存の区間・分岐の局所例では、実際の評価導出・未選択枝の trace・Block の局所参照の退行を捕まえない。基準版の四形の導出不在と、変更後の実際の導出存在を確認し、false の ifOnly は存在と任意の導出の空 trace を組にした。新しい六つの独立例は Eval の既定ビルドに置き、値と真偽・番号を独立に固定した。テスト専用の公開関数・フラグ・注入・ラッパーは加えていない。

既存例・テスト・公開定義の削除はない。Comparison の定義の移動を含め、Lean の各ファイルの最初の example より前の純増は404行、最初の example 以降の純増は159行である。Rust 本体と Rust テストの増減はともに0行である。

検査の割り当ては依頼文の補足に従い、plan の検査表そのものは変更していない。相互帰納の評価への変更に必要な Flow の証明の調整を同じ変更で行った。停止条件に当たる言語の規則・中心命題・公理の変更はなかった。L07b の二定理、C0 の独立レビューと受け入れ、X03 の VM 比較はそれぞれの担当へ渡す。

private/ とそこを指すスキルのリンクは読んでいない。git の add・commit・branch・merge・stash・reset・checkout 等の変更操作は行っていない。コミット・取り込み・docs/todo の更新・公開は取りまとめの担当である。
