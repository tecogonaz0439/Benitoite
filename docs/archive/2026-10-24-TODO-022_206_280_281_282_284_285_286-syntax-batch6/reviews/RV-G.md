# RV-G 改造全体のレビュー（第6弾）

- 日付: 2026-10-27
- 担当: Claude Code のサブエージェント（Opus 5.5）
- 対象: `706d7ca3..0b4979eb`（読むだけの worktree `<repo>-rv-g`、detach、HEAD 0b4979eb）。改造のディレクトリ D = `docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/`
- 方法: 次を読んだ。D の README・plan.md の該当行・decisions.md の D28・results.md の S・X05・U03 の節。設計書の差分（00-04、01-03、01-04、01-12 の区間解析の節の抜き出し、02-05「区間解析」の各節、02-09、02-10、03-01、03-06、03-07、03-10、06-01、06-04、06-06、06-09、07-03、07-04 の「区間解析の対象構文の評価関係」と「区間解析を含む全比較への接続」）。英語リファレンスの差分、同梱 Skill（SKILL.md・idioms.md の区間解析の節・inspection.md・diagnostics.md）、標準ライブラリのソースの差分（Integer・Byte・Range・Log）。実装は `typeck/interval/` の diagnostics.rs・summary.rs・budget.rs・fixed_domain.rs・arithmetic.rs の一部、`diag/codes.rs`、`cli/check_report.rs`、`cli/tools/test_runner/check_report.rs`、`typeck/decls.rs`・`mod.rs`、`external/runtime.rs`・`text.rs`、`builtins/funcs/log.rs`、`scripts/check.sh`・`scripts/check/advisories.py`（終了状態の扱い）、`tools/derive/` の差分、Cargo.toml・二つの Cargo.lock・deny.toml。Lean は中心命題の定義（`Interval/Eval.lean` の `NormalSoundness`・`WarningSoundness`）と `Interval/Sound.lean` の二定理の言明、`Benitoite.lean` の import の閉包を確かめた。機械的な照合として、変えた文書の相対リンクと見出しの参照、設計書が引く Lean の名前の実在、`sorry`・`axiom`・`native_decide`・`admit` の有無、追加した src の `#[allow]`・大域の状態・`as`・作業 ID のコメント、公開の文書と記録の手元の絶対パスを `git grep` と小さな Python で調べた（道具は scratchpad に置き、リポジトリを変えていない）。
- 実行していないこと: ビルド、テスト、`scripts/check.sh`、`scripts/check-formal.sh`、Lean のビルド、処理系の実行。本体の作業ツリーと `target/` は使っていない。`private/`・`docs/todo/` は読んでいない。リポジトリのファイルと git の状態は変えていない。

## 件数と判定

- 重大 0 件、中 2 件、軽 7 件。
- 判定: **条件付き受け入れ**。中1・中2 は Z01（Z01a・Z01b）の前か Z01 の中で閉じられる。言語の規則の変更、Lean の主な定理の前提・結論の変更、公理の追加を要する指摘はない。

区切りをまたいで照合し、食い違いがなかった主な点は次のとおりである（所見にはしない）。

- 予算: 本体の上限は各 100,000、検査全体は各 1,000,000、深さの fuel は 4096 である。02-05・英語リファレンス・`budget.rs`・`decls.rs` が一致する。項目の上限は同時保持に対するもので、英語の "simultaneously held" とも合う。
- `intervalAnalysis` の欄名と入れ子（`phaseStops.exceeded/unidentified` の四欄、`depth`・`other`、`usage` の五欄）: 06-01・02-05・英語リファレンス・inspection.md・`check_report.rs` が一致する。coverage の判定（本体なしは件数0の all、全本体が無効なら none、有効と無効が混じれば some、test 全体の集約、探索失敗と使い方の誤りは none、doc の例の探索が未完なら some）も `summary.rs` と test_runner の集約が設計どおりである。
- W0404 の対象: 27 宣言である。内訳は組み込み 20 と包み 7 で、整数 23 と Byte・UnsignedInteger8 の 4 に分かれる。01-04・02-05・03-06・07-04・`fixed_domain.rs` の `CONTRACTS`・英語リファレンス・標準ソースの冒頭の注記が一致する。操作と HTTP の欄を除く理由も、01-04・02-05・02-10・03-06・06-06・07-04・Skill で同じ文になっている。
- 診断の文言（W0401・W0402・W0404・R0906 の `component_handles`）: `diag/codes.rs` と生成された `diagnostics.md` が一致する。取っ手の上限 100,000 は `external/runtime.rs` の `COMPONENT_HANDLES` と `set_max_component_handles`、02-09・03-10・CHANGELOG と一致する。
- 依存: 二つの lock とも rustls 0.23.46、rustls-webpki 0.103.16、webpki-root-certs 1.0.10、wasmtime と内部クレートが 49.0.4、cranelift-codegen が 0.136.4 で、README の範囲どおりである。`deny.toml` の `[advisories]`（RustSec の `db-urls`、空の `ignore`）は 07-03 と一致する。`check.sh` の水準ごとの単位の一覧、`fuzz/Cargo.*` の分類、change・release での無条件の選択、`lint_default` の `--examples` は、07-03 と AGENTS.md と一致する。
- Lean: `analyzeBase_normal_sound : NormalSoundness Models analyzeBase` と `analyzeBase_warning_sound : WarningSoundness Models analyzeBase` の言明は、07-04 の説明（任意の環境・予算・評価。`Reached` に原因の一致を含めない）と一致する。`formal/` の Interval と IntervalDiff、`testdata/interval-budget/*.lean` に `sorry`・`axiom`・`native_decide` はない（`admit` は軽4）。`Benitoite.lean` が直接 import しない 7 モジュールも、ほかのモジュールを通して既定のビルドに入る。07-04・01-12 が引く定理名は、確かめた範囲ですべて Lean に実在する。
- 保証の範囲: 01-04・02-05・02-10・06-01・06-04・06-06・英語リファレンス・Skill はどれも、警告がないことや `coverage: all` を安全の証明と書いていない。評価関係との一致を全入力の意味の一致と書いてもいない。return の区間を比べていないこと（RV-X05 の中1）と externalType の除外に残る未比較の 14 件・14 件は、02-05・07-03・07-04・英語リファレンス・results.md で同じ限界として書かれている。
- リンク: 変えた文書の相対リンクと見出しの参照はすべて解決する（数式の `](…)` による誤検出だけ）。英語の文書と Skill から日本語の設計書・docs/todo・private/ へのリンクはない。版を固定した自リポジトリの URL は v0.0.11 と v0.0.12 のタグだけを指し、中間のコミットを指すものはない（v0.0.12 は軽7）。
- 実装の規約: 追加した src の `#![allow(...)]` は五つとも `#[cfg(test)]` のモジュールにある。一時的に置いた `dead_code` の許可は残っていない。大域の可変状態、`unsafe`、作業 ID や計画の文書を引くコメント、手元の絶対パスはない。`as` は i8〜u64 の定数の i128 への拡幅と、u64 の範囲を確かめた後の 1 箇所だけで、どちらも収まることが明らかであり、後者には理由のコメントがある。

## 所見

### 中1 改造の `security-advisories.md` がない（読めば確定）

- 場所: D の直下（ファイルがない）。参照する側は `AGENTS.md`「改造の進め方」の手順 2、`.claude/skills/security-advisories/SKILL.md` の 14〜15 行、`docs/workflow/change-plan-template.md` の 11 行と 67 行、`docs/workflow/implementation-request.md` の 14 行、D/plan.md の 813 行と 1450 行。
- 問題: この改造で加えた手順 2 とスキルは、照合日・対象・根拠・未照合の範囲・設計者の判断を「改造の `security-advisories.md`」に記録すると定める。スキルは、公開候補での再照合も「同じ改造の `security-advisories.md` に追記」すると定める。しかし D にこのファイルはない。最初の照合は preflight.md の「P2」の節、各段の結果は s01〜s05 の results.md に分かれている。plan.md の 1450 行も「security-advisories.md（今後の照合記録）」と書くだけで、作る作業を割り当てていない。このままでは Z01b の再照合に追記先がない。作ったばかりの規則に、この改造自身の記録が従っていないことにもなる。D/README の「文書の一覧」にも、記録先が書かれていない。
- 根拠: `ls` で D の直下にないことを確かめた。`git grep 'security-advisories.md'` の結果は上記の参照だけである。
- 修正案: Z01a か Z01b の手順に「D/security-advisories.md を作る」を加える。中身は、P2 の最初の照合（日付・対象・二つの lock と固定版・設計者の判断で TODO-284〜286 を組み込んだこと）、S01〜S05 の照合の要約と各 results.md へのリンク、未照合の範囲（ツールチェーンは Z01b で照合）を集め、候補での再照合をそこへ追記する。作らない場合は、移行中の例外として記録先（preflight の P2 と各 results.md）を README と plan の「前提と依存」に明記する。README の「文書の一覧」も、results.md・time-policy.md と合わせて直す。

### 中2 handle の訳語が章の中で二通りあり、新しい訳語「取っ手」の出典と選定の記録がない（読めば確定）

- 場所: `docs/design/00-overview/00-04-glossary.md` の「コンポーネントの取っ手」の行。`docs/design/03-interop/03-10-external-functions.md` の「各実行は Store・Instance・外部ハンドル・解放待ち・実行番号を新しく持つ」で始まる【決定】の段落。02-09「外部の関数の実行」、02-10 の R09nn の行と「実行時エラーと資源の不足の報告」。D/decisions.md の D28。
- 問題: 03-10 の同じ段落に、既存の「外部ハンドル」と、新しい「コンポーネントの取っ手（component handle）」が並んでいる。同じ英語の handle に別の語を当てている。用語集にも「取っ手」の行だけが加わり、「外部ハンドル」との違いを示していない。AGENTS.md「文章の規範」は、新しい術語について他の言語での呼び名と日本語での用例を調べて出典を添え、定着した訳語がなければ候補を示して設計者に選んでもらうことを求めている。D28 と README には、この語の出典の調べも設計者の選択もない。同じ節で加えた「到達記録（evaluation trace）」も、原語の用例の出典が記録にない（RV-C0 の軽8 の対応は、行を加えたことだけを記す）。
- 根拠: `git grep '取っ手'` は design の 4 ファイルに当たり、decisions.md の D28 には語の選定がない。`git grep '外部ハンドル'` は 02-09・02-11・03-10・06-04・07-04 に当たる。
- 修正案: Wasmtime と Component Model の文書の用法（resource handle、handle table など）と、日本語の用例（「ハンドル」が多いと見込むが未確認）を調べて出典を添え、「取っ手」「ハンドル」、または原語のままのどれにするかを設計者に選んでもらう。結果に合わせて、用語集・02-09・02-10・03-10 の語をそろえ、「外部ハンドル」との違いを用語集の定義に書く。「到達記録」の原語 evaluation trace にも用例の出典を添える。言語の規則と Lean には影響しない。

### 軽1 01-12 の区間解析の節に処理系の実装方式の記述が加わった（読めば確定）

- 場所: `docs/design/01-spec/01-12-core-calculus.md` の「区間解析の定数倍」（1676 行。「端点と加減算・符号付き定数倍の中間値は i128 で表す。UnsignedInteger64 の積は u128 で計算し…」）、「区間解析の本体の識別と元の出現の対応」（1756 行。「元 AST の NodeId・UTF-8 のバイト範囲は Rust の対応表にだけ保存する」）、「区間解析の予算付きの式とフロー」（2280 行。「処理系が使う本体の入口」）。
- 問題: AGENTS.md は 01-spec に処理系の実装方式を書かないと定めている。01-12 には B0 の時点でも Rust の交換に触れる文があった（`Rust|i128|JSON|NodeId` の行は 15 から 41 へ増えた）。ただし、i128・u128 の表現と、Rust の対応表への保存は実装の決定であり、02-05「区間解析の閉区間の領域」が同じことをすでに定めている。
- 修正案: 1676 行の i128・u128 の段落と、1756 行の Rust の対応表の一文を 02-05 か 07-04「区間解析の独立交換の読者」へ移し、01-12 には「Lean の Int で表し、処理系の整数表現との一致は結論しない」だけを残す。2280 行は「交換と処理系の比較が使う本体の入口」と書けば、実装方式に依存しない。

### 軽2 Skill の警告の例は検査されないのに「この完全なスクリプトが三つの警告を出す」と断定している（要再現）

- 場所: `crates/benitoite/skill/references/idioms.md`「Explaining local interval warnings」の最初の例と、その後の表（W0401 `[0,0]`、W0402 `[130,137]`、W0404 `[64,9223372036854775807]`）。
- 問題: 例は ` ```text ` で囲まれているので、`tests/skill_examples.rs` は読まない。W0404 の `x >= 64` の場合は `tests/cli_process.rs` の "comparison" が同じ区間を確かめている。しかし、`divisor = 0` の枝の W0401 と、Integer8 の `value >= 120s8` からの W0402 は、この形のままでは検査されていないと見込む。この例は LLM が警告の説明の手本にするので、診断の文言や区間の表示が変わったときに食い違いを検出できない。
- 修正案: 例と期待する三つの診断（コード・一次位置・注記の区間）を、`testdata/warnings/` のゴールデンテストか cli_process の表に加え、Skill の例と同じ本文であることを確かめるテストを置く。または、警告を許す囲みの種類が skill_examples にあればそれを使う。

### 軽3 W0401・W0402 の診断は区間が取れないと `[0,0]` を表示する（机上の反例、要再現）

- 場所: `crates/benitoite/src/typeck/interval/diagnostics.rs` の `diagnostic`（145 行の `candidate.right.bounds().unwrap_or((0, 0))`、162 行の `bounds.map_or_else(|| interval(0, 0), …)`）。
- 問題: W0404 の枝は、Bottom・Top・交差の場合に `None` を返して診断を作らない。W0401 と W0402 の枝は、区間が取れないと `[0,0]` という具体的な区間を注記に入れる。区間が取れない候補は起きないはずの状態と見込むが、起きた場合は誤った区間を事実として利用者と LLM へ示す（W0402 では「結果区間が [0,0] なので溢れる」と読める）。02-10 の「推論した閉区間を注記に示す」とも合わない。
- 修正案: W0404 と同じく `?` で `None` を返し、候補を捨てる。区間が取れない候補を作らないことを不変条件としてテストで固定する。

### 軽4 Lean の `private def admit` が、証明の穴を探す grep に誤って当たる（読めば確定）

- 場所: `formal/Benitoite/Interval/Budget.lean` の 118 行（`private def admit`）と、その参照（137・146・181〜188・260〜282 行）。
- 問題: `admit` は Lean の証明の穴の戦術の名前でもある。ここでは関数の名前なので健全性への影響はない。しかし、`sorry` と並べて `admit` を grep する点検は誤検出をし、見た人は確かめ直す手間を負う。
- 修正案: `admitStep` などに改名する。急がない。

### 軽5 公開のテストデータに手元の絶対パスが残っている（読めば確定。0.0.11 から存在）

- 場所: `crates/benitoite/tests/desugar_export/exchange-manifest.json` の 1710・3811・3823 行と、`routing-manifest.json` の 1355・3116・3126 行（`"entry: NoMainFile { dir: \"/Users/<user>/src/Benitoite/crates/benitoite/testdata/…\" }"`）。
- 問題: B0 でも同じ 3 件ずつがあり、本改造は増やしていない。ただし本改造は exchange-manifest.json を作り直しており、作り直しの経路が、誤りの文に含まれる絶対パスをそのまま固定している。D の記録ではパスを `<repo>` などに伏せる決まりがあるが、公開のテストデータは対象外になっている。
- 修正案: 本改造の範囲外として docs/todo に項目を加える。書き出しの側で、リポジトリの根からの相対パスにするか `<repo>` に伏せる。

### 軽6 01-04 の「前提」の節に規範の【決定】が増えた（読めば確定。既存の構成）

- 場所: `docs/design/01-spec/01-04-types-basic.md` の「## 前提」（9〜43 行）。
- 問題: 算術の実行時エラーの二段の扱いは、B0 でも「前提」の節にあった。本改造は、区間解析で警告してよい条件（W0401・W0402・W0404）という規範をそこへ加えた。章の構成（目的と範囲・前提・仕様）からは、規範は「仕様」に置くのが自然である。02-05 と 06-01 からは `01-04-types-basic.md#前提` へリンクしている。
- 修正案: 急がない。次に 01-04 を直すときに「仕様」の下へ節（例:「算術の失敗の警告」）を立てて移し、02-05 と 06-01 のリンクを直す。見出しを参照するテストの印と道具は、`git grep` で確かめる。

### 軽7 Z01 への引き継ぎ: CHANGELOG と v0.0.12 のリンク（読めば確定。計画では Z01 の担当）

- 場所: `CHANGELOG.md` の「Unreleased」、`crates/benitoite/skill/references/inspection.md` の最後の段落（`blob/v0.0.12/docs/reference/benitoite.md#interval-analysis-coverage` と `#local-interval-warnings`）。
- 問題: Unreleased には依存の更新と勧告の照合だけがある。中心の区間解析（W0401・W0402 の拡張、W0404、`intervalAnalysis`）、`Log.formatRecord` の公開、derive の JSON・Property の事前拒否、`--deny-warnings` で受理が変わりうること、取っ手の上限による受理範囲の縮小（BREAKING_CHANGES の要否は Z01a が判断）がまだない。inspection.md は、まだないタグ v0.0.12 を指している。plan.md の 1203〜1216 行が Z01 に割り当てているので誤りではないが、取りこぼすと Skill が存在しない版を案内する。
- 修正案: Z01b の照合の表に、「Unreleased の各項目が README の三案と相乗りの項目をすべて覆うこと」と、「タグを付けた後に v0.0.12 の二つの見出しが解決すること」を加える。06-09 の互換性の表に 0.0.12 の行を加えるかどうかも、Z01a の BREAKING_CHANGES の判断と同じ場所に記録する。
