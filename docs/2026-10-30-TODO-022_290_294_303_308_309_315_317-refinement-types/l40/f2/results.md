# L40 群 F2 の実装結果

基準 B_WORK: `2719963cf6c41badadbd3589fd150179f34fe075`。指定ブランチ: `m014/l40.f2`。Git の操作は行わない。勧告は共通依頼文の照合を継承し、依存の更新を加えない。RSS は未取得（計画上の非採取）。

基準とブランチは起動依頼の指定値を採用し、担当から実 HEAD とブランチを照合する Git コマンドは実行していない。開始入力は inputs-start-1〜4.json、最終の変更対象は inputs-final.json の SHA-256 で識別する。

## 単位の開始と終了

| 単位 | 開始（UTC） | 終了（UTC） | 判定 |
|---|---|---|---|
| L40.29 | 2026-11-04T02:44:46.983344+00:00 | 2026-11-04T02:49:26.523713+00:00 | 局所 Lean 終了0。正常値・拒否の分離と実δの読者 |
| L40.33 | 2026-11-04T02:49:26.523713+00:00 | 2026-11-04T02:53:41.945500+00:00 | 局所 Lean 終了0。五定義・左右所属・Block14・腕三種各6・実return/枝/腕 |
| L40.34 | 2026-11-04T02:53:41.945500+00:00 | 2026-11-04T02:54:36.355333+00:00 | 局所 Lean 終了0。完全な第二候補・補題・同じneg反例を本番化 |
| L40.35 | 2026-11-04T02:54:36.355333+00:00 | 2026-11-04T02:58:34.008252+00:00 | 局所 Lean 終了0。同じ値の所属・型付きmark・七葉・最初の失敗の読者 |

開始前の依頼文・既存記録の読取りは、この単位の区間の外である。外側の時間と能動時間を区別する。

## 実装前に確認した入口

L40.29 は既存の `integerDelta_binary/negate/floor/absolute/shift` の署名を保ち、`IntKind` と同じ二実値から実応答の正常値（同じ幅の同じ定数との `ValueRel`）又は当該演算の拒否理由を返す補題を加える。失敗理由の6形は `integerOutcome` の既存の写像で照合し、Error の列は実行の葉で一要素へ渡す。独立の正常応答の存在や後続演算を前提にしない。

適用例の関門: 守る契約は評価順と同じ定数・同じ理由の受渡しである。商の overflow を剰余にも適用する変更、又は return の通常成分への混同で例は失敗する。既存の型保存だけではこの一致を検査しない。検査のための本体の差し込み口は追加しない。

## 単位の完了条件の照合

初回の報告前に、detail 第5節と群 F2 の条件を照合した。以下は実装担当の自己点検であり、独立レビュー及び受け入れの判定ではない。

| 単位 | 担当分の判定 | 本番の証拠 |
|---|---|---|
| L40.29 | 完了。全七幅の正常値と当該演算の拒否を分離。後続の演算なし | StandardIntegerFailure の integerChecked_split、binary_checked、neg_checked、divMod_checked、floor_delta_split、signed_minimum_stops、shift_outside と実 δ の読者 |
| L40.33 | 完了。五定義、左右 Mem、局所 ResultMem、実 return・選択枝・腕・Block14 | IntervalFlowLeaves の return_leaf、if_true_leaf/if_false_leaf、block_* 14、arms_*/width_arms_*/result_arms_* 各6、boolean_return、boolean_branches、wildcard_return_arm |
| L40.34 | 完了。完全な現行の第二候補と同じ neg の反例 | FirstFailure の BeforeError、BeforeErrorSteps、FirstFailureHandoff、first_error、pure_failure、first_failure_handoff、old_candidate_false、revised_counterexample_accepted |
| L40.35 | 完了。同じ値の所属を typed_returned_mark と制御七葉へ渡す | IntervalControlLeaves の normal_state_member、escape_*_member 三本、error_*_member 二本、exit_*_typed 二本、boolean_mark、typed_first_failure |

上の新四モジュールを [既定の入口](../../../../formal/Benitoite.lean)へ追加した。公開した全入口には同じ既定ビルド中の読者又は適用例がある。01-12 と 07-04 は本番の実定義と前提に合わせて更新した。五つのフローの定義と BeforeError/BeforeErrorSteps/FirstFailureHandoff のコードは、01-12 に本番と同じ字面で写している。設計書に改造の段名や未実装の作業を書いていない。

## L40.29 の幅と演算

幅は `IntKind` の全7構成子を量化する。Integer は integer64 の別名であり、Byte はこの7種に含めない。表の組合せの数と証明の宣言数は別である。数学上の値は Int のまま扱い、大きな範囲を具体に列挙する評価はしていない。

| 幅 | 加減乗 | 負号 | 通常の商・剰余 | 床商・床剰余 | absolute | shift |
|---|---|---|---|---|---|---|
| Integer8 | 正常又は overflow | 正常又は overflow | 正常・0除算・商の overflow | 同左。床剰余は非零除数なら正常 | 正常又は最小値の overflow | count 0〜7 が正常、域外は拒否 |
| Integer16 | 同上 | 同上 | 同上 | 同上 | 同上 | count 0〜15 が正常、域外は拒否 |
| Integer32 | 同上 | 同上 | 同上 | 同上 | 同上 | count 0〜31 が正常、域外は拒否 |
| Integer / Integer64 | 同上 | 同上 | 同上 | 同上 | 同上 | count 0〜63 が正常、域外は拒否 |
| UnsignedInteger16 | 正常又は overflow | API なし | 正常又は0除算。剰余は商の検査に依存しない | 正常又は0除算 | 元の同じ値 | count 0〜15 が正常、域外は拒否 |
| UnsignedInteger32 | 同上 | API なし | 同上 | 同上 | 元の同じ値 | count 0〜31 が正常、域外は拒否 |
| UnsignedInteger64 | 同上 | API なし | 同上 | 同上 | 元の同じ値 | count 0〜63 が正常、域外は拒否 |

加減乗の21組と符号付き負号の4組は、実 OperationResult が同じ数学値の `integerChecked` であることから分ける。正常枝では同じ幅の同じ定数との `ValueRel` を返し、overflow 枝ではその数学値が域外であることを返す。名前付き δ は、群 D の integerDelta_binary/negate を使う。通常の intDiv/mod の14組は、実 checkedDivMod に接続する。mod は非零の除数なら必ず正常であり、商の overflow を剰余へ伝えない。

床演算の14組は、群 E の `StandardIntegerAPI.floorNumber` と群 D の integerDelta_floor を使う。符号付き四幅の最小値÷−1では、床商と通常の商は IntegerOverflow、床剰余は正常な0である。`floorModulo_normal` は全七幅・任意の非零の除数で正常値の表現可能性を証明する。absolute は7種で正常値又は overflow に分け、符号付き最小値では停止し、unsigned では元の値を保つ。shiftLeft/shiftRight は全7種、shiftRightUnsigned は符号付き4種にある。域外 count の拒否はビット値の計算前の分岐であり、正常枝も同じ幅の表現可能な値を返す。既存の integerDelta_shift の署名と可用性の条件は変更していない。

`Failure` の6形は `integerOutcome_rejected` で payload も量化して既存の整数応答へ写す。overflow は IntegerOverflow、zeroDivisor は DivisionByZero、unknown/outsideDomain/invalidBounds/outOfRange は ArgumentOutOfDomain である。これは整数応答の写像の性質であり、Range の Result.Error を failed に変える規則ではない。算術の追跡対象では unknown を除く F1 の条件を保つ。ErrKind、区間の Failure、篩の proof-steps の停止を同じ型にしない。

## F07 の局所規則と実際の読者

joinV/normalF/returnF/seqF/joinF は、群 A の固定した定義の形と一致する。joinV は bottom を単位、同幅整数を区間包、Boolean を二フラグの論理和、異種を unknown とする。joinV_left/right、return_mem、join_left/right、seq_tail、seq_abrupt は、この実定義の所属を証明する。normal_mem_of_related と returned_mem_of_related は ValueRel.toApprox_eq による二系であり、それだけを .33 の実質として数えていない。

return_leaf は子の EvalPartial とその観測結果の ResultMem から、実 return の EvalPartial と returnF の所属を作る。if_true_leaf/if_false_leaf は実際の条件と選んだ同じ本体を受ける。Block の読者14本は EvalBlock の14構成子に一対一であり、正常な bind では同じ具体値を前置した環境の tail を使う。bindPat は同じ PatternLocals の束縛列を使う。head が returned/failed の各 abrupt では tail の導出を受けない。末尾の bind/discard/pattern は正常値だけを Unit にし、異常終了を伝播する。

整数・幅付き整数・Result の腕はそれぞれ6構成子を扱う。body/guardTrue は選択した本体、skip/guardFalse は元環境の残り、guardAbrupt は同じ異常終了を使う。Result の tag/payload の全体の構成、親の実行から子への分解、腕の束縛数の表層からの供給は結論に加えていない。boolean_branches は真の枝の returned true と偽の枝の normal false を実際に構成し、normal true/returned false の誤った所属をともに否定する。wildcard_return_arm は同じ選択の腕の本体から returned を作る。

これらの腕・Block の局所規則は独立評価の導出を対象とする。型付けの側は現在の LeafInputs と既存の保存葉を使い、群 E の欄の等号を含む HasTypeArmsQ.plain/guarded を変えていない。型付けの規則を、旧の前提の形で複製した読者はない。

## 最初の失敗の受渡し

FirstFailure は、前段の [受渡し](../../l20/n/h04-handoff.lean) の完全な BeforeError/BeforeErrorSteps/FirstFailureHandoff を本番へ置く。first_error は同じ有限実行の最初の error の位置を返す。pure_failure はその位置が pure の実呼出しである場合だけ、事象 none、一要素の理由列、同じ型・行の正規化と範囲・実引数の δ の err を返す。最初の error の後の suffix は、理由列・継続・ストアが変わり得る元の Steps として返す。

neg の同じ反例では、独立評価は左の neg を正常とし、右の neg を overflow とする。一方、実 δ は左で LeftError を返し、実行は右に進まない。old_candidate_false は後の拒否に実 δ の一致を求める全称命題を否定し、revised_counterexample_accepted は左の最初の位置と suffix を受け取る。FirstFailureHandoff は型付け、解析との一致、独立の信頼条件を前提にしない。typed_first_failure は、同じ型付きの開始の Inputs とこの受渡しを組み合わせる。

## 第一候補・第二候補・合成の残り

| 系列 | 本群での判定と証拠 | 後の担当 |
|---|---|---|
| 第一候補：解析の failed | 群 F1 を継承。IntervalFailure.tracked_failure_sound は Models・同じ EvalPartial failed・TrackedFailure から同じ analyze の mayFail=true を証明する。全109場合、任意 Parameters、停止/未対応の baseUnknown を保つ | 証明の再実装なし。群 A/F1 の results と RV-L40.a を引用 |
| 第二候補：実行の最初の失敗 | 本群で本番化。FirstFailure.first_failure_handoff と typed_first_failure、同じ neg の反例の受理 | 群 G の照合・独立レビューへ渡す |
| 正常・returned の局所所属 | 本群で完了。五定義、実 return/枝/腕/Block と同じ値、typed_returned_mark と制御七葉 | 全表層と各本体の実解析出力から returned を供給する合成は L70 |
| 最初の失敗と整数の理由 | 最初の失敗の位置の δ を `integerDelta` の具体の理由へ結ぶ接続は未実施 | L70 |
| 全体の合成 | 本群で閉じない。BudgetAnalyze.Report.sharedFlow の returned が呼出し側の引数であることを保持 | L70：親実行の分解、other Result、束縛数、実表層・本体の所有、主定理。R10b/R50：実装・交換 |

G07 の既済みと H04 の担当分を重複加算しない。局所の δ と算術の一致から、任意の B の δ と解析が無条件に一致するという結論へ進めていない。全体系の主定理、Rust/Lean の全比較、受け入れを本群の完了へ含めない。

## 宣言と検査

宣言の表と宣言一覧・公理監査の詳細は再開1の群末一回分へ置き換えた。以下の検査の表と初回の実行時刻は初回の履歴であり、再開1の検査は末尾の節に記す。

| 新モジュール | 手書き公開 | 手書き private | その他の生成宣言 | 環境の全宣言 | 匿名の適用例 |
|---|---:|---:|---:|---:|---:|
| StandardIntegerFailure | 20 | 4 | 49 | 73 | 14 |
| IntervalFlowLeaves | 73 | 9 | 31 | 113 | 43 |
| FirstFailure | 9 | 22 | 39 | 70 | 3 |
| IntervalControlLeaves | 10 | 1 | 0 | 11 | 9 |
| 合計 | 112 | 36 | 119 | 267 | 69 |

全名は [source-declarations.json](source-declarations.json) と群末一回分の `declarations-*-part-*.json` にある。匿名例は環境宣言に加算しない。監査対象一覧は [axioms.lean](axioms.lean) が既定 import の環境から作り直し、印字時に実体化する宣言が尽きるまで2周して得る。[audit.py](audit.py) は対象と #print axioms の一対一と依存を照合する。再生成は `python3 <改造>/l40/f2/audit.py --tmp <tmp>/audit` であり、Lean は formal/ から固定版の `lake env lean -M 12288` で起動する。宣言名を保存するモジュールは今回の4本だけである。

| 検査 | 結果と内容 | 外側の時間 |
|---|---|---:|
| 単独 Lean | 各単位の末尾は終了0。実定義と読者を -M 12288 で検査 | 各コマンドは checks.json |
| 既定ビルド | formal/ から対象・オプションなしの lake build。終了0、1252 jobs | 最終1.661秒 |
| 公理監査 | 全991モジュール・78,752宣言、今回218宣言。新公理0、依存は propext/Quot.sound/Classical.choice の部分集合のみ | 24.529秒 |
| work の選択確認 | 指定 B_WORK、--only なし。spec_tally・spec_examples・formal_build | 0.168秒 |
| 作業末の work | 一度だけ実行して終了0。仕様対応の自己検査と集計、仕様例7成功・失敗0・無視0、既定全 Lean と sorry 拒否 | 11.160秒 |
| 記録の照合 | verify.py 終了0。新4モジュールの既定 import、既存997本の Lean ソースの不変、Block14・腕18、64義務、監査の同じ入力と全宣言を照合 | 初回は別計測なし |

既定ビルドは増分であり、clean build とは呼ばない。初回の既定ビルドは新しいモジュールの olean を作るための単位途中の確認で1.799秒、最終は追加した制御の読者を含む確認である。work 入口の呼出しは群末の一回だけとする。work の中でも同じ既定ビルドが実行される。

群末の全公理監査の生出力と全対象一覧の大きさ・SHA-256 は、再開1の結果で置き換えた [audit-summary.json](audit-summary.json) を正とする。生出力は `<tmp>/benitoite-l40-f2/` に置き、改造に大きなログを保存しない。コマンド・実測の開始/終了・本体終了・外側秒・bytes/SHA-256 は [checks.json](checks.json) と [audit-summary.json](audit-summary.json) を正とする。RSS は未取得（計画上の非採取）であり、別の測定や近似値は追加していない。

work は `scripts/check.sh --level work --base 2719963cf6c41badadbd3589fd150179f34fe075` を一度実行した。開始03:04:54.455831 UTC、終了03:05:05.616191 UTC、終了状態0。生出力5,847バイト、SHA-256 `2f5a923781d224c2b53eb12005b1d81d706d2c38096ebde91adff40863d3d71a`。全比較・Rust 全 lib・clippy・性能測定は今回の選択に加えていない。初回報告の時点では、本番の Lean と二つの設計書に、この検査の後の変更はなかった。再開1の変更後の検査は末尾に記す。

verify.py は開始入力全件と最終ソースを比較し、既存の形式化の変更が既定 import の追加だけであることを確かめる。旧 Release、Typing、主な十言明のソースもこの比較に含まれる。台本は今回の4モジュールすべてが推移的な既定 import に入ることと、公理監査の全対象の存在も照合する。最終の入力・件数・記録サイズは [verification.json](verification.json) に保存する。各ファイル100,000バイト以下、群全体は約0.32 MBであり、宣言一覧の写しは群末の一回分だけである。

## 計画との差と時間

| 項目 | 差と判断 |
|---|---|
| 署名・型付け・主定理・信頼条件 | 前の群で固定した署名の変更0。主な十言明・型付け規則・既存の OperationResult/δ の定義・公理・提供範囲の変更0 |
| 内部の配置 | 数値の局所意味を StandardIntegerFailure、制御の型付き読者を IntervalControlLeaves に分けた。既存の共有モジュールを編集せず上層へ追加した |
| 使わない前提 | 新規の error/exit の四読者は元状態だけで保存できるため、最終自己点検で hP/hPB/hB を除いた。前の群の署名は変更していない |
| 時刻の訂正 | L40.33 の最終具体例の誤りを記録の追記時に見落とし、一度終了欄へ書いたが直ちに実施中へ戻し、修正後の局所終了0の時点で閉じた。L40.35 は02:57:52の後に error/exit の不要な前提を除く自己点検を加え、最後の局所検査の02:58:34へ終了を更新した |
| 局所検査の失敗 | run.py の引数位置一件、依存 olean がまだない単独検査一件、Lean の補助証明・型推論・末尾の簡約の誤りを修正した。生出力の識別は checks.json。最終の四単位・既定ビルド・全監査は成功 |
| 操作と保護したファイル | Git の操作、plan/detail/README/レビュー記録/群 A〜E の記録、処理系、既存の Release の変更0 |

単位の開始はその場で、終了は局所検査を終えた時点で記録した。最初の単位の開始前の読取りと、単位終了後の設計書・記録・監査・work は下の区間の外である。外側の時間から能動時間を確定しない。未経験の群へ一律の比で外挿せず、計画の見込みと4時間・9時間の相談条件を変更しない。

| 単位 | 開始から終了までの外側の時間 |
|---|---:|
| L40.29 | 279.540秒（約4分40秒） |
| L40.33 | 255.422秒（約4分15秒） |
| L40.34 | 54.410秒 |
| L40.35 | 237.653秒（約3分58秒） |
| 四単位の区間合計 | 827.025秒（約13分47秒）。読取り・群末の作業を含む全所要ではない |

担当義務は [obligations.md](obligations.md) で64行を保持し、F2の12行を一行ずつ判定した。全体の義務を今回閉鎖した行は0。取りまとめに新しい仕様変更の判断を求める停止事項はない。今回の定義・言明・前提と読者の独立レビュー、群 G の全体照合、設計者の受け入れを依頼する。

## 再開1

開始（UTC）: 2026-11-04T03:19:33+00:00。終了（UTC）: 2026-11-04T03:29:58.665748+00:00。RV-L40.f2 の中1・軽1〜4・情報1だけを処置する。前の群の署名・主な十言明・型付け・既存 δ・公理を保つ。


| 所見 | 処置 |
|---|---|
| 中1 | 分岐の残り7構成子、式の block、matchInteger/matchWidth/matchResult/matchAbrupt の12入口を追加。join_left/right・seq_tail・seq_abrupt で同じ結果の所属を得る。ifOnlyFalse の通常の Unit は normalF .unknown で受ける。01-12・07-04 は分岐9構成子と扱う match の名前に合わせた |
| 軽1 | error_let_member/error_mark_member の reason・FlowApprox・所属の前提と結論を除き、元の StateTyE から Step と同じ理由列での型付けの保存だけを返す。写しも所属を保存の根拠としない形に修正 |
| 軽2 | 正常な bind、guard の真偽、Integer8 と既知の Result.Ok の腕の body に具体の読者を追加。中1の12入口にも具体の読者を置き、通常成分と returned 成分又は異なる Boolean の誤った所属を否定 |
| 軽3 | binary_delta_split の overflow に同じ数学値の値域外条件を保持。divMod_delta_split は Bool で結論を分け、剰余では0除算又は正常値だけ、商では値域外条件付きの overflow を含む。division_overflow_iff で非零除数の通常の商が overflow する条件と符号付き最小値÷−1の同値を証明 |
| 軽4 | 01-12 は integerFailure が整数応答の写像であり、Range の Result.Error を扱わないと明記 |
| 情報1 | 後段への受渡しの表に、最初の失敗の位置の δ と integerDelta の具体の理由を結ぶのは L70 と一行追加 |
| 情報2・3 | 指定どおり処置なし |

| 追加した入口 | 具体の読者 |
|---|---|
| if_abrupt_leaf、else_if_abrupt_leaf、if_only_abrupt_leaf、match_abrupt_leaf | abrupt_conditions：条件・照合値の return を同じ returned true で伝播。通常成分又は returned false の誤った所属を否定 |
| else_if_true_leaf、else_if_false_leaf | boolean_else_if：真の本体は returned true、偽の後続式は normal false。逆の二所属を否定 |
| if_only_true_leaf、if_only_false_leaf | unit_if_only：空本体の真と偽はともに通常の Unit。returned Unit を否定 |
| expression_block_leaf | bound_boolean_return：head の true を実際に束縛し、tail の local 0 から return、式の block へ上げる。normal true と returned false を否定 |
| match_integer_leaf | integer_match_return：整数1の wildcard の腕から returned true を式の match へ上げ、normal true と returned false を否定 |
| match_width_leaf | width_match_return：Integer8 の1の腕の body から同じ接続と否定 |
| match_result_leaf | result_match_return：標準表で認識する既知の Result.Ok の腕の body から同じ接続と否定 |
| 既存の arms_guardTrue/arms_guardFalse | guarded_boolean_branches：真は本体の returned true、偽は次の腕の normal false。逆の二所属を否定 |

matchOtherNormal/matchOtherFailed は L70 に残す。両構成子は `rangeResultMatch = none` の other Result を扱い、選択した腕の導出を前提に持たない。matchOtherNormal は型だけが一致する任意の通常値を結果に取り得るため、腕の所属から join/seq の局所規則だけで同じ値の所属を得られない。matchOtherFailed も腕の mayFail の供給がなく、other Result と実解析の結果の接続を要する。今回指定された12構成子で追加を見送ったものはない。

適用例の作成時の関門は test-audit に従った。守る契約は同じ評価結果と二成分の区別であり、束縛した値の取り違え・guard の分岐先の取り違え・腕の returned を normal へ混ぜる退行で否定の結論が成立しなくなる。従来の変数のままの例と型保存だけではこの接続を確かめていなかった。既存の評価関係と公開入口を用い、検査専用の差し込み口は追加していない。

前の群で固定した署名は変えない。本群で追加した補題のうち、レビューが指定した binary_delta_split・divMod_delta_split の結論、error 二補題の不要な所属の前提・結論だけを修正した。named_binary_split の従来の弱い結論は、強めた binary_delta_split から And.left で従来どおり使える。主な十言明・型付け・既存の δ・公理の変更はない。


再開1の群末の検査（各一度）:

| 検査 | 結果と内容 | 外側の時間 |
|---|---|---:|
| 既定の lake build | 終了0。formal/ から対象指定なし。1252 jobs。新しい読者を既定 import 内で検査 | 2.346秒 |
| 公理監査 | 終了0。991モジュール・78,801宣言。今回4モジュールの267宣言を含み、private・生成宣言も対象。新公理0、依存は propext/Quot.sound/Classical.choice の部分集合だけ | 25.290秒 |
| work の選択確認 | 終了0。指定基準の --dry-run。spec_tally・spec_examples・formal_build | 0.118秒 |
| 指定基準の work | 終了0。この再開で一度だけ、--only なし。仕様対応の自己検査・集計、仕様例7成功/失敗0/無視0、既定 Lean ビルドと sorry 拒否 | 3.862秒 |

work の開始は 2026-11-04T03:29:02.555203+00:00、終了は 2026-11-04T03:29:06.417125+00:00。コマンドは `scripts/check.sh --level work --base 2719963cf6c41badadbd3589fd150179f34fe075`。生出力は 5847バイト、SHA-256 `a19cd4db85e0b4aa28aac028ab902a286acc04e18d330496c3c362cf81662f5b`。初回と再開1は checks.json のラベルで区別し、同じ再開での重複実行はない。

公理監査の生出力は 14541756バイト、SHA-256 `3166f926cb15653eb16251ae5a2e5c679c3f5ef31fd2747a4654c31e5eb2114a`。全対象一覧は 5144268バイト、SHA-256 `5a1acc56ee8cf22376623a1bbb2cc57e6b46cd84346fc0e02aa6331852bd3231`。宣言の記録と監査の詳細は群末の今回一回分へ置き換え、全量の写しを重ねていない。生出力は一時領域に置き、記録は bytes/SHA-256 だけを保持する。RSS は未取得（計画上の非採取）。

局所確認では、Unit の EvalOutcome の型注釈、整数リテラルの有界な表現、Range の record の payload、core Lean の補題名と String の不一致の処理を修正した。根から Lean を起動して対象が見つからない呼出しも一件あり、formal/ から固定版と -M 12288 を指定して確認した。最終の単独検査三本と群末の既定ビルドは終了0。固定済みの定義を変える必要や停止条件は生じていない。

記録照合（verify-r1）は終了0、0.167秒。新4モジュールの既定 import、既存997本の Lean ソースの不変、Block14・腕18、担当義務64行、監査の最終入力・全267宣言、初回と再開1それぞれ一回の work を照合した。各ファイル100,000バイト以下、全体は約0.33 MB。

再開1の外側の所要時間は 625.666秒（約10分25秒）。能動時間と待ち時間は分離していない。残件は上記の L70 の範囲であり、今回の指定所見に未処置はない。取り込み・独立再レビュー・受け入れは取りまとめへ渡す。Git の操作と保護対象の編集は行っていない。

## 再開2

開始: 2026-11-04 03:33:22 UTC。終了: 2026-11-04 03:36:35.178050 UTC。再レビュー（再開1）の再軽1・再軽2を処置する。再情報1〜3は指定どおり処置しない。基準は `2719963cf6c41badadbd3589fd150179f34fe075`。

| 所見 | 判定と処置 | 証拠 |
|---|---|---|
| 再軽1 | 完了。ite・elseIf の真偽4入口は `seqF h (joinF f g)`、ifOnly の真偽2入口は `seqF h (joinF f (normalF .unknown))` を結論する。既存の join_left/right の結果に seq_tail を一段適用した。異常終了の入口と条件のフローを含めた形が一致する | IntervalFlowLeaves の if_true_leaf/if_false_leaf・else_if_true_leaf/else_if_false_leaf・if_only_true_leaf/if_only_false_leaf、01-12 と 07-04 の対応する写し |
| 再軽2 | 完了。error_let_member・error_mark_member を error_let_typed・error_mark_typed へ改名し、具体の適用例と宣言の一覧を追随した。写しにも現在の補題名を明記した | IntervalControlLeaves の2入口と既存の適用例、01-12・07-04 |
| 再情報1〜3 | 指定どおり処置なし | 再レビュー（再開1）の結論 |

真偽の6入口はすべて揃えた。match の既存の入口は `seqF h f` のままである。この件で L70 に追加の橋を残さない。前の群の署名・主な十言明・型付けの規則・既存の δ・公理は変えない。今回の群内の6入口の結論と暗黙の h、および error の2補題名の変更は再開2の明示の指定による。

boolean_branches・boolean_else_if・unit_if_only は条件のフローを `normalF (.boolean true true)` とし、更新した6入口を直接使う。test-audit の作成時の関門に従い、既存の具体の読者だけを更新した。守る契約は同じ評価結果の所属と通常/returned の区別であり、枝又は成分の取り違えがあれば既存の否定の結論が成立しない。入口のフローが変わったため適用先を追随する必要があり、同じ契約の検査や検査専用の差し込み口は追加しない。Lean の宣言数の増減はない。

検査ラッパーの最初の呼出しでは --formal の位置を誤り、子プロセスの起動前に FileNotFoundError となった。Lean は起動されず、checks.json への記録もない。引数順を修正して以下の群末の検査を行った。

再開2の群末の検査（各一度）:

| 検査 | 結果と内容 | 外側の時間 |
|---|---|---:|
| 既定の lake build | 終了0。formal/ から対象指定なし。1252 jobs。変更した6入口・具体の読者・error の2葉を既定 import 内で検査 | 1.904秒 |
| work の選択確認 | 終了0。指定基準の --dry-run。spec_tally・spec_examples・formal_build | 0.118秒 |
| 指定基準の work | 終了0。この再開で一度だけ、--only なし。仕様対応の自己検査・集計、仕様例7成功/失敗0/無視0、既定 Lean ビルドと sorry 拒否 | 3.868秒 |
| 記録の照合 | 終了0。新4モジュールの既定 import、既存997本の Lean ソースの不変、Block14・腕18、担当義務64行、最終監査入力と全267宣言、初回・再開1・再開2それぞれ一回の work を照合 | 0.171秒 |
| 公理監査 | 終了0。991モジュール・78,801宣言。今回4モジュールの267宣言を含み、private・生成宣言も対象。新公理0、依存は propext/Quot.sound/Classical.choice の部分集合だけ | 24.579秒 |

work のコマンドは `scripts/check.sh --level work --base 2719963cf6c41badadbd3589fd150179f34fe075`。開始は 2026-11-04T03:35:51.501325+00:00、終了は 2026-11-04T03:35:55.369108+00:00。

既定ビルドの生出力は 45694バイト、SHA-256 `64f8170f2f239c8dc3feae6dc374a4e8c222c45d5254372dd5ee6e45c3b37d95`。

公理監査の生出力は 14541750バイト、SHA-256 `550ff17a0cac74fa335b57dc2b583739e02bc129b68388fd49328abc678a97b2`。

workの生出力は 5847バイト、SHA-256 `5d1a8bb64781e02782ce6c00888712915c2fdd6a8681e371c68e1e477e7444e8`。

verifyの生出力は 579バイト、SHA-256 `800568a161255e19da82bf1c5abad2369dce6462da7348ee16b5178b616c50ca`。

公理監査の全対象一覧は 5144266バイト、SHA-256 `3155dd9dcb642cc1ce1b2ba377ac9586e44c1c95bebf14f69e0639f6874f0014`。宣言と監査の記録は再開2の群末の一回分へ置き換えた。過去の全量の写しは増やさず、生出力は一時領域に置いて bytes/SHA-256 だけを保持する。各検査のコマンドと時刻は checks.json、公理監査は audit-execution.json と audit-summary.json、最終入力の照合は inputs-final.json と verification.json に記録した。RSS は未取得（計画上の非採取）。

再開2の外側の所要時間は 193.178秒。能動時間と待ち時間は分離していない。指定所見の未処置はない。Git の操作と保護対象の編集は行っていない。独立再レビューと受け入れは取りまとめへ渡す。

## 群 F2 の作業末の work の検査（取りまとめ）

- 基準: `2719963cf6c41badadbd3589fd150179f34fe075`。作業木は再開2の後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 2719963cf6c41badadbd3589fd150179f34fe075`。選ばれた単位は spec_tally・spec_examples・formal_build。
- 結果: 終了0。外側 420.51秒、最大常駐量 2,939,404,288 バイト。仕様例7件が通り、形式化のビルドに sorry はない。
