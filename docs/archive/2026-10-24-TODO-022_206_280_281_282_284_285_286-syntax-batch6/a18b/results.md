# A18b の結果

- 着手: 2026-10-26 07:08:28 JST（2026-10-25 22:08:28 UTC）。
- 終了: 2026-10-26 07:17:50 JST（2026-10-25 22:17:50 UTC）。所要時間は9分22秒である。
- B_WORK・HEAD: `d82c182642fd7adbfa4a06c78b424a00f32d6fe8`。ブランチは `mod012/A18b`。
- 状態: 指定範囲の文書更新・生成参照の再生成・work 検査・差分の点検を完了した。独立レビューと受け入れは取りまとめへ引き渡す。

## 範囲と変更

plan.md「計画の変更（2026-10-26、RV-C3 を受けて）」と作業群 A18 の A18b に従った。共通依頼文、前提と依存、内部の契約、指定の検査、D3・D16・D18 と追記、A16a〜A18a・L18〜L21V の申し送りと取りまとめのレビュー、RV-C3・RV-L21R・RV-L21T・RV-L21U と応答を確認した。文章には japanese-tech-writing、シェル操作には rtk を適用した。private/ とそこを指すスキルのリンクは読まず、git の変更操作・委任・docs/todo の変更・コミット・取り込み・公開は行っていない。

| 対象 | 変更 |
|---|---|
| `docs/design/03-interop/03-06-stdlib.md` | 標準 call の認定と、固定端点から得る成功値の由来の認定を分けた。import 別名、認定した call の引数の親環境での解析、未認定 call の独立解析、Result の一度の保存と全腕、同じ成功値への直接 value、忘却の境界をそろえた。E0340 は 01-03 の規範を参照し、A1 と実 VM 比較の未完を明記した |
| `docs/design/07-quality/07-04-formal-semantics.md` | 認定した call と Result の全腕の解析に本文・対応表をそろえた。三欄の具体値と由来側のキー・束縛番号・証拠を区別し、条件環境の合流での忘却、Range の認定走査と auxiliary の計上を反映した。A18a の有限の入力で確認済みの型・同定・固定表と、X02・X03b に残る全比較を区別した |
| `crates/benitoite/src/prelude/stdlib/Range.bnt` | モジュールの doc コメントに、固定端点、直接 match または Result の一保存、単独の Ok の同じ成功値への直接 value、別名・合流・関数境界等での忘却、Range の Error を新警告にしないことと実行時検査の保持を追記した |
| `crates/benitoite/skill/references/stdlib/Range.md` | `cargo run -p benitoite --example gen_skill` で再生成した。生成物は手で編集していない。他の生成参照と bundle.rs に差分はない |

Rust のコード、Lean（formal/）、固定表と生成元、言語規則・型・エフェクト、公開の型と署名、主要定理の前提と結論、公理、依存と固定ツールチェーンは変更していない。Range.bnt は doc コメント以外が基準と一致する。設計書の見出しとコードブロック、既存の文書例と診断の期待値も変更していない。テストの追加・変更はない。

## レビュー所見との対応と保証の範囲

| 所見・契約 | 対応 |
|---|---|
| RV-L21R 軽2 | 07-04 の「呼び出しの頭・引数を独立解析」を未認定の call に限定し、認定した call の引数は親の環境でソース順に解析すると記した。match の腕を番号だけ辿る条件は、Range の Result と一種類の整数のどちらにも認定できない場合に限定した。認定した Result の Error・guard・Result 全体の変数・wildcard を含む全腕を親から解析する説明と対応表をそろえた |
| RV-L21R 軽3 | 対応表に `WarningsInCallReach`・`IndependentResult.CallsRecognized`・`BudgetWhole.analyze_warning_call_reach` を加えた。全体の保証は停止後も `bodyOutputs` に保存した本体の親と独立入力を対象とし、未発見・未解析の本体には述べないと記した。Lean のコメントの訂正は本枝では行わず、応答どおり L22 へ残す |
| D3・D16 の追記 | 値の合流に加え、条件環境の合流でも外側の記録まで忘れ、番号を再利用しないことを明記した。成功値の由来は保存直前の auxiliary 一項であり、保存自体には操作数を加えない。認定走査の対象と順序を Lean に合わせ、正確な回数の正は各 Lean の関数定義とした |
| D18・RV-L21T/U/V | 成功値は `.data owner []` と三欄の `.con` で表し、具体値の意味は呼び出しキーによらない。三欄を認定できない表現や other の未知の正常値・失敗の導出を残す説明にそろえた。実交換の同定を型名や表示名から推測せず、公開境界の不透明性をコアの `.opaque` と区別した |
| A18a・A1 | 保存した比較入力の全 Range 呼び出しについて型・標準署名・構成子の同定を照合済みであり、Range の形を含む固定表を照合する範囲を記した。この記述は A18a の完了後の実装と記録に合わせたもので、A18b で実交換や固定表を再計算した結果ではない |

評価規則を定義すること自体は A1 の信頼の範囲である。中心二命題や Release の δ に標準 API の振る舞いの仮定を加えない。小モデル・独立例・固定表の内側の検査を、標準ソース・脱糖・Release・実 VM との一致の証拠に代用しない。全関係状態の比較は X02、実 VM の値・三欄・Result の成否と保存引数・逆転優先・射影・算術の失敗・到達の比較は X03b に残り、X03b が閉じるまで実本体との接続は未完である。

## 検査と実行結果

実行場所は `<repo>`。Cargo は既存の書き込み可能なキャッシュを `CARGO_HOME=<tmp>/benitoite-a01a-cargo` として使った。Rust/Cargo の固定版は1.98.1。Lean の実行は行っていない。[実行器](run.py)はコマンド・終了状態・外側の monotonic 時計による時間・出力を保存し、手元のパスを `<repo>`・`<home>`・`<tmp>` に伏せる。

| 実行 | 結果 | 外側時間・記録 |
|---|---|---|
| `cargo run -p benitoite --example gen_skill` | 終了0、生成参照を再生成 | 3.412秒。[ログ](gen-skill.log)・[コマンドと終了](gen-skill.json) |
| 指定の work と同じ基準・対象の `--dry-run` | 終了0、指定の6単位を選択 | 0.015秒。[ログ](work-dry-run.log)・[コマンドと終了](work-dry-run.json) |
| 指定 work、一度、`/usr/bin/time -l` で計測 | 検査本体0、6単位成功。計測器1 | 26.713秒。[ログ](work.log)・[計測器の終了と時間](work.json) |
| `git diff --check` と最終点検 | 終了0 | [点検器](final-review.py)・[点検結果と入力ハッシュ](final-review.json) |

指定したコマンドは次のとおりである。計測時は [run-work.sh](run-work.sh) が同じ指定の検査を実行し、検査本体の終了状態を保存する。

```sh
scripts/check.sh --level work --base d82c182642fd7adbfa4a06c78b424a00f32d6fe8 --only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --test stdlib_doc_examples --dry-run
/usr/bin/time -l /bin/zsh docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a18b/run-work.sh
```

| work の内訳 | 結果 |
|---|---|
| `tests_related` | `skill_examples` 3件、`stdlib_doc_examples` 1件成功 |
| `skill_generated` | 再生成の一致、成功 |
| `spec_tally` | 自己検査と仕様集計が成功。初回リリースの完了条件の未記入は none |
| `spec_examples` | 7件成功 |
| `reference_examples` | 1件成功 |
| `skill_docs` | 8件成功 |

統合テストは計20件成功、失敗0件、ignored 0件である。指定外の全 lib・全統合・Lean ビルドは追加していない。ログの `selected checks passed` と `A18B_CHECK_EXIT_STATUS=0` が検査本体の成功を示す。**最大常駐量（maximum resident set size）は、サンドボックスの `sysctl kern.clockrate: Operation not permitted` により取得不能**だった。計測器の終了1を検査の不合格とは扱わない。time の real/user/sys は26.71/24.38/4.69秒である。

検査に失敗・再試行はない。途中の文書編集では、stdin の Python の文字コードエラーと、不正な空 hunk を含む patch の拒否が各一度あった。どちらもファイルへ書き込む前に停止し、apply_patch の入力を直して反映した。work 後には03-06の説明中の用語を二箇所だけ平易な表現へ直した。見出し・コードブロック・ソース・生成参照・検査の入力は変わらず、古くなった検査はないため成功済みの6単位を繰り返していない。

## 最終点検・計画との差と申し送り

最終点検で、追跡済みファイルの差分が上記4件だけであること、index に差分がないこと、Range.bnt のコメント以外と設計書の見出し・コードブロックが基準と一致すること、追加・変更行の相対リンクとアンカーが存在することを確認した。Rust・formal/・固定表・依存には変更がない。記録のパスの伏せ方と保存した Python の構文も確認した。

実装範囲と検査の割り当てからの変更、言語規則・主要定理・公理についての判断待ち、6時間の上限による中断はない。A18b が受け持つ未実施・不合格の検査は残っていない。計測の環境制約と、後続が担当する未完の接続は上記のとおりである。

| 担当・時期 | 残る検査・比較・レビュー・受け入れ | 見込み |
|---|---|---|
| 取りまとめ、A18b の取り込み前 | 文書と生成参照の独立レビュー、RV-L21R 軽2・軽3と A1 の限界の確認、受け入れ | 不明 |
| 取りまとめ、A18 の後 | S-A3。標準束縛→Ok/射影→区間の接続を、宣言・名前付き引数・golden・desugar_export の統合テストで確認し、段を受け入れる | 計画の3〜10分。レビュー・受け入れ待ちは不明 |
| L22、次の Lean の作業 | RV-L21R 軽3 の `CallReachWhole.lean` のコメントの根拠の節の訂正と、その作業の検査・レビュー | 不明 |
| X01・X02・X03b、計画の依存を満たした後 | 独立交換と全関係状態の型・区間・候補・費用の比較、実 VM の三欄・成否・逆転優先・射影・失敗・到達の比較、レビューと受け入れ | 各計画に従う。今回未実施のため実測は不明 |

stage・change・release、check-formal.sh 全体、実 VM の比較、コミット・取り込み・docs/todo の更新・保管・公開は、本枝では行っていない。

## 取りまとめのレビュー（2026-10-26）

変更は 03-06・07-04・Range.bnt の doc コメントと、gen_skill で作り直した生成参照だけで、Rust のコード・Lean・固定表は変えていない。RV-L21R の軽2・軽3 の 07-04 の訂正を含む。指定の6単位は成功した。S-A3 へ進む。
