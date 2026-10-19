# L1 実装結果

2026-10-18、Codex。作業L1を完了した。Rustとの接続は未実施であり、K1・K3・K4へ渡す。

## 基準と変更

- B_WORK: `8f4bfce16dbfa08f8f3a61e1b0c504e94857d0d3`。
- 開始時HEAD: `90fca33cf245063389a82c8d1aa8a81c65ac471d`、ブランチ `mod009/L1`。B_WORKからHEADまではP2の6文書だけ、B_CHANGE `6b0568a3ddcc46b0a0e64504139ce286a27fd86a`からHEADまでは改造の文書だけであり、処理系差分がないことを確認した。開始時の作業ツリーはクリーンだった。
- `formal/Benitoite/Checked/Access.lean`: 所有元比較、別名による所有元・境界の保存、通常値と内部表現の操作の区別。
- `formal/Benitoite/Checked/Scope.lean`: 解析済み入力の妥当性、exact/one/manyとpath exact/tree、Intのポート、成功・失敗・入力保存・射影・証拠消去、別条件への適合が型名から導けない反例。
- `formal/Benitoite/Checked/Range.lean`: 閉区間、逆転／範囲外の二つの失敗、三入力と射影の保存、証拠消去、一点区間と最小／最大Integerの端点。
- `formal/Benitoite.lean`へ三モジュールをimportした。新規の名前付き定理42件、`example` 17件を既定ビルドに含めた。
- 01-12に定義・言明・保証の範囲を写し、07-04の対応表へ独立小証明として追加した。既存の見出しは変えていない。

## 検査と結果

最終検査の具体的なコマンド・終了状態・外側の実測時間は[check-times.json](check-times.json)、出力は[work-dry-run.txt](work-dry-run.txt)・[work.txt](work.txt)に保存した。workは最後に一度だけ実行した。

| 検査 | 終了状態・外側の時間 | 結果 |
|---|---|---|
| 変更前に `formal/` で `lake env lean ../docs/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/l1/axioms.lean` | 0、1.806秒 | READMEの#print axioms一覧30件を[axioms-before.txt](axioms-before.txt)へ固定 |
| 局所の `rtk proxy lake env lean Benitoite/Checked/Access.lean` | 0、0.312秒 | 定義・定理と具体例が通る |
| 局所の `rtk proxy lake env lean Benitoite/Checked/Range.lean` | 順に1/1/0、0.216/0.306/0.290秒 | 証明の分岐処理と計算による具体例を修正し、最終成功 |
| 局所の `rtk proxy lake env lean Benitoite/Checked/Scope.lean` | 順に1/0/1/0、0.693/0.667/0.798/0.798秒 | 構造体の欄名・分岐処理と、カーネルで簡約できるラベル検査へ修正し、最終成功 |
| `scripts/check.sh --level work --base 8f4bfce16dbfa08f8f3a61e1b0c504e94857d0d3 --only formal_build,spec_examples,spec_tally --dry-run` | 0、0.011秒 | 指定した三単位だけを選択 |
| 同じ指定から `--dry-run` を除いたwork | 0、12.855秒 | spec_tallyの自己検査と集計、spec_examples 7件成功・失敗0・ignore 0、既定のlake build成功・sorryなし |
| 変更後の同じ `lake env lean …/l1/axioms.lean` | 0、0.707秒 | [axioms-after.txt](axioms-after.txt)は変更前とバイト単位で一致 |
| `formal/` で `lake env lean ../docs/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/l1/checked-axioms.lean` | 0、0.622秒 | [新規42定理の公理依存](checked-axioms.txt)は標準のpropext・Classical.choice・Quot.soundの範囲。sorryAxなし |
| `git diff --check`、新見出しと三モジュールのコメントの対応、新規ソースのsorry/axiom/native_decide不在 | 0 | 差分と写しの対応に問題なし |

局所確認の失敗は、`split`を矛盾分岐に適用したこと、等式の除去後に消えた変数を使ったこと、予約語 `matches` を欄名にしたこと、Except全体の等値のDecidableを要求したこと、String.startsWith/endsWithがカーネルで簡約できなかったことによる。欄名と証明を直し、ラベルの先頭末尾の検査を文字列の文字列挙のhead?/getLast?で表した。既存の例・assert・期待値の変更や弱化、ignoreの追加はない。

spec_tallyは01-12の他の多くの節と同様、新節を「テスト参照なし」と表示するが終了0である。小モデルの所有元の境界であるLean定理と具体例で確認し、Rustのspec印を形式的に追加していない。Rustは変更していないため、lib全件・clippy・fmtや全統合・特殊構成・check-formal全体は実行していない。

## 共通の関門・計画からのずれ

- K契約／K境界: ホスト一段と多段、根を含むパスtree、閉じたポート0〜65535、失敗の優先順、全保存欄を維持した。Rangeの定数Errorを静的拒否へ変えていない。操作の許可やIOの成功を結論しない。
- K形式化／K接続: Core・Release・Surface・Exchangeの既存定義・定理・Builtins.Assumptionsは変更していない。Ty/Eff/Step、主定理の前提と結論、WellTyped/WellFormed/Input.Soundの定義を通じた意味も変えていない。READMEの30件の公理依存は開始前と同じである。
- K文書: 01-12と07-04へ、独立小証明であることとparser・Rust/.bntとの未接続を明記した。構文の章・標準ソース・診断表は変更していないため、gen_skillの再生成は不要。
- K安全点／K性能: Rust・VM・GCや性能測定は変更対象にしていない。
- インターフェースの未指定部分を[R145](../decisions.md#r145-l1の解析済み入力と失敗の表現2026-10-18実装時の具体化)に採る案として記録した。任意の解析済み入力をmakeで妥当性検査し、成功値にその証拠を持たせた。失敗は解析済みパターン・対象を保存し、元の字面とreasonはparser側へ残す。作業範囲・保証・最終検査の割り当ては変えていない。
- test-auditの作成時の四問: 守る契約は公開境界、所属の境界、失敗順、端点と保存である。捕まえる誤りは一段を多段として扱うこと、パスの文字列前方一致、根の拒否、負数portの見落とし、逆転と所属の失敗順の逆転、閉区間の上端の除外である。新しいモデルなので既存のテストはこれらの関数を通らず、独立期待値を小モデルの入口に置いた。Rustの公開範囲の拡大やテスト用の差し込み口は加えていない。既存テストの削除・変更は0件。

## 後の作業への申し送り

- 次は計画どおりL2。ここで追加した三モジュールはStdだけに依存し、本体の形式化を前提にしない。既存定理の同じ公理比較には[axioms.lean](axioms.lean)と変更前出力を使える。
- K1はAccessのownerを実際の解決済み宣言元へ接続する。K3/K4は[correspondence.md](correspondence.md)の独立期待値により、parserの正規化結果・パターンの形・保存欄・失敗順・各射影を照合する。元の字面・reasonと大文字の正規化は小モデルで証明していない。Rangeでは三入力の符号付き64ビット表現可能性を明示する。
- 小証明の成功はRust/.bntとの対応やcheck-formal全比較の成功ではない。段1の残りとRV2を閉じてからRustへ進む。
- コミット、取り込み、docs/todoの変更は行っていない。
