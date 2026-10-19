# L2 実装結果

2026-10-18、Codex。作業L2を完了した。Rustと標準の`.bnt`との接続は未実施であり、M1へ渡す。

## 基準と変更

- B_WORK・開始時HEAD: `6238140aaf5b9886447455f3009272e1aa7adb04`。L1の取り込み済みの版。ブランチは`mod009/L2`、開始時の作業ツリーはクリーンだった。
- `formal/Benitoite/Library/ResultLaws.lean`: 成功型が先のResult、map/pure/apply/flatMap、三法則とmapの二法則、map/applyとflatMapの一致、関数側のError優先、三辞書と上位射影、型だけでは単位則が得られない反例。公開の定理12件。
- `formal/Benitoite/Surface/Monad2Examples.lean`: 実際の三クラスの署名、ResultとUserResultの六実装、F: Monad2を受けて上位のmapを呼ぶ関数。Ty.WF/SatAllと対象辞書、全プログラム検査、実名一致、型付け、範囲条件、性質1、前置辞書とmap/flatMapの値化を閉じた。両型各12件の入力の検査とコア実行、Xの不一致と別の型の辞書の拒否を含む。公開の定理15件。
- `formal/Benitoite.lean`へ二モジュールをimportした。01-12に定義と保証の写し、07-04に小モデルと本体判断の区別と対応表を加えた。既存の見出しは変えていない。
- R146へ本体例の具体化を記録し、M1の照合用の[独立期待値](correspondence.md)を固定した。

## 検査と結果

最終検査のコマンド・終了状態・外側の実測時間は[check-times.json](check-times.json)、出力は[work-dry-run.txt](work-dry-run.txt)・[work.txt](work.txt)に保存した。workは最後に一度だけ実行した。

| 検査 | 終了状態・外側の時間 | 結果 |
|---|---|---|
| 局所の `rtk proxy lake env lean Benitoite/Library/ResultLaws.lean` と `rtk proxy lake env lean Benitoite/Surface/Monad2Examples.lean`（formal/） | 最終0、途中の外側の時間は未集計 | 対象モジュールだけを確認。途中の失敗と修正は下記 |
| `scripts/check.sh --level work --base 6238140aaf5b9886447455f3009272e1aa7adb04 --only formal_build,spec_examples,spec_tally --dry-run` | 0、0.010秒 | 指定した三単位だけを選択 |
| 同じ指定から`--dry-run`を除いたwork | 0、12.311秒 | spec_tallyの自己検査と集計、spec_examples 7件成功・失敗0・ignore 0、既定のlake build成功・sorryなし |
| `lake env lean ../docs/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/l2/axioms.lean`（formal/） | 0、0.735秒 | READMEの既存30件。[出力](axioms.txt)はL1のaxioms-before.txtとaxioms-after.txtにバイト単位で一致 |
| 同じディレクトリの`new-axioms.lean`を`lake env lean`で検査（formal/） | 0、0.730秒 | [新規27定理](new-axioms.txt)。ResultLawsの12件は公理依存なし、本体例の15件は標準三公理だけ。sorryAx・Lean.ofReduceBoolなし |
| `git diff --check`、新規ソースのsorry/axiom/native_decide不在、写し・新見出しとコメントの対応 | 0 | 差分に問題なし。既存の主定理とその前提の定義は変更なし |

局所の失敗は、作業ディレクトリを取り違えたファイルパス、任意のXの値を要求する不適切な反例案、暗黙のXの未指定、lookup/mapの表現の違い、場合分けとsimpの不足、利用できないaesopによるものである。反例を二引数の定数型に直し、表の有限の所属と本体の番号・原子の条件を明示的に証明した。最終のモジュール確認とworkは成功した。既存の例・assert・期待値の変更や弱化、ignoreの追加はない。

spec_tallyは新節を他の01-12の節と同様に「テスト参照なし」と表示するが終了0である。新しい契約の所有元であるLeanの定理と本体の検査・実行例で確認し、Rustのspec印だけを足すことはしていない。Rustの変更がないため、lib全件・clippy・fmt、全統合・特殊構成・check-formal全体は実行していない。

## 共通の関門・計画からのずれ

- K契約/K接続: 成功型が先、Xの共通性、applyのError優先、契約名、辞書の順と上位射影・値化を保つ。実装の型付けを変換後の型検査だけで代用せず、全プログラムの検査成功から既存の健全性定理を使って表層の型付けを得て、性質1へ接続した。
- K形式化: Core・Release・Surfaceの既存規則・公開11件とprogram・WellTyped/WellFormed/Input.Sound・Builtins.Assumptionsは変更していない。主定理の前提・結論・保証対象も変わらない。既定の全体ビルドと公理比較を完了した。
- K文書: ResultLawsは主定理の外の小証明、Monad2Examplesは本体の判断へ接続する具体例として写した。Rust/.bntとの一致やkind検査の証明とは呼ばない。構文の章・標準ソース・診断表は変えていないためgen_skillの再生成は不要。
- K安全点/K性能/K境界: Rust・VM・GC・測定、公開境界・Scope・Rangeの意味は変更対象にしていない。
- 計画との実質的なずれはない。未指定だった宣言表・利用者型・反例をR146の推す案として具体化した。本体例はmap/flatMapの意味を分岐で直接書き、標準関数の信頼する署名を増やさない。M1の標準実装の委譲はdesign 6.1を保つ。
- R142のTy.WF/SatAllの区切りは既存規則だけで閉じた。続く宣言・辞書・実行も同じ規則で閉じられたため、追加の作業・相談や見込みの拡張は不要だった。
- test-auditの四問: 守る契約は二引数辞書の型・上位射影・捕捉と成功/失敗の結果、関数側のError優先である。現実的な退行は型引数や辞書番号の取り違え、失敗型の暗黙の混同、applyの優先順の逆転である。既存の例には二引数クラスがなく、新しい入力を本体の公開の検査・脱糖・実行へ通す必要があった。両型は同じ準備と表を共有し、期待値は対象の処理から作らない。本番の公開範囲の拡大や差し込み口は追加していない。既存テストの変更・削除は0件である。

## 後の作業への申し送り

次は計画どおりL3。二モジュールは既定のimportに含まれ、後続のSurfaceの変更でも全体ビルドを保つこと。R138の公理比較には[axioms.lean](axioms.lean)と[axioms.txt](axioms.txt)を使える。

M1は[correspondence.md](correspondence.md)の両型各12件と拒否入力を、実ソースから辞書の脱糖・VM・局所交換へ通す。コールバック0/1回と引数式のソース順は観察可能な効果で別に確かめる。L2の純粋な例だけを、その回数・評価順やkind検査の保証として引用しない。全形式化比較はL7と改造末の割り当てへ残す。

コミット、取り込み、docs/todoの変更は行っていない。
