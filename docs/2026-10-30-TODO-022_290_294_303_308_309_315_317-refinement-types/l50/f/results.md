# L50 群 F の結果

担当の実装と自己点検の記録である。独立レビューと受け入れは取りまとめ・設計者が行う。再開前の検査値は当時の記録であり、現在の宣言一覧・実署名・監査・verify は末尾の「再開1」で更新する。

- 指定ブランチ: `m014/l50.f`。git の操作は行わない。
- B_WORK: `57d27892e00cfa4f95c6351f4b35567614e763aa`。
- 対象: L50.26〜.30。
- 最大常駐量: 未取得（計画上の非採取）。

## 単位の時刻

外側の時間を記録する。能動時間と待ちは分離していない。

| 単位 | 開始 | 終了 | 判定 |
|---|---|---|---|
| L50.26 | 2026-11-04T22:15:24+09:00 | 2026-11-04T22:19:20+09:00 | 完了（局所 Lean 終了0） |
| L50.27 | 2026-11-04T22:19:20+09:00 | 2026-11-04T22:20:47+09:00 | 完了（局所 Lean 終了0） |
| L50.28 | 2026-11-04T22:20:47+09:00 | 2026-11-04T22:22:32+09:00 | 完了（局所 Lean 終了0） |
| L50.29 | 2026-11-04T22:22:32+09:00 | 2026-11-04T22:23:03+09:00 | 完了（局所 Lean 終了0） |
| L50.30 | 2026-11-04T22:23:03+09:00 | 2026-11-04T22:41:24+09:00 | 完了（既定ビルド・監査・work・記録照合が終了0） |

## 完了条件の照合

共通依頼文と指定資料、承認済みの NamesWF、前群の全称の署名と申し送りを継承した。F01/F03/F04/F05、前段の TelClosure.apply と正常応答の facts の署名を変えていない。具体例から全体の閉鎖を推測せず、各入口の全入力の型で判定した。最終の単位は群末の検査と記録照合を含む。

| 単位 | 全場合・全入力の証拠と判定 |
|---|---|
| L50.26 | 完了。ScopeValueDelta の path_target は全閉じた型付きパスを逆転し、opaque定数・要求の形を分類の矛盾で除く。pathValueRun は checked/checkedAt の保持する同じ絶対パスを String へ写す。pathInValue_response は全 BuiltinArgs。widenPathIn_response は許容した被覆と既存 widen_opaque から、同じ値を目的型へ渡す。全Topによる許容も含み、起点を再解決しない |
| L50.27 | 完了。RequestValueDelta の retained_request は全型付き RequestIn から二保持形・同じreq・閉じた内容型・groundVal・固定reqTargetを返す。requestInValue_response は既存 valueRun の型付けを使い default 枝を排除する。widenRequestIn_response と全型付き要求の適用例は同じ保持値・req・端点を保つ |
| L50.28 | 完了。ScopeResponse.response は任意P/B/Ψの元の全BuiltinArgsと同じ共通lookupから六行の具体δを構成する。delta_typed は共通表の全純粋行、outcome_typed は決定性を使い同じδの全実応答、ground は全正常値、normal_facts は同じ正常値の項観測を扱う。対象所属の適用例と既存 normal_reply_facts の読者を含む。別枠の三結果葉も全引数・全ws・全有効σで適格。分類だけの未完0 |
| L50.29 | 完了。ModelConstraints の sat_rename/admits_rename/sat_values/admits_values は任意の型・型引数列・非空制約を量化する。既存carrierの値bind/norm不変を使い、型・行の像の値依存とFailの縮約を除かない |
| L50.30 | 完了。sat_renameTypes/admits_renameTypes は TypeParamRenaming、sat_subst/admits_subst は閉じた型像と各位置のSatAllから構造の保存を帰納する。ScopeConstraintInstances は共通表の八欄の実証・無制約・admits_satを構成し、宣言の形成を同じP/lookupのsig_scopedへ接続する。allows_bind_compの全二段代入も完了。群末検査と記録照合は後掲 |

[義務と申し送り](obligations.md)には33義務・31申し送りを一行ずつ判定した。O015/O022/O034/O035/O038/O048/O049/O058/O062/O065/O082/O144とH03/H04/H06/H07/H09/H10/H14/H19/H22/H25/H26/H28/H31の群Fの担当部分を閉じた。義務全体の閉鎖は0行であり、七IO・三モデル75欄・実行の全読者・external/release・主定理・公開形は、計画の既存の担当のままである。群Fの独立の未完をこれらへ送っていない。

## 射影と拡大の δ

| API | 同じ具体の処理: Lean の中の一致 | 同じ具体の処理: 処理系との一致 | 型付き入力の結論 |
|---|---|---|---|
| Scope.pathInValue | ScopeDelta.valueDelta → pathValueRun。保持するpathの成分を `/` で結び先頭に `/` を付ける。checked/checkedAtで同じ文字列 | 処理系は検査した入力のStringを保存して返す。pathValueRun_parseAtInputにより、絶対形として受理した全入力でそのStringと一致する | 全BuiltinArgsからStringの型・Ground・AdequateResult・非exit |
| Scope.widenPathIn | ScopeDelta.valueDelta → widenRun。単一値vを.val vとして返す | 処理系のwiden_path_inも被覆を確かめて同じ値を返す | 型は既存widen_opaqueで広がる。同じvなので対象とsnapshotは不変 |
| Http.requestInValue | RequestDelta.valueDelta → 既存ModelHttp.valueRun。二保持形で同じreq | 処理系のrequest_valueも保持レコードの欄0の元の要求を返す | 型・groundVal・reqTarget一致からdefault枝を除く |
| Http.widenRequestIn | RequestDelta.valueDelta → 同じScopeDelta.widenRun。同じv・req・endpoint | 処理系のwiden_request_inも被覆を確かめて同じ値を返す | 被覆だけで結果型を広げる |

`checkedAt` の解決後のパスは処理系にまだ実装されていない。

チェック2行は群EのScopeDelta.delta/RequestDelta.deltaを変更せずに集約した。六行の同じ最終δはScopeResponse.deltaである。型・行引数の個数と範囲列の長さをBuiltinArgsから取り出し、実際の依存列を具体化して全値列と同じ結果型へ進む。範囲は入力として一度与えられ、結果や効果から逆算しない。widenの許容は、全Topの枝又は同じB.admitsRの被覆から供給する。一般のopaque共変規則は足していない。

各射影/拡大のresponseは任意P/Bに対する入口である。widenの補助入口は表の許容が被覆を与えることを受け取り、ScopeResponse.responseも対象・内容の分類と共通lookupを受け取る。これらは既存の表の欄についての事実であり、新しい独立の信頼条件ではない。共通表ではScopeSignaturesの定義とwiden_admittedで全て供給し、delta_typedはHasHttp Pと元のBuiltinArgsだけから呼べる。[実署名](actual-signatures.md)に暗黙引数を含む型を保存した。L60の合成には単独の表へ限定した定理でなく、これらの任意P/Bのresponseを渡す。

Outcome.errを削除していない。例えばパス射影のmalformedな空列は.err InvalidPathInとなる。型付きパスではその枝が除かれる。要求のvalueRunのdefault枝は既存のまま保持するが、型付き要求の全入力で到達しないことを証明した。チェックのResult.ErrorとOutcome.errは別の構文であり、両者を正常成功の存在へ強めていない。

## 純粋な応答・観測と別枠の結果葉

ScopeResponse.delta_typedは六純粋行を全lookup・全BuiltinArgsで扱う。応答存在と、任意outについてδが返す実応答の型・全有効σ適格性・非exit（outcome_typed）を区別した。groundは同じδが返した正常値について量化する。normal_factsと既定ビルドのnormal_reply_factsの適用例は、同じ正常値とtoTerm?の等号を使う。全σの対象所属の適用例は同じ応答の型・AdequateResultから既存target_member_interpretへ接続する。正常のfacts、対象所属、外部IOの成功は混同しない。

adequate_externalRef/adequate_externalHandle/adequate_scopePatternは、各構文の全引数・任意ws・全有効σについて成立する。Val.Adequateのこれらの枝は既定のTrueであり、証明は自明である。leaves_unobservedは、三構文のtoTerm?がnoneであることと、全パターンの束縛列の項観測が等しいことを別に証明した。パターンのvarは値全体を束縛するが、内部の生入力を取り出す観測にはならない。これら三構文に元の生入力のValの欄はなく、外部呼出しの結果の三条件はL60が受け持つ。atErrorの内部の元入力が不活性である証拠は、群DのDetail.originals_unobservedを継承し、再実装しない。U02の公開形は選んでいない。

## 八つの保存則と制約の供給

| 既存条件 | ModelConstraintsの本番入口 | 証明の入力と全量化 |
|---|---|---|
| 値のsat_rename | sat_rename | 任意S/C/a/p/ξ。型付けやξの単調性を要求しない強い同値 |
| 値のadmits_rename | admits_rename | 任意S/ps/C/as/ξ。全列長と各位置の制約 |
| 値のsat_values | sat_values | 任意S/C/a/p/ν。型・行を具体化した後の値依存を含む全型 |
| 値のadmits_values | admits_values | 同じ全列と各位置。非空制約も同じsatで検査 |
| 型のsat_renameTypes | sat_renameTypes | 任意TypeParamRenaming C D ρ。非単射ρと開いた型を含む |
| 型のadmits_renameTypes | admits_renameTypes | 同じ列の全位置で前行を適用 |
| 型のsat_subst | sat_subst | 任意C1++C0/a/p/ts/es。閉じた型像・各像のsat・個数一致。行像は任意 |
| 型のadmits_subst | admits_subst | 任意列と全位置に前行を適用 |

satisfies_bind/satArgs_bindの相互の帰納は、元の型変数の各制約を像が満たすことから全構造を保存する。dataは同じsummary行とarity・依存位置を保ち、List/Map/Setは要素を辿る。非空制約でfn/tapp等を拒否する場合も除かない。型代入のtvarは、C1に残る位置・C0の像の位置・文脈の外の三つに分け、最後は元のsat成功で排除する。keyはequalityの条件も供給する。型像の篩は値依存を持ってよく、行像に入るFailも任意である。Fail列の長さや重複を読まない。

共通16行のScopeSignatures.substitutionAssumptionsは任意P/delta/ioについて八欄を埋める。共通表のadmitsは型引数の個数によるため、その保存は同じlookupの全16行の照合とlength_mapで示す。一般のModelConstraints.admitsについても、非空制約を含む全保存の定理を別に用意し、三モデルの後続が利用できる。sat_unconstrainedは任意の型に空制約を供給し、admits_satは同じBと型引数列のSatAllを返す。モデルのsatをTrueへ置き換えていない。Pのarity/kind/sourceTelRowsは八保存則の独立仮定にせず、群Eのsig_scopedと同じlookupの適用例で供給する。

## 閉じた移植の在庫

群Bの残件allows_bind_compの1目的を閉じた。新しいEff.allows_bind_compは全θ/φ/e/σ/κ/l/tについて、正規化した二段bindの許容と三経路の選言との同値を返す。元の名前付き原子の範囲は二段のinstを順に適用し、最初の行像は二段目のbindで読む。最初の行置換で残る変数だけが二段目の行像へ進む。型・値の像とFailの縮約を除く条件はない。行像を読む実適用例を既定ビルドに置いた。

旧ReleaseのSubstEnv.composeを新しい四名前空間の環境へそのままコピーせず、同じ目的を全入力の三経路の同値で満たした。detail第8節の「署名をそのままコピーするという意味ではない」に従う補助入口であり、前段の固定署名やF02の変更ではない。群Cで閉じたMembership4/ShapeOk5と合わせ、27目的の在庫に群Fが受け持つ残件は0。段全体の最終照合は群K/Lで行う。

## 追加宣言・写し・既定 import

| モジュール | 主要な追加と読者 |
|---|---|
| ScopeValueDelta（新） | snapshot_kind/path_target、pathValueRun/widenRun/valueDelta、pathInValue_response/widenPathIn_response。ScopeResponseの実読者へ |
| RequestValueDelta（新） | retained_request/valueDelta、requestInValue_response/widenRequestIn_response。要求の全二経路と同じ値の拡大の適用例 |
| ScopeResponse（新） | 六行のdelta/response/delta_typed/outcome_typed/ground/normal_facts、三結果葉のadequateとleaves_unobserved。既存の正常応答・対象観測の読者へ |
| ScopeConstraintInstances（新） | 共通表のadmits_iff_count、八欄のsubstitutionAssumptions、sat_unconstrained/admits_sat。実際の二種類のAssumptionsと形成の適用例 |
| ModelConstraints（追加だけ） | 値4・型4の保存、admits_map/sat_norm/sat_unconstrained。privateの骨格の帰納と型像の補助も実読者を持つ |
| EffectTargets（追加だけ） | allows_bind_compとその実適用例 |

新設4モジュールを全てformal/Benitoite.leanの既定importへ追加した。01-12/07-04の写しは、実装した定義と前提、八保存、同じδと結果葉の観測を反映する。経緯や未実装の作業を写しへ書いていない。verifyは全追加モジュールを開始入力との差から再抽出して、既定importの閉包に含むことを確認する。既存2モジュールと根のimportは、追加部分を除くと開始時のハッシュに一致することも検査する。

全宣言の唯一の写しはdeclarations-part-01.jsonである。監査は変更6モジュールの全168宣言を対象とし、private・生成宣言を含む固定点2巡で列挙した。新設4モジュールは全79宣言（ScopeValueDelta35、RequestValueDelta21、ScopeResponse14、ScopeConstraintInstances9）、既存2モジュールは全89宣言（ModelConstraints52、EffectTargets37）である。89を追加数と呼ばない。主要33入口の暗黙引数を含む実署名をactual-signatures.mdへ保存した。対象の一覧はaudit.py/audit-tail.leanから作り直せ、宣言名の接頭辞でprivateや生成宣言を落とさない。

## 群末の検査と公理依存

固定Leanはformal/lean-toolchainのleanprover/lean4:v4.34.1を使用し、単独Leanはlake env lean -M 12288で実行した。既定ビルドはformal/を作業ディレクトリに対象指定なしのlake buildである。最大常駐量は未取得（計画上の非採取）。Rust/Leanの全比較、ベンチマーク、独立レビューと受け入れは実行していない。

| 検査 | 実行・内容・結果 | 外側の時間 | 記録 |
|---|---|---:|---|
| 既定ビルド | formal/からlake buildを一度。既定importの全1,281ジョブ、終了0 | 14.142302秒 | [build-check.json](build-check.json) |
| 公理監査と全称契約 | lake env lean -M 12288。全168宣言・private/生成を含む固定点2巡、主要33実署名、元のF07と八条件の適用。終了0 | 11.316543秒 | [audit-summary.json](audit-summary.json)、[contracts.lean](contracts.lean) |
| 選択確認 | scripts/check.sh --level work --base 57d27892e00cfa4f95c6351f4b35567614e763aa --dry-run。終了0 | 0.337876秒 | [dry-run-check.json](dry-run-check.json) |
| 作業末work | 上記基準で--onlyなしを一度。仕様対応の自己検査と集計、仕様例7成功/0失敗/0ignored、既定Leanビルドとsorry拒否。終了0 | 8.779123秒 | [work-check.json](work-check.json) |
| 記録照合 | 全追加import、開始入力との差、全監査宣言とハッシュ、33義務/31申し送り、検査の一度の実行、リンクと容量。結果はverification.jsonを正とする | verification.jsonを正とする | [verification.json](verification.json) |

明示の既定ビルドとwork内の既定ビルドは別の実行である。指定のwork自体は一度だけであり、onlyで絞っていない。既定ビルドには変更していない既存モジュールの警告の再表示がある。今回の追加・変更の補題の最終局所検査と公理監査に警告はない。

公理への依存はpropext・Quot.sound・Classical.choiceの部分集合だけで、新公理・sorryAx・独立の信頼条件は0。監査の生出力は92,029 bytes、SHA-256 ce6c643ff8e5d89d74c7e16969fbf4a487b09cd58b35c83ed3a7db76952c9468。対象一覧は13,474 bytes、SHA-256 f8e55ac3b3a6371b27d3422d1653a0a6ca091c981146130cf51bbb0f5d4f02bb。生出力と一覧は一時領域に置き、改造には台本・件数・ハッシュと唯一の宣言記録を置く。全既定環境の段末監査とは区別する。

## 途中の失敗と計画との差

最初のScopeValueDeltaを書き出すコマンドは作業ディレクトリを重ねた相対パスで終了1となり、ファイルを作らなかった。正しいリポジトリ相対パスで作成した後の局所Leanでは、暗黙のkindの型注釈、casesの枝の字下げ、要求の実名への置換、Adequateの明示した構文、simpの不要引数を修正した。骨格の帰納ではrawBindの簡約、型列の長さ、Boolの等号の括弧、各像の型注釈を直した。Effectの二段代入ではcases後の変数名を直した。記録照合の最初の実行は、出力先verification.jsonへの自己参照リンクを未生成として拒否したため終了1となった。自分の出力先だけを生成予定のリンクとして扱うよう直した。本番・写し・Lean監査・workの入力は変えていない。これらの途中の失敗は成功の根拠にせず、最終の局所検査・既定ビルド・公理監査・workを根拠とする。大きな具体列や範囲の評価は行っていない。

検査例にはtest-auditの作成時の関門を適用した。守る契約は、保持する絶対対象・同じreq/endpoint/値の保持、typed入力のdefault排除、型と値の制約の保存、二段の代入の許容である。再解決、要求の差替え、sat=Trueへの退行、片方の範囲像又は行像の適用漏れを各入口の全称の型で検出する。既存の一般の型付けやF01〜F05を複製せず、今回の具体δと既存の読者との接続を検査する。テスト用の差し込み口・Rustテスト・フラグは追加しない。

計画の内部の配置として、射影と拡大を新設ScopeValueDelta/RequestValueDeltaへ分け、共通表の置換条件をScopeConstraintInstancesへ置いた。名前空間はScopeDelta/RequestDelta/ScopeSignaturesを使い、群Eの既存δとresponseの署名・本体は変えない。allows_bind_compの補助の形は上記のとおりである。主な十言明・型付け規則・前段の固定署名・利用者の書ける形・提供範囲・精密な外部状態に変更はない。旧Release、処理系、計画、detail、u02-options、README、レビュー、l40と群A〜Eの記録を編集していない。gitの操作も行っていない。

能動時間と待ちは分離していない。外側の時間だけを能動時間の実績へ換算せず、群Fの見込み4時間5分〜8時間と後続の既存見込みを保つ。4時間の途中報告条件と16時間上限には達していない。取りまとめに新しく判断を求める点はない。独立レビューと設計者の受け入れは、担当の自己点検と分ける。

| 残る手順 | 内容・担当 | 見込み |
|---|---|---|
| 群Fの独立レビューと受け入れ | 取りまとめ・設計者。全称の署名、同じδ、八保存、三結果葉、公理と記録 | 不明 |
| 七IO・三モデルへの適用 | 群G〜J。任意P/Bのresponseと骨格の八保存を使い、同じ表の全応答と75欄を構成 | detailの各群の既存見込み。検査・レビュー待ちは不明 |
| 全実行読者と段末照合 | 群K/L。既存状態保存へ接続し、全環境監査・最終work/RSS・独立レビュー | 既存の2時間50分〜5時間15分、2時間40分〜5時間。検査・レビュー待ちは別 |
| 外部・主定理・実装の接続 | L60/L70とR段の既存担当。external/release、全主定理、Rust/Leanの全比較 | 各計画の範囲。待ちは不明 |

## 単位ごとの所要時間

日本時間。群末の検査と記録はL50.30に含む。開始前の指定資料の読み取りは含めず、能動時間と待ちは分離していない。

| 単位 | 開始 | 終了 | 外側の所要 |
|---|---|---|---:|
| L50.26 | 2026-11-04T22:15:24+09:00 | 2026-11-04T22:19:20+09:00 | 3分56秒 |
| L50.27 | 2026-11-04T22:19:20+09:00 | 2026-11-04T22:20:47+09:00 | 1分27秒 |
| L50.28 | 2026-11-04T22:20:47+09:00 | 2026-11-04T22:22:32+09:00 | 1分45秒 |
| L50.29 | 2026-11-04T22:22:32+09:00 | 2026-11-04T22:23:03+09:00 | 0分31秒 |
| L50.30 | 2026-11-04T22:23:03+09:00 | 2026-11-04T22:41:24+09:00 | 18分21秒 |

単位の区間の合計は26分00秒である。L50.26〜.30の担当分は完了し、群Fの独立の未完は0。最終の記録照合は本番と写しの同じハッシュを再確認するだけで、Lean・work・公理監査は重ねて実行しない。宣言の写しは群末の一回分だけである。終了時刻・所要時間の追記以外に、本番・写し・監査入力・検査台本の変更はない。独立レビューと受け入れは未実施である。

## 再開1

開始: 2026-11-04T22:52:27+09:00。RV-L50.f の軽1・軽2を処置する。情報1〜7は処置不要である。

往復の補題は全入力を量化し、splitChars の再帰に沿って証明する。大きな具体値の評価はしない。群末に既定ビルド・公理監査・verify・指定のworkを各一度実行する。

| 指摘 | 処置・判定 |
|---|---|
| 軽1 | 完了。AtInput に private の splitChars_ne_nil・intercalate_splitChars・intercalate_splitText と parseAtInput_path_text を追加した。splitChars の文字列分割の再帰を全入力で帰納し、区切りの再挿入が元の文字列を返すことを示した。ScopeValueDelta の pathValueRun_parseAtInput は、絶対形として受理された任意の s/w について checked の射影が元の String を返す。任意の範囲・snapshot の checkedAt への全称の適用例も既定ビルドに置いた。results の δ の表は Lean の中の一致と処理系との一致を分け、checkedAt の解決後のパスが処理系にまだないことを results と 01-12 に明記した |
| 軽2 | 完了。07-04 の ModelConstraints・ScopeConstraintInstances の行に、sat_bind_values・admits_bind_values の型像を変えない全置換での同値と、値の改名・値の置換・非空の制約・型像の衝突の対照例の説明を、八条件と並べて戻した |
| 情報1〜7 | 指示どおり処置なし |

AtInput の非公開の分割関数は別モジュールから直接参照できないため、その全入力の補助証明は定義元に置き、射影の往復補題を ScopeValueDelta に置いた。既存の解析定義は変更していない。verify は追加部分を除くと開始時の AtInput のハッシュへ戻ることも照合する。監査の対象を既存の6モジュールから7モジュールへ広げ、AtInput の既存・追加・private・生成宣言を全て含める。宣言の写しは今回の群末一回分で置き換え、重複して保存しない。主要な実署名には二つの往復の入口を加える。

局所 Lean は固定版の lake env lean -M 12288 を用いた。最初の試行では非公開名の参照・String の prefix を示す補題名・if の分岐順に関する証明が通らず、定義元への配置と明示した分岐に直した。最終の二モジュールの局所検査は終了0、警告なしである。全入力の言明に反例はなく、大きな具体値の作成・評価は行っていない。

適用例には test-audit の作成時の関門を適用した。守る独立の契約は受理済みの絶対パスの元の文字列と射影値の一致で、区切りや先頭の `/` を失う退行を検出する。既存の checked/checkedAt の一致の例は元の解析入力に接続していないため、この往復を検査できない。新しい例は全称の往復の入口を起点解決済みの保持形に適用し、新しい差し込み口や処理系のテストは追加しない。

検査の基準は B_WORK のままである。今回の build/work は resume1- を付けた別記録に一回分を保存する。前回の dry-run は同じ基準の選択確認として引用し、再実行しない。verify の --record-prefix は今回の build/work の生出力もハッシュで照合する。明示の lake build と work 内の既定ビルドは別の実行である。

| 今回の検査 | 結果 | 所要 | 記録 |
|---|---|---:|---|
| 既定の lake build | formal/ から対象指定なしを一度。全1,281ジョブ、終了0 | 397.051837秒 | [resume1-build-check.json](resume1-build-check.json) |
| 公理監査 | 変更7モジュールの全354宣言、private・生成宣言を含む固定点2巡。新公理0、終了0 | 12.003744秒 | [audit-summary.json](audit-summary.json) |
| 指定の work | --only なしで指定の B_WORK を一度。仕様対応表の自己検査と集計、仕様例7件、既定Leanビルドとsorry拒否、終了0 | 4.353441秒 | [resume1-work-check.json](resume1-work-check.json) |
| verify | 開始入力との差、7モジュールの既定import、全監査宣言、検査の一回分と生出力のハッシュ、33義務・31申し送り、リンク・容量を照合。初回終了0の後に本文の重複を修正し、再照合する | 最終の所要・成否は記録を正とする | [verification.json](verification.json) |

依存公理は propext・Quot.sound・Classical.choice の部分集合だけで、sorryAx・新公理・独立の信頼条件は0である。全354宣言のうち、AtInput は既存宣言を含む174宣言、ScopeValueDelta は生成宣言を含む47宣言である。354を今回の追加宣言数とは呼ばない。新設4モジュール全体の現在の宣言数は91、主要な実署名は二つの往復の入口を加えた35件である。宣言一覧の写しは declarations-part-01.json の一回分（71,728 bytes）に置き換えた。

監査の生出力は 161610 bytes、SHA-256 ad15c954c65e050a1b9a424428e768d740ff522dbb92d0afad2d63437d7784c0。監査対象の一覧は 29148 bytes、SHA-256 b102c8c8fa6c936f915822eeeda6381eda89462b6ee8b74de039f474f111b3e6。生出力は一時領域に置き、改造には台本と件数・ハッシュを残す。ビルドとworkの生出力の大きさ・ハッシュは各JSONにある。

明示のビルドは6分37秒で、検査全体の見込みの2〜5分を超えた。AtInput に依存する既存の標準関数の証明の再ビルドが主な待ちで、当初の見込みの2倍には達していない。変更していないモジュールの警告は再表示されたが、追加・変更した二モジュールの局所検査と公理監査に警告はない。解析関数、処理系、型付け規則、主な十言明、前段の固定署名は変更していない。git の操作は行っていない。新しい判断を求める点はない。

記録追記スクリプトの条件式の書き誤りで本文が二重になっていた。初回の verify は終了0（0.150111秒）だったが、最終の読み直しで重複を見つけ、同じ本文の二つ目だけを削除した。この記録修正のため verify だけを再実行する。群末の指定からのずれは verify の2回の実行であり、既定ビルド・公理監査・workは各一度である。本番・写し・監査入力・検査台本は初回のverify後に変更していない。

最終のverifyは終了0、0.134886秒である。終了: 2026-11-04T23:07:42+09:00。開始からの外側の所要は15分15秒（能動時間と待ちは分離していない）。軽2件の処置は完了した。最終のverify後は本段落の成否・所要・終了時刻だけを追記し、本番・写し・監査入力・検査台本は変更していない。

## 群 F の作業末の work の検査（取りまとめ）

- 基準: `57d27892e00cfa4f95c6351f4b35567614e763aa`。作業木は再開1の後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 57d27892e00cfa4f95c6351f4b35567614e763aa`。
- 結果: 終了0。外側 452.72秒、最大常駐量 2,928,885,760 バイト。仕様例7件が通り、形式化のビルドに sorry はない。
