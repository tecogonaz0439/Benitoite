# L6c2の実装結果

2026-10-18、Codex。L6の続行L6c2は完了した。前回のl6/results.mdに残した全体の捕捉禁止を閉じ、計画のL6の完了条件を満たす。開始版B_WORKと対象HEADは `f8ee6c5e4eb24fdddf7ecde5290efce9e50d24e5` で、開始時の作業ツリーはクリーンだった。L6の最初の開始版は前回記録の `d0e4f09b86c0d8170e7c6f2c0f4117bd7609b26b` である。コミットとdocs/todo/の変更は行っていない。

## 変更

- `BuilderCaptureCompose.lean`を追加した。letChain/sequence/callComp、辞書と直接の頭、レコードの構築と更新、展開、文字列補間、専用操作を、実際のコアのCapturesへ合成する。liftReadsの加法則で追加のletを数える。
- `BuilderNoCapture.lean`を追加した。式・Types・Each・Arms・Blockの捕捉保存を、任意のpvとEnvReads pv Γについて相互帰納で証明した。HoleArgsの固定式と穴も接続した。式の保存を仮定として受ける旧HasBlockQ.captures_of_exprは、仮定なしのHasBlockQ.capturesへ置き換えた。
- `builders_no_capture`と`builders_block_no_capture`は、任意の整列したΓ・Δについて、実際の脱糖の全体にCaptures (fun i => Δ.kindAt i = none)を結論する。局所宣言の後続の部分導出にも、その場所の非空Δで適用できる。lambda/lazy/部分適用と通常節・Fail節は、空Δでの型保存とnoneの不参照を使う。通常の式の子は同じΔで帰納する。宣言の後続にも直接帰納する。
- `Benitoite.lean`と`BuilderExamples.lean`から正式importした。既定ビルドの外へ分けた証明や未ビルド差分はない。
- `BuilderExamples.lean`へ4個のexampleを追加した。通常のセル利用、lambda/lazy/部分適用のcallee・固定引数の捕捉の拒否、先行copyの通常値の捕捉、Fail節の二位置を数えることを、非空の外側のセル位置を除外するコアの述語で確認する。既存27個のexampleと期待値はそのままで、合計31個となった。
- 01-12・07-04へ閉じた定理を写し、古い「専用宣言の型保存・コアの捕捉禁止を含まない」という中間状態の一文を更新した。formal/READMEの公理検査へ捕捉2件とordinary_resultを追加した。planのL6の続行ID・基準・検査の欄を具体化し、R154へ補助の配置と相互帰納の判断を記録した。

規則・既定分岐を含む読者の対応、共通の関門K、test-auditの四問は[rule-review.md](rule-review.md)にある。形式化の証明・入口の差分は追加678行・削除63行、新しい証明二ファイルを含む。BuilderExamplesは追加28行・削除1行で、削除はimport先の置き換えだけである。既存のassert削除・期待値の緩和・ignore追加は0件。Rustの処理系とRustテストの差分は0行である。

## 契約と公理の照合

[contracts-comparison.json](contracts-comparison.json)は、開始版に対して、公開の健全性11件・program・性質1と表層のエフェクト健全性、Input.Sound/WellTyped/WellFormed、七判断、checker、Releaseの型/効果/遷移とBuiltins.Assumptionsを含む110ファイルがバイト単位で同一であることを記録する。Reads/Capturesの定義と既存の全具体例も保った。主定理の前提/結論、公開の保証範囲、公理や仮定を変更していない。

[READMEの全33件の出力](axioms.txt)と[内部補題26件の出力](internal-axioms.txt)は、propext・Classical.choice・Quot.soundだけに依存する。sorryAx・Lean.ofReduceBool・独自公理はない。READMEの入力と[axioms.lean](axioms.lean)は一致し、従来の30件の出力は前回l6/axioms.txtとバイト単位で一致した。[比較の要約](axioms-comparison.json)と[確認した関係入力のハッシュ](verified-inputs.json)を保存した。今回の検査はすべて現在の関係状態で実行しており、前回のビルドや仕様例の成功の引用で代用していない。

## 検査

作業末は計画の三単位をdry-runで確認し、一度実行した。Dは本改造のディレクトリである。完全な引数・cwd・終了状態・外側の時間は[check-times.json](check-times.json)にある。

| コマンド | 終了状態 | 外側の時間 | 記録 |
|---|---|---|---|
| `scripts/check.sh --level work --base f8ee6c5e4eb24fdddf7ecde5290efce9e50d24e5 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.010秒 | [work-dry-run.txt](work-dry-run.txt) |
| `scripts/check.sh --level work --base f8ee6c5e4eb24fdddf7ecde5290efce9e50d24e5 --only formal_build,spec_examples,spec_tally` | 0 | 8.194秒 | [work.txt](work.txt) |
| `lake env lean <D>/l6c2/axioms.lean` | 0 | 0.723秒 | [axioms.txt](axioms.txt) |
| `lake env lean <D>/l6c2/internal-axioms.lean` | 0 | 0.728秒 | [internal-axioms.txt](internal-axioms.txt) |

formal_buildは既定の全体lake buildとsorryの拒否に成功した。spec_examplesは7件成功・失敗0・ignore0、spec_tallyは自己検査と集計に成功し、初回リリース版の完了条件の未記入は0件だった。spec_tallyのテスト参照のない節の一覧はwork.txtにそのまま残す。今回の追加のLean具体例は既定ビルドに含まれる。

途中はBuilderCaptureCompose/BuilderNoCapture/BuilderExamplesの変更したモジュールだけをlake buildした。途中の外側の時間は集計していない。Leanの照合・定義の展開不足、暗黙の型や式の推論、束縛数の自然数の正規化、相互帰納での変数の共有を修正した。主定理や既存のテストを弱めて通した箇所はない。初期のlake呼び出しはリポジトリの根をcwdにして失敗したため、以後はformal/をcwdに固定した。照合補助のProgram.leanのパスもLemmas/Program.leanへ直した。作業末の四コマンドはすべて初回の実行で成功した。

Rustを変えていないため、Rustの全lib・追加の統合・clippy・fmt・gc-stress・all-targetsは実行していない。check.sh全体とcheck-formal.sh全比較も実行していない。構文の章・標準ソース・診断表は変えていないのでgen_skillの再生成は不要である。

## 計画からのずれと申し送り

計画の実装範囲と保証に変更はない。依頼のL6c2という名前は元のplanでは独立の作業になっていなかったため、L6の残りを閉じる続行として、現在の開始版と同じ指定検査を追記した。R154は証明の分割・配置と補助の置き換えを具体化したものであり、設計者への相談を要する主定理・公理・Builtins.Assumptionsの変更はない。

L7へ進める。交換版12・独立入力、Rustとの新構文の接続と全形式化比較、RV2の独立レビューと受け入れは後続の担当である。既存の継続・Reference・Stateの規則は変えていない。追加の捕捉定理は、その場所のΓ・Δで部分導出へ適用し、公開入口が空Δという理由だけで捕捉禁止の確認を済ませない。
