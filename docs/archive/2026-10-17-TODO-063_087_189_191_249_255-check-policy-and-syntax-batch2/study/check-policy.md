# TODO-255 検査の方針の調査

## 調査の範囲と読み方

2026-10-17、`mod255/design`、HEAD `0027a22c` を基準に調べた。0.0.8 は TODO-063・087・189・191・249・255 を一つの改造として扱い、検査の方針を先に決める。本書は調査の記録であり、現行の規約を変更するものではない。判断の選択肢は [設計者への問い](check-policy-questions.md)、TODO-255 の原文は [項目の写し](../todo-items.md) に置く。

調査対象は現行の AGENTS.md、検査のスクリプト、07-03・07-04、関係するスキル、2026-10-11 以降の17改造の計画・結果・レビューである。後半に資料の一覧を示す。`work/m254/check-*.txt`、`at?-G*.txt`、`*-report.md` と補足の記録も読んだ。work/ は追跡外なのでリンクせず、後で消えても判断を読めるよう必要な結果を本書へ写す。過去の記録は実績を調べる資料とし、現在の仕様の根拠にはしない。完了記録に残る「未公開」は採取当時の状態であり、現在の0.0.7の公開状態を示すものではない。

記録の「最後」は、改造の締めの共通検査と、公開直前の検査の両方を指すことがある。以下では実際に実行した位置を記す。「記録なし」は未実施の断定ではない。計画にコマンドがあるだけのものを実行済みに数えず、実装と検査を合わせた作業時間を検査時間として扱わない。

## 現行の検査の選び方

### 規約と依頼文の重なり

[AGENTS.md](../../../../AGENTS.md)「テストの運用」と [07-03](../../../design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査) は、取り込み前に変更に応じた check.sh を通し、公開前には --full を通すよう定めている。検査前の知らせ、dry-run の確認、長い検査の時間の予告も必要である。分類外のファイルや存在しない基準で終了状態3となった場合は、設計者が full/only/none を選ぶ。

一方、最近の実装プランは、これに各作業の lib 全件・関連統合テスト・Clippy（Rust の静的検査、lint）・fmt と、段末の check.sh・両構成の all-targets を加えた。TODO-254 の計画 K6 は「段末は各作業の選択の検査の代わりではない」とも書く。実際の共通の依頼文では check.sh をオーケストレータへ委ねたため、作業の記録には計画との差として未実施が繰り返し記された。検査を誰がいつ行うかの正が複数箇所にあることが、重複と未達の説明を増やしている。

関係するスキルの現状は次のとおりである。今回は内容を調べたもので、コミット・テストの改変・片付けは行わない。

| スキル | 現在の規定と今回の論点 |
|---|---|
| [git-workflow](../../../../.claude/skills/git-workflow/SKILL.md) | コミットメッセージの書式だけを定める。検査を追加する規定はない。TODO-255 のための本文改訂は不要である |
| [test-audit](../../../../.claude/skills/test-audit/SKILL.md) | 作成時の四問、主なテストを置く境界、退行の再現、監査後に関係するテストと07-03の検査を通す規定がある。テストの価値と実行の時期は別の判断であり、実行回数を減らすだけでテストを削除しない |
| [clean-build](../../../../.claude/skills/clean-build/SKILL.md) | target/ を消すと再ビルドが数分増える。Lean を触る途中は .lake/ を消さない。検査中の片付けを止める。検査結果の保存先を生成物の下だけに置くと、片付け後に引用できなくなる |

### check.sh の単位と構成

[scripts/check.sh](../../../../scripts/check.sh) の `classify`・`select_check` と実行部を照合した。二つの構成とは、既定の `gc-mark-sweep` と、検証器を加えた `gc-mark-sweep,heap-verify` である。gc-stress は安全点ごとに回収を強制する追加の構成であり、heap-verify と目的が違う。

| 指定・変更 | 実際の選択と注意点 |
|---|---|
| 指定なし、`--base <rev>` | 基準の版から作業ツリーまでの差と未追跡ファイルを分類する。基準の既定は origin/san_benito。直前の作業だけでなく、改造全体の差を拾う場合がある |
| `--dry-run` | 選択と最初に当たったファイルを表示する。検査は実行しない。分類不能でも dry-run 自体は0で終えるので、終了状態だけでは停止の有無を判断できない |
| `--only <name,...>` | 差分の分類を使わず名指しする。名前は rust/default_lib/long/release_stack/licenses/heap/spec_examples/reference_examples/skill/spec_coverage/skill_eval/python/formal。long は rust も選ぶ。heap だけなら rust は選ばない |
| `--full` | rust・default_lib・long・release_stack・licenses・仕様/リファレンス/Skill・仕様集計・道具の自己検査を選ぶ。heap と formal は選ばず、両構成の test all-targets も独立には実行しない |
| `--none` | 検査をせず終了する。現行の規約では設計者が不要と判断した場合に使う |
| Rust/Cargo の変更 | crates/ と fuzz/ は rust。Cargo の宣言と lock は licenses も選ぶ。rust は関係するモジュールの絞り込みを持たない |
| runtime/vm/refinterp の変更 | rust に加えて long。heap/ の変更はさらに default_lib と heap を選ぶ |
| 仕様・例・生成元 | 01-spec と付録08-04は spec_examples と spec_coverage。構文の章は skill も選ぶ。英語リファレンスは reference_examples。Rust の変更からも Skill 再生成と仕様集計へ進む |
| formal/ の変更 | formal は sorry を拒む `lake build` だけ。check-formal.sh 全体は別に実行する。formal/reviews/ は対象外 |
| Python・一般文書・スクリプト | tools/ は固定の Python 検査群。一般の docs/・Markdown・スキル等は実行なし。check-formal.sh 以外の検査スクリプト等は分類不能として設計者に尋ねる |

オプションは同時指定を全て拒む実装ではない。例えば --none は先に終了し、--only と --full を併用すると選択が足し合わされる。水準の指定を足す際は、この優先順位を暗黙に継承せず、競合の扱いを決める必要がある。

| 検査名 | 実際に走る主なもの |
|---|---|
| rust | fmt、heap-verify+alloc-stats の workspace all-targets Clippy、既定の lib/tests Clippy、heap-verify の workspace test、heap-verify+gc-stress の workspace lib/tests、仮置きの許可・unsafe_code の場所、Skill 再生成、仕様集計 |
| default_lib | 既定の lib のテスト。long を選んでも、このコマンドには --include-ignored を渡さない |
| long | rust の通常実行とgc-stressの両方に --include-ignored を渡す。長いテストだけを追加実行する形ではなく、通常テストも再実行する |
| release_stack | release の lib から測定済みスタックの10テストを選び、ignore を含めて走らせる |
| heap | [check-heap.sh](../../../../scripts/check-heap.sh)。通常の確保と対象ごとの確保の Miri、ヒープの到達可能性の比較20,000列。Miri は未定義動作を検出する Rust の実行器である |
| formal | sorry の警告がない lake build。六入口の比較とは別である |
| 独立の check-formal.sh | [スクリプト全体](../../../../scripts/check-formal.sh) は Lean の既定ビルド、六つの実行器、Rust の書き出し、独立した交換入力、脱糖・型表・網羅性・表層検査・manifest の照合を行う |
| python/skill_eval/licenses | Python の構文、source-migrate/try-actions-migrate の自己検査等、skill-eval の自己検査、依存の許諾の検査。LLM を呼ぶ評価は含まない。named-arguments-migrate の自己検査は python に含まれない |

`long` は印の文字列を選び分けず、全ての ignore を含める。このため `formal: ...` の書き出しも走るが、Lean との比較は行わない。同じ書き出しを check-formal.sh でも繰り返す一方、long が成功しただけでは形式化との一致は確認できない。

test all-targets と、現在の rust の workspace test も重なる。全ターゲットは例やベンチのテストを追加するが、既定の cargo test も例のコンパイルを行う。また、all-targets に文書コメントのテスト（doctest）は含まれない。置き換えるなら --doc を別に残す必要がある（[Cargo の一次資料](https://doc.rust-lang.org/cargo/commands/cargo-test.html)、2026-10-17確認）。TODO-247 の移行漏れは runtime_builtins の統合テストで見つかっており、all-targets にだけ含まれるテストが見つけた例ではない。

### 時間の実績

古い07-03の約28分やヘルプの「long は約15分追加」「release_stack は約5分追加」は、現在の総時間の実測とは区別する。次表の「実行計」はログの各テスト実行器が示す時間の和であり、コンパイルとコマンド間の時間を含まない。外側の経過時間は完了記録に明記された値だけを使う。

| 検査 | 記録から確認した時間 | 出典・限界 |
|---|---|---|
| 0.0.7 作業の既定 lib | 通常は約77〜101秒。M2bの並行時は124.17秒 | 各 results。V1a の二度目は79.33秒、ビルド処理0.12秒 |
| 0.0.7 関連統合テスト | 2〜80秒程度の実行計。全体では再ビルド等が加わる | 各作業の表。Z4 は lib/統合/lint/fmt の外側が計141.409秒 |
| 二構成の lint | 段末の Cargo 表示の和で約8〜49秒 | work の G1〜G6/Z6。作業V1aの詳細 lint は59.73秒 |
| heap-verify 全件、longなし | 実行計465.47〜504.70秒 | 段末7回、約7.8〜8.4分 |
| gc-stress 全件、longなし | 実行計1414.25〜1550.12秒 | 同上、約23.6〜25.8分。7回合計約171分 |
| 既定 default_lib | 実行計77.24〜92.32秒、段末のビルド約5〜30秒 | 07-03の2026-10-12実測はビルド14秒+実行38秒。版と時点が違う |
| 両構成の all-targets | G2:440.23+575.64秒、G4:429.49+552.02秒。公開前:478.13+569.47秒 | 実行計約16〜18分。公開前の外側は87−68=19分 |
| --full 内の二つの全件実行 | 通常側1534.40秒、gc-stress側2161.98秒 | longとformal書き出しを含む。通常側約25.6分、強制側約36.0分 |
| release_stack | 実行21.49秒、ビルド1分44秒 | 0.0.7の公開前ログ。約5分追加というヘルプの見込みと別である |
| --full 全体 | 0.0.5:61分、0.0.6:65分、0.0.7:68分 | 各改造の完了記録。0.0.7はall-targets込み87分 |
| check-heap.sh | 約10分という規約上の予算。今回の資料に直近の単独の外側時間なし | 実測値として新しく測ったものではない |
| check-formal.sh | 古い記録536秒、WIT改造Z6約10分、0.0.6段末14分 | 六入口の全体。lake build単独と混同しない |
| 関係するgc-stressだけ | X1:12.9+11.7秒、X2:17.6+4.4秒、X3:13.3+11.2秒、X4:12.6+5.1秒、X5:8.4秒 | 2026-10-12 TODO-182_183_184の measurements。ビルド込み。全件強制を段ごとに回す必要性とは別の材料である |

## 改造の進め方の実績

### 17改造の比較

表の A01〜A17 は末尾の資料一覧に対応する。R は関連テスト+Clippy+fmt、S は関連テストをgc-stressでも実行、K はlib全件+関連統合テスト+Clippy+fmtを表す。作業のコマンドは計画と結果・レビューを照合した範囲であり、過去の全コマンドの生ログは残っていない。「段の一括実行の記録なし」は、作業レビューを行わなかった意味ではない。

| 改造 | (a) 作業ごとの実績 | (b) 段の検査 | (c) 最後の実行と時間 |
|---|---|---|---|
| A01 小修正・堅牢化（10/11、165ほか） | J/W/C1/C2。個別のJSON・CLI等と、取り込み前check。Jは交換出力を変更しcheck-formalも成功 | 作業ごとにcheck。独立した段末の記録なし | --only rust,licenses,spec_examples,reference_examples,spec_coverage,skill_eval,python。成功、単独時間の記録なし |
| A02 実行時・検査の堅牢化（042ほか） | H1/T/P/B/N/R/H2/H3。関連テスト。取り込み前check、P/Bはcheck-formal、R/Tは短い測定 | 作業ごとのcheckを取り込み担当が実行。H1で誤りの順序の退行を検出 | --base 375304c の選択（long/heap含む）+check-formal成功。単独時間の記録なし |
| A03 型検査・脱糖（178/190） | T1〜T8。型・パターン等、各check、関係作業はformal | 独立した段末の記録なし | --base v0.0.2（long含む）+check-formal成功。計画のformal見込みは約9分、最後の総時間なし |
| A04 後片付け・スタック（174ほか） | S/R/C1/C2a/C2b。R。C1では複数構成のlint、コメント作業はbuild all-targets | 独立した段末なし。重い検査を最後へ一度に集約する試行 | --only rust,long,release_stack,heap,python成功、45分 |
| A05 Regex・HTTP（185/201/202） | X1〜X4。R。X2はinterrupt_process/test_command/runtime::run。通常構成のみ | 独立した段末なし | 選択rust,long,heap,reference_examples。初回38分でgc-stress失敗、修正後48分で成功。後の性能測定でも退行を検出 |
| A06 テスト信頼性・IO（182ほか） | X1〜X5。R+S。Sの時間は上表の秒単位 | 独立した段末なし | --base 1ca0f7b、rust/long/例/仕様集計成功、43分43秒 |
| A07 テストの穴・ライブラリ（177ほか） | Y1〜Y11/Y2fix/Z1〜Z4。R+S。参照比較の長い試行はY4だけ | 独立した段末なし | --base eb8dac11、rust/long/例/仕様集計成功、44分17秒 |
| A08 実行時・HTTP（173ほか） | V1〜V6/Z1〜Z4。R+S。V1で既定のヒープのテストを確認 | 独立した段末なし | check.sh自身の変更で停止。設計者が検査なしを選び、最後の一括実行は未実施 |
| A09 診断・テスト（170ほか） | W1〜W6/Z1〜Z4。golden/skill_docs/help_tests、二構成lint/fmt | 独立した段末なし | --base 44e38cbf、rust/long成功、約45分 |
| A10 guard・runner・診断（193ほか） | W1/W2/W3/W5/Z1〜Z4。golden/skill_docs/help_tests、二構成lint/fmt | 独立した段末なし | --base af4e79cc、rust/long/例/仕様集計等成功、約44分 |
| A11 パッケージ・WASM第1段 | W1〜W7/Z1〜Z7。R、二構成lint。Z3レビューの実行で広域テストの失敗を再現 | レビュー単位は作業ごと。定例の全件段末の記録なし | --only rust,long,licenses,spec_examples,reference_examples,skill,spec_coverage,python,formal成功、約52分 |
| A12 パッケージ・WASM第2段 | V1〜V7/枝/Z1〜Z7。R、関係するS、二構成lint。V7の作業報告でspec印の誤りを検出 | 定例の全件段末の記録なし | --base e3de3f82、rust/long/licenses/例/Skill/集計/python成功、約54分 |
| A13 型付きリスト転送（240） | T1/T2、T3の軽微修正。externalの通常/強制、lint/fmt | 独立した段末なし | --base ed825030~1、rust/long/reference/python成功、約52分 |
| A14 幅付き数・WIT（020/241） | P1〜P40a/枝/Z1〜Z6。関連テストと二構成lint/fmt、Lean先行。計画は各Pでcheckの一式を実行しない分担 | G1〜G8レビュー。段ごとのcheck一括の実績は確認できない | 選択rust/default_lib/long/licenses/heap/例/Skill/集計/python/formal。golden・集計・lakeで停止と修正を経て全て成功。全体の検査時間の記録なし。Z6 formalは約10分 |
| A15 名前付き引数（247、0.0.5） | L/N/Zの各作業Kと関連テスト、形式化。計画Kのcheckと実作業の委任を区別する | G8a時点でrust等を前倒しし移行漏れを検出。all-targetsの負荷による失敗後、単独再実行成功 | --fullは一度で成功、61分。前倒し分と同じ検査を再度含む |
| A16 try処置・拡張型（018ほか、0.0.6） | 48実装作業と枝、K/関連テスト、形式化の接続。B10aで乱択の時間超過を検出し、レビューで原因を特定 | 段2check34分、段3check36分+formal14分、M5check35分、M9前倒しlicenses/formal+formal14分。all-targetsは各作業に記録 | Z10後--full成功、65分。全件を最後に初めて失敗させた記録なし |
| A17 ハーネス向けCLI（254、0.0.7） | 35作業+Z1〜Z7でK。文書作業でもlib等を実行。A4/M2bで両構成all-targets（C3分は段末へ委任） | G1〜G6+Z6後の7回、各36〜57分。G7は完了扱いの段末を省いた | Z7後--full68分+両構成all-targets、合計87分。全て成功 |

作業時間が8〜15分、あるいは30〜60分という記録は、実装・確認・報告を含む。検査の待ち時間だけの比較には使えない。A01〜A03の作業ごとcheckから、A04〜A14の最後に一回という試行を経て、A15〜A17では広い検査を段末にも追加した。この追加は主に移行漏れへの対策であり、重複を増やす前に、漏れた入力と検査の持ち主を直す選択もあった。

### 0.0.7 の作業ごとの実行

次表は保存された各 results と work の報告を照合したものである。全42作業で既定lib・Clippy・fmtを実行した。K-Rを要する本体変更に加え、P1/P2/M2a/M3a/F2等の文書作業でも同じ実行がある。計画の「文書だけならRust検査を重ねない」と、実際の共通依頼の差である。gc-stressとcheck.shは作業担当が実行せず段末へ委ねた。

| 作業（結果へのリンク） | libまたはlibを含む一括テストの実行時間 | 関連統合テスト等（Clippy・fmtは全行で別に実施） |
|---|---:|---|
| [P1](../../2026-10-17-TODO-254-harness-check-interface/p1/results.md) | 82.51秒 | `cli_process`、`test_command`、`skill_docs`、`package_command`、`runtime_builtins` |
| [P2](../../2026-10-17-TODO-254-harness-check-interface/p2/results.md) | 80.92秒 | `cli_process`、`test_command`、`interrupt_process`、`skill_docs` |
| [V1a](../../2026-10-17-TODO-254-harness-check-interface/v1a/results.md) | 80.29/79.33秒 | `build_info` |
| [V1b](../../2026-10-17-TODO-254-harness-check-interface/v1b/results.md) | 80.46秒 | `build_info` |
| [V2](../../2026-10-17-TODO-254-harness-check-interface/v2/results.md) | 79.22秒 | `cli_process`、`test_command`、`build_info` |
| [Z1](../../2026-10-17-TODO-254-harness-check-interface/z1/results.md) | 83.55秒 | `build_info`、`cli_process` |
| [C1a](../../2026-10-17-TODO-254-harness-check-interface/c1a/results.md) | 80.07秒 | `cli_process`、`interrupt_process` |
| [C1b](../../2026-10-17-TODO-254-harness-check-interface/c1b/results.md) | 79.95秒 | `cli_process`、`interrupt_process` |
| [C2a](../../2026-10-17-TODO-254-harness-check-interface/c2a/results.md) | 87.39秒 | `cli_process`、`test_command`、`fmt_command`、`package_command` |
| [C2b](../../2026-10-17-TODO-254-harness-check-interface/c2b/results.md) | 79.65秒 | `cli_process`、`interrupt_process` |
| [C3](../../2026-10-17-TODO-254-harness-check-interface/c3/results.md) | 77.48秒 | `cli_process`、`package_command`、`golden` |
| [Z2](../../2026-10-17-TODO-254-harness-check-interface/z2/results.md) | 100.86秒 | `cli_process`、`test_command`、`golden` |
| [T1a](../../2026-10-17-TODO-254-harness-check-interface/t1a/results.md) | 80.68秒 | `test_command` |
| [T1b](../../2026-10-17-TODO-254-harness-check-interface/t1b/results.md) | 80.64秒 | `test_command`、`interrupt_process` |
| [T1c](../../2026-10-17-TODO-254-harness-check-interface/t1c/results.md) | 78.10秒 | `test_command`、`fmt_command`、`cli_process`、`interrupt_process` |
| [T2a](../../2026-10-17-TODO-254-harness-check-interface/t2a/results.md) | 76.68秒 | `test_command`、`fmt_command` |
| [T2b](../../2026-10-17-TODO-254-harness-check-interface/t2b/results.md) | 77.44/86.10秒 | `test_command`、`cli_process`、`fmt_command` |
| [T3](../../2026-10-17-TODO-254-harness-check-interface/t3/results.md) | 90.23秒 | `test_command`、`fmt_command`、`cli_process` |
| [Z3](../../2026-10-17-TODO-254-harness-check-interface/z3/results.md) | 88.39秒 | `test_command`、`cli_process`、`fmt_command` |
| [A1](../../2026-10-17-TODO-254-harness-check-interface/a1/results.md) | 82.76秒 | `cli_process`、`skill_docs`、`test_command` |
| [A2a](../../2026-10-17-TODO-254-harness-check-interface/a2a/results.md) | 76.99秒 | `test_command`、`cli_process`、`interrupt_process` |
| [A2b](../../2026-10-17-TODO-254-harness-check-interface/a2b/results.md) | 80.81/97.35秒 | `test_command`、`cli_process`、`interrupt_process` |
| [A3](../../2026-10-17-TODO-254-harness-check-interface/a3/results.md) | 83.04秒 | `test_command`、`interrupt_process`、`cli_process` |
| [A4](../../2026-10-17-TODO-254-harness-check-interface/a4/results.md) | 78.39秒 | `cli_process`、`test_command`、`golden` |
| [Z4](../../2026-10-17-TODO-254-harness-check-interface/z4/results.md) | 81.63秒 | `cli_process`、`test_command`、`fmt_command`、`interrupt_process`、`skill_docs` |
| [E1](../../2026-10-17-TODO-254-harness-check-interface/e1/results.md) | 85.81秒 | `l13_external_commands`、`l10_console_clock_process`、`runtime_builtins`、`skill_docs`、`cli_process` |
| [S1](../../2026-10-17-TODO-254-harness-check-interface/s1/results.md) | 89.48秒 | `cli_process`、`skill_docs`、`skill_examples` |
| [S2](../../2026-10-17-TODO-254-harness-check-interface/s2/results.md) | 81.80秒 | `cli_process`、`skill_docs`、`skill_examples`、`test_command` |
| [Z5](../../2026-10-17-TODO-254-harness-check-interface/z5/results.md) | 78.49秒 | `cli_process`、`l10_console_clock_process`、`l13_external_commands`、`runtime_builtins`、`skill_docs`、`skill_examples`、`test_command`、`interrupt_process` |
| [D1](../../2026-10-17-TODO-254-harness-check-interface/d1/results.md) | 89.44秒 | `spec_examples`、`reference_examples`、`skill_docs`、`cli_process`、`test_command` |
| [D2a](../../2026-10-17-TODO-254-harness-check-interface/d2a/results.md) | 77.63秒 | `reference_examples`、`spec_examples`、`cli_process`、`test_command`、`skill_docs` |
| [D2b](../../2026-10-17-TODO-254-harness-check-interface/d2b/results.md) | 82.79秒 | `reference_examples`、`skill_docs`、`skill_examples`、`spec_examples`、`cli_process` |
| [D3](../../2026-10-17-TODO-254-harness-check-interface/d3/results.md) | 87.05秒 | `cli_process`、`test_command`、`l13_external_commands`、`spec_examples`、`reference_examples`、`skill_docs`、`skill_examples` |
| [Z6](../../2026-10-17-TODO-254-harness-check-interface/z6/results.md) | 80.25秒 | `cli_process`、`test_command`、`l13_external_commands`、`spec_examples`、`reference_examples`、`skill_docs`、`skill_examples` |
| [M1](../../2026-10-17-TODO-254-harness-check-interface/m1/results.md) | 90.37秒 | `package_command`、`golden`、`cli_process`、`skill_docs` |
| [M2a](../../2026-10-17-TODO-254-harness-check-interface/m2a/results.md) | 79.07秒 | `package_command`、`golden`、`cli_process`、`test_command`、`runtime_builtins`、`reference_examples`、`skill_docs`、`skill_examples`、`spec_examples` |
| [M2b](../../2026-10-17-TODO-254-harness-check-interface/m2b/results.md) | 124.17秒 | `package_command`、`golden`、`cli_process`、`test_command`、`runtime_builtins`、`reference_examples`、`skill_docs`、`skill_examples`、`spec_examples` |
| [M3a](../../2026-10-17-TODO-254-harness-check-interface/m3a/results.md) | 80.94秒 | `reference_examples`、`spec_examples`、`cli_process`、`test_command`、`skill_docs` |
| [M3b](../../2026-10-17-TODO-254-harness-check-interface/m3b/results.md) | 84.35秒 | `reference_examples`、`skill_docs`、`skill_examples`、`spec_examples` |
| [F1](../../2026-10-17-TODO-254-harness-check-interface/f1/results.md) | 80.80秒 | `cli_process`、`test_command`、`interrupt_process`、`fmt_command`、`package_command`、`golden`、`runtime_builtins`、`l10_console_clock_process`、`l13_external_commands`、`reference_examples`、`spec_examples`、`skill_docs`、`skill_examples` |
| [Z7](../../2026-10-17-TODO-254-harness-check-interface/z7/results.md) | 79.61秒 | `golden`、`package_command`、`skill_docs`、`reference_examples`、`spec_examples`、`cli_process`、`test_command`、`skill_examples` |
| [F2](../../2026-10-17-TODO-254-harness-check-interface/f2/results.md) | 80.57秒 | `cli_process`、`test_command`、`package_command`、`golden`、`reference_examples`、`spec_examples`、`skill_docs`、`skill_examples` |

両構成の all-targets は、A4・M2bで作業担当が実行し、G2・G4でも取りまとめ担当が実行した。C3自身は段末へ委任しており、実行済みに数えない。A4の実行計は430.47+556.28秒、G4は429.49+552.02秒と別の出力である。workのA4ログでも両コマンドの完了が確認でき、外側の時間は512.001+660.939秒であった。A4とG4の全ターゲットは重複した実行である。この作業分の追加削減は下の見積もりに上乗せしない。M2bのall-targetsでは中断テスト二件が30秒待ちで失敗し、同じtarget/を共用した並行実行をやめ、条件を変えず直列で成功した。これは段末で初めて見つかった本体の退行には数えない。

### 0.0.7 の段末と公開前の内訳

| 実行記録 | 指定 | 通常側の実行計 | gc-stressの実行計 | その他と完了状態 |
|---|---|---:|---:|---|
| G1 | rust,default_lib,skill | 469.29秒 | 1447.33秒 | default_lib 79.00秒。成功。build_infoはV1/V2/Z1で別途実施済み。段末での独立した追加実行のログなし |
| G2 | 同上 | 479.69秒 | 1472.98秒 | default_lib 79.91秒、両all-targets 1015.87秒。成功 |
| G3 | 同上 | 465.47秒 | 1414.25秒 | default_lib 77.24秒。成功 |
| G4 | 同上 | 504.70秒 | 1423.18秒 | default_lib 78.43秒、両all-targets 981.51秒。成功 |
| G5 | rust,default_lib,reference_examples,skill | 474.13秒 | 1426.48秒 | default_lib 78.59秒。成功 |
| G6 | rust,default_lib,spec_examples,reference_examples,skill,spec_coverage | 492.99秒 | 1550.12秒 | default_lib 91.08秒。成功 |
| Z6後 | G6と同じ | 499.93秒 | 1502.72秒 | default_lib 92.32秒。成功 |
| G7 | 完了記録では段末を省略 | 完了値なし | 実行の記録なし | check-G7.txtにはfmt・二構成lintと通常テスト開始までの途中出力がある。中止の時刻・理由は残らず、段末成功にも完全な未着手にも数えない |
| 公開前 | --full | 1534.40秒 | 2161.98秒 | default_lib 79.33秒、release_stack 21.49秒。全体68分。両all-targetsを加え87分 |

完了した段末は7回である。個々の外側の開始終了時刻は生ログにないため、36〜57分という完了文書の範囲を各行へ割り当てない。TODO-255の約5時間は概数として使う。原文の最後の約75分より、完了記録と生ログを照合した87分を優先する。

## 後の検査で初めて見つかった失敗

### 定例の段末・最後の検査による検出

記録から確認できた例を以下に全て挙げる。同じ原因の二テストは一件の事象としてまとめ、修正で新たに生じた失敗は別にする。失敗のない記録や、初回の場所を確定できないものを補って数えない。

| 番号 | 改造・時点・検査 | 失敗したもの | 作業の検査で見つからなかった理由と分類 |
|---|---|---|---|
| F1 | A05 最後のcheck、gc-stress | X2が追加した二つの中断プロセステストで、準備行の待ちに間に合わない | 作業は通常構成だけ。強制回収下でリスト生成が二次の時間になった。強制時100要素へ直し再実行成功。**構成の追加による検出**であり、同じ通常テストの繰り返しの効果ではない。根拠: [X2 handlingの追記](../../2026-10-11-TODO-185_201_202-regex-and-http-details/reviews/2026-10-11-X2/handling.md)、README所要時間 |
| F2 | A14 最後のcheck、golden | 補助経路のR0905にメモリの注記が増え、期待値と違った | 個別の短い検査では最終接続後のこのgoldenの期待値まで覆っていなかった。記録は初回停止を明記するが、漏れた個別フィルタの全履歴はない。**入力の範囲の追加**。根拠: [README状態](../../2026-10-13-TODO-020_241-wit-types-and-transfer/README.md#状態) |
| F3 | A14 再実行、spec coverage | 外部の関数のgolden8件のspec印が、集計対象の01-specの見出しを指していない | Rustのテスト成功だけでは集計器の契約を確かめない。**別の道具の不足**。根拠: [README状態](../../2026-10-13-TODO-020_241-wit-types-and-transfer/README.md#状態) |
| F4 | A14 F3修正後の再実行、golden | spec印の修正でバイト位置が動き、wit-generic-recursiveの期待位置と違った | 最後の検査の途中の修正が入力を変更した。F3より前の成功では確認できない。**修正後の再検査**。根拠: [README状態](../../2026-10-13-TODO-020_241-wit-types-and-transfer/README.md#状態) |
| F5 | A14 最後の既定lake build | CheckTablesSound.lean の証明が演算子型の正規化に合わない | 実行器からimportされない証明で、対象を絞ったビルドでは検査されなかった。Z6で場合分けを直し、定理の言明を保持した。**ビルド対象の不足**。根拠: [README状態](../../2026-10-13-TODO-020_241-wit-types-and-transfer/README.md#状態)、Z6対応 |
| F6 | A15 G8a中の前倒しcheck --only rust、test(mark-sweep) | runtime_builtinsの二テスト。旧位置引数がE0449となり、一方29診断、もう一方1診断 | Rust文字列中の入力の移行漏れである。lib全件と指定した統合テストだけではこの二件を通していなかった。Z9で16箇所を移行。**統合入力の範囲の追加**。all-targets専用の発見ではない。根拠: [G8a-reportの追加と対応8](../../2026-10-14-TODO-247-lambda-and-named-arguments/reviews/G8a-report.md) |

0.0.7 の完了した7回の段末と最後の検査には、初めて見つかった失敗はない。0.0.6の記録された段末と最後のfullにも、そのような失敗はない。上表以外の改造は、成功、最後の検査なし、または別の検出者として下表に分類した。記録が残らない試行まで「失敗0件」と断定するものではない。

### 作業・レビュー・測定で見つかったものとの区別

| 番号 | 例と検出者 | 検査方針への意味 |
|---|---|---|
| E1 | A02 H1の取り込み前checkで、不正な応答の誤りの順序の変化を検出（plan末尾） | 担当環境ではTCP不可で、取り込み担当が補った作業の検査である。段末の全件反復の実績とは分ける |
| E2 | A11 Z3レビューで、外部の関数の新goldenを読むcodegen corpus/verify二件の失敗を実行で再現 | 完了条件の --lib external だけでは、入力群を共有する別のテストが漏れる。入力を読む側も変更の影響に含める必要がある。取り込み担当の最後の検査を待たず発見した例である |
| E3 | A12 V7の作業報告でspec印の誤りを検出し、Z4で修正 | F3と同種だが、最後のcheckは一度で成功した。集計器を入力変更時に走らせる理由になる |
| E4 | A16 B10a-1のrandom_programsで約122秒の時間超過。G5bレビューでB10-3のpreludeからTraitを読む変更が原因と指摘 | 失敗自体は作業の統合テストで検出済み。変更前の基準をB10-3後に取ったため原因を誤認した。Z7で約50秒へ戻した。段末が初発ではない |
| E5 | A15 Z9の既定all-targetsでrandom_differentialが71.42秒、単独再実行48.59秒 | 重い検査との並行実行による時間超過と記録される。機能の反例はなく、条件を変えず再実行成功。全ターゲット専用の退行検出には数えない |
| E6 | A17 M2bのall-targetsで中断テスト二件が30秒待ちに失敗 | 同じtarget/で両構成を並行実行。負荷や実行ファイルの差し替えの影響は可能性であり原因を確定していない。直列再実行成功。成功だけを残さず、実行環境の失敗として記す |
| E7 | A05 最後の性能測定でfib約+8%、loop約+12% | HTTPのHashSet追加を戻すと解消し、Vec+二分探索で修正した。コードの配置・展開の影響という推定である。機能テストの失敗には数えないが、最終の測定に固有の価値がある |
| E8 | A16 の D1/D6/B7/B10-3 等の check-formal でmanifest/交換欄/標準宣言の欠落を検出 | 各作業の結果に初回失敗と修正がある。六入口の接続の検査であって、段末が初めての検出者ではない |

heap-verifyがある側とない側の違い、長いテスト、release_stack、Miri、両構成のlintが、定例の段末または最後で初めて失敗を見つけた例は、調査した記録にはない。A08の既定ヒープのテストの弱さは改造前の調査の対象であり、この種類の発見に数えない。all-targetsの追加部分だけが初めて機能の失敗を見つけた例も確認できない。これは検査の不要性を示すものではなく、実績から主張できる範囲の限界である。

## テストの水準と実行時期を分ける根拠

単体テスト（unit/component testing）は部品、結合テスト（integration testing）は部品間の接続、受け入れテスト（acceptance testing）は利用目的と公開可能な状態を対象とする。対象と目的が違うので、最後に単体テストを再実行しても受け入れの確認には置き換わらない。ISTQB CTFL 4.0.1 §2.2.1は、対象・目的・根拠・失敗の種類・責任等で水準を区別している（[一次資料](https://istqb.org/wp-content/uploads/2024/11/ISTQB_CTFL_Syllabus_v4.0.1.pdf)、2026-10-17確認）。

一方、継続的インテグレーション（continuous integration、CI）の段は、実行の順序や依存を決める区分である。GitLabの文書はジョブと段を分け、段の順序と依存による実行を説明している（[一次資料](https://docs.gitlab.com/ci/pipelines/)、2026-10-17確認）。これはこのリポジトリでGitLabやGitHub Actionsを導入する提案ではない。「レビューのまとまりの数だけ同じ検査を実行する」という必要は、CIの段の考え方からは導かれない、という本書の判断の参考である。

この区別をBenitoiteへ当てはめると、「作業・段・改造・リリース」は実行時期の区分であり、テストの水準と一対一には対応しない。作業の中でも公開CLIの結合テストを行い、改造の最後に既存機能の回帰検査（regression testing）を広く行うことができる。重複を判断する単位は、名前の同じテストだけでなく、対象の状態・構成・入力・確認する契約である。

## 形式化と今回の構文の改造への条件

[07-04「01-12 との対応」](../../../design/07-quality/07-04-formal-semantics.md#01-12-との対応) は検査の頻度とは独立した順序を定めている。形式化の範囲の内側なら、処理系より先に Lean の定義・型付け・脱糖（desugaring）・性質1の証明を直し、01-12の写しと対応表を同じ変更で揃え、定義と言明のレビューを受ける。外側なら対応表へ対象外と理由を書く。本件の調査はそれらを変更しない。

docs/todo の TODO-250 は、設計を一度に行い、実装は段ごとにレビューと取り込みを行い、版の更新と公開を一回にまとめる方針である。段ごとに全件の同じ検査を行うことまでは定めていない。TODO-189・249・191、導出の方式を決めた後の063・087について、形式化の内外と接続の時点を個別に判定する必要がある。内側の変更のLean先行を、検査の集約を理由に改造末へ送らない。

前回のtry処置の [判断Q6〜Q11](../../2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/decisions.md#q6-裸の-try-を今後も失敗を返すと固定するか) は、裸のtry/or returnの固定した意味、dieの表示と失敗終了、一般の型付き失敗の捕捉を区別した。TODO-249の実装を前回終えたとはしない。0.0.8の受け入れ条件には、この既存契約を保つことと新しい相互変換を確認することを別々に割り当てる。具体的な失敗エフェクトや導出の仕様はS1で決めない。

## 0.0.7 に当てはめた時間と危険の見積もり

まず、作業ごとの検査をそのまま残し、約5時間の7回の段末だけを条件付きの接続確認へ変える場合を計算する。推す案は [C1〜C4](check-policy-questions.md#c1-検査をどの時期と目的に分けるか) に記す。G1〜G5のうち実際に新しい接続を閉じる5箇所を一回2〜5分、文書だけのG6、Z6後の一括、改造末に隣接するG7の全件実行を省く仮定である。

| 項目 | 従来の実績または概数 | 案を当てた値 | 数値の性質 |
|---|---:|---:|---|
| 段末 | 約300分（個々は36〜57分、7回の単純な範囲は252〜399分） | 接続確認10〜25分 | 新案は計画上の見込み。5箇所の選択と時間は未実測 |
| 最後の広い検査 | 87分 | 一度の改造全体検査と公開候補の確認に分け、従来相当の87分を予算として残す | 時期の移動だけで減った扱いにしない |
| 公開候補に固有の追加確認 | 独立の計時なし | 5〜10分の仮予算 | CLI/ソース配布の確認の追加分。0.0.7はソースだけの公開である |
| 比較可能な合計（作業分を除く） | 約387分 | 約102〜122分 | 約265〜285分、約68〜74%減という計算。新規ビルドや失敗の修正時間は含まない |

この見積もりは、改造全体の検査と公開候補の確認で同じ全件を二度実行しないことを前提にする。別途、文書だけの8作業P1/P2/M2a/M3a/M3b/D3/F1/F2のlib実行は少なくとも約11分である。ただしD3/F1は実CLIの照合を含むので、その関連テストまで全て不要とはしない。この11分やC3/A4等の重複を上の削減額に上乗せしない。ビルドを含む完全な作業別の経過時間がないため、改造全体の総削減率は算出できない。

見つけ損ねる確率の増加は数値化できない。0.0.7の段末7回に初発の失敗がないことだけで、将来も危険がないとはいえない。既存の全件・構成・長いテストを改造末に一度残せば、主に変わるのは検出の時期である。0.0.7で最大約26分のgc-stressを毎段走らせた分は減らせるが、根の保持などを変えた作業で関係する強制回収まで省けばF1型の失敗を後まで持ち越す。局所の特殊構成を残し、共有の入力の読者を選択に含め、最後の検査で新たな失敗を見つけたら選択漏れを直す条件を付ける。

## 調べた改造の資料

各行の計画、完了記録、resultsのある作業、reviewsの指摘と対応を調べた。古い改造の多くは独立したresults.mdを持たず、READMEとplanの末尾が実績の記録である。

| 番号 | 改造のディレクトリと実績の資料 |
|---|---|
| A01 | `2026-10-11-TODO-165_166_167_169_177_194-small-fixes-and-hardening`。[README](../../2026-10-11-TODO-165_166_167_169_177_194-small-fixes-and-hardening/README.md)、[plan](../../2026-10-11-TODO-165_166_167_169_177_194-small-fixes-and-hardening/plan.md)、[reviews](../../2026-10-11-TODO-165_166_167_169_177_194-small-fixes-and-hardening/reviews) |
| A02 | `2026-10-11-TODO-042_177_195_196_197_198-runtime-and-check-hardening`。[README](../../2026-10-11-TODO-042_177_195_196_197_198-runtime-and-check-hardening/README.md)、[plan](../../2026-10-11-TODO-042_177_195_196_197_198-runtime-and-check-hardening/plan.md)、[reviews](../../2026-10-11-TODO-042_177_195_196_197_198-runtime-and-check-hardening/reviews) |
| A03 | `2026-10-11-TODO-178_190-typecheck-and-desugar-fixes`。[README](../../2026-10-11-TODO-178_190-typecheck-and-desugar-fixes/README.md)、[plan](../../2026-10-11-TODO-178_190-typecheck-and-desugar-fixes/plan.md)、[reviews](../../2026-10-11-TODO-178_190-typecheck-and-desugar-fixes/reviews) |
| A04 | `2026-10-11-TODO-174_175_180-cleanup-and-small-runtime-fixes`。[README](../../2026-10-11-TODO-174_175_180-cleanup-and-small-runtime-fixes/README.md)、[plan](../../2026-10-11-TODO-174_175_180-cleanup-and-small-runtime-fixes/plan.md)、[reviews](../../2026-10-11-TODO-174_175_180-cleanup-and-small-runtime-fixes/reviews) |
| A05 | `2026-10-11-TODO-185_201_202-regex-and-http-details`。[README](../../2026-10-11-TODO-185_201_202-regex-and-http-details/README.md)、[plan](../../2026-10-11-TODO-185_201_202-regex-and-http-details/plan.md)、[reviews](../../2026-10-11-TODO-185_201_202-regex-and-http-details/reviews) |
| A06 | `2026-10-12-TODO-182_183_184-test-reliability-and-io-details`。[README](../../2026-10-12-TODO-182_183_184-test-reliability-and-io-details/README.md)、[plan](../../2026-10-12-TODO-182_183_184-test-reliability-and-io-details/plan.md)、[reviews](../../2026-10-12-TODO-182_183_184-test-reliability-and-io-details/reviews) |
| A07 | `2026-10-12-TODO-177_181_185_186_214-test-gaps-and-library-details`。[README](../../2026-10-12-TODO-177_181_185_186_214-test-gaps-and-library-details/README.md)、[plan](../../2026-10-12-TODO-177_181_185_186_214-test-gaps-and-library-details/plan.md)、[reviews](../../2026-10-12-TODO-177_181_185_186_214-test-gaps-and-library-details/reviews) |
| A08 | `2026-10-12-TODO-173_208_215_220-runtime-and-http-robustness`。[README](../../2026-10-12-TODO-173_208_215_220-runtime-and-http-robustness/README.md)、[plan](../../2026-10-12-TODO-173_208_215_220-runtime-and-http-robustness/plan.md)、[reviews](../../2026-10-12-TODO-173_208_215_220-runtime-and-http-robustness/reviews) |
| A09 | `2026-10-12-TODO-170_179_209_221-diagnostics-and-test-gaps`。[README](../../2026-10-12-TODO-170_179_209_221-diagnostics-and-test-gaps/README.md)、[plan](../../2026-10-12-TODO-170_179_209_221-diagnostics-and-test-gaps/plan.md)、[reviews](../../2026-10-12-TODO-170_179_209_221-diagnostics-and-test-gaps/reviews) |
| A10 | `2026-10-12-TODO-193_219_224-guard-return-test-runner-and-diagnostics`。[README](../../2026-10-12-TODO-193_219_224-guard-return-test-runner-and-diagnostics/README.md)、[plan](../../2026-10-12-TODO-193_219_224-guard-return-test-runner-and-diagnostics/plan.md)、[reviews](../../2026-10-12-TODO-193_219_224-guard-return-test-runner-and-diagnostics/reviews) |
| A11 | `2026-10-13-TODO-046_047_048_085_090_092_093_094_096_098_211-packages-and-wasm-phase1`。[README](../../2026-10-13-TODO-046_047_048_085_090_092_093_094_096_098_211-packages-and-wasm-phase1/README.md)、[plan](../../2026-10-13-TODO-046_047_048_085_090_092_093_094_096_098_211-packages-and-wasm-phase1/plan.md)、[reviews](../../2026-10-13-TODO-046_047_048_085_090_092_093_094_096_098_211-packages-and-wasm-phase1/reviews) |
| A12 | `2026-10-13-TODO-047_212_230_232_234_235-packages-and-wasm-phase2`。[README](../../2026-10-13-TODO-047_212_230_232_234_235-packages-and-wasm-phase2/README.md)、[plan](../../2026-10-13-TODO-047_212_230_232_234_235-packages-and-wasm-phase2/plan.md)、[reviews](../../2026-10-13-TODO-047_212_230_232_234_235-packages-and-wasm-phase2/reviews) |
| A13 | `2026-10-13-TODO-240-typed-list-transfer`。[README](../../2026-10-13-TODO-240-typed-list-transfer/README.md)、[plan](../../2026-10-13-TODO-240-typed-list-transfer/plan.md)、[reviews](../../2026-10-13-TODO-240-typed-list-transfer/reviews) |
| A14 | `2026-10-13-TODO-020_241-wit-types-and-transfer`。[README](../../2026-10-13-TODO-020_241-wit-types-and-transfer/README.md)、[plan](../../2026-10-13-TODO-020_241-wit-types-and-transfer/plan.md)、[reviews](../../2026-10-13-TODO-020_241-wit-types-and-transfer/reviews) |
| A15 | `2026-10-14-TODO-247-lambda-and-named-arguments`。[README](../../2026-10-14-TODO-247-lambda-and-named-arguments/README.md)、[plan](../../2026-10-14-TODO-247-lambda-and-named-arguments/plan.md)、[reviews](../../2026-10-14-TODO-247-lambda-and-named-arguments/reviews) |
| A16 | `2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or`。[README](../../2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/README.md)、[plan](../../2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/plan.md)、[results](../../2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/results.md)、[reviews](../../2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/reviews) |
| A17 | `2026-10-17-TODO-254-harness-check-interface`。[README](../../2026-10-17-TODO-254-harness-check-interface/README.md)、[plan](../../2026-10-17-TODO-254-harness-check-interface/plan.md)、[results](../../2026-10-17-TODO-254-harness-check-interface/results.md)、[reviews](../../2026-10-17-TODO-254-harness-check-interface/reviews) |

本調査では処理系の検査・ビルド・性能測定・LLMを呼ぶ評価を実行していない。文書の確認として、ローカルリンクと見出し、表の列数、TODO-255の原文との一致、C1〜C12の連番、空白と変更範囲を確認した。check.shのdry-runは、既定のorigin/san_benito基準では既にHEADへ入ったSkill評価の記録4件も拾い、skill_eval/pythonを選んだ。今回の追加3文書だけを比べる `scripts/check.sh --base HEAD --dry-run` は検査対象なしであった。いずれも表示だけであり、選ばれた処理系・道具の検査は実行していない。
