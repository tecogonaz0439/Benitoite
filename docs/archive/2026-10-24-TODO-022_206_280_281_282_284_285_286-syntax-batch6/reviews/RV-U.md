# RV-U: 警告の棚卸し・設計書と英語リファレンス・同梱 Skill の手書き文書（U01〜U03a）の区切りのレビュー

- 日付: 2026-10-27
- 担当: Claude Code のサブエージェント（Opus 5.5、取りまとめが依頼）
- 対象: 範囲 `d1c59025..89c7a777`（detach した worktree、HEAD 89c7a777）。改造ディレクトリ D = `docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/`。U01 の `D/u01/warnings.md`、`D/u01a`・`D/u01b` の results.md と集計の JSON、テスト専用の `crates/benitoite/src/pipeline/interval_inventory.rs`。U02 の設計書 00-04・01-04・02-05・02-10・03-06・06-01・06-04・06-06・07-04 と `docs/reference/benitoite.md`。U03a の `crates/benitoite/skill/SKILL.md`・`references/idioms.md`・`references/inspection.md`。U03b（生成参照の作り直しと訳の引き渡し）は範囲外である。
- 方法: `git diff d1c59025 89c7a777` を中心に読んだ。実装との照合のため、`typeck/interval/{fixed_domain.rs,flow/fixed_domain.rs,diagnostics.rs,arithmetic.rs,summary.rs,budget.rs,mod.rs}`、`typeck/decls.rs` の解析の呼び出し、`diag/codes.rs` の W0401・W0402・W0404・E0435、`cli/check_report.rs`・`cli/tools/test_runner/check_report.rs` の `intervalAnalysis` の作成と集約、`pipeline.rs` の `on_large_stack`・`check_stages` を読んだ。照合した文書は AGENTS.md の「設計書の規約」「レビューの観点」「改造の設計で守ること」「再帰の深さ」、D/plan.md の作業群 U01〜U03、D/decisions.md の D2〜D9・D12・D16（追記を含む）・D18・D19（追記を含む）・D21・D22、D4 の変更、「設計者の選択（2026-10-24）」、D/reviews/RV-C4-response.md・RV-X05-response.md、u01a・u01b・u02a・u02b・u03a の results.md と取りまとめのレビュー。
- 実行: 重いビルド・テスト・`scripts/check.sh`・K1 は実行していない。worktree ではビルドせず、手元の本体の作業ツリーにある debug の実行ファイル（05:14 のビルド。`crates/benitoite/src` の最後の変更 5a1d90a3 の 04:44 より後で、それ以後 src は変わっていない）を作業用の領域へ写し、作業用の領域に置いた小さい `.bnt` で `check`・`check --report=json`・`check --deny-warnings --report=json`・`test --check --report=json` を走らせた。U01b の `normal-summary.json`・`normal-inputs-*.json` を小さい Python で再集計した。リポジトリのファイルは変更していない。

## 所見の要約

- 重大: 0 件
- 中: 0 件
- 軽: 7 件
- 判定: **受け入れ**（軽の所見は U03b か G01 の前の後片付けで直すか、記録に残せばよい）

実装と文書の主な規則は一致していた。照合して一致を確かめた点は次のとおりである。

- 予算: 本体の操作数・保持項目数が各 100,000、検査全体が各 1,000,000（`budget.rs` の `Limits::default`）。英語リファレンス・02-05「区間解析の駆動と予算」・D16 と一致する。
- W0404 の対象: `fixed_domain.rs` の 27 宣言（Byte と UnsignedInteger8 の shiftLeft・shiftRight、符号付き五モジュールの三関数、符号なし四モジュールの二関数）。純粋で署名が一致する宣言だけを認め、操作の項目はない。シフト量は全て Integer で、域は `[0,w−1]`。候補は契約位置の引数が非空で域と交差しないときだけ作り、先行の引数に正常値がなければ候補を作らない（`select_arguments`）。01-04・02-05・英語リファレンス・Skill の記述と一致する。実行でも、Byte・UnsignedInteger8・Integer16.shiftRightUnsigned・名前付き引数の順の入れ替え・import の別名 `I`・Integer64 で W0404 が出て、パイプと穴・関数値・捕捉値を使うラムダでは出ず、ラムダの内側の比較からは出た。`Process.exit(300)` に W0404 は出ない。
- HTTP: 英語リファレンスと idioms.md の `Http.text`・`Http.html`・`Http.json`・明示した `Http.Response` の構築と更新の例は、警告なしで終了 0 になった。`Http.respond` の既定の実装は `http_server.rs` で 200..=599 を検査している。
- Range の function summary: 直接の match と一度の局所保存の両方で、成功値の射影後の加算に W0402 が出た。成功値の別名の複写と、利用者関数を通した値では出なかった。import の別名 `R` でも出た。英語リファレンス・idioms.md・03-06 の記述と一致する。
- idioms.md の三警告の例: 実行で W0401（除数 `[0,0]`）・W0402（`[130,137]`、`[-128,127]`）・W0404（`[64,9223372036854775807]`、`[0,63]`）が各 1 件出て、注記の文と補助位置も説明の表と一致した。`coverage: all`、`complete: true`。`--deny-warnings` では `checkError`・`complete: false` のまま `coverage: all` を保った（06-04・英語リファレンスの記述どおり）。
- coverage の集約: `IntervalAnalysis::aggregate` は全 Target が none なら none、一つでも all 以外なら some、Target なしは 0 件の all。doc の Target は通常の入口と全生成例（check/error 例を含む）を同じ集約にかけ、例の探索が未完なら none を一つ加える。探索失敗では報告全体を none にする。06-01・06-04・02-05・英語リファレンス・inspection.md と一致する。
- E0435: `const` には `if` やシフトの呼び出しを書けず E0433 になるので、01-04 の「評価が実際に算術の失敗で止まったとき」と「局所解析の警告だけを理由に E0435 とはしない」に反する経路は見つからなかった。評価に失敗した定数は解析の有効な入力から外れる（`mod.rs` の `valid`）。
- 用語: 00-04 の「区間解析」「function summary」の行、既存の「対象構文の評価関係」の行が、02-05・03-06・07-04・02-10・06 系の章の使い方と一致する。設計者の選んだ二語と併記の形も守られている。
- 英語の文書から日本語の設計書へのリンク: `docs/reference/benitoite.md`・SKILL.md・references/ に `docs/design` へのリンクは残っていない。SKILL.md・inspection.md の v0.0.11 の `#inspection-reports` は、タグ v0.0.11 の英語リファレンスに見出しがあり、受け入れ規則の文がある。v0.0.12 のリンクは取りまとめが Z01b で確かめると記録済みである。
- U01 の件数: `normal-summary.json` の区分を合計すると、入口 1,216・Target 1,256・型検査到達 945・未着手 311・本体 3,450・別本体 844・定数参照 458・番号付きの出現 74,511・独立入力 34,752・独立入力の候補 5 となり、warnings.md の数と一致した。`normal-inputs-*.json` の全 Target の要約から、本体超過・全体による未解析・番号未取得・段停止・深さ停止のどれかを持つ Target を数えると 0 件で、「通常入力で上限到達 0 件」の主張を記録が支える。U01a の W 診断の旧 59 件・新 73 件は区分の表とコード別の表で一致し、R 拒否の差引 −1 件は Log.formatRecord を使う 5 入口の B0 の未定義の誤りで説明されている（u01a/results.md）。

## 所見

### 軽1: 定義を一つも持たない test の対象は `coverage: all` になるが、英語リファレンスと inspection.md は none と読める

- 場所:
  - `docs/reference/benitoite.md`「Interval analysis coverage」の `"none"` の文（"`"none"` means analysis did not start, including failure before type checking or a check with no valid bodies."）。
  - `crates/benitoite/skill/references/inspection.md`「Local interval analysis」の表の `coverage` の行（"targets with no valid bodies after type checking"）。
  - 設計書 06-01「区間解析の追加報告」と 02-05「区間解析の報告の集計」の「型検査で全本体が無効となった対象は `none`」。
- 問題: 実装（`summary.rs` の `Report::summary`）は、解析を始めた検査で `input_definitions == 0` かつ無効な本体が一つ以上あるときだけ none にする。本体が一つもない検査は 0 件の all になる。
- 根拠: 空のファイルと `record` だけのファイルに `test --check --report=json` を実行すると、どちらも `status: ok`・`complete: true`・`coverage: all`・`inputDefinitions: 0` だった。型の誤りの関数だけのファイルは none、型の誤りの関数と正しい関数が一つずつのファイルは some（`inputDefinitions: 1`）だった。英語の "no valid bodies" は本体が一つもない場合を含むので、実装と食い違う。設計書の「全本体が無効」は、本体が0個の場合にどちらとも読める。
- 修正案: 実装を正として文書を直す。英語リファレンスは "a check in which type checking left none of its bodies valid; a checked file with no bodies at all is a zero-count `"all"`" の趣旨にする。inspection.md の行も同じにする。06-01・02-05 は「本体が一つ以上あり、型検査で全てが無効となった対象は none」「本体を持たない対象は件数0の all」と明記する。あわせて、型の誤りの本体と有効な本体が混じる対象が some になること（実装は無効な本体を未完の範囲に数える）を、英語の "all" の定義の列挙（unsupported or stopped range, pending input, ...）に加えると読み手が迷わない。
- 確定の度合い: 実行で確定（実装はコードからも確定）。

### 軽2: 英語リファレンスの形式化の保証の文が、比較していない範囲を含めて「一致を有限の入力で確かめる」と読める

- 場所: `docs/reference/benitoite.md`「Local interval warnings」の最後の段落（"Agreement with the compiler, standard-library source, and VM is checked on finite inputs, rather than proved for all programs."）。
- 問題: 07-04「区間解析の対象構文の評価関係」は、`return` の返す区間を交換・比較していないこと、外部型を含む定義の独立入力の区間と Bottom の本体が Lean と未比較で残ること、Byte・UnsignedInteger8 のシフトの結果と域内の値は評価関係と比べていないこと、操作と HTTP の欄は比較に含めないことを、A1 の限界として書いている（RV-X05 への対応の中1・中2）。英語の文は「処理系・標準ソース・VM との一致は有限の入力で確かめた」と述べるだけで、確かめていない部分があることを書かない。続く文の "records the trusted rules and comparison limits" が限界の存在を示すので誤りとまでは言えないが、受け入れの判断に使う読み手には一致の範囲が実際より広く読める。
- 根拠: 07-04 の当該節の「境界の構文による早い return は…return の値は二つの中心命題の対象外」、外部型の除外の段落（355件中14件）、Byte の4宣言の行（「比較済みには数えない」）、操作と HTTP の欄の段落。
- 修正案: "Agreement with the implementation, standard-library source, and VM is checked on selected finite inputs; some results, such as returned intervals, are not compared. This is not a proof for all programs." の形にし、比べていない部分があることを一文で書く。02-05「区間解析の範囲と保証」の「有限の入力で比較する」も「対象の一部を有限の入力で比較する」とするとそろう。
- 確定の度合い: 読めば確定（文の範囲の問題）。

### 軽3: 01-04 の W0404 の項目が、Byte と UnsignedInteger8 の正の名前と別名を逆に書いている

- 場所: `docs/design/01-spec/01-04-types-basic.md`「前提」の W0404 の箇条（「各整数モジュールと `Byte`・その別名 `UnsignedInteger8` のシフト関数」）。
- 問題: 同じ章の「型の一覧」は正の名前を `UnsignedInteger8`、別名・既定の表示名を `Byte` とする。01-01 も「`UnsignedInteger8`（別名 `Byte`）」、英語リファレンスの型の表も Canonical name を `UnsignedInteger8`、Alias を `Byte` とする。W0404 の箇条だけが Byte を本体、UnsignedInteger8 を別名と書く。標準モジュールの層では `Benitoite.Byte` が組み込みで `Benitoite.UnsignedInteger8` が包みの関数（07-04）なので、型の別名とモジュールの関係が混ざっている。
- 根拠: 01-04「型の一覧」の表、01-01 の接尾辞の表、`fixed_domain.rs` の `Benitoite.Byte.*` と `Benitoite.UnsignedInteger8.*` の二つの組。
- 修正案: 「各整数モジュールと、`UnsignedInteger8`（別名 `Byte`）の二つのモジュール `Byte`・`UnsignedInteger8` のシフト関数」とする。
- 確定の度合い: 読めば確定。

### 軽4: テスト専用の `interval_inventory.rs` が、規約の例外の一覧にないスタックの大きさでスレッドを起こす

- 場所: `crates/benitoite/src/pipeline/interval_inventory.rs` 92〜99 行（`interval_inventory_matches_pipeline` が `stack_size(STAGE_STACK_BYTES)` のスレッドで `run` を呼ぶ）。
- 問題: AGENTS.md「再帰の深さ」は「スレッドのスタックの大きさを変えてテストを通すことはしない」とし、例外を `stages_fit_the_measured_stack_` で始まるテスト（16 MiB）だけに限る。このテストは、本番の段のスレッド（`pipeline::on_large_stack` の 64 MiB）で走る `check_stages` と型検査を、段のスレッドを通さずに直接呼ぶために同じ大きさのスレッドを起こしている。目的は本番の構成の再現であり、深さの不具合を隠すためではないと読めるが、そう判断する理由のコメントがなく、`on_large_stack` も使っていない。既定の lib のテストに含まれるので、規約の字面との食い違いが残る。
- 根拠: `pipeline.rs` の `on_large_stack`（`STAGE_STACK_BYTES` を使う唯一の本番の箇所）と、`STAGE_STACK_BYTES` の参照の一覧（本番の1箇所とこのテストの1箇所）。
- 修正案: `super::on_large_stack(run)` を使い、「本番の段と同じスタックで `check_stages` を呼ぶため（設計書 02-01「関数の呼び出しと処理系のスタック」）」とコメントする。規約の例外として扱うなら、AGENTS.md の例外の一覧へ加えるかを取りまとめが判断して記録する。
- 確定の度合い: 読めば確定（規約の字面との差。動作の誤りではない）。

### 軽5: idioms.md の HTTP の節の冒頭と説明の表の位置の書き方

- 場所:
  - `crates/benitoite/skill/references/idioms.md`「HTTP」の最初の二段落と `check` の例。
  - 同「Explaining local interval warnings」の表の W0404 の行（"W0404 at `n: n`"）。
- 問題: (1) HTTP の節は、従来は「A client and a server in one program.」から HTTP の使い方を始めていた。今は区間解析が HTTP の欄を追わないという注意と、範囲外の状態 700・701 を構築する例が先に来る。HTTP のスクリプトを書くために節を開いた読み手（主に LLM）は、使い方より先に範囲外の値の例を読む。(2) W0404 の一次位置は引数の式 `n`（`n: n` の値の側、実行では 19 行 39 列）であり、ラベルを含む `n: n` ではない。
- 根拠: 実行の出力の一次位置。U03a の差分。
- 修正案: (1) HTTP の注意と例を、同じ節の終わりか「Explaining local interval warnings」の中の小節（たとえば "HTTP values are not tracked"）へ移し、HTTP の節からは一文で案内する。(2) 表の場所を "W0404 at the `n` argument" とする。
- 確定の度合い: (1) は読み手への影響の判断、(2) は実行で確定。

### 軽6: 英語リファレンスの `phaseStops` の行が、検査全体の停止を挙げていない

- 場所: `docs/reference/benitoite.md`「Interval analysis coverage」の表の `phaseStops` の行（"Separate stop counts for preparation, body discovery, queue construction, and analysis control."）。
- 問題: 実装（`summary.rs`）は、定義の間で全体の予算が尽きた停止（`Report::stopped`）も `phaseStops` に加える。06-01 は「入口作成・発見・待ち行列・別本体制御・検査全体の停止事象数」、inspection.md は "nested-body control, and whole-check control" と書くが、英語リファレンスの行は "analysis control" だけで、検査全体の停止が含まれるかを読み取れない。
- 根拠: `summary.rs` の `if let Some(stop) = self.stopped { summary.phase_stops.add(...) }`、06-01 の表の `phaseStops` の行。
- 修正案: "... queue construction, nested-body control, and whole-check control." とする。
- 確定の度合い: 読めば確定。

### 軽7: U01 の棚卸しの後に加えた例と、英語リファレンスの訳の引き渡し

- 場所: `D/u01/warnings.md`「消費と上限」、`D/u02b/results.md`「計画との差と申し送り」、`D/u03a/results.md`「Z01 への翻訳対象の引き渡し」。
- 問題: (1) U01 の 1,217 入口は U01a の時点（cb15b08b）の一覧であり、U02b・U03a が加えた例（英語リファレンスの HTTP の `check` 例、idioms.md の HTTP の `check` 例と Range の `test` 例、`text` の三警告の例）を含まない。これらは `reference_examples`・`skill_examples` で「診断なし」を確かめているが、予算超過は診断を出さないので、「通常入力で上限到達 0 件」の主張はこれらに及ばない。例は小さく、上限に届く見込みはほぼないが、主張の範囲が記録に書かれていない。(2) U03a は Skill の変えた段落の一覧を Z01 へ渡したが、U02b は英語リファレンスの変えた節（Inspection reports の表の行と Target の文、Interval analysis coverage、Local interval warnings、HTTP の段落と例、Range の段落、Width-specific の段落の書き換え）の一覧を残していない。
- 根拠: `D/u01a/inputs.json` の固定の SHA-256 と日付、U02b・U03a の結果の記録。
- 修正案: (1) U03b の results.md に「U01 の消費の測定は U01a の一覧の範囲であり、U02b・U03a の追加例を含まない」と書くか、追加例だけを `interval_inventory` の環境変数の入口で測って最大値を添える。(2) U03b の訳の引き渡しの表に、英語リファレンスの変えた節を加える。
- 確定の度合い: 読めば確定（記録の範囲の問題）。

## 範囲外で気付いたこと（所見に数えない）

- 02-10「警告の扱い」の既存の文「Integer64 と UnsignedInteger の別名にも同じ判定を適用する」は、01-04 の「Integer と UnsignedInteger の別名」と書き方が違う。今回の差分の行ではないが、U02b が同じ段落の前後をそろえたので、次に触れるときに「Integer・UnsignedInteger の別名」へそろえるとよい。
- 01-04 の局所解析の【決定】は、既存の算術の警告の規範と同じく「前提」の節にある。02-05 も `#前提` へリンクしている。章の構成（規範は「仕様」に置く）から見ると位置が揃っていないが、既存の構成に合わせた追加であり、今回の作業で直す必要はない。
