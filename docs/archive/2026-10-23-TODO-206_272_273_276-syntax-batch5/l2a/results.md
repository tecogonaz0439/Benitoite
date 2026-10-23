# L2aの結果

2026-10-23、実装担当Codex。基準B_WORK・HEADはともに `56e0ebc5ffcefe5d4e48a14671a6c33ae4109828`、ブランチは `mod011/L2a`。担当範囲は[計画のL2a](../plan.md#作業-l2a-補間の型付け脱糖と型保存)である。型付け・脱糖・型保存・範囲と捕捉、および既定ビルドを維持するための全読者の追随を完了した。計画で指定した一時拒否を残し、取りまとめの独立レビューへ渡す。この結果は段Iの完了やF1以降の開始条件には数えない。

## 実行した検査

局所ビルドはすべてリポジトリの `formal/` 内で実行した。作業末の本実行は一回であり、結果の引用によって省いた検査はない。

| コマンド | 終了状態 | 外側の時間 | 結果・修正 |
|---|---|---|---|
| `rtk proxy lake build Benitoite.Surface.Lemmas.Extensions Benitoite.Surface.Lemmas.ExtensionsScoped Benitoite.Surface.Lemmas.BuilderCaptureCompose Benitoite.Surface.CheckLemmas Benitoite.Surface.CheckPredicates`（初回） | 1 | 未計測 | `interpAllowed_sound` の式形式の分岐に `by` がなく、Boolの補題名も誤っていた。`by` と `Bool.and_eq_true_iff` へ修正した。非推奨の `dif_pos` も `dite_eq_left` へ替えた |
| 同コマンド（修正後） | 0 | 未計測 | 107ジョブが成功。型保存・範囲保存・捕捉と原子集合の補題が新構成を扱う |
| `rtk proxy lake build Benitoite.Surface.CheckExamples`（初回から3回目） | 各1 | 未計測 | 新しい型判断の具体例で、命題を展開する前のDecidable合成、`fnTy` の空エフェクトの具体化、期待する拒否理由の字句に誤りがあった。定義を展開して証拠を作り、`Eff.substAt_ofAtoms` で空エフェクトを明示的に書き換えた。拒否理由は既存checkerの文字列に合わせた。脱糖の独立した期待コアは初回から一致した |
| 同コマンド（修正後、4回目） | 0 | 未計測 | 93ジョブが成功。新しい4例は補間全体の型判断、同じ入力へのcheckerの一時拒否、Stringの整形呼び出しと七定数、混在する部分の評価・変換・連結と束縛下の番号を検査する |
| `rtk proxy scripts/check.sh --level work --base 56e0ebc5ffcefe5d4e48a14671a6c33ae4109828 --dry-run` | 0 | 未計測 | 変更14ファイルからspec_tally・spec_examples・formal_buildを選択。Rustの全libは選択しない |
| `rtk proxy /usr/bin/time -p scripts/check.sh --level work --base 56e0ebc5ffcefe5d4e48a14671a6c33ae4109828` | 0 | 67.14秒 | 仕様集計の自己検査と集計が成功し、未記入の初回リリース完了条件なし。仕様例7件が成功（テスト本体3.55秒）。既定lake buildとsorry拒否が成功し、最後の出力は `selected checks passed` |
| `rtk proxy python3 -B -`（文書・変更範囲を読む標準入力スクリプト） | 0 | 0.205秒 | 両設計章の既存見出しとtextフェンスが基準版と同じで、相対リンクの参照先が存在し、フェンスが閉じていることを確認。変更14ファイルはL2aの範囲内であり、主定理・検査の健全性と計算可能性・Builtins.Assumptionsのファイルは基準から同一。差分に公理・sorry・admitの追加なし |
| `rtk proxy git diff --check` | 0 | 未計測 | 空白の誤りなし |
| `rtk proxy python3 -B -`（結果記録後の確認） | 0 | 未計測 | 変更14ファイルと新規の本結果記録だけであること、HEADが基準と同じであること、結果記録を含む相対リンク・見出しへのリンク・末尾空白を確認。diffの空白検査も成功 |

文書を編集するための標準入力Pythonの一回は、UTF-8のソースとして読めず構文解析で終了1になった。この実行によるファイルの変更はなく、apply_patchと文字コードを明記した短いPythonへ分けて反映した。これは検査の成功には数えていない。局所ビルド中の失敗はすべて作業末の本実行前に修正した。

## 計画からのずれと申し送り

計画からの範囲のずれ、言語の規則の追加判断、主定理の前提・結論の変更、公理・Builtins.Assumptionsの追加はない。Rust・交換形式・実際の組み込み表は変更していない。設計書01-12の型付けと「文字列補間」、07-04「01-12 との対応」へ、完成した定義・証明と一時拒否の状態を反映した。新しい表層構文のtextフェンスと期待する失敗への一時登録は加えていない。

L2bへ渡す内部契約と補題は次のとおりである。

- `InterpPart.formatted ty spec` は式と頭を一つずつ消費する。`exprTypes` はty、`converterTypes` は `FormatSpec.converterType ty` を加え、`Allowed` は `spec.Valid ty` を要求する。`count` は既存の非textの場合によって一つと数える。
- `FormatSpec.arguments spec` は、構文の妥当性を満たす場合にL1の七定数を `Val.const` へ写す。構文が不正な場合の空列は関数の全域化のためであり、型判断の `Allowed` からは到達しない。`FormatSpec.arguments_typed` は妥当性から `FormatSpec.constantTypes` の型付けを与える。`arguments_scoped`・`arguments_captures` はすべての書式について成立する。
- `StrHeadsTyped` と `directHeads_typed`・`converterTypes_fn` の補助の言明を、一引数に限定した形から、任意の契約名・引数列を持つ純粋なStringへの頭に一般化した。補間の具体的な契約は `converterTypes` が引き続き固定する。`interpolate_typed` は追加の `InterpPart.Allowed parts` を受け取り、`HasTypeQ.desugar` の既存のE_Interpolationの前提から渡す。公開の主定理の前提は増やしていない。
- `interpolate` の新分岐は、評価済みの値と七定数を頭へ渡すletを作り、その下へ残りの値・頭・蓄積した文字列の番号を一つずらす。全式の先行評価は既存の `sequence` が担う。`interpolate_typed`・`interpolate_scoped`・`interpolate_captures` を接続した。BuilderFreeの定義とその読者は既存の子の式・頭の列の検査で足り、変更不要であった。
- `InterpParts.AtomsIn` はconvertedだけでなくformattedの型も対象とする。`interpolation_types_atoms` は書式の七定数型を含む期待型の原子集合を与える。この補題を使う `interpolation_case`・`computes_interpolation` は新しい構成でも成立する。後者はソースの変更を要しなかった。

一時防御の除去はL2bの担当である。位置と除去時の対応は次のとおりである。

1. `Surface/CheckPredicates.lean` の `interpAllowed` の `.formatted _ _ :: _ => false` を、`formatValid ty spec` と残りの部分の判定に替える。
2. 旧 `interpAllowed_spec` の同値は一時拒否と一致しなくなるため、本作業では一方向の補助定理 `interpAllowed_sound` に替えた。L2bでは受理する判定との同値を証明し、必要なら `interpAllowed_spec` を戻す。`CheckSoundCollections.lean` の呼び出しは現在 `interpAllowed_sound` を使う。
3. `CheckExamples.lean` の `FormattedInterpolation` 内の一時拒否の例を、受理の例へ更新する。同じ名前空間の型判断と独立期待コアの例は、拒否だけではない接続を確認しているので維持する。全14型と不適合・不正指定・間接または非純粋な頭の正負例はL2bの割り当てである。
4. 01-12・07-04の一時拒否と未接続の説明を、その時点の実装へ合わせる。L3で交換・組み込み宣言の照合、F5と最後の関係状態でRustとの全比較を行う。本作業の既定ビルドの成功をそれらの成功とは扱わない。

テスト追加の作成時の関門では、型判断・checker・脱糖の公開境界で、Stringを素通しする誤り、固定引数の欠落・順序・省略精度の誤り、全式評価より早い変換、束縛下の番号の誤りを対象にした。既存例はformattedを持たず、これらの新分岐を検査できない。期待コアは符号化・脱糖の補助関数から生成せず、独立した定数とコアの構成で記した。新しい本番用の差し込み口はない。テストの削除・緩和はない。Leanの本番・証明は追加114行・削除26行、具体例は追加74行・削除0行である。

独立レビューと受け入れは取りまとめがL2b起動前に行う。gitの変更操作、privateの読み書き、docs/todoの更新、測定・LLM評価・公開操作は行っていない。
