# C1Rb3c の結果

2026-10-25。基準 B_WORK と開始時の HEAD は `b1dd3620a52116d1978cb4fac0be82877cf2695b`、ブランチは `mod012/C1Rb3c`。開始時に未コミット差分はなかった。private/ と、そこを指すスキルのリンクは読んでいない。git の変更操作は行っていない。

## 文書と定義の照合

C1Rb3c の文書の照合と修正を完了した。Lean・Rust・言語の規則・中心二命題・旧主定理・公理・Builtins.Assumptions は変更していない。実装を変える必要や、設計者の判断を要する証明上の問題は見つからなかった。独立レビューと親 C1Rb の受け入れは取りまとめに残る。

| 変更先 | 照合した定義・言明と修正 |
|---|---|
| 01-12「区間解析の予算付きの式とフロー」「区間解析の独立入力の保存と保証」 | BudgetAnalyze.expr と BudgetChildren の振り分けを写し、「まだ接続していない」を修正した。未知の子の独立解析と未到達・別本体の番号だけの走査、with の追加位置、Block に番号を増やさないことを明記した。unknownChildren_walk・unknownChildren_silent と既存の番号・位置・領域の証明、analysis_savesInputs・入口の全入力の Sound の保証を揃えた |
| 01-12 の Context の保存順 | BudgetIndependentRun.captureIndependent と BudgetChildrenExamples の入れ子の期待値に合わせた。independentRev は訪問順の逆順ではなく、結果を記録した順の逆順である。内側の結果を先に保存し、外側の結果を後から先頭へ加える |
| 07-04「区間解析の対象構文の評価関係」「01-12 との対応」 | 親の警告は親の入力の領域、独立入力自身の警告はその入力の根から定めた領域に属することを区別した。任意予算の入れ子の保存と式・本体入口の保証、既定 import、実行比較の例と定理の区別、未完の範囲を揃えた |
| plan.md の契約表・分類表 | 独立入力の保存・復帰・停止・順序・入れ子・入口の保証を反映した。親の出力と independentRev の各入力自身の候補をともに読んで重複をまとめる契約を明記した。Surface.Syntax の Expr 全53構成子の名前が分類表に含まれることも読み取りの Python で確認した |
| 用語集「警告領域」 | 名前と原語欄の「—」は保ち、未知の子を独立入力とするときの範囲の定め直しを補った。実行の到達可能性や実際の訪問済みの集合を意味しないことを明記した。名称の候補は下記に留めた |
| reviews/RV-C1-response.md | 中1・中5について、この枝で揃えた保証・契約・限界と後続の担当を追記した |

構成子の扱いは BudgetChildren.lean の unknownChildren、保存と復帰は BudgetIndependentRun.lean、Sound と SavesInputs は BudgetIndependent.lean、入れ子の帰納と入口の系は BudgetIndependentSound.lean と照合した。番号は BudgetTraversal.lean、親候補の復元は BudgetLocated.lean、入力ごとの領域は WarningRegion.lean・BudgetRegion.lean と照合した。BudgetChildrenExamples の9組の #guard は固定期待値との実行比較であり、任意の入力についての証明として記述していない。新しいテストや例は追加・変更していない。

## 「警告領域」の名称の候補と一次資料

2026-10-25 に下記の一次資料を確認した。現在の定義は、一つの入力の根から具体規則だけで辿れる構文上の出現の集合である。実行の存在、分岐条件の充足、予算内で実際に訪問したことは要求しない。この定義と同じ集合を指す定着した術語は、確認した資料では見つからなかった。次の二案は設計者が選ぶための候補であり、文書の語を変更する決定ではない。

| 候補 | 一次資料で使う呼び名 | 今回の定義への適用と限界 |
|---|---|---|
| 術語を増やさず「具体規則で扱うプログラム点の集合」と説明する（推す案） | Clang の [Data flow analysis: an informal introduction](https://clang.llvm.org/docs/DataFlowAnalysisIntro.html#data-flow-analysis) は解析する位置を program points と呼ぶ。日本語では、滝本宗宏「[SSA形式における共通部分式の効率的な発見法](https://www.jstage.jst.go.jp/article/jssstconference/2003/0/2003_0_8/_pdf)」（日本ソフトウェア科学会第20回大会、2003、1頁の要旨）に「プログラム点」「プログラム点の集合」の用例がある | program points / プログラム点は既存の呼び名である。「具体規則で扱う」は Benitoite の定義を限定する説明であり、出典の術語とは主張しない。今回は式のキーで区別した出現を指すと定義すれば、実行到達や訪問の実績を含意せずに述べられる |
| 原語 syntactic reachability を使い、日本語候補を「構文的な到達可能性」とする | Frama-C 33.0 の [The Metrics plug-in §1.2.4](https://frama-c.com/download/frama-c-metrics-manual.pdf#page=7) は syntactic reachability と Eva が解析した範囲を区別し、前者を後者の過大近似として説明する | 構文から定めることと実際に解析した範囲の違いを表せる。ただし Frama-C では呼び出し可能な関数を扱い、今回の具体規則だけの AST 走査とは対象が異なる。「構文的な到達可能性」という日本語の定着した用例は今回確認できておらず、訳語候補としてのみ示す。採用するなら実行の到達可能性との違いを定義に残す必要がある |

region を既存の術語としてそのまま割り当てる案は推さない。[LLVM RegionInfo.h の RegionBase の説明](https://llvm.org/doxygen/RegionInfo_8h_source.html#l00193)は、CFG の single entry single exit の部分グラフを Region と定める。今回の集合はその入口・出口の条件を持たないため、同じ定義であるとは扱えない。また [CodeQL の制御フロー解析の説明](https://codeql.github.com/docs/codeql-language-guides/analyzing-control-flow-in-python/#about-analyzing-control-flow)は AST の要素と制御フローの節点を区別する。この区別に照らしても、今回の構文上の範囲だけから実行への到達を主張する名前は避けるのがよい。最後の適用上の判断はこれらの資料と Lean の定義を比べた本担当の推論であり、出典による Benitoite の命名ではない。

## 実行した検査

依頼で指定された三単位だけを実行した。Lean のビルドを並行して走らせず、formal/lakefile.toml の各プロセスの `-M 12288` を保った。単一ファイルの Lean 検査は実行していない。

```sh
scripts/check.sh --level work --base b1dd3620a52116d1978cb4fac0be82877cf2695b --only formal_build,spec_examples,spec_tally --dry-run
CARGO_HOME=/private/tmp/benitoite-c1ra-cargo-6o0m3fp5 scripts/check.sh --level work --base b1dd3620a52116d1978cb4fac0be82877cf2695b --only formal_build,spec_examples,spec_tally
```

本実行は `/usr/bin/time -l python3 /private/tmp/benitoite-c1rb3c-work.py` で包み、Python の subprocess から上記の検査を一度起動した。先行枝と同じ書き込み可能な一時 CARGO_HOME を使い、依存の版・入力・検査範囲を変えていない。

| 検査・コマンド | 終了状態 | 外側の時間 |
|---|---|---|
| 指定の work の dry-run | 0。spec_tally・spec_examples・formal_build の三単位だけを選択 | 未計測（1秒未満） |
| 指定の work 本実行（一度） | 検査本体0。三単位とも成功 | Python monotonic 7.618240708秒、time real 7.65秒 |
| 仕様例（work 内） | 7成功・0失敗・0無視 | 個別の外側時間は未計測。テスト実行器の表示3.69秒 |
| 仕様集計（work 内） | 自己検査と集計に成功。初回リリースの完了条件の未記入なし | 個別の外側時間は未計測 |
| 形式化（work 内） | 既定 lake build と sorry 拒否に成功 | 個別の外側時間は未計測 |
| Expr 全53構成子と分類表の名前の照合（読み取りの Python） | 0。53構成子、分類表の名前の欠落0件 | 未計測 |
| 変更した6文書の相対 Markdown ファイルリンクの存在確認（読み取りの Python） | 修正後0。リンク先の欠落なし。アンカーの自動照合は含めない | 未計測 |
| `git diff --check`（読み取り） | 0 | 未計測 |

最大常駐量（maximum resident set size）は取得できなかった。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告したためである。検査本体の終了0とは区別し、time 自身の終了状態は保存していない。検査本体の失敗と再実行はなかった。一時ログと検査本体の終了状態・時間は `/private/tmp/benitoite-c1rb3c-work.{log,json}`、time の出力は `/private/tmp/benitoite-c1rb3c-time.log` に保存した。必要な結果は上表に転記しており、別の状態への結果の引用を目的とする記録ではない。

局所のリンク点検は、初回の簡易正規表現がコード・数式の `](...)` もリンクと誤認して終了1となった。相対 Markdown ファイルへのリンク先の存在を確認する処理へ対象を限定して再実行し、終了0を得た。文書のリンク自体に修正を要する欠落はなかった。work 本実行後の追記は、import の所在の説明・07-04 の対応表・所見対応・本結果記録であり、仕様例のコードブロックと集計対象の見出し、Lean の入力は変えていない。

## 計画からのずれと申し送り

- 検査の割り当ての表に C1Rb3c の行はないため、今回の依頼で指定された formal_build・spec_examples・spec_tally だけを実行した。ほかの results.md には追記していない。
- C1Rc が検査全体の本体順と全体予算の駆動、別本体の予算付き発見、fuel の選び方を閉じる。これらを C1Rb の文書で実装済みとは扱わない。
- Rust の実装と独立交換では、親の警告だけでなく独立入力自身の候補も読む。親の未知の空 trace からその子の原因を保証せず、保存した入口環境と各入力自身の評価導出を使う。
- 「警告領域」の名称は設計者の選択待ちであり、本作業では変更していない。独立レビューと C1Rb 全体の受け入れは取りまとめの担当である。
