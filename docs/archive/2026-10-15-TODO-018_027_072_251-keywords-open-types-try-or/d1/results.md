# D1 Coverage view と将来の形の準備

## 実装前の定義・言明の自己確認

設計の「形式化と受け渡し」、R9・R10、P2 の定理対応表を、現在の Coverage と照合した。D1 では `CoverageView := DataName → Bool` と全て false の `closedView`、`Shape.future d`・`CoverageWitness.future d`、既存の `shapes` に追加する `shapesWithView` を用意する。現在の呼び出しは切り替えない。

証明する言明は、閉じた view の列挙が既存の列挙と等しいこと、任意の view で既存の形と現在の値の特殊化の証拠が残ること、将来の形を特殊化できるのは変数と `_` だけであることとする。`CtorsComplete`・`Inhabits`・`Exhaustive`、補題 U と既存の健全性定理の前提・結論は変更しない。将来の形を実在の値とする `Represents` の場合も追加しない。これは新しい外部仮定を要しない保存補題の追加であり、現在の値についての保証を保つ。

表示は既存の ConName 表を残し、DataName から型名と record の印を引く表を別に受け取る入口を追加する。旧入口は型表示表を空にして委譲し、既存の反例の表示を保つ。型名は表示表から引き、構成子名や型引数から作らない。

この確認は実装者の自己確認である。07-04 所定の Claude Code による定義・言明のレビューと設計者との合意を代替しない。レビューへ渡す具体的な定義・言明をこの変更で用意し、G2 へ申し送る。

## test-audit の作成時の関門

1. 主となる境界は Lean の形の列挙・特殊化と反例表示である。既知の形の保存は一般の補題で、将来の形の拒否と包括的なパターンの受理、入れ子の表示は評価できる独立例で確かめる。
2. 捕まえる退行は、future の追加で既知の構成子が消えること、既知の構成子や record のパターンで future を覆うこと、型ごとの指定の混同、入れ子で型の出どころや record の区別を失うことである。
3. 既存の CoverageExamples と CoverageShow の例を拡張する。既存の例には view と future がない。保存の一般命題と具体的な表示の期待値は異なる契約であり、同じ検査を Rust 側へ重ねない。
4. Rust の公開範囲・フラグ・テスト専用の差し込み口は増やさない。新しい Lean の入口は後続の判定と交換形式への接続に使うためのものである。

Lean の変更は機能の先行追加であり、既存の不具合の修正ではない。既存の assert・Lean の評価例の期待値・ignore・対象外理由は変更しない。診断の仕様変更もない。検査の manifest の補正は、次節の R26 の一件に限る。

## 変更の範囲

形式化の最終検査の失敗を受け、二つの manifest に既存の `older-language` の負の入力を追加する（R26）。追加前の作成時の関門への回答は次のとおりである。守る契約は、全 golden 入力の識別子と分類理由が交換出力に完全一致すること。捕まえる退行は、旧言語版の E0908 を読み飛ばす、または別の理由へ置き換えることである。既存の一覧にはこの一件がなく、既存の checker の完全一致が実際に失敗したため、その一覧を拡張する。公開の入口・フラグ・差し込み口は追加しない。期待する E0908 は既存の `.diag.json` から独立に確認し、実測値から一覧全体を再生成しない。

開始時の HEAD は `dc2c15a17fa99bba8f12e93bcc46c780254cfa88`、作業ツリーは clean だった。

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Release/Coverage.lean` | view、future、列挙の補助と保存補題、既存の評価例の拡張。元の shapes と判定の呼び出しは維持 |
| `formal/Benitoite/Release/CoverageShow.lean` | DataName ごとの表示表を受け取る表示入口と独立の期待文字列。旧入口と既存の期待値を維持 |
| `docs/design/01-spec/01-12-core-calculus.md`、`02-impl/02-05-typechecker.md`、`07-quality/07-04-formal-semantics.md` | 先行モデルの規則・保存する性質・未接続の範囲の写し |
| `p2/formal.md`、この記録 | 実際の定義名・定理名との対応、作成時の関門、検査の結果と申し送り |
| `crates/benitoite/tests/desugar_export/{exchange-manifest,routing-manifest}.json` | R26 の旧言語版の負の入力一件と厳密な分類を追加。既存の受理件数と全行を維持 |

Rust の実装、構文の章、標準ライブラリ、診断の表、交換形式、docs/todo/ は変更していない。Skill の再生成を要する生成元の変更はない。コミットは行っていない。

## 検査

実行前にコマンドと形式化の検査の見込みの時間を報告した。コマンドは rtk を経由した。依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成の検査は実行していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,156 passed、既存の ignored 21、99.27 秒 |
| `cargo test -p benitoite --test spec_examples --test skill_docs` | 成功。15 passed、2 suites、4.65 秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `formal/` で `lake build` | 成功。159 jobs。最終の Lean のツリーでも check-formal の先頭で再実行し、83 秒で成功 |
| `bash scripts/check-formal.sh` | 初回は R26 の manifest の欠落を検出して終了状態 1。補正後に全体を再実行し、終了状態 0 で成功。coverage_export 2 件、desugar_export 15 件、Python 4＋12 検査を含む |
| `python3 -I crates/benitoite/tests/desugar_export/check_named.py target/desugar-diff/run-43554 target/coverage-diff/run-43554` | 成功。初回の同じ出力について最終段を再実行し、六入口・全件の分類・15 件の破損入力の拒否を確認 |
| `git diff --check` | 成功 |

`lake env lean` の最初の確認では、新しい評価例の `by decide` が `Pat` の DecidableEq を合成できず失敗した。命題と期待値は変えず、定義による簡約の証明 `by rfl` に直した。これは形式化の表現の都合であり、規則や定理の弱化ではない。

追加した五補題と、既存の `usefulFuel_none_sound`・`useful_none_sound`・`checkMatch_exhaustive_sound`・`irrefutable_sound`・`checkMatch_unreachable_sound` は `#print axioms` で確認した。列挙の一致・包含と特殊化の補題は `propext` だけ、現在の値の保存補題と既存の健全性定理は従来どおり `propext`・`Classical.choice`・`Quot.sound` だけに依存する。追加の axiom・sorry・admit・native_decide はない。

### 六入口の件数と分類

初回の出力は `target/desugar-diff/run-43554/` と `target/coverage-diff/run-43554/` にある。manifest の一件を補正した後、最終段を再実行し、さらに全体を再実行して以下の値と分類理由を完全一致で確認した。全体の再実行の出力は `target/desugar-diff/run-46305/` と `target/coverage-diff/run-46305/`、ログは `target/desugar-diff/run-46305/d1-check-formal.log` に保持する。corpus・型表・網羅性の版は 8/2/2 のままである。

| 入口 | 確認した結果 |
|---|---|
| desugarDiff | golden の定義 955 と random の定義 72,778、合計 73,733 が一致。定義の mismatched/outside/excluded は 0。プログラムは golden matched 346・excluded 381、random matched 1,000・excluded 0 |
| builtinCheck | 対象 1,346 プログラム、primitive の比較 72,316、不一致・非収束 0。全 1,727 入力の識別子と除外理由の対応を最終段で確認 |
| coverageDiff | 境界 20＋random 10,000＝10,020 件、named の独立入力 2 件が一致。不一致・燃料切れ 0 |
| coverageProgramDiff | match 16,405＋binding 6,033＝22,438 件が一致。不一致・対象外・燃料切れ 0 |
| surfaceCheck | 全対象入力を単独の入口でも検査。旧来の個別の失敗は manifest の理由との完全一致を維持。named の独立入力の定義数 1・2・5・3・1・2・1 も維持 |
| surfaceCheckAll | 検査 51,656、matched 51,636・outOfScope 19・q11 1。不一致・準備の失敗・lazyRestriction 0 |

新しい対象外理由は作っていない。R26 の一件は既存の E0908 の負の入力を一覧に加えたもので、受理された定義を対象外へ移していない。`outOfScope` と q11 の各入力・定義・理由は、既存の `programReports.surfaceOutcomes` と完全一致している。builtinCheck の未変換の opaque 引数は既存の `Task.await`・`TaskGroup.spawn` の二つのままである。

幅付きの交換形式の Python 4 検査と契約名の 12 検査が成功した。最終段では契約の破損 3 件、hole/pipe の破損 6 件、named export の破損 6 件をそれぞれ意図した理由で拒否した。既存の破損入力の検査を一つも減らしていない。

## 計画との差と申し送り

処理系の実装・規則・公開の受け渡しに計画との差はない。予定外の二つの manifest の補正は R26 に記録した。外部レビューを証明より先に行うという順序については未充足であり、R25 に推す案として記録した。D2a では `shapesWithView` とその保存補題を有用性の再帰へ接続し、D2b 以降で本体の view を表層の受理条件へ渡す。D3 で DataName の表示表を交換形式の必須情報にする。旧表示入口の空の型表示表を、新版の情報の欠落を補う用途に使わない。

定義・言明の外部レビューと設計者との合意はこの記録の自己確認とは別であり、オーケストレータへ申し送る。処理系の意味変更へ進む前に所定のレビューを済ませる。`scripts/check.sh` と gc-stress は依頼どおりオーケストレータが最後に実行する。
