# RV5 0.0.10 のリリース候補の最後のレビュー（改造全体と Z3〜Z8・M1・V1・Q1・Q2）

## 対象と方法

- 対象:
  - 改造全体 `git diff c31e64b03d2810343e1779926bea4ebc958b6164..98c3572a`（ブランチ san_benito、HEAD `98c3572a`）。
  - 中心は RV4 の後の取り込み（`git log --first-parent e9de51fc..98c3572a`）の Z3・Z4・M1・V1・Z5・Z6・Z7・Z8・Q1・Q2 と、改造全体としての整合である。RV4 までに見た細部は繰り返さない。
- 読んだもの:
  - AGENTS.md（設計書の規約・レビューの観点・実装の規約）
  - D の README.md、todo-items.md、design.md（11・13・15 節ほか）、plan.md（RV5 の行、「改造末の全件・形式化・測定・release」の表と手動照合の段落）、decisions.md（R198〜R221）、results.md
  - reviews/ の RV4.md・RV4-response.md・RV4-check-response.md
  - z3・z4・z7・z8・m1・v1・q1・q2 の results.md（q2 は evidence.json の一部も）
  - オーケストレータの一時ログ `work/m010/final-logs/`（chain・release・formal・change-rest・perf-short）と、追跡する測定記録 `tools/bench/results/2026-10-21-270a717c-comparison/`
  - Z3・Z4・Z7 の Rust の差分、CHANGELOG、docs/reference と docs/ja の英日、同梱の Skill（SKILL.md・references）と docs/ja/skill、docs/design の差分、formal/README.md
- 実行したこと:
  - `git diff --name-only` で、270a717c の後の変更の範囲と、76ed2d5e→270a717c の Rust の差分を確かめた。
  - `cargo build --release -p benitoite` で作った `./target/release/benitoite` に、`work/m010/reviews/rv5-scratch/` の小さな .bnt を与えた（rec1.bnt・int1.bnt・log1.bnt。`run` と `check`）。
  - `cargo test -p benitoite --lib` に Z3・Z4 のテスト 6 件を名指しして実行した（6 件成功）。
- しなかったこと:
  - cargo test の全件、scripts/check.sh、scripts/check-formal.sh、lake build、性能の測定
  - 0.0.9 のビルドと、移行の前後の再実行（Q2 の記録を読んで確かめた）
  - SHA-256 の再計算と、Linux での実行
- 所見ごとに、確かめた事実か推測かを記す。docs/todo は読めないので、TODO の判断は D の記録による。

件数は重 0・中 3・軽 5 である。

## 中

### 中1 同梱の Skill と日本語の訳が、予約語 block を反映していない（V1、確かめた事実）

- 場所:
  - `crates/benitoite/skill/SKILL.md` の 91 行「There are 35 keywords」。同じ行は `die` の予約だけを述べ、`block` の予約に触れない。
  - `docs/ja/skill/SKILL.md` の 98 行「キーワードは 35 語ある」。
  - `docs/ja/skill/references/common-mistakes.md` の 124 行（`end block` がない）と 470 行（「次の 35 語」。`block` がなく、`record` を名前に使える例外もない）。冒頭の注記は「翻訳元は Benitoite 0.0.10 の英語版」としている。
- 問題点:
  - 英語の `references/common-mistakes.md` の 467 行と生成の grammar は 36 語とし、`block` を含める。SKILL.md の本文だけが 35 語のままである。
  - `block` の予約は 0.0.10 の主な非互換の変更である。SKILL.md は LLM が最初に読む文書であり、そこに予約の記述がない。
  - 日本語の common-mistakes は、版の注記だけを 0.0.10 に替え、キーワードの段落と終端の語の一覧を訳し直していない。Q2 の「日本語Skillの手書き五文書も翻訳元0.0.10」という確認は、注記の照合にとどまる。
- 失敗の筋書き:
  - LLM が SKILL.md の「35 keywords」と 0.0.9 の知識から、`bind block <- …` のような名前を書く。E0216 で拒否される（Q2 が 0.0.10 で確かめた振る舞い）。往復が一回増える。
  - 設計者が日本語の訳を読み、キーワードは 35 語で `record` は名前にできないと受け取る。英語の版と食い違う。
- 修正案:
  - SKILL.md の 91 行を「There are 36 keywords; … `block` is reserved, including labels and names after a dot (E0216). `record` is also accepted where a lowercase name is required.」の趣旨に直す。
  - docs/ja/skill/SKILL.md の 98 行と、common-mistakes の 124 行・470 行を英語の版に合わせて訳し直す。
  - 手書きの五文書の英日で、キーワードの数と一覧を照合する検査（skill_docs の一項目か、Q2 の照合の項目）を足すとよい。

### 中2 設計書と formal の案内に、Lean 先行段・V1 時点の「Rust は未実装・全比較は未実施」が残る（L2・V1、確かめた事実）

- 場所:
  - `docs/design/01-spec/01-12-core-calculus.md` の 233 行「現在の Rust の整数の判定は常に `other` を残すため、この全域の判定は Lean 側に実装した範囲である」（L2 の c400efe0 で入った）。
  - `docs/design/07-quality/07-04-formal-semantics.md` の 156 行「Rustの全交換比較は未実施であり」と、289 行（対象外の表の「交換13/5の独立入力と旧版の拒否」）の「Rustの全比較は未実施とする」。
  - `formal/README.md` の 297 行「版全体の全比較は未実施である」と 369 行「全比較と正式接続の宣言は、V1後に取りまとめがcheck-formal.sh全体で行う」。
  - `formal/tests/batch4-exchange/README.md` の 51 行「全比較はV1後に取りまとめが行う」。
- 問題点:
  - TODO-191 の Rust の実装は T1 で入った。`rv5-scratch/int1.bnt`（Integer の両端までの三つの区間だけで `match` を書いた入力）は、今の CLI で `run` が成功した。Q2 も全域の後の catch-all が E0602 になることを確かめている。01-12 の文はこれと逆のことを述べる。
  - 六入口の全比較は、results.md の「check-formal 全体」の 2 回目（76ed2d5e、終了 0）で済んでいる。07-04 と formal の案内はこれを反映していない。
  - formal の案内は「V1」「取りまとめ」という改造の作業の名前を、保管の後も残る現役の文書に書いている。
  - AGENTS.md の設計書の規約（今の実装だけを書く）と、計画の RV5 の行「設計書が今の実装と一致」に反する。
- 失敗の筋書き:
  - 次の改造で 01-12 を読んだ実装担当が、Rust の Integer の網羅性の判定は全域を扱わないと受け取り、重複した実装や誤った移行を計画する。
  - 07-04 を保証の範囲の正として読む利用者・レビュー担当が、0.0.10 の形式化の接続は閉じていないと判断する。
- 修正案:
  - 01-12 の 233 行の後半を「Rust の判定も同じ全域の規則を実装し、六入口の全比較で一致を確かめている」の趣旨に直す。
  - 07-04 の 156 行と 289 行を、全比較の結果（2026-10-21、件数）を書く形か、「全比較は check-formal.sh で行う」という現在形に直す。
  - formal/README.md と batch4-exchange/README.md から「V1後に取りまとめが」を除き、全比較の入口と結果を現在形で書く。
  - `git grep -E "未実施|未接続|取りまとめ|V1後"` を、保管の前の点検項目に加える。

### 中3 targets の本測定を保留した扱いと、その行き先が記録されていない（取りまとめ・Q2、確かめた事実）

- 場所:
  - plan.md の 479 行（性能 targets の行）と 493 行「shortとtargetsを必須とする」。RV5 の行（383 行）も targets を確認の対象に挙げる。
  - results.md の 87 行「計画のtargetsの本測定は設計者の判断で行わない」。
  - decisions.md の R217〜R221 には、targets を行わない判断、性能の対策を docs/todo の TODO-275 へ回す判断、CHANGELOG に性能の増減を書かない方針のどれも R 番号として載っていない。
- 問題点:
  - 設計者の判断そのものは指摘しない。ただし、計画が必須とした段を外す判断が、計画の表にも決定の記録にも反映されていない。results.md の散文と q2/results.md にだけある。
  - TODO-275 へ回すと書かれたのは、short の退行（Q1 の G2 の型検査の索引の作り直しなど）である。targets の 166 点・55 目標（bench-targets.json）を測らずに残したことの行き先は、どこにも書かれていない。
  - targets には、TODO-248 の残る論点の三つめ（三種類の構築器の追記・短い構築・copy の費用の測定。todo-items.md 20 行、design 15.2）と、TODO-032 の数値目標の判定が含まれる。行き先がないと、これらの TODO を閉じてよいか判断できない。
  - bench-targets.json と design 15 節は D にあり、改造を閉じると docs/archive/ へ移る。後の測定の担当が入力の場所を知る手掛かりが、記録に残らない。
  - CHANGELOG の 34 行「Six-entry full comparison and performance acceptance belong to the final integration checks」は、性能の受け入れが行われるかのように読める。実際は targets を行っていない（軽2 でも扱う）。
- 失敗の筋書き:
  - docs/todo で TODO-248 を「完了」として閉じる。構築器の専用バッファの速さを確かめる測定は、どの項目にも残らずに失われる。
  - 後の性能の改造が、0.0.10 の目標の式と入力を作り直す。
- 修正案:
  - decisions.md に R222 を足し、設計者の三つの判断（targets を行わない、性能の対策を docs/todo の TODO-275 へ回す、CHANGELOG に性能の増減を書かない）と、その理由・日付を記す。
  - plan.md の 479 行・493 行に「設計者の判断で本測定を行わない（R222）」と注記する。
  - results.md の性能の節に、targets の行き先（例: docs/todo の TODO-275 に、bench-targets.json の SHA-256 `88f5fcf2…` と保管先のパス、design 15 節を写す）を書く。
  - CHANGELOG の 34 行の該当の文を除く（軽2）。

## 軽

### 軽1 移行案内のリンクの付け替えの記録が、CHANGELOG だけを名指ししている（V1・Q2、確かめた事実）

- 場所:
  - `docs/reference/benitoite.md` の 1796 行と `docs/ja/reference/benitoite.md` の 1698 行。どちらも `docs/2026-10-19-TODO-…-syntax-batch4/historical-tools/named-arguments-migrate/README.md` へリンクしている。
  - q2/results.md の 100 行は、付け替えが要るものとして CHANGELOG の移行の表だけを挙げる。
  - v1/results.md の 69 行は「今回の移行案内からhistorical-toolsへのリンクも実際の保管先へ更新する」と一般的に書く。
- 問題点:
  - 付け替えの必要自体は V1 の申し送りに記録されている（設計者の決定どおり）。
  - ただし、最後の記録である Q2 が CHANGELOG だけを名指ししているので、英日のリファレンスの 2 か所が漏れやすい。今はどのリンクも切れていない。
- 失敗の筋書き: オーケストレータが q2/results.md に従って CHANGELOG だけを直し、`git mv` の後に英日のリファレンスのリンクが切れる。
- 修正案:
  - q2/results.md か results.md に、付け替える 3 か所（CHANGELOG の 19 行、docs/reference/benitoite.md の 1796 行、docs/ja/reference/benitoite.md の 1698 行）を一覧で書く。
  - 保管の後に、`git grep "2026-10-19-TODO-"` で D への参照が保管先を指すことを確かめる。

### 軽2 CHANGELOG の 0.0.10 の節に、長すぎる行と内部の手続きの文がある（V1、確かめた事実）

- 場所: CHANGELOG.md の 13〜19 行（移行の表）、25 行（Log の項目）、34 行（内部交換の項目）。
- 問題点:
  - 移行の表の一つのセルに 4〜8 文を詰めている（特に 14・15・16・18 行）。手順と例外と背景が混ざり、利用者も LLM も何をすればよいかを拾いにくい。
  - 0.0.9 の節と違い、`block`・`Log`・`uses Log`・`--allow-effects` などをコードの書式にしていない。検索も、文と名前の区別もしにくい。
  - 34 行の「Six-entry full comparison and performance acceptance belong to the final integration checks; local work results alone do not establish them.」は、開発の作業の段取りの文である。利用者向けではなく、今の状態とも合わない（中3）。
  - 0.0.9 の節の末尾にある、導入の手順・日本語の訳への案内と保証の範囲の一文がない。
- 書き直しの案（意味を変えず、一つの文に一つのことを書く）:
  - 13 行の block:
    - 0.0.10 の欄: 「`block` is now a keyword. `block ... end block` is an expression whose value is its last expression (Unit if it is empty or ends with `bind`). It does not change where `return` returns. Using `block` as a name, label, or name after a dot reports E0216.」
    - 移行の欄: 「Rename identifiers named `block`.」
    - 「Use blocks for local work such as builder construction」は、Builders の箇条へ移す。
  - 14 行の Integer:
    - 0.0.10 の欄: 「Ranges that cover every 64-bit `Integer` value are exhaustive. A catch-all after them is unreachable (E0602). If a value is missing, E0601 shows it.」
    - 移行の欄: 「Remove the unreachable catch-all, or fix the ranges. Gaps and guarded ranges still need a catch-all.」
  - 15 行の language:
    - 0.0.10 の欄: 「`language "0.0.9"` and earlier report E0908 with the migration notes. `0.0.10` is accepted. Later versions report E0907.」
    - 移行の欄: 「1. Migrate the source. 2. Set `language "0.0.10"`. 3. Run `benitoite package update` after dependencies are final. Omitting `language` does not migrate code.」
  - 16 行の prelude:
    - 0.0.10 の欄: 「`Log` and `SourceLocation` are in the prelude. `Log` cannot be renamed with `as` (E0339); `SourceLocation` can.」
    - 移行の欄: 「Rename conflicting user names. Call `SourceLocation.here()` directly where the location is needed. A wrapper should take a `Location` argument. Using `here` as a value, hole, or pipe reports E0467.」
  - 18 行の derive:
    - 0.0.10 の欄: 「Records, manifests and receipts use version 3 (`generatorVersion` `3.0.0-syntax-batch4`). Inventory 2, configuration 1 and `Property.libraryVersion` 2.0.0 are unchanged.」
    - 移行の欄: 「1. Finish any pending old apply with the old tool. 2. Check old body hashes. 3. Run a new `preview` and review its diff and record. 4. `apply` with that manifest's SHA-256. 5. Run `check`, `test` and `derive check`. Old manifests cannot approve a new apply. A seed alone does not reproduce old results.」
  - 25 行の Log は、四つの箇条に分ける:
    - 「`Log` is a new effect. `IO.All` and `Console.Write` do not include it. Declare `uses Log`, and add `Log` to `--allow-effects` when you use that option.」
    - 「Without a handler, Info and higher go to stderr. `Log.error` does not stop the program.」
    - 「Arguments are evaluated even when the level is disabled. Check `Log.enabled` before expensive work.」
    - 「A handler must handle both `emit` and `enabled` to remove `Log`. `withTextLogger` needs `Console.Write`. `withAttributes` passes `Log` on. `withSinks` keeps the sinks' effects.」
  - 34 行: 最後の文を除き、「Development tools: the internal exchange format is now corpus 13 / sidecar 5. Regenerate old corpus-12 files that contain builders.」程度にする。
  - 節の末尾に、0.0.9 と同じ形で導入の手順（`docs/reference/install.md#updating-from-009-to-0010`）と日本語の訳への案内を一文で足す。
- 失敗の筋書き: 利用者や LLM が長いセルの途中の例外（例: 「Keep coverage for gaps and guarded ranges」）を読み落とし、穴のある区間の catch-all まで消して E0601 になる。

### 軽3 利用者の文書に載らない変更が二つある（G1・H2、確かめた事実）

- `record` を名前に使えること:
  - 01-01 のキーワードの節（36 語、`record` 以外は識別子に使えない）と、生成の grammar・英語の common-mistakes には書かれている。
  - CHANGELOG と docs/reference（英日）には書かれていない。docs/reference の Log の節は「The sink callback takes `record`」と書くが、`record` を引数名に使えるという規則は示さない。
  - 制限を緩める変更なので、非互換ではない。ただし利用者・LLM が Log の API を写すときの前提になる。
- `--wasm-stats` の新しい欄:
  - `crates/benitoite/src/external/stats.rs` の 252〜254 行は、`runtime_compilations`（normal・adapter）と、test の `test_declaration_compilations` を出力に加える。0.0.9 の stats.rs にこれらの欄はない（`git grep` で確かめた）。
  - 設計書 03-10 には意味が書かれている。docs/reference の 2072 行の欄の一覧、Skill の idioms.md の 833 行、CHANGELOG には載っていない。
  - Q2 の照合と測定器は、これらの欄に頼っている。
- 修正案:
  - CHANGELOG の「Builders, logging, and checked values」か新しい「Other changes」の箇条に、`record` を名前に使えることと、`--wasm-stats` の二つの欄を一文ずつ書く。
  - docs/reference の字句の節と 2072 行に同じことを足し、日本語の訳も直す。idioms.md の 833 行にも欄の名前を足す。

### 軽4 results.md の引用の理由と性能の記録に、細かい不正確がある（Q2、確かめた事実）

- 場所: results.md の 101 行と 106 行、91 行。
- 問題点:
  - 106 行は「bench比較器の変更はこれらの検査が実行しない範囲である」とする。しかし change の単位の python_syntax は `tools/bench/compare/*.py` の構文を検査する（`scripts/check.sh` の 247 行）。結論は変わらない。Z8 の作業末の work で python_syntax を通しており（z8/results.md）、その後に compare の Python は変わっていないためである。理由をこの事実に替えるべきである。
  - 101 行は 270a717c の後の変更を「Z8（tools/bench/compareの6ファイルと測定記録…）」とする。git では、測定記録の 35 ファイルは Q1 の取り込み（d37792d6）で入っている。
  - 91 行は「66点中65点に退行の疑い」とだけ書く。残る 1 点（`bridge-shared-8`）は alerts.json で「判定不能」（入力不足・標本数不足・ぶれ以下）である。計画の RV5 の行は、判定不能の扱いの記録を求めている。
- 修正案: 上の三点を results.md の該当の文で直す。三つめは「残る1点（bridge-shared-8）は判定不能」と一文足せばよい。

### 軽5 改造を閉じる作業の点検項目に、候補の ID と D の文書の更新が入っていない（取りまとめ、確かめた事実）

- 場所:
  - results.md の 97 行（手動照合は HEAD e6247c11 の CLI で行った）。
  - q2/results.md の 12 行と 14 行。`--version=json` の build.commit と、`skill list/show` の producer が候補のコミットを含む。
  - D の README.md の 31 行「実装・証明・性能の成功を報告する段階ではない。実装開始の指示は別に受ける」。
- 問題点:
  - RV5 への対応、リンクの付け替え（軽1）、保管の `git mv` で、公開するコミットは e6247c11 とも 98c3572a とも違うものになる。そのコミットで確かめ直す項目（`--version=json` の commit、Skill の producer、skill_generated、D へのリンクの消失）が記録されていない。
  - D の README.md の「状態と判断の基準」は P2 の時点のままである。保管すると、この改造の結論（入ったもの、保留した targets、TODO の扱い）を README から読めない。
  - 15 件の TODO のうち、どれを閉じ、どれの残りをどこへ回すかの一覧が D にない。AGENTS.md の「改造の進め方」の 4 の作業の入力になるものである。
- 修正案:
  - results.md に「最終の候補での確認」の節を置き、確かめ直す項目と、処理系に差分がないことを示す `git diff <e6247c11> <最終の候補> -- crates Cargo.toml Cargo.lock formal scripts tools` を書く。
  - D の README.md の状態の節を、完了の時点の要約に替える。
  - 下の「閉じてよい TODO と、新しい TODO に回すもの」を D に写す。

## 閉じてよい TODO と、新しい TODO に回すもの

docs/todo は読めないので、D の README.md・todo-items.md・design.md・各作業の結果から判断した。「閉じてよい」は、todo-items.md の論点が設計書・実装・テスト・利用者の文書に揃って入ったものである。

| TODO | 入ったもの | 判断 | 残り・回す先 |
|---|---|---|---|
| B17（TODO ではない） | block の式（01-01・01-02・用語集、L5・B3、英日・Skill・CHANGELOG） | 完了 | Skill の予約の記述（中1） |
| 248 | 局所の構築器のエフェクトを外す規則（Lean L3a〜L4b、B2）、三種類の専用バッファ、R0907、copy の物理コピー | 規則と実装は閉じてよい | 三種類の費用の測定（todo-items.md 20 行、design 15.2、bench-targets 16.5）は未実施。TODO-275 か新しい項目へ（中3） |
| 206 | 組み込みの Log、既定の出力、`SourceLocation.here()`、許可・報告 | 方針 1・2 は閉じてよい | 方針 3 の暗黙のエフェクト（README 27 行で対象外）、TODO-023 との関係、ファイルを捕える出力先・JSON の出力先の確認。TODO-206 を縮めて残すか、暗黙のエフェクトを新しい項目へ |
| 191 | Integer 全域の網羅性（Lean L1・L2、T1、移行、E0602） | 閉じてよい | 01-12 の古い文を先に直す（中2） |
| 022 | 長さ・添字・非空の検査済みの値（G3、03-06、英日・Skill） | 一部だけ。閉じない | 静的な篩型、SMT の採否、形式化への影響。TODO-022 を残す（TODO-142 と合わせて） |
| 087 | 再帰・型パラメータのレコードの生成器・縮小器と Show/Order（G4・G5、版 3 の記録） | 一部だけ。閉じない | 専用の Property の実行（CLI。P6 で見送り）、テストと実行時の権限制御の関係。TODO-087 を縮めて残す |
| 032 | 列挙・指数的な照合・自由変数の再走査・ir/check の環境の複製（design 9.1〜9.4） | 列挙した四つの処理は閉じてよい | 数値目標の判定（TODO-262 の本測定）と、約 1.1 秒の残りの確認は未実施。short では関数の多い入力の検査が 0.0.9 の約 2 倍になった（Q1、G2）。TODO-262 と TODO-275 へ |
| 200 | 判定の木の共有と、上限を超えた match の行ごとの照合（T3） | 閉じてよい | 最終の資源制限（L0112）は設計どおり残る |
| 226 | 宣言由来の偽の診断の整理（T5・Z2） | 閉じてよい | 誤りの式を束縛した名前の型が後の注釈で決まり、さらに後の使用で E0401 が出る限界（R202、02-04 に明記）は新しい項目へ |
| 227 | 同名の別の型の表示（T5） | 閉じてよい | なし |
| 246 | 幅付き整数の標準関数への W0401・W0402（T5） | 閉じてよい | なし |
| 192 | 穴ごとの余分な Let の除去（Lean 先行、T2、全比較で一致） | 閉じてよい | なし。Let の数の測定は targets の一部だが、交換の比較とテストで減ることを確かめている |
| 253 | 旧移行道具の保管（G6） | 閉じてよい | 保管の移動のときに 3 か所のリンクを付け替える（軽1） |
| 168 | Writer の解放と二度目の中断のテスト（G7） | 閉じてよい | Linux での同期は未確認（design 11.2）。Linux の検査を扱う項目があればそこへ、なければ新しい項目へ |
| 222 | 参照インタプリタの変換での共有の保存（H1） | 閉じてよい | なし |
| 229 | test 起動での Engine・Component の共有（H2） | 閉じてよい | テストの並行実行との関係は TODO-219 の側に残る。`--wasm-stats` の新しい欄の文書（軽3） |
| 262（15 件の外） | builders 族の requires・import の修正だけ（M1） | 閉じない | 四状態の本測定は残る |

新しく docs/todo に置く（または既存の項目に足す）もの:

- docs/todo の TODO-275: G2 の型クラスの実装の索引の作り直し、T5 の前後の小さな増加。0.0.10 の targets（bench-targets.json の 166 点・55 目標）をここで測るかも決める（中3）。
- 誤りの式からの回復の限界（R202）。
- G7 の FIFO の同期の Linux での確認（既存の項目がなければ）。

## 確認した内容（指摘なし）

### 1. 270a717c の後の変更が処理系を変えていないこと

確かめた事実:

- `git diff --name-only 270a717c 98c3572a` のうち、D の外は `tools/bench/compare/` の 6 ファイルと `tools/bench/results/2026-10-21-270a717c-comparison/` だけである。crates・Cargo.toml・Cargo.lock・formal・scripts に差分はない。
- 取り込みごとの範囲:
  - Z8（270a717c→9cce9775）: compare の 6 ファイルと D だけ。
  - Q1（9cce9775→e6247c11）: 測定記録と D だけ。
  - Q2（e6247c11→98c3572a）: D の 4 ファイル（decisions.md・results.md・q2/results.md・q2/evidence.json）だけ。
- 76ed2d5e→270a717c の crates の差分は `src/ir/decision.rs` だけである。読んだ限り、意味は変わっていない。
  - `emit_jump` は元と同じ `made(LCompKind::Jump …)` を返す。
  - `finish_length`・`finish_gets` は、子を下ろした後に同じ構築を行うだけである。
  - 組み立ての順序・値・エフェクトは同じである。
- check-formal の比較は、脱糖と網羅性（判定の木への変換の前）を対象とする。このため、76ed2d5e の 2 回目の全体の結果を 270a717c と今の HEAD へ引用する理由は成り立つ。

### 2. 証拠と記録の一致

確かめた事実:

- chain のログと results.md の記述が一致する。
  - formal: 9b4012b8 で終了 1・876 秒、76ed2d5e で終了 0・1,120 秒。
  - change: 76ed2d5e で終了 1・3,229 秒。change-rest: 270a717c で終了 0・1,979 秒。
  - release: 270a717c で終了 0・150 秒。
- release のログ: release_stack の 10 件が成功し、「Release acceptance remains pending」で終わる。
- change-rest のログの先頭の選択: lint_heap・long_only・heap_checks・formal_build の 4 単位である。
- formal のログの件数が results.md と一致する。
  - 表層: 一致 51,725・対象外 19・Q11 1。
  - 最後の照合: 1,789 入力・73,836 定義・Coverage 22,482。
- short:
  - perf-short.log の節ごとの件数（15+11+17+11+8+1+1+1+1）は 66 点である。
  - alerts.json は 65 点が退行の疑い、1 点が判定不能である（軽4）。
- 性能の扱いは設計者の決定どおりである。
  - CHANGELOG に性能の数値・増減はない。
  - results.md は docs/todo を「docs/todoのTODO-275」と文字で書き、リンクしていない。
- 版: crates/benitoite/Cargo.toml と Cargo.lock が 0.0.10、CHANGELOG の先頭の節も 0.0.10 である。Cargo.lock の差分は自身の版だけである。

### 3. Z3・Z4・Z7 の直し

- Z3 の record の改行（`newline.rs`・`items.rs`）:
  - 字句の段の規則から `record` を外し、宣言の構文解析だけで型名の前の改行を読み飛ばす最小の変更である。
  - 確かめた事実: `rv5-scratch/rec1.bnt` で次の三つが通り、`run` は 2 と 2 を出した。
    - `record` と型名の間の改行
    - `bind z <- record` の次の行を大文字で始める形
    - `record` を引数名・束縛名に使う形
  - 名指しのテスト（値の文の区切り、宣言の改行、欄名の拒否）も成功した。
- Z4 の診断の抑制:
  - E0433 は `Expr::Error` だけを `bad_shape` から外した。独立した式の E0433 は残る。
  - W0501 は、本体に誤りの式を含む関数だけで止める。`consts::visit_block` は、ブロックを持つすべての式（match のガード、with の束縛、handle の節、block、lazy、lambda、try の die の説明）を辿る。このため、誤りの式を見落として不完全なエフェクトから修正案を出す経路は見当たらない。
- Z4 の Log の修正案:
  - 確かめた事実: `rv5-scratch/log1.bnt` で、利用者の `record Log` が Log を隠すと、W0501 と E0501 は `uses Benitoite.Log` を勧めた。その修正を当てると、`check` は成功した。
  - 名指しのテスト 3 件も成功した。
- Z7: 上の 1 のとおり意味を変えない分割である。測定と 02-01・AGENTS.md の数値（13,959,168 バイト、約 13.3 MiB）は z7/results.md の記録と一致する。

### 4. 設計書の規約

- docs/design に【未決】【要検証】はない。
- 次のリンクはない。
  - docs/design・docs/reference・docs/ja・CHANGELOG・Skill・tools・AGENTS.md から docs/todo へのリンク
  - 設計書の章から改造のディレクトリへのリンク
- 用語集の「ブロック式」の項と、引いている見出し（01-02「ブロック式」、02-04「位置の式の事前展開」、02-05「警告」「誤りの報告と検査の継続」）は存在する。
- 02-01 の段の止め方の例外（E0467 の後も型検査を続ける）は、02-04 の記述と実装（`source_location.rs` の置き換え）に一致する。

### 5. 組込み向けの構成を損なう変更がないこと

確かめた事実:

- Cargo.toml と Cargo.lock の依存は変わっていない（自身の版だけ）。機能の一覧も変わっていない。
- このリポジトリに tiny という名前の機能・構成はない。そのため、条件そのもの（大きな依存を足していないこと、64 ビットだけを前提にしないこと）で確かめた。
- 構築器のバッファの大きさの計算は、次の形を使う。
  - `usize::try_from`
  - checked の演算
  - `isize::MAX` の上限
- 番地の `as usize` は、識別のキーにだけ使う（H1）。32 ビットでも成り立つ。
- 追加の行に、大域の可変状態（thread_local!・static mut・OnceLock）はない。
- 追加の行の unwrap・panic は、見た範囲ではテストの補助の中のものだけである（推測を含む。全行は確かめていない。change の lint_default・lint_heap の成功とは合う）。

### 6. 英日と移行案内

- install の英日は、0.0.10 がソースだけの版であることと、0.0.9 からの更新の手順（block、Integer、Log の許可、derive の版 3、旧道具の場所）をそろえて書いている。
- 英日のリファレンスの見出しの数は 69 と 69、install は 15 と 15 で一致する。
- Log の節を一つ抜き出して比べ、内容が一致することを確かめた。
- 移行の前後の実行は、Q2 の記録（0.0.9 で前の形が終了 0、0.0.10 で後の形が終了 0、前の形が E0216・E0602・E0908）を読んで確かめた。旧 `uses State` が受理されることも、同じ記録にある。
