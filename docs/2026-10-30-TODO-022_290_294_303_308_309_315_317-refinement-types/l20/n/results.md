# L20 群 N の結果

再開3で、局所の再レビューの中1件・軽3件を処置した。再開2の H04 の第二候補が偽であることを Lean に再現し、実行の最初の失敗の位置を特定する候補へ改めた。B_WORK は `14dc5648d5c8cb866268ecd3f29020d8e43436b9`。主な十言明・型付け規則・ValueMeaning・CoreAssumptions・公理は変更していない。旧 Release、処理系、plan、detail、レビュー記録への変更と、git の状態を変える操作は行っていない。

## 再レビュー（再開3）の処置

| 所見 | 処置と証拠 |
|---|---|
| 中1 | h04-counterexample.lean の OldH04 に旧第二候補を保存し、old_candidate_false で全称の候補を否定した。x=1・y=min64 の neg x + neg y について、EnvRelAt・実際の脱糖の等号・独立評価の overflow・TrackedFailure・実行の失敗を同時に構成する。独立評価は左を正常、右を拒否するが、δ は引数1でだけ err を返し、実行は左で失敗する。現行の FirstFailureHandoff は同じ実行の最初の error を特定し、その位置の pure の δ の拒否を取り出す。revised_candidate_valid が一般の場合を証明し、revised_counterexample_accepted が同じ反例の左の neg と LeftError を構成する。δ と算術の一致は前提に足していない |
| 軽1 | other の Result では一意性ではなく、実行の tag に合う選択の存在と payload の関係を後段が要する、と申し送りを修正した。ValueRel.other からは得られず、L70 が実値から独立評価の値を構成する際に扱う |
| 軽2 | result_arm の docstring を「tag と payload」にした。所有元と実値の型引数を関係が結ぶとは記述しない |
| 軽3 | ValueRel.of_ground を ValueRel.toApprox_eq に改名し、三つの本番の読取り、完全署名、宣言一覧、監査対象、01-12/07-04を更新した。旧名の別名は追加していない。strengthening-blockers.md の旧署名は停止の根拠として残し、現行名と区別した |

補助の Lean は既定 import の外に置いた。BeforeErrorSteps は、選んだ同じ実行の接頭部分がまだ error に入っていないことを持つ。現行の第二候補は、最初に error に入る Step とその後の Steps、事象列の分割を返す。その位置が pure の組み込みなら、同じ実引数・型/効果/範囲引数で δ が返した err を取り出す。純粋な δ の事象は none なので、位置は before の閉包・捕捉・継続・ストアを含めて特定する。独立 trace の同名の演算に置き換えない。

最初の失敗が処理されて後続が実行されることもあるため、最初の理由が最終の理由列に残ることも要求しない。独立評価の第一候補の解析は引き続き H04 の未証明の義務であり、第二候補の実行の分解だけから failed の所属や表層の位置の全体の対応を結論しない。

## 所見ごとの処置

| 所見 | 処置と証拠 |
|---|---|
| 中1 | ValueRel を相互帰納的な ValueRel/ValuesRel にした。Unit・Boolean・七幅の整数は同じ定数、構造値は同じ tag と再帰的な引数列を持つ。rangeError は同じ構成子名と数学上の各整数欄に一致する定数列を持つ。other の観測と非変数性は別の構成子に分けた。result_selection_related は、具体の一引数の Result と既存の対象パターンについて、関係と独立評価の選択から実際の firstAlt と束縛列を得る。connect_result_arm はこれを使い、同じ列に対する子の実行を受ける。result_tag_contrast に Ok/Error・Unit/構造値・入れ子の引数の不一致の拒否と、同じ Ok の候補を選ぶ受理を置いた |
| 中2 | ArmInput の Eval/Selection/Miss は既存の三種類を分ける。connect_arm_skip・connect_arm_guard_true・connect_arm_guard_false は、各種類の既存の独立評価の構成子と実行をともに構成する。independent_arm_guards/independent_arm_skip が Integer・integer8・Result の三種類すべての真・偽・skip に具体に適用する |
| 中3 | Runs の展開だけで閉じる旧の問題は再開2で直したが、その第二候補は再レビューの反例で偽だった。現行の候補と処置は上の再開3の中1を正とする |
| 軽1 | leaves.md に継承/追加の列を置き、validate.py が表から69・7を計算する。76宣言の実在、60行の Step を構成する実物の葉への到達、StateTyE だけを返す16行を照合する。前提の列は実物の WellFormed/WellTyped/CoreAssumptions/EffectsOk/σ.Valid を分け、guard_true の SubstitutionAssumptions は CoreAssumptions.substitutions から供給すると書いた。validate-cases.py で区分一行の変更が68・8になり、欠ける葉・違う構成子・欠ける定義本体を拒否することを確認した |
| 軽2 | Reference.new・op・raise・節のある IO/exit/PathBases の四枝に step の式と Step を結ぶ補題を追加した。FreshStepInputs/step_fresh_selected が四補題を読み、concrete_fresh_operation が同じ適格な表の具体の操作に適用する。解放枠の ret/escape の step も step_release_selected/concrete_release_frames で接続した。selected_primitive_step の oracle は B.selectOracle に統一した |
| 軽3 | signatures.md は関係・選択・ArmInput の定義本体と帰納的な構成子、H04 の二つの完全な命題を含む。validate.py はヘッダーだけでなく定義本体も照合する |
| 軽4 | concrete_other_control_leaves を追加。同じ具体の WellFormed・WellTyped・CoreAssumptions・有効な σ の下で、ErrPopMark と EscHandle に型付きの元状態から適用する。EscMark は従来の concrete_control_leaf も保持する |
| 軽5 | 関数 view の支持の供給元を下表に記した。一般の支持なしの等号や、WF だけから有限の s の支持を得る補題を仮置きしない |
| 軽6 | concrete_interval_control は二つの let と途中 return の五つの実遷移を構成し、同じ終状態に EndState normal Unit と StateTyE を持つ。別の終状態の型付けを並べる形を改めた |
| 軽7 | 与えられた親の実行の分解と、適格な選択肢の下での束縛数の一致を、下の申し送りと h04-handoff.md に記した |

## 内部署名と強い関係の供給

| 変更した署名・定義 | 変更後と実際の供給元・読者 |
|---|---|
| ValueRel/ValuesRel | Unit、Boolean、七幅、構造値、rangeError、other を構成子で分ける。unitRel/integerRel と七幅の例は、独立評価の unit・local・整数の構成子が与える同じ具体値から構成する。Result の構造の関係は同じ payload の unitRel と ValuesRel.cons から構成する |
| ValueRel.toApprox_eq | 強い関係から toApprox の一致を取り出す。近似と Ground を入力に値の関係を作らない。normal_shared_iff と guard の真偽の実値の同定が読む |
| typed_returned_mark | happrox の代わりに同じ c/v の ValueRel を入力にする。unit_escape は独立評価の Unit に対応する unitRel を渡し、元状態から行先の型付けを構成する |
| ValueRel.close と ValuesRel.close | closeVal/closeVals の構造に従って再帰する。公開の close の入力の形は同じで、関係の意味が強くなった。Runs.let_returned/returned_mark は子の EndState が持つ強い関係を取り出して close に渡す。主定理から関係を仮定しない |
| 環境の延長 | EnvRel.extend/extendMany、EnvRelAt.extend/extendMany は同じ引数の形で強い関係を保持する。extendMany の証明を相互帰納的な ValuesRel の構成子への再帰にした。binding_and_return と inserted_scrutinee が実際の子の値と同じ番号の捕捉を供給する |
| normal_shared_iff | 同じ入力の形を保ち、観測を toApprox_eq から取り出す。七幅の integer_values が同じ ConcreteValue.type の一致を供給する |
| connect_result_arm | 具体の Result 構成子と対象パターンの下で、実照合と束縛列を関係から導く。独立に hm/hvs を仮定する入力を外し、得た同じ束縛列に対するコード・子の Runs を branch で受ける。result_arm がその列を同定して子の独立評価の Unit と実行を供給する |
| result_arm、concrete_interval_control | 前者は導いた実照合の束縛列を存在量化する。後者は実行の同じ終状態を存在量化し、関係と型付けをその状態に結ぶ |
| RelationBoundary の反例 | 旧の弱い関係の代わりに近似の一致を明示し、Unit/構造値の強い関係は成立しないことと、旧入力では必要条件すら得られないことを残した。strengthening-blockers.md に旧二署名と反例の記録を保持する |
| selected_primitive_step | 任意の oracle の引数と if を除き、pure/IO/exit が同じ B.selectOracle を使う。具体の二つの呼出しも同じ式で読む |
| H04 の第二候補 | 独立評価の後続の拒否と δ の一致を要求する旧候補を外した。実際の Steps から最初の error の位置とその位置の局所の δ の観測を返す候補にした。使わない EnvRelAt・コードの等号・独立評価の failed はこの実行の候補から外し、解析の候補と区別する |

関数 view の具体の読者 `view_observation_model` は、自由な原子のない Unit の引数・結果・空の効果について、`Ty.support_toTel_iff` と `f.names_wf` から `s=[]` の Support を構成して渡す。一般の L70 の呼出しでは、呼出し側が持つ有限の原子列 s とその支持の証拠を供給する。型・行・範囲の適格性と、特定の有限列への Support は区別し、その供給の担当を L70 とする。支持を必要としない一般版は追加していない。

## 全76遷移と残る場合

[leaves.md](leaves.md) は全76行のソース側の一般の StateTyE と実際の入口を示す。継承69・追加7、重複0。Step と行先の StateTyE を返す60行と、行先の StateTyE だけを返す16行を区別する。行先のコードの型付けを入力にした葉は0。固定 σ/Eb と元の継続・ストアの条件を維持する。代表の match_body_zero・handler_return_const・drop_used_const・resume_const・drop_rel_const・esc_drop_rel_const は既定 import に残すが、一般の葉には数えない。

| 場合 | 判定と後続 |
|---|---|
| 具体の Result と対象パターンの body | 閉じた。関係から同じ firstAlt と再帰的な束縛列を得る |
| 三種類の skip/guardTrue/guardFalse | 閉じた。独立評価と実照合・子の実行の入力から双方の親を構成する。一般の入口はコードや値の一致を勝手に推測せず、呼出し側が同じ選択と実照合を供給する |
| otherOk/otherError の選択と payload | 一意性は要らない。実行の tag に合う選択の存在と、独立値の payload と実値の payload の関係が要る。ValueRel.other の観測と非変数性からは得られない。L70 が実値から独立評価の値を構成するときに扱う。利用者の構文・型付け・ValueMeaning を狭めていない |
| 対象外の Result パターン | result_pattern_related の外側。既存の rangeResultPattern/rangeResultArms の対象範囲を継承する。表層の受理範囲の新しい制限ではない |
| 全 step_sound・進行・保存と逆方向の完全性 | L70。今回の局所補題の入力に主定理を置いていない。逆方向の完全性は追加しない |
| 算術/δ/標準関数の拒否と解析の failed 所属 | H04。解析の候補は未証明。実行の最初の失敗の分解と局所の δ の観測は補助 Lean で証明した。実表・表層の対応と解析の所属の全体合成は未完として h04-handoff.md へ渡す |

| 申し送り | 必要な内容 | 担当・時期 |
|---|---|---|
| 観測した実行の分解 | 親の Steps を子の実行へ分解する。子から親を構成する Runs の補題だけでは失敗所属の向きに足りない | L70、H04 の全体合成の前 |
| 腕の束縛数 | 適格な選択肢の下で firstAlt の結果の長さと Arm.bindersOf を一致させ、upRen ws.length と脱糖の改名をつなぐ | L70、腕の全体合成の前 |
| other の Result | tag に合う選択の存在と payload の関係を、実値から独立評価の値を構成するときに得る | L70、腕の全体合成の前 |
| 一般の関数 view の支持 | 同じ有限の原子列 s と Tel.Support を呼出し側から供給する | L70、関数 view の契約を使う時 |

## 担当義務の判定

| 義務 | 担当分の判定と証拠 | 残る段 |
|---|---|---|
| O003 | 完了。新しい七葉と選択は元状態の局所参照・支持の条件を継承し、新しい欠けを足していない | L70 の表層と全合成 |
| O008 | 完了。escape の値と戻り先の型は元状態から得る。強い関係は同じ実値を受け、捕捉の変数番号を保持する | L40 の開始逆転、L70 |
| O038 | 完了。76葉の対応、同じ σ/Eb の制御七葉、応答・六つの fresh の枝を実行関数へ接続 | L40/L50/L60 の応答、L70 の全保存 |
| O046 | 完了。if/match/guard の一般の葉を対応表で区別し、三種類の guard の真偽・skip と実行を接続 | L30、L40 の算術/length/δ |
| O058 | 完了。元の R・結果注釈・固定 Eb を使い、存在の条件へ Ground/Adequate を追加していない | L40/L50/L60、L70 |
| O090 | 記録完了。束縛/戻り先は G07、算術/δ/所属は H04 とし、重複して加算していない | H04/L70/R10b/R50 |
| O138 | 担当分完了。偽 guard は元環境と捕捉へ戻り、unknown の排除や暗黙の検査を加えない | L30/L40/L70/R10b、再レビュー・受け入れ |
| O169 | 担当分完了。強い関係、三種類の腕、七幅の数値一致、同じ終状態の型付き mark、failed の完全な候補署名を固定した。解析の解析の解析の解析の候補の証明済みとはしない | H04 の算術/δ/所属、L70/R10b/R50 |
| O016 | 公理監査を再実行。既存と新しい宣言・生成された補助定数・使用定義を含め、許可三公理だけ | 独立再レビューと L70 の全合成 |
| O084 | 一般の葉/代表、局所合成/主定理、候補の型検査/証明、自己点検/独立レビューを区別 | 取りまとめの再レビュー、設計者の受け入れ |
| O027 | RSS は本体・計測器とも未取得（部分作業であり計画上の非採取）。-M 12288 を RSS としない | 段末に取りまとめが限定採取 |
| O118 | 新しい Lean コメントは役割・規則・不変条件を説明し、作業IDを残していない | 全 L の共通点検 |

## 宣言・検査・記録

最終の手書き宣言は **174件**（定理120・定義48・帰納的な関係6、private 52）。再開1の130件から44件を追加し、既存の内部署名と証明を上表のとおり変更した。全名と位置は [declarations.md](declarations.md)、入力の大きさと SHA-256 は [inventory.json](inventory.json) に置く。署名は **65,066 bytes** で100 KB以下である。新規6モジュールを全て既定 import に含む。01-12・07-04 の写しは同じ内容へ合わせた。

既定ビルドの外の補助は、h04-handoff.lean の3宣言と h04-counterexample.lean の31宣言である。同じ H04 の3定義は両ファイルで検査し、validate.py が一致を照合する。これらは既定モジュールの174宣言に含めず、declarations.md と inventory.json に別枠で一覧を置く。

公開入口には、一般の合成の読者又は具体の適用例を置いた。四つの fresh の補題は step_fresh_selected、三つの腕の接続は independent_arm_guards/independent_arm_skip、Result の照合の補題は result_arm/result_tag_contrast、解放の実枠は concrete_release_frames が読む。制御の七葉の具体の適用は EscMark・ErrPopMark・EscHandle の三つであり、残る四つに具体例があるとは数えない。

新しい反例の境界は、独立評価が後で拒否する位置と実行が最初に拒否する位置を同一視しないことである。旧候補を否定し、改めた候補と同じ実行の具体例を受理する。既定ビルドの例では候補のこの量化の誤りを検査していないため、依頼どおり補助 Lean で検査する。

既存の対照例の test-audit の境界は、値の構造・tag・引数の不一致、guard の真偽・skip の独立評価と実行の対応、同じ実行の終状態の型付けである。既存の単独の遷移の例では検出しない関係の境界を、既定ビルドの命題で検査する。表の検査は、件数の区分変更と三種類の破損を別の入力で確かめる。処理系のためだけの差し込み口や Rust のテストは追加していない。

| 最終検査 | 終了 | 外側の時間 | 内容 |
|---|---:|---:|---|
| 旧候補の否定・改めた候補の証明 | 0 | 0.778秒 | 独立評価・実脱糖・実行の反例、一般の最初の失敗の分解、同じ例の受理、補助の公理印字 |
| H04 の完全署名 | 0 | 0.613秒 | 第一候補の型検査と第二候補の完全な定義の型検査 |
| 既定 lake build | 0 | 2.015秒 | 858 jobs、対象の削減なし |
| 公理依存 | 0 | 3.705秒 | 既定の11モジュール1,075定数＋208明示対象、補助6対象。許可三公理だけ |
| 署名・表・候補の写し | 0 | 0.135秒 | 76葉・60の Step 構成子・16の状態の葉・定義本体、二つの補助ファイルの同じ候補 |
| 表の検査の対照 | 0 | 0.503秒 | 区分一行の変更で68/8、欠ける葉・違う構成子・欠ける本体を拒否 |
| work の dry-run | 0 | 0.117秒 | 指定基準、--only なし |
| 再開3末の work | 0 | 3.714秒 | 仕様対応の自己検査・集計、仕様例、既定 Lean と sorry の拒否 |

work のコマンドは `scripts/check.sh --level work --base 14dc5648d5c8cb866268ecd3f29020d8e43436b9` とし、--only で絞らない。再開3では作業末に一度実行する。コマンド・終了・時刻・時間・生のログの大きさと SHA-256 は [checks-resume3.json](checks-resume3.json)、監査の集計は [audit-summary-resume3.json](audit-summary-resume3.json) を正とする。公理は propext・Classical.choice・Quot.sound だけで、新しい公理・sorryAx・追加した unsafe/partial は0。既存 ClosureTyping のコンパイラ生成の二つの再帰の定数も印字する。監査対象は audit-modules.txt と audit-declarations.txt、再実行の入口は axioms.lean である。

再開2の監査で firstResultAlt のコンパイラ生成の _unsafe_rec を拒否した。構造的再帰の明示だけでは消えなかったため、同じ計算を既存の List.foldr で定義し、新しい生成の定数をなくした。監査の例外は増やしていない。再開3の補助の型検査では、名前の解決・暗黙引数・帰納の書き方を修正して同じ命題を通した。これらを主な言明や型付け規則の変更で埋めていない。生の中間出力は <tmp> に置き、その一覧の大きさ・SHA-256 を logs-resume3.json に残す。

計画からの変更は、取りまとめが指定した H04 の第二候補の修正と補題名の変更である。H04 の第一候補の解析の証明、L70 の全合成、実行の分解と束縛数の一致は担当境界に残る。新しい公理・独立の信頼条件・利用者の記述の制限は追加していない。再開1の停止と旧署名の反例は strengthening-blockers.md、当時の検査は checks-resume1.json に残す。独立再レビューと受け入れは取りまとめ・設計者の担当であり、今回の自己点検をその代わりに数えない。

再開3の最初の記録した検査は2026-11-02 23:28:24 JST。それ以前の読取りと作成は未採取であり、能動時間と待ちを分離していない。外側の検査時間は上表に記録し、作業時間や RSS に読み替えない。


再開3末の work は終了0、3.714秒。仕様例は7成功・失敗0・無視0。最後の work の後は結果・ハッシュ・検査のメタデータだけを更新した。

## 作業末の work

取りまとめが再開3の後に実行した。

| 項目 | 値 |
|---|---|
| コマンド | `scripts/check.sh --level work --base 14dc5648d5c8cb866268ecd3f29020d8e43436b9` |
| 終了状態 | 0 |
| 外側の時間 | 147.24 秒 |
| 最大常駐量 | 1504198656 バイト |
