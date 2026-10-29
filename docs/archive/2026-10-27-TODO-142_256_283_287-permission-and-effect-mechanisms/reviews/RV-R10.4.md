# RV-R10.4: 構造等号と被覆の制約の独立レビュー

2026-10-28。対象は R10.4 の未コミットの差分（20ファイル）と `r10.4/` の results.md・ログ。作業版と基準版（`3d7219a2` の archive）を別の target でビルドし、入力（範囲の外の原子が入り込む経路、被覆で受理すべき例、Top だけの resume の例）を通して比べた。IR の検査器を通す探査は作業版の写しで行った。作業用のディレクトリと git の状態は変えていない。

結論: 重大0・中1・軽4。意味（被覆と構造の境界）、健全性、Top の互換に問題はない。中1 は範囲付きの原子を使うプログラムで効果の宣言漏れの診断を悪くするので、直してから取り込むことを推す。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `typeck/solve.rs::solve_effects` の E0519 の分岐 | E0519 を出す条件が「必要な原子が非 Top」か「上限のどこかに非 Top の原子がある（名前を問わない）」で、同じ名前の原子が上限にあるかを確かめない。`uses` を持たない main が `File.Read["/data/a"]` の関数を呼ぶと、基準版は E0501（呼び出しの位置、declared here、`help: add uses ...`）だったのが、E0519 の notCovered（主位置が関数名、ラベル「is not covered by ``」が空）になる。`uses File.Read["/data/**"]` の main が `Console.Write` の関数を呼ぶと、無関係な範囲付きの原子があるだけで E0519 の unknownSource になる。どちらも直すべき呼び出しの位置と直し方が消える。主位置が `r.span`（関数の本体では関数名、ラムダでは lambda 全体）で、`missing_effect` が使う由来の位置を使っていない | 上限に同じ名前の原子があって範囲が覆えない場合だけ E0519 にし、それ以外は従来の E0501／E0401 の経路へ戻す。主位置を由来の位置にし、`r.span` は副位置の declared here にする。ラベルの expected は同じ名前の原子だけを並べる。「周囲の原子を広げるか、呼び先の範囲を狭める」help を加える。テスト `effect_coverage_uses_one_same_named_atom` の `File.Read` → `File.Write` の行、02-05 の手順3、01-07 と 02-10 の E0519 の条件の文を合わせる |
| 軽1 | 軽 | 同上 | E0519 の分岐が `continue` するので、従来の pair の経路の `reported` による重複の抑止と `break` を通らない。一つの引数が二つの原子で覆えないだけで E0519 が2件出る（`relay(body: g)`）。行の変数が欠けると E0401 も重なり得る | pair を持つ制約では位置ごとに一度だけ報告して `break` する |
| 軽2 | 軽 | `typeck/interval/identity/tests.rs:127` | FnUses の制約を `Structural` で作るが、本番の `check_function` は `Cover`。Top だけの準備なので結果は変わらないが、位置表になく理由も書かれていない | `Cover` にそろえるか、位置表に「テストの準備だけで構造」と書く |
| 軽3 | 軽 | `ir/check.rs` の `structural_effects` の前のコメント | 根拠の設計書の節を示していない | 02-06 で今回加えた決定の節を引く |
| 軽4 | 軽（記録だけ） | `traits/impls.rs` | 宣言が `/data/**` で実装が `/data/a` の場合に E0711 になる。Lean の `checkMethods` は本体を型クラスの宣言の効果に被覆で照合するので Rust のほうが厳しい（健全性は損なわない）。01-06 に「構造上の部分集合」と明記してあり意図した選択と読める | 後続で Lean と比べるときの差として記録する |

## 問題がなかった点

- 位置表の網羅: 本番の `Constraint::EffSub` の生成15箇所、`register_effect` の直接の呼び出し（`equal_function_effects` は構造、`flow_inner` の Var/Fn と Fn/Fn は被覆）を数え直し、位置表（被覆10行・構造14行）がすべてを含む（軽2 のテストの準備を除く）。`calls::generate`・`builder`・`generate::apply`・try の die の Process.Exit は被覆、部分適用・保護本体と節・Fail の Rest と節・lazy・guard・die の説明・with の State は構造で、Lean の E_Sub／B_Sub、E_PartialCall の `Eff.Sub`、E_Handle／E_HandleFail、C_Use と一致する。IR の検査器も C_Sub・C_Eff・`Ty.Le`・K-Handle の節と Fail の Rest が被覆、C_Handle・C_Handle_Fail の保護本体と純粋の要求が構造で、L50.4 の 1 と一致する。
- 被覆の意味: `EffectName::covers` は名前の一致を確かめてから `Range::covers` を呼ぶ。異なる種類や族は false、Top を覆うのは Top だけ、和で覆わない。`EffectSet::covers` は行の変数と Fail を構造上の所属で判定し、Lean の `Atom.Covers`／`Eff.Covers` と一致する。伝播は右辺の確定部分との照合にだけ被覆を使い、行へは元の原子を構造で挿入する。狭い原子を消さず、相互被覆から等号を導かない。型の等号・関数型の単一化・Fail の型・制約の重複の鍵・hash は構造のまま。
- 健全性: 範囲の外の原子が入り込む経路（行の変数のインスタンス化、if で合流した関数値、ハンドラの保護本体・節・resume・Fail のハンドラの外への流出、注釈付きの部分適用、パイプ）はすべて拒否された。被覆で受理されるべき入力は受理され、脱糖後のコア IR の `check_program` も0件。
- Top の互換: CLI 249通りで差0、交換206ファイルが大きさと SHA-256 まで一致。追加の Top だけの resume の6例もテキストと JSON の両方で基準版と出力・終了状態が同じ。
- 規約・テスト・検査の記録・設計書: 本番に `unwrap`・添字・`as`・lint の免除を加えていない。文言は `diag::codes` と `typeck::text`。テストは公開の `check_text` と脱糖・`check_program` を通して観測する。work は check.sh 自身の終了0、外側473秒。設計書は中1 の E0519 の条件の部分を除き実装と一致する。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1・軽1〜軽3 | 採る（推す案。診断の退行なので同じ枝で直す） | R10.4b |
| 軽4 | 記録だけとする。Rust のほうが厳しい側で健全性を損なわず、01-06 に明記がある。K10 で Lean と比べるときの既知の差として申し送る | K10 への申し送り |

R10.4b（同じ枝）で中1・軽1〜軽3 を直し、work を再実行した（check.sh 自身の終了0、外側453.80秒、lib 1,354件・統合41ターゲット413件）。取りまとめがレビューの入力で確かめた: 範囲付きの原子を持つ main が `Console.Write` の関数を呼ぶ例と、`uses` のない main が `File.Read["/data/a"]` の関数を呼ぶ例は、B_WORK と同じ E0501（呼び出しの位置、declared here、`add uses ...` の help）。範囲が覆えない一引数の例は E0519 が1件で、同じ名前の原子だけを並べ、「widen the surrounding atom scopes, or narrow the callee scopes」の help が付く。
