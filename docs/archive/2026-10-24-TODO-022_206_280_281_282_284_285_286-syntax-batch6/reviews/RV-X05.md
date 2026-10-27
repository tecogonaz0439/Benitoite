# RV-X05: 区間解析の Rust と Lean の接続（X01〜X05）と全比較 K1 の区切りのレビュー

- 日付: 2026-10-27
- 担当: Claude Code のサブエージェント（Opus 5.5、取りまとめが依頼）
- 対象: 範囲 `0341dfe3..732b2925`（detach した worktree、HEAD 732b2925）。改造ディレクトリ D = `docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/`。範囲内の本番の Rust（`typeck/decls.rs`・`typeck/mod.rs`・`typeck/interval/{mod,flow,diagnostics,observation}.rs`）、書き出し（`tests/desugar_export.rs`・`tests/desugar_export/{exchange.rs,interval.rs,interval/*}`）、比較器（`formal/tests/interval_{source_compare,vm_compare,range_vm,shift_vm}.py`・`test_interval_exchange.py`）、`scripts/check/{formal_interval.py,interval_artifacts.py,test_policy.py}`、`scripts/check-formal.sh`、02-05・07-03・07-04・`formal/README.md`。K1 の3回目の記録（`D/x05a/results.md` の「3回目」と `D/x05a/run3/`）。
- 方法: 読むだけで行った。`git diff 0341dfe3 732b2925` を中心に読み、照合に要る範囲で `formal/Benitoite/Interval/Exchange.lean`（`informative`・`Expected`・`differences`）、`formal/IntervalDiff/Main.lean`、`ExchangeExamples.lean`、`typeck/interval/flow.rs` の `Approx` を読んだ。照合した文書は D/plan.md の契約表（比較報告・警告・予算の交換の行）、作業群 X01〜X05、「計画の変更（2026-10-26、RV-C5 を受けて）」「同（2026-10-27、X05a の停止を受けて）」「同（2026-10-27、X05a の2回目の停止を受けて）」、検査の割り当ての K1・S-X の行、D/decisions.md の D5・D17・D18・D22、D/x05a・x05r・x05s の results.md と取りまとめのレビュー、D/reviews/RV-C5.md と RV-C5-response.md。
- 実行: `cargo`・`lake`・K1 は実行していない。保存済みの `D/x05a/run3/evidence-summary.json`（10系統の要約）と `D/x05a/run3/exclusion-details.json`（除外した16本体の Rust の観測）を、小さい Python の読み取りスクリプトで集計しただけである。リポジトリの外の ZIP は読んでいない。

## 所見の要約

- 重大: 0 件
- 中: 2 件（中1: 「全 Top だけの一致を拒む」関門が、`return` で終わる本体の正常値の Bottom だけで満たされる。中2: 外部型の除外の検査が独立入力の区間と Bottom を見ず、情報を持つ解析結果を比較から落としている）
- 軽: 6 件
- 判定: **条件付き受け入れ**

K1 の3回目は、計画の完了条件の六入口・独立入力・全関係定義・Rust/Lean・VM・Range/案III を一つの関係状態（`d62dbaa1`）で通しており、件数の整合（programs の 100,005 − 16 = 99,989、Top 21,011 + 情報 78,978 = 99,989、型検査 1,403 + 389 = 1,792、manifest 系統の 341 − 16 = 325 など）も保存済みの要約で確かめられた。不一致を受け入れた経路は見つからなかった。警告の候補を除外が隠した例もない（16本体の親候補・独立入力の候補はすべて空）。

一方、受け入れの記録（x05a の取りまとめのレビュー、results.md の3回目、07-04 の除外の理由）は、比較が持つ情報の量を実際より大きく書いている。受け入れの条件は次の二つである。中1・中2 の書き方を X05b の集約（S-X の受け入れ）の前に直すこと。関門と除外の条件を強めるか、今の条件のまま限界として記録するかを取りまとめが決めて記録すること。

## 所見

### 中1: 「全 Top だけの一致を拒む」関門が、return で終わる本体の正常値の Bottom だけで満たされる

- 場所:
  - `formal/Benitoite/Interval/Exchange.lean` 833〜840 行（`informative`。Integer の根の型では `approx.integer != top`）。
  - `crates/benitoite/tests/desugar_export/interval/manifest.rs` 327〜394 行（`classify`。Bottom を `top: false`・`informative: true` に数える）。
  - `formal/tests/interval_source_compare.py` 46〜57 行（`approximation` は `returnedInteger` を期待へ入れない）、425・436 行。
  - `scripts/check/formal_interval.py` 129〜132 行（系統ごとに `informativeBodies > 0` だけを要求する）。
  - 記録: `D/x05a/results.md` 182・311・401 行。
- 問題: 比較する本体の値は正常な継続の成分だけである。Lean の `Expected`/`differences` は integer・boolean・other・widths・nonIntegerOther を比べ、`return` の返す区間を交換していない。Rust は `returnedInteger` を記録するが、比較器は読み捨てる。Benitoite の関数は `return` で結果を返す（例: `interval/vm-arithmetic.bnt` 3〜5 行の `return 8 + 2`）ので、その本体の正常値は Bottom になる。`informative` と `classify` は Bottom を非 Top と数える。その結果、整数の区間が全て Top になる解析でも、`return` を含む本体があれば系統ごとの関門も Lean の `allTop` 判定も通る。
- 根拠: 保存済みの `run3/evidence-summary.json` の `nonBottomInformativeBodies`（比較器が集計するが、どこも要求しない欄）は次のとおりである。

  | 系統 | 情報を持つ本体 | うち Bottom | Bottom 以外 |
  |---|---:|---:|---:|
  | programs | 78,978 | 74,943 | 4,035 |
  | identity | 195 | 192 | 3 |
  | manifest/manifest-interval | 249 | 238 | 11 |
  | range/interval | 65 | 65 | 0 |
  | vm の6系統 | 39・39・46・46・108・108 | 全件 | 0 |

  10系統のうち7系統は、関門を Bottom だけで満たしている。results.md の「情報を持つ結果が0本体の系統はない」「全Topだけの一致ではない」と、取りまとめのレビューの「99,989本体のうち78,978本体が情報を持つ結果であり、全ての結果が Top であるだけの成功ではない」は、字義の上では D17 と契約表の基準を満たす。ただ、根拠として挙げた件数の95%は Bottom である。整数の区間として情報を持つ本体は programs の 4,035 だけになる。実際の比較が空虚でないことは、警告の比較（programs 38件、vm 20件など）と独立入力の値の照合が支えているが、関門はそれを要求していない。
  なお RV-C5 中1 は「return だけで抜ける本体」に触れていたが、L29R が直したのは整数でも Boolean でもない型の判定だけであり、Integer 型の根の Bottom は残った。
- 修正案:
  1. 記録の修正（必須）: x05a の3回目と取りまとめのレビュー、X05b の集約では、情報を持つ本体の件数に Bottom と Bottom 以外を分けて書く。比較が空虚でない根拠として、警告の比較件数と、Bottom 以外の情報を持つ本体・独立入力の件数を挙げる。
  2. 関門の強化（取りまとめが選ぶ）: `formal_interval.counts` で、系統の集合全体について `nonBottomInformativeBodies > 0` を要求する。系統ごとには「Bottom 以外の情報を持つ本体、比較した利用者の警告、Top 以外の独立入力のどれかが1件以上」を要求する。
  3. 限界の明記: 07-04 に、`return` の返す区間を交換していないこと、関数本体の正常値が Bottom になることを A1 の比較の限界として書く。`returned` を交換に加えるかは docs/todo の項目にする（Lean の `Expected` と健全性の言明の範囲に関わる）。
- 確定の度合い: 読めば確定する（コードの分岐と保存済みの要約の件数から導ける）。整数が全 Top になる退行で関門が通ることは、机上の推論であり実行していない。

### 中2: 外部型の除外の検査が独立入力の区間と Bottom を見ず、情報を持つ解析結果を比較から落としている

- 場所:
  - `scripts/check/interval_artifacts.py` 24〜29 行（`no_information` は本体自身の integer・widths・returnedInteger だけを見て、Bottom を「情報なし」とする）、46〜50 行（独立入力は候補だけを見る）。
  - 07-04 343 行の段落の「理由:」と 07-03 173 行。
  - `D/x05r/results.md` 86・93 行、`D/x05a/results.md` 202・344 行、x05r の取りまとめのレビュー。
- 問題: 除外の受け入れ条件は「情報を持つ解析結果を出さない」（plan の X05a の停止を受けた計画の変更。取りまとめの判断の理由は「区間解析は外部型の値に事実を持たない」）である。ところが実装は二つの情報を見ていない。
  1. 除外した本体の独立入力の正常値。保存済みの観測では、16本体の独立入力355件のうち14件が Top でも Bottom でもない閉区間を持つ。例: `.createMany` の start 13 は `[-9223372036854775808, 9223372036854775806]`、resource の `.main` の start 3 は `[10, 10]`、start 46 は `[1500, 1500]`。
  2. 本体自身の正常値の Bottom。16本体のうち14本体は integer・六幅が Bottom、boolean が (false, false)、nonIntegerOther が false である。中1 の `informative` の規則では、同じ値を他の本体では情報を持つ結果と数えている。

  前者について x05r/results.md 86 行は、最初の試行で独立入力の値まで Top/Bottom に限ったところ失敗し、その限定を外したと記録している。その後の 93 行は「全定義の理由付き除外が情報を持つ解析や候補を隠さず」と述べ、07-04 も「理由: 外部型を Surface に加えず、情報を持つ解析結果や警告を比較から取り落とさないためである」と書く。results.md の「Top・Bottom 以外の整数区間0」は本体自身の値についてだけ正しい。条件を実装中に狭めた判断は報告されているが、取りまとめのレビューは触れておらず、受け入れの理由と食い違ったまま残っている。
  警告については問題がない。16本体の親候補・独立入力の候補はすべて空であり、利用者の警告を除外が隠した例はない。
- 根拠: `run3/exclusion-details.json` の `details[*].bodies[*]` の値と独立入力を集計した（独立入力355件、閉区間14件、本体の Bottom 14件）。比較器の欄は上記の行から読める。
- 修正案: 次のどちらかを取りまとめが選び、記録する。
  - (a) 条件を受け入れの理由に合わせる: 独立入力の正常値も Top/Bottom に限る。このとき今の4入力は不合格になるので、外部型の定義の扱いを設計者へ戻す。
  - (b) 今の条件を保ち、書き方を直す: 除外の受け入れの根拠を「警告の候補がない（利用者の警告は落ちない）」に限る。除外した本体に情報を持つ独立入力14件と、Bottom の本体14件が Lean と未比較で残ることを、x05a の記録・07-04・07-03 に件数で書く。07-04 の「理由:」の「情報を持つ解析結果…を取り落とさない」を削る。将来の外部型の交換は docs/todo の項目にする。
- 確定の度合い: 読めば確定する（保存済みの観測とコードから導ける）。

### 軽1: 負例は対象がなければ黙って省かれ、全比較はその一覧を要求しない

- 場所: `formal/tests/interval_source_compare.py` 201〜202 行（`changed is None` なら `continue`）、224・235・245〜246 行（条件付きの負例）。`scripts/check/formal_interval.py` の `counts`（`negativeCases` を読まない）。
- 問題: 負例の欄（integer・after・context・next・warnings・independent・userWarnings・phasePosition・externalType の4種）は、選べる入力がなければ記録されないだけで、失敗にならない。今の K1 では、phasePosition は manifest 系統だけ、externalType は programs と manifest 系統だけ、independent は vm の6系統にない（`run3/evidence-summary.json`）。将来、意図した停止の入力や外部型の入力が変わると、比較器の負例が黙って消えても K1 は通る。X05S は userWarnings の選択を直したが、対象の警告がない系統では同じく黙って省かれる形のままである。また最初の負例は corpus の先頭の入力を選ぶので、先頭が除外を持つ入力なら意図しない不一致で K1 が止まる（誤りの受け入れではなく、誤った停止になる）。
- 修正案: `formal_interval.counts` で、10系統の `negativeCases` の和集合が上記の全種を含むことと、各系統が integer・after・context・next・warnings を含むことを要求する。最初の負例の選択から除外を持つ入力を外す。
- 確定の度合い: 読めば確定する。

### 軽2: 旧定数警告の採用済みの組を、旧定数警告の診断と照合していない

- 場所: `formal/tests/interval_source_compare.py` 169〜179 行（`seen` は Rust の `legacyWarnings.identities` から作る）。
- 問題: 新候補のうち `seen` にある組は、Lean の期待からも外される。`seen` は Rust の `Warnings` の内部の集合をそのまま使い、旧定数警告の診断（`legacyWarnings.diagnostics`）と対応するかを確かめていない。Rust が診断のない組を誤って登録すると、その位置の新しい警告は Rust でも期待でも消え、比較は一致する。
- 修正案: 各組 `(NodeId, 原因, 一次位置)` から作った `(コード, 一次位置)` が旧定数警告の診断の中にあることを要求する（件数も一致するなら多重集合で比べる）。
- 確定の度合い: 比較器の穴は読めば確定する。今の Rust で不整合が起きるかは、実行しないと分からない。

### 軽3: 観測のための再検査を、通常の検査の解析の要約とだけ照合している

- 場所: `crates/benitoite/tests/desugar_export/interval/manifest.rs` 64〜83 行。
- 問題: 書き出しは `typecheck_with_interval_observations` で型検査をもう一度行い、通常の検査（`p.types`）とは区間解析の要約の件数だけを比べる。比較器が照合する利用者の警告は、この再検査の診断から取っており、利用者が CLI で見る `checked.diagnostics` とは照合していない。コードの経路は同じで、観測の差し込みは読むだけなので、本番の振る舞いは変わらない。私が読んだ範囲では、記録先の有無で解析・予算・診断を変える箇所はなかった。ただ、この照合を加えれば、観測の経路が通常の解析を写していることを件数だけでなく診断でも確かめられる。
- 修正案: 再検査の W0401・W0402・W0404 の診断（コード・一次位置・順序）が `checked.diagnostics` の同じコードの診断と一致することを assert する。
- 確定の度合い: 読めば確定する（照合の欠け）。不一致が起きるかは実行しないと分からない。

### 軽4: 本番の公開 API に、テスト専用の入口と serde_json の型が加わった

- 場所: `crates/benitoite/src/typeck/mod.rs` 198〜218 行（`pub fn typecheck_with_interval_observations`、`#[doc(hidden)]`、戻り値に `Vec<serde_json::Value>`）。
- 問題: 契約表の冒頭は「外部に公開するためだけのラッパーを増やさない」と定める。この入口は統合テストから呼ぶためだけに `pub` になっている。02-05 は「内部用の入口」と書いて理由を説明しており、本番の経路は記録先なしで同じ処理を使う。組込み向けの構成で serde_json を外す境界を作るとき、この署名が障りになる。
- 修正案: 機能（例: `formal-export`）の下に置くか、公開を許した理由を契約表の注として残す。どちらにするかは取りまとめが判断する。
- 確定の度合い: 読めば確定する（方針の判断は取りまとめに委ねる）。

### 軽5: 比較の要約の一部の真偽は定数であり、件数の照合の根拠にならない

- 場所: `formal/tests/interval_source_compare.py` 381 行（`matched=True`）・480 行（`rustLeanMatched=True`）。`scripts/check/formal_interval.py` 130 行。
- 問題: `rustLeanMatched` と除外を含む報告の `matched` は、途中の assert を通れば常に真の定数である。`counts` が `rustLeanMatched` を要求しても、新しい検査にはならない。results.md 311 行の「全10系統で `rustLeanMatched: true`」は、比較が最後まで走ったことの記録であり、独立の証拠ではない。
- 修正案: 記録では「各系統の比較器が終了まで走った」と書く。欄を残すなら、要約の中の比較件数と個別報告の件数の照合を `counts` の根拠として挙げる（今もしている）。
- 確定の度合い: 読めば確定する。

### 軽6: 2回目の K1 と X05S の環境の記録の Lean の版が、固定版と合わない

- 場所: `D/x05a/results.md` の2回目の「ツールチェーン」（Lean 4.35.0、Lake 5.0.0-src+eb6cafb）、`D/x05s/results.md` の「検査と記録」の末尾。
- 問題: `formal/lean-toolchain` は範囲の前後とも `v4.34.1` である。3回目の記録は `lake env lean --version` で 4.34.1 を記録し、過去の 4.35.0 を転記しなかったと注記している。2回目と X05S の記録は `formal/` の外の既定のツールチェーンを読んだとみられる。実行ファイルの SHA-256 は一致しているので、比較の結果は変わらない。
- 修正案: 2回目と X05S の記録に、版の表記の誤りと3回目の記録の参照を注記する。
- 確定の度合い: 読めば確定する（固定版のファイルと記録の食い違い）。原因の推定は確かめていない。

## RV-C5 の所見の閉じ方

| 所見 | 閉じ方の確認 |
|---|---|
| 中1 非整数・非 Boolean の型の Top を非 Top と数える | L29R（`1e4b58f8`、範囲の直前）で `informative` の分岐が `!nonIntegerOther` になった（`Exchange.lean` 839 行）。Integer の根で `return` による Bottom を非 Top と数える点は残り、中1 として挙げた |
| 中2 未着手の期待の黙殺、全体の after・段停止・件数 | L29R で `notAnalyzed` の照合と、入力の `after`・`counts` の任意欄が入った。実ソースの比較は未着手の本体に `{"notAnalyzed": 停止理由}` を与え、入力の `after`・`counts` を渡し、段停止は `compare_structure` で Rust の manifest と照合する（`interval_source_compare.py` 276〜317・411〜418 行）。閉じている |
| 中3 X03c の表と除外の食い違い | plan の X03c の表を直した。`interval_shift_vm.py` は評価関係との比較46行・独立期待値だけ62行を Lean の報告の件数（116 行）と行ごとの `comparisonEligible`（121 行）で照合する。07-04 の表も一致する。閉じている |
| 軽1 profile の拒否の例 | `ExchangeExamples.lean` の例が `"future"` と理由 `unsupported interval profile` になった。閉じている |
| 軽2 包みの宣言の数 | 7宣言に直り、包みの域外14実行で R0701 の文言と元の call の位置を照合している（`interval_shift_vm.py` 59〜69 行）。閉じている。要約の `wrapperDeclarations=7`・`wrapperOutsideRuns=14` は定数だが、各実行の照合が根拠になる |
| 軽3 INPUT と REPORT の同一の判定 | `IntervalDiff/Main.lean` が実パスで比べる。閉じている |

## 確かめて問題がなかった観点

1. 全比較の入口: `check-formal.sh` は `set -euo pipefail` で動く。区間の出力先は `formal_interval.py prepare` が新しい空の場所かを確かめ、実パスの同一・親子・リンクを拒む。四つの書き出しは別の出力先へ渡す。既存六入口の最終照合（`check_named.py`）が成功してから `manifest` と `verify` を行う。`test_policy.py` の自己検査は、四つの書き出しの名前と出力先、10系統の順、`prepare → collect → manifest → verify` の順を確かめている。
2. 入力の固定: `collect` は実行前の入力ハッシュ（1,220ファイル）を保存し、`verify_inputs` が実行後にも一致を求める。最終の manifest は自身を除く全ファイル（12,063）のハッシュを持ち、`verify` が読み戻して追加・欠落・改変と件数の再計算の差を拒否する。索引から読む共有の入力は、索引と参照先の両方がハッシュに入る。
3. 実ソースの解析の比較: Rust の候補の一次位置を、Surface の対応表から独立に計算した位置と照合する（`candidate`・`warning_primary`）。利用者の警告は、旧定数警告と新候補をまとめた並びを、順序を含めて Rust の診断と比べる。系統ごとに入力数・個別報告数・比較件数を manifest と照合し、深さ除外と段の深さ停止を0件に限る。
4. 除外をまたぐ予算: `compare_excluding` は、除外した本体を含む Rust の消費を順に足した計上記録を、Rust の検査全体の最終消費と照合する。残る定義は、その直前の状態を入口に置いて一つずつ Lean で比べ、Lean の `after` を計上記録の直後の状態と比べる。モジュールの分類の1回を差し引く扱いと最大保持の取り方も、再実行の入口と一致している。除外した本体の消費が正しいことは Lean では確かめていないが、07-04 は「除外した本体そのものの Rust/Lean の一致は主張しない」と書いており、主張の範囲と合っている。
5. 評価関係と VM: 算術・フローは、手計算の値・trace を Lean の評価関係と、Lean の評価の trace を標識付きの実 CLI と、それぞれ照合する。標識を除いた Surface の構造の一致、子の失敗・未選択の枝・短絡の未評価、R0201 と標識位置の失敗の除外、値・到達・失敗位置の負例がある。Range は三欄・射影・逆転の優先と負例を照合し、事前に選別した9本体を比較件数に入れない。シフトの域内と Byte の62行は独立期待値だけで照合し、評価関係との比較件数へ入れない。07-04 と `formal/README.md` は、これを有限の入力についての A1 の接続の検査とし、意味保存や評価規則の信頼の除去を主張していない。過大な書き方は見つからなかった。
6. 本番の Rust: 範囲内の変更は、記録先を任意で受け取る経路の追加（`check_recorded`・`analyze_recorded`）と、読むだけの観測（`observation.rs`、`Approx::observed`、`Warnings::observed`）である。記録先がないときの経路は従来と同じ関数を通り、予算と診断の操作は増えていない。観測は解析が作った `BodyReport` と予算の状態をそのまま写しており、書き出しのための別の計算ではない。
7. K1 の証拠: 3回目の記録は、関係状態・コマンド・終了・時間・環境・実行ファイルの SHA-256・各入口の件数・除外と停止・出力容量（区間 0.68GB）・永続の ZIP のハッシュ・作業末の work を残している。件数は保存済みの要約と一致し、1回目と2回目の失敗を成功へ書き換えていない。最大常駐量の未取得は記録の欠けとして明記されている。
