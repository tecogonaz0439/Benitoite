# V10.2b: 英語 reference・Skill・生成物の照合

## 作業と状態

2026-10-30 JST、担当。B_WORK と HEAD は `c0a4673a4b6bd532e1ea2331a7f71105efdbd507`、ブランチは `m013/v10.2b` である。開始時の差分はなかった。[開始状態](initial-state.json) に英語文書・生成参照・bundle の SHA-256 を保存した。

H06・H13〜H21 の10行について、英語文書の照合と編集を完了した。変更は英語7ファイル・20箇所である。同一ファイルの同一見出しを一箇所とし、空行だけの差を除く。新設見出しは5件である。生成参照66ファイルと bundle は再生成して内容差分0件だった。指定の W-E は初回で成功した。日本語訳、版の表記、CHANGELOG 本体は変更せず、対応表と英文案を本ディレクトリへ置いた。

`private/`、同所を指すスキル、`docs/todo/` は読んでいない。AGENTS.md、共通依頼文、plan-v10、README の決定、V10.2a の追補後の結果、版の棚卸し、各 H 行の保存記録とレビュー、現行設計書と実装を根拠とした。記録には japanese-tech-writing を適用した。状態を変える git 操作、依存更新、新しい CARGO_TARGET_DIR、Lean のビルド、全比較、性能測定は行っていない。担当の照合と検査の成功は、独立レビュー・設計者の受け入れを代用しない。

## H 行の照合表

英語 reference のパスは `docs/reference/benitoite.md`、Skill のパスの接頭辞は `crates/benitoite/skill/` である。実装のパスの接頭辞は `crates/benitoite/src/` である。保存記録は経緯と未確認の特定に使い、現在の仕様は V10.2a 後の設計書と実装に照合した。

| 行 | 出どころ・実装との対応 | 今回の結果・編集位置 |
|---|---|---|
| H06 | [R10](../r10/results.md)、[R30 の棚卸し](../r30.5/handlers-boundaries.md)、[R40.3 の全操作の照合](../r40.3/results.md#変更と全接点の照合)。`prelude/stdlib/IO/File.bnt`・`Network/Http.bnt`、`typeck/effects/handle.rs::select` の解決済み操作による完全性 | reference「Complete and partial handlers」に Read13・Write16・Connect2 の全操作、readText 一節では不足12・writeText 一節では不足15、旧 send は sendIn が不足する部分ハンドラであることを記した。Skill と idioms の操作数と固定参照もそろえた。別名・完全／部分・不足節の照合は下節。外部の母集団と件数は不明のままである |
| H13 | [RV-R30.1 軽1](../reviews/RV-R30.1.md)、[R30.1](../r30.1/results.md)、[R30.5](../r30.5/handlers-boundaries.md)。03-06「Scope」、03-09「クライアント」、`types/scope` と `builtins/checked_scope` | reference「Scope」の旧 IPv6・全数字四ラベルの一括拒否を、正規形 IP/CIDR の受理、不正な IPv4 の拒否、IPv4 射影の対象拒否へ修正した。パターンの代数では IPv6 を保つ。URL の数値風 host 拒否と直接 Scope の名前の判定は区別した。common-mistakes も一致させた |
| H14 | [R30.1 の既知不良と交換の扱い](../r30.1/results.md#既知の不良の対象と診断)、[RV-R20](../reviews/RV-R20.md)。01-06「定数の型」、`typeck/checked_args.rs`・`tests/desugar_export.rs` | reference「8. Constants and type aliases」と Skill・common-mistakes を新四入口へ追随させた。checkPathIn は pattern/path、checkRequestIn は hostPattern/port bounds が追加検査の対象で、二射影は条件引数を持たず追加対象なしである。URL 解析は実行時に残る。E0459〜E0462 は既知不良の追加拒否であり、交換ではコード付き除外・空の定義となる。必須判定の四理由とは別であり、成功例や同じ理由の比較に数えない |
| H15 | [README の TODO-308 の決定](../README.md)、[V10.2a の追補](../v10.2a/results.md#v102ab-追補-rv-v102a-の指摘への対応)、[R40.1](../r40.1/results.md)、01-06「範囲付きの不透明標準型」 | reference「Scoped values and IO」に直接 bind の射影・明示拡大と、同じ狭い型の IO 転送の例を加えた。Skill・idioms・common-mistakes では、狭い関数／節引数と宣言した狭い戻り値には注釈だけで由来を与えず、bind へ移すだけでは直らないことを分けた。現在の精度の制限と記し、恒久の設計にしていない |
| H16 | [R30.5](../r30.5/results.md)、[R40](../r40/results.md)、[義務表](../v10.1a/obligations.md)。01-06・01-07、03-06/07/09、`builtins/table.rs` の認定と対象位置 | reference に六純粋宣言と七 IO の表を加え、保持した同じ値／要求、要求の五欄と実効 endpoint、不変添字、明示拡大、入力型による効果の具体化を記した。節の IO は完全ハンドラの外へ残る。既存 HTTP 例の bind の形を維持した。宣言・登録表・生成参照を照合したが変更していない |
| H17 | [R40.1](../r40.1/results.md)、[R40.3 の Show 照合](../r40.3/results.md#変更と全接点の照合)。03-09 と `Network/Http.bnt::RequestCheckError` | 標準 Show を加えない決定を保った。reference「Checked HTTP requests」と idioms「HTTP」に InvalidUrl/Scope の match を示し、内側 ScopeError の Show と、送信時の NetworkError を分けた。採否を再質問していない |
| H18 | [UB20.02](../ub20.02/results.md)、[R40.2](../r40.2/results.md)、[R40.3](../r40.3/results.md)、[RV-R40 中1](../reviews/RV-R40.md)。06-01/04/06、`cli/inspection.rs`・`cli/tools/test_runner/docs/prepare.rs` | reference「Inspection reports」「Declared target bounds」「Effect limits before execution」と install の説明を、既に修正済みの inspection と一致させた。expanded は名前集合、bounds は宣言上限である。欠落 bounds は全対象、未知対象は all、未完了は null と読む。check/error の空の Effects/tests は入口未選択を表し、純粋を意味しない。処理済み利用者名や診断の由来を許可へ戻さない |
| H19 | [R30.2d の版と承認](../r30.2d/results.md#互換と確認済み-manifest)、[R30 の意図した差](../r30/results.md#意図した差)、V10.2a の外部生成の版。03-06/08・06-06、`tools/derive/README.md` | reference「Record generators and shrinkers」と Skill「Reference documents」の現在の inventory/hash を4へ修正した。外枠3・生成規則3.1.0-syntax-batch5・設定1を維持し、旧 manifest/receipt は新版の apply の承認にならないことを記した。過去の版の移行節は変更せず、新しい移行案内・手順は作っていない。旧ツールで保留中の apply/recovery を終えること、旧本文のハッシュを照合すること、apply 後に通常の check/test と derive check を行うことの既存の手順文は、`tools/derive/README.md` と重複するため意図して削除した |
| H20 | [README の DET-09](../README.md)、[R30 の全ハンドラ](../r30.5/handlers-boundaries.md)、01-07 の七操作 | [CHANGELOG 文案](changelog-draft.md#h20-added--changed) に七操作の追加と、旧 send の一節では Connect が残る事実を英文で用意した。書き換え手順・前後コード・移行例・性能増減を含めていない |
| H21 | [RV-R20 軽4](../reviews/RV-R20.md)、[R20 の意図した差](../r20/results.md#意図した差) | 当初は修正項目の文案を用意したが、追補で50個・200個の入力を両版の CLI に通し、公開 0.0.12 が拒否しないことを確認したため文案から外した。[除外の理由](changelog-draft.md#h21-の項目を外した理由)と下の追補に根拠を記す |

## 変更したファイルと箇所

| ファイル | 箇所数 | 変更した説明 |
|---|---:|---|
| `docs/reference/benitoite.md` | 12 | 冒頭の保証、検査報告、対象上限、名前だけの照合、既知不良、エフェクトの総論、範囲構文、ハンドラの完全性、生成の版、Scope の IP、範囲付き値と七 IO、HTTP 要求と失敗 |
| `docs/reference/install.md` | 1 | Agent Skill の導入節で、ハーネスが対象上限を説明することと名前だけの照合・隔離の責任を補った |
| `crates/benitoite/skill/SKILL.md` | 2 | 検査済み値の現在の制限・四入口・完全性・候補の固定参照、生成情報の版と承認の境界 |
| `crates/benitoite/skill/references/inspection.md` | 1 | 新しい対象上限の正を候補の固定参照へ結び、旧版参照の用途を既存必須欄に限定した |
| `crates/benitoite/skill/references/idioms.md` | 2 | HTTP 例の RequestCheckError の match と精度の制限、テストの部分ハンドラと操作数 |
| `crates/benitoite/skill/references/common-mistakes.md` | 1 | 新四入口、IP/CIDR と射影対象の拒否、bind と狭い引数の限界 |
| `crates/benitoite/skill/references/language-comparison.md` | 1 | 比較表の旧 String IO と Top、範囲付きの入力を使う IO と保証の区別 |

[英日対応表](translation-map.md) と [対応 JSON](translation-map.json) が20箇所の見出しと訳の担当範囲を示す。製品版の0.0.12の表記と language 宣言は保持した。新しい固定 URL の v0.0.13 は、今回指定された候補の契約への参照であり、製品版の一括更新ではない。

## ハンドラ・別名・不足節の照合

[機械で読める照合](handler-audit.json) に、実標準宣言と生成参照の同じ操作列、文書の節位置を保存した。Read13・Write16・Connect2 は、reference の全操作表とも一致する。生成参照に File/Connect のハンドラ例はない。

| 対象 | 完全性と扱い |
|---|---|
| reference の countWordsCounts、Skill の firstLineWorks、idioms の countWordsReadsFile | 3例とも readText だけの部分ハンドラで、不足は他の12操作である。uses File.Read を保ち、実際のファイルを読む例とは説明していない |
| 対応する日本語3例 | 同じ readText の部分ハンドラで File.Read が残る。今回は読むだけとし、追加した説明の翻訳は V10.3a へ渡す |
| 完全な Log の文書例 | 一操作の利用者 Log、標準 Log の全 emit/enabled を処理する既存例の区別を保つ。File/Connect の完全ハンドラと数を混ぜない |
| File/Http の別名 | 標準効果のモジュールは as を拒否する。純粋な Scope の別名 S は同じ標準宣言として認定する。新設 reference 例は実際に S を使い、W-E の reference_examples が検査した |
| 旧 send・不足節・節自身の IO | send だけでは sendIn が不足する。全操作を処理しても節自身の別対象 IO は外側へ残る。reference の表と既存 Skill の説明を一致させた |
| 先行棚卸しの35件 | R30.5 が数えた当時の File30・Connect5 のテンプレート／ソース件数である。完全／部分の判定、共通節を別件に数えない条件を引き継いだ。今回の文書例は追加の File/Connect ハンドラを含まない。35を現時点の全リポジトリの再集計値とはしていない |
| リポジトリ外のコード | 母集団・件数とも不明である。0件や全件対応済みにはしていない |

## 固定参照と生成物

固定参照は [一覧](pinned-references.md) に全14出現・9種類を記した。既存必須欄と区間解析の4出現・3見出しは v0.0.12 のローカルタグの本文と一致する。新しい範囲の10出現・6見出しは候補 v0.0.13 に固定し、候補内の見出しと契約を照合した。同名のローカルタグは存在せず、タグを取得できた、または公開 URL の取得が成功したとは記録していない。見出しの改名・削除は0件であり、テスト・生成器の見出し参照の修正は不要だった。

G の `cargo run -p benitoite --example gen_skill` は終了0、外側3.461508秒だった。[ログ](generate.log) と [計時](generate.json)、[生成元・生成物・bundle の SHA-256](generated-audit.json) を保存した。生成参照66ファイルと bundle は開始版とバイト一致であり、構文・標準ソース・診断表・生成器も開始版と一致する。W-E の skill_generated と skill_docs は鮮度・索引・埋め込み対象の一致を検査し、差分を作らなかった。生成物は手で直していない。

全比較の一般 corpus は `tests/desugar_export.rs::discover` が testdata を収集し、英語文書や Skill を自動収集しない。書き出し器・台本・Lean・標準ソース・testdata は不変である。今回の文書差分を理由に全比較を再実行せず、F-Q の入力変更や引用不能を新たに判断する事象も生じなかった。最終候補の全 Skill の実 CLI 本文ハッシュと producer の照合は V10.3c の担当に残す。

## 検査

指定の dry-run を先に実行し、3単位と五つの統合ターゲットが選ばれることを確認した。同じ指定を一度実行した。

```sh
scripts/check.sh --level work --base c0a4673a4b6bd532e1ea2331a7f71105efdbd507 --only tests_related,skill_generated,spec_tally --test reference_examples --test skill_docs --test skill_examples --test stdlib_doc_examples --test spec_examples --dry-run
/usr/bin/time -p scripts/check.sh --level work --base c0a4673a4b6bd532e1ea2331a7f71105efdbd507 --only tests_related,skill_generated,spec_tally --test reference_examples --test skill_docs --test skill_examples --test stdlib_doc_examples --test spec_examples
```

実際の計時は check.sh を呼ぶ短い sh を time で包み、直後の終了値を保存してから同じ値で sh を終了した。ラッパーの全文は [work.json](work.json)、check.sh 自身の値は [work-check-exit.json](work-check-exit.json)、出力は [work.log](work.log) に保存した。計時器の終了だけから check.sh の終了を推定していない。

| 検査 | 結果 |
|---|---|
| [dry-run](work-dry-run.log) | check.sh 自身0。tests_related・skill_generated・spec_tally の指定を確認した。名指しの部分選択である |
| reference_examples | 1成功・失敗0・無視0・除外0、テスト本体3.81秒 |
| skill_docs | 8成功・失敗0・無視0・除外0、0.09秒 |
| skill_examples | 4成功・失敗0・無視0・除外0、4.55秒 |
| spec_examples | 7成功・失敗0・無視0・除外0、3.24秒 |
| stdlib_doc_examples | 1成功・失敗0・無視0・除外0、2.54秒 |
| skill_generated | 再生成後の状態に変化なし、成功 |
| spec_tally | 自己検査と通常集計が成功。参照テストのない節の一覧は出力され、初回リリースの未記入条件は none だった。仕様全体の検証完了とは扱わない |
| W-E 全体 | **check.sh 自身0、time も0**。計21成功・失敗0。time の real **23.49秒**・user24.62秒・sys3.49秒、外側23.498848秒。指定どおり一度実行し、Rust の全 lib・clippy・fmt や全比較は選んでいない |
| リンク・見出し | [link-audit.json](link-audit.json) の74文書・相対リンク242件で切れ0件。生成参照と変更しない minimal reference も対象にした。コードフェンスとインラインコードを除いて照合した |
| 差分の空白 | git diff --check は終了0。変更範囲、見出しの保持、版の保持、ソース等の不変は [最終状態](final-state.json) に保存する |

最大常駐量は未計測である。指定の time -p は RSS を報告しないためであり、0とは記録していない。W-E の初回失敗・再実行はない。記録を作る一回の補助 Python は、標準入力の文字コードの SyntaxError で実行前に終了1となった。ファイルは書かれておらず、Markdown の記録は apply_patch で作成した。処理系や文書例の失敗ではない。

W-E 後の読解で、reference と SKILL.md の版の段落を、外枠3の三種類と inventoryVersion/hashVersion を持つ manifest・生成記録に明確に分けた。receipt は正確な manifest と生成記録のハッシュへ結び付くという説明である。[補正前後の照合](post-check-prose.json) に、二文書の全フェンスと見出しが不変であることと、その SHA-256 を保存した。版の段落以外、生成物・bundle・ファイル集合・構成・テストは不変であり、通過した例・生成物・仕様集計の入力の意味を変えていない。Skill の追加一行も500行未満の制約を保つ。新しい実候補の埋め込み本文の検査とは区別し、同じ検査を反復せず W-E の結果を維持した。最終の文書本文に対する固定参照の SHA-256 は更新した。

## 停止判断と V10.3a 以降へ渡す点

J3 に該当する本番・標準宣言・生成器・bundle・規則・構文・Lean の写しの変更は不要だった。新たに設計者の判断を求めて止めた事項はない。H17 の Show の採否や TODO-308 の制限を再質問していない。

| 次の担当 | 渡す内容 |
|---|---|
| V10.3a | [英日対応表](translation-map.md) の7ファイル20箇所を訳す。版の棚卸しの区分に従って現在版・正常な三つの宣言例・訳元を一括更新する。今回の候補固定 URL と過去の版のリンクの用途を保持する |
| V10.3a/c | [CHANGELOG 文案](changelog-draft.md) の H20 を最終編集と候補照合へ使う。H21 は追補の公開版での再現により文案から外した。移行手順や性能の増減を加えない。外部ハンドラの件数は不明を保つ |
| 取りまとめ・リリース準備の前 | 埋め込む Skill を編集したため、plan-v10 の M と H23 の性能判断を取り込み後の区切りで行う。担当は short を実行していない。既存の費用の採否を変えていない |
| V10.3c | 実候補の全 Skill 論理名・本文のハッシュ・版置換後の SKILL.md・producer を照合する。今回の skill_docs の成功を実候補の版の証拠へ読み替えない |
| V10.1d/c と最終の引用判断 | 書き出し入力の再確認と F-Q は既定の担当に残す。H03 の限界、義務02/03/04の未確認、H31 の局所結果と最終比較の違いを閉じたことにしない |

独立レビュー、設計者の受け入れ、版の更新・訳・CHANGELOG の本体編集、性能測定、候補の release は実施していない。今回の完了は、英語文書・生成参照の照合と指定された W-E の範囲である。

## 時間

開始は2026-10-30 03:28:03 JST（2026-10-29 18:28:03 UTC）である。G は約3.46秒、W-E は約23.50秒だった。能動時間と短い読み取り・記録の待ちは厳密には分離していない。独立レビュー・測定・設計者の回答待ちはない。終了時刻と外側の所要は [final-state.json](final-state.json) に記録する。見込み上端の2倍と6時間の停止条件には達していない。W-E 後の版の段落だけの補正と検査の入力が不変である根拠は上節に記した。

## V10.2bb 追補: RV-V10.2b の指摘への対応

2026-10-30 JST、[レビューの取りまとめの対応](../reviews/RV-V10.2b.md#対応取りまとめ)に従い、同じ未コミット差分の上で6件に対応した。B_WORK と HEAD は `c0a4673a4b6bd532e1ea2331a7f71105efdbd507`、ブランチは `m013/v10.2b` のままである。[追補の開始状態](supplement-initial-state.json)に既存の差分とファイルの SHA-256 を保存した。

### 指摘と修正の対応

| 指摘 | 直した箇所 | 対応 |
|---|---|---|
| 中1 | Skill の language-comparison「Functions」 | assert の行を元の比較表の末尾に戻し、範囲付き IO の追加段落を表の後へ移した。表は一つである |
| 中2 | Skill の inspection「Inspecting before execution」 | “The candidate reference” を “The v0.0.13 reference” にした。埋め込み Skill と英語 reference を検索し、リリースの段階を表す語の残りを点検した。縮小器の候補値、診断の候補名、旧移行節の移行候補という意味の candidate(s) は保った |
| 中3（H21） | 本ディレクトリの CHANGELOG 文案 | 50個・200個の入力を再構成し、公開 0.0.12 と現在の CLI の check へ通した。公開版で拒否されなかったため、H21 の Fixed の項目を外した。根拠と版ごとの操作数の違いは下節に記す |
| 軽1 | 上の H19 の行、英日対応表 | derive の既存の手順文の削除が、`tools/derive/README.md` との重複を避ける意図した削除であると明記した。[訳への追補](translation-map.md#レビュー後の訳への追補)に、V10.3a の訳でも同じ文を消すと記した |
| 軽2 | reference「Complete and partial handlers」 | File.Write の操作列を `writeBytesIn, appendBytes, appendBytesIn` の宣言順にそろえた。16操作の集合と数は同じである |
| 軽3 | Skill「Checked values and local builders」 | 埋め込み文書の説明を、インストールした版の文法・診断・標準ライブラリの署名を記す参照へ限定した |

追補で変更した追跡対象は英語の4ファイルである。先行する英語7ファイルの差分は保持した。生成物の手修正、本番・標準宣言・生成器・bundle・設計書・テスト・testdata・計画・日本語訳の変更は不要であり、J3 の停止条件に当たる問いは生じなかった。`private/` とそこを指すスキル、`docs/todo/` は読まず、git の状態を変える操作、新しい CARGO_TARGET_DIR、Lean のビルド、全比較、性能測定は行っていない。

### H21 の再構成と公開版での確認

50個・200個の元の入力は、`r20.4/` と改造内の `rv-probes/` の保存ファイルには見つからなかった。独立した RV-R20.4b の文書もなく、再確認は [RV-R20.4 内の追記](../reviews/RV-R20.4.md#r204b-の再確認2026-10-29取りまとめの依頼)にある。その説明と [保存された通常入口の再現形](../r20.4/rv-probes/scoped_calls.rs.txt)から入力を新しく作った。元入力のバイト単位の再実行とはしていない。

入力は、一つの sample 関数に File.Read の全操作を処理する lambda を50個または200個並べ、後に置いた tick のハンドラの節から各 lambda へ protected 関数を渡す形である。protected は Top の `uses File.Read` を宣言する。元の狭い範囲の再現と区別し、H21 の主張どおり Top だけを使った。各 lambda の引数の効果は後の節の呼び出しから届く。実 IO と VM の実行は行わず、公開 CLI の check で受理と診断を調べた。

公開 0.0.12 の File.Read は11操作、現在は13操作である。同じ完全性を比較するため、旧版用の11節と、追加の readTextIn/readBytesIn の2節だけを加えた現在版用の13節を保存した。同じ11節の入力も現在版に通し、部分ハンドラによる拒否を対照とした。[入力と独立期待値](h21-reproduction/expectations.json)は CLI の実行前に保存した。入力本文・大きさ・SHA-256 を同じ場所に残す。

| File.Read の完全ハンドラの数 | 公開 0.0.12、11節（期待0） | 現在の CLI、13節（期待0） | 現在の CLI、同じ11節（期待2・E0501） |
|---|---|---|---|
| 50 | 終了0、標準出力・標準エラーとも空、0.136秒 | 終了0、標準出力・標準エラーとも空、0.241秒 | 終了2、E0501 が1件、0.261秒 |
| 200 | 終了0、標準出力・標準エラーとも空、0.223秒 | 終了0、標準出力・標準エラーとも空、2.100秒 | 終了2、E0501 が1件、2.725秒 |

6実行とも独立期待値に一致した。旧11節の現在版での拒否は、追加2操作の節がなく File.Read が残るためである。誤った拒否の再現とは数えない。[実行の一覧](h21-reproduction/execution.json)に正確なコマンド、バイナリと入力の SHA-256、終了状態、外側の秒数、診断ログを保存した。公開版のバイナリの SHA-256 は依頼の `69b9ee4be97a883c8c2e0a7d8e289bd2ae1160b75179d7b12fd5a434a2acacf7` と一致した。現在の CLI は `cargo build -p benitoite --bin benitoite` でビルドし、終了0、ビルドの表示は5.08秒だった。現在の Cargo の製品版は版上げ前の0.0.12であり、`--version` の表示を公開版と同じ実装の証拠にはしていない。

以上から H21 の修正項目を CHANGELOG 文案から外した。0.0.12 の公開版ではこの拒否がなく、0.0.13 の開発の途中で入って直したものである。前の公開版との差として Fixed に載せず、[文案から外した理由](changelog-draft.md#h21-の項目を外した理由)を残した。H20 の2項目は維持し、R20 の開発中の記録と意図した差は変更していない。

### 追補の検査と時間

指定の [dry-run](supplement-work-dry-run.log) は check.sh 自身の終了0で、tests_related・skill_generated・spec_tally の3単位と、reference_examples・skill_docs・skill_examples・stdlib_doc_examples・spec_examples の5統合ターゲットを選んだ。[実行の指定と計時](supplement-work.json)に同じ引数を保存し、`/usr/bin/time -p` で包んで一度実行した。[実行ログ](supplement-work.log)と [check.sh 自身の終了状態](supplement-check-exit.json)を保存した。

| 検査 | 結果 |
|---|---|
| reference_examples / skill_docs / skill_examples / stdlib_doc_examples / spec_examples | 順に1・8・4・1・7件成功。計21成功、失敗0・無視0・除外0 |
| skill_generated | 成功。生成参照66ファイルと bundle の内容差分なし |
| spec_tally | 自己検査・通常集計とも成功。参照のない節は表示され、初回リリースの未記入条件は none |
| 指定した部分選択全体 | check.sh 自身0、time も0。real 23.63秒、user 24.22秒、sys 3.49秒。外側23.634252秒 |
| 相対リンク・アンカー・表 | [照合記録](supplement-link-table-audit.json)。minimal reference と生成参照を含めた78文書の相対リンクと版固定リンク14件で切れ0件。Functions は見出し・区切りを含め43行の4列表で、41件の比較を一つの表に保つ。操作表と変更した記録内の表も列数が一致する |
| リリースの段階を表す語 | [検索の記録](supplement-publication-terms.json)。残り0件。candidate(s) の33出現は縮小器の候補値・診断の候補名・旧移行節の移行候補として意味を確認して保持した |
| 変更範囲と空白 | [最終状態](supplement-final-state.json)。開始時から変わった追跡対象は指定の英語4ファイルだけであり、HEAD・ブランチ・index は不変。git diff --check は終了0 |

最大常駐量は未計測である。指定の time -p は RSS を報告せず、0とは記録していない。指定検査の失敗・再実行はない。H21 の11節を現在版に通した2件の終了2は、実行前に定めた拒否の対照である。今回の部分選択を work 全体・change・release の成功とは扱わない。全比較は再実行も新たな引用判断もしていない。

追補の開始は2026-10-30 03:55 JST頃である。実検査は04:01:53〜04:02:16 JST、H21 の6実行は計約5.69秒だった。終了時刻と外側の所要は [最終状態](supplement-final-state.json)へ記す。能動時間と短いツール待ちは厳密に分離していない。独立レビュー・設計者の回答待ち・性能測定の待ちはなく、2時間の停止条件には達していない。V10.3a は更新した英日対応表と H20 の文案を使い、H21 を公開版との差へ戻さない。取り込み後の性能判断、独立レビュー、受け入れ、候補の照合は既定の担当へ残す。
