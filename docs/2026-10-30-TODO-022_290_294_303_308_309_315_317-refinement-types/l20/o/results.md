# L20 群 O・P の結果

L20.123〜.134 を実装した。基準 B_WORK は `428ed95f768f41d63cbc3353e2b21fca0bb88e42`、指定のブランチは `m014/l20.o` である。ブランチの切替・作成・コミットを含め、直接の git 操作はしていない。検査の入口は指定の基準で差分を分類する。主な十言明、型付けの規則、ValueMeaning、CoreAssumptions、旧 Release は変更していない。plan・detail・レビュー記録と Rust の処理系にも変更を加えていない。

## 完了した単位

| 単位 | 判定 | 実装と確認 |
|---|---|---|
| L20.123 | 完了 | LegacyJudgment.Embedded の七結論を任意の Φ で定義し、LegacyOutputInput.induct_regular で親の規則・形成、全子の入力・帰納仮説を渡す。既存 LegacyRule の全46規則を同じ入口で扱う。親子それぞれの kind/値の深さは各 LegacyNodeRegular/LegacyNodeContext/LegacyNodeTypes の実物から読む。定数の全導出に embed_constants でこの帰納を適用した |
| L20.124 | 完了 | legacy_local_shift/local_zero は空と非空の旧 L を扱い、ValueAssumptions を要求しない。local_let と local_arm が n=1・L=[] へ適用し、nonempty_local_bound が拡張2の参照位置2を保持する |
| L20.125 | 完了 | embedPatTy/embedPatTys/embedAltsTy は構成子表から同じパターンと束縛型の像を構成する。LegacyNodeContext.bindings は子の binds δ ++ Γ から任意 nv の LegacyNodeTypes δ を構成する。bindings_from_child と nested_pattern/nested_alts が適用する |
| L20.126 | 完了 | legacyPatternVal と相互再帰の legacy_matchVal/legacy_matchList が全パターンの照合結果と束縛列を対応させる。legacy_inhabits/All/Each が範囲の深さ0の全新 Inhabits から旧の所属を構成し、List/data の各子へ下降する。checkedAt_in_list が任意の範囲・保持対象の入れ子の具体例となる |
| L20.127 | 完了 | atError を Scope.ScopeError.At と同じ七文字列に写す。at_shape が同時に満たせる具体のプログラムと組み込み表から StandardError を構成する。at_legacy_inhabits、at_pattern_typed、at_seven_bindings、at_old_correspondence が型・型引数0個・束縛列を照合し、異なる名前・欄数・型引数数を拒否する。nested_at_correspondence も既定ビルドに置く |
| L20.128 | 完了 | embedExhaustive は LegacyTables と旧型の a.WF 0 nt と旧 Exhaustive から同じ ps の新 Exhaustive を構成する。list_coverage が適用する。無条件の含意の反例と入力の拒否も既定ビルドに置く |
| L20.129 | 完了 | V_Var/V_Const/V_Bytes の3枝。表現可能性は親の入力から供給する |
| L20.130 | 完了 | V_Fun/V_Prim/V_Op の3枝。宣言の kind、型/行の像、署名の依存列を具体化し、正規化等号と convert で旧 fn の像へ戻す。非空の範囲/行引数を禁止する前提は追加していない |
| L20.131 | 完了 | V_Lam の1枝。子の任意 Φ の結論を liftMany へ特殊化し、hideConts/bindParams/hideBuilders と名前・arity を合わせる |
| L20.132 | 完了 | V_Con/V_List/V_Map/V_Set/V_Dict の5枝。子の型付け、宣言の型引数、欄、SatAll、正規化鍵の制約を旧の局所前提と表から供給する |
| L20.133 | 完了 | V_LocRef/V_LocLazy/V_Checked/V_CheckedRequest/V_Raise の5枝。同じ場所・対象・要求・端点を使う。保持要求の子の Φ は空へ直接特殊化する |
| L20.134 | 完了 | V_Super/V_Sub の2枝。embedLe と結果の Annotation を使い、LegacyRule.embed_value で値19枝を一つに合成する。unit_from_value_rule が具体の表で適用する |

値19枝は、各規則の子に対する帰納仮説から親の新しい型付けを再構成する補題である。七判断の全導出を閉じた定理ではない。残27規則（Vs/Each 4、CQ 17、Arms 3、Clauses 2、Failure 1）は L20.135〜.143 の担当、状態と三親判断は L20.144〜.148 の担当に残る。定数の構文については V_Sub を含めた全導出の埋め込みを LegacyOutputInput.embed_constants で証明した。一般の embedHasTypeVQ など七契約の証明や、embedStep、一般の実行の模倣を済みとは数えない。

## 署名と前提

七つの契約と帰納の骨格を実装前に [signatures.md](signatures.md) に固定した。各単位の署名は実装と並行して記録し、最後に型検査の出力へ揃えた。値の補題を100 KB未満に保つため [value-signatures.md](value-signatures.md) に分けた。最終の完全署名は [signatures-o.lean](signatures-o.lean) と [signatures-p.lean](signatures-p.lean) の型検査の出力に一致する。七つの全埋め込みの契約は [contracts.lean](contracts.lean) の Prop として別に型検査し、証明済みの定理と区別している。七結論の本体は [LegacyTyping.lean](../../../../formal/Benitoite/Release/Refinement/LegacyTyping.lean) にある。

| 入口 | 前提と結論 |
|---|---|
| LegacyJudgment.Embedded K P0 B j | j の七形それぞれについて、旧 C と同じ kind 列 κ を使う legacyTypeCtx C κ、旧 Ψ/Γ/R/L/項/結果の像と任意 Φ の新判断を述べる |
| LegacyOutputInput.induct_regular | 既存の node 入力と、親の LegacyRule/LegacyNodeRegular・全子の入力・全子の M を受ける step から M を得る。M を Embedded とする骨格を保つ |
| LegacyRule.embed_value | K.WF P0、LegacyTables K P0 B0 B、値の LegacyRule、親の LegacyNodeRegular、全子の Embedded → 同じ値の親の Embedded。独立の新しい信頼条件はない |
| 表現可能性と対象保持 | LegacyNodeRegular の既存の構文/保持型/型入力を使う。定数・bytes、署名、kind と型引数、同じ場所/対象/要求/端点の検査を、型付けや ValueMeaning の独立入力に置き換えない |
| embedPatTy/embedPatTys/embedAltsTy | LegacyTables と旧パターン判断 → 同じパターンの新判断と束縛型列の像。不要な K.WF・κ/C/nv・LegacyNodeTypes は要求しない |
| legacy_matchVal/legacy_matchList | 全パターンと全新値に対し、旧照合の結果 = 新照合の結果に旧の構造の写しを map した列。値が embedVal の像である等号を要求しない |
| legacy_inhabits/All/Each | LegacyTables、新 Inhabits（又は列）、旧型の像との等号、旧 WF 0 nt → legacyPatternVal による旧 Inhabits。構成子の欄の形成は表から取り出す |
| embedExhaustive | LegacyTables、旧型の a.WF 0 nt、旧 Exhaustive P0 a ps → 新 Exhaustive (embedProgramWithKinds K P0) (embedTy a) ps |
| legacy_local_zero | 旧 LocalCtx.extend n L の像の下での新 HasTypeCQ → 新 localExtend n (L.map ...) の下での同じ HasTypeCQ。P/B/Ψ/Q/C/Γ/Φ/R/項/型/効果は同じで、ValueAssumptions は不要 |

legacyPatternVal は照合が読む構造を保つための関数である。checkedAt と checkedRequest は同じ対象の旧 checked、atError は七文字列の At、構成子と List は子を再帰的に写す。Float64 は旧の `.float 0` に写し、Float32 のビット列は保持する。その他の内部を照合が読まない値には旧 fnRef の値を使う。型付けや遷移を保存する逆写像とは呼ばない。値の型付けは新しい HasType の構成子で証明し、意味の包含で代用していない。

## 網羅性と受理・拒否の対照

| 対照 | 受理の証拠 | 拒否の証拠 |
|---|---|---|
| 範囲の深さ0 | list_input と list_coverage。fixed top の opaque の List は、任意の checkedAt を含む値も同じ allList で照合に成功する | rangeOpaque = opaque o (rvar 0) は旧の空パターン列が網羅的だが、新しい checkedAt が属して空列は網羅的でない。old_range_exhaustive/new_range_not_exhaustive と range_input_rejected を同じ既定 import に置く |
| 標準 At | 具体の oldProgram/kinds/oldBuiltins/builtins と tables を同時に構成し、at_shape・at_legacy_inhabits・型引数0個・七文字列の束縛を証明する | at_wrong_name は Other、at_wrong_arity は6欄、at_type_argument_rejected は余分な型引数1個を拒否する |
| 局所文脈 | local_let/local_arm で空の旧局所文脈の拡張を使う | 非空の文脈では拡張2の後の bound 2 が同じ string builder を参照する。非空の文脈を空として扱ってはいない |

元の無条件の網羅性の反例 [rv-f-t2.lean](../../l10/f/rv-f-t2.lean) も変更していない。公開した補題の読者と具体の適用例は全て既定 import に含める。検査例は、新旧の判断の接続、At の形の不一致、範囲の閉性の必要性を確かめるために置いた。処理系の Rust テストは追加・変更していない。

## 値19規則の本番追随の記録

時刻は2026-11-03 JST、clock.curr_time で各規則の前後を採取した。規則の作成・関連する補助の作成・局所の Lean 検査と再試行を含む外側の時間 E である。測定のためだけの実装はしていない。生の時刻の転記は [rule-times.json](rule-times.json) にも置く。

| 旧規則 | 開始 JST | 終了 JST | 外側の時間 E | 本番の宣言（LegacyValueCases 内） |
|---|---|---|---:|---|
| V_Var | 00:17:50 | 00:18:26 | 36秒 | `var_case` |
| V_Const | 00:18:26 | 00:18:38 | 12秒 | `const_case` |
| V_Bytes | 00:18:38 | 00:18:44 | 6秒 | `bytes_case` |
| V_Fun | 00:18:44 | 00:27:23 | 519秒 | `fun_case` |
| V_Prim | 00:27:23 | 00:40:39 | 796秒 | `prim_case` |
| V_Op | 00:40:39 | 00:43:05 | 146秒 | `op_case` |
| V_Lam | 00:43:05 | 00:44:34 | 89秒 | `lam_case` |
| V_Con | 00:44:34 | 00:45:16 | 42秒 | `con_case` |
| V_List | 00:45:16 | 00:45:24 | 8秒 | `list_case` |
| V_Map | 00:45:24 | 00:45:32 | 8秒 | `map_case` |
| V_Set | 00:45:32 | 00:45:46 | 14秒 | `set_case` |
| V_Dict | 00:45:46 | 00:46:11 | 25秒 | `dict_case` |
| V_LocRef | 00:46:11 | 00:46:47 | 36秒 | `locRef_case` |
| V_LocLazy | 00:46:47 | 00:46:56 | 9秒 | `locLazy_case` |
| V_Checked | 00:46:56 | 00:47:02 | 6秒 | `checked_case` |
| V_CheckedRequest | 00:47:02 | 00:47:10 | 8秒 | `checkedRequest_case` |
| V_Raise | 00:47:10 | 00:47:58 | 48秒 | `raise_case` |
| V_Super | 00:47:58 | 00:48:13 | 15秒 | `super_case` |
| V_Sub | 00:48:13 | 00:48:20 | 7秒 | `sub_case` |

合計 E は **1,830秒（30分30秒）**。各規則の分離可能な待ち W と能動時間 A は未取得であり、A=E として扱わない。共通の骨格・パターン・局所文脈の作成はこの表より前、19枝の合成・具体例・設計書・監査・結果の作成はこの表より後であり、単価へ重ねていない。V_Fun の519秒には型/行/署名の共通代数、V_Prim の796秒には全体の範囲の具体化と旧の最上位の具体化を合わせる共通補助と再試行を含む。この二枝の合計1,315秒は全体の約72%である。

残り N=27 には値列/各要素4・計算17・腕3・節2・Fail節1の形の差がある。A を分離していないため c=A/19 は算出しない。E/19 を能動単価と呼ばず、27倍を残りの見込みにしない。残27規則の計画の既存の見込みを今回だけで置き換えず、後続担当は共有補助の再使用と実際の通常記録の内訳を取りまとめへ示して更新する。状態と親判断はこの標本に含めない。依存がそろう前の補題の時間で本番の見込みを更新していない。

## 内部の署名の変更と配置

| 対象 | 最終の形と理由 |
|---|---|
| LegacyOutputInput.induct_regular | 初案の Embedded 専用の帰納から任意 M の帰納に一般化した。全子の入力と帰納仮説はそのまま渡す。embed_constants が実際に適用する |
| legacy_local_zero | 初案の L=[] から任意の旧 L へ一般化した。空・非空それぞれで old extend と新 localExtend を対応させる |
| embedPatTy/PatTys/AltsTy と embedExhaustive | 使用しない K.WF や型入力をパターン三判断から除いた。網羅性の初回の入口には LegacyNodeTypes [a] を残し、再開1で実際に使う旧型の a.WF 0 nt へ弱めた。旧全埋め込みの契約の前提は強めていない |
| legacy_rawBind/Tys/Eff | 初案の空の行像から任意の旧/新の行像の対応へ一般化した。旧型には新しい範囲変数を導入しないため新 SubstEnv.ranges=[] の等号を明示する。legacy_subst_rows/legacy_substEff が読む |
| legacy_instREff | 未正規化の旧 Eff.instR の像との等号の初案を、両側を正規化した等号に直した。旧 Eff.instR は最上位の Fail 列の並びを保存し、新しい Eff.instR は正規化する。型付けの結論は同じ正規形の等号から構成する |
| legacyPatternVal/legacyPatternVals | 証明だけで使う相互再帰の関数を明示的 noncomputable とした。初回の監査で検出した Lean 生成の実行用 _unsafe_rec を残さず、監査の例外を追加していない |
| 補助の配置 | 予定の LegacyTyping/LegacyPatterns から、型/範囲の代数、照合/網羅性、値の規則ごとのモジュールへ分けた。全て既定 import から到達する |

初回の公開ソースに明示した追加宣言は161個、17モジュールである。再開1で5個を追加し、現行は166個である。名前・モジュール・行番号・種別は [declarations.tsv](declarations.tsv)、全公開署名は二つの署名文書に置く。初回の生成された補助を含む環境上の監査対象は499定数であり、ソースの宣言数と区別する。[audit-modules.txt](audit-modules.txt) と [audit-declarations.txt](audit-declarations.txt) は対象一覧、[axioms.lean](axioms.lean) は再実行できる台本である。既存の十の主な移送、旧モデルと旧の進行・保存・一段実行の健全性・エフェクトの健全性、ValueMeaning と型付けの定義も同じ監査で明示している。

## 担当の義務の判定

| 義務 | 群 O・P の判定と証拠 | 残る担当・時期 |
|---|---|---|
| O042 | 担当部分完了。七判断の共通の帰納、パターン/網羅性、値19枝を既定 import に追加。旧 import・旧主定理を保持 | L20.135〜.148 が残27規則・全状態・親判断、L70 が切替。embedStep は要求しない |
| O065 | 担当部分完了。固定した Cκ と kind 表、形成・表現可能性・対象保持を既存入力から供給。独立の新しい入力は追加していない | 同上の全埋め込み、L40 の利用葉、L50/L60 の実表、L70 の切替 |
| O160 | 値19規則を本番に置き、各規則の外側の時間を記録。待ちと能動時間は分離不能のため未取得とし、残27規則の見込みを平均で機械的に置き換えない | 後続の移植は通常記録から更新。L40 の別種の作業はこの単価を使わない |
| O016 | 担当部分完了。17モジュール499定数と既存の指定対象の全公理依存を印字し、許可三公理だけを確認 | 独立レビューと L70 の合成は取りまとめ |
| O084 | 担当部分完了。範囲深さ0・型/行/宣言 kind・対象保持、七判断/状態/遷移の未完を上記で区別。σ と external の新しい証明を主張していない | 全 L/R/K の最終受け入れ |
| O027 | 担当部分の記録完了。下表に本体と計測器の RSS、機械/OS、単位、未取得と理由を分けて記す | 各段の記録は各担当。今回で他段の未取得を埋めない |
| O118 | 担当部分完了。新 Lean のコメント・宣言に作業 ID がないことを文字検索し、説明は規則と役割で記述 | 全 L の最後の共通点検 |

## 検査と公理依存

検査のコマンドは次に集める。Lean の単独の実行は全て `-M 12288`、既定ビルドは対象を指定せず `lake build` とした。

```sh
cd formal
lake build
lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/o/contracts.lean
lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/o/signatures-o.lean
lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/o/signatures-p.lean
lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/o/axioms.lean
cd ..
scripts/check.sh --level work --base 428ed95f768f41d63cbc3353e2b21fca0bb88e42 --dry-run
scripts/check.sh --level work --base 428ed95f768f41d63cbc3353e2b21fca0bb88e42
```

work の dry-run は、言語仕様の写しに対する仕様対応の自己検査と集計（spec_tally）、仕様例（spec_examples）、Lean の既定ビルドと sorry の拒否（formal_build）を選んだ。`--only` では絞らない。Rust のソースを変えていないため lib 全件を追加しない。各局所証明を通した後、作業末の work を一度実行した。最終のコマンド・終了・外側の時間・ログの大きさと SHA-256 は [checks.json](checks.json) に記録した。

公理依存の最終の集合は propext・Classical.choice・Quot.sound の三つである。sorryAx・新しい公理・ソースの unsafe/partial は0件。初回の監査は legacyPatternVal の Lean 生成の実行用再帰定数を検出して終了1となり、上記の明示的 noncomputable で解消した。単独署名の初回は表示オプション pp.width が存在せず終了1となり、format.width へ修正して再実行した。その他の局所の型検査では帰納の依存する添字、正規化、暗黙引数と定義展開の照合を修正した。これらを公理や主な言明の弱化で埋めていない。

| 項目 | 本体 | 計測器 | 機械・OS・単位・扱い |
|---|---|---|---|
| 最大常駐量 RSS | 未取得 | 未取得 | arm64、macOS 27.2（26B123）。値を採取していないため bytes/KiB 等へ換算しない。今回は限定採取の作業を追加していない |
| Lean のメモリ制限 | プロセスごと -M 12288 | 該当なし | Lean 4.34.1、Lake 5.0.0-src+5045d00。制限値を実際の RSS と呼ばない |
| 規則ごとの時間 | 外側 E を秒で記録 | clock.curr_time の時刻 | 待ち W・能動 A は未取得。機械速度の比を他段へ一律適用しない |

生の出力は <tmp> に置き、改造には要約・対象一覧・大きさ・SHA-256 を置く。記録のある中間ログは [logs.json](logs.json) に列挙した。局所検査の一部はツールの出力だけであり、完全な生の作業履歴を保存したとはしない。旧の構文や主な定理を含む全回帰、Rust/Lean の最終の全比較、独立レビューと受け入れは今回の検査に含めない。

## 計画との差と申し送り

未承認の主な言明・型付け規則・ValueMeaning・公理・独立の信頼条件・表現可能性/対象保持/宣言 kind 表の前提の追加はなく、停止条件に当たる穴も見つけていない。内部の補助の一般化と、使用しない前提の削除、正規化等号の訂正、モジュールの分割は上記のとおりである。利用者の書ける形は変更していない。

後続の担当は LegacyJudgment.Embedded と induct_regular を使って残27規則を同じ帰納に合成する。let/腕では legacy_local_zero、パターンでは embedAltsTy と子の文脈の bindings、網羅性では範囲深さ0の embedExhaustive を使う。型/行/範囲の具体化は LegacyTypeAlgebra/LegacyRangeAlgebra の正規化等号を再使用できる。既存の LegacyDeclarationInputs の入力を強めず、全状態・三親判断の結論は後続で構成する。

| 残る手順 | 見込み | 担当 |
|---|---|---|
| 定義・言明・仮定と義務の独立レビュー | 不明 | 取りまとめ |
| 指摘があれば処置と関係する再検査 | 不明 | 担当の割当てによる |
| 群 O・P の受け入れ | 不明 | 設計者 |

独立レビューと設計者の受け入れは未実施であり、担当の自己点検をその代わりに数えない。

初回の作業末の work は終了0、外側の時間7.781315秒。仕様対応の自己検査と集計、仕様例7件成功・失敗0・無視0、Lean の既定ビルドと sorry の拒否が通った。直前の単独の既定 lake build は875 jobsで成功した。公理監査は17モジュール499定数と明示した既存対象を合わせて558件の依存を印字し、許可三公理だけを確認した。二つの署名文書は37,213/54,945 bytesで、100 KB以下である。

初回の最終のソース・既定 import・設計書の SHA-256 は [inputs.json](inputs.json)、新ソースの禁止語・作業 ID と結果/署名のリンクの検査は [static-summary.json](static-summary.json)、公理の件数と集合は [audit-summary.json](audit-summary.json) に置く。初回の work の後、その報告までは結果・ハッシュ・検査のメタデータだけを更新し、証明・既定 import・設計書を変えていない。

## 再開1: RV-L20.o 軽1〜4の処置

2026-11-03。[RV-L20.o](../../reviews/RV-L20.o.md) の軽1〜4を処置した。軽5は今回の対象に含めず、七契約と全埋め込みの合成の入口は変更していない。基準は引き続き `428ed95f768f41d63cbc3353e2b21fca0bb88e42`。直接の git の操作、plan/detail/レビュー記録/旧 Release/Rust の変更、新しい公理・sorry・主な十言明・型付け規則・ValueMeaning の変更はない。

| 所見 | 処置と証拠 |
|---|---|
| 軽1 | embedExhaustive の主の入口を LegacyTables・旧 a.WF 0 nt・旧 Exhaustive に弱めた。Sorted/Declared/kind/値の深さなどの使わない前提を除き、旧の強い入口の別名は置いていない。list_coverage は既存の型入力の WF を legacy_wf で移して渡す。match_node_coverage は Unit を照合して wild の腕で Unit を返す C_Match の node を、照合値・腕・return の子の入力まで構成する。同じ children の照合値の子の regular から WF を取り出し、弱めた入口へ適用する。range_wf_rejected は opaque o (rvar 0) が旧 WF 0 nt を満たさないことを証明し、従来の range_input_rejected が使う。旧/新の無条件の網羅性の反例は保持した |
| 軽2 | results.md/signatures.md の記録順序を修正した。実装前に固定したのは七契約と帰納の骨格で、各単位の署名は実装と並行して記録し、最後に型検査の出力へ揃えた。今回の変更・追加の署名も文書へ記してから実装し、最終の型検査の出力へ揃えた |
| 軽3 | 01-12/07-04/results.md に、旧 .float 0 に写すのは Float64 であり、Float32 のビット列は保持すると記した。照合の関数と証明は変更していない |
| 軽4 | list_from_value_rule は Unit 一要素の List の親の regular と、子の各要素の型付けを構成して embed_value の V_List を適用する。operation_from_value_rule は具体の unitOperation と unitOp の lookup、署名の入力・空の型引数・SatAll・結果型の入力を構成して V_Op を適用する。同じ oldProgram/kinds/oldBuiltins/builtins と tables/kinds_wf を使い、oldProgram.ops に unitOp、effects に UnitEffect の操作の一覧を置いた。宣言表と組み込み表を同時に満たしている |

新しい具体例は、導出を合成する入口が、子を持つ規則・署名を読む規則・網羅性を読む C_Match で、実際に満たせる入力から使えることを守る。従来の V_Const の例だけでは、この三つの接続の欠落を検出できない。既存の準備の表と子の入力を再使用し、検査用の型付け規則・信頼欄・本番の差し込み口は追加していない。C_Match の例は旧 node と網羅性を構成する範囲であり、新しい計算の全埋め込みや七判断の合成の完了を主張しない。

追加した公開宣言は LegacyPatternExamples.unitOperation/range_wf_rejected、LegacyEmbeddingExamples.list_from_value_rule/operation_from_value_rule/match_node_coverage の5個。declarations.tsv は全166宣言の現行の行番号へ更新した。signatures.md/value-signatures.md と signatures-o/p.lean も更新し、七契約自体は変更していない。署名文書の大きさは37,573/58,025 bytesで、両方100 KB以下である。

### 再開1の検査と時間

| 検査 | 終了 | 外側の時間 | 内容 |
|---|---:|---:|---|
| 最終の既定 lake build | 0 | 0.154秒 | 対象指定なし、875 jobs。変更した証明の直前の再ビルドも成功 |
| 完全署名の型検査（群 O） | 0 | 0.670秒 | signatures-o.lean、-M 12288 |
| 完全署名の型検査（群 P） | 0 | 0.671秒 | signatures-p.lean、-M 12288 |
| 公理監査の再実行 | 0 | 2.080秒 | axioms.lean、-M 12288。変更3モジュールを含む既存の17モジュール全体を再監査 |

公理監査は生成定数を含む509定数と明示した既存対象を合わせて568件の依存を印字し、propext・Classical.choice・Quot.sound の三つだけを確認した。sorryAx・新しい公理・unsafe/partial の追加は0。現行の集計は [audit-summary-resume1.json](audit-summary-resume1.json)、宣言の一覧は [audit-declarations-resume1.txt](audit-declarations-resume1.txt)。再実行の台本は同じ axioms.lean であり、監査から外した対象はない。

検査のコマンド、終了、時刻、外側の時間、生のログの大きさと SHA-256 は [checks-resume1.json](checks-resume1.json) に記録した。初回の checks.json/inputs.json/audit-summary.json は初回の状態の記録であり、再開1の状態の成功の根拠に読み替えない。局所の追加例の初回の型検査では、暗黙引数の指定、LegacyRowsInput の五成分、名前の長さと一意性、署名の具体化の等号、node 構成子の指定を修正した。実行用の再帰や前提の追加で解消していない。

時間の最初の採取は2026-11-03 01:27:15 JSTで、それ以前の短い読取りは未採取である。待ちと能動時間は分離していない。初回の値19規則の時間に今回の処置を加算せず、残27規則の単価を今回の時間で更新しない。RSS は本体・計測器とも未取得（計画上の非採取）。機械は同じ arm64/macOS 27.2、Lean 4.34.1、-M 12288で、制限値を実際の RSS と呼ばない。

| 残る手順 | 見込み | 担当 |
|---|---|---|
| 軽1〜4の処置の再レビュー | 不明 | 取りまとめ |
| 指摘があれば処置・関係する再検査 | 不明 | 割当てによる |
| 再開1の受け入れ | 不明 | 設計者 |

再開1の作業末の work は `scripts/check.sh --level work --base 428ed95f768f41d63cbc3353e2b21fca0bb88e42` を --only なしで一度実行し、終了0、外側3.724085秒だった。dry-run が選んだ仕様対応の自己検査・集計（spec_tally）、仕様例（spec_examples）、既定 Lean ビルドと sorry の拒否（formal_build）が全て成功した。仕様例は7成功・失敗0・無視0。Rust のソースを変えていないため Rust の全 lib を追加していない。

再開1の採取区間の外側の時間は603.017秒である。開始・終了は [timing-resume1.json](timing-resume1.json)、最終の証明・既定 import・設計書の大きさと SHA-256 は [inputs-resume1.json](inputs-resume1.json)、中間の失敗も含む保存ログは [logs-resume1.json](logs-resume1.json)、禁止語・作業 ID・リンクの照合は [static-summary-resume1.json](static-summary-resume1.json) に置く。生の出力は <tmp> に置いた。再開1の work の後は結果・ハッシュ・検査のメタデータだけを更新し、証明・既定 import・設計書を変えていない。

## 作業末の work

取りまとめが、RV-L20.o の再レビュー（可）の後に、Refinement の生成物を消してから一度実行した。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base 428ed95f768f41d63cbc3353e2b21fca0bb88e42` | 0 | 147.84秒 | 1,540,440,064 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。
