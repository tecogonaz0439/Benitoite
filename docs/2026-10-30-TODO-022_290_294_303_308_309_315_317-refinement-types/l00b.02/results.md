# L00b.02a・L00b.02b・L00b.02c: 公開契約の改訂前の停止

本書前半は一度目の停止の記録である。レビュー後の署名改訂は末尾「2026-10-31: 完全署名の改訂と起動単位の分割」を参照する。前回の入力・実行記録は変更していない。

2026-10-31。**三単位とも未完了である。** `.02a` の全 sort の観測に対し、現行 `Transport.values` の公開欄では置換後の sort の保存に必要な条件が不足することを確認し、公開契約を変更する前に停止した。停止の根拠、検査した入力、未証明の言明、改訂候補は [contract-boundary.md](contract-boundary.md) にある。取りまとめの契約改訂・独立レビュー・再指定を待つ。

## 基準と操作

| 項目 | 記録 |
|---|---|
| B_WORK | `2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf`（起動依頼の指定） |
| 指定ブランチ | `m014/l00b.02`（起動依頼の指定。担当は切替・作成・コミットをしていない） |
| 開始の時計 | 2026-10-31 00:42:37（+0900）。共通依頼文を最初に読んだ直後の時計 |
| 条件 | [共通依頼文](../implementation-request.md)、[計画](../plan.md)の L00b 前文と `.02a`〜`.02c`、公開署名の停止条件、ユーザーの「契約の型・公開の欄を変える必要が出たら、実装を進めずに報告する」 |
| 判断の継承 | README「設計者の決定」、decisions D02/D03・D17〜D22・U01、L00a.12 の二度の契約改訂。Nat/WF、値置換の bind、単調な改名、篩の芯での cont 除外を変更していない |
| 勧告 | [改造の照合](../security-advisories.md)と「組み込まない」の判断を引継ぎ。再照合・依存やツールチェーンの更新なし |
| 変更範囲 | 本ディレクトリの停止報告・匿名の証拠の検査入力・検査記録のみ。本番の formal・処理系・現行設計書・計画・契約の変更なし |
| 入力の照合 | [formal-inputs.json](formal-inputs.json) の361ファイル（`.lake` を除く Lean ソース358件、lakefile・toolchain・manifest 3件）。作業後の SHA-256 がすべて一致 |
| Git | 担当から git コマンドを実行していない。work の dry-run に伴う基準・差分の読取りだけを使用する |
| 最大常駐量 | 未取得（計画上の非採取）。work 本実行と採取は取りまとめの担当。RSS のための追加ビルドなし |

今回、独立レビューは行っていない。L00a のレビュー6文書（RV-.06a/.06b/.08/.12-stop/.12/.16）と [申し送りの統合表](../l00a.16a/lemmas.md)を照合したが、今回の自己点検を独立レビューとして数えない。

## L00b.02a: 全 sort と置換の接続

閉じた新しい本番の定義・補題は0件である。追加した Ty/Term/Pred の構成子も0件である。`Transport.values` の型と `Pred.sorted_bind` → `Ty.LeQ.bind` / `rawBind` の接続を照合した。

[boundary-check.lean](boundary-check.lean) は宣言を追加せず、匿名の証拠を型検査する。空でない source の List の位置について、任意の `t : Term` を像にしても現行 Transport が成り立つ。このため、長さを観測する構成子を加えると、現在の整数だけの公開欄では一般の sort の移送を示せない。拡張後の長さの式に対する反例は未実行であり、現在の整数だけの定理の反例とは区別する。

残りは、全 sort の有限構文と観測の型、Transport の公開欄の改訂、型付き像からの証拠の構成、移動・置換・被覆・埋め込み・WF・正規化の該当する場合の追加である。担当は契約確定が取りまとめ、実装が `.02a` の再開担当である。これらを L10 へ送って `.02a` の完了にしない。

`rawApply` の kind の検査は未実装であり、`.02a` に残る。現行の `rawApply` は ctor/tvar 以外の像をそのまま返す。篩だけでなく base 等でも引数が落ちることを、RV-L00a.08 軽4と照合した。逆転の残りの送り先は従来どおり `.11` である。今回の停止を理由に、篩付き像の全体を不適格として除外する契約は採っていない。

cases/match は、追加した場合0件・新しい追随0件である。**実際の Ty の全 cases/match の箇所数は未計数**であり、O009 は未完了である。Ty 構成子数（旧15、新最小16）をその箇所数の代用にしない。

計画からのずれは、全構成子の追加前に公開契約の停止条件を適用した点である。最初の1時間以内の接続確認で報告した。全 sort の拡張が既存の補題の条件だけで閉じるとは認定していない。

## L00b.02b: 依存列と外部の接点

新しい本番の定義・補題・構成子は0件である。依存列、σ、外部 ID・宣言表、呼出しと応答、正常/return、範囲付き値・全状態の構成子は未実装である。

現行 Program の六欄と型付けの完全署名を検査した。外部宣言表を Program に足す方式は公開欄の追加、外部表を既存の型付けへ明示引数として足す方式は公開署名の変更になる。契約が将来の詳細化へ送っている σ/外部表/状態の完全署名を、担当が未承認のまま選ばなかった。既存 δ に外部応答を隠すこともしていない。候補の差分は [停止報告](contract-boundary.md#外部宣言表の配置)にある。

残りの担当は、完全署名と配置の確定が取りまとめ、その後の構成子・移動・置換・埋め込みの追加が `.02b` の再開担当である。L50/L60 は既定の構成子の葉を証明する担当として保ち、今回追加しなかった構成子を後で主定理へ後付けしてよいとは扱わない。

cases/match の追加・追随は0件。全型付き状態の計数は未実施である。計画からのずれは、依存する `.02a` の契約改訂前に停止したことである。

## L00b.02c: 共有層と import

新しい本番の定義・補題と import の変更は0件である。共有層への分離は未実施であり、`.02c` は未完了である。

現在の依存は次のとおりである。

```text
Interval.Domain → Release.Syntax → Release.TypeSubst → Release の型の層
Release.Refinement.Types → Release.Typing → 旧 Release の構文・型
```

`Interval.Domain` は `Release.Syntax` の `min64` / `max64` と、旧 Ty を使う `IntKind.type` / `ofType` を参照する。現在は Refinement から Domain への新しい依存を足していないので、今回のソースに import 循環が発生したわけではない。新旧の判断を含む現在の既定ビルドが通ることは確認したが、これを共有層分離の完了の証拠にはしない。

残りは、整数の種類・値域・区間の表現を Release の項の構文に依存しない共有層へ分け、旧 Ty との対応を互換側に配置し、既存 API の読者と新構文の読者が適切な層を読むようにすることである。`.02b` の後に `.02c` の担当が実装し、向きと API の互換を記録する。

cases/match の移設・変更は0件。計画からのずれは、前段の契約改訂前に共有層の変更へ進まなかったことである。

## 義務の判定と申し送り

| 義務・申し送り | 今回の判定・証拠 | 残る担当 |
|---|---|---|
| O009（本番 Ty の変更面の定量化） | 未完了。cases/match 全件の計数と方式比較は未実施 | `.02a`〜`.02c` 再開時 |
| O016（公理依存） | 使用する15宣言を実行して限定確認。新しい宣言は0件。段末全体の A-L を閉じていない | L00b 末、L10〜L70 |
| O002/O004/O006/O031（新構成子の移動・置換・被覆・相互置換） | L00a の完成範囲を維持。全 sort の移送条件の不足を特定したが、追加の場合は未実装 | `.02a`/`.02b` 再開、L10/L20 |
| O029（Γ/facts/Φ・依存列） | 未完了。現行の有限 facts と整数の移送を照合しただけ | `.03`、L20 |
| O040（表現の較正） | Nat/WF と四名前空間を維持。全 sort/骨格の実績を取得したとは扱わない | L00b の後続・取りまとめ |
| O042/O159（並置と全構成子） | 現行の新旧並置の既定ビルドは成功。全構成子と切替は未完了 | `.02a`/`.02b`、L10/L20/L70 |
| O085（cwd/home/root 等） | 未実装。範囲用 σ の意味と配置は再開時に確定する。値置換の σ と混同しない | `.02b`、L50/R70/D10 |
| O169（区間の共有領域） | 現行依存を確認。分離・新構文との接続は未実施 | `.02c`、L10/L20/L40/L70 |
| RV-.06a 重1/中3、O159 | 予約された全構成子・公開名の不足を維持し、完成済みにしない | `.02a`/`.02b`、L10/L70 |
| RV-.06a 重2・軽4、正規化の一般化 | 既存の埋め込み/正規化の交換は変更していない。平坦化・true 消去は未実施 | `.11`、L10/L20/L40 |
| RV-.06a 中2/中5、全 sort の facts/観測 | 現最小四判断の完成を取り消さない。全 sort の Transport の変更が必要 | `.02a` 再開、L10/L20/L40 |
| RV-.06b 軽1/軽2/軽3/軽6、RV-.12 軽2 | 既存の公開補助を使用して照合。本番ファイルは編集していないため、未使用 private/冒頭説明/Subst の理由の追記は未実施 | 次に該当ソースを触る担当 |
| RV-.06b 軽4、二度目の契約改訂 | 芯の cont の WF 除外は既に解消済み。その境界と D02/D03 の提供範囲を保つ | L10/L20/L40/L70 |
| RV-.06b 軽5、RV-.08 軽4 | rawApply の引数消失を照合。kind 側の解決は未実装 | `.02a` 再開、`.11` |
| RV-.08 中1/軽1/軽2/軽3/軽5〜7 | 解消済みの最小代表・None・記録を再課題化しない。一般の型/行の WF/sort と四名前空間の一般合成は未完了 | L10/L20 |
| RV-.12-stop、第一の契約改訂 | 値置換は bind、改名の WF 保存は単調なものに限る条件を継承。今回それらの本体を変更していない | 再開時の全構成子、L20/L50 |
| RV-.12 中1/中2・軽3/軽5 | 継続束縛下の SubstOk.up、型像の cont の除外、narrowing に必要な芯の向き、文脈WFと規範反映を未完として保持 | L10/L20/L40/L70、D10 |
| O007/O008/O030/O032/O039/O046/O047/O051/O052 | 全 canonical/ground/状態の完成は未主張 | `.03`/`.04`/`.11`/`.13`/`.14`、L20/L40 |
| RV-.16 軽1（次回 A-L） | モデルの仮定充足3件と限定同値4件を今回の15対象へ含めた。前回694対象の記録は変更していない | L00b 末に全対象と照合 |
| RSS と O010/O040/O075/O089 の見込み | 末尾 work 本実行は担当から行わない。時間の記録から工数を減額しない | 取りまとめ、L00b 末 |

`.03` は今回の未完了分を前提に開始できない。再開後、全 sort の観測、依存列、σ/外部表/状態の構成子、共有層を先にそろえ、その構文に対して None・lookup・外側参照・宣言順と extend の規約を確かめる。

## 公開名と検査

新しい公開名0件、private から公開へ変えた名前0件、既存の公開型・欄・規則の変更0件である。`boundary-check.lean` は `#check` と `#print axioms` だけを持ち、定義・補題を宣言しない。

| コマンド・対象 | 終了 | 外側の時間 | 記録 |
|---|---:|---:|---|
| `formal/` で `lake build`（既定の全ターゲット） | 0 | 0.149374042秒 | [build.log](build.log)、[build.json](build.json) |
| `formal/` で `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.02/boundary-check.lean`（最終） | 0 | 0.690375792秒 | [boundary-check.log](boundary-check.log)、[boundary-check.json](boundary-check.json) |

既定ビルドは増分で603ジョブの既存成果物を再利用した。既存の Interval の警告が再表示されたが、新しい sorry/error はない。clean build、全保存、新しい構成子のビルド成功を示す記録ではない。`lakefile.toml` の `-M 12288` を変更していない。

匿名の証拠の初回検査も終了0（0.68627075秒）だったが、`unnecessarySimpa` 警告が1件あった。検査入力の tactic を `simp ... at hp` に直し、最終は警告0・error0。初回の成功を新しい最終入力の実行済み記録に流用していない。

15対象の `#print axioms` はすべて `propext`・`Quot.sound`・`Classical.choice` の部分集合であり、未承認の依存は0件。[集計](axioms-summary.json)に対象数と集合を記録した。これは停止箇所の使用定義・既存補題と追加のモデル/限定同値の確認であり、L00b 全体の A-L の完了ではない。新しい独自 axiom/sorry/admit は追加していない。

work はユーザーの指定に従い次の dry-run のみ行った。本実行は取りまとめへ残す。

```sh
scripts/check.sh --level work --base 2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf --dry-run
```

終了0、外側0.098875584秒。文書だけの10変更ファイルとして「検査なし」を選んだ。[生出力](work-dry-run.log)と[実行記録](work-dry-run.json)に保存した。これは Lean の work の成功を意味しない。再開して本番の Lean を変更した後は、同じ基準と最終差分に対して選択を取り直し、取りまとめが sandbox の外で本実行する必要がある。

## 所要と再開条件

最初の時計00:42:37から00:51:11（+0900）の dry-run 後の時計までの外側の時間は **8分34秒** である。この後の記録の追記とリンク・入力の最終照合はこの区間に含めない。能動時間と待ちを全区間で分離していないため、能動時間の確定値や証明一件あたりの単価にしない。記録した区間の能動時間の上限としてのみ読む。ビルドと匿名の証拠の検査のコマンドごとの外側の時間は上表と JSON に分けた。

全 sort の実装を試した実績ではなく、契約と接続の確認で停止した実績である。4〜10時間の元の見込みから残りを減額せず、上端の2倍の20時間を超える条件は非該当。追加の能動時間とレビュー等の待ちの再見積もりは、[停止報告の表](contract-boundary.md#再開時の順序と所要)にあるとおり未確定である。

取りまとめが全 sort の移送条件と外部表の完全署名を改訂・レビューして再指定した後、`.02a` から再開する。主定理の結論を弱めること、任意の Prop を信頼条件として足すこと、D02/D03 の提供範囲を狭めることは再開案に含めない。


## 2026-10-31: 完全署名の改訂と起動単位の分割

[signatures.md](signatures.md) を RV-L00b.02-sig と plan の2026-10-31の最初の二つの判断に従って改訂した。末尾の第14節に重1〜重4、中1〜中8、軽1〜軽8、予約名、第7.3/7.4節と未決点の対応を置いた。**本番の `.02a`〜`.02c` は引き続き未完了であり、今回の成果は契約と起動表の改訂案である。**

基準は起動依頼で指定された B_WORK `2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf`、ブランチも指定の `m014/l00b.02` を引き継ぐ。担当から git コマンド、切替、作成、コミット、push は行っていない。処理系・設計書・本番 Lean・plan・既存契約は変更していない。本ディレクトリの文書・補助入力・記録だけを変更した。前回保存した formal-inputs.json の361入力は最終点検で全件のSHA-256が一致した。

改訂の要点は、Optionを保持するsnapshotの置換とVarsIn、opaqueのRangeIx、新しいbitsのConst、継続の改名をImageOkに分けたSubstOk、R0と結果のRの像の一致、SubstOk.hide、外部の無事象/no-exit、Map/Setの言語の鍵の等値による重複縮約、δ/IOの結果の全有効σでのAdequate、StateTyのValidだけの条件である。fnとdependentFnは .11 の比較/正規化を切り替えるまでC_App/C_DependentAppを並置し、その間の型付けの完全性を主張しない。

### 型検査と自己点検

全コマンドの作業ディレクトリは formal、Leanは固定のv4.34.1、メモリ引数は `-M 12288` である。補助入力は本番のimportに加えていない。

| コマンドの末尾（先頭は `lake env lean -M 12288`） | 終了 | 外側の時間 | 判定・記録 |
|---|---:|---:|---|
| `../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.02/nested-negative.lean` | 1 | 0.622秒 | 期待した拒否。Orの局所変数を含むnested inductiveの制限を再現。[入力](nested-negative.lean)、[log](nested-negative.log) |
| `../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.02/decidable-negative.lean` | 1 | 0.648秒 | 期待した拒否。List(Option Term)のDecidableEqの自動導出不可。[入力](decidable-negative.lean)、[log](decidable-negative.log) |
| `../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.02/signature-probe.lean` | 0 | 0.651秒 | ImageOk代案、構造的な相互再帰、BEq、noneの保持、無条件の完全性の障害の小さい補助証明。[入力](signature-probe.lean)、[log](signature-probe.log) |

完全なコマンドと入力SHA-256は [signature-probes.json](signature-probes.json)。初回のDecidableEq付きの補助入力は終了1で、[初回の出力](signature-probe-first.log)を保存した。LawfulBEqの自動導出も同じnestedの制限で拒否され、最終入力ではBEqの自動導出だけを確認した。構造のBEqの正しさや言語の鍵の等値の証明まで済んだとは扱わない。最終のbindOptional/predBind/無条件の完全性の障害の補助定理は、#print axiomsが公理依存なしと報告した。新しい独自axiom/sorry/admitはない。

[文書の点検](revision-check.json)は構成子の数、旧Step68名の記載、コードフェンス、相対リンクを照合し、本番入力361件が変わっていないことを確認した。[case-inventory.json](case-inventory.json)は現在の実名と直接場合分けしている57場合を保存する。新しい3族の各71場合とTypedFacts56の計269は、将来の導出の構成子ごとの被覆義務であり、実際に証明を型検査した件数ではない。追加は212被覆義務で、枝数に一律の単価を掛けた見積もりではない。

本番を変更していないため、今回 `lake build`、新しい全補題のA-L、workの本実行は行っていない。文書の点検でGitを間接に呼ぶことも避け、ユーザーのGit操作なしの指定を保った。前回のキャッシュ再利用の既定ビルドを新しい署名の型検査済みの根拠として引用しない。RSSは未取得（計画上の非採取）。

今回の全区間の開始時計は未取得であり、能動時間の確定値は出さない。最初に記録した時計は02:14:43（+0900）、結果の追記前の時計は02:30:07で、その間は15分24秒である。先に行った読取り・補助入力の準備・最終点検と本節の追記をこの区間へ含めない。上表のコマンドごとの外側の時間は能動時間と分け、L00aや本番証明の単価には使わない。

### 起動表と未確定の点

| 起動単位 | 能動時間の見込み | L20から移す分 |
|---|---:|---:|
| .02a 全sort/型/有限置換 | 3〜5時間 | 2〜2時間 |
| .02b 値の葉 | 2〜4 | 0（旧.02bの枠を配分） |
| .02b 外部 | 2〜3 | 2〜3 |
| .02b σ/At | 2〜4 | 2〜4 |
| .02b 腕/節/ハンドラ | 3〜6 | 3〜6 |
| .02b 閉包/状態 | 3〜6 | 3〜6 |
| .02c 共有層 | 1〜3 | 0 |
| 合計 | **16〜31時間** | **12〜21時間** |

各単位の末に全既定の `lake build` が通ることを要求した。型の参照の依存順に、有限のPathEnv/ID/AtErrorを .02a、Capture/Closureと状態の構文・旧68遷移を値の葉の単位へ置き、外部/Atの遷移が後の未定義の状態を参照しないようにした。閉包と型付き状態の判断、依存呼出しは最後の単位で接続する。

実装再開の確定契約として返せない点は二つある。

1. **中2の無条件の完全性。** sortだけ合う観測不能な内部snapshotに対して、全域の二値解釈で真ならevalClosedがsome true、という言明は、述語とその否定のどちらかが真であることと両方の評価がnoneであることから成り立たない。本番Predの型付き反例を実行したとは主張せず、この論理的な障害の小さい補助証明をsignature-probeに置いた。第3.2節にClosedObservableを明示した完全性と、到達したsourceの条件でこの補助条件または閉じたEntailsを内部で導く義務を代案として示す。主定理の利用者へ前提を追加する案、新公理、提供範囲の縮小は採っていない。この代案を採れるかは取りまとめの再レビューに返す。追加の能動時間は未確定で、.04/.13/.14b/L20/L50のどの接続が不足するかを確定してから判断する。レビュー/設計者の待ちは不明。
2. **判断 (4) の56時間の相談条件。** 上の12〜21時間をL20から移すと、L00bは24〜56から**36〜77時間**、L20は39〜90から**27〜69時間**となる。合計63〜146時間は変えないが、L00bの上端が56時間を超える。このため取りまとめが計画へ配分を反映し、設計者へ再提示する前に実装を起動しない。時間を足し増したり、L20へ同じ証明を残して二重に数えたりしない。取りまとめの計画反映と受け入れの待ちは不明。

今回の自己点検を独立レビュー済みとは呼ばない。署名の改訂案と起動表の作成は済んだが、中2と見込みの取り扱いを確定する前には本番実装へ進めない。O002/O004/O006/O009/O029/O042/O159/O169等の本番の義務の未完了は前回どおり維持する。


## 2026-10-31: `.02a` の実装開始と公開WF保存の条件での停止

RV-L00b.02-sig2の追記と三段の配分の整理を終え、本番の有限構文を実装した。**`.02a`は未完了である。** snapshot内のNoneの位置に対するWF保存の公開条件が足りないことを確認し、全sortのTerm/Tyへ切り替える前の、既定ビルドが通る区切りで止めた。根拠と未採用の改訂候補は [02a-wf-contract.md](02a-wf-contract.md) にある。L00bの上端77時間とClosedObservableは、今回は停止理由ではない。

### 基準・署名の追記・配分

B_WORKは引き続き起動指定の `2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf`、ブランチも指定の `m014/l00b.02`。gitコマンド・切替・作成・コミットは行っていない。Rust・処理系・現行設計書・planを変更していない。勧告は従来の照合と「組み込まない」を継承し、依存/ツールチェーンを更新していない。

signaturesに次を追記した。追記自体の独立レビューは未実施である。

- 中1: 無条件のpredBind_openを撤回し、termBind? ν t = some uを受け取るpredBind_open_of_someを固定した。現行Entailsの17構成子にopenを使う規則はない。ground追加時の確認は.04のままである。
- 中2/軽2: SubstOk.upのR0をshiftし、upN/extendNone/shiftE/clauseと、既存Ty.bind_shiftV_values/Eff.bind_shiftV_valuesを使う可換性を記した。None版のsourceのRも親のRをshiftする形へそろえた。
- 軽1: CaptureOk/ClosureTy等は構成子の引数とカリー化した前提を使い、And/Existsの下に局所の再帰する判断を置かない。
- 軽3: BuiltinArgs/AdequateResult/CoreAssumptionsをat、CQ等のR0拘束の切替をhandlersへ配置した。
- 軽4/軽5: .14a/.14eの見込みを維持し、構文の可換性と状態の代表を再計上しない。固定2時間は配分であり実測でなく、下端が楽観的な可能性を記した。
- 軽6: Pred.bind_congrへ改名し、使わないSortedの前提を削った。

| 段 | 変更前 | 変更後の配分 | 移動 |
|---|---:|---:|---|
| L00b | 24〜56時間 | 36〜77時間 | 12〜21時間を受け取る |
| L10 | 22〜48 | 15〜36 | 7〜12時間をL00bへ移す |
| L20 | 39〜90 | 34〜81 | 5〜9時間をL00bへ移す |
| 三段合計 | **85〜194** | **85〜194時間** | 下端・上端とも維持 |

`.02a`の共通の全sort/WF/snapshot可換性の追随はL10から2時間を移す。.02bの5群はL10から5〜10、L20から5〜9時間を移す。L10は.02で閉じた場合を再計上せず、自分で新しく増やした構成子の場合だけを内数とする。元の枠が群ごとに確定配賦されていたという実績はなく、これは現在の作業内容を区別する未実測の再配分である。planへは取りまとめが写す。

### 本番に置いた定義と閉じた補題

新規モジュール [ScopeSyntax.lean](../../../formal/Benitoite/Release/Refinement/ScopeSyntax.lean) と、Typesのimport変更を本番に残した。SortはLeanの予約語なのでコードでは«Sort»と綴るが、公開の宣言名はBenitoite.Release.Refinement.Sortである。

| 追加した有限の型 | 構成子数 |
|---|---:|
| Sort | 14 |
| PathBase / PathEnv | 5 / 1 |
| RangeExpr / RangeIx | 3 / 2 |
| TargetInput / AtFailure / AtError | 2 / 7 / 1 |
| ExternalId / ComponentId / ExternalFunctionId | 各1 |
| FieldRef / Measure | 1 / 7 |
| Comparison / FloatClass / FloatWidth | 6 / 6 / 2 |
| 合計 | **16型・60構成子** |

関数はRangeIx.inst/RangeIx.WF、embedRange/embedIx、Measure.input/Measure.outputの6定義である。閉じた5補題の共通接頭辞はBenitoite.Release.Refinementである。

| 補題 | 閉じた範囲 |
|---|---|
| RangeIx.inst_nil | 空の範囲の像でfixed/rvarを保つ |
| RangeIx.inst_fixed | fixedの像へ置換を再適用しない |
| embedIx_injective | 旧Ixの構造の等号を反映する |
| embedIx_inst | 旧の範囲の具体化と新しいRangeExprの列への埋め込みが交換する |
| embedIx_wf | 旧Ixの番号の上限を新しいRangeIxへ移す |

生成された構成子・射影等を除く手書きの宣言は27である。既定importに含めたが、旧Ty.opaqueはまだ旧Ixのままであり、この5補題だけでTyの埋め込みの追随を完了したとは扱わない。

### 場合の数・未完了と送り先

`.02a`の計画はSort14/Term20/Pred14/Ty21/Tel2/Atom2等と、移動・置換・narrowingの既存各15場合、TypedFactsの2入口各V6、LeQの予定12規則への追随であった。今回追加したのは前表の有限構文だけである。Term/Pred/Ty/LeQ/HasTypeの新しい構成子は0、既存の3族の新しい場合は0である。現在の整数だけのTerm3/Pred8/Ty16と、3族各15＋TypedFacts12の計57場合は保った。有限構文の60構成子を型付けの60場合と数えない。

WFの補助入力で確認した不足は次のとおりである。Γ=[none]、Δ=[]、snapshotにsome(var 0)、像ν i=some(var 0)を置くと、sourceはWF/sortを満たし、全sortの像の条件は空に成り立つのに、targetのWFは成立しない。selfの下のvar 1でも同じである。本番の現行SubstOkがNoneの像を制約しないことも直接証明した。前三者は拡張の定義の小さい再現であり、まだ整数だけの本番Term/Tyの定理の反例ではない。

signature 3.4は型付き像からWFを導くとするが、Noneの位置には型付き像の証拠がない。一般のTy.wf_bind_values/Eff.wf_bind_valuesに、sourceがその位置を読まない条件や観測像のWFをどう渡すかはまだ公開署名へ固定されていない。この追加の公開前提を担当の判断で足さずに停止した。新しい主定理の前提、新公理、提供範囲の縮小は加えていない。

残りの担当は署名の条件の確定・再レビューが取りまとめ、その後の同じ`.02a`の再開が実装担当である。Term/Predの全構成子、部分的な値の像とopenの可換性、Ty/Tel/Atom/Const、全sortのTransport、型付き観測、WF/移動/置換/埋め込み/既存相互補題の追随を残す。これらを後の群へ送って`.02a`を完了にしない。

O002/O004/O006/O009/O029/O040/O042/O159等は未完了のままである。O016は今回追加したモジュールの全宣言についてだけ検査し、L00b全体のA-Lを閉じたとは扱わない。PathEnvの有限データは置いたが、σのValid/Ready/Adequate・運用の対応はat/L50等に残る。

### ビルド・公理依存・入力の照合

| コマンド（作業ディレクトリはformal） | 終了 | 外側の時間 | 判定 |
|---|---:|---:|---|
| `lake build` | 0 | 18.6468秒 | 旧体系・並置体系と全既定ターゲット。604ジョブ |
| `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.02/02a-wf-boundary.lean` | 0 | 0.3740秒 | 最終の4補助定理を型検査 |
| `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.02/02a-scope-axioms.lean` | 0 | 0.6985秒 | 定義元のモジュールで公開・private・生成された宣言を全抽出 |

記録は [02a-commands.json](02a-commands.json)、[build](02a-build.log)、[WFの出力](02a-wf-boundary.log)、[公理依存の出力](02a-scope-axioms.log)、[公理依存の集計](02a-axioms-summary.json)。lakeの設定は従来のmoreLeanArgs=["-M","12288"]のままである。補助の一ファイルの検査にも同じ値を付けた。workは依頼どおり実行していない。RSSは未取得（計画上の非採取）。

ScopeSyntaxを定義元とする587宣言の依存の和集合はpropextだけで、未承認の公理0件、sorryAx/Lean.ofReduceBool等0件である。初回の接頭辞だけの抽出は575対象でprivateの生成名を含まなかったため、定義元のモジュールによる抽出へ直し、最終587対象を再実行した。補助4定理の依存も許可されたpropext/Quot.sound/Classical.choiceの部分集合である。

初回のScopeSyntaxの単独検査はSortが予約語であるため終了1となり、«Sort»へ直して成功した。WFの補助入力の初回はList/Optionの下の再帰の停止性を自動で証明できず終了1で、WFもスロットの列との構造的相互再帰へ直した。最終の本番と補助にsorryを置いて成功させたものではない。

開始前の [入力](02a-inputs-before.json) と現在の [入力](02a-inputs-after.json) を比較し、既存361入力のうちTypesのimportだけを変更、残り360はSHA-256一致、追加の本番ソースはScopeSyntaxだけと確認した。ソースの未コミット差分の代わりに変更ファイルと前後のハッシュを保存し、Git操作なしの指定を保った。

最初に記録した時計は2026-10-31 02:49:10（+0900）、結果追記前の時計は03:07:15で、記録した区間の外側は18分05秒である。先に行った共通依頼文等の読取りと、この後の結果の追記・最終点検はこの区間に含めない。能動と待ちを全区間で分離していないので、能動時間の確定値や本番証明の単価にはしない。トークン数は未取得である。時間超過による停止ではなく、公開補助契約の未確定条件による停止である。


## 2026-10-31: `.02a` の再開、参照の判断の実装とhideの公開条件での停止

今回のWF保存の候補(1)(2)をsignaturesへ反映し、本番の現行構文に参照の判断とWFへの補題を置いた。**`.02a`は未完了である。** some contへの参照を許す判断と、some contをNoneにする既存のhideを同時に保存するため、公開条件の追加の判断が必要になった。[02a-reference-contract.md](02a-reference-contract.md)へ、必要な署名を一組にまとめて返す。前回のNoneの参照によるWFの停止は今回の了承で解消し、L00bの77時間や時間超過で止めたものではない。

### 基準と署名

B_WORKは `2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf`、ブランチは指定の `m014/l00b.02`。gitコマンド、切替、作成、コミットは行っていない。Rust・処理系・現行設計書・planは変更していない。依存とツールチェーンも変更していない。勧告の判断は従前の記録を継承する。

signatures第3.4節へTerm/Pred/Ty/Eff.Referencesを公開し、参照の変数の場合をsomeの型がある位置へのlookupとした。Declaredとは独立の構文の判断である。self/依存引数では文脈を延長する。WFの補題にはsourceの参照と、someの位置の像がsomeならtargetの上限を満たすImageWFを渡し、sort保存と別に言明した。termWF_of_sortedは参照からWFを導く入口へ改めた。第17節は今回の了承、第18節は新しい接続の不足と、本番・未完の対応表である。

Transportの全sort欄が制約しない関数型の位置、ShiftMapのOrdinary限定、継続のhideの不足を明示した。some contの参照をOrdinaryへ暗黙に狭めることや、hideの補題の前提を黙って増やすことは行っていない。前回済みのsig2中1〜中3・軽1〜軽6の追記と配分は維持した。

| 段 | 変更前の能動時間の見込み | 現在の配分 | 移動 |
|---|---:|---:|---|
| L00b | 24〜56時間 | 36〜77時間 | 12〜21時間を受け取る |
| L10 | 22〜48 | 15〜36 | 7〜12時間を移す |
| L20 | 39〜90 | 34〜81 | 5〜9時間を移す |
| 三段合計 | **85〜194** | **85〜194時間** | 下端・上端とも維持 |

`.02a`は3〜5時間、移す分はL10から2時間、L20は0である。今回もplanは編集していない。これは既存の未実測の配分であり、停止後の残りがこの枠へ収まることを新たに実測した表ではない。

### 本番に置いた定義と閉じた補題

[Context.lean](../../../formal/Benitoite/Release/Refinement/Context.lean)へ、現行のTerm3/Pred8/Ty16の全構文に対して次を追加した。Tyの参照は各子型・Fail列の型へ再帰し、refinedではselfを加えたPredの参照を検査する。

| 本番の宣言 | 役割・直接の根の場合の数 |
|---|---|
| Term.References / Pred.References | sortとは独立したsome位置への参照。3 / 8場合 |
| Ty.References / private referencesTys / Eff.References | 型・型列・行の相互の参照。16 / 2 / 1場合 |
| Term.references_wf | Termの参照から変数の上限。3場合 |
| termSorted.references | 現行整数sortから参照。3場合 |
| Pred.Sorted.references | 述語のsortから参照。8場合 |
| Pred.references_wf | selfを加えた参照からWF。8場合 |
| Ty.Sorted.references / private sortedTys_references / sortedEff_references | 型・型列・行のsortから参照。16 / 2 / 1場合 |

新しい手書きの宣言は12（参照の定義5、補題7。private2を含む）。定義の直接の場合は30、補題の直接の場合は41である。`| A | B => …`は構成子ごとに数え、一つの構成子の複数の前提を別の場合にしない。

[ValueRegularity.lean](../../../formal/Benitoite/Release/Refinement/ValueRegularity.lean)のtermWF_of_sortedを削除し、Pred.wf_of_sortedは `Pred.references_wf h.references` に接続した。整数sortを使ってWFを導く独立の帰納法を重ねていない。

前回のScopeSyntaxの16型・60構成子と5補題はそのまま本番に残っている。今回新しく追加したTerm/Pred/Ty/Tel/Const/LeQ/HasTypeの構成子は0である。全sort用のTerm/Tyへ切り替えたとは扱わない。

### 型検査用の下書き

[02a-term-syntax-draft.lean](02a-term-syntax-draft.lean)へ、Term20/Pred14、ObservationEnv、termBind?/slotBind/termBind/predBind、snapshot内を含むVarsIn、WF、Source、lift/open/upValuesと、次の補題を置いた。ScopeSyntaxだけを本番から読み、同じ名前の現行Types/Contextをimportしない独立した型検査用の入力である。本番の既定importには入れていない。

- optional/slot/total/predicateの恒等置換と合成。noneのスロットを保持する。
- 改名の成功、termBind?_lift、upValues_comp、predBind_lift。
- termBind? ν t = some uを前提とするpredBind_open_of_some。
- Term/PredのVarsInの単調性、自由変数全体の一致によるbind_congr。
- optional/totalの置換後のVarsIn、termWF_bind、Pred.wf_bind。

構造のDecidableEqにはClassical.propDecidableを使った。言語の鍵の等値や実行時の比較をこの古典的なinstanceで定義したものではない。入れ子のList/Optionに対する置換と帰納法は、slot/slot列との構造的相互再帰で型検査を通した。

全Term20/Pred14の定義とこれらの代数的な補題が型検査を通ったことは、Ty/Tel/Atom/Const・全sort判断・型付け・旧の埋め込みまで接続できたことを意味しない。残りの統合用の下書きとして保存する。

### 新しい確認点、場合の数と未完の送り先

[02a-reference-map-boundary.lean](02a-reference-map-boundary.lean)は本番のTransport/ShiftMapを使い、現行関係だけから新しい参照の保存を導く全称命題が偽であることを含む5定理を証明した。下書きのReferenceBoundaryでは、拡張のTerm上の `measure listLength (listValue [some (var 0)])` に必要な小さいsort判断を定義し、関数型の位置の像と継続を隠す場合の2つのsort保存の境界を証明した。後者を全HasSort/全型付き入力の本番の反例とは呼ばない。

今回のsomeだけの判断はsome contへの参照を許すが、既存ShiftMap.lookupはOrdinaryだけを保ち、hideContsはsome contをNoneへ変える。Transportに像の参照の欄を足すだけでは、ShiftMap.transport/hideの接続を閉じられない。修正候補は、参照をsomeかつOrdinaryへそろえる案と、someの全位置の参照を保ってhide側に隠す位置を読まない条件を受け取る案である。どちらも公開の判断又は補助の前提に関係するため、今回の承認を超える変更を実装せず停止した。

| 項目 | `.02a`の予定 | 今回末の実際・送り先 |
|---|---|---|
| Term/Pred/Ty/Tel | 20/14/21/2構成子 | 本番は3/8/16/0。20/14は型検査用下書き。残りは同じ`.02a` |
| Sort/有限構文 | Sort14等 | 前回の16型60構成子を保持 |
| 既存移動/置換/narrowing | 各15の全sort/Option像への追随 | 現行の各15を維持。新しい体系への追随は未完、同じ`.02a` |
| TypedFactsの2入口 | V6を各入口で処理 | 現行12の場合を維持。全sort/部分像の観測への追随は未完 |
| LeQ等 | LeQ予定12、TelLe2、TelClosure2 | 新しい規則の追加0。未完、同じ`.02a` |
| 新しい参照とWFの入口 | 全構文、self/Tel | 現行の全構文で定義30/補題41の場合を閉じた。Telと全Termは未接続 |
| Ty/Eff.wf_bind_values | 参照とImageWFを明示した版 | 公開署名へ反映。本番は現行版のまま、切替は同じ`.02a` |

既存3族各15＋TypedFacts12＝57の型付けの直接の場合と、新しい参照の定義30/補題41は、異なる対象なので合算して型付けの場合の実績としない。後の群の追加212被覆義務や累計269は実装済みになっていない。

O002/O004/O006/O009/O029/O040/O042/O159等は未完了のまま維持する。O016は今回対象の3モジュールについて検査した範囲だけを記録し、段全体のA-Lを完了とはしない。公開条件の確定・必要なレビューは取りまとめ、その後の同じ`.02a`の再開は実装担当。`.02b`や`.02c`には進んでいない。

### ビルド、公理依存、入力と外側の時間

再現用の入口は [02a-r3-validate.py](02a-r3-validate.py)。検査はすべてformalを作業ディレクトリとした。詳細コマンド・終了・開始時計・外側の時間・原出力のハッシュは [02a-r3-commands.json](02a-r3-commands.json) にある。

| 検査 | 終了 | 外側の時間 | 件数・範囲 |
|---|---:|---:|---|
| lake build | 0 | 6.1942秒 | 全既定604ジョブ、旧体系と並置体系を含む |
| lake env lean -M 12288 …/02a-reference-map-boundary.lean | 0 | 0.3512秒 | 本番関係を使った5定理 |
| lake env lean -M 12288 …/02a-term-syntax-draft.lean | 0 | 1.3629秒 | 下書きの全宣言543。公理の表示545件のうち2件は境界定理の再表示 |
| lake env lean -M 12288 …/02a-r3-axioms.lean | 0 | 0.8401秒 | ScopeSyntax587＋Context363＋ValueRegularity113＝1063宣言 |

公理の抽出は定義元のモジュールを使い、private・生成された宣言も含めた。3モジュールの依存の和集合はpropext・Quot.sound・Classical.choice、未許可0件。下書きも同じ3種の範囲内である。本番関係の5補助定理はpropextだけに依存する。Refinementの本番ソースにsorry/admit/axiomの語の該当0件で、sorryAx依存も0件である。

原出力は [build](02a-r3-build.log)、[本番関係の境界](02a-r3-reference-map.log)、[全Term/Pred下書き](02a-r3-term-draft.log)、[本番の公理](02a-r3-axioms.log)。集計は [02a-r3-validation.json](02a-r3-validation.json)。lakefileのmoreLeanArgs=["-M","12288"]を維持し、一ファイルの検査にも同じ上限を明示した。workは今回も指定どおり実行していない。RSSは未取得（計画上の非採取）。独立レビュー・受け入れは未実施である。

前回の [入力](02a-inputs-after.json) と今回の [入力](02a-r3-inputs.json) の362件を比べ、変更はContext/ValueRegularityの2件、残り360件はSHA-256一致。今回の本番差分をgitを使わず [02a-r3-production.patch](02a-r3-production.patch) に保存した。補助入力と検査入口のハッシュは [02a-r3-artifact-inputs.json](02a-r3-artifact-inputs.json)。設定・Leanの固定版・旧Releaseの全ソースと交換器は変更していない。既定ビルド後に本番ソースは変更していない。

今回の最初に記録した時計は2026-10-31 03:15:38（+0900）。結果追記前の時計03:38:34までの外側は22分56秒である。その前の共通依頼文等の読取りと、この後の記録・最終点検は含めない。能動と待ちを全区間で分離できないため、能動時間の確定値にしない。トークン数は未取得。元の3〜5時間の枠を2倍超過したための停止ではない。残りの見込み・検査・レビュー・受け入れの担当は02a-reference-contractの末尾の表にまとめた。

[最終の自己点検](02a-r3-final-check.json)で、既定ビルド後の本番入力の変更0件、補助入力のハッシュ不一致0件、文書の相対リンクとコードフェンスの問題0件を確認した。記録時計は03:39:48で、最初の記録時計からの外側は24分10秒である。この後の最終応答は含めない。

## L00b.02a: 全 sort・型・有限置換の群を仕上げる（2026-10-31、再開4）

### 範囲と基準

今回の `.02a` の本番の定義・補題と担当検査を終えた。`.02b` / `.02c` には進んでいない。群末の独立レビューと受け入れは未実施であり、取りまとめへ渡す。第18節までの停止の理由は、最新の候補(A)と補助契約の詳細化によってこの群で処理した。自己点検を独立レビュー済みとは記さない。

B_WORK は `2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf`、ブランチは指定値 `m014/l00b.02` である。git を呼んで検査・切替・作成・コミットしていない。今回開始時の ScopeSyntax / Context / Types / ValueRegularity を含む前の担当の未コミット差分を土台にした。[開始時のハッシュ](02a-r4-inputs-before.json)と[最終のハッシュ](02a-r4-inputs-final.json)を保存した。本番の差分（[大きさとSHA-256](large-records.md)）は**今回開始時の作業ツリーからの差分**であり、B_WORK に単独で適用する差分ではない。処理系・現行設計書・plan・docs/todo は編集していない。依存・固定ツールチェーンの更新も行っていない。

### 置いた構成子と閉じた定義・補題

| 群 | 本番の内容 |
|---|---|
| 有限の構文 | Sort14 / Term20 / Pred14 / Ty21 / Tel2 / Atom2 / RangeExpr3 / RangeIx2 / Const16。Float64 は bits、Float32 も既存の bits を保つ。Ty の新5形は dependentFn / external / scoped / pathBases / scopePattern。PathBase / PathEnv / TargetInput / ID / AtFailure / AtError の先行する有限構文も既定 import に含む |
| 項・述語 | 下書きの Term / Pred を `TermSyntax.lean` へ接続。partial/total の bind、slotBind / bindSlots、恒等・合成・bind_congr・lift/open・WF・Source・全自由変数の追跡。none のスロットは観測した値0に変えない |
| sort・参照・Transport | Ty.HasSort と一意性、全 sort の Term.HasSort / Pred.Sorted、Ty/Tel/Eff の Sorted / References / WF。Transport.values / references / typeImages / facts、extend / up / up_raw / extendNone / shiftV / types / imageWF を閉じた。TypedFacts から SubstOk.observations / references / transport を導く。整数の既存入口は系として保つ |
| 型と行の正規形・順序 | Ty/Tel/型列/Eff の norm / rawBind / bind / shiftV / WF の全場合。有限の欄の単射な code、Term/Pred/Ty/Tel の木の単射性、移動と比較・正規化の交換。Atom の Bool 所属関数を保ち、旧型の比較順も保つ |
| 有限置換 | 型/行の shiftTypes / substAt / subst、値の rawSubstV / substV、範囲の rawMapRanges / substRAt / instR / shiftR を全型・Telへ拡張。値の置換との交換、範囲の置換との交換、恒等・合成・WF0 での不変性。任意の cutoff の BindShift と up から rawBind_up / bind_up を導く |
| 部分型・被覆 | Ty.LeQ の既存9＋新3、TelLe2 / TelClosure2 の bind / rawBind / norm / shift / 有限置換。新3は dependentFn、同じ scoped の包含、scoped から同じ index の旧 opaque への互換。Eff.Covers の置換は Transport を要求しない形を保つ |
| 旧の埋め込み | embedTy / embedTys / embedEff / embedConst / embedAtom / embedIx、正規化・比較・WF の既存の交換、embedTy_injective。opaque は embedIx を使い、based/secrets の像を Top へ忘れない。Const.type_embed の旧16場合も閉じた |
| telescope | Ty.toTel、names / arity、NamesWF を前提にした名前・引数数・WFの対応、rawBind / norm / bind / shift の対応。instantiate は実引数を順に bind し、成功したときの個数を instantiate_length で示す。TelLe/TelClosure は名前と arity を保存する |
| kind | TyKind / KindCtx / Ty.HasKind / TyCon.arity / TypeImagesKinded。ProperApply と rawApply_proper / rawApply_valueKind により、適格な ctor/tvar と arity から引数を捨てる枝・Unit 補完へ入らないことを示す。Def.kinds は外側の宣言注釈の有限の出現を検査し、矛盾・範囲外を拒否する。Def.kinds_sound / KindWF、衝突・範囲外による none の補題を置いた |
| 宣言照合 | FieldRef/Term/Pred/Ty/Tel.Declared。受け手の名目型、P.cons、型引数数、欄位置、閉じた宣言型、具体化後の結果 sort を照合。DeclarationImages / DataImages と型付き観測からの供給、束縛の下の up、正規化・値置換の保存を閉じた。V_Sub/C_Sub の行き先、V_Refine の carrier/述語へ接続した |
| 既存の型付け | 移動・置換・narrowing の各 V/Vs/Each/C の全15場合、TypedFacts、hide、None の入口を追随。narrowing の補助判断は P/C と対象型の Declared を保持する。旧の raw 値置換の衝突・継続の narrowing の障害例は削除していない |

構文と相互再帰の主な入口は [TermSyntax](../../../formal/Benitoite/Release/Refinement/TermSyntax.lean)、[Types](../../../formal/Benitoite/Release/Refinement/Types.lean)、[Context](../../../formal/Benitoite/Release/Refinement/Context.lean)、[Transport](../../../formal/Benitoite/Release/Refinement/Transport.lean)、[Telescope](../../../formal/Benitoite/Release/Refinement/Telescope.lean)である。宣言照合は [DeclaredTransport](../../../formal/Benitoite/Release/Refinement/DeclaredTransport.lean)、kind は [Kinds](../../../formal/Benitoite/Release/Refinement/Kinds.lean) / [KindInference](../../../formal/Benitoite/Release/Refinement/KindInference.lean)、参照だけの保存は [ValueReferences](../../../formal/Benitoite/Release/Refinement/ValueReferences.lean)にある。

### 場合の数の予定と実際

[場合の一覧](02a-r4-case-inventory.json)に、Lean の inductive metadata と、既存の各入口の直接の根のパターンを保存した。36種類の帰納型の構成子数を Lean で照合した。構成子数、単項の構造再帰、二項の比較の直積、公開の系の数を混ぜていない。

| 対象 | 予定 | 実際 |
|---|---:|---:|
| Sort / Term / Pred | 14 / 20 / 14 | 14 / 20 / 14 |
| Ty / Tel / Atom / RangeExpr / RangeIx / Const | 21 / 2 / 2 / 3 / 2 / 16 | 同じ |
| 移動（V/Vs/Each/C） | 6/2/2/5＝15 | 15 |
| 値の相互置換（同順） | 15 | 15 |
| narrowing（同順） | 15 | 15 |
| TypedFacts の予定の2入口（observation / assume） | 6＋6＝12 | 12。integer_observation は observation の系で直接の場合は0 |
| 上の予定の直接の場合の合計 | 57 | 57 |
| 追加した TypedFacts の補助入口 | 予定表に内訳なし | 28。assume_optional 6、observation_references 6＋Each2、data_observation 6、observation_declared 6＋Each2 |
| 補助入口を含む上記の実際の直接の場合 | ― | 85。新しい型付け規則が28増えたという意味ではない |
| Ty.LeQ / TelLe / TelClosure の bind、rawBind | 各12/2/2 | 各16、2入口で32 |
| Ty/Tel/型列/Eff の単項の構造再帰 | 各21/2/2/1 | 各26の根を被覆 |
| 二項の木の比較・単射性 | 別計数 | Ty は21×21＝441、Tel は2×2＝4。旧型の比較の埋め込みは15×15＝225 |
| 旧の埋め込みの根 | Ty15 / 型列2 / Eff1 / Const16 | 同じ。旧型付け・遷移の全保存と同じ件数には数えない |

hide_context と公開の subst / narrow / subst_under_none は対応する相互本体から導くため、15場合を重ねて数えない。L10から前倒しした全sort/WF・型付き像・snapshot の可換性は上の本番へ含めた。計画の固定の移動額2時間を実測の能動時間と置き換えたり、工数の合計から減額したりしていない。

### 補助契約で決めたこと

採用案・理由・捨てた案を [signatures.md 第19節](signatures.md#19-02a-再開後の補助契約の決定)へ追記した。主なものは次である。

1. 参照は some かつ Ordinary の位置に限り、snapshot の some の中も追う。ImageWF / ImageReferences も source の Ordinary を受け取る。Transport.references を型付き像から導く。
2. Transport.typeImages は型変数の像が Ordinary であることを要求する。自己の Ordinariness を保持するためであり、値だけの置換は tvar の像から内部で証明する。有限型置換の補助入口には供給する像の Ordinary を渡す。
3. 全域の open の交換へ戻さず、成功時の predBind_open_of_some、改名の系、Option を保つ openOptional / assume_optional を使う。既存の整数・assume の入口も保つ。
4. HasSort/References の self は some a :: Γ、宣言型を読む Declared は Γ.extend a とする。宣言の欄型には WF 0 cd.ntys 0 を要求する。
5. DeclarationImages は値の宣言照合と名目の情報を分け、TypedFacts → 型付き像 → 宣言照合の移送の順に導く。P や未証明の宣言保存の仮定を LeQ/Transport に加えない。
6. Ctx.Narrows P C の here は行き先 b の Declared を持つ。V_Sub の証拠の再構成に必要な補助条件である。V_Sub/C_Sub/V_Refine の既存前提を保ち、予定の Declared を末尾へ加えた。
7. 依存列の bind/up は任意の cutoff の構文の交換で閉じる。像の正規形の一致は SameTypes と subst_norm_images で扱う。
8. kind は外側の宣言注釈の有限の出現を検査する。構成子位置の像は ctor/tvar のみ、data の arity は全ての同名の構成子宣言との一致を検査する。宣言への kind 欄の追加は行わない。
9. 比較には有限構文の単射な code を使い、旧の順序を保つ。表示文字列や言語の鍵の等値を比較の根拠にしない。
10. 相互再帰と型付けの循環を避けるため、BindingShift / ContextFacts / ContextMap / ValueClosed / DeclaredTransport 等へ補題を分けた。既存の公開名は保った。

進行・保存・エフェクトの健全性の主定理の前提/結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態を変更していない。独立レビューでは、上の補助判断の詳細化がこの境界を保つことも確かめる。

### 検査と証拠

再実行用の [02a-r4-validate.py](02a-r4-validate.py) は git を使わず、最終の本番入力を固定し、既定ビルド・境界の型検査・全対象宣言の公理依存を実行する。[全結果](02a-r4-validation.json)、[コマンドと外側の時間](02a-r4-commands.json)、[検査用入力のハッシュ](02a-r4-artifact-inputs.json)を保存した。

| 検査 | 結果 | 元記録 |
|---|---|---|
| `cd formal && lake build` | 終了0、既定619 jobs。既定 import に全46の Refinement モジュールを含む。新しい本番に sorry / admit / axiom / native_decide のトークンなし | [build.log](02a-r4-build.log) |
| `lake env lean -M 12288 …/02a-r4-boundary.lean` | 終了0。None/cont の snapshot、sortのない関数の参照、noneの保持、self/外側、Float/Character、未宣言の欄、ctorの形、2引数の下の外側参照の10項目 | [入力](02a-r4-boundary.lean)、[出力](02a-r4-boundary.log) |
| `lake env lean -M 12288 …/02a-r4-axioms.lean` | 終了0。全46モジュールの6,151宣言（private・生成宣言を含み、今回の新規/変更を包含）を検査。重複なし。使用は propext / Quot.sound / Classical.choice のみ。独自公理・sorryAxなし | [入力](02a-r4-axioms.lean)、[出力の大きさと SHA-256](large-records.md)、[集計](02a-r4-axioms-summary.json) |
| 入力の一致 | 448入力の検査前後のSHA-256が一致。今回開始時からの変更はLean46ファイル、うち新規15。設定・固定版は変更なし | [本番入力](02a-r4-inputs-final.json)、[差分の一覧](02a-r4-source-changes.json) |
| Lean / Lake | Lean 4.34.1、Lake 5.0.0-src+5045d00。macOS arm64。既定のmoreLeanArgsも単独検査も-M 12288 | [Lean](02a-r4-lean-version.log)、[Lake](02a-r4-lake-version.log) |
| work / RSS | 依頼に従いworkは未実行。RSSは未取得（計画上の非採取）。取りまとめの検査へ渡す | [validation.json](02a-r4-validation.json) |

既存の Interval の警告は既定ビルドで再表示される。今回の Refinement の警告は最終の記録で0件である。補助検査を含む最終検査の外側の時間は約5.60秒であった。これは実装の所要時間ではない。Rust/Lean の全比較や主定理の完成の証拠にも数えない。

### テストの関門と計画からのずれ

既存の障害例・OpenSubstitution は、raw置換によるFailの並びの衝突、V_Sub/C_Subの実際のΓ/facts、継続を芯とする篩のWF除外とnarrowingという独立した契約を保つために残した。観測項・参照・Declared の前提へ追随しただけで、都合の悪い導出や反例を削除していない。これら3ファイルは計28行増、Rustテストの追加・変更・削除は0件である。本番Leanの今回の差分は合計6,139行から9,916行（純増3,777行。上の28行を含む）である。

境界の補助入力は、旧の整数だけの構文では扱えなかったsnapshot/sort/依存列/宣言照合の契約を公開入口で確かめる。新規の本番の差し込み口は要しない。旧のプログラムを実行して退行の失敗を再現した検査とは呼ばず、今回の形式化の境界の局所照合とする。単に構成子の一覧を写したテストを本番へ追加せず、構成子数は検査の件数の記録として Lean metadata から得た。

TypedFacts の補助入口28場合と、宣言照合の移送・正規化の交換を具体化したため、署名の初期表にない内訳が増えた。既存の15場合やL10から移した分を未完のまま送っていない。途中には import と複数ファイルの相互追随を確かめるための既定ビルドも実行した。最後の受け渡し用の検査は、上のハッシュとコマンドに対応する一式だけを引用する。

### 残りと送り先

| 残り | 送り先・時期 |
|---|---|
| この群の定義・前提・補助契約・場合表の独立レビュー、work、受け入れ | 取りまとめが群末の独立レビューを起動し、workを実行。受け入れは設計者。レビュー依頼は [RV-L00b.02a-request](../reviews/RV-L00b.02a-request.md) |
| 値の葉のV12/C7、注釈を持つ値の規則のDeclaredと正則性、Capture/Closureと状態の全構文、旧68遷移の骨格、場所/builderの移送条件 | 次の `.02b-values`。3族に19場合を加え累計34、TypedFactsの新しい補助入口にも同じ新葉を追加する。今回の既存15場合を再配賦しない |
| V_Con の data_observation / observation_declared、primitive等の型引数のkindとDeclaredの供給 | `.02b-values` の各葉とAdmissible。Def.kinds は外側の注釈の供給であり、呼出しのkind検査・全宣言の適格性を済ませたとはしない |
| Program.WellTyped・全注釈と文脈のWF/Declared/kind | `.03`。既存のPの関数の表と、今回の有限のkindの供給を接続する |
| 依存実引数列の型付けと逐次具体化の相互補題、外部表と応答 | `.02b-external`。Tel.instantiateの定義を置いたことと、TelArgs/外部応答の保存を分ける |
| σのValid/Required/Ready/Adequate、Atの実行と保持値 | `.02b-at` / L50 / L60。今回は有限構文だけであり、静的判断へσを渡さない |
| SubstOk.up/hideのR0拘束、腕・節・継続の全場合 | `.02b-handlers`。今回の普通の値の参照の保存と混ぜない |
| 閉包の型付け・捕捉・依存βと全状態保存、共有層 | `.02b-closures` / `.02c` / L20 / L70 |
| 閉じた評価・IEEE/Decimal・Map/Setの鍵の等値と重複縮約、ground、欄の事実、三モデル | `.04` / `.05` / `.13` / L30 / L50 / L60。比較用のcodeを鍵の等値へ流用しない。`.13` は複数の構成子の欄で受け手の構成子との一致と観測がnoneになる場合の意味を照合する（RV-L00b.02a 軽2） |
| fn/Telの正規化後等号、不変位置、dataの変性、F3全体 | `.11` / L10 / L40。dataCore_source / DataImages / data_observation / DeclarationImages.data / ContextMap.declaration を、型引数の等号から宣言の欄の具体化に必要な関係へ弱める（RV-L00b.02a 中2） |

O002/O004/O006/O009/O029/O040/O042/O159等は、この群の上の構文・相互補題の分を本番で閉じた。義務全体は後続群を含むため未完のままである。O016は今回の全46モジュールの宣言を検査した範囲だけであり、L00b全体の段末A-Lを完了とはしない。O169の共有層への分離は `.02c` に残す。計画と義務表の取りまとめ・更新は担当から行っていない。

### 外側の時間

今回の開始は2026-10-31 03:43:30 JST。[開始記録](02a-r4-start.json)から、最終検査終了時点まで5,410.69秒（約90.18分）であった。文書と申し送りを含む受け渡し記録の時点は `02a-r4-delivery.json` に残す。能動時間と待ちを分離していないため、外側の時間として扱う。3〜5時間の見込みの上端の2倍（10時間）には到達していない。能動時間の比の較正、L10/L20の移動額と改造全体の見込みの更新は、取りまとめの通常記録で行う。

### レビューの所見の対応（RV-L00b.02a、2026-10-31、再開5）

群末の独立レビュー [RV-L00b.02a](../reviews/RV-L00b.02a.md) と、plan の2026-10-31の先頭の取りまとめの判断に従い、案(i)を実装した。再開4の記録にある「kind の推論」は今回撤回し、宣言済みの kind と注釈の照合に置き換えた。前回の検査記録はその時点の入力の記録として残し、今回の最終入力と結果は r5 のファイルへ保存した。

| 所見 | 直した箇所・対応 |
|---|---|
| 重1：Dict[Cl,F] と高カインドの型パラメータ | Types の TParamDecl と Syntax の ClassDecl に下記の欄を加えた。Kinds の Dict はクラスの argumentKind で引数を検査し、KindInference の出現の収集も同じ kind を使う。Def.kinds は宣言と注釈の照合へ変更した。signatures 第2.2節・第7.1節・R2・第19節を更新し、辞書の引数を kind 検査から外す案(ii)を捨てた案へ明記した |
| 中1：narrowing へ Declared を供給する正則性 | signatures 第12.2節の `.02b-values` の行と第20節の義務の対応表へ、V_Lam・V_List 等の注釈に Ty.Declared を加え、型付けから Declared を取り出す正則性の補題を置くことを固定した。書ける形を狭めないことを同群のレビューで確認する。今回は Typing / Narrowing の本番を変更していない |
| 中2：data の不変性への依存 | signatures 第20節の `.11` の義務と本節の残りの表へ、Ty.LeQ.dataCore_source / DataImages / data_observation / DeclarationImages.data / ContextMap.declaration を、型引数の等号から宣言の欄の具体化に必要な関係へ弱めることを追加した。変性を入れる変更と同時に観測・置換・narrowing を追随する |
| 軽1：ValueReferences の一覧漏れ | RV-L00b.02a-request にB_WORKからの新規16ファイルの一覧を加え、ValueReferences.lean を含めた。今回開始時からの新規15と、前の担当のScopeSyntaxを区別した |
| 軽2：複数構成子の欄の参照 | signatures 第20節の `.13` の義務と本節の残りの表へ、受け手の構成子と ref.constructor の一致の扱い、および観測がnoneになる場合の意味を追加した。`.04` の閉じた評価と表層の許可する形との照合も残す |
| 軽3：typeImages の説明 | 補助契約の一覧2を「型変数の像が Ordinary」に揃えた。本番の条件 `∀ i, Ordinary (θ.types i)` は変更していない |

追加した欄とその置き場所は次である。

| 宣言 | 欄・既定値 | 用途と旧宣言との対応 |
|---|---|---|
| TParamDecl | `constraints : O.TParam := {}`、`kind : TyKind := .value` | 関数の型パラメータごとに、旧の組込みの制約を保ってkindを格納する。Def / MethSig / PrimSig の tparams を `List TParamDecl` とする。メソッドと組込みの関数も関数の宣言として扱う |
| ClassDecl | `argumentKind : TyKind := .value` | 型クラスの引数のkind。Dict と実装の対象がこの欄を読む |

操作・実装の型パラメータは表層が値の型だけを認めるため `O.TParam` のままであり、ConDecl.ntys も変更していない。型付けの C と Builtins.sat/admits が使う制約もそのままで、関数の宣言から constraints を射影する。kind の列を Def の独立した欄へ重ねて格納せず、`Def.declaredKinds` が各型パラメータの kind を集める。旧 Release の kind を持たない情報から高カインドの宣言を推測する操作はしない。

`embedTParam` は旧の制約をそのまま格納し、kind の既定を value とする。`embedTParam_constraints` / `embedTParam_kind` / `embedTParam_injective`、`embedMethSig_constraints` / `embedClassDecl_argumentKind` を閉じた。`embedMethSig` と `embedClassDecl` は旧の型・行・名前・表を写す補助であり、旧の全型付けの保存を完成したとは扱わない。表層が明示する F[_] / F[_, _] と型クラスの引数のkindは新欄へ写す。

照合の補題は `Ty.valueKind_dict_iff` / `Ty.valueKind_dict_iff_class`、`ImplDecl.targetKinded_iff`、`Ty.kindUses_dict_tvar`、`Def.kinds_sound` / `kinds_complete` / `kinds_eq_some_iff` / `kinds_declared` / `kinds_length`、宣言との衝突と不適格な注釈によるnoneの補題である。`Def.KindWF` は出現との一致だけでなく、引数・結果・効果の注釈自体の HasKind も検査する。型変数を含まない不適格な Dict の引数も、出現なしとして通さない。旧の kindCandidate / inferKinds とその推論の補題は削除した。

[新しいkindの境界入力](02a-r5-kind-boundary.lean)の21定理で、次を確かめた。

- レビューの `map[F[_]: Functor,A](d: Dict[Functor,F], x: F[A]) -> F[A]` の出現がconstructor 1とvalueに一致し、宣言したkindでDef.KindWFとDef.kindsが成功する。
- Dict[Functor,Option] と対応する実装の対象が適格であり、Functor[Integer] の辞書・実装の対象は拒否される。
- F[_, _] に当たるparameterとmap構成子をFunctor2の引数に使える。Functorへ二引数のmap構成子を渡すと拒否される。
- 宣言をvalueに変えたF[A]は拒否される。未使用の明示したconstructorのkindはvalueへ変わらない。
- valueを既定とするクラスの辞書は従来どおり値の型を受け入れ、裸の構成子を拒否する。型変数の出現がない不適格な辞書の注釈もDef.kindsで拒否する。
- 旧のパラメータの制約の往復、型クラスの既定のkind、メソッドのパラメータの制約の射影が保たれる。

この入力は公開するkindの判断と宣言との照合を守る。現実的な退行は、Dictの引数を常にvalueと数えること、逆に検査から外すこと、明示したkindを注釈から推論し直すこと、arityの不一致を通すことである。既存の10項目の境界入力はkindの宣言とDictの組合せを扱っていなかった。新しい本番の差し込み口は不要である。修正前の挙動の再現は独立レビューの実行結果を引用し、担当が旧ツリーを再ビルドして実行したとは記さない。Rustのテストは変更・追加・削除していない。

最終検査は [02a-r5-validate.py](02a-r5-validate.py) で実行し、[結果](02a-r5-validation.json)、[コマンド・終了・外側の時間](02a-r5-commands.json)、[入力ハッシュ](02a-r5-inputs-final.json)、[検査用入力のハッシュ](02a-r5-artifact-inputs.json)を保存した。

| 検査 | 結果 |
|---|---|
| `cd formal && lake build` | 終了0、既定619 jobs。最終の記録は約8.84秒。Refinement の警告は0件。既存Intervalの警告は再表示される。根拠は [build.log](02a-r5-build.log) |
| kindの境界の型検査と公理依存 | `lake env lean -M 12288 …/02a-r5-kind-boundary.lean`、終了0。21定理とその依存を確認。[出力](02a-r5-kind-boundary.log) |
| 既存の境界の再確認 | `lake env lean -M 12288 …/02a-r4-boundary.lean`、終了0。None/cont・snapshot・self/外側・sort・欄・依存列の10項目を保持。[出力](02a-r5-previous-boundary.log) |
| 全対象の公理依存 | `lake env lean -M 12288 …/02a-r5-axioms.lean`、終了0。既定importの全46モジュール・6,276宣言（今回の新規/変更、private・生成宣言を包含）。重複なし。使用はpropext / Quot.sound / Classical.choiceのみ。独自公理・sorryAxなし。[入力](02a-r5-axioms.lean) / [出力の大きさと SHA-256](large-records.md) / [集計](02a-r5-axioms-summary.json) |
| ソースと設定 | 49の本番入力・設定を検査前後で照合して一致。変更したLeanはTypes / Syntax / Kinds / KindInferenceの4ファイル、純増81行。設定と固定版は変更なし。[開始時](02a-r5-inputs-before.json) / [差分の一覧](02a-r5-source-changes.json) / [今回の差分](02a-r5-production.patch) |
| 抜け道と担当範囲 | 本番Refinementのsorry / admit / axiom / native_decide / implemented_by / unsafe / partialの語の検出なし。Leanは既定・単独とも-M 12288。workは依頼に従い未実行、RSSは未取得（計画上の非採取） |

主な定理の前提と結論、新しい公理、提供範囲、精密な外部状態について追加の変更はない。今回のkindの宣言の追加は取りまとめの案(i)の判断に限り、表層で既に書ける高カインドの制約を受け入れるための修正である。次の群には進んでいない。中1の本番の修正は `.02b-values`、中2は `.11`、軽2は `.13` へ固定し、今回受け持つ重1・軽1・軽3を後送していない。再レビューと受け入れの完了は主張しない。

外側の時間は、入力保存時点から最終検査終了まで991.51秒（約16.53分）であった。最初の時刻取得は2026-10-31 05:34:02 JSTで、検査後の時刻取得05:53:53 JSTまで約19.85分である。初動の読取の正確な開始時刻は採取していないため、この値を厳密な会話全体の能動時間とは扱わない。文書・申し送りを含む受け渡し時点は `02a-r5-delivery.json` に記録する。所要の目安1〜2時間の上端を超えていない。

## .02a の作業末の work（取りまとめ、2026-10-31）

- 基準: `2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf`。作業ツリーは RV-L00b.02a の所見の対応を終えた状態。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf`（sandbox の外）。選ばれた単位は `formal_build`（`cd formal && lake build` と `sorry` を使う宣言の拒否）だけである。
- 一度目はビルドの結果が手元に残っていたため、0.26秒で終わった。最大常駐量が Lean の検査を表さないので、`formal/.lake/build` の `Benitoite/Release/Refinement` の生成物（lib と ir）を消して、もう一度実行した。
- 結果: 終了0（selected checks passed）。外側の時間は29.13秒、最大常駐量は966,131,712バイト（約0.90 GiB）。
- 計画からのずれ: なし。大きな生の記録3件は、改造に大きさと SHA-256 だけを残した（[large-records.md](large-records.md)）。

## `.02b-values`：値の葉と既存計算の停止点（2026-10-31）

**群全体は未完了である。** 組込みの制約の値移送に、主な定理が読む信頼条件又は受理条件の変更が必要になるため、起動依頼の停止条件を適用した。[停止点の契約](02b-values-contract.md)と[レビュー依頼](../reviews/RV-L00b.02b-values-request.md)を残した。外部の群へは進んでいない。

基準 B_WORK は `fb9afed8a9dc800ea558c07ccdc7c589b40118f8`、指定ブランチは `m014/l00b.02b-values` である。前の `.02a` の取り込みは依頼の `08f9ac72` を出どころとし、git で状態を照合・操作していない。処理系、現行設計書、plan.md は変更していない。

### 閉じた定義と補題

| 群 | 本番に置いたもの・閉じた範囲 |
|---|---|
| 値の相互構文 | Capture.mk/Closure.mk、Capture.values/empty、Closure.capture/code、Val.dependentLam/closure。Val は17→19。dependentLam の注釈と本体の各束縛を rename/subst/substTyAt へ追随し、既存の toTerm/恒等改名の証明を保った。閉包の型付け・状態保存は未実装 |
| 追加した値の規則 | V_Raise、V_Con、V_LocRef、V_LocLazy、V_Bytes、V_Super の6。注釈の WF/Sorted/Declared、構成子宣言と欄数、場所の閉じた型、Byte の上限を接続した |
| 追加した計算の規則 | C_If、C_Lazy、C_Escape、C_Use の4。Γ/Φ/R の移送、lazy の hide、通常資源と State の条件を保持した |
| 宣言照合の正則性 | Ty.Annotation、Ctx.Declared、HasTypeVQ.declared、HasTypeVsQ.declared、Ctx.Narrows.of_value。V_Lam/V_List に Declared を加え、現在の全V12場合から、文脈の Declared を前提に型の Declared を取り出す。narrowing の here への供給をこの入口で閉じた |
| ストアの移送 | LocTy.WF、LocTy.Normal、StoreTy.WF/PreservesNormals/Extends と反射・推移・射影、hide の WF/保存、StoreTy.empty。V/Vs/Each の shift_values は source の WF と通常の場所の保存、CQ は WF と全場所の保存を受ける |
| 3族 | 移動・値の相互置換・narrowing の各族に、追加したV6/C4の全場合を加えた。hide_context、像の params/none、公開の subst/subst_under_none/narrow に StoreTy.WF を接続した。局所参照はまだ追加していない |
| 型付きの観測と事実 | TypedFacts の observation/assume/assume_optional/data_observation/observation_declared/observation_references にV6の全場合を追加した。V_Con は宣言の owner/型引数/欄数を保つ。Vs の長さ・観測の参照・宣言照合の各入口も追加した |
| 具体化と値注釈の交換 | Ty.bind_data、Ty.subst_shiftV_closed、SubstEnv.normRows、Ty/Tel/Eff.bind_normRows、normBindTys_normRows、Ty.subst_norm_typeImages/subst_norm_rowImages/subst_norm_images_all、Ty.substV_subst_closed_rows/subst_shiftV_closed_rows。型/行の像を先に正規化する場合も扱い、行引数をCanonicalに限定しない |
| 許容の定義 | SatAll、QTy/QTel/QTys/QEff/Qsig、Ty/Tel/Eff.RowsIn、NoFail/RowTransport、Admissible/PrimitiveAdmissible/MethodRowsAdmissible。scope の nv を独立に持ち、値依存型引数を除かない。呼出しの葉への接続・移送・kind の供給は未完了 |

新規本番ファイルは [Admissible](../../../formal/Benitoite/Release/Refinement/Admissible.lean)、[StoreTransport](../../../formal/Benitoite/Release/Refinement/StoreTransport.lean)、[TypingDeclared](../../../formal/Benitoite/Release/Refinement/TypingDeclared.lean)、[ValueInstantiation](../../../formal/Benitoite/Release/Refinement/ValueInstantiation.lean) の4である。既定 import に含めた。変更した本番Leanは15ファイル（新規4・既存11）、そのファイル群の行数は2,939→3,605、純増666行である。[全一覧とハッシュ](02b-values-source-changes.json)と[差分](02b-values-production.patch)を保存した。

### RV-L00b.02a 中1と補助契約の判断

V_Lam/V_List の Declared の追加と、値からの Declared の正則性は閉じた。変数は元から任意の Γ の lookup だけで型付けられるため、正則性は Ctx.Declared を前提にする。V_Var 自体へ新しい前提を加えていない。計算の全規則から結果型の Declared を取り出す一般の正則性は、群の残りとして未完了である。

この追加で利用者の書ける形は狭まらない。未宣言の data 名・不適格な欄の参照は表層で拒まれ、ラムダの契約と空 List の要素型も、表層で解決済みの型を注釈にするからである。今回の Declared はそれらの宣言との照合をコアにも要求する。これは source とコアの全対応を証明済みという主張ではなく、群末の独立レビューとL70で確かめる根拠である。

補助契約の採った案・理由・捨てた案は signatures 第21節へ記録した。主なものは、(1) Annotation の三欄、(2) 文脈を前提にした正則性、(3) source の StoreTy.WF と通常/全場所の二つの保存関係、(4) 空ストアからの弱化による既存の障害例の言明の維持、(5) nvを引数にする許容、(6) 行の像の正規化との交換、である。

### 停止した理由と未採用の案

本番の `B.sat` と `PrimSig.admits` は任意の型/型列の述語である。元の sat/admits と、型付きの値の像・sort/References/Declared/WF だけでは、値移送後の sat/admits を導けない。[境界入力](02b-values-constraint-boundary.lean)は、sat について、既存の型/行の置換・型文脈の延長・制約なしの条件を満たしながら、整形式の篩付き型を整数0で値置換すると鍵の条件が失われる表を示す。移動の場合も同じ不足を示した。これはその条件の独立性の証拠であり、全CoreAssumptionsと新StateTyを満たすモデルの主定理への反例とは区別する。

葉ごとに sat/admits の移送に閉じた条件を要求する案も検討したが、元の sat/admits からその条件を供給できないため、本番から外した。利用者の書ける形と旧導出の範囲を狭めない証明を後送し、3族だけを完成させる処置は採っていない。型引数を値非依存に限る案も採っていない。

推す案は、値置換と単調な改名についての sat/admits の保存を組込みの信頼条件に明記し、三モデルで証明する案Aである。主な定理が読む前提に独立した条件が加わるため、補助契約の委任だけでは確定しない。案Bは制約を判定する型の構造への写しを定義するものだが、こちらも制約の解釈の変更を要する。具体的な署名の要旨・対案・追加の能動時間と残りの工程は停止点の契約に記した。D28/F Q07 の既存の了承内としてAを扱えるかの判断も取りまとめへ返す。

### 場合の数：予定と現在

| 対象 | 群末の予定 | 現在・閉じた範囲 |
|---|---:|---|
| 値/計算の追加 | V12/C7 | V6/C4。残りV6/C3は未完了 |
| 3族の累計 | V18/C12/Vs2/Each2=34、各族 | **V12/C9/Vs2/Each2=25、各族**。今回10場合を加えた。現存する導出の未処理場合は0だが、群末の34場合の完成ではない |
| TypedFacts の予定の2入口 | observation18＋assume18=36 | observation12＋assume12=24。今回6×2=12場合追加 |
| TypedFacts の追加の補助入口 | 全ての追加葉へ追随 | assume_optional12、data_observation12、observation_references はV12/Vs2/Each2=16、observation_declared も16。合計56。`.02a` の28から28増であり、予定の2入口とは分ける |
| Declared の正則性 | 群の型付け全体 | V12/Vs2、Ctx.Narrows.of_value。CQ等の一般化は残り |
| 構文 | Val19/Comp13/Capture1/Closure1、Frame等と旧68遷移 | Val19/Comp13/Arm1/Clause2/Capture1/Closure1。LocTy4は維持。Frame/Cell/State/Event、Step/step、旧値・状態の埋め込みは未完了 |

実際の構成子数は [公理依存の入力](02b-values-axioms.lean)が Lean の metadata で照合した。派生した空ストアからの弱化や整数の系を、新しい根の場合として二重に足していない。L10/L20 から移す時間は第12.2節のこの単位では0であり、今回閉じた10場合や具体化の交換を後段で再計上しない。

### 検査と証拠

[再実行用の台本](02b-values-validate.py)で、次を実行した。[全結果](02b-values-validation.json)、[コマンド・終了・外側の時間](02b-values-commands.json)、[本番380入力のハッシュ](02b-values-inputs-final.json)、[補助入力のハッシュ](02b-values-artifact-inputs.json)を保存した。検査の前後で本番入力のハッシュは一致している。

| 検査 | 結果・実行時間 | 根拠 |
|---|---|---|
| `cd formal && lake build` | 終了0、既定623 jobs、2.826秒。旧体系・並置体系・全既定ターゲットを含む | [出力](02b-values-build.log) |
| 制約と場所の境界 | `lake env lean -M 12288 …/02b-values-constraint-boundary.lean`、終了0、0.530秒。satの不足、型付きの像、場所を空ストアへ消せないことを確認。17宣言の公理依存も照合 | [入力](02b-values-constraint-boundary.lean) / [出力](02b-values-constraint-boundary.log) |
| 既存の参照・sort等の境界 | r4の入力を変更せず実行、終了0、0.638秒。None/cont・snapshot・self/外側・宣言照合等を保持 | [出力](02b-values-previous-boundary.log) |
| 既存kindの境界 | r5の入力を変更せず実行、終了0、0.388秒。21宣言の公理依存も照合 | [出力](02b-values-kind-boundary.log) |
| 新規/変更宣言の公理依存 | 既定importの全50モジュール・6,543宣言を検査、終了0、4.935秒。privateと生成宣言を含み、今回の新規/変更を包含。使用は propext/Quot.sound/Classical.choiceだけ。独自公理・sorryAxなし | [入力](02b-values-axioms.lean) / [集計](02b-values-axioms-summary.json) / [生の出力の大きさとSHA-256](large-records.md) |
| 担当範囲・抜け道 | 本番Refinementに sorry/admit/axiom/native_decide/implemented_by/unsafe/partial の語の検出なし。設定と固定版は変更なし。Leanは既定・単独とも-M 12288 | [結果](02b-values-validation.json) |
| 重複Mapの本番型付け | **未実施**。V_Mapを本番へ置く前に停止した。境界入力のmap_premisesを、本番V_Mapの重複受理の証拠と呼ばない | 再開後、この群の末で実施する |
| work / RSS | workは起動依頼に従い未実行。RSSは未取得（計画上の非採取） | 取りまとめの担当を維持 |

Leanは4.34.1、手元のmacOS arm64である。既存Intervalの警告は再表示されるが、最終のRefinementの警告は0件である。公理の依存の生の出力は669,661バイトで一時領域へ置き、改造には大きさとSHA-256だけを残した。

途中は、相互定義の引数の追随、raw/normの像とmapの関数の等号、境界の帰納法の一般化の不足で局所検査が失敗した。各箇所を修正し、上の最終入力で再確認した。途中の失敗で Lean が回復用に生成した sorryAx の出力は成功の証拠にしていない。最終の境界と全宣言の公理依存には残っていない。

既存の障害例は、構成子の引数の追随と、空ストアからの型付けを目的の任意のストアへ移す証明へ直した。元の言明と、不正なraw置換・継続の篩に対する反例を保った。Rustテストの追加・変更・削除は0件である。境界入力は本番の型付け・SubstOk・ストアの保存関係を使い、新しい本番の差し込み口は設けていない。制約の例は新構文の論理的な不足の照合であり、旧Rustの退行を再現したテストとは呼ばない。`test-audit` の作成時の関門をこの区別で適用した。

### 残りと送り先

| 残り | 送り先・条件 |
|---|---|
| sat/admitsの移送の信頼条件・制約の解釈の判断 | 取りまとめ・設計者。本停止点の契約のA/B、又は別の供給経路を確定する |
| V_Fun/Prim/Op/Map/Set/Dict、C_BuilderLet/BuilderOp/Meth | **同じ `.02b-values` の再開**。新しい構成子に対応する3族/TypedFactsを含む。V_Map/V_Setに重複なしの条件を足さない |
| primitive等のkind/Declared、許容の移送、計算の正則性、局所参照/None版 | 同じ群の再開。型引数の外側の値依存を除かず、LocalRef.HasKind/LocalSubstOk/LocalCtx.Shiftを閉じる |
| Captureの操作、Frame/Cell/State/Event、旧68遷移/step、埋め込み | 同じ群の再開。今回置いたCapture/Closureの型だけを、実行や捕捉の保存の完成にしない |
| 群末の34場合の検証・重複Map・結果更新・独立レビュー・work | 担当が本番と検証・記録を仕上げ、取りまとめが独立レビューとwork。受け入れは設計者 |
| 外部の群 | `.02b-values` を完了しレビューするまでは起動しない。今回の未完了を外部群の内数へ移さない |
| RV-.02a 中2/軽2 | 既定どおり `.11` のdata変性と `.13` の複数構成子の欄。今回の停止とは別の義務として維持 |

O002/O004/O006/O009/O029/O040/O042/O159等のうち、この節に列挙した定義と現存する25場合だけを本番で閉じた。義務全体と群全体は未完了である。O016は今回の50モジュールの照合範囲だけで、L00b全体のA-Lの完了ではない。O169の共有層は `.02c` のままである。

### 外側の時間と計画からのずれ

開始は2026-10-31 06:02:14 JST、最終検査終了は06:32:41 JSTで、外側の時間は1,827.53秒（約30.46分）だった。文書・依頼の仕上げを含む受け渡し時点は `02b-values-delivery.json` に保存する。能動時間と待ちを分離していないため、能動時間の実測や較正の比には使わない。見込み2〜4時間の上端の2倍（8時間）による停止ではない。

計画からのずれは、群を完成する前に、組込みの制約について新しい信頼条件又は制約の解釈の判断が必要になったことである。新しい前提を主な定理へ加える代わりに停止した。独立レビューと受け入れは未実施であり、この報告を群末の完了報告へ読み替えない。

## `.02b-values`：案Aでの再開と群末（2026-10-31）

**この起動単位の実装と群末の検査を終えた。** 群末の独立レビューは条件付き可（重なし、中2・軽5）であり、所見への対応は本節末「レビューの所見の対応」に記す。受け入れは未実施である。 取りまとめが採った案Aを [signatures 第22節・第23節](signatures.md) と本番に反映した。上の停止点の節・その入力と出力は当時の記録として保持する。今回の最終入力と検査は `02b-values-r2-*` を正とする。外部の群には進んでいない。

基準 B_WORK は `fb9afed8a9dc800ea558c07ccdc7c589b40118f8`、指定ブランチは `m014/l00b.02b-values` である。gitの照合・操作、処理系・現行設計書・plan.mdの変更、作業末のworkは行っていない。

### 完成した定義と補題

| 群 | 今回の最終状態 |
|---|---|
| 値の葉12 | **V_Fun/Prim/Op/Raise/Con/LocRef/LocLazy/Map/Set/Bytes/Dict/Super** を本番に置いた。Fun/Prim/Opは依存列の具体化を保つ。Conは宣言の名目型・型引数のkind・欄数を照合する。Map/Setには重複を拒む前提を足していない |
| 計算7 | **C_BuilderLet/BuilderOp/If/Lazy/Escape/Use/Meth**。builderの局所参照、Noneとkind内の値参照、lazyのhide、通常資源とState、メソッドの逐次具体化を接続した |
| 案Aの四条件 | Builtins.ValueAssumptionsのsat_rename/admits_rename/sat_values/admits_values。型・型列のWF/Sorted/Declaredと型付きの値の像を明示する。CoreAssumptionsがこの証拠を含み、CoreAssumptions.valuesから補助定理へ供給する。Leanの公理ではない |
| 許容とkind | TypeAnnotations/RowAnnotations/SignatureInstance/TypeArgsKinded、RangeExpr.FitsKind/WF/Canonical、Builtins.RangeAdmissible。Admissible/PrimitiveAdmissible/MethodRowsAdmissibleの移動・値置換・narrowingを各葉へ接続した。Ty.HasKindのrawSubstV/norm/bind_values/shift_valuesと型列のkind保存を閉じた |
| 3族 | HasTypeVQ/VsQ/EachQ/CQの**shift_values/subst/narrow**の全34場合を閉じた。各入口へValueAssumptionsとStoreTy.WFを渡す。値は通常の場所を保存するストア、計算は全場所を保存するストアへ移動する。CQはLocalCtx.Shift/LocalSubstOkを受け取り、hide_contextとsubst_under_noneも追随した |
| 宣言照合の正則性 | HasTypeVQ.declared、HasTypeVsQ.declared、**HasTypeCQ.declared**、Ctx.Declared、Ctx.Narrows.of_value。V_Lam/List等の注釈と、C_Let/BuilderLetの外側の結果にDeclaredを明示した |
| TypedFacts | observation/assumeの両入口をV18へ追随。assume_optional/data_observation/observation_declared/observation_referencesも全葉と関係するVs/Eachへ追随した。V_Conの宣言・名目型・欄数、Mapの鍵列と値列の両方を保持する |
| 値と具体化の交換 | Ty.substV_subst_closed_rows/subst_shiftV_closed_rowsと正規化した型・行の像の交換。instantiatedTel_shift/substとそのTelの等式、RowTransport.map、三つの許容のmapを閉じた |
| メソッドの実引数 | Tel.argumentsが、先行する実引数で次の引数型・最終契約を逐次具体化する。opening_comp、Tel.bind_values_comp/bind_open_exchange、arguments_subst/map/shift/norm/normalを閉じた。部分観測のNoneを勝手に通常項へ変えない |
| 局所参照 | LocalRef.HasKind、LocalCtx.Shift、LocalSubstOk、各extend/empty、HasKind.shift/lift/subst、renameKind/substKindの閉性と束縛の交換。Noneを増やす場合も既存のkindの値注釈をshiftする |
| Captureの操作 | env/closeTy/Eff/R、各At版、closeTel、extend/extendNone/extendMany、closeVal/closeVals、Closure.pure/apply/view。lam/dependentLamを捕捉したclosureへ写し、既存closureは保持する |
| 状態と実行 | **Frame7/Cell6/LocTy4/State4、Event2（io/release）、旧68遷移とstep**。Stepsはnoneを事象列へ加えない。σを固定し、外部oracleの公開引数を先に置いた。旧68構成子の名前・順序は完全一致 |
| 旧の埋め込み | Val17/Comp13/Arm1/Clause2/Frame7/Cell6/LocTy4/State4、Def/ConDecl/OpDecl/MethSig/ClassDecl/ImplDecl/Program、Cont/StoreTy/Store/Outcome/Eventを写す関数。宣言のparamsの各位置、ret/effは必要な引数数だけshiftして依存列へ格納する。embedStore_setと長さの補題も閉じた |

追加した公開の定義・補題277名を [一覧](02b-values-r2-public-api.md) に記した。これは手で宣言した名前の一覧であり、生成されたrecursor・射影等は含めない。新規本番Leanは17、変更した既存Leanは11、合計28ファイルである。[全変更とSHA-256](02b-values-r2-source-changes.json)と[全393入力のSHA-256](02b-values-r2-inputs-final.json)を保存した。既定importに全63モジュールを含む。

### 場合数の予定と実際

| 対象 | 予定 | 実際・照合 |
|---|---:|---|
| 追加する導出 | V12/C7 | **V12/C7、19場合**。停止時点のV6/C4から残りV6/C3を追加した |
| 3族の累計 | 各V18/C12/Vs2/Each2=34 | **各34、3族合計102**。今回の起動全体で各族に19場合追加。Leanが各相互matchの全場合を検査し、構成子数もmetadataで照合した |
| TypedFactsの予定の2入口 | observation18＋assume18 | **36**。今回の追加12葉×2=24場合を含む |
| TypedFactsの補助入口 | 全葉 | assume_optional18、data_observation18、observation_references22、observation_declared22、**計80**。Vs/Eachの各2を含む。派生する整数の系やassumeの系を根の場合へ二重に足さない |
| 正則性 | 値・値列・計算 | V18/Vs2/C12。Each.nilだけから要素型のDeclaredを取り出す言明は置かない |
| 構文 | Val19/Comp13/Capture1/Closure1 | **予定どおり**。Frame7/Cell6/LocTy4/State4、BuilderContents3、LocalRef.HasKind2、Event2、Step68/Steps2も照合した |
| 旧遷移の被覆 | 68 | **名前・順序とも68件一致**。[一覧と照合](02b-values-r2-step-coverage.json) |

### 補助契約で採った判断

採った案・理由・捨てた案の詳細は signatures第22・23節に残した。担当が確定したのは次の補助の細部であり、案Aを超える主な定理の前提・結論の変更、新しい公理、提供範囲・利用者の書ける形・精密な外部状態の変更は加えていない。

1. sat/admitsの保存はValueAssumptionsの独立した四条件として受け取る。各葉を「移送に閉じた型だけ」の別の受理条件へ変える案と、型引数を値非依存に制限する案は採らない。
2. AnnotationはWF/Sorted/Declaredを持ち、kindは宣言のkind列で別に照合する。高カインドの型引数をvalueに固定しない。行引数の失敗型の注釈も呼出し側のΓで照合する。
3. 宣言の依存する型・行はTelとして具体化する。C_Methは純粋なTel.argumentsと既存Vs判断を使う。TelArgs二導出の追加は外部の群の予定を維持し、この群の数を増やさない。
4. ストアの型は閉じたものを保つ。値にはPreservesNormals、計算にはExtendsを要求する。場所を全て消す移送は認めない。
5. 局所文脈は通常の値と同じ番号を持ち、Noneを延ばしてもkind内の外側の参照をshiftする。任意のρで計算を移す案は捨て、LocalSubstOkを要求する。値の任意ρは保持した。
6. C_Let/BuilderLetの結果のDeclaredは明示的に検査する。shift後の本体から逆向きに推論する補助へ依存させない。
7. Closure.viewで一歩に必要な値を閉じ、内部のcodeはCaptureとともに残す。実引数は一度だけ環境へ追加する。旧lamの実行上のTelの終端unit/emptyは型の証拠として使わず、結果型・効果は後の捕捉した型付けの証拠が検査する。
8. 旧の埋め込みは情報を保つ構文の変換として置く。開いた旧状態の閉性や、旧の全型付け・遷移の保存を証明済みとは扱わない。

RV-L00b.02a中1について、値に加えて計算全体から結果型のDeclaredを取り出す正則性を閉じた。変数の型はCtx.Declaredから取り出し、narrowingのhereにはCtx.Narrows.of_valueで供給する。未宣言の名前・不適格な欄参照は表層で既に拒まれ、ラムダや空コレクションの注釈も解決済みの型である。今回の追加はその宣言照合をコアにも明示するもので、型注釈の構文を減らさない。この根拠と、捕捉境界・空のコレクション・高カインドの型引数を群末の独立レビューで確認する。表層との全対応の証明自体はL70の担当のままである。

既存のraw置換・篩の継続に対する障害例は削除していない。一般の移送の補題を呼ぶ正のwitness7件は案AのValueAssumptionsを明示して呼出しに渡し、ストアの弱化にも同じ証拠を渡す。負の言明には案Aを勝手に足していない。

### 群末の検査

[再実行用台本](02b-values-r2-validate.py)、[全結果](02b-values-r2-validation.json)、[コマンド・終了・時間](02b-values-r2-commands.json)、[補助入力のハッシュ](02b-values-r2-artifact-inputs.json)を保存した。最終検査中の本番393入力は前後で一致した。

| 検査 | 結果 | 証拠 |
|---|---|---|
| 旧体系・並置体系・全既定ターゲットのLeanビルド | `cd formal && lake build`、**終了0、636 jobs**。最終の入口はキャッシュ利用0.155秒であり、全636ファイルを新たに検査した時間とは呼ばない。途中の関係するビルドで変更した本番をコンパイルした | [出力](02b-values-r2-build.log) |
| 案A・重複Map・場所・Captureの境界 | `lake env lean -M 12288 …/02b-values-r2-constraint-boundary.lean`、**終了0、0.648秒、30宣言**。Integerの外側の値を区別するsat/admitsの表はValueAssumptionsを満たさない。満たす表では依存鍵型のMapの置換が通る。重複Mapの本番型付け、場所を消すストアへの移送不能、let/関数適用の捕捉値と一度だけの追加を確認 | [入力](02b-values-r2-constraint-boundary.lean) / [出力](02b-values-r2-constraint-boundary.log) |
| 既存の参照・sort等の境界 | r4の入力を変えず実行、**終了0、0.648秒**。None/cont・snapshot・self/外側・宣言照合等 | [出力](02b-values-r2-previous-boundary.log) |
| 既存kindの境界 | r5の入力を変えず実行、**終了0、0.385秒、21宣言の公理依存も照合** | [出力](02b-values-r2-kind-boundary.log) |
| 新規・変更宣言の公理依存（A-L） | 全63モジュール・**7,448宣言**を検査、**終了0、5.978秒**。非公開・生成宣言を含み、報告件数・一意な件数・モジュール別件数が一致。使用は **propext/Quot.sound/Classical.choiceだけ**。独自公理・sorryAxなし | [入力](02b-values-r2-axioms.lean) / [集計](02b-values-r2-axioms-summary.json) |
| 構成子数・抜け道・設定 | 3族の34場合、Step68等をLean metadataで照合。本番Refinementにsorry/admit/axiom/native_decide/implemented_by/unsafe/partialの語の検出なし。Lean4.34.1、既定・単独とも **-M 12288**。固定版・lake設定は変更なし | [結果](02b-values-r2-validation.json) |
| work・RSS・Rust | workは依頼どおり取りまとめへ残した。RSSは未取得（計画上の非採取）。Rustのテストの追加・変更・削除は0件 | 同上 |

大きな生の記録は、公理依存762,611バイトと差分206,185バイトを一時領域へ保存した。改造には [large-records.md](large-records.md) の大きさ・SHA-256だけを残し、100 KBを超える生の記録を追加していない。台本・文書に手元の絶対パスを記していない。

途中の局所検査は、追加した前提の呼出し、相互定義の新しい場合、raw/normの交換、Captureを持つ状態への移植、補助入力の引数の不足で失敗した。修正後の最終入力で上の検査を全て通した。失敗時の回復用sorryAxを成功の証拠にはしていない。新しいRefinementの警告は残していない。既存Intervalの警告の再表示は維持した。

### 残る義務と次の群への申し送り

| 義務・残り | 担当・時期 | 今回の判定と根拠 |
|---|---|---|
| `.02b-values` の値12・計算7・3族34・TypedFacts・Declared・状態構文・旧68遷移/step・埋め込み | 今回の担当 | **実装と検査を完了**。本節とr2の入力・出力。今回受け持つ未完了を外部の群へ移していない |
| 案Aの三モデルのsat/admitsの充足 | L50（三モデル）、L60/L70（接続）、`.15`（信頼条件の比較） | 条件の言明とCoreAssumptions.valuesによる供給を今回置いた。モデルの実装・充足は未実施。signatures第22節の義務の対応表に固定した。carrierの骨格から定め、篩と外側の値の番号を判定に使わない |
| 外部の5導出とTelArgs | 次の `.02b-external` | 今回のVal19/Comp13/Step68へ追加する。Tel.argumentsとMethodArgumentsの交換を再利用できる。外部pureの無事象、external_typedのno-exit、名目ID、TelArgsの各束縛の3族は同群で閉じる |
| At・保持値、handlers、closuresの判断と型付き状態 | それぞれ既定の後続単位 | CQ/NoneのR0拘束とImageOkへの切替はhandlers。旧lamのlambdaShapeの終端を静的契約として信頼しないこと、CaptureのΓ/Φとbodyの証拠、全状態・step_soundの接続はclosures/.14a/L20/L70。今回それらの完了を主張しない |
| Program.WellTyped、文脈・全注釈のkind/WF/Declared | `.03` | SignatureInstance/TypeArgsKindedへの供給を接続する。V_Conの名目型・宣言の観測と今回の呼出しのkind照合は本番に残した |
| RV-.02a 中2/軽2 | `.11` / `.13` | data変性、複数構成子の欄の既定の義務を維持 |
| 独立レビュー・work・受け入れ | 取りまとめ・設計者 | [群末レビュー依頼](../reviews/RV-L00b.02b-values-request.md)を更新。独立レビューの判定と所見への対応は本節末に記す。work・受け入れは未実施 |

O002/O004/O006/O009/O029/O040/O042/O159等は、この起動単位の定義・34場合・構文・遷移を本節の証拠で閉じた。O016は63モジュールの今回の照合範囲を閉じ、L00b全体のA-L完了とはしない。O010/O160の較正は通常の外側の時間を取りまとめへ返す。O169の共有層は`.02c`の担当を維持する。提供範囲と設定のCLI照合等、今回に割り当てられていない義務全体は閉鎖していない。

### 外側の時間と計画との差

再開の時刻は **2026-10-31 06:41:34 JST**、最終検査終了は **07:19:36 JST**、外側の時間は **2,282.83秒（約38.05分）** であった。前の停止までの作業と、再開を待った時間は混ぜない。文書・依頼の仕上げを含む今回の受け渡し時点は `02b-values-r2-delivery.json` に記す。能動時間と待ちを分離しておらず、能動時間の比を実測したとは扱わない。上端の2倍の8時間には到達していない。

計画からの変更は、承認された案AのD28の意味の追加と、その証拠を3族に明示したこと、C_Methで既存Vsと純粋な逐次具体化を使った補助契約の選択である。主要な場合数・今回の提供範囲・後続の順序は変えていない。前回の停止点の残りを今回の内数で仕上げた。独立レビュー・取り込み・workは取りまとめの担当のままである。


### レビューの所見の対応（RV-L00b.02b-values、2026-10-31）

[群末の独立レビュー](../reviews/RV-L00b.02b-values.md)は**条件付き可（重なし、中2・軽5）**であった。取りまとめのplanの2026-10-31の先頭の判断に従い、以下の契約・担当・依存をsignaturesに固定した。今回の変更はsignatures.mdと本小節だけである。後続の定義の改訂や定理の証明を今回済ませたとは数えない。

| 所見 | 直した箇所 | 対応・残る義務 |
|---|---|---|
| 中1 | signatures **第2.2節・第12.2節の.02b-valuesの行・第24節**。現行の入口と将来の契約の区別は第10.1節にも注記 | 案(ii)のkind表を引数に与える案を採り、D29の定理に旧導出の型引数のkindの整合を前提として置く。宣言・プログラムの埋め込みの定義の改訂と旧導出の埋め込みの定理はL20、合成・表層の照合はL70。案(i)は旧の定理の対象を狭めるため採らない。現行Leanのvalue固定の補助は今回変更していない |
| 中2 | signatures **第24節の義務の対応表**、第12.2節の.02b-closuresの行 | D29の旧のV_Fun/V_Prim/V_Op由来のfn型の位置の埋め込みが、.02b-closuresのC_DependentAppと.11のfn/dependentFnの正規化後の等号に依存することを一行に固定した |
| 軽1 | signatures **第23.2節**、第24節の対応表 | 型を変えないnarrowing・hide・空ストアからの弱化のValueAssumptionsは、改名の補題の再利用による前提であり、意味上の必要ではないと注記した |
| 軽2 | signatures **第24節の義務の対応表** | .03で外側の型パラメータのkindを宣言から与え、TypeArgsKindedのKをそれに固定する。開いた文脈のkindの一貫性はこの接続で確認する |
| 軽3 | signatures **第24節の義務の対応表** | L50の三モデルの骨格はエフェクトを読まないか、集合として読む。Fail列の正規化による整列・重複除去を含めて案Aの保存を証明する |
| 軽4 | signatures **第24節の義務の対応表**、第12.2節の.02b-closuresの行 | .02b-closuresとL20で、場所の型のDeclaredをStoreOk等の不変条件として保持し、生成・保存からV_LocRef/V_LocLazyへ供給する |
| 軽5 | signatures **第24節の義務の対応表** | L20・L70で旧の遷移の埋め込みにNamesWFを前提として置き、旧のparams.lengthとTel.arityの一致を供給する |

本番のLean・処理系・現行設計書・plan.mdを変更せず、gitの操作と次の群の実装も行っていない。今回は文書の契約・担当・依存の照合と相対リンクの検査を行い、既定ビルドと公理依存の検査は再実行していない。前節のr2のビルド・公理依存の記録はその本番入力の結果として保持する。この記録の修正を、後続の義務の実装完了や再レビューによる受け入れと同一には扱わない。

文書の照合では、変更禁止範囲の4,776ファイルが今回の編集前と一致し、前回のr2の本番393入力も全て同じSHA-256であることを確認した。二文書の相対リンクは全件解決し、signaturesの対応表と本小節に中2件・軽5件の計7行がそろっている。最初の時刻取得07:42:41 JSTからこの照合の時刻07:45:51 JSTまでの外側の時間は約3.17分であり、能動時間と待ちを分離した値ではない。

## .02b-values の作業末の work（取りまとめ、2026-10-31）

- 基準: `fb9afed8a9dc800ea558c07ccdc7c589b40118f8`。作業ツリーは案 A での再開を終えた状態。その後の RV-L00b.02b-values の所見の対応は文書だけで、本番の Lean は変えていない。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base fb9afed8a9dc800ea558c07ccdc7c589b40118f8`（sandbox の外）。選ばれた単位は `formal_build`（`cd formal && lake build` と `sorry` を使う宣言の拒否）だけである。最大常駐量が Lean の検査を表すように、先に `formal/.lake/build` の `Benitoite/Release/Refinement` の生成物（lib と ir）を消した。
- 結果: 終了0（selected checks passed）。外側の時間は36.72秒、最大常駐量は966,918,144バイト（約0.90 GiB）。
- 計画からのずれ: 起動単位の表の見込みどおりの範囲を、停止と再開（案 A）を挟んで閉じた。

## `.02b-external`：外部と依存する実引数列の群末（2026-10-31）

**この起動単位の実装と群末の検査を終えた。** 次のσ/Atの群へは進んでいない。群末の独立レビューは条件付き可（重なし、中1・軽4）であり、所見への対応は本節末「レビューの所見の対応」に記す。work・受け入れは取りまとめ・設計者の担当であり、今回の完了には含めない。基準B_WORKは `9184a3ced427d4897fcb234d2ac277f95b60ac0f`、指定ブランチは `m014/l00b.02b-external` である。前の群の取り込み08f9ac72・f42ab9aaは依頼の指定値を使い、gitによる照合・操作を行っていない。処理系・現行設計書・plan.mdは変更していない。

### 置いた構成子と閉じた定義・補題

| 群 | 本番へ置いたものと閉じた範囲 |
|---|---|
| 外部の値・計算と5導出 | Val.externalRef/externalHandle、Comp.externalCall。V_ExternalRef/ExternalHandle、C_External、HasTypeTelArgsQ.done/param。既存の値・計算を除かず、V_ExternalRefはSignatureInstance、ハンドルはID・component/resource・arity・Annotationを照合する |
| 宣言表と名目性 | 外部の型/関数/成分のID、ExternalMode/TypeDecl/Position/PathStep/Use/Signature/Decl/Key/Handle、Program.externals/externalType/externalFunction/ExternalWF。有限表のkeyと宣言内ID・重複を検査し、ExternalWF.type_lookup/function_lookupで適格性を取り出す。Ty.Declaredのexternalで未知のID・不正なarity・全型引数を検査し、Declaredの置換/正規化の保存も追随した |
| 外部の署名 | ExternalValueType、ExternalMapKey、ExternalOccurrence、ExternalUseAt、ExternalTelWF、ExternalSignature.WF、ExternalCallAdmissible。非再帰の具体化の有限な導出、全入れ子の外部型、引数borrow/結果own、component、usesの過不足、外部型がある場合だけState、単相・arity 0を検査する。WITのABI全体の照合器ではない |
| 3族 | **HasTypeVQ/VsQ/EachQ/CQ/TelArgsQのshift_values/subst/narrowを累計各39場合で閉じた。** TypedFactsの全入口と、値・値列・計算のDeclared正則性も新しい葉へ追随した。TelArgsのhide_context/subst_under_noneはRを持たず、任意の局所参照の像を保つ |
| 依存列の交換 | Tel.bind_norm/bind_renaming/open_shift/open_subst、instantiate_eq_arguments/instantiate_subst/instantiate_shift。paramの下のup/cutoffと、実引数の部分観測を保つ逐次具体化を交換する。前の群のbind_open_exchange等を再利用し、外側の値依存を除外していない |
| TelArgsからの取り出し | result_annotation/declared/normal/instantiate/length/arguments。最終契約、検査した引数型列、HasTypeVsQ、結果型のWF/Sorted/Declaredを同じ導出から取り出す。ExternalArgs.instantiateで外部署名の具体化へ接続した |
| 閉性と応答の三欄 | Val/Comp/Arm/Clause/Capture/ClosureのClosedAtとVal.Ground、ExternalArgs、Outcome.Typed、ExternalSignature.instantiate。Builtins.ExternalAssumptionsのexternal_typed/exists/no_targetsをCoreAssumptionsへ接続し、external_typedのno-exitを保った。第四の外部仮定は加えていない |
| 意味論と実行関数 | E_ExternalApply/External/ExternalErrを既存Stepへ追加し、すべてnoneのラベルとした。Closure.viewで型引数と実引数を捕捉環境で閉じる。stepがExternalOracleを使い、val/errだけを無事象で実行する。Eventはio/releaseの2形のまま、E_ExternalExitはない |
| 埋め込みと既存の障害例 | 旧Programの外部表を空列に写し、embedProgram_externalsを置いた。旧Val17/Comp13等の埋め込みはそのまま維持する。既存の生の置換・narrowingの障害例は言明を変えず、新しい構成子の不可能な場合だけを追加した |

本番の新規Leanは [External](../../../formal/Benitoite/Release/Refinement/External.lean)、[ExternalResponse](../../../formal/Benitoite/Release/Refinement/ExternalResponse.lean)、[Ground](../../../formal/Benitoite/Release/Refinement/Ground.lean)、[TelTyping](../../../formal/Benitoite/Release/Refinement/TelTyping.lean) の**4ファイル**であり、すべて既定importに含む。新規4・既存20、合計24ファイルを変更した。これらの行数は5,239→5,897、純増658行である。[全ファイルとSHA-256](02b-external-source-changes.json)、[差分](02b-external-production.patch)、[追加した公開宣言62名](02b-external-public-api.md)を保存した。62名は手で付けた名前であり、構成子・射影・recursor等を重ねて数えていない。

### 場合の数の予定と実際

| 対象 | 予定 | 実際と確認方法 |
|---|---:|---|
| 追加した導出 | V2/C1/TelArgs2=5 | **5**。V_ExternalRef/ExternalHandle、C_External、done/param |
| 3族の累計 | 各39 | **V20/C13/Vs2/Each2/TelArgs2=39、三族で117**。前の34から各5場合追加。相互のmatchの網羅性はLeanが検査し、構成子数もmetadataで照合した |
| TypedFactsの予定の2入口 | observation20＋assume20 | **40**。追加2葉×2=4場合。整数の系を別の場合へ重ねていない |
| TypedFactsの補助入口 | 全葉・関係する列 | **assume_optional20/data_observation20/observation_declared24/observation_references24=88**。後二つはV20/Vs2/Each2を含む |
| 宣言照合の正則性 | 新しい葉・外部計算 | V20/Vs2/C13とTelArgs2。TelArgsから結果のAnnotationも導く |
| 構文 | Val21/Comp14/Step71 | **予定どおり**。Capture1/Closure1、Frame7/Cell6/LocTy4/State4、Event2/Steps2も維持 |
| 旧遷移 | 旧68をすべて維持 | **旧68件の名前と順序を維持し、新規3件を追加**。[照合](02b-external-step-coverage.json) |

TelArgsの直接の相互入口はTypingShiftの `HasTypeTelArgsQ.shift_values`、SubstTypingのprivate `subst_telArgs`、Narrowingのprivate `context_telArgs` である。公開のsubst/narrow/hide/None版やinstantiate等の系へ同じ根の場合を重ねて配賦していない。第12.2節どおり、外部型のWF/宣言照合の追随をL10から1時間、依存列の相互置換と逐次具体化をL20から1〜2時間移す枠として扱う。今回閉じた分をL10/L20で再計上しない。この額は能動時間の配分であり、今回の実測時間ではない。

### 補助契約で決めたこと

[signatures第25節](signatures.md)に完全な入口と、採った案・理由・捨てた案を記録した。

1. Ty.Declaredのexternalでも、有限表のID・arityと型引数を検査する。葉だけに検査を置く案は捨て、全入れ子の注釈にも適用した。
2. 受け渡すdataは、全構成子の有限一覧と具体化後の全欄の有限な導出で検査する。祖先のdata名だけで一律に循環とする案は、有限の同名の入れ子も拒むため採らなかった。
3. Mapの鍵は篩のcarrierを辿る。最外のbaseだけを許す案は採らない。Unitの省略等を含むWITのABIの細部は既定の表層・交換で照合し、表示名から標準型を推測しない。
4. 外部呼出しの型引数はcount/kind/SatAll/Annotationを明示して検査し、ExternalSignature.WFから現行の空列を導く。一般の型引数の外部型や値依存型まで制限せず、ソースの多相externalも追加していない。
5. 外部ハンドルにはAnnotation、外部関数の参照にはSignatureInstanceを渡す。WFだけからDeclaredを得る案は採らない。
6. TelArgsは同じΓ/Φで各実引数を読み、restを逐次bindする。非依存Vsだけの検査や、Γへ全実引数を先に束縛する案は採らない。paramの下の交換、Rを持たない相互補題、hide/None版は今回閉じた。
7. 外部応答は三欄とno-exitをCoreAssumptionsへ接続した。Event.external・E_ExternalExit・第四の外部条件・delta/IO/releaseへの自動追加は採らない。
8. Groundは型・行・範囲・値の自由変数を有限構文で検査する。varだけの不存在や、任意の置換に対する意味上の不変性へ置き換えない。

### 群末の検査と証拠

[再実行用台本](02b-external-validate.py)、[検査全体](02b-external-validation.json)、[コマンド・終了・外側の時間](02b-external-commands.json)、[本番397入力のSHA-256](02b-external-inputs-final.json)、[補助入力のSHA-256](02b-external-artifact-inputs.json)を保存した。最終検査中の本番入力のハッシュは前後で一致した。Leanは4.34.1、既定・単独とも **-M 12288** であり、固定版・lake設定は変更していない。

| 検査 | 結果 | 証拠 |
|---|---|---|
| 旧体系・並置体系・全既定ターゲットのLeanビルド | **`cd formal && lake build`、終了0、640 jobs、2.287秒**。変更した本番は途中の関係するビルドでもコンパイルし、最終入口は既存の成果物も再利用する。全640ファイルを新たに検査した時間とは呼ばない | [出力](02b-external-build.log) |
| 新しい外部と依存列の境界 | **終了0、0.957秒**。pure呼出しの型付け/無事象遷移/step、トラップの無事象エラー、名目IDの区別とbind後の保持、未知ID/重複key/不正arity/異なるcomponent、入れ子のborrow/ownと逆向きの拒否、開いた型注釈の非Ground、依存結果の逐次具体化とTelArgsの実導出、exitを返す表の三条件の拒否、不適格oracleの非遷移、有限のBox[Box[Integer]]、篩付きMap鍵を確認。補助入力の61宣言の公理依存も照合 | [入力](02b-external-boundary.lean) / [出力](02b-external-boundary.log) |
| 既存の参照・sort等の境界 | r4を変えず実行、**終了0、0.642秒**。None/cont・snapshot・self/外側・宣言照合等を保持 | [出力](02b-external-previous-boundary.log) |
| 既存kindの境界 | r5を変えず実行、**終了0、0.380秒**。21宣言の公理依存も照合 | [出力](02b-external-kind-boundary.log) |
| 前の値の群の境界 | 元の記録を変えず、今回の新構成子の不可能な場合を追加した写しを実行。**終了0、0.677秒**。Mapの重複と依存鍵・場所の削除拒否・捕捉環境等を保持し、30宣言の公理依存も照合 | [今回の入力](02b-external-values-boundary.lean) / [出力](02b-external-values-boundary.log) |
| 新規・変更宣言の公理依存（A-L） | **終了0、6.347秒、67モジュールと旧の指定7宣言、計8,019宣言**。private/生成宣言を含み、報告件数・一意な件数・モジュール別件数＋旧7宣言が一致。使用は **propext/Quot.sound/Classical.choiceだけ**。独自公理・sorryAxなし | [入力](02b-external-axioms.lean) / [集計](02b-external-axioms-summary.json) |
| 構成子数・抜け道・設定 | Lean metadataで39場合・Step71等を照合。本番Refinementにsorry/admit/axiom/native_decide/implemented_by/unsafe/partialの語の検出なし | [検査全体](02b-external-validation.json) |
| work・RSS・Rust・独立レビュー | workは依頼どおり取りまとめへ残した。RSSは未取得（計画上の非採取）。Rustテストの追加・変更・削除は0件。今回の自己点検を独立レビューとして数えない | [レビュー依頼](../reviews/RV-L00b.02b-external-request.md) |

A-Lの旧7宣言はModel/ModelTargets/ModelHttp.assumptions、Ty.le_iff_leOld/wf_iff_old/varsIn_iff_old、Eff.covers_iff_sub_oldである。外部の新しい三モデルの条件充足をこれらの旧モデルの照合で代用しない。公理依存の生の全出力は最終822,591バイトであるため一時領域へ置き、[large-records.md](large-records.md)に大きさとSHA-256だけを残した。途中の全出力も同じ表で区別した。差分61,194バイトは100 KB以下なので改造内に保存した。文書・台本に手元の絶対パスは記していない。

途中の局所検査では、新しい型/相互導出の参照、正規化とbindの表記、暗黙引数、全構成子を直接消去する既存の補助証明で失敗した。既定ビルドの最初の実行ではSubstTypingObstruction、続く局所検査ではNarrowingObstructionの新しい場合が不足していた。言明を弱めず不可能な場合を追加して修正した。前の群の境界入力も構成子追加で場所の逆転の網羅性が不足し、[初回コマンド記録](02b-external-first-commands.json)と[初回出力](02b-external-first-values-boundary.log)に残した。今回の写しに二つの不可能な場合を追加し、元のr2の入力・出力は変更していない。失敗時の回復用sorryAxを成功の証拠には使わず、最終の入力で全件を照合した。

### テストの作成時の関門

新しい補助入力の持ち主は、本番Leanの宣言表・型付け・逐次具体化・Step/stepである。独立した契約は、外部pureの無事象、外部応答のno-exit、IDの名目性、全入れ子のborrow/own、閉じた型注釈、依存列の具体化である。Event.external/exitの追加、表示名による同一視、未知IDやarityの検査漏れ、param下のup/cutoffの誤り、型注釈を無視したGround、有限の同名の入れ子や篩付き鍵の誤拒否があれば失敗する。前の群には外部の構成子とTelArgsの型付けがなく、この失敗は捕まえられなかった。検査用の本番API・フラグ・差し込み口は加えていない。前の群の境界の写しは今回の構成子でも既存の負の言明を維持できるかを照合するための記録であり、新しいRustのテストを重ねたものではない。

### 閉じた義務・残りと送り先

| 義務・残り | 今回の判定と証拠 | 残る担当・時期 |
|---|---|---|
| 第12.2節のexternalの5導出・三族39・TypedFacts・TelArgsのup/bindと逐次具体化・Rなしの各入口 | **この群の担当分を完了**。本節・本番ソース・境界・A-L。L10/L20へ同じ証明を後送していない | 後の群で構成子を増やすとき、その新しい場合だけを追加する |
| O002/O004/O006/O009/O029/O040/O042/O087/O088/O159等のexternalの骨格・依存列・移動/置換/埋め込み | 今回の範囲の定義・39場合・Step71・旧構文の空の外部表を閉じた。外部型を通常opaque/Unit/Topに消していない | 型付き状態と主定理の合成、旧全導出/遷移の埋め込みはL20/L60/L70。義務全体を今回閉鎖したとは数えない |
| O016のA-L | 現在の67モジュールと旧7宣言を8,019件照合した | L00b末と後続各L段のA-L、信頼条件の新旧対照は`.15`/L70 |
| O010/O160の所要の記録 | 通常の外側の時間を本節へ記録した | 能動時間の比の較正・全体見込みの更新は取りまとめ |
| 外部の三モデルのtyped/exists/no_targetsとexternal_adequate | 三欄とno-exitの言明・CoreAssumptionsへの供給・型付き入力の具体化を置いた。モデルの充足とadequateの一般補題は未完 | 第5節どおりL60/L70。第四の仮定にせず、型の構造から導く |
| σ/Atと保持値 | 今回は実装していない | **次の`.02b-at`**。新しい値/計算をGround・Capture・全構文操作・三族・TypedFacts・Declared正則性へ同時に追加する。現在のGroundは全注釈のWFを検査するため、単なるvarなしへ弱めない |
| ExternalWFのProgram.WellTypedとの接続、宣言と外側kindの供給 | 補助のWFとkindを今回接続済みの全宣言の適格性とは数えない | `.03`。第24節軽2のKを宣言のkind列へ固定する義務を維持 |
| 第24節のRV-values中1/中2・軽1〜5 | 全7行の担当と依存を変更していない。この表でexternalへ新たに割り当てられた行はない | kind表付き埋め込みはL20/L70、関数型の対応はclosures/`.11`/L20/L70、場所のDeclaredはclosures/L20、骨格のエフェクトはL50、旧lamのNamesWFはL20/L70 |
| handlers/closuresと保存・effect_soundness/step_sound | 外部遷移を既存Stepへ加えたが全状態の保存の証明は未主張 | 既定の各群・`.14`/L20/L60/L70。外部oracleの応答の条件をstep_soundへ渡し、σ/Ebの固定と無事象を保つ |
| 提供範囲・交換・CLIと受け入れ | 今回のLeanの境界を実CLIや全比較の成功とは呼ばない | 既定のR段/L70、独立レビュー・work・取り込み・受け入れは取りまとめ・設計者 |

### 計画との差と外側の時間

5導出・三族39場合・TypedFacts・3遷移・既定ビルドという起動表の範囲は変更していない。補助の具体化はsignatures第25節に集めた。Groundと外部の型の全入れ子のDeclaredを外部の入力条件に必要な範囲で同じ群に置き、後続のσ/Atの葉は追加していない。主な定理や提供範囲の変更、新しい公理、精密な外部状態、第四の外部仮定を追加していない。

最初の時計の取得は2026-10-31 **07:47:58 JST**（[開始記録](02b-external-start.json)）、最終検査終了は **08:06:46 JST** で、その間の外側の時間は **1,128.10秒（約18.80分）** だった。時計の取得より前にも共通依頼文等を読んでおり、その初動の時間は採取していない。文書・依頼の仕上げを含む受け渡し時点は `02b-external-delivery.json` に残す。能動時間と待ちを分離していないため、能動時間の実測・較正の比とは扱わない。見込み2〜3時間の上端の2倍（6時間）には達していない。


### レビューの所見の対応（RV-L00b.02b-external、2026-10-31）

[群末レビュー](../reviews/RV-L00b.02b-external.md)は**条件付き可（重なし、中1・軽4）**であった。plan「計画の変更と取りまとめへの確認点」の2026-10-31の先頭の判断に従い、以下を修正した。変更はsignatures.md、本小節、境界の補助入力と今回の検査記録だけである。本番のLean・処理系・現行設計書・plan.mdを変えず、gitの操作、work、次の群の実装は行っていない。

| 所見 | 直した箇所 | 対応・残る義務 |
|---|---|---|
| 中1 | signatures **第25節のレビュー後の扱い・第25.3節・第25.4節の決定の表、第24節の義務の対応表、第12.2節のexternalの行と後続`.04`/`.05`/L60の表**。第5節の署名にも暫定の注記 | 篩付きの型を外部境界で受け付け、受信後の全入れ子の篩の所属検査を必須にする案を固定した。external_typedの結論は全入れ子の篩を除いた型（carrier）までへ弱め、E_Externalで結果・Mapの鍵・dataの欄等の述語を閉じて評価し、違反はerrにする。信頼条件と遷移・stepの本番の改訂を`.04`・`.05`でそろえ、L60のModel/ModelTargets/ModelHttpで三条件の充足と検査後の所属・違反時のerrを示す。R50・L70で表層・交換を照合する。**現行の本番が篩までを信頼するのは、その改訂までの暫定である**。本番の改訂を今回済ませたとは数えない |
| 軽1 | signatures **第25.1節、第24節の対応表** | L70が示すのは「処理系が受理する外部署名ならExternalSignature.WFを満たす」という向きだけとした。dataのUnitや予算等で補助判断の上限が広いため、逆向きの受理は主張しない |
| 軽2 | signatures **第25.2節、第24節の対応表** | 現行ExternalCallAdmissible.typesは空のΓで検査し、SignatureInstanceは呼出し側のΓを使うことを明記した。現在は単相・ts=[]なので影響しない。多相の外部宣言を加える改造でTypeAnnotations P C Γ tsへ改め、SignatureInstanceと文脈をそろえ、外側の値依存を含む移送とmapを証明し直す義務を残した |
| 軽3 | signatures **第12.2節の`.02b-closures`の行、第24節の対応表** | C_DependentAppの実引数をHasTypeTelArgsQで検査してE_ExternalApplyの後のC_Externalへ渡す道筋を固定した。Tel.argumentsとVsを使う場合は、文脈の正則性から各引数のAnnotationを得てTelArgsを作る逆向きの補題を同じ群で閉じる。L20はこの接続と捕捉環境の具体化からE_ExternalApplyの保存を示す。今回のHasTypeTelArgsQ.argumentsの一方向だけで代用しない |
| 軽4 | **02b-external-boundary.leanのStatefulとRecursive**、signatures第24節の対応表 | `get(c: Cell) -> Integer uses State`のExternalSignature.WF（Stateful.get_wf）、ハンドルを渡すC_Externalの型付け（Stateful.get_call_typed）、自分自身を欄に持つ`Nil | Cons(L)`がすべてのcomponent/unitについてExternalValueTypeを持たないこと（Recursive.recursive_rejected）を追加し、Leanで検査した |

第24節の元のRV-valuesの7行は維持し、今回の5行を同じ義務の表へ追加した。上の実装時点の「残りと送り先」の表は当時の記録であり、外部の受信検査とE_ExternalApplyの接続の最新の割り当てはこの小節とsignatures第24節を正とする。受信後の所属検査は後続の未実施の義務であり、今回の文書の修正を検査の実装・三モデルの充足・再レビューによる受け入れとは扱わない。

境界の3例は既存の本番の宣言表・WF・型付けの導出を使う。非空usesの逆向きが構成できない、Stateの効果が正規形でなくなる、ハンドルのTelArgsからC_Externalへ接続できない、自己参照dataを有限な受渡し型として通す、という退行を捕まえる。以前のpureSigは引数なし・emptyであり、これらを確かめていなかった。本番の検査用API・フラグ・差し込み口は追加していない。

実行したコマンドはリポジトリの根から見て次の相対入力である。

```sh
cd formal
lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.02/02b-external-boundary.lean
```

**終了0、外側1.024秒、警告0件**であった。境界入力の87宣言の公理依存も照合し、使用はpropext・Quot.sound・Classical.choiceだけで、独自公理・sorryAxはなかった。[最終出力](02b-external-r2-boundary.log)と[入力・出力のSHA-256、コマンド・終了・時間・公理依存の記録](02b-external-r2-validation.json)を保存した。初回の局所検査は、名前空間の前のdocコメント、具体化後のdoneのAnnotationの明示、再帰型の拒否の帰納法の書き方で失敗した。コメントを通常のコメントにし、終端の型を明示し、有限な導出の帰納仮定を直接使って修正した後、上の最終入力で成功を確かめた。

前回の境界61宣言の記録は実装時点の入力に対する結果であり、今回の追加後の境界はr2の87宣言の記録を正とする。本番は変更していないので、前回の本番397入力・640 jobsのビルド・8,019宣言のA-Lを再実行していない。変更禁止範囲と本番入力のハッシュ、相対リンク、今回の入力・出力の一致は [r2の範囲の照合](02b-external-r2-scope-check.json) に記録する。

最初の時計の取得08:25:16 JSTから、この文書と入力の照合までの外側の時間は約5.10分であった。能動時間と待ちを分離した値ではない。今回の30分以内の目安を超えていない。再レビューと受け入れは未実施である。

## .02b-external の作業末の work（取りまとめ、2026-10-31）

- 基準: `9184a3ced427d4897fcb234d2ac277f95b60ac0f`。作業ツリーは群の実装を終えた状態。その後の RV-L00b.02b-external の所見の対応は文書と境界の補助入力だけで、本番の Lean は変えていない。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 9184a3ced427d4897fcb234d2ac277f95b60ac0f`（sandbox の外）。選ばれた単位は `formal_build`（`cd formal && lake build` と `sorry` を使う宣言の拒否）だけである。先に `formal/.lake/build` の `Benitoite/Release/Refinement` の生成物（lib と ir）を消した。
- 結果: 終了0（selected checks passed）。外側の時間は38.66秒、最大常駐量は983,564,288バイト（約0.92 GiB）。
- 計画からのずれ: なし。


## `.02b-at`：σ/Atと保持値の群末（2026-10-31）

以下の初回記録の後に、同節末の「レビューの所見の対応」を追記した。**RV-L00b.02b-at後のD28の改訂・本番・最新の検査は、その小節を正とする。**

**この起動単位の実装と群末の検査を終えた。** 腕・節・ハンドラの型付けには進んでいない。独立レビュー・work・取り込み・受け入れは取りまとめ・設計者の担当であり、今回の完了には含めない。B_WORKは `1874fe91aa3684662dca4c69b284ea9614b9fb56`、指定ブランチは `m014/l00b.02b-at` である。前の取り込み08f9ac72・f42ab9aa・5ed7029bとブランチは起動依頼の指定値を使い、gitの照合・操作・コミットを行っていない。処理系・現行設計書・plan.md・旧Release本体を変更していない。

### 置いた構成子と閉じた定義・補題

| 群 | 本番に残したもの |
|---|---|
| 有限な起点と解決 | PathEnv.Valid/lookup/Binds、PathPattern.atBase、RangeExpr.resolve/Mem、TargetInput.resolve、SnapshotMem。必須のroot/cwd/homeと任意のwork/tmp/secretsを区別する。明示した空のsecretsは束縛済みである |
| 初期準備 | PreparationNode.Child/Reachable、帰納的PathEnv.Required、Ready、InitialPrepared/ready。型・行・篩のmember・既知の名目型の全構成子の欄・到達した宣言・組込み署名を辿る。動的ScopePatternの内容を静的な必須起点へ加えない。全宣言の列挙を仮定しない |
| 値と計算 | Val.pathBases/scopePattern/checkedAt/atError、Comp.issuePathBases/checkAt。既存のchecked/checkedRequestも型付けへ接続した。Ground・改名・値置換・型置換・Capture/Closure.view・Sourceに新しい場合を加えた |
| 型付け | V_PathBases/ScopePattern/Checked/CheckedRequest/CheckedAt/AtError、C_IssuePathBases/CheckAt、CheckedWitness.plain/request、相互のAtCallAdmissible.mk。Requestの空C/Γ/Φの型付け、Ground、reqTargetの一致を保つ |
| Resultとエラー | ResultShape、StandardError/DeclaredとerrorType_eq/errorType_declared/error_data/error_observation_declared。Resultのarity2と両構成子の欄位置、閉じた標準Scope.ScopeErrorの宣言を検査する。AtError.textFields/valuesとvalues_typedで、全七欄の文字列表現・snapshot・構成子パターンの束縛をそろえた。利用者向けShowの切詰めは行わない |
| Atの準備と検査 | parseAtInput/parseAtPattern、parseUrlTarget、Val.reqTarget/target?、groundTy/groundValとWF/Groundの補題、AtRequest/AtPrepare/AtPrepared。AtPrepared.fixed_index、AtPrepare.fixed_index/no_staticIndex、AtCallAdmissible.fixed_index/no_staticIndex、checkAt.soundを閉じた。未束縛・動的条件・静的添字・形式不良をErrorにする |
| 保持値の適格性 | Val/Comp/Capture/Closure/Frame/Cont/Cell/Store/Outcome.Adequate、SnapshotAdequate、AdequateResult。場所からストアへ無限に再帰せず、有限の保持箇所のsnapshotを同じσと照合する。SnapshotMem.kind/current、CheckedWitness.kind/membershipを閉じた |
| 旧の絶対形との対応 | CheckedWitness.absolute_plain/absolute_request、HasTypeVQ.checked_opaque/checkedRequest_opaque、checkedAt_subst。旧のopaqueへの互換はscoped_forgetから導き、裸の標準opaqueや要求のないRequestInを認めない |
| 組込み応答の条件 | BuiltinArgs、Builtins.ResponseAssumptions、CoreAssumptionsへの包含とresponses。delta_typed/io_typedの結果に、同じoutに対する全有効σのAdequateResultを置いた。io_kind/io_existsとTargetAgreement.io_targetも型付き入力の同じ束を使う。外部の第四の条件は加えていない |
| 意味論と実行器 | 新PrimKind.pathBasesと旧8形のembedPrimKind、Event.pathBases、E_PathBasesApply/IssuePathBases/AtOk/AtError/AtPrepareError。旧68遷移と外部3遷移を維持した。E_OpPrimとstepの通常のhandler経路にpathBasesを加え、発行だけがProcess.Environmentの事象を出す |
| 既存の補題 | shift_values、値の相互subst、narrowing、TypedFactsの全入口、hide/None版、Declaredの正則性。CheckedWitness.shift_storeはrequestのHasTypeVを同じ相互証明で移す。値置換・narrowingでは空文脈と同じストアの保持要求の証拠を再利用する。snapshotとmemberの値置換・WFも既存の全構文操作とAtTypingの系で照合した |

追加した手書きの公開名は **107名** であり、[公開宣言の一覧](02b-at-public-api.md)に全名を置いた。生成された射影・recursor・等式定理・Repr等をこの数へ重ねていない。新規Leanは **10ファイル**、既存は **22ファイル**、合計 **32ファイル** である。全て既定importに含む。全ファイルとハッシュ・前後の行数は [変更の一覧](02b-at-source-changes.json)、本番407入力は [最終入力](02b-at-inputs-final.json)で照合する。変更対象の行数は **5385→6746、純増1361行** である。

新規10ファイルはAdequate、AtContracts、AtInput、AtPrepare、AtSound、AtTyping、BuiltinResponse、PathResolution、Preparation、Sourceである。既存22ファイルと、新規の改造内の入力・記録の全一覧は[レビュー依頼](../reviews/RV-L00b.02b-at-request.md)にある。

### 場合の数の予定と実際

| 対象 | 第12.2節の予定 | 本番・実際のmatchと再利用 |
|---|---|---|
| 値・計算・事象・遷移 | Val25/Comp16/Event3/Step76 | **25/16/3/76**。旧68の名前・順序を保持し、外部3と今回5を加えた。[照合](02b-at-step-coverage.json) |
| 型付けと保持の証拠 | V26/C15/Vs2/Each2/TelArgs2/Witness2、計49 | **49構成子を置いた**。AtCallAdmissibleの補助1は別記する |
| 移動 | この群の10場合を含む49 | HasTypeVQ.shift_values、Vs/Each/CQ/TelArgsの同名入口とCheckedWitness.shift_storeの相互matchで49。AtCallAdmissible.shift_valuesの補助1を加えると**50** |
| 値の相互置換 | 同じ49を保つ | subst_value/values/each/comp/telArgsの根は**47**、subst_at_callの補助1で**48**。Witnessの空文脈・同じストア・保持要求は変わらないため、その証拠を再利用し、別の2matchと数えない。HasTypeVQ.checkedAt_substを実際の構文の系にした |
| narrowing | 同じ49を保つ | context_value/values/each/comp/telArgsの根は**47**、context_at_callの補助1で**48**。Witnessの二つの証拠を同じ理由で再利用する。narrowの公開入口はこの相互証明から導く |
| TypedFactsの主な入口 | observation/assume各26、追加6×2 | **各26、計52**。すべての新しい値を処理した |
| TypedFactsの補助 | 全入口を追随 | data_observation/assume_optional各26、observation_declared/observation_referencesはVs/Each各2も含め各30。補助は**112**、主な入口と合わせて**164** |
| 正則性とhide | 新しい葉・計算と保持要求を追随 | HasTypeVQ.declaredは26、CQ.declaredは15。hide/None版は更新した三族を使う。Each.nilから要素型のDeclaredを導く偽の一般化は加えていない |
| TargetInput | 予約はabsolute/relativePathの2形 | **3形**。既に決定済みの~と~/をhomeとして保つ内部homePathを追加した。新しい変数展開や利用者の書ける形の追加ではない |

49は判断の構成子数であり、三族に別々の147個のmatchを追加したという実績へ読み替えない。移動50・置換48・narrowing48はAtCallの補助を含めた実際の根の数である。上の再利用を採ったことはsignatures第26節に記録した。新しい三モデル・全状態の保存・閉じた評価・L70の旧導出の埋め込みを、この件数へ混ぜていない。

### 補助契約で決めたこと

[signatures第26節](signatures.md)に採用案・理由・捨てた案を置いた。主なものは次である。

1. Required/Ready/InitialPreparedへBを加え、組込み署名の固定起点と既知の名目型の全欄も辿る。動的ScopePatternの内容をReadyへ混ぜない。
2. BuiltinArgsへbを加え、同じ署名を持つ別名のadmitsRを取り違えない。
3. AtCallAdmissibleを型付けと同じ相互帰納へ置き、someのtokenの型付けと入力型・indexの構文の適格性を検査する。valContentの宣言型はWF 0 0 0とする。
4. 保持要求は空文脈で型付けし、改名・各置換・捕捉でそのまま保つ。ストアの移送だけは相互のshift_valuesで追随する。
5. Adequateは全有限保持箇所を調べ、someのsnapshotを同じσ、noneをabsoluteに限る。Readyは保存の前提へ加えない。
6. 標準Result/Scope.ScopeErrorの宣言・arity・欄を照合する。String型の七欄は実際の値と同じsnapshotにし、AtError.values_typedとmatchValにも接続する。最初のnone七欄の下書きは撤回した。
7. checkAtは未解決のpattern/boundの字句WFを検査し、起点に含むリテラルの*をパターンのワイルドカードとして拒まない。
8. TargetInput.homePathで既定の~を保ち、cwd相対形から区別する。途中のdot・空要素・余分な末尾/・..・~userは拒否する。
9. 準備のstaticIndexをrvarだけに限定し、privateなPreparationErrorの証明からno_staticIndexを導く。成功時のindex=.fixed boundも証明する。
10. PathBasesは通常のhandler経路を通し、専用のσの発行からだけ事象を出す。δ/IOが任意の別実行のtokenを選ぶ経路は加えない。

これらは起動依頼で委ねられた補助の具体化として採った。主な定理の前提・結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態の変更はないという担当の判断を、群末レビューでも確認してもらう。

### 群末の検査と証拠

[再実行用台本](02b-at-validate.py)、[検査全体](02b-at-validation.json)、[コマンド・終了・外側の時間](02b-at-commands.json)、[補助入力のハッシュ](02b-at-artifact-inputs.json)を保存した。本番の最終407入力は検査の前後で一致した。Lean4.34.1、既定と単独の双方で **-M 12288** を使い、固定版とlake設定を変更していない。

| 検査 | 最終結果 | 証拠 |
|---|---|---|
| 旧・並置体系と全既定ターゲットのビルド | `cd formal && lake build`、**終了0、650 jobs、1.105秒**。変更箇所は途中の局所ビルドでも検査した。最終入口は成果物を再利用し、650ファイル全てを新たに検査した時間とはしない | [出力](02b-at-build.log) |
| 今回の境界 | **終了0、1.956秒、73宣言の公理依存も照合**。別σのtoken、型付きRequestのGround/端点/要求なしの拒否、openな保持要求、secrets未指定/空、動的条件/静的添字、At準備のindex、C_CheckAt、既知の未束縛起点、名目型の欄の到達、Stepとstep、標準エラーのString観測と構成子パターンを確認した。大きいURLとパスの字句例は実行による照合とし、真偽を証明へ注入していない | [入力](02b-at-boundary.lean) / [出力](02b-at-boundary.log) |
| 前の参照・sort・None/cont/snapshotの境界 | r4を変更せず実行、**終了0、0.644秒** | [出力](02b-at-previous-boundary.log) |
| 前のkindの境界 | r5を変更せず実行、**終了0、0.381秒**、21宣言の公理依存を照合 | [出力](02b-at-kind-boundary.log) |
| 前の値の葉の境界 | 新しい不可能な場合を足した写しで、**終了0、0.858秒**。重複Map・依存鍵・場所の削除・捕捉環境を保ち、30宣言の公理依存を照合 | [写し](02b-at-values-boundary.lean) / [出力](02b-at-values-boundary.log) |
| 前の外部の境界 | レビュー修正後の入力を変更せず実行、**終了0、1.050秒**。Statefulの署名/ハンドル引数、再帰拒否も含め87宣言の公理依存を照合 | [出力](02b-at-external-boundary.log) |
| A-L | **終了0、7.279秒、77モジュールと旧の指定7宣言、計8,944宣言**。private/生成宣言を含め、報告数・一意な数・モジュール別件数+7が一致。使用は **propext/Quot.sound/Classical.choiceだけ**。独自公理・sorryAxはない | [入力](02b-at-axioms.lean) / [集計](02b-at-axioms-summary.json) |
| 構成子数・抜け道・範囲 | Lean metadataで49構成子、Val25/Comp16/Event3/Step76等を照合。本番のsorry/admit/axiom/native_decide/implemented_by/unsafe/partialの語の検出0件 | [検査全体](02b-at-validation.json) / [範囲の照合](02b-at-scope-check.json) |
| work/RSS/Rust/全比較/独立レビュー | workは依頼どおり取りまとめへ残した。RSSは未取得（計画上の非採取）。Rustのテストの変更0件。今回の自己点検を独立レビューや全比較の成功と数えない | [レビュー依頼](../reviews/RV-L00b.02b-at-request.md) |

旧の指定7宣言はModel/ModelTargets/ModelHttp.assumptions、Ty.le_iff_leOld/wf_iff_old/varsIn_iff_old、Eff.covers_iff_sub_oldである。旧モデルの照合を、新しいσ/At・外部の三モデルの充足の代用にはしない。最終の公理依存の全出力は **918,089バイト**、差分の全出力は **101,245バイト** なので一時領域へ置き、[large-records](large-records.md)に大きさとSHA-256を残した。改造に100 KBを超える生の記録を置いていない。

途中は構造的再帰の判定、Optionalなtokenの依存消去、型付きエラーの正則性、既存の障害例の不足、境界の暗黙引数とStringの閉じた評価で失敗した。処理系の言明や期待する契約を弱めずに修正した。[初回のビルド](02b-at-first-build.log)、[初回の境界](02b-at-first-boundary.log)、[途中の検査の扱い](02b-at-development-checks.json)を保存した。初回入力の当時の写し・時間は未採取であり、これらを再実行可能な最終入力の証拠とはしない。失敗時のLeanの回復用sorryAxを、成功の証拠には用いていない。Stringの長い字句のcbvによる証明作成は中断し、実行による字句の照合と、型付きRequestの形に関する証明を分けた。

### テストの作成時の関門

持ち主は本番Leanの保持値の型付け、Adequate、At準備、Step/step、RuntimeMatchである。守る独立した契約は同じσの保持、RequestのGround/端点一致、準備の具体化済みindex、静的な既知契約の必須起点、純粋なAtとProcess.Environmentの発行の区別、標準エラーの観測である。snapshotの等式やRequestの条件の脱落、rvarの残留、空secretsの未束縛扱い、動的条件/静的添字の混同、名目型の欄の起点の見落とし、エラーのString欄のnone化があれば失敗する。前群にはこれらの値・計算・保持の証拠がないため、同じ境界では捕まえられなかった。検査用の本番API・フラグ・差し込み口は加えていない。前の群の写しは既存の負の契約を維持するためであり、元の記録は変更していない。

### 義務の判定・残りと送り先

| 義務 | 今回の判定・証拠 | 残る担当・時期 |
|---|---|---|
| 第12.2節のatの行、構成子と三族・TypedFacts・保持要求・WF/Declared | **この群の担当分を完了**。上の本番、境界、A-L。Witnessの再利用と補助の数は明記した | 後続の群は新しく増やす場合だけを追加し、今回の一般の移送をL10/L20で重ねない |
| O002/O004/O006/O009/O029/O040/O042/O085/O159の骨格・移送・並置 | σ/Atの有限構文・49判断・Ground/Source・既定importと、型/行/値参照を保つ追随を置いた | 義務全体の閉鎖ではない。全状態の保存・旧の全導出と遷移の埋め込みはL20/L70、共有層は`.02c` |
| O016のA-L | 現時点の77モジュール+旧7宣言、8,944宣言を照合した | L00b末と後続各L段、信頼条件の新旧対照は`.15`/L70 |
| O010/O160の所要 | 通常の外側の時間を下に記録した | 能動時間の比・改造全体の見込み更新は取りまとめ |
| O061/O062/O063/O082/O092/O096/O097/O165/O166/O168 | 固定σ・At・保持値・準備・全σのAdequateResult・絶対の互換入口と失敗情報の骨格を置いた。checkAt.soundと保持対象の所属の橋も閉じた | 全有効σでのCoversの健全性、IO対象と標準契約・三モデルの充足、文字列解析/reqTarget/標準エラーの公開構成子とShowの対応はL50。表層・交換・CLIは既定のR段/L70/V10 |
| 第24節のRV-values全7行 | 担当を変更していない。今回の構成子でも前群の境界を保った | kind表付きD29はL20/L70、fn/Telの対応はclosures/`.11`、外側kindは`.03`、場所のDeclaredはclosures/L20、三モデルの骨格はL50、旧lamのNamesWFはL20/L70 |
| 第24節のRV-external全5行 | 範囲を変更していない。Stateful/Recursiveの正負の例も再実行した | 受信後の篩は`.04`/`.05`/L60、受理からWFへの向きはL70、多相externalは別改造、TelArgsへつなぐC_DependentAppはclosures/L20 |
| 腕・節・ハンドラ | **次の`.02b-handlers`へ渡す**。今回C_Match/Handle/Resume等は追加していない | ImageOk3、R0の結び付け、SubstOk.hide/up/None/多相節の全束縛、Arms3/Clauses2/Failure1、PatTy等と全新構成子の正準形を同群で閉じる。AtErrorの構成子パターンには今回置いたvalues/values_typedを使う |
| 閉包/状態と主定理 | Adequateを置いたことをStateTyの全接続・保存と数えない。CoreAssumptionsもこの群の応答の改訂分であり、後続の宣言/ストア等の全欄の完了とはしていない | closures/`.03`/`.14`/L20/L50/L60/L70で固定σ/Eb、全状態、step_sound/effect_soundnessとモデルへ接続する |
| 受け入れ | 自己点検と検査まで | 群末の独立レビュー・work・取り込み・受け入れは取りまとめ・設計者 |

### 計画との差と外側の時間

Val25/Comp16/Event3/Step76と保持値の49判断は起動表どおりである。補助のRequiredへのB、BuiltinArgsへのb、TargetInputのhomePath、AtCallの相互判断、閉じたvalContent、Witnessの再利用、エラーの七欄の観測を第26節で具体化した。RuntimeMatchの変更は追加したatErrorの一場合だけであり、次の腕・節・ハンドラの型付けを先取りしていない。主な定理の変更・新公理・提供範囲の変更・外部の第四の条件・精密な外部状態を加えていない。

最初の時計の取得は2026-10-31 **08:31:53 JST**、最終検査終了は **09:16:01 JST** で、外側は **2,648.00秒（約44.13分）** であった。[開始](02b-at-start.json)、[検査全体](02b-at-validation.json)、[受け渡し](02b-at-delivery.json)に時計を残す。文書の仕上げを含む受け渡しまでの時間はdeliveryを正とする。能動時間と待ちを分離していないため、能動時間の実測や較正の比にはしない。見込み2〜4時間の上端の2倍（8時間）には達していない。


### レビューの所見の対応（RV-L00b.02b-at、2026-10-31）

[独立レビュー](../reviews/RV-L00b.02b-at.md)は条件付き可（重なし、中2・軽4）であった。plan「計画の変更と取りまとめへの確認点」の2026-10-31の先頭の判断に従い、下表の対応を本番と義務の対応表へ反映した。修正後の独立レビュー・work・取り込み・受け入れは行っていない。

| 所見 | 対応と確認 | 残る義務 |
|---|---|---|
| 中1 / PathBasesの署名の形と旧四欄 | CoreAssumptionsにpathBases_shapeを加え、型パラメータ・行・範囲・実引数が空、結果が.pathBases、効果がProcess.Environmentの一原子、opEffが同じ名前である形を供給する。opEff_io/effect_opsのkindの分類へpathBasesを加え、store_shape/store_admitsから除いた。pathBasesを含む同じ組込み表BEでCoreAssumptions全体が成立する境界のcore_with_pathBasesを証明した | **D28の意味の変更**としてsignatures第27節に記録した。取りまとめ・.15で設計者への報告と07-04の新旧対照、L50で三モデルの充足を行う |
| 中1 / E_PathBasesApplyの局所の場合 | issuePathBases_typed、pathBases_empty_arguments、pathBases_empty_values、pathBases_apply_destinationを本番で閉じた。lookupとkindから到達先のC_IssuePathBases、型付きの具体化と実引数の空性を供給する。境界で実際の遷移と到達先の計算の型付けを照合した | 状態全体の保存・進行はL20・L70、節との接続は.02b-handlers |
| 中1 / 事象と効果 | SemanticsにEvent.Coveredを置き、σ発行はProcess.EnvironmentのTopの被覆を要求する。covered_pathBasesを証明し、境界でその効果による被覆と空効果での拒否を示した。IOの範囲は存在量化するため、これをIO対象の許可の健全性の証明とは数えない | effect_soundnessの**結論の形は変更しない**。事象と継続末尾の効果の接続・空効果の無事象の証明はL20・L70に残し、第24節へ明記した |
| 中2 / handlerのある発行がstuck | E_IssuePathBasesのNoHandler前提とstepのissue枝のsplitHandler検査を削除した。appでのhandler選択は維持する。旧handled_stuckに当たるhandler付きの内部issueで、handlerがあること、Stepの発行、実行器の発行の三つを証明した | 次の群は改訂後の発行を使う。Sourceからissueを直接作る経路を追加したとは扱わない |
| 軽1 / 文言・公開API・網羅性 | 第24節へ、textFieldsを処理系の文言の契約から定める表示関数に差し替える義務を追加した。現在のreprStrの七欄を公開APIの確定や処理系との対応済みと扱わない | L50・L70でU02の公開構成子にStandardError・RuntimeMatch・TypedFactsをそろえる。.02b-handlersで内部と公開の構成子一覧を一致させて網羅性を検査する |
| 軽2 / 常に真のClosed | 推す案としてAtError.Closedの定義とV_AtErrorの前提を削除した。AtErrorは値・型の変数の構文を含まず、データ型が閉性を保証するためである。三族、TypedFacts、Declaredと二つの障害例のmatchも追随し、境界でClosedなしの型付けを示した | 今回の局所修正を完了。常に真の前提を残す案や、WF/所属の条件を「閉性」に混ぜる案は採らない |
| 軽3 / Sourceと.loc | Val.Sourceの.locをFalseへ変更した。単独の場所とList内の場所をSourceが拒否する境界を示した。表層から作る構文の区別だけを直し、場所の型付けを削除していない | 今回の局所修正を完了。SourceをStoreOkの代用にはしない |
| 軽4 / 旧絶対形のD20の前提 | 第24節のD29の義務へ、旧V_CheckedはvalContent=none、旧V_CheckedRequestはGroundとreqTargetの端点一致を前提にして埋め込むことを追加した | L20・L70でD29へ明示し、D20/O044と07-04・現行01-12の対照を行う |

今回のD28の追加は、初回実装時の補助契約の具体化の判断を訂正するものである。取りまとめが承認した主な定理の前提の改訂として扱い、「主な定理の前提を変えていない」とは報告しない。主な定理の結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態への変更はない。レビューの指摘を超える判断を理由に停止する箇所はなかった。

本番の新規ファイルは0件、変更は既存のRefinement内の13ファイルである。[今回の差分](02b-at-r2-production.patch)と[変更の一覧](02b-at-r2-source-changes.json)は、レビュー後の修正に入る直前の写しを基準にする。群全体のB_WORKからの差分と混同しない。Val25/Comp16/Event3/Step76、型付けと保持の証拠49構成子は変わらない。今回はV_AtErrorとE_IssuePathBasesの前提を減らしたので、対応する各matchの引数だけを追随した。

[signatures第24節・第27節](signatures.md)に送り先、採った案・理由・捨てた案を置いた。新しく加えた主要な宣言はPrimSig.PathBasesShape、PrimSig.StoreShape、CoreAssumptionsの五欄、上記四補題、Event.Covered/covered_pathBasesである。削除した公開名はAtError.Closedである。初回の107名の公開宣言一覧は初回時点の記録であり、削除後の現行一覧と読み替えない。

検査の作成時の関門: 守る独立した契約は、PathBasesを含む表で信頼条件が両立すること、型付き発行への署名の供給、handler付きの内部issueの進行、σ発行とProcess.Environmentの対応、実行時の場所をSourceが受け付けないことである。旧の四欄の分類や発行時のhandler検査が残れば境界が失敗する。core_with_pathBasesはPathBasesのkindを持つ実際の表を構成するため、存在しないCoreAssumptionsを前提にした局所補題だけを検査する形ではない。検査のためだけの本番APIは加えていない。

再検査の結果は次のとおりである。Lean4.34.1、単独のLeanと既定ビルドのLeanの双方に-M 12288を適用した。固定版とlake設定を変更していない。

| 検査 | 修正後の結果 | 証拠 |
|---|---|---|
| 既定のcd formal && lake build | 終了0、0.155秒、650 jobs。変更箇所は途中の局所ビルドで再検査済みであり、最終入口は既存成果物を再利用した | [出力](02b-at-r2-build.log) |
| 今回の境界 | 終了0、2.055秒、94宣言の公理依存も照合 | [出力](02b-at-r2-boundary.log) |
| 前の参照・sort等の境界 | 終了0、0.636秒 | [出力](02b-at-r2-previous-boundary.log) |
| 前のkindの境界 | 終了0、0.386秒 | [出力](02b-at-r2-kind-boundary.log) |
| 前の保持値の境界 | 終了0、0.849秒、V_AtErrorの前提削除に対応するmatchだけを直した写し。30宣言の公理依存も照合 | [出力](02b-at-r2-values-boundary.log) |
| 前の外部の境界 | 終了0、1.032秒 | [出力](02b-at-r2-external-boundary.log) |
| A-L（新規・変更宣言と依存先を含む） | 終了0、7.267秒、77モジュールと旧の指定7宣言、計8,979宣言。件数・一意な数・モジュール別件数+7が一致 | [集計](02b-at-r2-axioms-summary.json) |
| 固定版 | 終了0、0.077秒 | [出力](02b-at-r2-lean-version.log) |

依存した公理は **propext・Quot.sound・Classical.choiceのみ** である。sorryAx・新公理・許可外の公理はない。本番のsorry/admit/axiom/native_decide/implemented_by/unsafe/partialの語の検出は0件。最終の407入力は検査前後で一致した。[全体の判定](02b-at-r2-validation.json)、[コマンドと時刻](02b-at-r2-commands.json)、[最終入力](02b-at-r2-inputs-final.json)、[台本と補助入力のハッシュ](02b-at-r2-artifact-inputs.json)、[再実行用台本](02b-at-r2-validate.py)を残した。初回の02b-at-*の検査記録は書き換えていない。

公理依存の全出力は921,882バイトで、一時領域へ置いた。大きさとSHA-256は[large-records](large-records.md)に追記した。今回の差分は100 KB以下なので改造内に置いた。改造内の新規の生記録で100 KBを超えるものはない。

途中の局所検査では、旧のEff.singleAtと新しいEffの型の取り違え、Listの補題名、V_AtErrorの障害例のmatch、境界の被覆の暗黙引数、実行器側のhandler検査の残存を検出して修正した。依存先の再ビルド中に境界を起動した回は、生成物がまだなく失敗した。これらの途中の失敗を成功の証拠に数えず、上表は全修正後に台本で改めて実行した結果である。元の値の境界は前提が減った後のmatchと合わなかったため、元の記録を保ち、r2の写しを再実行した。

新規の改造内ファイルは次のとおりであり、本番の新規ファイルはない。

- [02b-at-r2-artifact-inputs.json](02b-at-r2-artifact-inputs.json)
- [02b-at-r2-axioms-summary.json](02b-at-r2-axioms-summary.json)
- [02b-at-r2-axioms.lean](02b-at-r2-axioms.lean)
- [02b-at-r2-boundary.lean](02b-at-r2-boundary.lean)
- [02b-at-r2-boundary.log](02b-at-r2-boundary.log)
- [02b-at-r2-build.log](02b-at-r2-build.log)
- [02b-at-r2-commands.json](02b-at-r2-commands.json)
- [02b-at-r2-delivery.json](02b-at-r2-delivery.json)
- [02b-at-r2-external-boundary.log](02b-at-r2-external-boundary.log)
- [02b-at-r2-inputs-final.json](02b-at-r2-inputs-final.json)
- [02b-at-r2-kind-boundary.log](02b-at-r2-kind-boundary.log)
- [02b-at-r2-lean-version.log](02b-at-r2-lean-version.log)
- [02b-at-r2-previous-boundary.log](02b-at-r2-previous-boundary.log)
- [02b-at-r2-production.patch](02b-at-r2-production.patch)
- [02b-at-r2-scope-check.json](02b-at-r2-scope-check.json)
- [02b-at-r2-source-changes.json](02b-at-r2-source-changes.json)
- [02b-at-r2-step-coverage.json](02b-at-r2-step-coverage.json)
- [02b-at-r2-validate.py](02b-at-r2-validate.py)
- [02b-at-r2-validation.json](02b-at-r2-validation.json)
- [02b-at-r2-values-boundary.lean](02b-at-r2-values-boundary.lean)
- [02b-at-r2-values-boundary.log](02b-at-r2-values-boundary.log)

開始の時計は2026-10-31 **09:39:56 JST**、最終検査終了は **09:46:45 JST**、外側は **409.39秒（約6.82分）** である。文書と提出時の照合までの時間は[受け渡し](02b-at-r2-delivery.json)を正とし、能動時間と待ちは分離していない。目安の1時間以内に収まった。gitの操作、Rustの処理系・現行設計書・plan.mdの変更、work、次の群の実装は行っていない。

| 残る手順 | 担当・内容 | 見込み時間 |
|---|---|---|
| 修正後の確認・独立レビュー | 取りまとめ・レビュー担当。D28の五欄と局所補題、handler付き発行、軽の送り先を確認する | 不明 |
| 作業末のwork | 取りまとめ。共通入口で選ばれる形式化のビルドと禁止宣言の拒否を行う。今回の担当は実行していない | 不明 |
| 受け入れと取り込み | 取りまとめ・設計者。D28の意味の変更の報告と残る義務を確認する | 不明 |

## .02b-at の作業末の work（取りまとめ、2026-10-31）

- 基準: `1874fe91aa3684662dca4c69b284ea9614b9fb56`。作業ツリーは RV-L00b.02b-at の所見の対応（本番の Lean の修正を含む）を終えた状態。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 1874fe91aa3684662dca4c69b284ea9614b9fb56`（sandbox の外）。選ばれた単位は `formal_build`（`cd formal && lake build` と `sorry` を使う宣言の拒否）だけである。先に `formal/.lake/build` の `Benitoite/Release/Refinement` の生成物（lib と ir）を消した。
- 結果: 終了0（selected checks passed）。外側の時間は44.41秒、最大常駐量は1,070,383,104バイト（約1.00 GiB）。
- 計画からのずれ: なし。

## `.02b-handlers`：多相節の信頼条件での停止（2026-10-31）

この節は停止時点の記録である。取りまとめの承認後に再開し、下記「再開後の完成」の節のとおり本番の実装と群末の検査を終えた。

**この群は未完了である。** 指定された第12.2節の14導出を実装する前に、SubstOk.shiftEの通常値の像を移すためのsat/admitsの条件の不足を、本番の型付け判断で再現した。主な定理が読む信頼条件に関わるため、起動依頼の停止条件とsignaturesのS1に従い止めた。時間超過ではない。B_WORKは `5a602b7a2adc40e487f60c8ffc738d2f4595289c`、ブランチは `m014/l00b.02b-handlers` という起動依頼の指定値を使用した。gitの照合・操作・切替・コミットは行っていない。

### 残した定義・補題と本番の状態

本番Leanと既定importを変更していない。14導出、PatTy等、三族・TypedFacts・Declared・Ground・Captureの追加は0件であり、前群のV26/C15/Vs2/Each2/TelArgs2/CheckedWitness2の49構成子を維持した。AtCallAdmissibleの補助1構成子もそのままである。処理系・設計書・plan・旧Releaseは変更していない。

[補助Lean](02b-handlers-contract-boundary.lean)に次を証明した。名前の接頭辞は `Benitoite.Release.Refinement.HandlerContractBoundary.` である。これらは停止点の証拠であり、新しい本番の公開APIではない。

| 補助入力の群 | 閉じた定義・補題 |
|---|---|
| 閉じた型の例 | P/B、value_conditions/core_conditions、integer_annotation/source_typed、source_context_wf/target_context_wf、source_subst_ok、shape_unchanged、target_untypable/no_shifted_typed_image/no_shifted_subst_ok。現在のCoreAssumptionsを満たしても、型パラメータの先頭追加で通常値の像の型付けを失う |
| 開いた型の例 | Open.B/element/value/sourceCtx/shiftedCtx/ν、Open.core_rename/zero_values/zero_rename/value_conditions/core_conditions/sat_local/element_annotation/source_typed、Open.setCore/setCore_le/set_constraint、Open.shifted_element_rejected/target_untypable/source_subst_ok/no_shifted_subst_ok。sat_local相当を満たしてもSet[α₀]→Set[α₁]の移送を導けない |
| 検査 | Leanの環境から補助入力の全52宣言を列挙し、公理依存を照合した。定義・手書きの補題・生成された等式定理の数を分けず、この52は機械が列挙した全宣言数として記録する |

### 場合の数の予定と実際

| 対象 | この群の予定 | 今回の実際 |
|---|---|---|
| 計算・腕・節・像 | Cの5、Arms3、Clauses2、Failure1、ImageOk3の計14導出を追加 | **0/14**。現行49導出を維持 |
| 三族 | 追加14場合、累計63判断を被覆 | 未着手。移動の根は前群の49とAtCall補助1、置換/narrowingの根は各47とAtCall補助1のまま |
| PatTy/PatTys/AltsTy・Inhabits/Exhaustive | 腕が読む全形と移動・置換 | 追加0件 |
| TypedFacts | V26のまま維持 | 追加0件。前群の全入口を変更していない |
| R0・None・継続の改名・多相束縛・guardの全Φ | 同じ群で閉じる | 実装・境界の照合とも未着手。今回の二反例をこれらの完了証拠へ加算しない |

### 補助契約と停止点の判断

[signatures第28節](signatures.md)と[停止点の契約](02b-handlers-contract.md)に、採った検証方法・理由・採らなかった扱いを記録した。通常値の像を閉じた型へ限定せず、R0・None・guard・多相節の契約を保つ。Ctx.WFの未定義の予約名を小さい同名の代用で実装したとはしない。型付けの不成立はV_Sub/V_Refineも含めて証明した。

推す再開案は、型パラメータの先頭追加に対するsat/admits保存を信頼条件へ明記する**案A**である。これは値の改名・値置換の四保存則とは別であり、まだ採っていない。CoreAssumptionsの意味の変更に当たるため、取りまとめ・設計者へ判断を戻す。代案の具体的な構造への制約の変更、ClosedTyへの制限、移送先の型付けの外部前提化も停止点の契約に記した。

### ビルド・公理依存・入力

[台本](02b-handlers-validate.py)、[検査全体](02b-handlers-validation.json)、[コマンドと時刻](02b-handlers-commands.json)、[全407入力のハッシュ](02b-handlers-inputs-final.json)、[補助入力のハッシュ](02b-handlers-artifact-inputs.json)を保存した。本番入力は開始時・検査前・検査後で一致した。

| 検査 | 結果・範囲 | 証拠 |
|---|---|---|
| 旧・並置体系と全既定ターゲット | `cd formal && lake build`、**終了0、650 jobs、0.156秒**。既存成果物の再利用であり、全ファイルを新たに検査した時間とはしない。既存のlint警告は再表示された。以後は本番入力が変わっていないため、この一回を引用した | [出力](02b-handlers-build.log) |
| 停止点の補助入力 | `lake env lean -M 12288`、**終了0、1.359秒、52宣言**。現行CoreAssumptionsの充足と、二つの実際のSubstOkの正・負の証明。旧sat_localとの違いも含む | [入力](02b-handlers-contract-boundary.lean) / [出力](02b-handlers-contract-boundary.log) |
| A-L | `02b-at-r2-axioms.lean`を同一本番入力へ再実行、**終了0、7.958秒**。77モジュールと旧指定7宣言、計**8,979宣言**。一意な数とモジュール別件数+7が一致 | [集計](02b-handlers-axioms-summary.json) |
| 固定版・上限 | Lean **4.34.1**。既定lakefileのmoreLeanArgsと補助入力・A-Lは **-M 12288**。固定版・設定を変更していない | [版](02b-handlers-lean-version.log) / [入力一覧](02b-handlers-inputs-final.json) |
| 公理・抜け道 | 本番8,979宣言と補助入力52宣言とも、**propext・Quot.sound・Classical.choiceのみ**。sorryAx・独自公理・許可外依存はない。本番Refinementのsorry/admit/axiom/native_decide/implemented_by/unsafe/partialの語の検出は0件 | [検査全体](02b-handlers-validation.json) |
| work・RSS・全比較・レビュー | workは依頼に従い取りまとめへ残した。RSSは未取得（計画上の非採取）。Rust・全比較・独立レビュー・受け入れは未実施 | [停止点のレビュー依頼](../reviews/RV-L00b.02b-handlers-request.md) |

A-Lの全出力は **921,882バイト** なので `<tmp>` へ置き、[large-records](large-records.md)にSHA-256と大きさを記録した。本番差分は0件なので差分の写しは作っていない。大きい生の記録の絶対パスは文書と台本に書いていない。

途中の補助入力の型検査では、依存した添字を固定した帰納法の停止性、未定義のCtx.WFの予約名、rawBindとrawSubstVの交換の書換え、全宣言を列挙するLeanメタコードで失敗し、補助入力を直した。最後の成功には回復用sorryAxを含まない。途中の入力の写し・時計は未採取であり、途中の結果を最終入力の再現証拠として使わない。本番の規則・結論を弱める変更は行っていない。

### テストの作成時の関門

持ち主は本番の型付け・SubstOkと組込みの信頼条件であり、検査する独立した契約は「現行の信頼条件とWFな型付き像から、多相節の型パラメータの先頭追加が成立するか」である。値だけの四保存則又はsat_localを型の先頭追加に流用すると失敗する例を、実際の型付き導出とその否定で示した。既存の境界は型の先頭追加を扱わないため、この不足を捕まえない。テスト用の本番API・フラグ・差し込み口は加えていない。

### 残りと送り先、計画との差

| 義務 | 今回の判定 | 担当・時期 |
|---|---|---|
| 群末の14導出と全相互補題 | **未完了**。前群の状態を維持し、補助入力に二反例を保存した | 信頼条件の判断後、同じ`.02b-handlers`で再開。L10/L20へ再配賦して完了にしない |
| RV-L00a.12中1とR0の拘束 | **未着手** | 同じ群でImageOk.contVar/contLoc、hide/up/None、CQ/Arms/Clauses/Failureの公開署名を一緒に閉じる |
| RV-L00b.02b-at中1・中2のhandlersの担当分 | **未着手** | 同じ群でPathBasesの節と修正済みissueの遷移へ接続。全状態の進行・保存はL20/L70 |
| AtErrorの構成子と網羅性 | **未着手** | 同じ群でvalues/values_typedを使い、内部・公開の一覧と網羅性を一致させる。U02と文言の最終対応はL50/L70 |
| O016のA-L | 現在の本番8,979宣言と補助52宣言を検査 | 群再開後の変更にも再実行し、後続各L段の義務は維持 |
| O010/O160の所要 | 下記の外側の時間だけを取得 | 能動時間・待ちの較正と改造全体の見込み更新は取りまとめ |
| 次の閉包・状態の群 | **未起動** | handlersが閉じるまで進まない。前群からのkind表付きD29・fn/Tel・場所のDeclared・外部TelArgsの義務をそのまま引き継ぐ |
| 独立レビュー・受け入れ | 未実施 | 取りまとめ・設計者。今回の検査を独立レビューと数えない |

予定との差は、14導出の実装前に信頼条件で停止したことである。構成子や利用者の書ける形、提供範囲、主な定理の前提・結論は変更していない。候補の新しい信頼条件も採用していない。作業全体の開始は **2026-10-31 09:52:02 JST**、最終検査終了は **09:58:44 JST**、外側は **402.46秒（約6.71分）** である。文書の仕上げと提出前の照合までの外側の時間は[受け渡し](02b-handlers-delivery.json)へ記録する。能動時間と待ちは分離しておらず、能動時間の実測と扱わない。12時間には達していない。


## `.02b-handlers`：再開後の完成（2026-10-31）

初回提出時の結果を以下に残す。独立レビューで判明したguardの文脈と標準エラーの一覧の問題は、末尾の「レビューの所見の対応」で修正した。現在の契約はsignatures第29節の改訂後の行を正とする。

第12.2節の14導出と、移動・値の相互置換・narrowingの追加の場合を本番へ置いた。取りまとめが採った一般の型パラメータ改名の保存をCoreAssumptionsへ明記し、停止点の二反例の表が現行の条件では成立しないことを証明した。新しい停止点はない。B_WORKは `5a602b7a2adc40e487f60c8ffc738d2f4595289c`、指定ブランチは `m014/l00b.02b-handlers` である。gitの操作は行っていない。

### 閉じた定義と補題

| 対象 | 本番へ置いた内容 |
|---|---|
| 信頼条件 | TParam.Contains、TypeParamRenamingとid/prefix/under/insert/suffix、全型・Tel・型列・行のrawRenameTypes/renameTypes。Builtins.TypeAssumptionsの一般のsat_renameTypes/admits_renameTypesと旧sat_subst/admits_subst、恒等改名からのsat_local/admits_local、先頭追加の特殊化、SubstitutionAssumptionsとCoreAssumptionsへの接続 |
| 型付け | C_Match/Handle/Handle_Fail/Resume/ResumeL、Armsのnil/plain/guarded、Clausesのnil/cons、Failure.one、ImageOkのordinary/contLoc/contVar。HasTypeArms/ClausesのQemptyの略記も置いた |
| パターン・網羅性 | PatTy7/PatTys2、AltsTyのslotsの順列・selectSlotsとwitness、Inhabits23/All2/Each2、Exhaustive。値の移動/置換と型の移動、unguardedPatsの各構文操作との交換 |
| 値の移動 | FullShiftMap、逐次入力列・None・型パラメータ追加の下の移送、continuation/節/Failの文脈と全Φの移送。V/Vs/Each/CQ/Arms/Clauses/Failure/TelArgs/AtCallとCheckedWitnessの相互の場合 |
| 型の移動 | TypeShiftOrder/Algebra/Context/Contracts/Kinds/Exchange/Typing、宣言とkind/Annotationの移動、型の挿入と値の改名/置換/Tel.open/argumentsの交換。通常値の型付き像とSubstOk.shiftEAt/shiftEへ接続 |
| 値の相互置換 | SubstOk.hide/upValue/up/upNValue/upN/extendNone/params/shiftE/clause、ImageOkの3場合のlift/liftParams/shiftEAt/store移送、逐次のbinderImagesとTransport.many_values/clause_values。V/Vs/Each/CQ/Arms/Clauses/Failure/TelArgsのsubstとNone版。CQ/Arms/Clauses/FailureのR0を結論のRの像へ拘束 |
| narrowing・正則性 | Ctx.ContMapと、双方の型のWFを受けるCtx.Narrows.here、全型付け族とImageOk.narrow。CQ/ArmsのDeclaredとResumeのDeclared、hide/空ストア移送をTypingStoreへ分けた |
| PathBasesと標準エラー | CoreAssumptions.pathBases_clause_signature、HasTypeCQ.resume_location_contract。atErrorConstructors/Program.StandardErrorComplete/atErrorPattern、PatTy/PatTys.variables、AtError.match_pattern/match_pattern_typed、Exhaustive.atError。七欄をvalues/values_typedと同じ形で照合 |

[公開宣言の一覧](02b-handlers-r2-public-api.md)は新規・変更32モジュールの公開の手書き宣言を列挙する。本番の新規ファイルは19、既存の変更は13である。[変更のハッシュと一覧](02b-handlers-r2-source-changes.json)には既定importの更新も含む。新しいVal/Comp/Arm/Clauseの構成子は追加しておらず、既存のGround/Capture/Source/構文操作は元からこれらの形を持つ。Clause.substListだけは多相の像の型パラメータ移動を修正し、全構文の値改名との交換も証明した。Val25/Comp16/Arm1/Clause2/Step76を維持したことをLeanの環境で照合した。

### 場合の数の予定と実際

| 対象 | 予定 | 実際 |
|---|---:|---:|
| Cの追加 | 5 | 5、Cの累計20 |
| Arms/Clauses/Failure | 3/2/1 | 3/2/1 |
| ImageOk | 3 | 3 |
| 起動単位の導出の追加 | 14 | **14/14** |
| 三族の被覆義務 | 各49+14=63 | **各63**。内訳は下記のとおり |
| PatTy/PatTys | 7/2 | 7/2、値の移動・置換と型の移動を閉じた |
| Inhabits/All/Each | 腕の参照に必要な全形 | 23/2/2 |
| TypedFacts | V26を保持 | V26を保持。値の新規規則は0件 |

63の内訳は、V26/C20/Vs2/Each2/TelArgs2/Arms3/Clauses2/Failure1の58、CheckedWitness2、ImageOk3である。移動はCheckedWitnessも相互に消去する。置換・narrowing・型の移動は、保持要求の同じ閉じた証拠を再利用する。ImageOkはlift/liftParams・hide/up/store/shiftEAt・narrowの補助で3場合を処理する。**63個の相互matchを書いたという件数ではない。** AtCallAdmissibleの補助1構成子は別記し、63へ加算しない。[場合数の記録](02b-handlers-r2-case-inventory.json)とA-Lの構成子数の照合を参照する。

### 補助契約の選択と計画との差

[signatures第29節](signatures.md)に、各案・理由・捨てた案を記録した。採った細部は次のとおりである。

- R0はCQ/Arms/Clauses/Failureの結論のRの像へ固定する。C_ResumeLとその逆転は同じRを要求する。contVarは改名先のlookupを持ち、contLocは閉じた型・R0・場所の型を照合する。
- 置換の公開入口はSubstitutionAssumptionsを受ける。多相節の下では、置換像の型を移動してから値の束縛へ持ち上げる。通常の値の像を閉じた型へ制限しない。
- 操作の入力は宣言順の逐次の束縛とし、前の入力への依存を保つ。通常節は全入力の後の継続、Failはerrorの後のNoneを保持する。R/結果/行は型と値の双方の束縛数を反映する。
- guardはhideBuilders/hideConts・R=none・空の局所文脈を使い、全Φは保持する。通常節とFail節も全Φを持つ。unguardedPatsだけで網羅性を検査する。
- Resumeの葉は結果のDeclaredを受ける。narrowingのhereは元と先の型のWFを受け、継続のlookupを同じ型へ写す。
- 一般の型改名はnormする。生のshiftTypesについては順序保存を証明して正規化と交換する。PatTyのdataの欄は宣言の閉じた型パラメータの範囲で検査し、Inhabitsの篩はcarrierからの保守的な導入とする。
- 標準エラーは、現在の宣言表の構成子一覧と内部一覧の一致を明示してExhaustiveへ接続する。U02と文言の最終対応は既定のL50/L70に残す。StandardErrorの一構成子の存在だけから他がないとは仮定しない。
- 非公開のTypedImages/ContextMapと相互証明は実装補助のままとし、交換・束縛・型/ストア移送の共有補助を別モジュールへ分けた。

予定との差は、先に停止した後、承認された一般の型改名則と旧四欄の移行を同じ変更へ含めたこと、型の移動の相互補題と交換を独立モジュールに分けたことである。これらの信頼条件の意味の変更は、担当の補助契約の裁量だけで決めたものではない。主な定理の結論・提供範囲・利用者の書ける形・精密な外部状態は変更せず、新しい公理も置いていない。

### 群末の検査と証拠

[台本](02b-handlers-r2-validate.py)、[コマンドと所要](02b-handlers-r2-commands.json)、[検査全体](02b-handlers-r2-validation.json)、[全426入力のハッシュ](02b-handlers-r2-inputs-final.json)、[補助入力のハッシュ](02b-handlers-r2-artifact-inputs.json)を保存した。検査中の本番入力の変更は0件で、旧Release・固定版・lakefileを変更していない。

| 検査 | 結果 | 証拠 |
|---|---|---|
| 全既定ターゲット | `cd formal && lake build`、**終了0、669 jobs、33.363秒**。関係する変更モジュールを再ビルドした。旧のInterval等の既存lint警告は再表示された | [出力](02b-handlers-r2-build.log) |
| 二反例の保存と現条件による除外 | `lake env lean -M 12288`、**終了0、1.410秒、69宣言**。PriorCoreAssumptionsの充足と旧反例、closed_table_excluded/open_table_excluded | [入力](02b-handlers-r2-boundary.lean) / [出力](02b-handlers-r2-boundary.log) |
| 行の境界 | 同じ上限で **終了0、0.828秒、31宣言**。R0の不一致を部分型/効果拡大の下でも拒否、contVar/contLocとResumeの置換、None/error/continuation/外側の位置、先行する入力に依存する多相の署名、型付き像の型移動、guard/節/Failの非空Φ、AtError七欄とExhaustive、PathBasesのClauseSig、公開署名の#check | [入力](02b-handlers-r2-rows.lean) / [出力](02b-handlers-r2-rows.log) |
| A-L | 同じ上限で **終了0、9.558秒**。本番Refinementの全96モジュールと旧指定7宣言、計 **10,307宣言**。一意な件数とモジュール別件数+7が一致 | [入力](02b-handlers-r2-axioms.lean) / [集計](02b-handlers-r2-axioms-summary.json) |
| 公理と抜け道 | 本番10,307宣言と境界69+31宣言の依存は **propext・Quot.sound・Classical.choiceのみ**。許可外依存、sorryAx、独自公理は0件。本番Refinementのsorry/admit/axiom/native_decide/implemented_by/unsafe/partialの語の検出も0件 | [検査全体](02b-handlers-r2-validation.json) |
| 固定版と上限 | Lean **4.34.1**。既定のmoreLeanArgsと単独検査は **-M 12288**。RSSは計画上の非採取で未取得 | [版](02b-handlers-r2-lean-version.log) |

A-Lは生成された宣言と非公開の証明も含めて全件を検査した。旧指定7宣言には旧三モデルのassumptionsを含むが、新しいTypeAssumptionsを三モデルが満たす証明まで今回完成したという意味ではない。新しい三モデルの充足はL50へ残る。

公理依存の全出力は **1,070,864バイト** なので `<tmp>` に保存し、[large-records](large-records.md)に大きさとSHA-256を記録した。文書と台本に手元の絶対パスを残していない。workは依頼どおり実行していない。

途中の検査では、importの循環、raw型移動と正規化の順序、Noneの二重移動、相互の補題の暗黙引数、旧境界でのValueAssumptionsからSubstitutionAssumptionsへの更新漏れ、補助入力の定義的等式に関する失敗を検出して直した。上表は全修正後の入力に対する結果である。停止時点の元の反例入力は保管し、現行API用の写しで旧条件の充足と新条件による除外を照合した。

検査の作成時の関門では、本番のR0・束縛・表の契約を持ち主とした。既存の境界には多相節の像の型移動と新しいResume/Arms/Clausesの行がなかったため、今回の補助入力を加えた。専用の本番フラグや検査用のAPIは追加していない。モデルの充足と全状態の保存を、小さい境界の証明で代用していない。

### 残りと次群への申し送り

| 残る義務・手順 | 担当・閉じる条件 | 見込み時間 |
|---|---|---|
| 閉包・状態の8導出 | 次の`.02b-closures`。V_DependentLam/Closure、C_DependentApp、TelBody/CaptureOk/ClosureTy/DependentClosureTyとContTy/StoreOk/StateTy。今回の63のうち新規の場合だけを増やす | 既定の3〜6時間 |
| 閉包の三族と観測 | 次群。HasTypeVQ.shift_types_varの不可能な値の枝を新しい値規則へ追随する。捕捉したΓ/Φ・型付き像・依存βの交換とhideを接続する | 上記の内数 |
| 外部適用と場所のDeclared | 次群でVs+argumentsからTelArgsへの逆向き、StoreOk等のDeclaredを供給。保存への適用はL20。kind表付きD29とfn/Telの等号の既定の送り先を維持 | 上記の内数・後段は不明 |
| handle/resume/drop・PathBasesの全状態保存 | L20/L70。今回閉じた一般の置換・up・パターンの追随を再配賦しない | 不明 |
| 型改名・具体化と三モデル | L50。一般の制約包含を保つ改名、旧sat_subst/admits_substと値の四保存則を全モデルで示す | 不明 |
| 標準エラーの公開形・文言 | L50/L70。U02の公開形とP.cons/StandardError/RuntimeMatch/観測を一括して照合する | 不明 |
| D28の対照と報告 | .15・取りまとめ。今回の一般の型改名則による意味の変更を設計者へ報告する | 不明 |
| 独立レビュー | 取りまとめ・レビュー担当。[群末の依頼](../reviews/RV-L00b.02b-handlers-request.md)の観点と全新規ファイルを確認する | 不明 |
| 作業末のwork | 取りまとめ。共通入口の形式化ビルドと禁止宣言の検査を実行する。今回の担当は実行していない | 不明 |
| 受け入れ・取り込み | 取りまとめ・設計者。レビューの所見と上記の残る義務を確認する | 不明 |

再開の開始は **2026-10-31 10:03:24 JST**、群末の最終検査終了は **11:28:14 JST**、外側は **5,090.43秒（約84.84分）** である。文書と提出時の照合を含む外側の時間は受け渡しの記録を正とする。能動時間と待ちを分離しておらず、L10/L20から移した枠の能動時間の実測とは扱わない。12時間の停止条件には達していない。git、Rustの処理系、現行設計書、plan.mdの変更、work、次群の実装は行っていない。


### レビューの所見の対応（2026-10-31）

[独立レビューRV-L00b.02b-handlers](../reviews/RV-L00b.02b-handlers.md)の条件付き可（重1・中1・軽3）と、planの2026-10-31の先頭の判断に従い、以下を修正した。前回のguardの文脈は利用者の書ける形を狭めていたため撤回した。主な定理の前提・結論、CoreAssumptions、新しい公理、提供範囲、精密な外部状態は変更していない。停止を要する新しい変更はない。

| 所見 | 直した箇所・対応 | 判定と残る義務 |
|---|---|---|
| **重1：guardの文脈** | TypingのHasTypeArmsQ.guardedを元のΨと `localExtend δ.length Δ` に戻した。hideConts・R=none・Eff.empty・`liftMany δ.length Φ` は保持。TypingShift/SubstTyping/Narrowingのguardの場合と、TypeShiftTypingの型パラメータの移動の同じ場合を閉じ直した。narrowingはストアを変えずに継続を隠すContextMap.hideContsを使う | **修正済み**。signatures第29.3節の採った案・捨てた案を改訂し、旧のhideBuilders/空局所文脈の案を撤回した。K_Guardの型付けも同じΨ/局所文脈を使う義務を第24節へ追加 |
| **中1：標準エラーの網羅性** | AtPatternsのProgram.StandardErrorCompleteに `cs : List (ConName × ConDecl)` を追加。各項目のlookup・data・arityと、同じdataの全構成子の収載を検査する。atErrorConstructors csは各構成子の全変数のパターン列、atErrorPatterns csは内部At用のパターンを先頭へ加えた列とした。Exhaustive.atErrorをその全列について一般化 | **修正済み**。At/OutsideScopeの2構成子を持つ表でStandardErrorCompleteとStandardErrorを証明し、一般化したExhaustiveを適用した。OutsideScopeの値と内部の.atError値の双方を覆う。Atだけの列ではOutsideScopeを覆えないことも保存。U02の公開形・文言の最終照合はL50/L70 |
| **軽1：D29の正則性の供給** | 第24節の義務表に、C_Resumeの結果のDeclared、C_ResumeLの結果のDeclared、通常節のOpSig.WF、Fail節のAnnotation、空の腕のAnnotationを**各一行**で追加。旧導出とProgram/文脈/場所の正則性から供給する道筋を明記 | **文書対応済み**。実際のD29の埋め込みはL20/L70。Programの正則性とStoreOk等は.03・次群を依存とし、内側の節から外側の継続への二重の移動も照合する |
| **軽2：sat_localの旧欄との差** | 第29.1節に、旧欄のWFだけと、現在のCおよびC++extraの両側のAnnotation（Sorted・Declaredを含む）との差を明記。admits_localも両側のTypeAnnotationsを受けることを記した | **文書対応済み**。L20で旧証明を移す各使用箇所で供給し、Annotationを導けない場合は取りまとめへ報告する。信頼条件自体は今回変更していない |
| **軽3：篩の網羅性の後の変更** | 第24節と第29.4節のL10/L40/L70の行へ、C_MatchのExhaustiveの前提又はInhabits.refinedの定義を変更し、三族と網羅性の移送の該当場合を同じ変更で閉じ直すことを明記 | **文書対応済み**。Month・空型・非空List・長さを読むD27の網羅性の実装は既定の後続の担当であり、今回C_Match/Inhabitsを変更したとは数えない |

今回の本番の変更は既存6ファイル（AtPatterns、Typing、TypingShift、SubstTyping、Narrowing、TypeShiftTyping）で、新規の本番ファイルはない。[修正後の公開署名](02b-handlers-r3-public-api.md)と[変更のハッシュ](02b-handlers-r3-source-changes.json)を置いた。導出の構成子数は14追加・累計63のままである。

[境界の補助入力](02b-handlers-r3-boundary.lean)では、パターン束縛の外側のStringBuilderへ `.bound 1` でlengthを行うguardと、そのguardを持つ腕の型付けを示した。元のストアを読む `.loc 0` の専用操作も示した。さらに同じ腕について、値の移動、値の相互置換、Noneの下でIntegerを篩付きIntegerへ狭めるnarrowingを適用した。これにより、局所文脈だけでなく元のΨを残す修正も検査した。

同じ入力にAtとOutsideScopeの表を置いた。OutsideScopeの二つのString欄と内部Atの七欄をそれぞれのパターンで覆い、Atだけの列の非網羅性も証明した。元の単一構成子用の前提を、D61に従う表にも成立するものとして引用していない。csの条件はExhaustive.atErrorの補助の前提だけであり、C_Matchや主な定理へ一覧の前提を追加していない。

#### ビルド・公理依存・再現入力

[検査台本](02b-handlers-r3-validate.py)、[コマンドと所要](02b-handlers-r3-commands.json)、[検査全体](02b-handlers-r3-validation.json)、[全426本番入力](02b-handlers-r3-inputs-final.json)、[補助入力のハッシュ](02b-handlers-r3-artifact-inputs.json)を保存した。

| 検査 | 結果・範囲 |
|---|---|
| 既定ビルド | `cd formal && lake build`、**終了0、669 jobs、0.152秒**。修正した関係モジュールは途中のビルドで検査済みであり、最終回はその成果物を再利用した。既存のInterval等のlint警告は再表示された。[出力](02b-handlers-r3-build.log) |
| 所見の境界 | `lake env lean -M 12288`、**終了0、34宣言、0.871秒**。guardの構築器操作、三族の適用、At/OutsideScopeと内部Atの網羅性。[出力](02b-handlers-r3-boundary.log) |
| R0・None・Φ等の回帰 | 同じ上限で **終了0、31宣言、0.815秒**。r2の行の境界の現行API用の写しで、標準エラーの一覧の引数だけを追随。[入力](02b-handlers-r3-rows.lean) / [出力](02b-handlers-r3-rows.log) |
| 旧二反例の除外の回帰 | 同じ上限で **終了0、69宣言、1.266秒**。r2の同じ反例入力を再実行。[出力](02b-handlers-r3-prior-counterexamples.log) |
| A-L | 同じ上限で **終了0、9.316秒**。r2の全件列挙の台本を現行入力へ適用し、本番Refinementの96モジュールと旧指定7宣言、計 **10,308宣言**を検査。一意な件数とモジュール別件数+7が一致。[集計](02b-handlers-r3-axioms-summary.json) |
| 公理・抜け道 | 本番10,308宣言と境界34+31+69＝134宣言の依存は **propext・Quot.sound・Classical.choiceのみ**。sorryAx・許可外依存・独自公理は0件。本番Refinementの禁止トークンの検出も0件 |
| 入力と範囲 | 検査中の全426本番入力は不変。planとレビュー原本も開始時のハッシュと一致。旧Release・処理系・設計書・CoreAssumptions・固定版・lakefileを変更していない。work・次群は未実行 |

公理依存の全出力は **1,070,968バイト** なので `<tmp>` に置いた。SHA-256は `58aefaae39d9a1c3d0e54c1897abc9d94e8466c2b81394435ad151efe8db5e82` で、[large-records](large-records.md)にも追記した。文書と台本に手元の絶対パスは書いていない。

途中の局所検査では、ContextMap.hideContsと同名の構文操作の名前解決、補助入力の暗黙の型と具体的な定数の推論で失敗し、修正した。上の表は全修正後の成功であり、途中の回復用sorryAxを含まない。

検査の作成時の関門では、guardの公開の型付け規則と、宣言表から得る一覧による網羅性を持ち主とした。旧r2の境界はguardの構築器操作もOutsideScopeも含まなかったため、今回の誤りを検出できなかった。専用の本番フラグや検査用のAPIは増やしていない。

開始は **2026-10-31 11:46:27 JST**、最終検査終了は **11:52:36 JST**、外側は **369.69秒（約6.16分）** である。文書と提出時の照合までを含む時間は受け渡しの記録を正とする。能動時間と待ちは分離しておらず、1〜2時間の見込みを更新するための能動時間の実測とは扱わない。

今回の新規の改造内ファイルは次の一覧にまとめる。初回/r2の記録は保管し、現在の署名の検査にはr3を使う。レビュー原本は変更していない。

- [02b-handlers-r3-artifact-inputs.json](02b-handlers-r3-artifact-inputs.json)
- [02b-handlers-r3-axioms-summary.json](02b-handlers-r3-axioms-summary.json)
- [02b-handlers-r3-boundary.lean](02b-handlers-r3-boundary.lean)
- [02b-handlers-r3-boundary.log](02b-handlers-r3-boundary.log)
- [02b-handlers-r3-build.log](02b-handlers-r3-build.log)
- [02b-handlers-r3-commands.json](02b-handlers-r3-commands.json)
- [02b-handlers-r3-delivery.json](02b-handlers-r3-delivery.json)
- [02b-handlers-r3-final-check.json](02b-handlers-r3-final-check.json)
- [02b-handlers-r3-inputs-final.json](02b-handlers-r3-inputs-final.json)
- [02b-handlers-r3-lean-version.log](02b-handlers-r3-lean-version.log)
- [02b-handlers-r3-prior-counterexamples.log](02b-handlers-r3-prior-counterexamples.log)
- [02b-handlers-r3-public-api.md](02b-handlers-r3-public-api.md)
- [02b-handlers-r3-rows.lean](02b-handlers-r3-rows.lean)
- [02b-handlers-r3-rows.log](02b-handlers-r3-rows.log)
- [02b-handlers-r3-source-changes.json](02b-handlers-r3-source-changes.json)
- [02b-handlers-r3-start.json](02b-handlers-r3-start.json)
- [02b-handlers-r3-validate.py](02b-handlers-r3-validate.py)
- [02b-handlers-r3-validation.json](02b-handlers-r3-validation.json)

| 残る手順 | 担当・内容 | 見込み時間 |
|---|---|---|
| 所見への対応の再確認 | 取りまとめ・レビュー担当。重1/中1の境界と軽の送り先を確認する | 不明 |
| 作業末のwork | 取りまとめ。今回の担当は実行していない | 不明 |
| 受け入れと次群の起動 | 取りまとめ・設計者。今回の修正を受け入れた後、閉包・状態の群を別途起動する | 受け入れは不明、次群は既定の3〜6時間 |

## .02b-handlers の作業末の work（取りまとめ、2026-10-31）

- 基準: `5a602b7a2adc40e487f60c8ffc738d2f4595289c`。作業ツリーは RV-L00b.02b-handlers の所見の対応（本番の Lean の修正を含む）を終えた状態。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 5a602b7a2adc40e487f60c8ffc738d2f4595289c`（sandbox の外）。選ばれた単位は `formal_build`（`cd formal && lake build` と `sorry` を使う宣言の拒否）だけである。先に `formal/.lake/build` の `Benitoite/Release/Refinement` の生成物（lib と ir）を消した。
- 結果: 終了0（selected checks passed）。外側の時間は53.65秒、最大常駐量は1,078,444,032バイト（約1.00 GiB）。
- 計画からのずれ: なし。
