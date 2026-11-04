# L50 群 B の結果

担当の実装と自己点検の記録である。独立レビューと受け入れは取りまとめ・設計者が行う。

- 指定ブランチ: `m014/l50.b`。git の操作は行わない。
- B_WORK: `6c8ec4247893fa0013ec74ffabe8e33bc55a0678`。
- 対象: L50.06〜.10。群 A の F01 三補題、F03〜F05 と承認済み NamesWF を引き継ぐ。
- 最大常駐量: 未取得（計画上の非採取）。

## 再開1

開始: 2026-11-04T17:48:17+09:00。終了: 2026-11-04T17:52:17+09:00。外側の所要時間は4分0秒。指定資料の読み取り・修正・検査・結果の記録を含み、能動時間と待ちは厳密に分離していない。対象は RV-L50.b の軽1・軽2であり、情報1〜5の処置は不要である。

| 指摘 | 処置と判定 |
|---|---|
| 軽1 | 完了。ScopeCoverage の例を、同じ解決先から任意の k/t の所属を保存する受理側と、異なる起点の静的な被覆を拒否する側の連言にした。同じ q を用い、hl は所属保存に、hne は拒否に使う。docstring と coverage.md もこの連言に合わせた |
| 軽2 | 完了。MembershipTargets 末尾の例を任意の t : Target に広げ、a.observe η = some (.targetValue none t) を前提にした。証明は同じ simp の列で通る。01-12 の写しの、対象の種類を限定しない部分評価の記述と一致し、coverage.md も任意の対象にそろえた |
| 情報1〜5 | 指示どおり処置不要 |

既存の例を変更し、重複する例やテスト用の入口は足していない。test-audit の作成時の関門では、守る契約を解決先の一致と起点の一致の区別、および対象の種類に依存しない未評価の維持とした。既存の例だけでは前者の受理側と後者の全対象を検査できないため、同じ例の型を広げた。受理側の欠落や対象の種類の限定に戻る退行は、この例の全称の型で検出する。新しい本番の入口は不要である。Rust のテストファイルの追加・削除・行数の変更は0、本番 Lean の差は ScopeCoverage が差引2行増、MembershipTargets が差引0行である。

| 検査 | 実行と結果 | 外側の時間 | 最新の記録 |
|---|---|---:|---|
| 既定ビルド | formal/ から対象なしの lake build を1回。終了0、1267 jobs。修正2モジュールに警告なし。他モジュールの既存の警告は再表示された | 2.437212秒 | [resume1-build-check.json](resume1-build-check.json) |
| 公理監査 | audit.py --tmp <tmp> を1回。lake env lean -M 12288 で56宣言、固定点2巡、実型9件を照合。private・生成宣言を含む。終了0 | 11.837834秒 | [audit-summary.json](audit-summary.json)、[declarations.json](declarations.json) |
| 選択の確認 | scripts/check.sh --level work --base 6c8ec4247893fa0013ec74ffabe8e33bc55a0678 --dry-run を1回。終了0 | 0.126315秒 | [dry-run-check.json](dry-run-check.json) |
| 作業末 work | scripts/check.sh --level work --base 6c8ec4247893fa0013ec74ffabe8e33bc55a0678 を only なしで1回。終了0。仕様対応表の自己検査・集計、仕様例7成功・失敗0・ignored0、既定ビルドと sorry 拒否が成功 | 4.246204秒 | [work-check.json](work-check.json) |
| 記録照合 | verify.py --tmp <tmp> を1回。終了0。1,019入力、既定 import の閉包1,006モジュール、監査56宣言、全33義務・31申し送り・14目的、相対リンクと記録の上限を照合 | 0.144410秒 | [verification.json](verification.json) |

明示の既定ビルド1回に加え、指定された work の内部でも既定ビルドを実行した。これは今回の検査指定どおりであり、局所 Lean の追加実行はしていない。初回の局所 Lean 3件の記録は当時の入力に対する履歴として保持し、再開後の証明の成功は今回の既定ビルドと work を根拠とする。公理監査・宣言一覧・署名・dry-run・work・verify の記録ファイルは最新一回分へ更新する。以降の初回の結果にある数値は当時の実績である。

公理依存は propext・Quot.sound・Classical.choice の部分集合だけで、新公理・sorryAx は0件。監査の生出力は25,992バイト・SHA-256 `15fbd90a259c13f1063f19cb19dfe6e6785540c5f752c3b5ccf99fdf8a51ae33`、対象一覧は4,220バイト・SHA-256 `3864467891adef8fcadec031a32c96e0c03c4b868dda462b6dabd2d4413620e2`。生出力は一時領域に置き、改造には台本・件数・ハッシュと一回分の宣言記録だけを置く。

定義・規則・主な10言明・固定署名・既定 import に変更はない。01-12 と 07-04 の写しは、例の範囲を合わせたので再編集していない。停止条件に当たる変更と計画からのずれはなく、取りまとめに新しく判断を求める点はない。git の操作・処理系・旧 Release・指定された計画とレビューの変更は行っていない。正式 RSS は未取得（計画上の非採取）。独立レビューの指摘の処置と自己点検までであり、受け入れは取りまとめ・設計者が行う。

以降の節は初回の実装と検査の記録である。

## 単位の時刻

日本時間。外側の時間と待ちを厳密に分離できない区間を能動時間へ換算しない。

| 単位 | 開始 | 終了 | 外側の時間 | 判定 |
|---|---|---|---|---|
| L50.06 | 2026-11-04T17:25:10+09:00 | 2026-11-04T17:26:20+09:00 | 1分10秒 | 完了：記号列の4場合とbasedの実読者 |
| L50.07 | 2026-11-04T17:26:20+09:00 | 2026-11-04T17:27:16+09:00 | 56秒 | 完了：9対と全σの読者・起点差の拒否 |
| L50.08 | 2026-11-04T17:27:16+09:00 | 2026-11-04T17:28:09+09:00 | 53秒 | 完了：snapshot両側・3sort・具体化と短い列 |
| L50.09 | 2026-11-04T17:28:09+09:00 | 2026-11-04T17:31:47+09:00 | 3分38秒 | 完了：一原子の被覆・同じσの許容・全bind |
| L50.10 | 2026-11-04T17:31:47+09:00 | 2026-11-04T17:42:04+09:00 | 10分17秒 | 完了 |

単位の区間の合計は16分54秒。単位開始前の指定資料の読み取りと、単位終了後の報告の準備はこの合計に含めない。群末検査の待ちはL50.10の内数である。能動時間と待ちを厳密に分離していないため、この合計を能動時間の実績として外挿しない。

## 完了条件の照合

L50.06〜.09の単位末は局所Leanの成功を判定し、L50.10では後続の読者への接続と群末の検査まで照合する。[全場合の表](coverage.md)は、一般定理の全量化と全構成子の分岐を根拠とする。具体例から全体の閉鎖を推測していない。

| 単位 | 実装と完了の根拠 |
|---|---|
| L50.06 | 群Aのcovers_atBaseを再利用。exact/exact・tree/exact・tree/treeの受理、exact/treeの拒否を任意Wordで確認。新しいPathPattern.Covers.mem_atBaseをRangeExprのbasedの本番読者へ接続 |
| L50.07 | 全outer/innerと任意σのCovers.memを継承し、Top、旧absoluteのsound、同じbase、secretsへ読者を接続。全9対の成立又は不成立を照合。secretsの任意有限一覧/none/空とlookup noneも扱い、a≠bなら同じ解決先でも静的被覆を拒否 |
| L50.08 | SnapshotMem.monoをnone/someの両読者へ適用。RangeIxの全4対と任意の具体化列からinst_memを証明。Pred.memberの全3種類で同じsnapshotの解釈を拡大し、member_inst_monoへ渡す。短い列は変数を残し全fixedを拒否。snapshotなしのbasedの部分評価はnoneのまま |
| L50.09 | Atomの全9対を既存定義と照合し、covers_fixed_iffから任意Γ/Φ・全σのEff.Covers.allowsへ接続。既存Eff.Allows/allows_normを再宣言しない。全bind・union・empty・row・Topを接続。Failの重複から対象を許さず、行像を再具体化しない |
| L50.10 | [移植表](transplants.md)で最初の新移植13とT07の継承1を区別。在庫27の全目的を再判定し17完了・10残件を記録。F05の観測をF02でupperへ渡す読者、全義務・申し送り、公理と既定importを照合 |

範囲の意味は全σであり、Validを必要条件に追加していない。some snapshotでは元の所属に含まれるValidをそのまま保持する。述語の単調性は二値のinterpretの命題であり、未形成の外側の範囲も含む任意の被覆についてevalWithの成功を結論しない。部分評価の規則を変更していない。

[義務33行・申し送り31行](obligations.md)を一行ずつ判定した。群Bが担当するO015/O022/O034/O048/O060/O061/O144/O165と、共通のO016/O084/O118の担当部分を証拠へ対応させた。O082/O092/O166/O168の拒否の一部とH19/H22/H31の読者も照合した。義務全体の閉鎖は0行であり、実δ・7IO・3モデル75欄・全到達の主定理を閉じたとは記録しない。

## 追加宣言と写し

本番で変えたのはScopeCoverage・MembershipTargets・EffectTargetsの3モジュールである。新しいモジュールは0。群Aの宣言記録との差は22宣言で、公開定理20と生成定理2である。

| モジュール | 追加した公開定理 | 生成宣言 |
|---|---|---|
| ScopeCoverage | PathPattern.Covers.mem_atBase、RangeIx.Covers.inst_mem | 0 |
| MembershipTargets | Pred.member_mono、Pred.member_inst_mono | 0 |
| EffectTargets | Atom.covers_fixed_iff、移植表T01〜T14のT07を除く13入口、Eff.allows_bind_of_rows_ranges_nil、Eff.allows_substAt_nil | allows_union._simp_1_1、allows_bind._simp_1_1 |

新しいprivate宣言は0であるが、変更モジュールの既存privateと生成宣言も監査した。全宣言の写しは最新一回分の [declarations.json](declarations.json) だけに置く。[audit.py](audit.py) と [audit-tail.lean](audit-tail.lean) は対象の一覧を環境から固定点まで再生成する。新しい入口の実型9件は [signatures.md](signatures.md)、F01/F02の元の全量化への適用は [contracts.lean](contracts.lean) に保存した。公開入口には既定ビルドの例又は本番の読者がある。

01-12と07-04の写しは、所属の具体化、3種類の述語解釈、全bindと同じσの効果許容を実物に合わせた。新しい規則・構成子・定義は足しておらず、主な10言明・前段の固定署名は変更していない。旧Release・処理系・plan・detail・README・レビュー・l40・l50/aは編集していない。

## 検査と公理依存

B_WORKは `6c8ec4247893fa0013ec74ffabe8e33bc55a0678`。Leanの実行版は4.34.1、arm64-apple-darwin24.6.0、commit `5045d0056413266e57c625dcd7c365b10e377c52`、Releaseであり、formal/lean-toolchainと一致する。既定lakefileの上限と単独Leanの指定はともに12288である。

| 検査 | 実行・結果 | 記録 |
|---|---|---|
| 最終局所Lean | formal/からlake env lean -M 12288で変更3モジュールを個別に検査。すべて終了0、出力0バイト。ScopeCoverage 0.368174秒、MembershipTargets 0.384388秒、EffectTargets 0.452733秒 | local-scope-check.json、local-member-check.json、local-effect-check.json |
| 選択の確認 | 根からscripts/check.sh --level work --base B_WORK --dry-run。終了0、0.139332秒。仕様対応表の自己検査/集計、仕様例、formal_buildを選択 | [dry-run-check.json](dry-run-check.json) |
| 作業末work | 根からscripts/check.sh --level work --base B_WORKをonlyなしで一度。終了0、18.669798秒。仕様対応表、仕様例7成功・失敗0・ignored0、formal/から対象なしのlake buildとsorry拒否 | [work-check.json](work-check.json) |
| 公理監査と全称契約 | formal/からlake env lean -M 12288で監査入力を検査。終了0、11.669480秒。56宣言、固定点2巡、実型9件。privateと生成宣言を含む。追加22宣言を全て含む | [audit-summary.json](audit-summary.json) |
| 記録照合 | verify.pyで本番入力、既定import、監査、終了、全33義務・31申し送り・14目的、相対リンク、各記録100 KB以下を確認 | [verification.json](verification.json) |

既定ビルドはworkの入口内の一回であり、別の既定ビルド一式は重ねていない。scripts/check.shの既定import全体のビルドとsorry拒否が成功した。固定Leanでの局所証明と既定ビルドの成功をRust/Leanの全比較済みとは扱わない。正式RSSは未取得（計画上の非採取）。独立レビュー・受け入れは未実施である。

監査対象56宣言はpropext・Quot.sound・Classical.choiceの部分集合だけに依存する。新公理・sorryAx・未承認の信頼条件は0。生出力25,992バイト・SHA-256 `30a4b7301820573285ddb746367f3885b3f7ab9ec28ec9398df5e3c52aac79cb`、対象一覧4,220バイト・SHA-256 `3864467891adef8fcadec031a32c96e0c03c4b868dda462b6dabd2d4413620e2`。生出力は一時領域に置き、改造には要約・台本・唯一の宣言記録だけを置く。全環境の段末監査を今回再実行したものではない。

途中の局所試行では、付加の補助のドット記法、none snapshotのSnapshotAdequateの証人、bindの正規化した原子の所属、Atom.nameの等号分解、行像の存在量化とsecretsのmapの存在量化を修正した。失敗のある入力を成功の証拠にしていない。長い日本語を含むPythonの編集入力がUTF-8の構文エラーで実行前に停止した一回はファイル変更がなく、apply_patchで記録を作成した。最終局所3件・work・監査には失敗や再実行がない。

検査例の作成にはtest-auditの関門を適用した。守る契約は起点差の拒否、短い列の維持、未評価と偽の区別、範囲像と行像の適用順である。既存F01の一般証明は複製せず、その本番読者と受理/拒否の対照を置いた。テスト用の本番の差し込み口は追加していない。Rustのテストファイルの追加・削除は0である。

## 差と後続への申し送り

主入口の署名の差は0件。Aの承認済みNamesWFとF06.currentの差をそのまま継承する。T11/T12では新しい範囲像のあるbindの目的を明示し、旧の範囲像のない型をコピーしていない。この差は補助入口の形の具体化であり、F02の形の変更ではない。

在庫の更新は[移植表](transplants.md)のとおりで、最初の新13と継承1は全て完了した。追加の3目的のうち、型だけの置換は新補題、行の置換は供給側の全称の適用例、観測許容はAの既存証明で満たす。残り10目的を一般の全bindの意味の証明から自動的に完了と推測しない。能動時間と待ち、13目的だけの時間は分離できないので、一件当たり係数は未取得。計画の段の枠36.5〜84時間と後続の旧見込みを保つ。

取りまとめに新たに判断を求める点はない。停止条件に当たる変更は生じなかった。4時間の途中報告と10時間上限には達していない。U02に依存する公開形は選択・実装していない。

verifyは全Leanソースと写しの1,019入力を開始時のマニフェストと比較し、追加・削除0、変更は本番3モジュールと写し2文書だけであることを確認した。既定importの閉包1,006モジュールに変更3モジュールが全て含まれ、新モジュール0でも追加モジュールを自動検出して閉包と照合する処理を保つ。全56宣言、入力・生出力・台本・宣言記録のハッシュと、全義務・申し送り・14目的、相対リンク、各ファイル100 KB以下も照合した。

verifyの最初の二回は、まだ生成していない自分の出力verification.jsonへのリンクと、起点の列挙中のhomeを絶対パスと誤判定して終了1となった。出力への自己参照を出力先として扱い、パスの検出を語の境界に限定した後は終了0である。本番・Lean・work・公理監査の入力は変更していない。

| 残る手順 | 受け手と内容 | 見込み |
|---|---|---|
| 群Bの独立レビューと受け入れ | 取りまとめ・設計者。全称の型、全場合、移植在庫、公理依存、検査記録 | 不明 |
| 群C以降の実読者 | detailの担当。保持値/要求/単一対象の全前提と実表、発行/At、純粋δ、7IO、3モデル75条件 | 各担当の計画どおり。群Bの外側の時間による一律外挿はしない |
| 群Lの全環境監査と段末検査 | 全33義務・31申し送り、全環境監査、同じ最終workとRSS、独立レビュー・受け入れ | 計画の2時間40分〜5時間、検査とレビュー待ちは別 |

## 群 B の作業末の work の検査（取りまとめ）

- 基準: `6c8ec4247893fa0013ec74ffabe8e33bc55a0678`。作業木は再開1の後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 6c8ec4247893fa0013ec74ffabe8e33bc55a0678`。
- 結果: 終了0。外側 486.01秒、最大常駐量 2,971,205,632 バイト。仕様例7件が通り、形式化のビルドに sorry はない。
