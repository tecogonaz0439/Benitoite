# L50 群 C の結果

担当の実装と自己点検の記録である。独立レビューと受け入れは取りまとめ・設計者が行う。

「再開1」より前は初回作業時点の記録である。宣言・実署名・公理監査・verificationの保存ファイルは再開1の最新一回分へ更新した。初回の検査値と再開後の検査値を区別する。

- 指定ブランチ: `m014/l50.c`。git の操作は行わない。
- B_WORK: `eb289e60a63a0cb238ad4e2a43aaa5ac1a84676e`。
- 範囲: L50.11〜.15。群 A の承認済み NamesWF と群 B の全σの被覆を継承する。
- 最大常駐量: 未取得（計画上の非採取）。

## 単位の時刻

日本時間。外側の時間と待ちを厳密には分離せず、能動時間へ換算しない。

| 単位 | 開始 | 終了 | 外側の時間 | 判定 |
|---|---|---|---|---|
| L50.11 | 2026-11-04T18:04:30+09:00 | 2026-11-04T18:06:36+09:00 | 2分06秒 | 完了：C20/F03と全3sortの述語読者 |
| L50.12 | 2026-11-04T18:06:36+09:00 | 2026-11-04T18:14:43+09:00 | 8分07秒 | 完了：要求の二経路と Pair の篩・不一致拒否 |
| L50.13 | 2026-11-04T18:14:43+09:00 | 2026-11-04T18:18:38+09:00 | 3分55秒 | 完了：逆転からの互換拡大と全列の節への移送 |
| L50.14 | 2026-11-04T18:18:38+09:00 | 2026-11-04T18:24:05+09:00 | 5分27秒 | 完了：任意位置の同一要求と非Topの実署名の全前提 |
| L50.15 | 2026-11-04T18:24:05+09:00 | 2026-11-04T18:41:03+09:00 | 16分58秒 | 完了：同じwsを元列へ戻す適用・全位置の入口・群末検査 |

## 完了条件の照合

共通依頼文、detail全体とU02の材料、下書き・再開の記録、群A/Bの署名・レビュー・申し送り、planの停止条件と変更、設計者の決定、L40の実署名とL50の受け口を確認した。群Aの F03/F04 と群Bの全σの被覆は作り直していない。F04/F05 の承認済み NamesWF を維持する。

| 単位 | 全場合・全入力の判定と本番の証拠 |
|---|---|
| L50.11 | 完了。C20 と target_member に全29規則/25構文を対応。canonical_target が全保持3形を返し、target_member_interpret が全3sort/任意Ψ/Topを含む全範囲と同じ有効σの述語読者へ接続 |
| L50.12 | 完了。request_target が要求の2保持経路、同じ内容型/groundVal/reqTarget/対象所属を量化。Pair[String{true},String]入りの五欄要求を両経路で受理し、443を80へ変えた保持端点は任意の結果型で両経路とも拒否 |
| L50.13 | 完了。canonical_opaque は通常の資源の定数も含め、全C/Φ/Ψ/RangeIxを逆転。保持3形とCheckedWitnessの2枝から同じscopedを再構成。widen_opaque、widen_instTarget_covers、HasTypeVsQ.widen_coversが同じ値と全列をopSigAtの節へ移す |
| L50.14 | 完了。既存の任意位置のlookupをprivate single_inputへ共通化し、F04の公開署名は不変。single_requestが型/行/先行する値の代入後の実対象位置から同じ要求へ接続。非TopのFile.readTextInでNamesWFを含む全前提を実際に供給。ShapeOkの5一般目的を閉じた |
| L50.15 | 完了。single_inputs/request_inputsは元の具体化済み署名から任意の関数値の列へのTelClosureと同じwsの導出を受け、applyで元列へ戻してBuiltinArgs.normalizedへ接続。結果と効果の関係は適用の出力。7位置とD09の5入力形の全称の入口を照合 |

全場合の対応と量化、2つの要求経路、受理と拒否、7位置と5入力形は [coverage.md](coverage.md) に示す。義務33行と申し送り31行は [obligations.md](obligations.md) で一行ずつ判定した。群Cの担当分と、.21〜.35の実表/全応答・.51の全実表/実行葉の合成・.54のStateTyEからの接続を区別する。群全体の主定理・実IO・推論手続きの完了と呼ばない。義務全体の閉鎖は0行である。

## 保持対象・要求・single・F3

本番の完全名の先頭は `Benitoite.Release.Refinement` である。値29規則の導出の帰納と23規則の排除は追加していない。対象のない不透明型の定数の排除はF03、通常資源の定数はcanonical_opaqueのTopの枝で保持する。target.WFはF03の結論に加えない。

要求の読者は `HasTypeVQ.request_target`・`Builtins.ShapeOk.single_request`・`ScopedCallContracts.request_inputs` である。同じ値の ModelHttp.valueRun から同じ req を返し、内容型・groundVal・固定reqTarget・同じσでの範囲所属を同時に得る。既存 checkedRequest_content、CheckedWitness.request_content、ModelHttp の二射影と不一致拒否を利用する。Pair例は保持した型引数に篩を残してgroundValへ通し、型付けでは正規化して実際の欄型へ渡す。

互換拡大は `HasTypeVQ.canonical_opaque/widen_opaque/widen_instTarget_covers` と `HasTypeVsQ.widen_covers` である。新しいopaqueの共変規則を作らず、scopedの再構成・共変・忘却を使う。同じ要求/端点を拡大後に射影する例、非TopのPathInをTopのopaqueへ広げる受理と要求なしRequestInの拒否、全長の値列を実opSigAtの節の添字へ移す例がある。

singleの実読者は上のsingle_requestとsingle_inputs/request_inputsである。型/行/先行する値の代入のlookupを複製していない。具体例は実File.readTextInの原署名の行に一致し、ResultのOk/Errorを持つ具体のPと全arity、非Topの範囲、同じ対象を保持した引数、全BuiltinArgs、NamesWF、ShapeOk、適格性を供給する。例は任意Ψ/σを量化し、Top fallbackを使わない。IOの応答表・応答存在まで証明した例ではない。

F3の読者は `TelClosure.apply` の固定署名を使う。元列のAnnotationはSignatureInstance.resultから、Ctx.WFは空の文脈から供給する。P.WellFormed/CoreAssumptions/Ψ.WF/到達列のAnnotationの四前提を戻していない。元の型付き列と正規化したBuiltinArgsで同じwsとrsを保ち、結果型や許容効果から範囲を決めない。直接・明示拡大・関数値・callback・ADT/List・Reference/Lazy・節/resumeの7行には、全称の入口と既定の読者がある。Listの全要素とADT任意欄、refの実セル、lazyのthunk/done、resumeの直接/正規化の両入力を既存の補題で接続した。

## 在庫と追加宣言

[transplants.md](transplants.md) の9行（Membership4・ShapeOk5）を閉じた。群Bの17完了を継承し、27目的は26完了・残件1である。残る `allows_bind_comp` は .30 の既存担当である。ShapeOk5の一般目的を閉じたことから、.23の全実署名や.35のIO応答・存在を完了へ繰り上げない。

新規モジュールは MembershipWiden と ScopedCallContracts の2つで、既定importへ追加した。変更モジュールは AtInput・MembershipTargets・ShapeTargets の3つである。01-12と07-04に現在の性質と前提を写した。処理系・旧Release・型付け規則・前段の固定署名は変更していない。

| モジュール | 追加宣言（private・生成を含む） | 手で書いた公開定理 |
|---|---:|---|
| AtInput | 32 | parseUrlTarget_https_loopback |
| MembershipTargets | 19 | canonical_target・target_member_interpret・request_target |
| MembershipWiden | 9 | canonical_opaque・widen_opaque・widen_instTarget_covers・HasTypeVsQ.widen_covers |
| ShapeTargets | 39 | common・eff_eq・inst_eff_mem・single・single_inst・single_request |
| ScopedCallContracts | 2 | single_inputs・request_inputs |
| 計 | 101 | 16本 |

追加101宣言は定理77・定義24で、privateの完全名75、生成宣言（行番号0）62を含む。privateと生成の分類は重複する。既存定義の等式を利用した際に環境へ生成されたScopeDeclarationsのeq_1も含める。手で書いた16公開定理には全て既定の具体例又は本番の読者がある。全型は [signatures.md](signatures.md) の主要17件、全宣言は最新一回分の [declarations.json](declarations.json) に記録する。

## 群末の検査

基準は `eb289e60a63a0cb238ad4e2a43aaa5ac1a84676e`。固定Leanは formal/lean-toolchain の `leanprover/lean4:v4.34.1`。既定ビルドはformal/から対象なし、単独Leanは同じ場所から `lake env lean -M 12288`、workは根からonlyなしで実行した。正式RSSは未取得（計画上の非採取）。

| 検査 | 実行・結果 | 外側の時間 | 記録 |
|---|---|---:|---|
| 局所Lean | 各単位の本番モジュールを検査。最終の局所検査は全て終了0。途中の試行失敗は下記 | 各約0.5〜1秒。個別全試行の厳密な合計は未取得 | 最終状態の証拠は下の既定buildと監査 |
| 既定ビルド | formal/から対象なしのlake build。終了0、1269 jobs | 2.329920秒 | [build-check.json](build-check.json) |
| 公理監査・固定契約・実型 | audit.pyが生成した入力を単独Leanで検査。全5モジュールの218宣言、固定点2巡。終了0 | 10.938443秒（本番監査）＋0.867090秒（復元した元入力） | [audit-summary.json](audit-summary.json) |
| 選択の確認 | scripts/check.sh --level work --base 上記ID --dry-run。終了0 | 0.128722秒 | [dry-run-check.json](dry-run-check.json) |
| 作業末work | scripts/check.sh --level work --base 上記IDをonlyなしで一度。仕様対応表の自己検査/集計、仕様例7成功・失敗0・ignored0、既定Leanとsorry拒否。終了0 | 10.977734秒 | [work-check.json](work-check.json) |
| 記録の照合 | verify.pyが全追加モジュールの既定import、宣言、入力ハッシュ、義務と申し送り、検査の状態、記録の上限を照合 | 最終値はverification.json | [verification.json](verification.json) |

明示の最終buildとwork内の既定buildを区別する。最終build後の本番入力・写しの追加変更はないことを開始時刻と最終マニフェストで確かめる。既存モジュールの非推奨・未使用simp引数・リンク先の警告は再生されたが、今回の追加/変更モジュールと最終監査の警告は0である。仕様網羅表には従来の未対応節の表示があるが、自己検査と集計は成功した。Rustの変更・全比較・ベンチマーク・独立レビュー・受け入れは実行していない。

## 公理と再現

[audit.py](audit.py)・[audit-tail.lean](audit-tail.lean)・[contracts.lean](contracts.lean) により監査対象の完全名と実型を再生成できる。対象は名前空間の接頭辞で絞らず、所属モジュールを環境から調べてprivate・生成宣言も固定点まで列挙する。今回の5モジュール全218宣言を監査したうえで、前段の保存済み一覧と、開始時のAtInputのハッシュと一致する元入力の復元・再検査から追加101宣言を区別した。

依存は propext・Quot.sound・Classical.choice の部分集合だけで、新公理・sorryAxは0件である。全環境の段末監査を実行した意味ではない。生出力は110,229バイト、SHA-256 `7011b280fa94e9a928f7893668dad987a8b9aa5ede89a9575d91abaa28edf99b`。対象一覧は19,833バイト、SHA-256 `4b4043d261d7f6b847c6081461cc3ee624873898afc89fc8767b8acf51210414`。追加宣言一覧は9,637バイト、SHA-256 `54317de8c51b64e9ed7a351828f1eed074f5841602c353c56b51a774cf2b467b`。生出力と一覧は一時領域に置き、改造には台本・件数・ハッシュ・一回分の宣言記録だけを置く。

verify.pyは開始時の1,019入力と最終1,021入力を比較し、追加2モジュールと変更6ファイル（根import、既存3モジュール、写し2文書）だけであることを確かめる。既定importの閉包1,008モジュールに今回の全5モジュールが含まれる。開始マニフェストは131,826バイト・SHA-256 `61b1a64691c2f8dd9eff614be6e0933fb6e67543b46ed7c7d632b3798c89fb55`、最終は132,090バイト・SHA-256 `860d4f8740a6f08f922f3acf3c7cdca0d921ba721ae548f5f0e11ea7a5a835ce` である。

## 途中の失敗と修正

局所検査では、型注釈不足、scopedの語の引用、範囲添字の形成、Topを覆う範囲の逆転、型/効果の正規化、有限宣言のlookup、Pairの型引数の代入、値代入後のtelの正規化を修正した。URLの解析は単なるdecideで閉じず、AtInputの内部の解析定義を使う小さい等式を加えた。大きな具体列・範囲の評価、native_decide、新公理は使っていない。これらの途中の失敗を成功の証拠に数えない。

途中の最初の既定buildは、Pair例のbase型の正規化の未整理で終了1となった。修正後の局所検査は成功した。このビルドが終わる前に同じbuildを一度誤起動したため、直ちにそのセッションを指定して中断した（終了130）。プロセスの名前で停止していない。この2実行の外側の時間と完全な生出力は未取得であり、上表の成功の記録とは区別する。次の増分の既定buildは終了0・2.332472秒（build-progress-check.json）、最終入力での成功は上表のbuild-check.jsonである。

公理監査の最初の実行も218宣言の依存の検査は成功したが、追加件数へ既存AtInputの122宣言を含めてしまった。AtInputから追加した等式の区間だけを除くと開始時のファイルのハッシュと一致することを台本で確かめ、追加の手書きの定理を1件と数え直した後、元の入力を復元して同じ固定Leanで宣言を列挙した。元入力は91宣言、変更後は123宣言で、新たに生成された31宣言を含む差は32件だった。このため群の追加の分類を101件へ訂正した。元入力の復元の入力・出力の大きさとハッシュもaudit-summary.jsonへ残し、最新の本番監査と一覧だけを保存する。依存の結論と生出力のハッシュに差はない。適用前に失敗した一回のpatchはファイルを変更していない。

## 計画との差と申し送り

主な十言明、F03/F04/F05、前段のTelClosure.apply、型付け規則、書ける形、提供範囲、精密な外部状態、独立の信頼条件を変更していない。U02に依存する公開形は選択・実装していない。停止条件に当たる追加変更はなく、取りまとめに新たな判断を求める点はない。

計画の内部で、ShapeOk5の一般目的を.14でまとめて閉じ、.23には全実署名への適用を残した。任意位置のlookupはsingle_targetからprivate single_inputへ共通化し、single_requestでも再利用した。AtInputには固定URLの解析結果を、要求の具体例の実入力として供給する補助定理を一つ足した。F3の接続は、元の具体化済み署名から関数値の列への到達を使い、型付けを元列へ戻した後に正規化したBuiltinArgsを構成する。入力の具体化は一回である。

検査例の作成にはtest-auditの関門を適用した。守る契約は、同じ要求と端点の保持、篩を含むPairのgroundVal、型付きsingleの対象の存在、範囲の互換拡大と節の同じ列である。任意の結果型で不一致を拒否する対照、非Topの全前提、全要素/任意欄と実セルの読者が、既存の一般補題だけでは接続を確かめられなかった境界を守る。検査用のフラグや差し込み口、Rustのテストファイルの変更はない。

単位の時刻は冒頭で開始/終了の都度記録した。単位の区間の合計は36分33秒であり、単位開始前の読み取りと単位終了後の記録の再照合は含めない。所要は外側の時間であり、能動時間と待ちを分離していない。9移植目的だけの時間も分離できず、一件当たり係数は未取得である。未実証の群の見込みや段の枠は変更しない。

| 残る手順 | 内容・担当 | 見込み |
|---|---|---|
| 群Cの独立レビューと受け入れ | 取りまとめ・設計者。全称の署名、7位置の入口、同じ要求、非Topの全前提、在庫と監査を照合 | 不明 |
| 群D〜Jの実表と応答 | 既定の担当。発行/At、共通16署名、6純粋/7IO、三モデル75条件 | detailの各群の見込み。群Cの外側の時間で一律外挿しない |
| .30の残在庫 | 効果のallows_bind_comp。今回のMembership/ShapeOkと別の目的 | .30の35〜60分の内数。待ちは不明 |
| 群Kの全実表・実行葉の合成 | .51/.54でこの群の全称の入口から既存の全実行葉へ接続し、同じσ/Eb/μを照合 | 群Kの2時間50分〜5時間15分の内数 |
| 群Lと後段 | 全環境監査・段末検査・独立レビュー/受け入れ、L60/L70、R10b/R30の推論と実行 | 各計画の範囲。独立レビューと受け入れの待ちは不明 |

群末の記録の再照合では、本番や写しを変えず、AtInputの元入力を復元して生成宣言も含む追加件数を確定した。この区間は冒頭の単位の実装の所要へ遡って加えない。依存の監査範囲と結論に変化はない。

## 再開1

開始: 2026-11-04T18:53:43+09:00。終了: 2026-11-04T19:02:56+09:00。外側の所要時間は9分13秒。能動時間と待ちは分離していない。

独立レビュー RV-L50.c の軽1・軽2を処置する。情報1〜6は処置不要という指定を引き継ぐ。ブランチ・B_WORK・停止条件は冒頭と同じであり、git の操作は行わない。

### 処置と署名の差

軽1は `HasTypeVQ.request_form` を追加し、canonical_target の三形から checked と checkedAt の request none を排除して閉じた。前提は空の型・値・経路条件の文脈での型付け、端点のHolds、valKind、valContentの一致、同じσへのAdequateである。request_target がこの補題を読み、single_request と request_inputs が順に同じ値の型付けから適用する。三つの入口は保持する target/req とその保持形を結論に返す。既存の本番の適用例もこの結論を使う。

| 署名 | 差 | 元の署名からの適用 |
|---|---|---|
| HasTypeVQ.request_target | 使わない前提 form を除く変更。target/req を結論の ∃ へ移し、導いた保持形も返す | contracts.lean の第4例。元の form と返された保持形の構成子の等号を照合し、元の同じ target/req の全結論を得る |
| Builtins.ShapeOk.single_request | 使わない前提 form を除く変更。対象位置の target/req を結論の ∃ へ移し、導いた保持形も返す | contracts.lean の第5例。任意の p の lookup の後に元の form を照合し、元の全結論を得る |
| ScopedCallContracts.request_inputs | 使わない前提 form を除く変更。元列へ戻した対象位置の target/req を結論の ∃ へ移し、導いた保持形も返す | contracts.lean の第6例。同じ元列の型付け・結果型・効果・範囲とともに元の全結論を得る |

上の三つの適用例は単独Leanで成功し、群末の公理監査の入力にも含める。F03・F04・TelClosure.apply、主な十言明、型付け規則は変更しない。

軽2は MembershipWiden 末尾の対照を更新した。同じ `.checked (.path ["data"])` が `/data/**` の opaque から Top の opaque へ広がる受理と、`/other/**` の同じ名前の opaque への型付けの拒否を対にした。拒否は任意のσについて target_member から同じパスの所属を取り出し、所属の矛盾で閉じる。docstring・[coverage.md](coverage.md)・01-12と07-04の写しも実物に合わせた。

test-audit の作成時の関門では、守る契約を同じ値・同じ不透明型名の範囲所属とした。型付けから対象所属を得られなくなる退行をこの境界で捕まえる。従来の要求なしRequestInの拒否は別の名前の内容型によるため、この契約を確かめていなかった。既存の対照を置き換え、テスト用の本番の差し込み口は加えない。三つの契約の適用例は、前提除去の互換性を直接確かめるために置く。

局所検査では、四つの変更モジュールが終了0となった。具体例の要求の正規化にgroundValの等式を供給し、契約の適用例でQemptyを完全名にした。拒否例の未使用simp引数も除いた。これらの修正前の失敗と警告を最終の成功の根拠には数えない。

### 群末の検査と宣言

4検査は今回の最終入力でそれぞれ一度実行し、すべて終了0となった。work内の既定ビルドと明示の既定ビルドは別の実行である。指定の基準は `eb289e60a63a0cb238ad4e2a43aaa5ac1a84676e`、固定Leanは `leanprover/lean4:v4.34.1`、単独Leanは `-M 12288` である。実行台本 [run.py](run.py) に検査記録の接頭辞と既定buildを加え、既存記録を残したまま今回の一度の実行を保存した。[verify.py](verify.py) も接頭辞を受け取り、最新の宣言件数と実行記録を照合する。検査の選択確認は今回の最終状態でdry-runを一度実行した。

| 検査 | 実行・結果 | 外側の時間 | 記録 |
|---|---|---:|---|
| 既定ビルド | formal/から対象指定なしの `lake build`。終了0、1269 jobs | 2.646722秒 | [resume1-build-check.json](resume1-build-check.json) |
| 公理監査 | audit.py --tmp <tmp>。変更・追加5モジュールの全219宣言、private・生成宣言を含み固定点2巡。旧署名3本の適用例も成功。終了0 | 本番11.975534秒＋元入力の復元0.920973秒 | [audit-summary.json](audit-summary.json) |
| 選択確認 | scripts/check.sh --level work --base 上記ID --dry-run。終了0 | 0.129161秒 | [resume1-dry-run-check.json](resume1-dry-run-check.json) |
| 作業末work | scripts/check.sh --level work --base 上記ID。onlyなし、一度実行し終了0。仕様対応表の自己検査・集計、仕様例7成功/失敗0/ignored0、既定Lean・sorry拒否が成功 | 4.243339秒 | [resume1-work-check.json](resume1-work-check.json) |
| verify | verify.py --tmp <tmp> --record-prefix resume1-。終了0。1,021入力、既定import閉包1,008モジュール、全219宣言、義務33行・申し送り31行、検査記録・リンク・記録サイズを照合 | 0.146136秒 | [verification.json](verification.json) |

既定ビルドは既存モジュールの警告を再生したが、今回の四つの変更モジュールと公理監査に警告はない。既定build後の本番ソース・写しの変更はない。verifyは作業末workの終了を含む全記録を照合するため、最後に実行した。終了時刻と所要時間の記録だけをその後に追記し、本番・写し・監査入力・検査台本は変えていない。

群Cの追加分は102宣言（定理78・定義24）で、privateの完全名75、生成宣言62を含む。手で書いた公開定理は17本であり、再開で増えたのは request_form の1本だけである。監査対象219宣言の依存は propext・Quot.sound・Classical.choice の部分集合だけで、新公理・sorryAxは0件。元入力の復元でAtInputの91宣言を再確認し、前段の保存一覧と比較した。監査台本と宣言記録は最新一回分だけを保存し、主要18件の実署名を [signatures.md](signatures.md) へ作り直した。

| モジュール | 追加宣言（private・生成を含む） | 手で書いた公開定理 |
|---|---:|---|
| AtInput | 32 | 1本 |
| MembershipTargets | 20 | 4本（request_formを含む） |
| MembershipWiden | 9 | 4本 |
| ShapeTargets | 39 | 6本 |
| ScopedCallContracts | 2 | 2本 |
| 計 | 102 | 17本 |

監査の生出力は111,275バイト・SHA-256 `6968340d965416783a3700dd5376dbb84be555d904abd28b3b9f496748677f3e`。対象一覧は19,885バイト・SHA-256 `8d75f6de6320926660d15687ccbb3395a7d4fb891647c3e58a1108506156b148`。追加一覧は9,689バイト・SHA-256 `f734e458cbd9bcb27c4a5e7991c5197b96b6e88a6f76944a7214d2c2194c21bf`。生出力は一時領域へ置き、改造には件数・ハッシュ・再生成する台本だけを残す。最大常駐量は未取得（計画上の非採取）。

担当の義務33行・申し送り31行、Membership4件・ShapeOk5件の在庫の完了判定は変わらない。使わないform前提の除去と被覆の対照の修正だけを行い、情報1〜6は変更しない。新しい判断を取りまとめへ求める点はない。

## 群 C の作業末の work の検査（取りまとめ）

- 基準: `eb289e60a63a0cb238ad4e2a43aaa5ac1a84676e`。作業木は再開1の後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base eb289e60a63a0cb238ad4e2a43aaa5ac1a84676e`。
- 結果: 終了0。外側 482.16秒、最大常駐量 2,943,287,296 バイト。仕様例7件が通り、形式化のビルドに sorry はない。
