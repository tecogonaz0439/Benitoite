# Lean 担当による Rust 試作の照合

`rust/src/checker.rs`・`search.rs`・`lib.rs` を、独立に証明した `lean/P2.lean` と照合した。読解した版について、偽の証明を受理する具体的な差異は見つからなかった。負の整数の Lean への出力で再現する不具合が1件、資源の指標の範囲に関する確認事項が2件ある。同じ試作を担当する者による相互照合であり、独立した Opus のレビューではない。

本稿の行番号は2026-10-30 14:55〜14:58 JSTの読解時点を指す。指摘の実装修正は親担当に任せ、Rust のファイルは変更していない。

## 再現した不具合と費用の制限

| 項目 | 場所 | 問題・根拠 | 修正案 |
|---|---|---|---|
| 負cutの証明書を Lean へ書き出せない | `checker.rs:242` `Cert::lean`、不良の負divisorも出す場合は225行 | `(.split 0 -1 (.close 0) (.close 0))` は減算として解釈され、Lean がエラーにする。14:58:26の実行で再現した。括弧付きの `(.split 0 (-1) ...)` は14:58:51に成功した | Intの位置引数を `({k})`・`({d})` として出力する。負cutを使う実際のsplit証明書で再出力を確認する |
| `digits` を最終の検証も含む最大桁数と読むと一致しない | `search.rs:400`、500行、`lib.rs:39` `Lin::holds` | `x=999 ∧ y=999 ∧ 999*x-999*y≤0` を `digits=3` で解くと、`Model([999,999])`、`max_digits=3` を返す。元の式の検証では `999*999=998001`（6桁）を計算する。結果の真偽は正しい | 最終検証にも同じ桁数検査を通すか、`digits`・`max_digits` は探索内部の数値の指標であり、原式の検証はchecked i128だけで行うと明記する |
| `operations` は総演算・総費用を数えない | `search.rs:174`、416行、487行、493行、500行、`checker.rs:119` | gcdの内部の剰余ループ、clone、正規化、最終のcheck、元Formulaの各係数の評価に共通のtickはない。checkerは全node数を制限するが、Combineのtermsは各列≤100000であって合計ではない。この点は読めば確定し、計算時間の悪化自体は未測定 | operationsの指標を明示する。厳密な費用制限にするなら正規化・検査・モデル検証まで同じfuelを渡し、総terms数・総係数数を事前検査の共通上限へ加える |

負cutの再現に用いた誤った短い入力は [lean/RenderProbeRejected.txt](lean/RenderProbeRejected.txt)、括弧を付けた成功例は [lean/RenderProbe.lean](lean/RenderProbe.lean)、ログは [14:58:26](logs/lean-20261030-145826.log) と [14:58:51](logs/lean-20261030-145851.log) にある。後者の Lean 自体の終了状態は0である。構文の失敗を一般の意味規則の変更の根拠にはしていない。

桁数の再現は、既にビルドされた試作のrlibへ [lean/review_probe.rs](lean/review_probe.rs) をリンクして実行した。出力は [logs/lean-rust-review-probe.log](logs/lean-rust-review-probe.log) にある。`operations=4` で定数の矛盾が証明される例も出したが、この値自体はtickの定義通りであり、不良の証明ではない。総計算量の上限として扱わないための確認である。

## 整合していた点

| 観点 | 照合した理由・限界 |
|---|---|
| 事実の番号 | consume/deriveはfacts末尾へpushする。deriveとcloseはgetを使うため先行しない番号を拒否する |
| Or の両枝 | checkerは左右を `&&` で検査する。左に渡すfactsはcloneし、右へ左の導出を持ち込まない |
| split前の導出列 | searchのlinearは元factsへstepsに対応する導出を追加し、その状態で枝を探索する。戻す際に `wrap(steps, Split(...))` として親の導出をsplitの前へ復元する。枝の番号と一致する |
| 整数二分岐 | 左がunit coeffの `x≤k`、右がstrict_negによる `-x≤-k-1` であり、Leanと一致する |
| 負数の床 | 丸めは正divisorを要求し、`checked_div_euclid` を使う。Leanの正除数の `Int.ediv` と一致する。検索側の `div_euclid` も除数は正であり、0と `MIN/-1` の経路はない |
| 非負線形結合 | 負の重みを拒否し、checked加算・乗算で得た実際の結果をexpectedと比較する。左foldとLeanの右foldは数学的整数で同じである。i128の中間overflowによる拒否は保守的な追加条件である |
| 正規化の極性 | Rustはtrue=正、Leanはfalse=正であるが、入口はそれぞれの正極性を渡す。Eq/Neの左枝は元coeffとbound-1、右枝は負coeffと-bound-1であり、順序も一致する |
| 大きい入力の拒否 | checkerは反復の事前検査で式深さ256、証明書深さ1024、変数数256、合計node数100000を制限してから再帰する。solveは式深さ128と変数数256を先に検査し、探索のgo/linearは深さ256でunknownになる |
| 整数モデル | 有理数復元のden=1だけをモデル候補にする。linearの元factsを検証し、さらにsolve出口で元Formulaを検証する。検証失敗やchecked演算のoverflowはunknownになる |
| 予算切れの受理防止 | ErrはUnknownへ流れる。Refutedも最後にcheckを通る。unknownやoverflowを成功へ変える分岐は見当たらない |
| 再帰の限界 | 上記の深さの明示上限はある。Rustのスタック使用量がどの実行環境でも安全だという測定・証明はしていない。深いBox木の生成/DropやLean出力の再帰は別の確認対象である |

資源の上限はLean側にはなく、Rustが追加で拒否する条件である。その差は、Rustが受理した証明書を同じ数学的意味でLeanも受理できることと両立する。今回の有限の再出力例による照合から、任意のRustコードの意味保存定理が得られたとはしない。

## 親担当による修正後の確認（15:00 JST）

負のcutとdivisorの出力に括弧が追加されたことをソースで確認した。代表例にも負cutで整数分枝を使う入力が追加された。生成された式・証明書の全体の再検査は、親担当の最終Replay検査へ割り当てる。

モデルの係数ごとの評価は `Engine::eval_lin` と `eval_formula` を経て、探索と同じchecked演算・桁数・operationsの検査を使うよう変更された。既存の `review_probe.rs` を修正後のrlibへ再リンクしたところ、提示した3桁の例は **`Unknown(digits, limit=3, used=6)`** となった。出力は [logs/lean-rust-review-probe-fixed.log](logs/lean-rust-review-probe-fixed.log) にある。未測定の挙動を修正済みとしたものではなく、同じ入力の修正前後を実行して確認した。

gcdの内部の剰余ごとにもtickが入り、checkerの事前検査は式・導出の係数数とcombineのterms数を共通の合計へ加えるよう変更されたことを読解で確認した。operationsがnormalize・clone・最終checkerの全仕事量を表さない点は残る。親担当は「探索で定めた抽象演算数」として報告し、CPU時間や全仕事量の上限を本番の残課題にする方針である。
