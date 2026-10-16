# M5・G7 の移行の照合表

## 比較元と記録

P1 の `dc375420073cf71f8fcd0a85aa4c29c19078715e` と M4 取り込み後の `3bfece32` を比較した。P1 の [inputs.json](../p1/inputs.json) にある646候補・166ファイルを、[audit.json](audit.json) の p1_candidates へ全件対応付けた。index は P1 の study_try_candidates の0始まりの添字であり、パス・元の行・snippet・両時点のファイルのハッシュを残す。P1 の件数は簡易字句走査による候補であり、AST や実行テストの件数とは区別する。

`python3 -B docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/m5/audit.py` で比較記録を標準出力へ再生成できる。この道具は作業記録の照合専用であり、通常の検査から呼ばない。入力・期待値・assert を書き換えず、比較元の Git オブジェクトと P1 のハッシュの一致も確認する。

| P1 のファイルの役割 | ファイル数 | 最終の扱い |
|---|---:|---|
| 検査・検査の生成器・処理系の中の検査 | 102 | 裸の形と観測を保持。下表で入力と assert を確認 |
| 設計書・英語リファレンス・手書き Skill・診断の生成元 | 19 | M3 の変更・既に明示・記法の確認に対応 |
| 標準ライブラリ・現在の tools の手本 | 40 | M4 の136箇所を or return に移行 |
| 日本語訳 | 5 | M8 で最終の英語版から訳し直す。M5 では保持 |
| 合計 | 166 | 未分類0ファイル |

M3 の113入力と M4 の195入力、計308入力について、最終の inventory のハッシュと現在のファイルがすべて一致した。M3 の機械適用56箇所・手作業の省略例/実行用 fence 12箇所・インラインの確認、M4 の136箇所の契約と適用結果は、それぞれ [M3 の確認表](../m3/review.md)・[M4 の確認表](../m4/review.md)を参照する。M5 で移行の追加適用はしていない。

## 全追跡入力の再走査と保留の確定

`python3 -B tools/try-actions-migrate/migrate.py inventory --out /tmp/benitoite-m5-inventory` で、追跡中の2,987入力・3,721候補を走査した。[reconciliation.json](reconciliation.json) に全入力のハッシュ、自動分類の集計、自動分類が hold/change だった170候補の位置・元の分類・保持理由・実際の行を残す。日本語訳は予定された後続作業として明示する。自動分類の保留を消したり、型検査していない断片を型検査済みに替えたりしていない。

| 自動分類 | 件数 | 確認後の扱い |
|---|---:|---|
| already_explicit | 270 | return/die を明示済み。英語の手本は M3/M4 の最終ハッシュとも一致 |
| change | 8 | 全件が日本語訳。M8 へ引き継ぐ |
| history | 2,394 | 保管資料、過去の測定・評価、構文比較の固定入力、移行器自身や改造の記録。編集しない |
| keep_test | 643 | Rust・testdata・fuzz の検査。裸の成功/失敗を維持 |
| notation | 244 | 語、EBNF、構文・型・脱糖の一般形に加え、当時の移行器が未解析だった `benitoite test` の実行用 fence も含む。実行用 fence は M3 で個別に確認・移行済み |
| hold | 162 | 下の内訳へ全件対応付けた |
| pre_migration | 0 | 今回の自動分類に該当なし。移行前の引用は M3/M4 の before と history に記録 |
| 合計 | 3,721 | 未分類0件。英語の現行サンプルの未確認0件 |

この表は M5 時点の走査の記録である。G7・Z9 では、未解析の `benitoite test` などの実行用 fence を `hold` に分類するよう移行器を修正した。過去の集計と reconciliation.json は当時の分類を保つ。

hold の内訳は、日本語訳38、スタック検査の生成器7、移行器の説明2、通常の実装・文書・生成元の記法/説明109、裸の意味の一般形4、形式化の検査の説明2である。後二者も実行する手本ではない。裸の一般形4件は、language-comparison の Rust の `?` との対応、01-02 の明示形との同値性、01-09 の優先順位の二つの表記である。周囲の明示形と説明を読み、移行漏れでないことを確認した。生成元の E0211 の修正例には or return がある。

M3 が確認した26件の AST の裸の一般形と、実行する32ブロックの TryExpr 72件（return 40・die 32・裸0）は、変更されていない入力のハッシュによって対応を維持する。M4 の現行入力は136件すべて明示形で、残る9件は検査の生成器と移行器の説明である。最小版リファレンスに try の実行例はない。日本語訳の46候補（change 8・hold 38）は M8 の範囲であり、英語の移行完了に数えない。

## 裸の検査の入力と観測

P1 の golden 66入力と、同じ名前の期待値・付属ファイルを含む254ファイルは、元と現在の SHA-256 がすべて一致した。Rust ホスト38ファイルの try を含む復号済み断片は163件が完全一致し、差のある5断片を個別に確認した。断片の集合の一致だけで assert の保持を判断せず、以下の境界の差分と現在の assert を読んだ。

| P1 の持ち主の境界 | 入力・assert・観測の照合 |
|---|---|
| parser/effects の lazy・guard・try/catch・深さ | 元の表と assert はそのまま。パイプ全体の AST、E0218、E0235・位置・回復、997/1001 の try の入れ子の条件を保持 |
| typeck/effects の specification_examples_and_output_tables | first-release-try.bnt の三つの裸の入力と Result の判定を保持。`info.ret == ret` は型表の変更に合わせて `info.action == Return { ret }` へ厳密に対応 |
| 同 try_infers_return_types_and_reports_incompatible_types | 元の Option/Result と lambda の入力を false の枝で実行。true の枝に明示形を追加した。E0440/1/2・位置・help、E0407、入れ子2件の判定は保持 |
| 同 lambda/placeholder の note と副位置・型の流出 | 入力と既存の assert はそのまま。診断1件、最内の戻り先、note 全文、副位置の有無、誤転用の拒否を保持 |
| ir/desugar の try_reconstructs_failure_using_function_return_type_arguments | 元の裸を suffix が空の枝で実行し、明示形の枝を追加。Result/Option の二分岐、失敗の Escape の型、成功の型、try の位置の全 assert を保持 |
| refinterp の escape_and_try_stop_at_the_called_function_boundary | 裸の入力と `12\nbad\n` の期待は完全一致。失敗後に wrong を出さず、呼び出した関数の境界で戻る |
| named_escape・placeholder-try-run の golden | 元の入力・stdout・終了状態がハッシュ一致。callee/引数の順と穴で作る戻り先を保持 |
| c12-with-try-release・refinterp の解放 | 元の入力・期待値を保持。`early\n`、解放後の使用の失敗、通常 exit の状態3を観測。追加した die の任意欄は None を厳密に要求 |
| c11-try-not-result・placeholder-try-error | 元の E0440/E0441 の golden 全体が一致。主文・主/副位置・note・help・終了状態を保持 |
| formatter の PARENS と with の表 | 元の入力・正規形・再解析・二度目の整形の assert を保持。裸と明示形を混ぜる新しい行は追加分 |
| random_programs と generator | 両ファイルは P1 とハッシュ一致。生成件数、種、try-option/try-result、成功/失敗、VM/参照の比較、60秒制限を変更していない |
| desugar_export・coverage_export の corpus | 既存の独立入力と生成の入口を維持。新しい処置の交換を追加したが、元の裸の corpus を外す変更はない。六入口の全体は B14 の記録と、取り込み時のオーケストレータの検査に委ねる |

差のあるRustの5断片のうち、検査入力は二つである。resource_tests の cancellation_program は、共通化した関数を winner=`Result.Ok(2)`、extra_uses=空で呼び、旧入力を復元する。追加の Process の import 以外は復元後に元と一致することを audit.py で確認した。旧テストの仕事の筋書き・解放回数・出力の assert は維持し、die の別のテストを追加している。l21_json は Trait の import、Show・構築/更新の検査を追加した。元の try と Result.Ok の期待、ParseError の位置・message の条件は残り、fields の条件に Show の等式が加わった。残る三断片は grammar の導入と E0218 の説明、E0211 の修正例という生成元であり、裸の検査入力ではない。

## 診断・生成物・通常の検査の依存

M5 で診断の仕様変更はない。旧→新の対応、理由、元の誤りの保持先は [diagnostics.md](diagnostics.md) に集約した。M3 の E0211 の help 以外、P1 の裸の golden の診断には変更がない。

gen_skill を二度実行した。Skill 全59ファイルと bundle の計60ファイルで、開始時・一度目・二度目の SHA-256 が一致した。[generation.json](generation.json) に各値を残す。生成元・生成物・bundle を手で変更していない。

通常の check.sh の python は、共通抽出器と try 移行器の自己検査を一時ディレクトリの独立入力で実行する。両者とその helper は、この改造ディレクトリ・archive の manifest を読まない。自己検査内の `docs/archive/old.*` は、一時ディレクトリ内に作る歴史資料の分類の入力である。通常の検査からこの m5 の記録へ新たな参照を追加していない。

旧 named-arguments-migrate の inventory は既存の BASE/n1/joins.json・call-candidates.json・generated-snapshot.json を読む。これは M1 からの既知の依存と欠落（R75）であり、今回の共通部や新移行器の依存と混同しない。旧自己検査の失敗を残件として記録し、通常の検査の成功で代用しない。G7 の確認表は揃えたが、この残件と委任した段末検査を含む G7 の完了判断はオーケストレータが行う。
