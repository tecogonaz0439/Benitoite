# 第5弾の計画全体の事前点検（下書き）

2026-10-23、P1作成、P2でRP1対応。開始版は `a9c4132e6451904698cf344db1794c4d03affcd6`、ブランチはsan_benitoである。[plan.md](plan.md)・[decisions.md](decisions.md)・[共通依頼文](implementation-request.md)を現行の設計書・インターフェース・コードへ突き合わせた。これは計画担当の読解と文書の静的点検であり、独立レビューの受け入れ記録ではない。実装担当を起動する前に、取りまとめが実際のB_WORKと依存の出力で再点検する。

## 点検の範囲と実行していないこと

AGENTS.md、READMEの二つの「設計者の決定」、指定のstudyと問い、RS1〜RS3の指摘・対応、現行の00-01・00-04、言語仕様、処理系設計、03-01・03-06、06-01・06-03・06-04・06-06・06-09、07-03・07-04、共通の雛形、関係するRust・Lean・Python・検査スクリプトを対象とした。docs/todoは指定された4項目の範囲の読み取りだけに使い、実装に必要な内容は決定記録と計画へ写した。TODO-206にはログの出力先等が残るため、今回の部分だけを完了とする。

P1ではgitを状態・HEAD等の読み取りだけに使った。その開始時の作業ツリーに変更はなく、空き容量は約103GiBであった。P2ではgitを使っていない。ビルド・Cargoのテスト・Leanのビルド・処理系による再現・ベンチマーク・LLM評価はどちらでも実行していない。過去のstudyの実行結果をP1/P2の実行結果とは扱わない。

## 現行のインターフェースと依存の出力

| 対象 | 確認した現行の形 | 計画での受け渡しと判定 |
|---|---|---|
| モジュールのAST | `src/syntax/ast.rs`のModuleはheader/imports/declsを別々に持ち、file_usesはない。ファイルの構文解析の入口は`parser/decls.rs`であり、parser/mod.rsは基盤である | A1でfile_usesを追加し、全構築箇所を追随させる。未接続の型検査・構文入口はD36の一時防御で拒否する。通常のItem::Fnへ仮装しない。元のFnDecl.usesは保ち、A2の有効契約へ渡す |
| lex/parse | `lexer::lex(file,text) -> LexOutput`はtokens/comments/diagnostics、`newline::resolve_newlines(Vec<Token>) -> Vec<Token>`、`parser::parse(file,kind,text,tokens,comments,ids) -> ParseOutput`。字句診断は呼び出し側が先に受け取る | 保留診断をparserだけへ局所追加しても呼び出し側が失う。D28・F1に全読者の移行と範囲別の確定を割り当てた。F0で受け渡しの詳細を試す |
| 補間と先読み | lexer/string.rsはContent/Exprの状態を明示スタックで扱う。parser/interp.rsは式の直後にStrMid/StrEndを要求する。newline/lambda_boundsは解析前に字句を見る | F1で補間の入れ子ごとの状態を隔離し、F2で式を読み終えてから残ったコロンと元ソースを使う。括弧深さ0の最初のコロンではblock内の注釈を壊すため使わない |
| 部分の型情報 | 現行`InterpSegment`はspan/expr/tail、型情報は`types.interp_types`に置く。交換器もこの表から基本型を得る | F2で任意の書式と部分spanを加え、F4aで具体化済み型と適合を確認、F4bで脱糖・定数・実行へ渡す。F5は書式を含む表層をそのまま出し、通常呼び出しへ先に落とさない |
| 宣言の型付け | typeck/decls.rsの署名収集で`self.uses(f.uses.as_ref(), scope)`を使い、最外側の効果行・失敗型とNoFailを処理する | A2はこの前にファイル位置で解決した追加分を合併する。関数の同名パラメータを取り込まず、公開性・NoFail・外部照合まで同じ有効契約を見る |
| 名前解決と元位置 | resolve/walk.rs・checks.rsが元の参照を見て署名の公開性を調べる | Schemeへの追加だけでは公開性の検査から抜ける。A2に追加元の解決済み参照と効果別spanを渡す処理を入れた。構文の複写とNodeId再利用を避ける |
| 入口とJSON | cli/effect_limit.rsとtest_runner/check_report.rsは宣言上限を比較・報告する。通常checkの成功時の標準出力は空である | A3は合併済み契約と追加元を使う。D24は既存の成功報告をハーネスが示す手順であり、通常checkへ新しい文章を加えない |
| package | cli/tools/package/effects.rsは型検査済みSchemeではなく公開宣言の構文を読む。LogはState/IO.Allの短縮名処理だけでは拾えない | A4に独立した集計の修正・Logの識別・外部公開の直下の関数がある場合だけの追加・記録とupdateを割り当てた |
| derive inventory | `examples/derive_inventory/mod.rs`はversion2、moduleにimports/preambleEndを出す。preambleEndはdocとメタデータの末尾。Pythonは必須欄と版を厳しく検査する | D33でversion3とfileUses/importInsertLimitを必須化。preambleEndの意味を変更しない。A5でschema.rs・Python検証・READMEも一緒に変える |
| deriveの適用 | `tools/derive/derive.py`は既存importまたはpreambleEndから位置を求め、既存管理領域も候補にする。生成記録・manifest/receiptは版3、inventory版2、hash版3、generatorは3.0.0-syntax-batch4 | 挿入位置だけの修正では既存領域がusesの後にある経路が残る。A5で両経路を制約する。新generator/inventoryの条件を明示し、旧manifestは適用不可、旧記録は本文とhashを照合する新previewだけへ移す |
| try-actions inventory | `examples/try_actions_inventory.rs`のfunction_ownerは個別のusesの元文字列だけを出す。現行inventoryのルートにversion欄はなく、migrate.pyのmanifestはVERSION=1 | 「inventory1→2」という不正確な前提を避け、D33を「inventoryにversion2を新設、manifest1→2」とした。個別usesの意味を保ち、追加元と確認済み上限を別欄へ渡す |
| 整形器とSkill署名 | formatter/roles/walk.rsはheader/imports/declsを別に走査し、Skill生成器のdecl_headは標準ソースの元範囲を切り出す | A6でファイルの宣言を走査する。標準ソースでは不使用の規約を既存の解析検査で守り、生成署名から追加分が消える問題を防ぐ。利用者の構文への制限にはしない |
| 回復 | solve/provenance.rsはedges/incident/shapes/recovered/components/usesを既に持つ。Declared優先とzonkの後には元の変数が見えなくなる経路がある | C1/C2は既存Provenanceを拡張する。元の回復変数へ利用側が流し込んだ型と、束縛自身の明示契約・正常な関数の結果型を区別する。成功入力の順序とTy/交換は保つ |
| Leanの補間 | InterpPartはtext/stringExpr/converted、converterTypesは純粋な型別の直接頭を要求し、既存補間は全式評価後に変換・連結する | L1の書式データ→L2aの型付け・脱糖・型保存とL2bの全判定・証明→L3の交換、F4a/F4b/F5の利用と出力という依存を固定した。L2aは型付けと脱糖を完成させ、checkerの一時拒否で既存の証明を保つ。L2bが受理と証明を完成させるまで段Iを完了としない |
| Leanの交換の版 | Exchange/Version.leanはcorpus8〜13・sidecar2〜5、sidecarVersionはcorpus13以上を5へ写す。既存Pythonの版分岐にも13/5が埋め込まれている | L3/F5で14/6の全読者を追随させ、旧版の意味を維持する。新構成を旧版で黙って読むことを禁止する |
| 幅の依存 | unicode-widthはCargo.lockに0.2.2があるが、現状はdev-dependenciesのwat/wast経由であり、通常の直接依存にない | W1で固定の通常依存とcjkを明示し、03-01・ライセンス・Z1の配布表示を追加対象にした |
| 版問い合わせ | `src/cli/mod.rs`のVersionJsonはschemaVersion1とCharacter用unicodeVersionを出す。Versionはtext::VERSIONの二行を使う | D31で任意欄displayWidthUnicodeVersionを追加し、二行契約を保持。06-01を三行に変える作業は計画へ入れない |
| builtinsの境界 | funcs/string.rsは`BuiltinDecl`と`builtin!`、StrBuf/CheckedLen/予算を介して値を確保する。登録表の既存順は番号の意味を持つ | W2/F3は既存項目を並べ替えず追加する。数と幅の本体はbase側に置き、VM・Host・Wasmtimeから独立させる。新しい安全点の保持方式を変えたら局所特殊構成を前提にする |

## 例と診断の点検

| 例・契約 | 読解で確認できたこと | 実装時の確認と担当 |
|---|---|---|
| `uses Log, Console.Write` | Logはprelude、Consoleは`import Benitoite.Unofficial.IO.Console`を使う。古いimportの誤りはRS2対応で直されている | A1/A2でメタデータ→import→uses→関数の正負、main/test/外部/生成/非対象を確認 |
| `Fail[MyError]`と効果変数 | 具体型をファイル位置で解決し、同じFailの別名同一性と異なる失敗型を区別する必要がある | A2でNoFail計算を合併後へ移す。NoFail条件を新しく弱めない |
| `"${1.5m:+08.2f}"`・`"${-42:#08x}"` | studyの決定に従えば+0001.50と-0x0002aである。現行CLIでの成功例ではない | F3/F4bで独立期待値へ照合。整数最小値・Decimal最大値・負の零も同じ本体に通す |
| `"${f(x: 1):>8}"`・block内注釈 | 式の構文が消費するコロンと書式区切りを分ける必要がある | F0/F1/F2でラムダ・raw・三重引用符・入れ子・回復の先読みを対照にする。机上の反例を再現済みと表示しない |
| `String.displayWidthPadStart(s: s, width: w)` | 既存の名前付き引数構文で書ける。六関数の名前と署名は新規の決定であり、現行にはない | W2で標準ソース・組み込み宣言・参照文書を一致させる。0以下/幅超過で内容を変えず、両モードでmax契約を確認 |
| 空白による幅の加法性 | study9.3は両モードの生成済みソースの状態遷移を読んだ判断である。一般の連結の加法性は主張していない | W1で同版のソースを再確認し、先頭結合文字・末尾VS/ZWJ・合字・制御境界を小さい独立期待値で確認。今回のP1では実行していない |
| 回復のerror記号 | errorは説明用の記号で、Benitoiteの構文ではない | C1で不正なSourceLocation.hereと呼び出し不能を使って新規ビルドから再現する。f自身の注釈・n自身の注釈・正常な戻り型・外側構造の独立誤りを残す |
| 新しい診断番号 | 開始版の構文コードの末尾はE0260、型のコードにはE0467があり、E0261/E0262/E0468の使用はなかった | D34で予約を固定し、A1/F2/F4aでcodes.rs・02-10の説明・生成Skillを同時更新。E0422は書式なし、位置/意味の既存診断は既存コードを使う |

## 計画で直した食い違い

| 食い違い・漏れ | 修正した内容 | plan.mdの反映先 |
|---|---|---|
| ファイルusesの追加を型表だけへ置くと、公開性・入口・外部・警告が元ASTを見る | 有効な効果行と効果別の由来を一つの宣言収集から返し、ASTの元範囲を別に保つ | 受け渡しの表、A2・A3、D32 |
| packageの構文集計と型検査済み上限は別経路 | 外部公開の直下の関数があるファイルだけを構文で合併し、Logの識別も両リストへ適用する | A4、stage S-A |
| deriveの新規挿入位置を直すだけでは既存管理領域からusesの後へimportが入る | importInsertLimitを新設し、既存領域の選択も制約する。preambleEndをuses末尾へ広げない | A5、D33 |
| try-actions inventoryに既存version1があると仮定できない | 現行は版欄なしと確認し、新しい必須version2を導入する。manifestは1→2 | A6、D33 |
| `migrate_selftests`がderiveまで検査するという誤解 | check.shはsource-migrateとtry-actionsだけを実行するため、derive_inventoryのビルドとtest_derive.pyを直接割り当てた | work A5、特殊構成等の表 |
| 脱糖の設計章を02-07とする参照 | 現行02-07はバイトコードであり、脱糖は02-06へ直した | F3・F4bの参照先 |
| 人間向け版問い合わせへの三行目追加が現行契約と衝突 | 二行を維持し、表示の幅のUnicode版はJSONの任意欄とリファレンスへ置く | W2・Z1、D31 |
| formal_build成功を全比較の証拠に使えない | Lean段の既定ビルドとレビュー、F5のK1、最終候補のK2を分離した | L1・L2a・L2b・L3、F5、Z1、検査表 |
| 本番を変えないF0にもLean先行を課すと、字句方式の不成立の発見が遅れる | RP1指摘2を受け、scratchだけのF0をB0直後・L1前へ移した。F1以降の実装のLean先行は保つ | 段とレビュー、F0、D35 |
| 0.0.11準備の後へ性能測定を残す可能性 | 処理系を変える取り込みごとのshortをG1/Z1の前へ置き、候補中に動作修正が必要なら修正作業へ戻る | short行とZ1、D35 |
| 共通雛形の作業単位をそのまま使うと一作業が数時間になる | 合併・入口・package・derive・整形/移行、回復の原因と複合型を分け、23作業の依存と30〜60分の仮予算へ具体化した | 各作業と残り手順の表。L2a/L2b・F4a/F4bへ分け、ビルドと防御が成立する境界を明記 |

## 組込み向けの構成と利用者向け文書

数と幅の本体は通常のRust関数に置き、Wasmtime・VMの内部へ依存させない。Unicode表は小さい共通の基盤依存としてcjkを含め、構成ごとに同名関数を別の意味へ置き換えない。新しいネットワーク・暗号・サーバ依存や64ビットだけの前提は増やさず、動的widthと確保サイズはcheckedな算定・変換で処理する。将来の機能分割は今回実装する対象に加えない。

利用者向けの説明はハーネス経由を中心に置く。ファイルusesは許可操作の自動承認でもOSの隔離でもなく、検査済みの宣言上限である。Skillは成功したJSON報告を示す条件と、処理系の版を固定した報告仕様を参照し、ハーネス固有の操作や権限画面を写さない。英語リファレンスと手書きSkillは機能と同じ変更、日本語訳・版・CHANGELOGはZ1にまとめる。生成文法・診断・標準ライブラリの参照はgen_skillで作り直し、手修正しない。用語集はA1/F2/W2へ、診断の表と説明はA1/F2/F4aへ、追加元の診断の説明はA2/A3へ割り当てた。02-03では「補間の入れ子」とし、用語集の「枠」と混同しない。

## 検査と見積もりの点検

workを各作業、stageは相互作用のS-Aと条件付きS-F、changeをG1で一度、releaseをZ1の実候補で一度へ割り当てた。S-W・S-CはW2・C2のworkを引用し、S-FもF5がsrcや関係入力を変えなければF4bのworkとF5の交換検査を引用する。check-formal全体は接続を閉じるF5と最後の関係状態のZ1で行い、Leanだけの段へRustとの全比較を要求しない。既定/heapのall-targets、stress、doc、二構成lint、long_onlyはG1のchangeを入口とする。check-heapはheap配下を変えたときだけ自動選択され、変えなければ不要な理由をg1/results.mdへ記す。安全点や保持方式の変更に必要な局所検査は末尾へ前倒しする。Lのworkは自動分類でformal_build・spec_examples・spec_tallyを選び、formal/testsのPythonはL3の直接実行で確かめる。

gc-stressの新規入力は小さい値・幅を基本にし、65535の境界を反復や深い入力と組み合わせない。既存テストの緩和は予定しない。shortは処理系を変えた取り込みに直列で15分以内（ビルド別）を割り当て、W1はW2後へまとめ、examples/toolsだけのA5は外す。targets/fullは性能目標・バイナリ配布のない今回は実施しない。新しいLLM評価と実行ファイルの増分の測定も含めない。長い検査の時間は未測定であり、不明と仮予算を分けた。初回の短い局所観測とL1/F0の結果で見込みを更新する。

実装・検査・測定・レビュー・受け入れの残り手順はplan.mdの一つの表に集めた。23作業の仮予算は990〜1320分（16.5〜22時間）であり、studyの所要時間の見込み30〜59時間と区別した。各作業の30〜60分はセッションを区切る予算で、実測による短縮の主張ではない。L2とF4は二作業ずつへ分け、F0後とL1後に残り全体を更新する。A2の宣言収集とZ1の訳も継続時間を隠さない。独立したレビューと受け入れの待ち時間は不明である。

## 取りまとめが起動前に確かめること

1. P1文書の独立レビューを受け、D28〜D40の委任内の判断と作業粒度・仮予算を受け入れる。レビューを通ったとはP1自身で記録しない。
2. F0はB0直後にscratchだけで行い、L3末の既定ビルドと定義・言明・仮定のレビューをF1以降の形式化の内側の実装の条件にする。主な定理の前提・結論の変更、公理・Builtins.Assumptionsの追加が必要なら当該Lean作業を止め、設計者へ報告する。W/A/Cは進められる。その後は報告して待ち、V・VI・版上げへ進まない。
3. 各依頼のB_WORKとB_STAGEを完全IDへ固定し、依存の出力・現行シグネチャ・追加された関連ターゲットを再点検する。L1後とF0後の見積もりを更新する。
4. 実行環境のネットワーク・nightly・Lean・cargo-deny/cargo-about等の利用可否を開始前に確認する。使えないものは未実施の担当・時期を残し、別環境での実行を取りまとめる。
5. 最終候補を同梱物・版・生成物・実CLI・移行案内と照合し、委任範囲の受け入れを記録して設計者へ返す。履歴の集約・タグ・pushは指示を待つ。

現時点で言語の規則を再質問する項目はない。実行によって初めて分かる字句接続の成立・証明の通過・時間・stressの費用を、既に確認済みとは扱わず、対応する作業の先行条件と停止条件に残した。

## RP1で追加した事前点検

| 指摘の対象 | 今回読み取って照合した根拠 | 計画へ反映した点 |
|---|---|---|
| 検査単位と自動分類 | check.shのclassify・work/changeへの展開・source_rules・check_python_tools。spec_examples.rsの01-spec読取り | Lの自動work、文書確認の別手段、条件付きheap_checks。F2前は新表層例をtextフェンスへ入れない |
| ASTを読むexamples | derive_inventoryのModule読取り、try_actions_inventoryのsegments走査。lint_defaultはlib/testsのみ | A1・F2・F4a・F4bでexamplesを局所ビルド |
| 互換性の案内 | modules/package.rsのBREAKING_CHANGESと版別の検証、modules/text.rs、06-09の登録 | D37とZ1に0.0.11の登録とsummary/help、package_commandを割り当て |
| 型検査の途中と非対象 | file-effects 3.2、typeck/decls.rsと外部・入口、packageのAST読取り | A1の一時防御をA2・A4〜A6へ引き継ぐ。操作・定数・ハンドラ・局所関数値・doc例を非対象として明記 |
| 報告の受け手 | 06-01「main の非実行の検査報告」の完全なJSON・schemaVersion/kind・status・complete・終了状態 | D24とA3に条件全体を反映 |
| deriveの同梱例 | examplesのinventoryVersion2/generatorVersion、test_derive.pyの四ファイル複写 | 三例はA5で新preview・確認済みハッシュによる再生成。旧版の対照は専用入力へ |
| 型と診断の読者 | vm_handlers・io_modes内のtyped_failure、diag/codes.rsと02-10 | 存在しない統合名を除き、A2の両ターゲットとA2/A3/F4aの診断の文書を補う |
| 形式化の境界と用語 | 07-04の内外の対応、00-04の枠/call frame、studyの表示の幅の用例 | W2でTODO-272の対象外の行と用語集を更新。補間は入れ子と呼ぶ |

ここでの照合は読解による確認である。字句方式、証明と途中ビルドの成立、本体なし関数の次行usesの実診断、AST変更後のexamplesのビルド、JSONの実出力は実行で確かめる対象として各作業へ残した。

## P1の文書確認の結果（変更前の記録）

以下はP1時点の記録であり、P2で改めた文書の検査結果として引用しない。source_rulesは文書リンクの確認を含まず、その静的確認はP1の別スクリプトの結果である。P2ではgit操作を行わず、check.shも起動しない。P2の文書確認は[RP1-response.md](reviews/RP1-response.md)へ記す。

- 基準: `a9c4132e6451904698cf344db1794c4d03affcd6`。HEADは変更していない。
- `scripts/check.sh --level work --base a9c4132e6451904698cf344db1794c4d03affcd6 --only source_rules --dry-run` は終了0。名指した規約の二つの検査だけを選ぶことを確認した。
- 同じ指定からdry-runを外した実行も終了0。規約検査と後続のgitの読み取りを合わせたツール呼び出しの外側の時間は約0.3秒であり、検査単独の時間は分離していない。
- 新規4文書とREADMEの相対リンク・見出し参照・フェンス・末尾空白、D1〜D35の連番と重複なし、21作業のIDと一覧を静的に確認した。問題はなかった。
- `git diff --check`は終了0。新規文書は未追跡なので、別の読み取りスクリプトで末尾空白等も確認した。変更は指定の4文書とREADMEの一覧4行だけである。
- 実装・ビルド・実行テスト・測定・独立レビューは未実施。実装担当の起動と検査はplan.mdの割り当てに従う。
