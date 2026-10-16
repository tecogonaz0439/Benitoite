# D2a Release の view 付き判定と健全性

## 実装前の定義・言明の自己確認

設計の「形式化と受け渡し」、R9・R10 と D1 の保存補題を確認した。`usefulFuelWithView` の全再帰で同じ view を渡し、構成子の列挙に `shapesWithView` を使う。網羅性・束縛・選ばれない選択肢・覆っている選択肢の説明も同じ view を使う。既存の入口は `closedView` を渡す互換ラッパーにする。Surface の宣言表と Exchange はまだ切り替えない。

任意の view と燃料について補題 U を示し、現在の値についての `Exhaustive` と到達不能の健全性を導く。`shapesWithView_cover` によって現在の値に対応する形は残るため、`CtorsComplete` の前提を変えず、将来の形を実在の値とする仮定は追加しない。`SlotsOk` を要求する実行時の系も同じ結論へ接続する。燃料の計算と、燃料切れ・不整合では有用と答える契約は保つ。

これは実装者の自己確認である。所定の定義・言明の外部レビューと設計者の合意を代替しない。今回の未接続の差分をレビュー可能な形で渡す扱いは R27 に記す。

## test-audit の作成時の関門

1. 主となる境界は Release の公開判定 `checkMatchWithView`・`irrefutableWithView`・燃料付き有用性である。型ごとの指定を再帰全体で共有し、現在の値についての健全性を守る。
2. 捕まえる退行は、全既知構成子で将来の形まで覆うこと、構成子の欄・リスト・全ワイルドカードの列を落とす再帰で view を落とすこと、全既知構成子の後の包括的な分岐を誤って到達不能とすること、guard を網羅性に数えること、単一構成子の束縛を外部でも受理すること、燃料切れを網羅とすることである。
3. 既存の `CoverageExamples` の表を拡張する。旧入口の例には view がなく、D1 の例は列挙・特殊化だけなので再帰への渡し忘れを検出できない。既存の例と期待値を維持し、現在の値の一般的な保証は定理で証明する。
4. Rust の公開範囲・フラグ・テスト専用の差し込み口は追加しない。Lean の view 付き入口は後続の Surface と交換形式が使うためのものである。

機能の先行実装であり、不具合の修正ではない。診断の仕様変更はなく、既存の assert・期待値・ignore・対象外理由を変更しない。

## 変更の範囲と自己確認

開始時の HEAD は `0e916c802f5d4b77d74760cf823919a2e17b68c0`、作業ツリーは clean だった。

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Release/Coverage.lean` | 有用性・重なり・覆う選択肢・match・束縛の view 付き入口、任意の view の健全性、閉じた互換ラッパーと一致の定理、独立例 |
| `formal/Benitoite/Release/Lemmas/CoverageRuntime.lean` | 任意の view の到達不能判定を実行時の非選択へ結ぶ二つの系、旧入口の系の維持 |
| `docs/design/01-spec/01-12-core-calculus.md`、`02-impl/02-05-typechecker.md`、`07-quality/07-04-formal-semantics.md` | 実装した判定と証明、閉じた互換入口、Surface・交換形式・Rust がまだ旧入口を使う範囲の写し |
| `p2/formal.md`、`decisions.md`、この記録 | 実際の定義・言明の対応、R27、作成時の関門と検査の記録 |

`CtorsComplete`・`Inhabits`・`Exhaustive`・`AlternativeSelected`・`RuntimeSelected` と燃料の計算は変更していない。`shapesWithView_cover` から現在の値の特殊化を取り出すので、future を現在の値や実在の構成子とする仮定は要らない。既存の健全性の言明は元の型のまま保持し、view 付きの定理から閉じた系として導いた。

既存の Lean 評価例 34 件がすべて元の本文のまま残ることを HEAD と照合した。五つの評価例の追加により 39 件になった。全既知構成子と包括的な分岐、guard と同一分岐の重複、単一構成子の束縛、燃料切れ、ワイルドカード列の除去、構成子とリストの内側への view の受け渡しを表で検査する。Rust の実装とテストは変更していない。構文・標準ライブラリ・診断の表に変更がないので、Skill の再生成は不要である。

新しい健全性定理九つ、閉じた一致の定理七つ、既存の主な健全性定理と実行時の系について `#print axioms` を実行した。健全性の依存は従来どおり `propext`・`Classical.choice`・`Quot.sound` の範囲、一致の定理は `propext` のみである。新しい axiom・sorry・admit・native_decide はない。

最初の追加例の検査では、複合した結果の等値判定の `Decidable` の合成と、局所的な宣言表の字下げで失敗した。前者は `by decide` を定義の簡約による `by rfl` にし、後者は既存の宣言表の構文に合わせた。期待値と証明の命題は変えていない。

Rust の本番のコードとテストはともに差分 0 行である。Lean は定義・証明が合計 151 行増、評価例とその準備が 64 行増である。既存のテスト・評価例は削除していない。

## 検査

実行前にコマンドと形式化検査の時間の見込みを報告し、重い検査は順に実行した。依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成の検査は実行していない。コマンドは rtk を経由した。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,156 passed、0 failed、既存の ignored 21。73.80 秒 |
| `cargo test -p benitoite --test spec_examples --test skill_docs` | 成功。spec_examples 7 件、skill_docs 8 件 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `formal/` で `lake build` | 成功。159 jobs。最終の Lean のツリーでも check-formal の先頭で再実行して成功、50 秒 |
| `bash scripts/check-formal.sh` | 成功、終了状態 0。coverage_export 2 件、desugar_export 15 件（570.33 秒）、Python の独立検査 4＋12 件と六入口の完全一致を確認 |
| `lake env lean /private/tmp/benitoite-d2a-axioms.lean` | 成功。公理依存を確認 |
| `git diff --check` | 成功 |

`formal/**/*.lean` に sorry・admit・native_decide がないことも検索で確認した。

### 六入口の件数と分類

全体の検査の出力は `target/desugar-diff/run-50423/` と `target/coverage-diff/run-50423/` にある。ログは `target/desugar-diff/run-50423/d2a-check-formal.log`、公理依存の出力は同じディレクトリの `d2a-axioms.log` に保存した。最終の `check_named.py` は全 1,727 入力・73,733 定義・22,438 網羅性項目について、識別子・件数・分類理由を固定 manifest と完全一致で確認した。

| 入口 | 結果 |
|---|---|
| desugarDiff | 定義は golden 955＋random 72,778＝73,733 が一致。定義の mismatched/outside/excluded は 0。プログラムは golden matched 346・excluded 381、random matched 1,000・excluded 0 |
| builtinCheck | 対象 1,346 プログラム、primitive の比較 72,316、不一致・非収束 0。全入力の識別子と除外理由は最終段でも照合 |
| coverageDiff | 境界 20＋random 10,000＝10,020 件と named の独立入力 2 件が一致。不一致・燃料切れ 0 |
| coverageProgramDiff | match 16,405＋binding 6,033＝22,438 件が一致。不一致・対象外・燃料切れ 0 |
| surfaceCheck | 全 1,727 入力を単独の入口でも照合。named の独立入力の定義数 1・2・5・3・1・2・1 と、個別の失敗の分類理由も維持 |
| surfaceCheckAll | 全検査 51,656。matched 51,636・outOfScope 19・q11 1、不一致・準備失敗・lazyRestriction 0 |

最終の破損入力検査は、契約の改変 3 件、hole/pipe の改変 6 件、named export の改変 6 件をそれぞれ意図した理由で拒否した。幅付きの交換形式の Python 4 検査と契約名の 12 検査も成功した。corpus・型表・網羅性の版は 8/2/2 のままであり、対象内件数・対象外理由・既存の破損入力の検査を一つも減らしていない。

## 計画との差と申し送り

実装の範囲と規則に計画との差はない。所定の外部レビューを証明より先に行う順序については、このセッションで実施していないため R27 に推す案として記録した。自己確認を外部レビューの完了や設計者の合意として扱わず、オーケストレータへ申し送る。

D2b では `Declarations` に既定値が閉じた view を加え、ソースの match/bind から `usefulWithView`・`irrefutableWithView` を使う。任意の view で現在の `Exhaustive` を得る補題はこの変更で利用できる。record の取得・更新と try の内部の合成照合は閉じた view を明示し、D2c で本体ごとの指定へ進む。交換形式の版は従来どおり 8/2/2 のままであり、D3 での切り替えを先取りしていない。

`scripts/check.sh` と gc-stress の構成の検査は依頼どおりオーケストレータが最後に実行する。git のコミットと docs/todo/ の変更は行っていない。
