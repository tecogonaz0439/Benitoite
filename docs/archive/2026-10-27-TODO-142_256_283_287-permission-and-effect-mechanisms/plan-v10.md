# V10: 回帰・文書・公開候補の作業単位（下書き）

2026-10-30、V10P。V10Pb で [RV-V10P](reviews/RV-V10P.md) と J1・J2 の決定を反映した。[共通依頼文](implementation-request.md)と[計画の雛形](../../workflow/change-plan-template.md)に従い、[plan の V10](plan.md#段とレビュー)と [R/K の計画](plan-r10-r40.md)の予約3枝を具体化する。V10 は11単位とする。UB30.01/.02 は取り込み済みであり、残りへ再加算しない。取りまとめが独立レビューを得て採用するまで、起動依頼として使わない。V10Pb は計画と dry-run だけであり、以下の実装・検査・受け入れを実施した記録ではない。

## 前提と依存

| 欄 | 固定する内容 |
|---|---|
| 目的と範囲 | 0.0.13 の実装済みの契約、回帰の証拠、文書、同梱物、ソースだけの公開候補を一致させる。範囲付きのエフェクトは正規化した API の対象の静的な上限である。実行時の権限制御・実体の隔離・情報フロー制御を実装済みとしない |
| 判断の正 | [README の決定](README.md)、[decisions](decisions.md)、本書の順。DET-09 は README の一括回答で決定済みである。古い計画の「全比較を実行または引用」は、README の「V10 は引用し、実行が必要なら停止して設計者に問う」に読み替える |
| 改造の開始版 B0 | `6124775788579e60530f55fb85570f26ef7fa900`。change、release の基準と short の before に使う |
| V10Pb の基準 B_WORK | `3a07167b342d99325ef297f300c26cc4c04d5ccb`。ブランチ `m013/v10p`。UB30 の取り込みと J1・J2 の決定を含む。[開始状態](v10p/v10pb-initial-state.json)を保存した。旧 V10P の状態は過去の記録として残す。V10 の各起動では直前の取り込みの完全 ID に更新する |
| 検査の正 | [07-03「実装の規約と静的な検査」](../../design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査)、[07-04「01-12 との対応」](../../design/07-quality/07-04-formal-semantics.md#01-12-との対応)。具体的なコマンドは本書の「検査の割り当て」に集める |
| 最初の勧告照合 | [2026-10-27 の記録](security-advisories.md)。ワークスペースと fuzz は共通 deny.toml・locked・RustSec DB `3279c99911354c400e1d41e47c7d60e39258b147` で各検出0件。固定 Rust/Cargo 1.98.1、Lean 4.34.1、elan 4.2.4 に新規対象なしという当日の記録を引き継ぐ。設計者の判断は「組み込まない」。V10P では新規の勧告照合をしていない |
| 未照合の引き継ぎ | nightly Rust/Miri、elan の Rust 依存、Lean release notes 本文、試作に使った別機の実版。候補では Lean 担当の引き渡した版と実版も照合する。依存の0件で四ツールや未照合範囲まで確認済みとしない |
| 形式化の内外 | V10 の既定範囲に Lean の定義・証明・交換形式の変更はない。変更が必要なら停止し、設計者の判断後に Claude のサブエージェントが Lean を先行する別作業へ戻す。既定ビルドと独立レビューを経てから Rust を接続する |
| 担当 | 実装・文書・結果記録は Codex。独立レビューは実装者以外が行う。基準の指定、取り込み、docs/todo の更新と別リポジトリでのコミット、保管、公開は取りまとめ。受け入れは設計者 |
| 読む範囲と操作 | 担当は private/ と同所を指すスキル、docs/todo を読まない。必要な条件は本書と改造内の記録を渡す。担当は状態を変える git 操作を行わない。本書の将来の保管・公開の手順を V10P の操作許可にしない |

用語は [00-04](../../design/00-overview/00-04-glossary.md)と README に従う。情報フロー制御（information-flow control）、セキュリティ型システム（security type system）、非干渉性、非機密化（declassification）、エンドースメント（endorsement。信頼の付与、または完全性レベルの引き上げ）の後続設計を現在の仕様へ追加しない。

## 申し送りの棚卸し

同じ契約への重複をまとめた33項目である。元の30項目に UB30.01-1 と取りまとめが受け持つ RV-K10 の2項目を加えた。「重さ」の「中」「軽」「参考」は元レビューの分類を引き継ぎ、「必須」「限界」「決定済み」は計画上の扱いであって不具合の重大度ではない。状態は独立した欄へ記し、完了した項目も残す。レビューの「対応（取りまとめ）」の V10 行は、[原文9行・5文書の一覧](v10p/review-handoffs.json)で対応付ける。

| 番号 | 出どころ | 中身と現在の扱い | 受け持つ作業単位 | 重さ | 状態 |
|---|---|---|---|---|---|
| H01 | ub20.02「後の枝へ残す点」、plan の UB30、R40/K10 の結果 | [UB30.01b 追補後の本文](ub30.01/results.md)と [RV-UB30](reviews/RV-UB30.md)で完了。TODO-302/054 へは修正後の本文を転記する。局所比較の残りは H31 | V10.1a、V10.3d | 必須 | 完了（UB30.01b・RV-UB30、取り込み済み） |
| H02 | README「全比較の進め方」、K10.3/K10.3b、RV-K10.3 | 成功段の引用と失敗・未到達段の再確認を合わせた全比較の成功を、最終の関係状態へ引用する。全体の終了0を新たに得たと書かない | V10.1a、V10.1c、V10.3c/d | 必須・停止条件 | 未完（割当先で照合） |
| H03 | R20/R30/R40、K10.1〜.3、義務の対応表 | 初期の同じ ε、BA の継続末尾の整形式性、Top 定数の shapeAt、旧像の同値の射程、到達した RequestIn 全体の要求保持、valContents の型一致を書き手に任せる境界を保つ | V10.2a、V10.3c | 限界・了承済み | 未完（割当先で照合） |
| H04 | README の TLS の決定、R30.5、R40、K10.3 | 観測はプログラムが接続する保持 endpoint。host/port は scheme を持つ origin ではない。実パス・DNS 後の相手・OS/網の変換・DNS/TLS 副次通信の宛先や内容の流れを保証しない | V10.2a/b、V10.3a/c | 必須 | 未完（割当先で照合） |
| H05 | R30/R30.5b、RV-R30 軽3、R40、K10.3 W-K | random_differential は test_default_all 300件、test_heap_all 300件、test_stress 200件で各60秒の予算。約46秒は既定構成だけの実績で、heap/stress は未計測。他のビルドや並行の作業と同時に走らせない。負荷で超過したら同じ件数・予算で再確認し、初回失敗と判断を残す。release の自動選択にはこの検査はない | V10.1b/c、V10.3c | 実行条件 | 未完（割当先で照合） |
| H06 | LR-U7、R10/R30/R40 の結果 | 完全／部分ハンドラ・別名・旧 send・不足節を通常文書・生成物・訳の最終一覧へ照合する。File.Read 13・File.Write 16・Http.Connect 2。外部コードの母集団・件数は不明であり0としない | V10.2b、V10.3a/c | 必須・未確認 | 未完（割当先で照合） |
| H07 | LR-U8、R20/R30/R40、r30.5/handlers-boundaries | ネットワーク/WASM を外した構成、32ビット、全 OS の実ビルド・挙動は未確認。純粋な代数の依存方向と固定幅・検査付き変換の読解の範囲を保つ | V10.2a、V10.3d | 限界 | 未完（割当先で照合） |
| H08 | R20/R40、plan-r10-r40 の V10 | E0521 の自然な上限到達例と案内の解消効果は未確認。収束や必ず直るという保証を加えない | V10.1b、V10.2a/b、V10.3d | 未確認 | 未完（割当先で照合） |
| H09 | R20.5b を引く R20/R30.5 | 全体保持2,048 への通常ソースでの到達は構文の深さ上限が先行して未確認。本体16,384/512、全体65,536/2,048 と番号付け200,000イベントを混同しない | V10.1b/c、V10.2a、V10.3d | 未確認 | 未完（割当先で照合） |
| H10 | RV-R40 軽5「対応（取りまとめ）」 | E0519 の説明句への逆引用符、先頭の点と surface preorder の文言は、README の J1 の決定に従い docs/todo の TODO-315 へ回した | 完了（docs/todo へ） | 軽・決定済み | 完了（docs/todo の TODO-315 へ） |
| H11 | RV-R30 参考、R30.5b、plan-r10-r40 の V10.2 | 01-06 の「だけ」と lower.rs の定数本体・with の二つ目以降の束縛の記録位置を照合する。振る舞いの差は再現未確認。文書の範囲の誤りと実行が要る反例を分ける | V10.1b → V10.2a | 参考・要照合 | 未完（割当先で照合） |
| H12 | RV-R20 軽5、RV-R30 中1、R30.5b | 07-04 の19か所・01-12 の9か所の番号参照は置換済みで、保存した検索式の残り0件。未修正として再配分せず、最終差分の再検索だけを行う | V10.2a | 中／軽・完了済み | 完了（最終照合だけ） |
| H13 | RV-R30.1 軽1、R30.5、plan-r10-r40 | 英語 reference の旧2510行・訳2374行の IPv6/全数字ラベル拒否の説明を、IP/CIDR の受理と IPv4 射影の対象拒否へ追随させる。行番号は開始版の目印であり見出しで再同定する | V10.2b、V10.3a | 軽 | 未完（割当先で照合） |
| H14 | R20 の新四入口の決定、R30.5、plan-r10-r40 | 英語 reference 旧949行・訳921行の既知不良の静的診断を新四入口へ追随させる。E0459〜E0462 の除外と必須判定の理由を分ける | V10.2b、V10.3a | 必須 | 未完（割当先で照合） |
| H15 | README の TODO-308 の決定、R20/R30/R40 | bind の形、狭い関数／節引数への由来なし、同じ狭い型のまま IO へ転送する形を説明する。節引数は bind へ置くだけでは直らない。制限を恒久の設計としない | V10.2a/b、V10.3a/c | 決定済み | 未完（割当先で照合） |
| H16 | R30.5/R40、義務の対応表 | 六純粋宣言、七 IO、同じ値／要求の保持、明示拡大、部分ハンドラに残る効果を実標準署名と照合する | V10.2b、V10.3c | 必須 | 未完（割当先で照合） |
| H17 | RV-R20 軽7 → R40.1 → r40/results | RequestCheckError に標準 Show を追加せず、構成子の match で扱う判断は完了。V10 で採否を再質問せず文書に一致させる | V10.2b、V10.3a | 軽・完了済み | 完了（採否を再質問しない） |
| H18 | UB20.02、R40.2/.3、RV-R40 中1の対応 | expanded は名前集合、bounds は宣言上限、未知・未完了は空と異なる。doc の check/error 例は入口を選ばず空の Effects/tests であり純粋を意味しない。処理済み利用者名と任意の由来を許可へ戻さない | UB30、V10.2a/b、V10.3a/c | 必須 | 未完（割当先で照合） |
| H19 | R30.2d、R30/R40 の意図した差 | 宣言情報・意味ハッシュの版4と旧 manifest/receipt を新承認へ読み替えない境界。生成器本文の規則の版まで機械的に上げない。移行案内は作らない | V10.2b、V10.3a/c | 必須 | 未完（割当先で照合） |
| H20 | DET-09、README 一括回答、LR-U7 | CHANGELOG に七操作の追加と、旧 send の節だけでは部分ハンドラになり Connect が残る事実を短く書く。書き換え手順・前後コード・移行例・性能増減を書かない | V10.2b で案 → V10.3a/c | 決定済み | 未完（割当先で照合） |
| H21 | RV-R20 軽4、r20/results「意図した差」 | 完全ハンドラを含む lambda を後の節から呼ぶ Top のプログラムの、誤った E0501 拒否の解消を CHANGELOG の事実だけの修正項目にする案を用意する | V10.2b、V10.3a | 軽・編集判断 | 未完（割当先で照合） |
| H22 | security-advisories、plan の候補照合 | 候補の二 manifest・二 lock・共通設定と四ツールを再照合。取得不能や新規勧告を0件へ変えず、表示・記録・報告し次の改造へ渡す。検出だけで候補を止めない | V10.1c、V10.3b/c/d | 必須 | 未完（割当先で照合） |
| H23 | README/R20/R30/R40 の short 判断、benchmark | TODO-304/307 の受け入れ済みの費用と未確認の原因を保持する。処理系・埋め込む Skill を変えた取り込みの short は準備前に行う。今回は targets/full を割り当てない | V10.1b、V10.2b、V10.3a の起動前 | 決定済み・測定 | 未完（割当先で照合） |
| H24 | plan「改造の終わり」、IF30、R30.5、README SH2 | PM の独立モデルと本番を区別し、IFC-D2〜D9 と IF30 P09 の今回分・未接続、SH/SH2 の結果と本番未接続を転記する。任意 HR 未実施を試作未完にしない | V10.1a、V10.3d | 必須・取りまとめ | 未完（割当先で照合） |
| H25 | K10.1/.2/.3、UB20.02 | corpus15/sidecar7 と製品版を分ける。候補欄を除く非 Top12群57、Top互換3群、六入口・区間・全関係定義を保つ。三拒否の独立期待値への個別照合と予算2件の直接比較を区別し、typing を四理由へ変換しない | V10.1a、V10.3c | 必須 | 未完（割当先で照合） |
| H26 | R40.3 の handoff、K10.2/.3 | 報告側26入力と独立期待値、check/test/doc、非 Top/Top/拒否/不足節、名前だけの allow-effects を実候補で照合する。古い producer の版・commit を実候補の証拠にしない | V10.3c | 必須 | 未完（割当先で照合） |
| H27 | RV-R40.2 参考1 → R40.2b、RV-R40 | File の書き込み・追記の名前を worker/完了/失敗理由へ渡す修正は閉じている。二重失敗を大入力で再現したとはしない。V10 の再実装なし | V10.1a、V10.3d | 参考・完了済み | 完了（再実装なし） |
| H28 | plan「改造の終わり」、archive-and-bundle、README の旧作業場所の記述 | 保管前に work/・reference/ を出どころとして参照する箇所を棚卸しし、必要な根拠を改造内へ保存する。README 末尾の旧依頼文・共通条件・scratch の案内も解消する | V10.3d | 必須 | 未完（割当先で照合） |
| H29 | plan の V10/release、git-workflow | README、0.0.13、二 lock、訳、生成物、ライセンス、実 CLI、ソース配布、受け入れ・保管・集約後の commit/producer を一致させる | V10.3a〜e | 必須 | 未完（割当先で照合） |
| H30 | V10P の版上げの読解（後述） | J2 (a) は決定済み。0.0.13 を登録し、要約と help は事実だけ、language 宣言と版依存の期待値は版上げと同時に更新する。全比較の影響段は起動前の了承後に再確認する | V10.1b → V10.3a → V10.1d | 必須・決定済み | 未完（割当先で照合） |
| H31 | UB30.01-1、RV-UB30、RV-V10P 重大1・中1 | 利用者操作の署名の非 Top の固定添字と、節から範囲付き prim へ渡す組合せを局所比較する。利用者原子の明示 Top と user/prim/fail は既存の確認範囲。義務表の該当行は K10.2 で未完 | V10.1b、V10.1d、F-Q | 中・証拠不足 | 未完（書き出せなければ未確認のまま返す） |
| H32 | RV-K10.3 軽3「対応（取りまとめ）」 | manifest の同時保持による最大常駐量12.99 GiBを逐次読み取りの課題として転記する。TODO-314 の manifest 重複と関連を明示し、同じ論点を重ねて登録しない。原因のプロファイル特定は未実施 | 取りまとめ、V10.1a・V10.3d | 軽 | 未確認（登録済みかを取りまとめが照合） |
| H33 | RV-K10.1 軽2「対応（取りまとめ）」 | W-K の九項目の名指しと B-Lean の formal_build の引用の判断を README に記す | 取りまとめ、V10.1a | 軽 | 完了（README の2026-10-29の判断に記録済み） |

### 決定済みの判断と残る停止条件

| 判断 | 材料と推す扱い | 判断する時期・止める範囲 |
|---|---|---|
| J1: E0519 の文言（決定済み） | README の2026-10-30の決定により docs/todo の TODO-315 へ回す。H10 は完了（docs/todo へ） | 判断待ちから外す。V10 で診断文言・期待値を変えない |
| J2: 0.0.13 の言語版（(a) と決定済み） | 前例と同じ基準で、旧 Http.send の節だけのハンドラの受理が狭まる点を登録する。E0908 の要約と help は事実だけにし、節の書き換え方・移行手順は書かない（Q2）。testdata の language 宣言は0.0.13へ上げる | V10.1b は再現・登録の差分案・影響一覧だけ。版に依存する登録・テスト・testdata は V10.3a で版上げと同時に変える。V10.1d の起動は範囲と見込みを示し設計者の了承を得るまで停止 |
| J3: 全比較入力の変更または引用不能 | J2 と H31 の計画済み変更は下の影響表と V10.1d に従う。それ以外の処理系ソース・標準ライブラリ・testdata・書き出しテスト・Lean・台本の変更、または想定外の出力差は、理由と影響する段を示して停止する | 各作業の着手時と修正前、change の失敗を直す前、候補を更新する前。影響段の再実行前に必ず了承を得る。形式化の定義や交換器の機能追加は別の判断へ返す |

J3 の資源の判断材料は K10.2/.3 の実測である。一般 corpus は343,291,355 bytes（約343 MB）、routing の補助最大RSSは約8.20 GiB、manifest は約924 MiB・material は約300 MiB・observations は約561 MiBを同時に保持し、manifest 段の補助最大RSSは12.99 GiBであった。16 GB 級の計算機には余裕がない。Lean の `-M 12288` は Python と交換実行ファイルの上限ではない。V10.1d の前に空きメモリ・他の負荷・保存出力の空き容量を確認し、同時に長い検査を走らせない。後続課題として H32 を取りまとめが扱い、TODO-314 と重複登録しない。

H21 の CHANGELOG の事実だけの修正項目は編集案であり、新しい仕様の採否ではない。DET-09、Show を加えないこと、TODO-308 の一時制限、TODO-304/307 の費用、TODO-313/314 への送りは決定済みであり、同じ問いを立て直さない。

## 作業単位と依存

通常の作業の見込みは能動時間であり、実検査・ビルド・測定・独立レビュー・回答待ちは後の一表で分ける。各単位の末尾は、下の検査記号に割り当てた一回の work と独立レビューの対応を閉じる。担当の自己点検で独立レビューを代用しない。UB30 の2単位は済みとして残し、残りの時間へ再加算しない。

| 作業単位 | 目的 | 依存 | 担当・能動時間 | 検査・完了の条件 |
|---|---|---|---|---|
| UB30.01 境界文書と転記案（済み） | Q9(c) の境界文書と転記案 | UB10/20、R/K の結果 | Codex、実施済み | [UB30.01b 追補後の結果](ub30.01/results.md)。再起動しない。H31 は未完として分離 |
| UB30.02 独立レビュー（済み） | 境界文書を独立に点検 | UB30.01 | 独立レビュー、実施済み | [RV-UB30](reviews/RV-UB30.md)と UB30.01b で指摘対応済み。レビュー枠を再加算しない |
| V10.1a 申し送り・関係状態の確定 | 棚卸しと K10 の証拠の保全を閉じる | K10 の段の閉鎖、UB30、PM/IF の結果 | Codex、0.5〜1時間、独立レビュー | W-D。33項目の行き先・既存判断・未確認を固定し、F-Q の引用票の初版を作る |
| V10.1b 回帰・J2 の差分案・UB30.01-1 の局所比較 | 旧 send の E0501 の再現と版追随の案、固定範囲の利用者操作の証拠不足を閉じる | V10.1a、J1/J2 の決定 | Codex、1〜3時間、独立レビュー | W-R または W-D、F-L。版依存の登録・テストは変えない。UB30.01-1 の手書き期待値を実行前に固定。書き出せなければ未確認として返す |
| V10.2a 設計書の最終照合 | 現在の仕様・実装・保証の整合を閉じる | V10.1b の修正・判断、UB30 の指摘対応 | Codex、1〜2時間、独立レビュー | W-S。H03/04/07/09/11/12/15/18 の照合表とリンク・見出し・用語が一致する。設計書・コメントに作業の ID を書かない |
| V10.2b 英語 reference・Skill・生成物 | ハーネスと LLM が読む現在の契約をそろえる | V10.2a | Codex、1.5〜3時間、独立レビュー | G、W-E、必要な M。H06/13〜21 を全ファイル一覧で閉じ、日本語訳への変更一覧を作る。reference・Skill・生成物・コメントに作業の ID を書かない |
| V10.3a 版・訳・README・CHANGELOG の最終編集 | 版・訳・変更記録を一作業で候補へそろえる | V10.2b、J1/J2 の決定、V10.1b の差分案と局所比較、設計者のリリース準備の指示、必要な性能判断 | Codex、1.5〜3時間、独立レビュー | G、W-V。0.0.13、二 lock、英語と日本語の対応、固定参照、DET-09、ライセンスをそろえ、登録・help・版依存のテストと testdata を同時に変更し、編集済み候補 CANDIDATE を渡す。訳・README・CHANGELOG・コメントに作業の ID を書かない |
| V10.1d 版上げ後の全比較の影響段 | 変わった入力の書き出しと読者の比較・最終 manifest を更新する | V10.3a、範囲・見込みへの設計者の了承、formal_build と交換実行ファイルの引用確認 | 取りまとめ、能動0.5〜1時間、独立レビュー | F-U、W-D。H31 の範囲の実ソースも含む。成功した不変段は引用し、件数減少・想定外の除外は停止。新旧入力・出力のハッシュと差を保存 |
| V10.1c 改造全体の回帰 | 全実装・文書・版の関係状態で change を閉じる | V10.3a、V10.1d の成功と引用票、全 work と独立レビュー、最後の M の判断。ここでリリース準備の検査へ入る | 取りまとめ、能動0.5〜1時間 | C、T-D/T-C、F-Q。必要な全単位の成功または適格な引用、件数・失敗履歴と環境を保存する |
| V10.3b 候補の勧告の再照合 | 二依存対象と四ツールの照合・報告をそろえる | C の記録、候補 CANDIDATE の固定、Lean/elan の引き渡し | 取りまとめ、能動0.5〜1時間 | A。依存は release の A に任せ重ねない。四ツールの一次資料・固定版・実版・未照合・最初との差を記録する |
| V10.3c 公開候補の release と手動照合 | 実 CLI・同梱物・回帰の証拠・配布対象を候補へ結び付ける | C、V10.3b の準備、候補 CANDIDATE の取り込み | 取りまとめ、能動0.5〜1.5時間、独立レビュー | R、P、F-Q。release_stack 成功10件、勧告の対象別状態、実 CLI と全 Skill 論理名・本文ハッシュ、ソースの内容の一致を確認する |
| V10.3d 受け入れと項目整理・保管 | 設計者が証拠を受け入れ、未完を残して改造を閉じる | V10.3c、最終独立レビューと必要な修正の完了 | 設計者・取りまとめ、能動0.5〜1.5時間、回答待ちは不明 | W-D、F-Q の差分確認。設計者の受け入れを記録してから、取りまとめが docs/todo を整理し改造を保管する。操作の担当と結果を残す |
| V10.3e 集約後の候補・ソース配布と公開 | 最終公開コミット・タグ・ソースの証拠をそろえる | V10.3d、集約文の承認、公開操作の指示 | 取りまとめ、能動0.5〜2時間 | P-final、F-Q。集約前後の木が一致し、commit 依存の報告とソース配布を最終状態で確認する。push は明示指示後だけ |

順序は、済みの UB30.01/.02 → V10.1a/b → V10.2a/b → 最後の必要な M と判断 → 設計者のリリース準備の指示 → V10.3a → 範囲と見込みの提示・了承 → V10.1d → V10.1c → V10.3b/c → V10.3d/e である。V10.3a で版上げと関連入力を一緒に更新し、その状態の影響段を V10.1d、改造全体の回帰を V10.1c が受け持つ。採用時に取りまとめが plan の順序へ転記する。

### UB30 と V10.1 の対象・手順

UB30.01/.02 は B_WORK に取り込み済みである。境界文書と TODO-302/054 への転記は [ub30.01/results.md](ub30.01/results.md) の UB30.01b 後の本文を正とし、独立レビューは [RV-UB30](reviews/RV-UB30.md)を引く。古い未完の文案を転記しない。H31 の義務は K10.2 で未完であり、V10.1b の局所比較と V10.1d の最終関係状態の確認まで、既存の成功へ広げない。

V10.1a は `v10.1a/` に棚卸し、引用票、以後の変更の一覧を作る。PM/IF/SH2 は既存の結果と取りまとめの受け入れの有無を確認し、実装済みへ読み替えない。K10 の七つの交換実行ファイル、ソース・設定・固定版・台本の保存ハッシュを照合する。巨大な manifest の再生成や再比較は行わない。

V10.1b の成果物は `v10.1b/` の再現入力・独立期待値・差分案・影響一覧と、UB30.01-1 の固定入力である。H10 は J1 で後へ回したため診断文言を変更しない。H11 の `typeck/scope/lower.rs` と 01-06 は記録位置を照合し、振る舞いの変更が必要なら J3 へ戻す。対象の代数、被覆、局所解析、七 IO の規則を新たに変更する単位ではない。

J2 では、先頭に `language "0.0.12"` を宣言した入力で、旧 `Http.send` の節だけのハンドラに Connect が残り E0501 となることを、版上げ・登録の前に公開入口で再現する。期待する診断コードと位置を実行前に固定し、通常受理の対照と区別する。再現できなければ未確認と理由を返す。登録後は先に E0908 で拒否されるため、この再現を V10.3a へ送らない。

登録の差分案には `modules/package.rs::BREAKING_CHANGES` の `Version(0, 0, 13)` の行、`modules/text.rs` の事実だけの英文の要約と help、登録表を読むテスト、`modules/tests.rs::language_versions_check_the_release_boundary_in_each_header_location` の期待値（0.0.12 → E0908、0.0.13 → 受理、0.0.14 → E0907）を含める。文案の例は summary: “Handlers with only an Http.send clause are partial handlers; Http.Connect remains unhandled.”、help: “Benitoite 0.0.13 includes additional Http operations; handling Http.send alone leaves Http.Connect in the effect contract.” とし、再現と照らして独立レビューで確定する。節の書き換え方・手順・移行例は加えない（Q2）。この段階では登録・文言定数・版に依存するテストを適用しない。

書き換えるファイルの一覧を内容・役割ごとに保存する。B_WORK では `language "0.0.12"` を含む testdata は50ファイルである。テストの版文字列は統合の5ファイル（`cli_process.rs`、`package_command.rs`、`spec_examples.rs`、`test_command.rs`、`desugar_export/named.rs`）と src 内の4ファイル（`modules/tests.rs`、`modules/hash.rs`、`external/tests.rs`、`typeck/tests/diagnostics_batch4.rs`）を含む。`modules/package.rs` 内の登録表のテストも別に確認する。ハッシュを照合する依存の期待値（hash-match/hash-mismatch と package コマンド等）は、header の更新後の内容に対して文書化されたハッシュ規則で再計算する案を作る。`testdata/packages/{dependency-settings,newer-config,newer-language,older-language}.diag.json` は、現在版を表示する文と、古い宣言へ版順に加わる0.0.13の note/help を区別して列挙する。旧版を狙って拒否する入力・過去の説明は一括置換しない。50ファイル・9テストファイルは読解時の候補数であり、V10.1b で完全なパスと変更理由・依存ハッシュの変更先を固定する。

UB30.01-1 は既存の `tests/desugar_export/range-sources/expected.json` に case を足す方法を採る。入力の追加先も同ディレクトリとし、Report.save/Audit.log の同じ狭い型を節から File.writeTextIn へ渡す例を元にする。終了・定義数・署名の非 Top の添字・候補欄を除く非 Top の数・期待する効果と全定義の検査を、処理系の出力から作らず実行前に手で書いてハッシュを固定する。F-L で既存の書き出しと六入口を局所確認する。利用者操作の署名を書き出せず対象外になった場合は、本単位で交換器を拡張せず、未確認のまま取りまとめへ返す。expected.json の変更で K10.3b の入力ハッシュが変わるので、範囲の実ソースの最終確認は版上げ後の F-U に含める。局所成功だけで F-Q の義務の行を閉じない。

読めば確定する記録位置の相違は文書照合へ渡す。実行しないと分からない受理差は、既存の公開入口による短い入力と独立期待値で確かめる。未確認を消すための無目的な大入力は作らない。テストを変える場合は公開 test-audit の作成時の関門を通し、J2・H31 で決めた範囲を超えて通常 source・testdata・交換に触れる前に J3 を適用する。回帰を再現したらその枝で直すか後へ送るかを設計者へ返し、失敗を次の作業へ送って完了にしない。

### V10.2 の対象・手順

V10.2a は次の設計書と、その参照・目次・用語集を対象とする。実装を読んで現在の決定と照合し、未実装の項目を現行設計書へ加えない。01-12 の Lean の写しを変える必要があれば J3 で停止する。

| ファイル群 | 最終照合の内容 |
|---|---|
| 00-01、00-03、00-04、必要なら AGENTS.md の要約 | 型・エフェクトへの適合と対象の静的な上限、現在の保証、実行時権限制御・情報フロー制御の未実装、ハーネスの役割。目的や原則そのものを再設計しない |
| 01-02、01-06、01-07、01-12 の対応 | 閉じた範囲引数・Top・被覆と構造上の包含・不変添字・局所性・記録位置・節の S・全操作と部分ハンドラ。H11 は既存の規則を広げず表現を合わせる |
| 02-05/06/08/09/10、03-06/07/09、06-01/04/06 | 必須判定と後段警告の分離、保持、十三入口、実効 endpoint、診断理由、bounds/expanded、名前だけの照合、doc の空の Effects の意味 |
| 07-01、07-03、07-04 | 信頼する io_target と文字列解析・書き手の境界、OS/DNS/TLS の保証外、四水準と引用、全比較が閉じた範囲と H03/H25 の限界。単一ビルドや有限比較を意味保存の証明としない |

番号参照は `r30.5/r30.5b-number-references.json` の検索式を使い、後の変更で増えた箇所を調べる。見出しを改名する場合は spec 印・コードコメント・生成器の参照を同じ変更で直す。構文や規則を変える必要がある修正はこの文書単位で進めない。

V10.2b は `docs/reference/benitoite.md`・`install.md`、`crates/benitoite/skill/SKILL.md` と手書きの `references/{inspection,idioms,common-mistakes,language-comparison}.md`、生成器の出力と `src/cli/tools/skill/bundle.rs`、`v10.2b/` を対象とする。`benitoite-minimal.md` は過去の範囲の説明なので現在版へ機械的に書き換えず、リンクだけ照合する。

H13〜19 の内容を現在の英語へそろえ、ハーネス経由の利用を主にする。固定参照が説明する契約の版と見出しを一覧にする。新しい範囲の説明は候補 `v0.0.13` の対応する見出しへ固定し、既存必須欄の説明だけを指す旧版参照は意味を確認して残せる。まだ存在しないタグを取得成功とせず、候補内の文書の見出しを照合する。

生成参照を手で直さず G で再生成し、生成元・生成物・bundle の差分を点検する。標準宣言や生成器本体の修正が必要なら J3 へ戻す。既存のハンドラ棚卸しの対象一覧と文書内の全操作の数、別名、完全／部分の例を照合し、外部件数は不明のまま残す。日本語訳については全英語ファイルの変更一覧と対応表を作り、翻訳そのものは最後の V10.3a にまとめる。H20/H21 の CHANGELOG 文案も結果へ渡す。

### V10.3a の対象・手順

編集対象は `crates/benitoite/Cargo.toml`、ルートと fuzz の `Cargo.lock` の benitoite 項目、README、CHANGELOG、英語の版表記、`docs/ja/reference/{benitoite,install}.md`、`docs/ja/skill/SKILL.md` と手書き参照4文書、必要な生成物、`modules/package.rs`・`modules/text.rs`・登録表のテスト・`modules/tests.rs`、V10.1b で固定する testdata・依存ハッシュの期待値・`.diag.json`・tests の版文字列と `v10.3a/` である。ワークスペースの Cargo.toml や fuzz パッケージ自身の版を一律に上げない。J2 (a) の登録・help・表のテスト・language 宣言・版依存の期待値は本単位で版上げと同時に適用する。V10.1b では差分案と影響一覧だけを確定する。

設計者のリリース準備の指示を得てから、版を0.0.13へ上げ、二つの lock のパス依存を対象を絞った更新で同期する。一般の依存更新は行わない。0.0.12 の [Z01a](../2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/z01a/results.md)・[Z01b](../2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/z01b/results.md)の分担を参考に、版・登録・help・表のテスト・testdata・依存ハッシュ・CHANGELOG を一作業で変更する。登録だけを先に適用して50の入力を E0908 で除外しない。英語の最終差分を全て訳へ対応付け、原文の版・見出し・コードの同一性を確認する。生成参照に対応する日本語訳が現にないものは、訳を新設せず英語の全出力を別表で照合し、日本語を同梱 Skill へ加えない。

CHANGELOG には H20 の決定済みの事実と H21 の採択した事実を短く書く。README の現在版と変更記録へのリンクを更新し、現在版のラベルを「changes and migration」とする必要はない。0.0.13 の移行案内・移行例・手順・性能増減を作らない。古い版の変更履歴を0.0.13の手順へ機械的に書き換えない。

版・訳・CHANGELOG・同梱物の最終編集をこの一作業で終え、その後は照合と記録に限る。生成物や版固定リンクの変更を残したまま change へ進まない。埋め込む Skill と版固定リンクの編集は V10.2b で済ませ、最後の必要な short と判断をこのリリース準備の起動前に終える。本単位の版・登録・help・テスト・testdata・依存ハッシュ・訳・変更記録の差分は、測定経路の意味と入力が不変と確認できる場合に限り、根拠を記して直前の性能判断を維持する。確認できなければ準備前の見積もり・判断へ戻す。生成物や埋め込む文に追加修正が必要になったら、いったん V10.2b の編集・測定の区切りへ戻し、準備後に測定を追加しない。

## 全比較の入力と引用

### 版の番号が含まれる場所

V10P では書き出しを実行せず、現行の書き手・読者を読んで次の区別を確認した。

| 場所 | 製品版が入るか・根拠 | V10 での扱い |
|---|---|---|
| コア／Surface／標準表／coverage の交換 JSON | `tests/desugar_export.rs::CorpusStream` のヘッダは corpus15、sidecar7、`coverage_export.rs` は版4を数値で書く。交換の書き手に CARGO_PKG_VERSION・build_info・producer の参照はない。製品版をこれらの schema の数値へ書かない | 製品版の変更だけを理由に交換形式を上げない。ただし loader の版判定が入力の受理へ影響する可能性は別に確認する |
| 全比較が呼ぶ実 CLI の check/test 報告と保存ログ | `cli/build_info.rs::producer` は CARGO_PKG_VERSION と build を持つ。`formal/tests/test_range_sources.py::check_reports` は stdout を report-subset のログへ保存し、`test_range_known_differences.py` も報告をログへ保存する。したがって保存物全体には製品版が入る | 「全比較の書き出しには一切入らない」としない。意味の比較は終了・complete・Effects・コード・理由等を選んでおり producer を比較しないが、古いログの producer を新候補の版の証拠にしない。P で候補の報告を新規取得する |
| ビルドと言語版の受理 | `build.rs` は commit/dirty/target の由来を埋め、`modules/package.rs::check_header` は CARGO_PKG_VERSION を使う。`modules/tests.rs` は現製品版と将来版の期待を固定している | J2 (a) に従い V10.3a で版と登録・テスト・testdata を同時更新し、影響する書き出しと読者は V10.1d で再確認する。版上げだけで全関係状態がバイト一致したとはしない |
| testdata の header と `.diag.json` | `desugar_export.rs::discover` は `.bnt` と `.mode` を持つディレクトリを発見し、`export_desugar_corpus` が `.mode` と `pipeline::check_path` の結果を読む。`.files` 内は独立入力として探索しないが、依存として loader が読む。`.diag.json` は書き出し器の入力ではない | header は loader の受理に効く。0.0.12 のままなら E0908 による除外で比較範囲が減るので、成功用の header と依存ハッシュを更新する。0.0.12 → 0.0.13 は同じバイト数であり位置をずらさないが、受理・診断・依存の読み込みの結果まで不変とは断定しない。`.diag.json` の文言変更自体は golden の入力で、交換の変更理由とはしない |

### 作業単位ごとの入力への影響

ここで「触れる」は変更することを指す。読解とハッシュ照合は変更に含めない。対象を限定しても、実際の差分が広がれば判定をやり直す。

| 作業 | 処理系ソース・標準ライブラリ・testdata | 書き出しテスト・Lean・check-formal と読む台本 | 引用判断と停止 |
|---|---|---|---|
| UB30.01/.02、V10.1a | 触れない | 触れない | 文書と結果だけなら F-Q の以後の変更へ追加する |
| V10.1b | J2 は再現資料と差分案だけで、版依存のソース・テスト・testdata は変更しない | H31 は range-sources の入力と expected.json を追加。Lean・書き出し器の機能は変えない | F-L で局所比較し、既存の範囲の実ソースの入力ハッシュは変わると記録。最終状態の再確認は F-U。書き出せなければ未確認として返す |
| V10.2a | 触れない | Lean の写し・意味を変えない説明だけ | 設計例は work/change の入力にはなりうる。全比較が読む source と別に扱い、01-12 の規則変更は停止 |
| V10.2b、V10.3a の文書・生成物 | 文書の差分では標準ソース・testdata は触れない。版上げの testdata は次行へ分ける。bundle.rs は埋め込む Skill の索引として変更されうるため、処理系ソースへの接触あり | 交換テスト・Lean・台本は触れない | bundle.rs に差分が必要と分かった時点で J3。文書が全比較 corpus に自動収集されると仮定せず、収集範囲を確認する。候補の Skill は新規に照合する |
| V10.3a の版・登録・テスト・testdata | manifest/lock、modules/package.rs・text.rs、版依存テスト、testdata の header・依存ハッシュ・診断期待値を変更する | named.rs の固定パッケージの header も更新。Lean・交換形式の版・規則は変えない | J2 の適用範囲は確定済み。影響する書き出しと読者を下表から選び、F-U 起動前に範囲と見込みを示して了承を得る |
| V10.1d | 検査だけ。版上げ後の CLI と書き出しを使う | 下表の影響段と最終 manifest を更新。不変の段は引用 | 了承前は起動しない。想定外の変更・件数減少・除外増加は J3。全比較の入口全体を一括で呼ばない |
| V10.1c、V10.3b/c | 検査・照合だけ。実行器の生成物は作る | 全比較・交換の再書き出し・manifest 再生成をしない | 生成照合が差分を作った場合も修正を始めず入力変更を判定する。失敗は原因を調べ J3 を適用する |
| V10.3d/e | 改造文書の移動・相対リンクと履歴の整理。実装入力を変えない | 同左。保管で現行の台本が読むパスを動かす必要があれば停止 | 木の比較だけで候補の producer を引用せず P-final を行う。改造内の実入力を移動する場合は参照元と bytes の維持を確認する |

### V10.1d: 版上げ後に走らせ直す段の判定

判定の根拠は `scripts/check-formal.sh` の段の順序、`desugar_export.rs` の収集と `CorpusStream`、`desugar_export/named.rs::export_extensible_package`・`export_extensible_source`、`desugar_export/interval.rs::export_interval_manifest`、`range_sources.rs`、`check_named.py`、`scripts/check/formal_interval.py` の collect/manifest/verify である。V10Pb ではこれらを読んだだけで、再書き出しや比較は行っていない。

| 入力の変化と書き出し | 影響を受ける読者・後続段 | 実行または引用の条件・見込みの根拠 |
|---|---|---|
| testdata の header・依存ハッシュと現在版の loader。`export_desugar_corpus` を再出力する | named-programs の corpus/builtins/stdlib/coverage と同時に作る区間 manifest/material/observations。一般 corpus を読む desugarDiff・builtinCheck・surfaceCheckAll・coverageProgramDiff・check_named の該当部分、区間の collect と実ソース比較、最後の manifest/verify | 再出力は K10.3 の22分23秒が参考値。旧新の各出力の SHA-256 と入力別の識別子・受理/除外・定義数を照合し、変わった出力を読む段だけ再実行する。header の数字は交換 JSON にそのまま載らないため、ハッシュが同じ出力の読者は引用できる。50ファイルの独立探索と依存としての読まれ方を両方照合し、E0908 で範囲が減った状態は受け入れない |
| `named.rs::export_extensible_package` の二つの language 宣言、`export_extensible_source` の d6c パッケージ、`export_interval_manifest` の json-wasm-same/wasm-regex-same が読む依存 header | 該当する named の六入口と、manifest の区間の実ソース比較 | これらの書き出しを個別に再確認し、出力の差で読者を選ぶ。固定ソースだけを読む identity/range/vm、batch 群、coverage_export の乱数・境界の出力は、ソース・標準表・設定が不変なら K10.3 を引用する。通常 work の成功を交換比較の成功へ読み替えない |
| H31 の range-sources/expected.json と新しい固定入力 | `export_range_sources` → `formal/tests/test_range_sources.py` の六入口・拒否・報告側、`formal_interval.py::range_counts` と最終 manifest/verify | F-L の結果を保持し、版上げ後の F-U でも範囲の実ソースの段を確認する。expected.json を固定パスで読むため既存段のハッシュが変わる。既存成功群と追加群を別に数え、署名の非 Top と prim への転送の二点を記す。書き出せなければ未確認を残す |
| `.diag.json` の現在版の文と E0908 の note/help | golden。交換の書き出しは `.diag.json` を読まない | W-V に `--test golden` を含める。これだけの変更で交換の読者を再実行しない。loader の実診断を変える登録は上の corpus の行で別に評価する |
| 新旧出力と読者の結果がそろった状態 | `formal_interval.py collect`、変更した区間出力を読む比較、入力一覧と最終 manifest/verify、必要な check_named の最終件数照合 | collect は新旧を混ぜない出力集合へ行う。不変の成功出力は来歴とハッシュを記した上で再利用し、古い input-manifest を新出力へ流用しない。check_named 全体が必要なら、内部で不変群を再度呼ぶ範囲も了承時に示す。manifest の約6分57秒、verify の約37秒、check_named 全体の約5分49秒を参考にする |

影響段の暫定枠は45〜75分、初回の Rust/Lean ビルドと成果物の再取得は別に不明である。一般 corpus の再出力約23分、変化した読者と差分照合・範囲の実ソース・集約・manifest/verify に約22〜52分を置く。区間の出力が変わればそれを読む段も含める（K10.3 の区間段全体は約15分18秒）。V10.1d の起動前に取りまとめが V10.3a の実差分、残る成果物・七実行ファイルのハッシュ、空きメモリと短い局所確認の実績からこの範囲を更新し、実行する段・引用する段・コマンド・時間/RSS・未確定分を示して設計者の了承を得る。計画の採用だけで実行の了承としない。見積もれない追加段は短い試行の範囲を提示し、了承前に長い実行へ進まない。

### F-Q: 最終の関係状態への引用票

V10.1a で作り、候補 CANDIDATE と保管・集約後の公開状態で更新する。元は [K10.3 の全比較の判定と K10.3b](k10.3/results.md)、[独立レビュー](reviews/RV-K10.3.md)である。元の HEAD/B_WORK `d35557f93ca65e73a841a17d6f19f1b79cf04464` と未コミット差分、K10.3b の最終状態を、V10 開始版へ取り込んだ内容と照合する。元の HEAD だけを比較する方法は使わない。

| 07-03 の欄 | V10 の保存と判断 |
|---|---|
| 対象の状態 | 元の B_WORK/HEAD、引用先 B_WORK/HEAD の完全 ID、差分の有無と全一覧、別状態への未コミット差分と未追跡入力の内容の SHA-256。元は source-state.json.gz と k10.3b-final-state.json.gz、保存差分を使う。V10P の inputs.json は計画入力の一覧であり、この証拠の代わりではない |
| 検査の入力 | 処理系ソース・標準ライブラリ・testdata・独立入力と期待値・全書き出し元・生成元/物・manifest・設定・二 lock・Cargo/build.rs・固定版・七実行ファイル・check-formal.sh と読者の版/ハッシュを同定する。版・Skill・訳など変わった項目は無視せず、どの段が読むかを別表へ書く |
| 実行 | 一回目全体の終了1・外側2403.15秒と先行する出力先の終了2を保持。成功段を引用し、修正した corpus 三入力の必須欄と NoMainFile の読者、失敗・未到達段の再確認の正確な引数・終了・時間/RSS・件数・構成・ツール版・環境制限を元の各 JSON/log へ結ぶ |
| 件数と範囲 | 六入口、coverage 10,020/10,028、脱糖73,853定義、組み込み144,932比較、プログラム網羅性22,483、表層51,742一致・対象外19等を元集計と照合。独立範囲は12群57とTop互換3群、報告26入力50コマンド、三拒否の個別照合と予算2件の直接比較を区別する。候補欄だけの非 Top を成功へ数えない。区間・VM・既存除外と fuel 試行も残す。「OpRef と固定範囲の利用者操作」の義務は K10.2 で未完（RV-UB30）であり、既存の成功で閉じた扱いにしない。H31 の署名の非 Top と prim への転送は F-L/F-U の追加結果と別に照合し、書き出せなければ未確認のまま返す。版上げ前後で既存の受理・比較件数が減っていないことを確認する |
| 引用 | 元の結果と F-L/F-U の相対参照、以後の全変更、段ごとの再実行または影響しない理由、判断者・日付を候補ごとに記す。古い CLI の producer は意味の比較の証拠に限り、新候補の版・commit・同梱物には P/P-final の新しい証拠を使う |
| 修正 | 初回の欠落、NoMainFile、再出力1,009件のうち1,008件不変・corpus差414 bytes、K10.3b の値を変えない assert/policy の追加と説明の訂正を保持。以後の変更が読者や入力に及べば J3。引用不能な検査と理由を明記し、実行は設計者の判断を待つ |

元の巨大な出力をもう一組複写する必要はない。根拠になる入力・出力・台本は改造内へ保存し、大きな生記録は大きさと SHA-256、再生成手順と保存範囲を残す。target の消失を入力一致の確認済みに読み替えない。必要なハッシュが欠ける場合は未取得を記し、設計者へ返す。

## 検査の割り当て

以下は将来の実行用であり、V10P は dry-run だけを実行する。`<B_WORK>` は起動時に取りまとめが直前の取り込みの完全 ID へ置換する。全ての check.sh の実実行の直前に、同じ指定へ `--dry-run` を付け、選択・理由・包含・見込みを確認する。実検査は macOS で `/usr/bin/time -l`、Linux 等では `/usr/bin/time -v` で対象を直接包み、check.sh 自身の終了と計測器の終了を分けて保存する。RSS の原値・単位・MiB/GiB と環境制限も残す。

| 記号・水準 | 正確なコマンド・対象・選択の条件 | 担当・時期・保存先 |
|---|---|---|
| W-D: work 文書・記録のみ | `scripts/check.sh --level work --base <B_WORK>`。文書だけなら選択なし。相対リンク・見出し・出どころ・用語を読解で確認。補助 Python を改造文書に置く場合は実行せず ast.parse で構文を確認する | 当該担当、単位末一度、各小文字 ID の results.md。UB30.02 はレビュー記録だけなら実テストなし |
| W-R: work 回帰修正 | `scripts/check.sh --level work --base <B_WORK>`。Rust の共有入力を変えるため `--test` を省略して全統合を選び、既定 lib 全件・clippy・fmt・生成物・集計も各一度。J2・H31 で計画した範囲、または J3 の判断後に実行。途中は関係する局所検査だけ | Codex、V10.1b、v10.1b/。H31 の fixture だけなら `--test golden --test desugar_export` で読者を指定し、自動選択を dry-run で確認。資料だけなら W-D |
| W-S: work 設計文書 | `scripts/check.sh --level work --base <B_WORK>`。仕様例・skill_docs・skill_generated・spec_tally 等の自動選択を確認。01-spec/ または付録08-04 の text 例の変更時は `spec_examples` を含むことを必須とし、別の Cargo 実行を重ねない | Codex、V10.2a、v10.2a/。分類だけで漏れる読者があれば起動前に対象と根拠を名指しして計画へ追加する |
| G: 生成・版同期 | 生成元を変えた同じ単位で `cargo run -p benitoite --example gen_skill`。V10.3a の版上げ後は `cargo update --offline -p benitoite`、続けて `cargo update --offline --manifest-path fuzz/Cargo.toml -p benitoite`。二 lock の benitoite 項目以外の変化を確認し、一括更新しない | Codex、V10.2b/V10.3a。bundle.rs の変更が必要なら先に J3。W-E/W-V の skill_generated は鮮度の照合であり手動編集の代替ではない |
| W-E: work 英語・Skill | `scripts/check.sh --level work --base <B_WORK> --only tests_related,skill_generated,spec_tally --test reference_examples --test skill_docs --test skill_examples --test stdlib_doc_examples --test spec_examples`。Rust ソース・bundle.rs を変えず文書と生成参照だけで閉じる場合の指定である | Codex、V10.2b、v10.2b/。bundle.rs 等の Rust を変える承認が出た場合はこの部分選択を使わず W-V の自動 work と読者へ広げる |
| W-V: work 版・訳・最終編集 | `scripts/check.sh --level work --base <B_WORK> --test spec_examples --test reference_examples --test skill_docs --test skill_examples --test stdlib_doc_examples --test build_info --test cli_process --test package_command --test test_command --test declarations --test golden --test desugar_export`。manifest/lock の変更から lib 全件・lint/fmt・licenses/advisories 等も自動選択することを dry-run で確認 | Codex、V10.3a、v10.3a/。必要な `build_info` の ignored は C の long_only に含める。新しい意味の変更をこの単位へ追加しない |
| F-L: H31 の局所書き出しと六入口 | `BENITOITE_DESUGAR_DIFF_DIR=<局所の絶対出力先> cargo test --test desugar_export range_sources::export_range_sources -- --exact --nocapture`。CLI を `cargo build -p benitoite --bin benitoite` で用意し、`python3 -B formal/tests/test_range_sources.py --exports <局所の絶対出力先>/range-sources --cli <CLIの絶対パス> --output <局所比較の出力先>` | Codex、V10.1b、一度。約1.7秒は旧局所比較の参考値で、書き出し・新入力・CLI ビルドは別に未計測。手書き期待値を先に固定する。Lean の六交換実行ファイルを要し、既定ビルド・ソース・lake 設定・固定版・実行ファイルのハッシュが K10.3 と同じなら formal_build と実行ファイルのビルド成功を引用。欠落・不一致なら新規ビルドの範囲と見込みを取りまとめへ返す |
| F-U: 全比較の影響段の再確認 | V10.1d の影響表と下の F-U1〜3。`scripts/check-formal.sh` 全体は起動しない。開始前に入力差分とコマンド・引用範囲・見込み・資源を具体化し、設計者の了承を得る | 取りまとめ、V10.3a 後の V10.1d、一度。能動0.5〜1時間、実行45〜75分＋初回ビルド等不明、v10.1d/。F-L と同じ版上げ前の状態を反復する実行とは区別する |
| F-U1: 変わる入力の再書き出し | `BENITOITE_DESUGAR_DIFF_DIR=<F_OUT> cargo test --test desugar_export export_desugar_corpus -- --ignored --exact --nocapture`。同じ出力先で `cargo test --test desugar_export named::export_extensible_package -- --exact --nocapture` と `named::export_extensible_source`、`range_sources::export_range_sources` を各同じ指定で実行する。`export_interval_manifest` は `<F_INTERVAL>/manifest` を出力先として同じ指定で実行する | 取りまとめ。新旧の全出力のハッシュと個々の入力の分類を比較し、F-U2 を絞る。`<F_OUT>`・`<F_INTERVAL>`・`<F_COV>` は既存結果を壊さない別々の絶対出力先に固定。不変の保存物は根拠を付けて引き継ぐ |
| F-U2: 変わった出力を読む段 | `formal/.lake/build/bin/desugarDiff <F_OUT>/named-programs-corpus.json <F_OUT>/report.json`、`formal/.lake/build/bin/builtinCheck <F_OUT>/named-programs-corpus.json <F_OUT>/named-programs-builtins.json <F_OUT>/builtin-report.json`、`formal/.lake/build/bin/surfaceCheckAll <F_OUT>/named-programs-corpus.json <F_OUT>/named-programs-builtins.json <F_OUT>/named-programs-stdlib.json <F_OUT>/surface-check/report.json`、`formal/.lake/build/bin/coverageProgramDiff <F_OUT>/named-programs-coverage.json <F_OUT>/named-programs-builtins.json <F_OUT>/coverage/report.json` のうち入力が変わるもの。named の該当群・六入口と最終件数は `python3 -I crates/benitoite/tests/desugar_export/check_named.py <F_OUT> <F_COV>` が必要かを判定する。範囲の実ソースは F-L の Python 指定を `<F_OUT>` と版上げ後 CLI へ置き換えて確認する | 取りまとめ。check_named 全体には不変の群も含まれるので、全体を使う場合はその範囲も開始前に示す。全入力が不変の読者は引用する。各報告の親ディレクトリを先に用意する |
| F-U3: 区間の集約と最終保存 | `python3 -B scripts/check/formal_interval.py collect --interval-dir <F_INTERVAL> --desugar-dir <F_OUT> --coverage-dir <F_COV>`。区間の出力が変わった場合は `formal/tests/test_interval_exchange.py` の実ソースを読む段を、check-formal.sh の同段の全引数と更新した三出力先で具体化する。その後、同じ三引数で `formal_interval.py manifest` と `formal_interval.py verify` | 取りまとめ。区間・VM の不変の独立入力と比較結果は引用する。引数と実ソースの対象は了承前に確定。manifest は範囲の expected.json と最新結果も読むため更新必須。F-Q に実行と引用の合成、件数、時間/RSS、全ハッシュと初回失敗の来歴を残す |
| M: short | `python3 tools/bench/compare/run.py --tier short --state before=6124775788579e60530f55fb85570f26ef7fa900 --state after=<AFTER>`。取り込みの完全 ID、既存の全族の代表点・既定5標本。実入力の出力照合・校正後、採取15分超なら採取前に停止して点の削減と理由を記録 | 取りまとめ、処理系と埋め込む Skill を変えた取り込みごと、少なくとも最後の区切り。tools/bench/results/ と当該 results。文書・訳・メタデータだけで比較経路が不変なら理由と直前の判断を引用。準備後に追加しない |
| C: change | `scripts/check.sh --level change --base 6124775788579e60530f55fb85570f26ef7fa900`。既定/heap all-targets、stress lib/tests、doc、二 lint、fmt、規約、生成Skill、集計、Python、移行道具、policy、long_only、formal_build、advisories。候補の manifest/lock 変更による licenses も含める | 取りまとめ、V10.1c、一度。v10.1c/ と改造 results.md。現時点の16単位に、版上げの manifest/lock 差分による licenses が加わる17単位と omitted を実直前に照合。F-Q は別責任であり C の formal_build で代用しない |
| C の formal_build を引用する場合 | F-Q で Lean のソース・設定・固定版の一致を判断し、元の573ジョブ・終了0・sorryなしを引用する。残りは `scripts/check.sh --level change --base 6124775788579e60530f55fb85570f26ef7fa900 --only fmt,lint_default,lint_heap,test_default_all,test_heap_all,test_stress,doc_default,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests,licenses,policy_selftest,long_only,advisories` | 取りまとめ。候補の自動17単位を dry-run で確認した後、Lean ビルドを除く16単位の dry-run も保存。選択が変われば差を説明し追加する。引用と実行の組で C を閉じ、部分選択の終了0だけを change 全体の成功としない |
| T-D: derive の自己検査 | `cargo build -p benitoite --bin benitoite --example derive_inventory` の後に `python3 -B tools/derive/test_derive.py`。宣言情報・意味ハッシュ版4の読者と生成器・既存VMの接続。check.sh の migrate_selftests とは別である | 取りまとめ、V10.1c に一度、v10.1c/。C の all-targets はこの Python 検査を含まない |
| T-C: 比較道具の自己検査 | `python3 -B -m unittest discover -s tools/bench/compare -p 'test_*.py'`。探査の API 追随・二版のビルド・比較器。性能標本の採取ではない | 取りまとめ、V10.1c に一度、v10.1c/。V10 の同じ最終入力で既に実施した場合だけ07-03により引用する |
| A: 候補の勧告 | 二 lock は R の advisories に任せる。四ツールは `rustc --version --verbose`、`cargo --version --verbose`、formal で `lean --version`、`elan --version` を取得し、security-advisories スキルの一次資料を当日に照合する。rust-toolchain.toml、formal/lean-toolchain、Lean 担当の elan 引き渡しと実版を分ける | 取りまとめ、V10.3b/c。security-advisories.md、v10.3b/ と候補 results。道具の自動導入・更新をしない |
| R: release | `scripts/check.sh --level release --base 6124775788579e60530f55fb85570f26ef7fa900`。自動選択は release_stack と advisories の2単位。前者は `python3 -B scripts/check/run_ignored.py --kind release-stack --configuration release` で成功10件を要求 | 取りまとめ、V10.3c、候補 CANDIDATE で一度。v10.3c/ と改造 results。C の回帰全件を繰り返さない |
| P: 実 CLI・同梱物・ソース候補 | 下の「候補の照合」のコマンドと期待値。候補の完全 ID・差分・版・構成を固定し、新しくビルドした release バイナリのハッシュを残す | 取りまとめ、V10.3c。自動 R の終了0と分けて判定する |
| F-Q: 全比較の引用 | 上の引用票を読解・差分・ハッシュで更新する。`scripts/check-formal.sh`、ignored の export、比較の各段や manifest の再生成を起動する割り当てではない | 取りまとめ、V10.1a/c/d と V10.3c/d/e。計画済みの影響段は F-U、それ以外は J3 で停止 |
| P-final: 集約・タグ後 | P のうち `--version=json`、Skill の producer・本文ハッシュ、代表の報告、ソース archive の木・件数・内容を実公開コミットに対して確認する | 取りまとめ、V10.3e。意味の入力が同じなら C/R/F-Q の引用を更新。commit の違いだけで回帰全件を繰り返さない |

stage は新しい接続を予定していないため追加しない。R/K の段末の接続と全比較は閉鎖済みであり、V10 の文書・候補の整合は work と C/P が受け持つ。修正が新しい接続を作る場合は、J3 の判断後、読者を名指しした stage と根拠を計画へ追加する。

heap_checks は R20/R30 が既存表現を使い、確保器・根・障壁・安全点の不変条件を変えていない根拠を引き継ぎ、既定で再実行しない。V10 で保持や GC に及ぶ修正が出たら J3 と07-03の例外を適用し、次へ渡す前に doc・局所 heap/stress・必要な check-heap を新しい計画へ割り当てる。targets/full と LLM を呼ぶ Skill 評価は今回の対象外である。

### 候補の照合

P では次のコマンドを使う。`<候補例>` は R40.3 と K10.2 の固定入力から取りまとめが選び、期待値と SHA-256 を実行前に保存する。全比較の Python 台本を丸ごと呼ぶ代わりに、候補の公開 CLI の出力をこの固定期待値へ照合する。終了・単一報告・complete/executed・effects/bounds・コード/理由・producer を別々に確認する。

```sh
cargo build --release -p benitoite
target/release/benitoite --version=json
target/release/benitoite check --report=json <候補例.bnt>
target/release/benitoite test --check --report=json <候補テスト例.bnt>
target/release/benitoite test --doc --check --report=json <候補doc例.bnt>
target/release/benitoite skill list --format=json
target/release/benitoite skill show SKILL.md --format=json
target/release/benitoite skill show <一覧にある各論理名> --format=json
```

非 Top/Top、拒否、完全／部分ハンドラ・不足節、同じ狭い型の転送と射影の制限、純粋な処理後・利用者名非表示、同名の複数原子と冗長な宣言、未知/未完了、doc の check/error の空を確認する。名前だけの照合は、既存の副作用を起こさない固定例へ `run` と `test` の `--allow-effects=File.Write`、空の集合、不正な利用者名、範囲付きオプションを渡して受理／E0512／使い方の誤りを区別する。実 IO の新しい外部宛先を使わず、必要なローカル File/HTTP は R/K の制御した入力と相手を使う。

skill list の全論理名を show し、列挙漏れ・余分なファイル・本文の版・contentHash と候補ソースのレンダリング結果を照合する。生の SKILL.md の版プレースホルダと CLI の置換後の本文をそのままバイト比較しない。producer の版・commit・dirty の由来は、実候補のビルド条件と一致することを確認する。英語、訳、README、二 lock、ライセンス、生成物、ソースだけの配布の記述を一覧で照合し、実行ファイルを配布した扱いにしない。

候補 CANDIDATE の取り込み後に tar.gz/zip のプレビューを作る場合は、許可された出力先へ `git archive --format=tar.gz --prefix=Benitoite-0.0.13/ -o <候補tar.gz> <CANDIDATE>` と、format=zip の同じ指定を使う。未コミット候補を archive へ含めたとはしない。追跡木の一覧・ファイル数・実際の内容、二 lock、版、Skill、生成物、ライセンスを比較し、対象外の private/docs/todo/reference/work/target が入らないことを確かめる。タグ前のプレビューを正式なタグ付き配布物と呼ばない。

## 長い検査の中身・見込み・実行回数

V10P の [change dry-run](v10p/change-dry-run.log) は16単位、[release dry-run](v10p/release-dry-run.log) は2単位で終了0だった。これは開始時点の自動選択であり、将来の候補の選択の代わりではない。C では spec_examples と skill_docs が test_default_all に包含されて omitted だった。reference_examples 等の全統合も all-targets に含まれるので別に反復しない。

候補の版上げは manifest/lock を変えるため licenses が加わる。Lean のビルドを引用し licenses を含める C の残り16単位の[名指し dry-run](v10p/change-reuse-dry-run.log)、W-E の3単位と五統合ターゲットの[指定確認](v10p/english-work-dry-run.log)も終了0だった。名指しの確認は未来の差分を自動分類した証拠ではない。

時間の根拠は、直前の改造の [G01](../2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/g01/results.md)と [Z01](../2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/z01/results.md)、今回の結果に限る。過去の記録は時間運用の参考であり、現在の契約の根拠には使わない。

| 検査と中身 | 根拠と現在の見込み | 改造内で唯一か・再確認する条件 |
|---|---|---|
| C の通常・heap の workspace all-targets | 前版はそれぞれ3,058/3,072成功。今回の全統合 work は約8分、K10 の絞った work は約5分20秒。random_differential は test_default_all と test_heap_all に各300件・60秒の予算で含まれる。約46秒は既定だけ、heap は未計測。全ターゲット各構成の初回は不明 | 統合後の全件を各構成一度。他のビルドや並行の作業と同時に走らせない。以後に変わった読者だけ再確認 |
| C の stress lib/tests と compile_fail を含む doc | 前版は1,731成功と文書34成功。test_stress の random_differential は200件・60秒の予算で、今回の stress の時間は未計測。局所 H の約2〜2.5分を全件の所要へ外挿しない | 全件の stress と doc は C で一度。他のビルドや並行の作業と同時に走らせない。必要な局所安全条件は省略しない |
| C の long_only（heap と stress の ignored） | dry-run の固定表示は約15分＋ビルド。前版は二構成計58成功、個別時間なし。今回初回は不明。Scope 予算、深い構造、build_info の実ビルド等を含む。random_differential の三構成の予算は上の all-targets/stress の担当であり、この ignored 枠へ重ねない | 各構成一括一度。export_coverage/export_desugar_corpus は除外し、全比較の書き出しを成功へ足さない。成功0件を拒否 |
| C の二構成 clippy・fmt・規約・生成Skill・仕様集計・licenses | dry-run は clippy 各1〜3分、ほか数秒〜数分、licenses は共通設定の許諾一覧と依存の照合。前段の実績は work 全体内であり、この最終集合の個別時間は不明 | C で一度。examples のコンパイル/lint と全ターゲットのテストを区別。生成の変更は J3 を再判定 |
| C の Python 構文、移行道具・policy 自己検査 | policy は K10.3b で32件・約36秒。移行道具は dry-run の数分、今回の最終入力での初回は不明 | C で一度。Python 構文は tools の範囲であり formal の全比較を実行した意味にしない |
| C の formal_build | K10.3 の573ジョブ・終了0・sorryなしを F-Q の条件で引用する案。再ビルドの初回は不明、既存成果物を使う記録は約0〜29秒 | 既定は引用し再実行0回。入力変更なら J3。Lean の新しいビルドと全比較を混同しない |
| C 全体 | plan の暫定90〜150分を保持。前版の実績4,102秒＝約68分、現版の新しい全件時間は未計測。V10P の dry-run は約0.62秒であり実検査の見積もりではない | 改造全体の正式な change は一度。失敗・修正後は古くなった検査だけ再確認し、合成した判定を明示 |
| T-D と T-C | 前版は derive49件78秒、比較器39件227秒。今回 R30.5 の比較器自己検査39件は約129秒。暫定で各2〜5分、今回の最終入力では不明 | V10 の最終関係状態に各一度、または同じ入力の適格な結果を引用。性能測定ではない |
| R の release_stack | dry-run は約5分＋初回最適化ビルド。前版の R は勧告照合も合わせ142秒。現候補の初回ビルドは不明。暫定 R の実行枠10〜20分とし、未計測の初回ビルド費用は別に残す。キャッシュがあっても成功10件を確認する | 最終候補で一度。C の long_only と構成・対象が違う。後にビルド設定や枠を変えれば古くなる |
| C と R の advisories | dry-run は各1〜3分、初回 DB 取得は不明。二対象の状態・DB/lock/日時/構成を保存する | C と R で各一度、計二時点。候補の二 lock が変わる W-V の自動選択も別。四ツールの再照合は V10.3b で一度、取得不能を成功0件にしない |
| 全比較の不変段と影響段 | K10.3 は初回40分後に失敗、再書き出し22分23秒と必要な段の再確認で閉じた。F-U は45〜75分＋初回ビルド等不明。前版の本体43分57秒と旧計画の約16分をそのまま流用しない | 全体の再実行0回。不変段は F-Q で引用。J2 と H31 により変わる段だけ V10.1d で一度再確認する。起動前に範囲と更新した見込みを示して設計者の了承を得る |

長い検査を起動する前に、取りまとめは最新の差分と dry-run、短い work の実績、キャッシュと計算機の負荷を合わせ、検査の種類と全体の見込みを示して了承済みの範囲かを確認する。初回が不明の部分は、既存の局所検査を代表の一入力・一構成で短く試し、実行時間とビルド費用を分けて全件の見込みを更新する。期待値・件数・ignore・予算を縮めて正式な成功にしない。既存の短い試行の証拠で十分なら新しい試行を足さない。

random_differential は他のビルドや並行の作業と同時に走らせない。全体の見込みの2倍を超えそうな時点で進捗・遅い単位・負荷と残りを調べ報告する。タイムアウトの引き上げや件数削減をせず、失敗した単位を同じ条件で再確認する。長い新規実行の時間が見積もれない場合は、不明のまま開始せず短い試行の結果と上限を設計者へ示す。

## 項目整理・保管・公開と受け入れ

V10.3d は、全単位・独立レビュー・C/R/P・F-Q と未確認の一覧を設計者へ一組で渡す。終了0だけを受け入れとしない。設計者が受け入れた状態と日付、公開を許す範囲を記録し、取りまとめが次を行う。実装担当と V10P は docs/todo を読まず、転記案を改造内へ渡す。

| 対象 | 取りまとめが残す内容 |
|---|---|
| docs/todo の TODO-142 | 案4の中心の実装と証拠を閉じ、和の完全被覆・一般 glob/否定・範囲変数・部分ハンドラ・実体の対応・追加 IO の一般化まで閉じない。必要なら残りを分けて中心を閉じる |
| docs/todo の TODO-256 | 第一項・第三項の独立小モデル、第四項で案4が扱った範囲を記す。実行時拒否・情報フロー制御・サーバの接続を残し全体は閉じない |
| docs/todo の TODO-283・287 | 調べの採否・版の順序と SH/SH2 の学習・定理・本番未接続を記して調べを閉じる。hefty 本番候補・任意署名・由来の残りは閉じる前に行き先を確保する。HR の任意レビューの未実施を済んだ試作の未完へ変えない |
| docs/todo の TODO-269・154・109 | IF30 の八回答、受理表・信頼条件・方針項目、U01〜U14、P09 の今回分、実装前の書式境界を写す。未実装の三例や非干渉性を受け入れ済みにしない。項目を閉じない |
| docs/todo の TODO-302・054 | UB30.01b の後の ub30.01/results.md の本文と RV-UB30 を使う。表示・範囲引数・許可単位・後の由来、処理済み名が消える制約と UB30.01-1 の確認済み/未確認を残す |
| 登録済みの残り | TODO-022、296〜301、304〜308、313、314 について改造内の決定と転記済みの有無を確認する。費用・循環時の選択・一時の精度制限・Ix.WF・TLS取得抑止・manifest重複を重ねて新番号へ登録しない |
| J1 と RV-K10 の取りまとめ担当 | J1 は TODO-315 への送りで完了し再採番しない。H33 は README の記録済みの判断を照合する。H32 の逐次読み取りと TODO-314 の重複した manifest の課題の関係・既登録の有無を確認し、同じ論点を重ねて登録しない |
| 新規・未確認の候補 | 新たな勧告、未再現の反例、全体保持上限、E0521、追加の範囲付き IO/資源・二対象/再帰 IO、HostIn/EndpointIn 公開、scheme の精度等は既存の同じ論点へ追記を優先する。現象・再現有無・候補・未確認・判断を分け、取りまとめが運用規則に従って採番する |

転記・項目の閉鎖は取りまとめが非公開の別リポジトリ内でコミットする。公開の文書から同所へリンクせず、項目番号だけを文字で引く。今回の担当が禁止された領域を読む例外にはしない。

保管前には、取りまとめが `git grep -n -E 'work/|reference/' -- docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms` で候補を抽出する。`docs/reference/` などの通常の文書パス、禁止事項を述べる文、実際に work/・reference/ を出どころとして引くリンク・パスを読んで区別する。必要な入力・出力・台本を改造内へ写して相対リンクを直し、大きな生記録は大きさと SHA-256 を残す。単に検索0件にするために来歴を消さない。リンク解決と元資料の保存を確認してから、取りまとめが `git mv` で `docs/archive/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/` へ移し、深さが変わる相対リンクと参照を直す。設計書の章から保管先を引かず、以後は保管物を読み取り専用とする。

V10.3e は公開 git-workflow に従う。取りまとめが控えのブランチを残し、集約文の承認を得て前版タグ以後を一コミットへ集約し、集約前後の木の ID の一致を確認して軽量タグ `v0.0.13` を付ける。P-final で `--version=json` と全 Skill の producer、代表報告を作り直し、archive-and-bundle の `.claude/skills/archive-and-bundle/archive.sh archive v0.0.13` で tar.gz と zip を作る。正式出力の最上位は `Benitoite-0.0.13/`、名称は同スキルに従う。操作ログはソース archive と同じ出力領域に別記録として残し、最終の報告に公開コミット・タグ・producer の照合結果、ファイル名・大きさ・SHA-256・木との件数と内容一致を記す。保管済みの結果を追記で変えず、改造の根拠を work/ 内の出力へのリンクに置き換えない。

push は設計者の明示指示後に、取りまとめが `git push --atomic origin san_benito v0.0.13` で行う。控え・作業ブランチは送らない。受け入れ、集約文の承認、push の指示を同じものとして扱わない。

## 残りの時間

次表は検査・測定・レビュー・受け入れと公開までを含む一つの表である。時間は実行枠の合計の目安であり暦の所要ではない。V10 の11単位の能動時間は計8.5〜20時間、予備0〜1時間を加えて8.5〜21時間とする。V10.1d の能動0.5〜1時間と実行45〜75分を追加し、済みの UB30 の1〜2時間は残りから外した。通常 API 文書・Skill・訳の旧別枠4〜8時間は V10.2a/b と V10.3a の対応する作業へ配分し、全体へ二重に足さない。

| 残る手順 | 能動時間 | 検査・測定・レビュー等の枠 | 二重計上と未確定の扱い |
|---|---:|---|---|
| V10P のレビューと V10Pb の採用 | RV-V10P と本対応は済み。追加修正は不明 | 対応の独立確認・採用20〜40分、回答待ちは不明 | 旧レビューを未実施へ戻さない。V10 の実装見込みの外 |
| UB30.01/.02（済み） | 残り0時間 | 実装・独立レビュー・指摘対応は取り込み済み | 既存の計1〜2時間を再加算しない。UB30.01-1 は下の V10.1b と V10.1d へ含める |
| V10.1a/b と V10.2a/b | 計4〜9時間 | W-D/S/E と条件付き W-R、F-L：暫定20〜45分、初回構成・ビルドは不明。4単位の独立レビュー各10〜20分＝40〜80分 | H31 の局所比較と J2 の差分案を含む。見込みを超える場合は区切って再見積もり |
| V10.3a の最終編集 | 1.5〜3時間 | 生成・W-V（golden・版依存テストを含む）暫定10〜20分、独立レビュー10〜20分 | 版・登録・help・表のテスト・testdata・依存ハッシュ・訳・CHANGELOG を同時に変更 |
| 最後の必要な short と判断 | 調査・修正は上の担当枠、追加分は不明 | 文書だけなら0回。処理系・埋め込む Skill の変更は取り込みごと、採取各15分以内＋二版ビルドは不明 | J1 は変更なし。J2 の登録等も測定経路が不変かを準備前に確認し判断する。準備後の測定を計画しない |
| V10.1d の影響段の再確認 | 0.5〜1時間 | F-U 45〜75分＋初回ビルド・取得等不明、独立レビュー10〜20分 | 起動前に範囲と更新した見込みを示して設計者の了承を得る。不変段と formal_build は適格なら引用。H31 の最終確認もここで行う |
| V10.1c の C と追加自己検査、F-Q | 0.5〜1時間 | C 90〜150分、T-D/T-C 各2〜5分、引用票読解は左へ。独立レビュー10〜20分 | formal_build の適格な引用は C の選択から外す。影響段の実行は V10.1d へ計上し、ここで重ねない |
| V10.3b の候補勧告 | 0.5〜1時間 | 四ツール資料の取得時間は不明。二 lock の1〜3分と DB 初回不明は R の中 | C の二 lock 照合と候補の再照合は別時点。取得不能の記録を無影響に変えない |
| V10.3c の R・P・ソース候補照合 | 0.5〜1.5時間 | R 暫定10〜20分、候補の初回ビルド・全 Skill 抽出・archive 内容照合は不明。独立レビュー10〜20分 | 回帰全件を反復しない。前版 R の142秒だけで現候補の初回を確約しない |
| V10.3d の最終レビュー・設計者の受け入れ・項目整理・保管 | 0.5〜1.5時間 | 全体独立レビュー20〜40分、設計者の確認待ちは不明 | 項目転記・保管前の根拠確認とリンク修正は左へ。対象外のファイルを担当へ読ませない |
| V10.3e の集約・タグ・P-final・正式 archive・指示後の push | 0.5〜2時間 | ビルド・抽出・圧縮・転送時間と承認待ちは不明 | 計測だけを理由に C/R/F を一括反復しない。木と関係状態で引用、commit 依存情報は更新 |
| V10 の予備 | 0〜1時間 | 条件付きの検査・判断待ちは別に不明 | 保証と検査を減らす余地ではない |
| V10 全体 | 8.5〜21時間 | 既知の仮枠：検査179〜320分、単位と全体の独立レビュー100〜200分。合計4時間39分〜8時間40分。未確定のビルド・short・取得・追加修正・回答待ちは別 | 検査＝20〜45＋10〜20＋45〜75＋90〜150＋4〜10＋10〜20。単位レビュー8回＋全体一回で100〜200分。済みの UB30 と計画のレビューを含めない |
| 現在から公開まで | V10 8.5〜21時間、V10Pb の採用で生じる追加修正は不明 | 上の4時間39分〜8時間40分＋対応の独立確認・採用20〜40分＝4時間59分〜9時間20分。未確定分と、受け入れ・公開指示待ちは不明 | 能動時間と検査・レビュー枠は別。既に閉じた R/K、済みの UB30・PM/IF/SH2 と過去の short を再加算しない |

## 停止条件と計画の採用

J2 と H31 の計画済み変更以外で全比較の入力に触れる変更、引用条件の不足、想定外の再実行が必要な場合は J3 に従い、その作業を止めて設計者へ問う。計画済みの V10.1d も、起動前に書き出し・それを読む段・範囲の実ソース・引用する段の範囲と見込みを示し、設計者の了承を得るまで停止する。書き出せない H31 は未確認のまま返す。既存の成功を保つために値・型・範囲を Top へ落とす、比較対象・拒否・非 Top・件数・時間制限を減らす変更は採らない。主定理の前提/結論・Assumptions・信頼条件・公開契約・保証の変更、依存更新、対象外の本番機能の追加も停止条件とする。

分類不能・基準不明の終了3では、対象ファイルと停止までの選択、不足する検査を示し、既に計画で名指しした範囲以外は設計者へ返す。指定の誤りの終了2は指定を訂正する。勧告の検出・取得不能・道具不在は表示と記録・報告を行い、それ自体を受け入れの停止条件にしない。設定・実行器の誤りや別のテスト失敗は成功へ変えない。

各単位の見込み上端の2倍を超えたと気付いた時点で原因・実所要・残りを報告し、通る区切りで止める。通る状態へ戻せない場合は失敗と未完を記録する。長い実行の待ちと能動時間は分けるが、外側の大幅な延長も知らせる。

採用時に取りまとめは、(1) 本書の独立レビューと決定済みの J1/J2、(2) 版上げと登録等を一作業にし、了承後の影響段の再確認を change より前に置く順序、(3) 各起動の完全な基準と変更範囲、(4) F-L/F-U/F-Q と C/R/P の実行・引用の割り当て、(5) 最後の一表の見込みと未確定分を plan の計画変更へ転記する。計画の下書きは入力の作業の取り込み後に起動し、枝のレビューでは義務表の行が閉じたかを確認する。V10Pb が他の計画へ加えるのは依頼で許された義務表の状態と配布の前置きだけであり、本番・設計書・テスト・git の状態は変えない。
