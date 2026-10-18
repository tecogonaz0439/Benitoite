# 0.0.8 の詳しい設計

## 目的と範囲

検査の重なりを減らし、実行の費用を下げる。確認する契約と実行する時期を割り当て、目的に必要な道具だけを足す。作業・段・改造・リリースの四水準を設け、変更に関係する検査、部品間の接続、全体の回帰、公開候補の受け入れを分担する。回帰検査（regression testing）は既存の機能を壊していないかの検査、受け入れ（acceptance testing）は公開する候補が利用目的と公開条件を満たすかの判定である。

本書は [C1〜C14](decisions.md) を具体化した段1の設計である。W1・W2a・W2bの実装に続き、W3で現行設計・規約・依頼文をそろえる。実装と検査の状態は [results.md](results.md) に分け、一般の作業への適用はRV1のレビューと指摘修正の完了後とする。既存のテストの期待値・大きさ・時間制限・ignoreの条件を、実行時間の短縮のために弱めない。

## 前提

基準は0.0.7公開後の `0027a22c171269cf5e5d975ee86bfd568efebb49` である。現行の実行部は [check.sh](../../../scripts/check.sh)、規約は [AGENTS.md](../../../AGENTS.md) と [07-03](../../design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査) にある。現状と過去の実績は [調査](study/check-policy.md) に記録した。過去の改造は作業の経緯と費用の資料であり、現行仕様の根拠にはしない。

ここで水準（level）は、検査を行う時期と責任の区分である。単体テスト・結合テストといった、対象による区分とは別である。作業でも本物の部品をつないだ統合テストを使う。Leanの先行条件は [07-04「01-12 との対応」](../../design/07-quality/07-04-formal-semantics.md#01-12-との対応) に従う。TODO-255自身は型の規則と脱糖（desugaring）を変えず、形式化の内側の改造には当たらない。01-12の規則・Leanの定義や証明はこの段では変えない。

## 水準ごとの責任と検査集合

| 水準 | 担当・確認すること | 実行する検査の集合 | 次の時期に任せるもの |
|---|---|---|---|
| work（作業） | 実装担当。変更した契約と入力の利用側が通ること | 途中は関係するテストのみ。Rustを変える作業の終わりに既定のlib全件・関連統合テスト・clippy・fmtを各一度。関係する生成物・仕様集計・文書例・道具の自己検査。ヒープ（heap）等の例外は下表 | examples のビルド（change で行う）、全件の特殊構成、全ターゲットのテスト、長いテストの全件、公開候補の確認 |
| stage（段） | 取りまとめ担当。初めてつながる部品間の受け渡し | 計画で名指しした接続の検査だけ。最後の作業で同じ接続まで確認済みならC8の条件で引用 | 作業のlib全件やlintの再実行、段数を理由にした全件検査 |
| change（改造） | 取りまとめ担当。統合後の回帰と構成の選択漏れ | Rustの変更があれば、既定・heap-verifyのworkspace all-targets、既定の文書コメントのテスト（doctest）、heap-verify+gc-stressのlib/tests、二構成のclippy（既定はlib/tests、heap-verifyはworkspace all-targets）、fmt、規約の機械検査、生成Skillと仕様集計、長い対象のみ。道具・依存等の変更には対応する検査も行う | 公開候補の版・配布・実CLIの確認。済んだヒープ・形式化の全比較は関係状態が同じなら引用 |
| release（リリース） | 公開の取りまとめ担当。実際の候補と証拠の一致 | 改造の検査記録との照合、候補の識別、版・同梱物・生成物・移行案内、実CLIの代表例、配布手順。最適化した構成のrelease_stackを一度 | 同じ関係状態の回帰全件の反復。タグや公開の操作は別の指示に従う |

文書・シェル・Pythonだけ、またはLeanだけの作業には、関係しないRustの全libを要求しない。Rustの作業末の四検査はC13の指定である。共有の型や入力が変われば、関連統合テストをその入力を読む側まで広げる。例としてgoldenの追加はcodegen corpus・verifyの読者も、構文の移行はRust文字列中の入力も対象になる。

段の検査を行う条件は、新しい接続、複数作業の相互作用、共有契約の切り替えがある場合である。段の最後の作業が同じ入力・構成の接続まで確認済み、独立した文書変更だけ、または直後の改造全体の検査がその接続を覆う場合は、参照結果と省く理由を記す。レビューと指摘修正後の再検査は残す。

| 例外の条件 | 作業時・接続時に必要な検査 | 改造末の扱い |
|---|---|---|
| 確保・回収・ポインタの生存・根・書き込みの障壁の不変条件を変える | 関係する既定・heap-verify、doc_default（compile_fail を含む文書テスト）、局所のgc-stress、必要な長い対象と `check-heap.sh`。次の作業の前提にする前に成功させる | 最後の関係変更に対する成功を引用できれば繰り返さない |
| VM等で安全点を越える値の保存を変える | 場所がheap/の外でも関係するheap-verifyとgc-stress。GC本体に及ぶならcheck-heapも加える | 全件の特殊構成も一度実行する |
| ヒープのコメント等だけを変える | 実装・入力・構成に影響しない根拠を記録し、計画に明示して絞る | パスだけを理由にMiriを反復しない |
| 形式化の内側の規則・脱糖を変える | 処理系より先に定義・証明・01-12の写し・必要な対応表。既定の `lake build` とsorryの拒否、定義・言明・仮定のレビュー | RustとLeanが接続した区切りと最終の関係状態で `check-formal.sh` 全体。成功済みなら引用 |
| 再帰の形・枠・最適化やビルド設定を変える | 関係するrelease_stackを名指しする | 公開するなら最終候補の構成に対応する成功をそろえる。公開しない改造ならchangeで行う |

## check.sh の指定と選び方

### 水準と変更範囲

新たに `--level work|stage|change|release` を加える。W2aで、水準の指定がない実行を直ちにworkへ切り替え、旧来の水準なしの自動選択は置き換える。水準なしの `--only`・`--full` は従来の実行集合を保つ。W2bに続くW3でAGENTS.md・07-03・07-04をそろえ、RV1の完了後に一般の作業へ適用する。RV1は進め方の関門であり、コードの既定を切り替える時点ではない。

| 指定 | 計画に固定する基準 | 自動で決める範囲 |
|---|---|---|
| work | 前の作業の取り込みのコミット。最初の作業は段1開始版 | 既存の分類から作業末の検査を選ぶ。Rustでは共通検査と関連統合テスト |
| stage | 段の開始版 | 自動選択なし。計画の `--only` を必須とする |
| change | 改造の開始版 | 既存の分類から改造末の検査を選ぶ。Rustでは全構成の一式 |
| release | 改造の開始版を表示 | 分類せず、Rustの変更の有無によらずrelease_stackを選ぶ。証拠の照合と実CLIは計画に従って別に確認する |

`--base` の既定は `origin/san_benito` のままにし、実装プランでは必ず基準を明示する。workとchangeの自動選択は、基準コミットから現在の作業ツリーまでの変更を扱う。ステージ済み・未コミット・未追跡のファイルを含める。変更の取得には `git diff --name-only --no-renames <基準> --` と `git ls-files --others --exclude-standard` を使い、重複を除く。削除と改名の旧パスも分類する。無視したファイルを暗黙の入力にせず、必要な入力は計画と結果へ明記する。

`--test <統合テスト名>` はwork・stageで繰り返し指定できる。Cargoの統合テスト名をそのまま渡し、空の指定と重複だけをcheck.shで拒否する。存在の確認はCargoへ任せ、cargo metadataや通常テストの件数の解析は加えない。任意のCargo引数やシェルのコマンド文字列は受け取らない。計画には完全なターゲット名を書く。

Rustのworkで `--test` がなければ、tests_relatedを `cargo test -p benitoite --test '*'` として全統合テストへ広げる。`*` はシェルで展開せず一つの引数としてCargoへ渡す。Cargo同梱の `cargo help test`「Target Selection」でこの指定を確認した（2026-10-17）。指定があれば複数の `--test <名前>` を一回のCargo呼び出しにまとめる。共有入力を変える計画では、その入力を読む全ターゲットを指定する。libだけに閉じる変更で統合テストを省くなら、理由と明示的な `--only` を計画へ書く。

stageの `--only` の欠落、tests_relatedの明示選択での `--test` の欠落、対象のない局所検査は指定の誤りとして終了2にする。文書だけ等で段の検査を省く場合は、実行を求めず、取りまとめ担当が省く理由と引用元を記録する。

### 検査の実行単位

従来の複合したrustを、新水準では次の単位に分ける。check.shはbash 3.2を対象とし、既存の分類と固定した検査名の集合を使う薄い対応処理をシェル内に足す。選択専用のPythonや新しいファイル分類表は作らない。コマンドは引数の配列で組み立て、evalしない。`set -u` の下の空配列と未指定の `--test` も自己検査に含め、連想配列は使わない。実装済みの指定とその検査結果は results.md に記録する。

| 新水準の検査名 | 実行するもの・範囲 |
|---|---|
| fmt | `cargo fmt --all --check` |
| lint_default | 現行と同じ `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`。examples・binsへ広げない |
| lib_default | `cargo test -p benitoite --lib` |
| tests_related | 上記の関係する統合テスト。未指定のworkは全統合ターゲット |
| test_default_all | `cargo test --workspace --all-targets` |
| test_heap_all | `cargo test --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify` |
| test_stress | `cargo test --workspace --lib --tests --no-default-features --features gc-mark-sweep,heap-verify,gc-stress` |
| doc_default | `cargo test --workspace --doc` |
| lint_heap | `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` |
| source_rules | 仮置きの許可・unsafeの許可位置の既存検査 |
| skill_generated | gen_skillによる既存の再生成照合 |
| spec_tally | 既存のspec-coverageの自己検査と集計 |
| spec_examples / reference_examples / skill_docs | 対応する既存の統合テスト |
| python_syntax | 現行のtools/のPython構文検査 |
| migrate_selftests | source-migrateの自己検査、`cargo build -p benitoite --example try_actions_inventory`、try-actions-migrateの自己検査。現行と同じ範囲とし、named-arguments-migrateの自己検査は加えない |
| skill_eval_selftest / licenses | 現行のskill-eval自己検査／許諾の検査。LLMを呼ぶ評価は含めない |
| long_only | heap-verify と heap-verify+gc-stress の構成ごとに一括実行し、形式化の書き出しを除外。成功件数は 1 以上 |
| heap_local / stress_local | `--test` で名指しした統合テストだけをheap-verify／heap-verify+gc-stressで実行 |
| heap_checks | `scripts/check-heap.sh` |
| formal_build | sorryを拒む既定の `lake build` |
| release_stack | 名前の前置きで測定済みスタックの対象を release で一括実行。成功件数はちょうど 10 |
| policy_selftest | `python3 -B scripts/check/test_policy.py`。中でcheck.sh・check-heap.sh・check-formal.shの三つに `bash -n` も行う |

heap_local・stress_localには `--test` を必須とする。局所のlibテストは、計画へ `cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep,heap-verify <フィルタ>` と、gc-stressを足した同じコマンドを直接書く。対象と期待する契約を計画で固定し、check.shにlibの局所指定や件数の照合を増やさない。

同じコマンド・構成・対象は一回だけ実行する。test_default_allがあればlib_defaultと単独の文書例テストを包含し、理由を表示する。workのtests_relatedが全統合ターゲット、または同じ文書例ターゲットを含む場合も、spec_examples・reference_examples・skill_docsを重ねない。構成が違うgc-stressは包含しない。結果の引用は手動で記録する。

| 水準 | `--only` で許す検査名 |
|---|---|
| work | fmt、lint_default、lint_heap、doc_default、lib_default、tests_related、source_rules、skill_generated、spec_tally、spec_examples、reference_examples、skill_docs、python_syntax、migrate_selftests、skill_eval_selftest、licenses、policy_selftest、heap_local、stress_local、heap_checks、formal_build、release_stack |
| stage | tests_related、heap_local、stress_local、policy_selftest |
| change | fmt、lint_default、lint_heap、test_default_all、test_heap_all、test_stress、doc_default、source_rules、skill_generated、spec_tally、spec_examples、reference_examples、skill_docs、python_syntax、migrate_selftests、skill_eval_selftest、licenses、policy_selftest、long_only、heap_checks、formal_build、release_stack |
| release | release_stack |

lint_heapは、heap/のworkでは自動で加える。他のパスでもheap-verify側の条件付きコードや構成を変えるなら計画で名指しする。check-formal.sh全体とlibの局所検査等、この入口に収まらないものは計画へ直接のコマンドを書く。部分選択の成功は水準全体の完了判定を代行しない。

### 既存の分類から水準への対応

現行のclassifyは「ファイル → 既存の種類」の処理として使い続け、その結果にだけ下表を適用する。roadmap→spec_coverage、fuzz→rust、check-formal.sh→formal、許諾の設定→licenses、tools/skill-eval→skill_eval、formal/reviews→対象外等の既存の対応を保つ。新たに既知の分類へ加えるのはcheck.shとscripts/check/のpolicy_selftestだけとする。

| 既存の種類 | workの自動選択 | changeの自動選択 |
|---|---|---|
| rust | fmt、lint_default、lib_default、tests_related、source_rules、skill_generated、spec_tally | fmt、lint_default、lint_heap、test_default_all、test_heap_all、test_stress、doc_default、source_rules、skill_generated、spec_tally、long_only |
| default_lib | lib_default | test_default_all |
| long | 自動追加なし。安全点を越える値等を変えるなら、計画に局所の特殊構成を加える | long_only |
| heap | lint_heap、doc_default、heap_checks。局所の二構成は計画に直接のCargoコマンドを書くか、対象付きのheap_local・stress_localで行う | heap_checks |
| formal | formal_build | formal_build |
| licenses | licenses | licenses |
| python | python_syntax、migrate_selftests | python_syntax、migrate_selftests |
| skill_eval | skill_eval_selftest | skill_eval_selftest |
| spec_examples | spec_examples | spec_examples |
| reference_examples | reference_examples | reference_examples |
| skill | skill_generated、skill_docs | skill_generated、skill_docs |
| spec_coverage | spec_tally | spec_tally |
| release_stack | 自動分類では出現しない。必要な計画が名指しする | 自動選択しない。公開しない改造の計画が名指しする |
| policy_selftest（今回追加） | policy_selftest | policy_selftest |
| full（分類不能の印） | 実行前に停止 | 実行前に停止 |

複数の種類があれば和集合を取り、前節の包含だけを適用する。Rustのworkは生成元やspec印のパスを別に調べず、skill_generatedとspec_tallyを常に選ぶ。構文の章だけの変更ではskill_generatedとskill_docsを組にし、spec_examplesとspec_tallyも既存の分類から選ぶ。道具・Cargo・formal・heapの条件付き検査もchangeが自動で選ぶ。成功済みの結果を引用して再実行を避けるなら、計画にそれを除いた `--only` と引用の行を記す。

check-heap.shは分類不能のまま、check-formal.shはformalのまま残す。説明だけの変更を自動判別する仕組みは作らない。段1で両者の説明を直すW3は `--only policy_selftest` を使い、三つのシェルの構文を確かめる。自動選択のdry-runが停止することも、段末の期待に明記する。他の未知のscriptsをまとめて許可しない。

ファイルの種類だけでは、共有入力やビルド構成への影響を決めきれない。計画とdry-runを照合し、入力を読む側と必要な構成を補う。分類不能のファイルと存在しない基準で終了3となったら、該当箇所を示し、設計者に当該水準の `--level … --only`（停止までに選んだ単位を案内し、分類不能のファイルに必要な単位を補う）、互換の `--full`・水準なしの `--only`、`--none`のどれで続けるかを尋ねる。段1の検査はplan.mdに名指しし、オーケストレータが走らせる前に設計者へ知らせて実行する。別の承認欄は設けない。

### 既存オプションと終了状態

| 指定 | 保つ意味・新しい制限 |
|---|---|
| 水準なしの `--only` | 現行の13名と実行集合を保つ。policy_selftestも新たに名指しできる。rustは従来のfmt・両lint・heap-verifyのworkspace test・gc-stress・規約・Skill・集計。longはrustを追加してinclude-ignored。default_libは単独でも指定可能。formalはlakeだけ、heapはcheck-heapだけ |
| 水準なしの `--full` | 現行のrust・default_lib・long・release_stack・licenses・spec_examples・spec_coverage・reference_examples・skill・skill_eval・pythonを保つ。heap・formal・check-formal全体や二構成all-targetsは追加しない。releaseの別名にはしない |
| `--level` と `--only` | 当該水準の検査名だけを許す。名指しした検査だけを走らせ、差分の分類も分類による停止も行わない。`--base` は表示に使うだけ。部分選択と表示する。rust・long・python・skill・formal等の旧複合名は拒否 |
| `--test` | work・stageのtests_related・heap_local・stress_localだけに使う。水準なしの旧only/fullとの併用を拒否。存在しないターゲットは実行時にCargoが失敗し、check.shは検査失敗の1を返す。dry-runでは存在を確認しない |
| `--base` | work/changeの自動選択だけがコミットの存在を検査する。旧only/full、新水準のonly、releaseでは表示だけ |
| `--dry-run` | 計画表示だけで、ビルド・テスト・生成をしない。停止なら水準指定の有無によらず3。旧自動選択の「停止予告を出して0」の扱いは引き継がない |
| `--none` | 設計者が不要と判断したときの明示指定。ほかの実行指定と併用しない |

`--full` と `--level`、full/only/noneの相互併用、不正な水準、値の欠落、空のonly要素、重複した単一オプション、空・重複したtest、選択した検査で使わないtestは終了2とする。stageのonly欠落、明示したtests_relatedの対象欠落、局所検査の対象欠落も2である。無指定で自動選択するworkのtests_relatedだけは、前述の全統合ターゲットを既定とする。終了3は自動分類での分類不能と基準不明に限り、計画の誤りを設計者へのfull/only/noneの質問へ変えない。選んだ検査の成功は0、検査失敗と必要な道具の不在は1とする。

### dry-runと結果の表示

dry-runには水準、基準、対象ファイル数、検査名・完全なコマンド・構成・対象・理由、包含で省く検査、後の水準の担当を出す。分類しない指定では `changed files not classified` と表示し、差分の表示を必須にしない。実行時間の見込みは検査ごとの固定の文字列とし、現行のdescribeと同じ形で出す。未計測なら「未計測」、long_only・heap_checks・release_stack等は長い検査であることと固定の予算を示す。時間を計算する仕組みは作らない。実行時も同じ選択と表示を使う。

終了0は「選択した検査が成功した」と表示し、水準全体の完了とは区別する。releaseは「候補と証拠の手動照合が別に必要」と表示する。受け入れの判定者と記録先は計画で固定し、自動の証拠ファイル解析や公開の実行は加えない。

## 長いテストの実行と検査方針の自己検査

### 長い対象の一括実行

【決定】長い対象の一覧は作らない。`long_only` は heap-verify と heap-verify+gc-stress の構成ごとに、`cargo test --workspace <構成> --lib --tests -- --ignored --skip export_coverage --skip export_desugar_corpus` を一回実行する。二つの `--skip` は形式化の書き出しを除き、その実行は check-formal に任せる。libtest の並列実行を使い、各ターゲットの要約の成功件数の合計が 0 なら失敗にする。長いテストを足すときはソースに前述の ignore 属性を付けるだけでよく、別の一覧への登録は要らない。

`release_stack` は `cargo test --release -p benitoite --lib -- pipeline::tests::stages_fit_the_measured_stack_ --include-ignored` で選び、成功件数がちょうど 10 であることを求める。テストの属性・名前・期待値は変えない。再帰の形・枠・最適化やビルド設定を変える作業では関係する release_stack を名指しし、公開しない改造なら change へ、公開するなら最終候補の構成へ対応する成功を割り当てる。

`scripts/check/run_ignored.py` はこの一括実行と要約の件数確認だけを担う。入口は `python3 -B scripts/check/run_ignored.py --kind long|release-stack --configuration heap|stress|release` とし、long は heap/stress、release-stack は release の組み合わせだけを許す。cargo metadata とターゲットごとの列挙は呼ばない。要約の欠落、失敗・無視・測定の混入、Cargo の失敗を成功にしない。ビルドの進捗を含む標準エラーと、標準出力を逐次表示する。

### 自己検査の境界

自己検査は `scripts/check/test_policy.py` にまとめる。test-auditの作成時の四問を結果へ記し、主な境界をcheck.shの入口から観察する選択・実行・停止・失敗伝播と、長い対象の実行器の選別・件数に限定する。内部関数やソースの字面を写す検査は作らない。

小さな一時Gitリポジトリへ実際のcheck.shと道具を写し、基準コミットと変更を作る。最低限、空でもよい `crates/benitoite/src/` と `formal/`、パスで呼ばれる `scripts/check-heap.sh` の代用、`deny.toml` と `scripts/release/about.toml`、構文検査に使うtools/のPythonも用意する。実際の道具のスクリプトは写して使い、代用するのはcargo・lake・check-heap.shだけとする。gitとpython3は本物を使う。policy_selftest自体の再帰呼び出しは実行せず、その選択をdry-runで観察する。

代用プロセスは引数と起動順を記録し、指定した失敗を返す。分類・選択・引数の組み立ては本物を使う。既存リポジトリのcheckoutや本番のテスト専用フラグは使わない。W1 時点の一覧と列挙は Z1 で廃止する。構成ごとの呼び出し、除外する名前、成功件数と失敗伝播を入口から確かめる。

| 契約 | 入力と期待する結果 |
|---|---|
| 互換性と切り替え | W1で改造前の旧only13名・full・引数なし（文書、Rust、heap、分類不能、基準不明）のコマンド・順序・終了状態を採取する。旧only/fullとそれぞれのdry-runはW2でも一致。引数なしはworkの集合へ変わり、停止のdry-runは0から3へ変わることを別に確認 |
| 水準・範囲 | 同じ差分のwork/change、異なるbase、ステージ済み・未追跡・削除・改名を確認する。stageは名指しだけ。分類不能・基準不明は3、指定の誤りは2、level+onlyは分類せず名指しだけ |
| 対象と包含 | testの空・重複・不要な併用・局所対象の欠落を拒否する。libと文書例の包含、異なるstress構成の保持を確認する。通常テストの出力件数は解析しない |
| 非実行と失敗 | dry-runはcargo・lake・check-heap等を起動しない。実行の先頭・途中・最後の失敗は1。後続を成功と表示しない |
| 長い対象 | long・formal・通常の対象の混在からlongだけを実行。構成ごとに一括実行し、形式化の書き出しを除外。対象0件・要約の欠落や不正・外部失敗は失敗。release_stack は成功10件を要求 |
| release | Rustのない差分でもrelease_stackだけを選ぶ。回帰全件は選ばず、手動照合の必要を表示し、受け入れ完了とは表示しない |

新しい道具はpolicy_selftestの分類で自身を検査する。実際のシェルの構文検査もこの自己検査の中で行う。処理系の全対象を走らせることで、選び方の検査を代用しない。

## 済んだ結果を引用する条件と保存先

普通の作業の results.md は、基準のコミット、走らせたコマンド、終了状態、外側の時間、計画からのずれと申し送りだけを記す。失敗した場合は原因と修正もこの範囲で残す。結果を引用するときに限り、以下の全欄を記録する。

自動キャッシュは作らない。検査の入力が同じかを担当者が判断し、結果と根拠を表へ残す。キャッシュはビルド時間を短くする生成物、引用する結果は過去の成功を現在の完了条件へ対応させる証拠であり、扱いを分ける。

| 記録する欄 | 必要な内容 |
|---|---|
| 対象の状態 | 基準の完全なコミットID、対象HEAD、差分の有無とファイル一覧。別の状態へ結果を引用するときだけ、未コミット差分と未追跡入力の内容のSHA-256も保存する。HEADだけで同一としない |
| 検査の入力 | 関係するソース、テストと入力・期待値、生成元・生成物、設定、交換器・入力の一覧（manifest）、実行する道具の版またはハッシュ |
| 実行 | 水準、正確なコマンドと構成・ターゲット・フィルタ、ツールチェーン、対象件数・成功/失敗/無視/対象外、終了状態、外側の経過時間、環境の制限 |
| 引用 | 元の結果の場所、以後の変更、影響しない理由、判断者と日付。引用できない場合は再実行する検査 |
| 修正 | 初回の失敗、原因、修正、再実行。環境要因という推定を機能の成功で置き換えない |

結果はDの `<小文字作業ID>/results.md`、段・改造・公開候補の集約はDの `results.md` に置く。実績は各作業で記録する。生ログをwork/やtarget/に置く場合も、引用に必要な状態・コマンド・件数・結論は追跡する文書へ残し、一時ファイルだけを参照先にしない。

日本語訳だけを変えても、その訳を抽出して実行するテストがあれば入力は変わる。標準ソース・Cargo設定・build.rs・文書の実行例・生成物・テストの期待位置を変えれば、関係結果を再検査する。影響を説明できない結果は引用しない。コミットだけ変わっても意味上の入力が同じなら回帰の結果を引用できるが、候補のビルド情報・版・同梱物は実際の公開候補で確認する。

## 共通の依頼文と実装プランの雛形

### 置き場所と規約の正

`docs/workflow/implementation-request.md` と `docs/workflow/change-plan-template.md` を新設する。前者はCodexへ渡す共通の依頼文、後者は改造ごとの実装プランの雛形である。実行方針の正は07-03、形式化の順序の正は07-04、AGENTS.mdは日常の要約と参照先を担う。docs/workflow/は設計書ではないが、説明するcheck.shの指定はW2で実装したものに限る。雛形には未実装の言語仕様を置かない。

理由: 改造を保管した後も使う文面なので、今回のDや読み取り専用のarchiveを継続利用の正にしない。検査だけのために新しいスキルを増やさず、AGENTS.mdと07-03から通常の作業文書へ案内する。雛形を直すときも実際のスクリプトと同じ変更でそろえる。

### 共通依頼文と雛形の本文

共通依頼文は [docs/workflow/implementation-request.md](../../workflow/implementation-request.md)、実装プランの雛形は [docs/workflow/change-plan-template.md](../../workflow/change-plan-template.md) へ移した。改造ごとに写して作業・基準・担当・検査の割り当てを具体化する。本文をこの文書へ重ねて保守しない。

作業末はworkがあればcheck.shを一度、未実装の移行中なら計画の直接のコマンドとする。具体的な検査は計画の割り当て表の当該work行へ集め、依頼文や作業の節へ全件のコマンド一式を複写しない。全件の特殊構成・長い対象・check-formal・check-heapには実行または引用の行を設け、後の水準の取り忘れを確認する。

## 書き直す文書と切り替え

| 対象 | 実装時に書き直す要点 |
|---|---|
| AGENTS.md | 「テストの運用」とディレクトリ表のscripts/formal、docs/workflow/・scripts/check/の行。作業末の一度の検査、条件付きの段、改造全体と公開候補、dry-runと停止、結果の引用。雛形への案内 |
| 07-03 | 「実装の規約と静的な検査」「ヒープとランタイムの確かめ方」と長い対象。四水準・実行集合・互換指定・例外・記録を正として書く。既存見出しとテストの設計原則は保つ |
| 07-04 | 「道具と置き場所」等の検査時期を07-03参照へそろえる。check.shのformal_buildと独立のcheck-formalを区別。先行条件・対応表・証明の保証は変えない |
| test-audit | 「確かめる」で当該水準の計画に従うと明記。作成時の関門とテストの価値の基準は維持 |
| clean-build | ビルドキャッシュと追跡する検査記録を区別し、targetだけを引用元にしない。削除範囲・許可の規則は変えない |
| check.sh・check-heap.sh・check-formal.shの説明 | ヘルプと先頭コメントを実装に合わせる。後二者は説明だけの変更を基本とし、実行集合は変えない |
| docs/workflow/の2文書 | 上記の共通依頼文と計画の雛形を置く。新規ディレクトリをAGENTS.mdから案内する |
| 関係する呼び出し元 | rgで旧only/full、毎段の全件、過去の実装プランの共通の検査の節の複写を検索し、現在使う説明だけをそろえる。過去archive、初回実装用のagents、docs/todoは書き換えない |

git-workflowには検査の規定がないので変更しない。benchmark・skill-evalの測定・LLM呼び出しの規則もこの変更では変えない。現行設計はW2に続くW3で実装済みの指定へそろえ、RV1より前に一般の作業へ適用しない。未実装の指定を現行仕様として先に書かない。

段1は [plan.md](plan.md) のW1・W2a・W2b・W3の4作業で実装・確認する。W2をwork/stageとchange/releaseの二つに分ける。移行中は、その作業で具体的に指定した検査を使い、一般の依頼を新方針へ切り替えるのはW3と段1レビューの後とする。以後の段は新方針で計画する。W3の完了だけではRV1の完了としない。切り替えの状態はresults.mdへ記録する。

## 段2以降の設計の位置付け

以下は `677f99447c63f996d0de71458afba34c51b8e23d`（段1取り込み後）を読んで作った実装前の案である。上のTODO-255の節は段1の記録として残す。47問の回答は変更せず、具体化に伴う判断とL0後の設計者の回答は [decisions.md](decisions.md) のR6〜R17に記す。案B・正規形・R7・公開APIと予算・工数超過は決定済みであり、[RV2初回の指摘](reviews/RV2-initial.md) はA2で反映し、証明の成立とRV2の閉鎖は未了である。この文書の例は提案する受け入れ条件であり、実行済みの例ではない。

型クラス（type class）の辞書、型付きの失敗（typed failure）、網羅性（exhaustiveness）の変更は形式化の内側である。段2で全項目の定義・証明・写しと交換入力のLean側を完了し、RV2を閉じてからRustへ進む。外部の生成道具の編集・照合、JSONの往復、乱数の分布、縮小の最小性、タスクとVMの実装は証明の対象外とする。内外の対応は後述の表に集める。

### 共通の表現と互換性

公開の関数型は利用者の契約名だけを持つ。辞書は内部名 `%dict1` 以降を前置し、継続は節の最後の内部引数とする。型引数とエフェクト引数は実行時に消す案であり、失敗のエラー型を消してよい根拠は後述の捕捉の定理で先に示す。操作番号は宣言の同一性を表す。型の表示文字列を操作番号や捕捉の鍵にしない。

0.0.8でも裸の `try` は `or return` と同じ意味であり、`or die` は `Process.Exit` と表示の既存契約を持つ。標準IOのResultの戻り値と公開CLIのサブコマンドは変えない。Characterの全域の後の分岐の拒否は互換性を壊す変更として扱う。通常入力のlanguage宣言は最後のV1で一度更新し、旧版・未来版・不正版を拒否する入力は、その目的を保つ。

## TODO-189: 操作の制約と辞書渡し

### 構文と型付け

`effect` 内の操作で、値の型のパラメータに通常の型クラスの制約を許す。`[T: C & D & equality]` ならCとDの二辞書を、宣言に書いた順で渡す。組み込みの制約は辞書数に含めない。上位の型クラスの辞書は受け取った辞書から取り出し、暗黙の追加引数にしない。操作の型構成子パラメータ、エフェクトパラメータ、利用者が書く操作自身のusesは引き続きE0510で拒否する。

宣言の値引数を `x̄:Ā`、結果をB、所属をL、制約の辞書型を `D̄` とすると、公開型は `∀ᾱ. (n̄:Ā) → B ! {L}`、コアの操作型は `∀ᾱ. (%dict̄:D̄, n̄:Ā) → B ! {L}` とする。呼び出す位置で型引数と辞書を選ぶ。節ではᾱを、ほかの型と等しくできない型（rigid type）として導入し、宣言の制約だけを仮定する。節の位置で具体的な実装を選び直さない。

Rustの `DictExpr` に節の所属を持つ根拠 `Clause { clause: NodeId, constraint: u32 }` を加える案とする。番号だけを外側の `Param` に流用しない。局所の根拠の型は `(節ID, 型パラメータ番号, クラスID)` から決め、上位の根拠もその所属を保存する。型検査の節の環境は入れ子で保存・復元する。ラムダが辞書を捕える場合は通常の自由変数の収集を使う。

### 脱糖と実行

直接呼び出しは、辞書を内部の値として用意し、値引数をソース順に一度評価し、契約名の位置対応で宣言順へ並べ、`op[T̄](d̄, x̄)` とする。辞書の構築は純粋であり、値引数の効果の順序を変えない。操作名の値化は `λ[n̄](x̄). op[T̄](d̄,x̄)` に写す。辞書は関数値を作る時点で捕え、操作のエフェクトは呼ぶ時点に残す。穴とパイプは既存の共通の配置処理に接続する。

コアIR（中間表現、intermediate representation）の `Clause` に `dict_params: Vec<DictParam>` を加え、値のparamsとcontは分けて保つ。操作の `OpDef` とバイトコードのarityは辞書数＋値引数数、節の原型はそれに継続一つを足した個数とする。独立したIRの検査は、辞書の数・クラス・対象のrigid型・所属・順序と、値引数・継続の型を宣言から再計算して照合する。未使用の辞書も個数に含める。

`PERFORM` の符号化は保つ案とする。既存の任意個の引数の受け渡しに辞書を含め、コード生成の「辞書付き操作」の内部エラーを、実際の引数の配置へ置き換える。VMと参照インタプリタで同じ順序を使う。辞書を置いたレジスタ・節の捕捉環境・捕えた継続はGCの根の走査に含め、安全点を越える裸のValueを作らない。引数個数・レジスタの範囲の実行時検査は維持する。

### Leanの変更と受け入れ

Surfaceの操作の宣言に `dictParams`、操作名に辞書の根拠、節に辞書数を持たせる。Releaseへ渡す操作のparamsとnamesは辞書を前置したものとする。節のde Bruijn番号は、0が継続、1から値引数の逆順、その後が辞書の逆順、最後が外側の環境である。型の番号は操作の型パラメータの個数だけ外側をずらす。辞書の型のパラメータ番号の範囲と `NamesWF(internalNames ++ names, dictTys ++ params)` を整形式の条件とする。

既存の `V_Op`・`C_Handle`・`E_Op` は普通の引数として辞書を受ける。Surfaceの `E_Op`・`HasClauses`・脱糖・checker・番号のずらしと代入を直し、`desugar_typed`・`surface_effect_soundness`・checkerの健全性を維持する。追加の補題案 `op_dicts_typed` は、宣言の制約を満たす根拠の列を前置した呼び出しに宣言どおりの型が付くこと、`clause_dict_scope` は節の根拠がその節の辞書の束縛へ写ることを述べる。過去の試みの枝を取り込むことは完了条件にしない。

受け入れは `Render.render[T: Trait.Show](value: T) -> String` の一つの節でIntegerとStringを表示できることである。二つのクラス、上位のクラス、外側の辞書と節の辞書がともに0番の例、節内ラムダの捕捉、操作の値化・穴・パイプを対照にする。表示の結果、ソース順、一度だけの評価を観測し、辞書の番号の字面だけを検査しない。型クラスの実装がない場合は既存の制約診断、公開の引数名・個数の誤りは既存診断を使う。189だけのための新番号は増やさない。

## TODO-249: 型付きの失敗とResultとの相互変換

### 名前と構文

標準モジュールは `Benitoite.Unofficial.Failure`、利用者名は `Failure` とする案である。preludeへ名前を追加せず、明示的にimportする。標準の宣言の同一性で `Failure.Fail` と `Failure.raise` を識別し、同じ綴りの利用者定義を特別扱いしない。

公開の契約は次の三つである。`effect Rest` は残りのエフェクトであり、toResultのRestにはFailが含まれない条件を付ける（後述）。

```text
raise[T, E](error: E) -> T uses Failure.Fail[E]
fromResult[T, E](result: Result[T, E]) -> T uses Failure.Fail[E]
toResult[T, E, effect Rest](body: function() -> T uses Failure.Fail[E], Rest)
  -> Result[T, E] uses Rest
```

`EffectRef` に型引数の列と位置を追加し、uses内で `Qualified.Name[Type]` を読めるようにする。名前解決後、標準Failだけにちょうど一つの値の型を要求する。一般の `effect L[E]`、他のエフェクトへの型引数、Failの引数省略・余分な引数は拒否する。formatterと型の表示も型引数を保つ。新しい予約語、`or fail`、catch構文は追加しない。

`Failure.Fail` とraiseの宣言は、標準モジュールの読み込み時に組み立てる標準専用の宣言とする。通常の `.bnt` に未対応の `effect Fail[E]` を書かない。既存の中身を見せないGeneratorと同じく、標準宣言の表から公開する。`Failure.bnt` はその宣言を参照する通常のfromResult・toResultの本体を持つ。raiseは通常の `@builtin` のIO関数へ置き換えず、操作として登録する。標準表・Skill生成・formalの信頼する宣言の書き出しもこの宣言を読む。

### 一つのエラー型と残りのエフェクト

エフェクト集合εに `Fail[E]` という原子を追加する。同じ集合で二つのFailが現れたときはEを不変の型として単一化（unification）し、一致すれば一つにする。一致しなければ拒否する。エラーの暗黙の和、Stringへの変換、型の包含によるエラー型の拡大は行わない。Eは、関数型のエフェクトを含む任意の値の型でよい。

RustではEffectNameの通常名の表現を保ち、EffectSetに `failures: Vec<Ty>` を加える案とする。確定したソースの計算では長さ0か1とし、推論中の候補と内部の継続の補助的な上限は複数を表せる。Fail列は型の上の固定した全順序で整列し、重複を除いて保持する（R13）。型代入・行の具体化・shift・和等で型や並びが変わった後も、型内部まで正規化し直す。`is_empty`・型の表示・代入・ハッシュ・自由な型変数の収集はfailuresも読む。単一化する和は推論器の失敗しうる操作、確定した上限の和は集合の演算として分ける。SchemeにNoFailのEffVarの集合を保存し、型検査の表には節の固定Eとabortの種類、局所の行の条件を記録する。IRと交換の独立検査がこの表を再検査する。

型引数を実行時に消すため、行変数（row variable、エフェクト集合を表す変数）の条件 `NoFail(ρ)` を内部の契約に加える（R7の決定）。公開の新しい構文にはしない。シグネチャの同じusesに明示したFailと並ぶρにNoFailを付ける。Failのhandleの残りのρにもNoFailが必要だが、その根拠はシグネチャから得なければならない。単独のρは、条件がなければFailを含んでよい。したがって通常のList.mapのエフェクト多相はFailを運べる。

| 操作 | 規則 |
|---|---|
| 型の代入 | FailのEの中も再帰して代入する。型の別名は展開して同一性を判定する |
| 行の具体化 | NoFail付きρへ名前の集合とFailなしの行だけを渡す。未解決の行ならNoFailをその行へ伝える |
| 和・包含 | 推論中のFailのEを単一化してから和・包含を判定する。確定後の純粋な集合演算が衝突を捨てて成功する実装にはしない |
| 一般化（generalization） | 宣言したシグネチャの字面だけからNoFailを計算する。値引数・戻り値の中の関数型も辿り、同じusesにFailと並ぶ行を集める。Scheme・型付き表層・交換形式に同じ条件を保存する |
| 呼び出し・値化・合流 | 署名由来の条件を複製して具体化する。その後の効果にFailが高々一つであることを直接検査する。異なるEが残ればE0514。メソッド、ラムダ、穴、パイプ、別モジュール、高階関数でも同じ規則を使う |
| 未確定 | シグネチャ由来の条件でNoFailを確認できなければE0515。閉じた入口の未確定条件も拒否し、空へ既定化して消さない |

NoFailは関数の本体から推論しない。関数・メソッドのシグネチャ全体を辿り、各usesでFailと並ぶ行だけからQを計算する。toResultのシグネチャはこの規則でRestのNoFailを得る。本体のhandleがそれ以外の行にNoFailを要したらE0515とし、引数の関数型に境界のFailを明示する、内側でResultへ戻す、捕捉の境界を移す、という修正を案内する。相互再帰でも宣言収集時のQを使い、本体による不動点の推論やモジュールをまたぐ追加伝播はしない。型クラスのメソッドも同じ規則とし、実装の本体からクラスのシグネチャの条件を強めない。ラムダは期待する関数型と明示した注釈の条件の範囲で検査する。

型の表示には `Rest excludes Failure.Fail` という説明を添える。単一化・一般化のアルゴリズム全体の証明は今回の範囲にせず、書き出したシグネチャからLeanの検査器もQを計算し照合する。「Failは高々一つ」は代入で保つ性質ではない。たとえば効果 `{RV1,R2}` へ `RV1 := {Fail[A]}`、`R2 := {Fail[B]}` を渡すと、各置換が許容されてもA≠Bなら二つになる。表層の呼び出し・値化・合流の規則と検査器は具体化した後にこの条件を課し、Rustもその位置でE0514を報告する。Releaseの型・計算・状態に単一Failの不変条件は課さない。

### 捕捉と節の型付け

Failure.raiseの操作の型引数は `[T,E]` である。Failの節ではEを本体のFailと期待型から決め、Tだけを節の新しいrigid型にする。節の `error` はE、節全体の戻り値はhandleの結果Uである。TをEやUと等しくしない。

型付きの節には捕捉するエラー型Eと `abort` の印を持たせる。ReleaseのHasFailureClauseはFailの節ちょうど一つに限り、通常のHasTypeClausesはraiseの節を拒否する（R17）。元の構文は `case Failure.raise(error) -> ...` のままとする。handleの本体が持つFailを除いた後に、節のエフェクトを合わせる。節自身はそのhandleの外側で実行するため、節が `Fail[F]` を起こすことと本体の `Fail[E]` は別に検査する。節から別のエラー型をraiseする明示変換を許す。

型付けの規則案 `C_Handle_Fail` は、本体 `M:U ! εb`、`εb ⊆ {Fail[E]} ∪ Rest`、`NoFail(Rest)`、境界Eに固定したabort節 `N:U ! εc`、出力 `εout = Rest ∪ εc` を前提とする。本体に許す効果と節の出力は別々に検査する。通常のC_Handleの `εb ⊆ εout ∪ handled` だけを使うと、節が外へ出すFail[B]まで本体へ許してしまうので、この部分を置き換える。通常の操作だけのhandleは従来の規則を使い、Failを名前だけでhandledへ入れない。

継続（continuation）の型付けには次の専用規則を置く。P・B・ストア型Ψは共通の引数として省略する。`NoFail(Rest)` は閉じた状態ではFailの原子も行変数もないことを表し、型の内部の潜在エフェクトまでは禁じない。

```text
K_Handle_Fail
  ContTy R ε k t b ε0 Re
  Rest ⊆ ε        NoFail(Rest)
  HasFailureClause E R h t εc        εc ⊆ ε
  Ty.WF 0 t
  -------------------------------------------------------------
  ContTy R ({Fail[E]} ∪ Rest) (.handleF h :: k) t b ε0 Re
```

`HasFailureClause` はEに固定した中断の節ちょうど一つを検査する関係であり、継続の0番を環境のnoneで利用不能にする。handledのFail列が空であることは定義から導き、規則の前提には置かない。穴に許す効果は `{Fail[E]} ∪ Rest` であり、節の効果εcや外側εの全体を穴へ入れない。通常のK_Handleは普通の操作だけの枠に使う。`C_Sub` と型の包含関係 `Ty.Le` は変えない。Releaseでは外側の効果や補助的な上限に複数のFailがあってよい。

捕捉先との一致はこの規則から示す。SplitAtが選んだ枠より内側の継続K1にはraiseの節がなく、したがってFailの枠もない。K1の各枠はFailの原子を外側へそのまま渡す（普通のhandledは名前だけを除く）。穴のraiseがFail[E′]を要すれば、選ばれたFailの枠の内側の効果にもその原子が含まれる。そこは `{Fail[E]} ∪ Rest` でRestはNoFailなので、E′=Eを得る。単一Failの代入保存を仮定せず、継続の規則とこの伝播の補題を証明する。

0.0.8ではFailの節と普通の操作の節を一つのhandleに混ぜることを禁じ、E0518で「handleを二重にする」と案内する。Failだけのhandleの内外に普通のhandleを置くことは許す。表層・IRの独立検査・Leanの検査器・Releaseの型付けも同じ区別を守る。

本体に `Fail[E] ∪ Rest` を上限として与え、`NoFail(Rest)` を要求する。Eが決まらない場合は、結果の束縛またはbodyの関数型の注釈を求める（R83）。純粋なbodyもこの上限への包含で許す。異なる型のFailがRestに隠れる形は拒否し、型で内側の節を飛び越す実行は提供しない。

Failの節はresumeを静的に禁止する。型付き表層・IRの独立検査・Leanのcheckerでも、継続用の0番を利用不能にする。内部の枠にはその位置を予約し、実行の既存のdropによる解放に使う。L2aでは節がTだけ一つ束縛することに合わせ、E-OpでTだけを代入する規則と、閉じた状態で余分なE′の代入が無害となる補題を比較して決める。Ψ κのcont型・保存継続のContTy（末尾のK_Handle_Failとその下のK_Empty）・CellOk・K_Dropをコード片で確定する。ラムダ・lazy・ガードに継続を渡さない規則も維持する。通常の操作の節は従来の再開を許す。

同じEを扱う入れ子は最も内側が捕捉する。異なるEの入れ子は、内側がその失敗を完全に処理した値を外側で使う場合に許す。返したラムダに `Fail[E]` が残れば、そのラムダを呼ぶ位置の契約で処理する。toResultが返すTの内部の潜在エフェクトまで消さない。

### 脱糖、標準関数、VMとCLI

fromResultは引数を一度評価し、Okの中身を返し、ErrorのEをそのままraiseへ渡す通常のmatchとする。toResultは次の処理を通常のhandleで包む。bodyをハンドラの内側で一度呼び、成功をResult.Okへ包み、raiseの節はResult.Error(error)でhandle全体を終える。成功値をOkへ包む位置はbodyの呼び出しの後であり、ErrorがOkに二重に包まれないようにする。

コアの節は `ordinary` または `failure(errorTy)` の種類を持ち、操作の宣言は通常の所属名または標準Failの型パラメータ位置を持つ。Failの部分具体化ではEだけを節の外側で固定し、Tを内側の番号0へ残す共通の関数を使う。型のずらし・代入・範囲の検査もこの区別に従う。IRから低位IRへ進むとき、型と捕捉の整合を独立に検査してから型の情報を消す。raiseの実行引数はerror一つ、節はerrorと継続である。189の辞書を加える必要はない。

VMの探索は既存の操作番号による最も内側の節の選択を使い、型の比較や新命令を加えない案である。非再開時のdrop、内側から逆順のwithの解放、二度の解放の防止を維持する。解放失敗は実行時エラーとなり、元のEを正常なResultとして返すとは約束しない。既に行った操作や状態の変更は巻き戻さない。

mainと@testには未処理のFailを残せない。`typeck/effects/declarations.rs` とCLI入口の検査で、利用者エフェクトと同じ未処理の診断にする。`IO.All`、`--allow-effects` の許可名、check/testの `expanded` にFailを加えない。受理した入口ではFailは処理済みである。Schemeの追加の条件は入口へ来るまでに具体化され、未確定の条件も入口で拒否する。`inspection.rs` がFailを組み込みIOとして解釈する内部エラーに到達させない。公開のcheckReport・testCheckReport・effectLimitの形式番号は維持する案である。

die・Process.Exit・資源不足・中断・外部トラップ・実行時エラーをtoResultが自動で捕まえることはない。子タスクの親から継承した非再開の節の実行時エラーは維持し、子自身のtoResultからResultを返す例を示す。lazyの直接の本体にFailが残れば既存の純粋性の診断で拒否し、本体内でtoResultを呼んでResultを返す形は許す。

### 新しい診断番号の案

調査版の `diag/codes.rs` ではE0512まで使っている。以下を0.0.8の予約案とし、実装開始時に衝突を再確認する。型の種類や制約、未処理の効果など既存の原因には既存番号を使い、新番号を一括して出す処理にはしない。

| 番号 | 原因と主な情報 | 修正の案内 |
|---|---|---|
| E0513 | エフェクトの型引数が不正。名前、期待個数、指定位置 | 型引数を取るのは標準Failだけであることを示す |
| E0514 | 一つの効果へ異なるエラー型のFailが合流。二つの型と原因位置 | mapErrorか節で明示的に一つのエラー型へそろえる |
| E0515 | 残りの行のNoFail違反、またはシグネチャからNoFailを導けない。行・必要となったhandle・具体化の位置 | 引数の関数型のusesにFailを明示する、内側でResultへ戻す、捕捉の境界を移す |
| E0516 | Failの節でresumeを使用。resumeと節の位置 | handle全体の結果を返す |
| E0517 | 捕捉するエラー型を確定できない。境界の位置 | toResultの結果またはbodyの型注釈を示す |
| E0518 | Failの節と普通の操作の節を同じhandleに記述。両節の位置。主文案は `cannot mix failure and ordinary operation clauses in one handle` | `nest two handles instead` と案内し、二重のhandleの例を示す |

文言は英語でdiagの表に置き、`code`・位置・関連位置を既存のJSON診断形式で返す。189のE0510から除くのはtrait_constraintだけとする。診断表を変えた作業でSkillの診断一覧を再生成する。

### 型付きの失敗の受け入れ例

次は通常のモジュールの提案例である。成功時はOk(4)、失敗時は元のStringを保持したErrorとなる。Showの実装のないレコードでも同じ変換が型検査を通ることを別の例で確認する。

```text
import Benitoite.Unofficial.Failure

function twice(result: Result[Integer, String]) -> Integer uses Failure.Fail[String]
  return Failure.fromResult(result) * 2
end function

function attempt(result: Result[Integer, String]) -> Result[Integer, String]
  return Failure.toResult(body: lambda()
    return twice(result)
  end lambda)
end function
```

| 例 | 受け入れ条件 |
|---|---|
| List.mapの外側のtoResult | 一件のErrorで後続要素の評価を行わずリスト全体のError。File.Read等の残りの効果は消えない |
| 同じEの内外と節での再raise | 本体の失敗は内側、節自身の失敗は外側が捕捉する |
| Fail[A]の内側へRest=Fail[B]を渡す | 直接呼び出し・高階・別モジュール・部分適用でE0514かE0515。明示の合流は0514、NoFailの具体化違反は0515 |
| 内側でFail[B]を処理したResultを外側で利用 | 受理。外側のFail[A]と混同しない |
| Tが失敗するラムダ | 成功として返ったラムダの型にFailが残る。呼び出す位置で捕捉する |
| withの入れ子からraise | 続きを実行せず逆順に一度ずつ解放。解放失敗をResult.Errorへ変えない |
| 親と子、lazy、die | 子内の変換とlazy内の変換は受理。親の非再開節の継承、未処理Fail、dieはそれぞれ既存の制限を保つ |

## TODO-191: Characterの全域の網羅性

### 判定の手順

文字の値域を `Dchar = [0,0xD7FF] ∪ [0xE000,0x10FFFF]` とする。リテラルを一点の区間とし、各列の端点およびその隣と、Dcharの分割の端0・0xD800・0xE000・0x110000で分割する。char_partition_coverは有効なスカラー値だけを表すLeanのChar上で述べる。文字の列には有効な値域内の区間だけを列挙し、区間に対応した特殊化を再帰する。全値の列挙は行わない。覆われていない有効な区間は明示的な形として残し、文字では実在の値を選べない `.other` を置かない。補題Uへ文字と整数の列の場合分けを加える。整数・文字列の `.other` は現行維持である。L4aでは07-04「01-12 との対応」の脱糖の行の、Character全域のリテラルの並び・範囲を01-05より広いとする記述も更新する。

最上位の列だけで判定せず、レコード・構成子・リストの各列へ同じ分割を適用する。各区間で特殊化した残りの列を調べることで、欄どうしの相関を保つ。全域の一つの範囲をbind・shadowの左辺に書いた場合も同じ有用性の手順で必ず照合すると認める。束縛へコンマの選択肢の新構文を足さない。

ガードのある分岐を網羅性の前の行には数えない。同じ分岐内の左の選択肢は、ガードの有無によらず次の選択肢の有用性に数える現行規則を維持する。CoverageViewの将来の構成子、燃料切れとE0609の扱いも保つ。Integerは実装のi64全域を覆っても `_` か変数が必要である。LeanのInt全体の有界化を今回の変更に含めない。

反例は、有用性の再帰が返した未被覆の区間の最小の有効なスカラー値を使う。たとえば `match c: 'a' -> …` の文字の反例は `'\u{0}'` となる。この選び方を初版の表示規則とし、従来の `_` から変わるE0601のgoldenとSkillの診断例をP1で更新し、CHANGELOGにも明記する。複合パターンでも残りの列の証拠と組み合わせ、サロゲートを出さない。RustとLeanで、文字リテラルとUnicodeエスケープを使う同じ表示規則へそろえる。反例の表示の正しさを新たな全体の定理とはせず、独立入力と実際の照合で確認する。

### 診断・移行と受け入れ

網羅しない場合のE0601、束縛のE0607、選ばれない分岐のE0602、同じ分岐の選択肢のE0608を維持する。全域を覆った後の `_` はE0602となる。診断には覆った前の分岐の位置を付ける。範囲の種類・逆転・値域の診断は変えない。

P1では通常の.bnt、Rustの埋め込み文字列、文書の実行例、toolsの参照解・fuzzの入力を調べ、末尾の `_` が新たに拒否される候補を `p1/migration.md` に分類する。生成物は生成元を修正して作り直す。負の検査は意図を保ち、archiveとreference/は調査の対象へ混ぜない。本体の意図を確認して不要な分岐を削るか処理を移し、自動で全候補を削除する移行器は作らない。外部利用者にはCHANGELOGと移行案内で同じ処置を説明する。`ir/decision.rs` は `_` なしで文字の全域を覆う場合も扱い、最後の到達しない既定の分岐は処理系の内部エラーとする。既定の分岐を要する既存のテスト（調査版の2584行目付近）も、全域の場合と未被覆の場合を区別して更新する。

受け入れは、`'\u{0}'..'\u{10ffff}'` の単独全域、サロゲート前後の二範囲、リテラルとの和、一文字だけ欠けた例、入れ子の欄、二欄の相関、ガード、bind、全域後の `_` とコンマ内の重複である。整数の全域が従来どおり拒否され、拡張可能な型の将来の構成子を文字の全域だけで覆ったとしない例も含める。

## TODO-063・087: 外部の生成道具の共通部

### 入力と設定の書式

入口を `python3 -B tools/derive/derive.py preview|apply|check` とする案である。必須の `--config <path>` と `--root <directory>` を取り、previewは `--out <directory>`、applyは `--manifest <path> --manifest-sha256 <digest>`。checkはファイルを書かず、一致なら0、不一致や生成不能なら1、引数・設定の書式の誤りなら2とする。applyは拒否時に対象へ書かない。公開のbenitoite CLIには追加しない。

読み取り用のRust example `derive_inventory` が本番のparser・モジュール読み込み・名前解決した型の情報を使って型の構造をJSONへ書く。Pythonは型の構文を正規表現で読まない。通常の関数を実行して型を調べず、未生成関数の呼び出しのため全プログラムの型検査が失敗しても型の宣言だけを収集できる経路を使う。宣言の収集そのものが不正なら止める。通常の関数の本体の検査を成功した扱いにはしない。

これはexampleだけの追加ではなく、処理系の公開APIの追加である。新しい `src/pipeline/declarations.rs` を `pipeline::declarations` として公開し、次の入口を置く案とする。既存のcheck/compileの型とシグネチャは変えない。

```rust
pub fn collect_declarations(
    entry: &EntrySpec,
    fs: &(dyn ModuleFs + Sync),
) -> DeclarationResult;

pub struct DeclarationResult {
    pub sources: Arc<SourceTable>,
    pub diagnostics: Vec<Diagnostic>,
    pub inventory: Option<DeclarationInventory>,
}
```

`DeclarationInventory` は所有した宣言情報であり、型の解決名・可視性・宣言順の欄と解決した型・元のSpan・依存型・関数のシグネチャ・読み込んだファイルの識別と内容を持つ。型の木のタグと各出力欄は以下のJSON契約に従い、exampleがハッシュとJSONへ変換する。通常の型の表を利用し、別の型解決器を作らない。読み込み・字句/構文解析・importと宣言の名前解決・シグネチャの型と制約・宣言の重複と可視性までを検査し、いずれかの誤りならinventory=Noneと診断を返す。IOの失敗も既存の診断へ含める。本体の名前解決・型検査・定数の評価・実行は行わず、未生成関数の本体内の参照はこの入口の失敗にしない。構文解析自体は全ファイルに必要なので、本体の構文の誤りは拒否する。

既存の宣言収集を本体の検査から分離して共用し、型クラスのシグネチャ等を本体なしで解決できなければG1aで止める。`CheckedProgram` は返さず、通常のcheckの成功と取り違えない。入口は既存の段と同じスタック・panic境界を使う。これは生成道具に必要な公開境界であり、テストのためだけのAPIではない。

設定はJSON、未知のキーと重複キーを拒否する。exampleの入口は `derive_inventory --root <dir> --config <path>`、標準出力はversion 1のJSONとする。targetsの各行にモジュールの解決名、型名、元のバイト位置、公開/非公開、宣言順の欄（名前・解決した型の木・位置）、依存型とカスタム関数のシグネチャ、読み込んだ全ファイルのpath/sha256を出す。型の木はbuiltin・record・list・map・option・unsupportedのタグで区別し、unsupportedには元の型と位置を残す。Pythonが別の型解決を実装しない。

```json
{
  "version": 1,
  "targets": [{
    "source": "app/People.bnt",
    "type": "People.Person",
    "region": "person",
    "json": {"encode": "encodePerson", "decode": "decodePerson", "keys": {"displayName": "display_name"}},
    "property": {"generator": "genPerson", "shrinker": "shrinkPerson"},
    "fields": {}
  }]
}
```

sourceはrootからの相対パス、typeは解決済みのモジュール名と宣言名である。型の識別にローカルなBindingIdを使わない。対象は型パラメータのないレコードであり、依存先を宣言順に辿って非循環を確認する。List・String鍵のMap・区別を失わないOptionを再帰して扱う。別モジュールの公開型を参照する場合はそこにもtargetを指定し、そのモジュールの公開の生成関数を呼ぶ。非公開の欄を外から読まない。JSONの基本型はString・Boolean・Integer・有限Floatとし、087にも同じ基本集合を用意する。他の型は明示の関数を指定する。

fieldsのキーは欄名とする。欄ごとに `encode`・`decode`、または `gen`・`shrink` に完全修飾した関数名を指定できる。片方だけの対、存在しない欄、同じJSONキーへの改名、未知の設定は拒否する。encode/decodeは純粋な後述のResult型、gen/shrinkは後述のGen・Shrinkerを返すゼロ引数の関数とする。公開のシグネチャのハッシュを記録し、生成後の通常の型検査でも契約を照合する。手書きの本体の意味、往復性と生成分布は利用者の責任である。

### 管理領域とハッシュの照合

初版の出力先は型を宣言した.bntとし、関数だけを生成する。型の可視性に合わせて関数も公開し、非公開型の生成関数は非公開とする。新しい型クラスやimplementは生成しない。管理領域は `// benitoite-derive:begin person` と `// benitoite-derive:end person` の完全な行で囲む。previewは印がなければ原則として末尾へ新しい領域を足す案を出す。ただし新たなimportが必要な新規領域は、既存importの後・最初の宣言の前に置く。既存領域がすべて宣言の後にあり新規領域もないときは、importの追加を拒否して宣言前の手書きのimportと再previewを案内する（R95）。印の重複・入れ子・片方だけの状態は拒否する。領域外の手書きのimportへ差し込まず、必要なimportも領域内に生成し、既存の同じimportを解決済みの同一性で再利用する。関数名・importの別名の衝突は生成前に報告する。

永続の生成記録はconfigと同じディレクトリの `<configのstem>.generated.json` とする。version、generatorVersion、targetの識別、宣言順の欄の構造・依存型・カスタム関数のシグネチャ・正規化設定のSHA-256、領域本文のSHA-256を持つ。宣言の空白やコメントだけでは構造ハッシュを変えない。道具の版にはテンプレートの版を含め、生成規則を変えたら必ず上げる。

previewは永続の記録を上書きせず、全入力ファイルの生バイトのSHA-256、編集範囲、変更前後の本文、更新後の生成記録を含むmanifestとdiffをoutへ出す。applyは確認済みmanifestのハッシュ、全入力、既存領域が直前の生成記録の出力ハッシュと一致することを確認してから書く。初回に既存領域があるのに記録がなければ、既存の手書きとして拒否する。手書き編集を `--force` で消す入口は設けない。生成管理を外す場合は、利用者が本文を残し、begin/endの二行、設定の当該target、そのtargetの生成記録を手で除く。残るtargetのcheckと通常のcheck/testを行う手順をREADMEに書く。専用のdetachコマンドは設けない。

checkは現在の型・依存先・設定・道具から再生成して、生成記録と領域の両方を比べる。欄の追加後もencodeが型検査を通る場合を検出する。生成領域へformatterが加えた変更も不一致とし、生成時の出力を本番formatterで整えてからハッシュを取る。formatterの規則が変われば再生成して確認する。

編集のUTF-8バイト位置・パス・重なり・全入力検証・diff・再適用のreceiptには `tools/source-migrate/source_migrate.py` を再利用する。生成の意味と承認はderive側で判断する。検証後の外部更新の排除と複数ファイルへの書き込みの原子的な完了はこの共通部の保証にない。途中のIO失敗は非零とし、receiptと残った差分で復旧する。通常のbenitoite checkは生成記録を読まない。利用手順へderive checkを必須として明記する。

### 道具の診断と受け入れ

道具の診断は、標準エラーへ英語の説明とpath、元のUTF-8バイトの半開区間、target、必要なら欄名を表示する。専用のJSON診断とD番号は設けない。設定・引数の書式の誤りは終了2、未対応型・循環・衝突・入力変更・手書き変更・再生成不一致・整形/出力検査の失敗は終了1、一致または正常なpreview/applyは0とする。失敗の原因は文で区別し、コンパイラの診断があればその番号と位置を添える。

受け入れは、実在する型からpreview→確認済みapply→通常のcheck/test→derive checkを行い、二度目のpreviewが差分なしになることである。欄追加、依存型と設定の変更、手書き編集、CRLF・日本語の欄の前の位置、型名の衝突、初回・再適用、全入力の一つが変更済みの場合を対照にする。生成本文の固定文字列の一致だけで変換の契約を検査したことにしない。

## TODO-063: JSONとレコードの変換

### 公開する型と関数

補助モジュールは `Benitoite.Unofficial.Json.Codec` とし、Json本体と同じ非公式の名前空間に置く案である。`PathPart` は `Field(String)`・`Index(Integer)`・`Key(String)`、`ConversionError` は `path: List[PathPart], expected: String, found: String, reason: String` の公開レコードとする。既存方針に合わせ失敗のレコードには `@extensible` を付け、Showの通常の実装は経路と種類だけを表示する。入力の値全体を自動で埋め込まない。

型Personの関数は `encodePerson(value: Person) -> Result[Json.Value, Codec.ConversionError]` と `decodePerson(value: Json.Value) -> Result[Person, Codec.ConversionError]` とする。補助関数群は基本型用 `encodeString/decodeString` 等、`encodeList[T](value: List[T], encode: function(value:T) -> Result[Json.Value,ConversionError])` と対応するdecodeList、String鍵Map用、Option用とする。コンテナの返す型もResultであり、純粋である。型ごとの生成では明示したこれらの関数を渡し、必要なラムダの契約名を一致させる。

### 変換の順序と失敗

| 対象 | 符号化と復号 |
|---|---|
| 必須欄 | 欄名を既定のキーにする。欠落・null・種類の不一致はError。暗黙の既定値なし |
| Option[T] | NoneをNull、SomeをTの変換。欠落・NullをNone。それ以外をSome。TがNullを成功として扱いうる自動変換は生成前に拒否 |
| 入れ子のOption | NoneとSome(None)の区別が失われるため自動生成を拒否。カスタム変換を要求 |
| レコード | 宣言順に欄を検査して最初の失敗を返す。すべて成功した後に余分なキーを鍵順で調べ、最初のキーを拒否 |
| List・Map | Listの添字順、Mapの鍵順で処理し最初の失敗。経路へ添字または鍵を前置 |
| 数 | IntegerはValue.Integerだけ。FloatはValue.Floatかつ有限値だけ。Json.asFloatによる暗黙のInteger変換は使わない |
| カスタム変換 | 相対経路の失敗を受け、呼び出し側が欄を前置する。数の明示変換と独自のOption表現はこの入口で指定 |

非有限Floatのencodeを拒否し、stringifyがNullにする既存の振る舞いに依存しない。Floatのdecodeも非有限を拒否する。`Option` のカスタム変換を指定する場合、欄全体を置き換えられるようにし、欠落を区別する用途には `decodeMissing: function() -> Result[T,ConversionError]` を任意指定できる案とする。未指定の必須欄は欠落エラーである。任意のValueにNullを許す欄もカスタム指定にする。

往復の受け入れは、対応型の値で各カスタム関数も往復条件を満たすときの `decode(encode(x)) = Ok(x)` とする。任意のJSONを復号・再符号化した字面の一致、重複キーの検出、parse/stringifyを挟んだFloatとIntegerの表現の保存までは保証しない。ParseErrorとConversionErrorを分け、文字列からの入口はparseのResultを利用者が明示して組み合わせる。

受け入れでは非循環の二段レコード、Optionの欠落とNull、余分なキー、キーの改名、入れ子のList/Mapの位置、Integer/Floatの違い、NaNと無限大、非対応型と入れ子Optionの拒否を確認する。249との接続は `Failure.fromResult(decodePerson(...))` を境界で選ぶ例一つに限り、CodecにFailを要求しない。

## TODO-087: 純粋な生成・縮小・性質の試行

### ライブラリの契約

モジュールは `Benitoite.Unofficial.Test.Property` とする案である。GenとShrinkerは通常の公開レコードで、純粋な関数を欄に持つ。Random.Generatorを明示して次の状態を返す。以下の型と契約名を初版のAPIとする。

```text
Gen[T] { run: function(generator: Random.Generator, size: Integer) -> Pair[T, Random.Generator] }
Shrinker[T] { candidates: function(value: T) -> List[T] }
Config { seed: Integer, trials: Integer, size: Integer, maxShrinks: Integer }
```

公開の `check[T](config: Config, gen: Gen[T], shrinker: Shrinker[T], property: function(value:T) -> Result[Unit,String]) -> Result[Unit, CheckFailure[T]]` と `formatFailure[T](failure: CheckFailure[T], show: function(value:T) -> String) -> String` を用意する。ここでProperty.CheckFailureは通常のdataであり、importの別名Failureと区別できる名前にする。`InvalidConfig(String)` または `Counterexample` のレコードを含む形とし、後者はconfig・最初の失敗の1起算の試行番号・original:T・reduced:T・元と縮小後の説明・候補を試した総数・limitReached・libraryVersionを持つ。Counterexample[T]はconfig・trial・original・reduced・originalMessage・message・shrinks・limitReached・libraryVersionを欄名とする。CheckFailure[T]の構成子は `InvalidConfig(String)` と `Falsified(Counterexample[T])` の二つとする。

生成道具の版と設定ハッシュは生成記録から報告へ添える。識別用の関数は生成しない。手書き生成器ではその識別を利用者が添える。

Configは `1 <= trials <= 10000`、`0 <= size <= 10000`、`0 <= maxShrinks <= 100000` を要求する案とする。seedはInteger全域を許し、全試行で同じsizeを渡す。誤設定では生成器・性質を一度も呼ばずInvalidConfigを返す。Gen.runは利用者の関数を保持するレコードの欄なので、直接呼び出すsizeをライブラリが丸めることはない。Property.checkは不正なConfigを拒否し、有効なsizeをそのままrunへ渡す。直接のrunと手書きGenのsizeの解釈はその関数の契約に従う。上限は初版の実用上の予算であり、資源量や性質の停止性の保証ではない。

基本APIは `constant[T](value:T)`、`map[A,B](gen:Gen[A], f:function(value:A)->B)`、`both[A,B](left:Gen[A], right:Gen[B])`、`integer(low:Integer, high:Integer) -> Result[Gen[Integer],String]`（両端を含む）、`boolean()`、`float()`（有限値）、`string()`、`list[T](element:Gen[T])`、`option[T](element:Gen[T])`、`stringMap[T](value:Gen[T])` とする。対応する縮小を `shrinkInteger()` 等で返す。mapされた値の逆写像は推測せず、利用者がShrinkerを別に指定する。絞り込みを無限に再試行するfilterは初版に加えない。

integerはlow>highをResult.Errorにし、low=highは乱数を進めず固定値を返すGenを作る。low<highなら、最初に `Random.nextInteger(generator, 0, 8)` で枝番号bを一つ引き、返ったGeneratorを次へ渡す。b=0は0が範囲内なら0、範囲外ならlow、b=1はlow、b=2はhighを返す。b=3〜7は次の `nextInteger(0,2)` で0ならhighを返し、1ならさらに `nextInteger(low,high)` の半開区間から引く（各呼び出しは直前のGeneratorを使う）。三つの先頭の枝は各1/8、後半のhighと半開区間は各5/16となる。0=lowなどで値が重なる場合は枝の確率をそのまま足し、重複を除くために引き直さない。high+1やhigh-lowを計算しないのでi64全域も同じ手順を使う。分布の一様性は約束しない。booleanは0/1、floatは0・±1とnextFloat由来の[-1,1)を固定の分岐順で選ぶ。stringは有効なスカラー値から長さ0〜size（抽選する番号を0以上0x10F800未満とし、0xD800以上の番号に0x800を足してサロゲートを飛ばす）、listとmapも大きさ0〜sizeとする。mapの重複鍵は最初の値を残し、埋まるまで再抽選しない。OptionはNoneを1/4、Someを3/4とする。各分岐の抽選も返す次のGeneratorへ反映し、同じgeneratorを二欄へ使い回さない。

### 縮小とレコードからの生成

組み込みの縮小は、整数では0と0へ近づく二分の候補、Floatでは0と絶対値を半分にした有限値、Booleanではtrueからfalse、String/Listでは空・連続する部分の削除・各要素の縮小、Mapでは鍵順の削除と値の縮小、OptionではNoneと中身の縮小を順に候補にする。整数の最小値へabsや単項負号を直接使って溢れさせない。候補の順を固定し、同じ候補と元の値は組み込みの候補内で除く。Listの候補数は入力の長さと要素の候補数に従う有限数とし、sizeを資源の絶対上限と説明しない。

性質の最初のErrorを見つけたら、その入力の候補を順に試す。Okなら次、Errorならその候補を現在値にして候補列の先頭から探索する。総試行数がmaxShrinksに達したら止める。組み込みが同じ値を避けても手書きのShrinkerが循環する場合はあるため、候補を試すたび総数を増やす。equality制約や一般のTの同一性検査を必須にしない。上限に達したかを記録し、得たreducedが実際にErrorとなった説明を保持する。最大値0ならShrinkerを呼ばず元の失敗をそのまま返し、縮小を試さなかったことをlimitReachedへ記す。最小の反例とは呼ばない。

非循環レコードのgen関数は、欄の宣言順にGeneratorを受け渡し、各欄へ同じsizeを渡してレコードを構築する。sizeは一つのコンテナの大きさの上限であり、入れ子を含む全体の要素数の上限ではない。shrink関数は一度に一欄だけを変更した候補を宣言順に連結する。欄どうしの条件を保つ必要がある型には、型全体の手書きGen・Shrinkerを使う。型パラメータ、再帰data、Show/Orderの導出を自動対応へ含めない。

### @testとの接続と再現

既存の@testがProperty.checkの結果をmatchし、ErrorをformatFailureでStringへ変えて `Result.Error` で返す。Assert.failへ接続するなら最後に一度だけ呼ぶ。試行途中のAssert・IO・exitを捕捉して縮小しない。`test --check` は従来どおり型と効果だけを報告し、生成器も性質も実行しない。専用属性、seedのCLIオプション、testCheckReportの構造化した反例は追加しない。

同じseed・config・型の構造・生成設定・道具とライブラリの版・性質と手書きの関数なら同じ試行と縮小の順となる。G1aは宣言の読み取り、G1bは管理と照合を受け持つ。G1bの編集の契約は小さな固定出力で自己検査し、利用者向けの生成機能はG2のJSON、G4のPropertyで初めて有効にする。途中段を公開しない。報告には元と縮小後の具体的な入力を表示関数で添える。表示が情報を省く関数なら、その文字列からの完全な復元は保証できない。長期の再現には具体的な入力を通常の固定例へ保存する。Random.fromSeedの版をまたぐ乱数列の契約を、生成規則の版をまたぐ入力の保証へ拡大しない。

受け入れは、同じseedでの再現、size=0、整数両端、空の容器、一欄ずつの縮小、既に縮んだ値、循環する手書き縮小と上限0、誤設定時の非実行、失敗の説明と入力の保持である。生成したJSONのレコードの往復を一つの@testから試す例を段6の接続例にする。同じ契約をCLIと各内部関数へ重ねて複製しない。

## 段2の形式化: 定義・言明・止まる条件

### エフェクトに型を保持するLeanの表現

設計者はL0後に案Bを選んだ（R6）。Atomは現行のname/rhoのままとし、Tyと `inductive EffR | mk (atoms : Atom → Bool) (fails : List Ty)` を相互帰納的に定義する。名前と行の関数を保ち、Failの型の有限列を別欄に持つ。Coreは変更しない。型を含むAtomを現行の関数の引数側へそのまま足す案は、再帰する型の定義が成立しないため採らない。

L0の二案の比較と反例は [l0/results.md](l0/results.md) に当時の記録として残す。一般のFail列には順序の違いによる等号の反例があるため、設計者は型内部まで再帰した正規形を採ると決めた（R13）。案Aは名前と行まで列に変える移行を要する。商は代表の取り出しと商の上の再帰の正当化が増え、同値関係による型付けの変換はC_App・Ty.Le・LocTy・StoreTy・継続と健全性11件へ変更が広がる。このためBと正規形で、比較の成功からLeanの `=` を得る既存の接続を保つ。

正規形では、子の型と効果を先に正規化し、Fail列をTyの上の固定した全順序で整列して重複を除く。全順序の案は、Ty構成子の現行の宣言順、同じ構成子の欄の宣言順の辞書式比較である。自然数は数値順、文字列はUnicodeスカラー値列の辞書式順、BaseTy/TyConは宣言順、列は要素順とし、契約名も含める。EffRはatomsと正規化したFail列の順で比較する。名前と行の関数を有限支持へ狭めず、固定したAtomの自然数符号の最初の相違点で比較する数学上の順序を置く。checkerでは内部まで覆う有限支持S上で同じ順序を計算し、数学上の順序・正規化との一致を証明する。符号化と全構成子の定義・言明・仮定は [l0/statements.md](l0/statements.md) にまとめる。これらはRV2初回の指摘を反映した、未証明の下書きである。

正規化を入れる操作は、Fail生成・和・行の具体化・型代入・shift・型構成子への適用・シグネチャの具体化・脱糖・交換の読み込みである。宣言・項の注釈・環境・ストア・継続の型にも構築と更新で正規形を保つ。R14に従い、Ty.WF/WFList・VarsIn/VarsInList・新しいEff.WFとストアWFをFailの型内部まで広げ、型に埋め込んだ効果のCanonicalを要求する。Eff.RhosIn・NamesWF・ClosedNoEffVars・Supportも再帰を広げ、norm_WF・norm_VarsIn・norm_RhosIn・norm_supportと対応する保存を証明する。最上位の効果にはC_SubがあるためCanonicalを要求せず、必要な等式は整形式かEff.Subの両向きで示す。R21に従い、型付けの規則には結果の型のWFを加える。Ty.Leの包含の定義は保ち、正規化や等号への接続を信頼する仮定に加えない。型を保ったまま最上位の効果だけを広げるC_Effの具体化はR22に記す。

L1b1では表現切り替え前にatomsCompareの全順序・ラベル付きの木の辞書式順序・汎用sortUniqueの補題を独立モジュールに作り、sorryなしの既定ビルドが通る区切りとして報告する。L1b2ではTyから木への単射で順序を引き戻し、正規化の停止・意味保存・冪等性、shift_compare・shift_canonical・shift/代入と正規化の交換、正規化した一般の合成、norm_legacy・canonical_of_failsLeOne・sub_normを証明する。L1aのAPIにはEff.ext・ofAtoms・substAt c ts es・shift k cとTy.shiftからの呼び出しを含め、利用側に直接の関数適用やfunextを残さない。

非計算的な選択を行う定義はatomsCompareだけに限る。tyCompare・型列の比較・sortUnique・normは構造的な相互再帰とし、sortUniqueは0・1要素で比較しない挿入ソートとする。L1b2冒頭に数例のrfl/decideを確かめ、末尾で既存の約360箇所（レビュー時の概数）がカーネルで簡約できることを確認する。実行ファイルへ非計算的なReleaseの操作を残さない。Surface/Check.leanのmethNameのEff.substRho、SurfaceCheck/Batch.leanのnormalizeのsubstTyAt、Surface/Desugar.lean・Exchange/Convert.leanを計算できる写しへ替える箇所として名指しする。

L1b末ではR15の案(b)として、検査器が内部にFailを含むLegacyでない型・効果を一時的に拒否する。Legacyの保存とnorm_legacyから計算できる写しとReleaseの条件付き等式を示し、検査成功から条件を導いて健全性11件の言明を維持する。六実行ファイルと全体のビルドも完了条件にする。L1cでこの拒否を外し、normWithと支持条件付きの等式へ置き換える。これは段2の最終の保証には残さない。

L1cのeffEq_sound/tyEq_soundは、支持とFail列の位置ごとの比較成功だけから生の `=` を返し、Canonicalを前提にしない。checkerは読者から渡された注釈を正規化せず、計算した型だけnormWithで正規化し、checkProgram_soundは渡されたプログラムについての結論を保つ。読者の正規化とcanonical_of_failsLeOneは受理の対応と整形式に使う。Releaseの任意長のFail列の正規形は一般の整列・重複除去で扱い、表層の0/1制限だけを根拠にしない。

R14の整形式とストアWFの強化は、設計者が認めた既存定理の前提の意味の変更である。理由: Failを含まない旧型はnorm_legacyで自動的に満たし、旧来の適用範囲は狭まらない。07-04にはeffect_soundnessへNamesWFを加えた前例もあり、保証の範囲を弱める変更ではない。L1b2で01-12の写しと07-04の前提の一覧を同じ変更で更新する。この範囲内はR12の停止条件に当たらず、範囲外の前提の追加は従来どおり止める。

型・効果のshift/substはFail内の型も同時に辿る。節の束縛の内側では、型引数だけでなくes内部のFail型も束縛数に応じてずらしてから挿入し、再び整列・重複除去する。入力から集めるSはname/rhoを覆い、Failの列は別に再帰する。宣言・注釈・型引数・行引数とその内部の潜在効果を覆うことを収集処理から導き、代入後もその支持を保つ補題へつなぐ。具体化後のFailを入力のatomsに存在すると仮定せず、有限集合の外の原子を黙って落とさない。

NoFailの文脈Qはシグネチャから計算する。許容される置換（admissible substitution）を `Admissible(Qcallee, Qcaller, θ)` と書く。これは対象効果eの全ρがes.length未満という `Eff.RhosIn (· < es.length) e` を含む型・行の範囲と通常の制約に加え、QcalleeでNoFailの行の像がFailを含まず、その像の行もQcallerでNoFailであることを表す。型の内部の潜在エフェクトは外側のNoFailと区別する。`noFail_subst` はこの条件から示す。QをHasTypeC等の添字に加える案と定義の表から規則が引く案はL2aで比較して決め、判断の形とQsigからQcallerへ写す型・項代入補題をコード片にする。変更範囲を踏まえL2bの見積もりも見直す。単一Failは表層で具体化後に課す前提であり、Releaseにその代入保存を要求しない。

### 言明の案と処理系への対応

以下は定理の名前と内容の案であり、証明済みの宣言ではない。既存の性質1〜3とcheckerの健全性を置き換えて弱くすることはしない。

| 名前の案・既存名 | 言明の要点 | 対応するRustの処理 |
|---|---|---|
| `tyCompare_total`・`tyCompare_eq_iff` | 型の固定した全順序の法則とeqからの等号。任意のname/rho関数の領域を維持 | Fail列の整列と比較 |
| `Ty.norm_idem`・`Eff.norm_idem` | 型内部を含む正規化の冪等性と正規形の構築 | Failの生成・和・型構築 |
| `Ty.norm_substAt`・`Eff.norm_substAt`・`norm_shift`・`bind_comp` | 入力と置換像の正規化が、代入/shift後の正規化と交換する。一般の行の合成を正規形の等号で示す | 型代入・行の具体化・束縛下のesのずらし |
| `Ty.norm_legacy`・`Eff.norm_legacy` | 再帰的にFailがない旧型では正規化が恒等 | 旧仕様・旧交換入力の保持 |
| `compareWith_eq_compare`・`normWith_eq_norm`・`effEq_sound`・`tyEq_sound` | 有限支持上の計算との一致と、支持条件と位置ごとの比較成功から生のLeanの `=`（Canonicalは不要） | 独立検査と型付けの等号の接続 |
| `noFail_subst` | QのNoFailが成り立つ効果にAdmissibleな置換を施してもFailを含まない | solveの行の具体化と制約伝播 |
| `failure_clause_selected_typed` | 型の付いた閉じた状態の `raise[T,E′](v)` をSplitAtで分けたとき、選ばれた枠の境界型EとE′が等しく、v:Eである | handleの除去、IRの節検査、操作番号だけの探索 |
| `failure_clause_no_resume` | abortの節にはその節の継続のresumeの型付けがなく、値・型の置換後もその禁止を保つ | 節の継続を利用不能にし、IRでも再検査 |
| `fromResult_ok/error`・`toResult_return/raise` | 通常のコアのmatch/handleの有限遷移の例として、Okを返す場合とEを保持するErrorを返す場合を示す。解放がない単純な例に限定 | 標準ソースの変換。一度の評価は別途実行例で確認 |
| `op_dicts_typed`・`clause_dict_scope` | 宣言の辞書の順と節の局所束縛への写しが型を保つ。操作の行の具体化はes=[]（E0510） | 189の辞書・引数・継続の配置 |
| `char_partition_cover` | 有効な任意のCharは列挙した区間のどれかに属する。サロゲート区間を値としない | patterns::shapesのCharacterの場合 |
| `usefulFuelWithView_none_sound` と系 | 任意のview・燃料で有用でない答えなら意味の上でも覆う。網羅性・束縛・非選択、拡張後の網羅性の既存結論を維持 | Character変更、CoverageView、実行の照合 |
| `desugar_typed`・`surface_effect_soundness` | Q付きの表層の整形式と型付けを満たす全対象入力について、脱糖後の整形式・型・効果、空の主効果からのIO不在を維持 | 型付き表層の書き出し、脱糖とIR |
| `preservation`・`progress`・`effect_soundness` | Bと正規形・型付きの節へ直したReleaseで既存の性質2・3を維持。必要なNoFailとK_Handle_Failの入力条件を明示し、単一Failや未証明の捕捉安全を状態の不変条件・仮定にしない | VMの仕様の根拠。Rust実装そのものの証明ではない |
| `checkProgram_sound/empty` と健全性11件 | 全注釈、行の条件、節の型を検査した成功から改訂したSurfaceの型付けを導く | Rustの推論結果を独立に検査 |

`failure_clause_selected_typed` は、節のEが一致するという結論をそのまま前提にしない。K_Handle_FailとSplitAtのK1を通るFailの伝播、本体の効果上限、NoFailの代入保存から導く。abort節はTだけを束縛し、境界で固定したEと外側の型の番号を混ぜない。実行時の代入をTだけに分けるか、閉じた状態で余分な代入が無害であることを示すかはL2aで決める。解放を含む一般の型保存は既存のreleases/dropの保存の証明へ接続する。

### 段2で止まる点と代案

| 時点 | 処理系へ進めない条件 | 残す資料と代案の候補 |
|---|---|---|
| L0後の文書での定義・言明の確認 | RV2初回の指摘が未反映、Bと正規形の定義・言明・仮定に不足がある | l0/statements.mdの未証明の義務とL0の反例。表現の選択は済んでおり、同じ選択を再確認せず、下書きをレビューする |
| L1a〜dの表現と代入 | 既存の保証や旧入力を失う、層の区切りでsorryなしの全体ビルドが保てない、R14の範囲外の前提の追加が必要、見積もりの2倍を超えそう | 壊れる最小の型と層間の依存。表現の再選択か取り込み単位の再見積もり |
| L2a〜cの捕捉の保存 | K1のFailの伝播、境界型との一致、resume禁止、性質1〜3または健全性11件が通らない | 最小の型付きプログラム・選ばれる節・不足する前提。境界識別値、型を含む実行時の識別、公開のNoFail構文を代案として示す |
| L3a/b・L4a/bとRV2の閉鎖 | 辞書の所属、補題Uと系、全読者、旧出力との全比較、写しに穴がある | 辞書の所属または最小の行列と照合値、失敗した交換入力。定義の修正と再レビュー |

いずれも原因を規則の不足・書き写しの誤り・形式化の表現の都合に分けて設計者へ相談する。新しい公理、sorry、対象内の入力を対象外にする分類、保証の弱い定理への差し替えでは進めない。境界の識別値や型を含む動的な捕捉はF4-Aからの設計変更になりうるので、候補として示すだけで自動で採用しない。189だけを先にRustへ進める代案もC14に反する。60分超のLean作業とC13の目安を超える作業数は設計者が認めた（R12）。60分ごとに状態を報告し、見積もりの2倍超過の見通し・R14の範囲外の仮定の追加・層ごとの全体ビルド不成立では止めて相談する。

### 交換形式と六入口の移行

corpusを10から11、builtins・stdlib・coverage・coverage-programを3から4へ上げる。L4bでLeanの読者と正負の独立入力、Rust側の出力の契約を `l4b/exchange-contract.md` に確定する。Rustの版を切り替える作業はO2の一つに定め、五形式の版・check_named.py・版の一覧・manifestを同時に更新する。O2ではFailの列を空、failureTypeをnull、各行のnoFailをfalseとして書き、F3で実際のFailと行の条件を出力する。交換上の型の効果は原子の列とし、Leanの内部の表現とは分ける。読者は型内部までBの正規形へ変換し、Leanの書き出しも固定順序へそろえる。Rustの列順をLeanのAtom符号順へ合わせる必要はなく、両辺をLeanの読者で正規化して比較する。Rustには同じ符号を実装しない（L1d・L4b）。Failは `{"kind":"fail","error":<Ty>}`、操作は `dictParams` と `effectKind`、節は `dictCount` と `failureType`（通常はnull）、各行パラメータはBoolの `noFail` を持つ。関数・メソッドの宣言と実装・型引数・定数の注釈にも同じ型の表現を用い、既存のview・契約名・所属を落とさない。

Leanが受け付け続ける版は、corpusが8・9・10（新規は11）、builtins・stdlib・coverage・coverage-programが各2・3（新規は4）である。現行にない旧版を追加で受理しない。旧版の独立入力は新しい情報が存在しない場合だけ、辞書0・通常節・Failなし・NoFailなしで読み替える。旧版へ新しい欄を混ぜた場合は拒否し、corpus8/9のtryの制限等も維持する。新版の欄を旧版へ混ぜた入力、Failの型引数の不正個数、範囲外の辞書と型番号、未知のnoFail参照を拒否する。古いcorpusを無条件にFailなしへ変換しない。表層の具体化後の単一Failの検査と、Releaseの上限で複数Failを許すことを区別し、後者を交換の読み取り時に一律に拒否しない。

六入口はdesugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAllである。L4bではそのすべてのLean側と独立入力を先にビルド・実行する。L1dで旧版の読み込みを確認し、L4bの末に今のRustの10/3の出力でcheck-formal.sh全体を一度実行して段2の回帰を閉じる。Rustの書き出しはO2で辞書、F3でFailと行、P1で文字の判定を接続する。新機能の全比較はP1末とV1の最終関係状態で行う。段2末の成功をRustの新機能の成功として引用しない。

R66の取りまとめの判断により、L4bの通常とview付きの網羅性の不一致だけは、全不一致の照合対象の型にcharacterが含まれることを機械的に確認し、件数と道具・結果を保存した場合に限りP1までの既知差として受け入れる。他の比較は全件一致を要求し、P1の全比較では文字を含め不一致0件を要求する。

標準モジュールの追加はG2〜G4でも信頼する宣言とcorpusへ影響する。L4bは将来の通常の関数とレコードを読む既存の一般の読者を用意し、後段でLeanへ個別のライブラリ名の特例や未実装の証明を追加しない。後段で形式化した規則の欠陥を見つけた場合は段2へ戻り、Leanと写しを直してから続ける。

## 実装時に更新する現行文書と生成物

| 対象 | 内容・更新する作業 |
|---|---|
| 01-12・02-05・07-04・formal/README | L1a〜L4bで定義・写し・対応表を同時更新。段2の間の処理系との未接続を明示。通常の利用者向けの規範の追加を先取りしない |
| 01-02・01-06・01-07・01-09 | O1/O2で操作の制約と全呼び出し、F1/F2で型付き参照と捕捉、P1で範囲。実装した範囲ごとに反映 |
| 01-05・02-05・02-06・02-08・02-09 | 各作業の判定・辞書・IR・VM・解放の実装へ対応。性質と実装の検証の範囲を区別 |
| 03-06・03-08・06-04・06-06 | F2とG1a/G1b〜G4で標準モジュール・Codec・Property・生成と利用手順。新章が必要なら目次と全参照を同時更新 |
| 02-10・diag/codes.rs・Skill | F1/F2で新番号と文言。構文・診断表・標準ソースを変える各作業でgen_skillを実行し、生成物を手で修正しない |
| tools/derive/README・docs/reference/benitoite.md・Skillの手書き参照 | 各機能作業で公開の型と例、生成のcheckの必須化、保証の限界を説明 |
| docs/ja・CHANGELOG・版の定数・通常入力・固定ハッシュ | V1で一度更新。旧版などの負の入力、archive、reference/は目的・規約に従う |

実装のソースの主な対応は study/ の調査表にある。設計書の見出しを改名する場合は参照するコメント・spec印・生成器を同時に探して直す。今回この表の現行文書やコードは変更しない。
