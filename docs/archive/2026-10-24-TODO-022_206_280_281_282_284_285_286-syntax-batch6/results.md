# 第6弾の段・改造の結果の集約

## stage S-R1（R01 の後）

計画の指定は `scripts/check.sh --level stage --base B_STAGE --only policy_selftest` である。R01 の後には実行せず、R01 の作業末の work（同じ `policy_selftest`）の結果を引用するつもりでいたが、その記録は 07-03「結果の保存と引用」の全欄を満たさない。そこで、R08 が R07 の取り込み後（`a4d4990712233357a456c5ff112fb1b430464ac8`、R01〜R07 をすべて含む）に新たに実行した `policy_selftest`（22件成功、`r08/results.md`）を S-R1 の証拠とする。実行時の基準 B_WORK と HEAD はともに上記の `a4d4990712233357a456c5ff112fb1b430464ac8` である。`check.sh --level stage` の入口ではなく `python3 -B scripts/check/test_policy.py` を直接実行した結果であり、stage の dry-run は通していないが、選ぶ単位と中身は同じである（`scripts/check.sh` の `policy_selftest` は同じコマンドを実行する）。引用ではなく、同じ検査を後の状態で実行した結果である（取りまとめ、2026-10-24）。

## stage S-R2・S-R3（R06 の後にまとめて実行）

S-R2 は R04 の後に置いていたが、取りまとめが実行し忘れたため、R06 の後に S-R3 と合わせて一度で実行した。二つの指定の統合テストの和をとった。

- 基準 B_STAGE: `f76f32234a55bd952c53aeda0685bd9dfef5a2b2`（R 段の開始）。HEAD: `79c544170b08bd40a703c942e040854ee3a68b70`（R06 の取り込み）。
- コマンド: `scripts/check.sh --level stage --base f76f32234a55bd952c53aeda0685bd9dfef5a2b2 --only tests_related --test property_library --test reference_examples --test skill_docs --test skill_examples --test spec_examples --test stdlib_doc_examples --test desugar_export`。事前に `--dry-run` で選択を確かめた。
- 終了0、外側の時間 41.97 秒。desugar_export 30件（ignored 1）、property_library 15件（ignored 2）、reference_examples 1件、skill_docs 8件、skill_examples 3件、spec_examples 7件、stdlib_doc_examples 1件、失敗0。
- T-D（derive の受理入力の一致）は `r03/results.md` の旧新比較（受理入力10件で本文・意味ハッシュ・記録が一致）を、T-L（Log の六入口）は `r05/results.md`・`r06/results.md` の局所比較（1入力・11定義一致）を照合した。

## R08: 相乗りの接続の照合

2026-10-24、実装担当。基準 B_WORK と着手時の HEAD は `a4d4990712233357a456c5ff112fb1b430464ac8`、ブランチは `mod012/R08`、着手時の差分はなかった。R01〜R07 の実装・文書・結果を D9〜D14 と照合した。現在の契約を変える修正は不要であり、R08 は集約・作業結果・独立レビュー依頼の三文書だけを変更する。

| 接続 | 照合した実装と文書 | R08 の確認 |
|---|---|---|
| derive の事前拒否 | `Manager.prepare`、03-06「外部生成の管理と照合」、道具の README、英語リファレンス、同梱 Skill | JSON/Property とファイル単位の宣言の組み合わせは preview・初回 apply・check の共通入口で全体を非書き込みで拒否する。Show/Order だけ、空設定、対象外の依存先には拒否を広げない。既存の自己検査49件を実 reader・formatter・通常 check/test で再実行し、全て成功 |
| derive の版と移行 | 同じ四つの案内と生成器の版定数、既存の記録・receipt の検査 | 生成器 `3.1.0-syntax-batch5`、inventory/manifest/receipt/記録/意味ハッシュ3、設定1、Property.libraryVersion `2.0.0` が一致する。型定義と対象の移動、旧道具での復旧を更新前に終える順序、新しい preview の確認を保つ。過去版の移行節は現行案内と分ける |
| Log の公開と例 | `Log.bnt`、生成参照 `stdlib/Log.md`、03-07、英語リファレンス、Skill の idioms と本文の案内 | 純粋な `formatRecord(record: Record) -> String` の署名・末尾改行なし・水準を選別しない契約が一致する。英語と Skill のテキスト/JSON の節は同一。読み戻し・属性の順序と重複・数値の表現・残るエフェクトを既存の文書例の入口で確認 |
| Log の標準宣言と形式化 | 既存の `log-standard.bnt`、g2 manifest、五形式と六入口の比較器 | 現状態から書き出し直し、既定 Lean ビルド後の六入口が1入力・11定義で一致。VM/参照評価の Direct/Request 比較も既存の書き出しテストで成功。Lean の規則・定理・公理の変更は不要 |
| 新水準の lint と旧指定 | `check.sh`、方針の自己検査、旧固定記録、07-03、workflow の二雛形 | 新水準の `lint_default` は lib/tests/examples、旧指定は従来の対象を保つ。自己検査22件が成功し、三シェル構文・旧集合を含めて確認。旧固定記録は B0 と同一 |
| 言語の版と Q4 の訂正 | 01-03・01-04、02-05、06-09、package の登録表と help | 01-03 に一般規則を残し、版別7件の登録内容と案内は06-09にある。0.0.6/7だけ節を名指さない差も保持。登録表・help は B0 と同一で、追加の E0908 はない。幅付き整数の既存の定数警告の説明は一致し、新しい局所解析の条件を先取りしていない |

実行コマンド・件数・時間と Log の交換ハッシュは [R08 の結果](r08/results.md)に記録した。R08 の再実行は既存入口による局所の接続確認であり、先行 work の全件結果や改造全体の受け入れを代用しない。生成参照は再生成後も差分なし。言語規則や Lean の主な定理の変更、公理の追加が必要な点は見つからなかった。

### stage と独立レビューへの引き渡し

S-R2/S-R3 は上記のとおり取りまとめが R06 後に実行済みである。R07 は文書の訂正、R08 は記録だけであり、それ以降に標準ソース・生成器・検査方針・実行例・交換器・manifest を変えていない。R08 では stage の再実行も過去結果を引用する受け入れ判断も行わない。S-R1 は上記のとおり、R08 が直接実行した方針自己検査22件を証拠とする。R01 の work 結果を引用して省略したものではなく、S-R1 の追加実行は不要である。段の受け入れは取りまとめが担当する。

独立レビューの範囲と受け入れ条件を [RV-R08 の依頼](reviews/RV-R08-request.md)へ記録した。独立レビューの実施・指摘対応後の受け入れは取りまとめが担当し、R08 の自己点検を独立レビューの完了として扱わない。

| 後続 | 担当と時期 | 見込み時間 |
|---|---|---|
| R08 の独立レビュー、stage の証拠の照合と段の受け入れ | 取りまとめが R08 の取り込み時に手配 | レビュー20〜40分、追加検査が必要なら plan の stage 行に従う |
| A07 以後の警告条件の拡張と U01 の strict 入力の棚卸し | 各担当が計画の依存成立後に実施 | 計画の各作業に従う。棚卸しの初回時間は不明 |
| 日本語訳の同期 | Z01a 担当がリリース準備時に実施。derive の現行版・対処・復旧と Log の二例を英語版へそろえる。06-06・03-08 の訂正に対応する訳の有無と、Skill の主語の明示も確認する | 計画の Z01a に従う |
| 改造全体の change、最終の形式化比較、実候補の release と受け入れ | G01・X05/Z01・取りまとめが計画の各時期に実施 | 計画の検査・全体表に従う。初回の全比較は不明 |

## R08R の後の short の省略

R08R は `crates/benitoite/src/builtins/funcs/log.rs` を変えたが、変更は文字列の上限を超えたときの報告名の定数を引数で渡すことだけで、通常の実行の経路の処理量は変わらない。計画の「性能比較のshort」の例外として short を省き、次の short（A07 の区切り）がこの変更も含めて比べる（取りまとめ、2026-10-24）。

## S02b の後の short と基準の切り替え（取りまとめ、2026-10-25）

計画は S02b の後に B0（706d7ca3）との short を置いていたが、`tools/bench/compare/run.py` は比較する版どうしの Cargo.lock の依存の記録が異なると比較を拒む（`build.py` の `evidence`。「Cargo.lock dependency records differ across comparison states」）。S01 と S02a で rustls 系と Wasmtime を上げたので、B0 との short はこの道具では行えない。依存の更新は勧告への対応として必須であり、性能を理由に戻す選択はないので、依存の更新による性能の変化は測らない。

以後の short の基準を B1 = `ac992bde2cb34d1861de3eb2943e75443a108189`（S02b の取り込み。S03〜S05 は依存を変えない）に切り替える。A07・A12・A15・A18・A21 の区切りの short は B1 と比べる。B0 から B1 までの処理系の変更（R05・R08R の Log、S01・S02a・S02b）のうち、依存の更新を除く分は R05 の short（退行の疑いなし）と、R08R・S02b の変更の小ささ（報告の名前・上限の設定と分類）で扱う。

## S04: 公開手順と保存記録のパス置換（2026-10-25）

基準 B_WORK は `100ab3753ed99f954f7b93f9a8329e2554de54ae`。AGENTS・公開の二雛形・git-workflow に、改造の最初の勧告照合と設計者の判断、および候補での二 lock とツールチェーンの再照合・表示・記録・報告・次の改造への引き継ぎを加えた。CHANGELOG の Unreleased に修正版と手順を記した。03-01・02-09・02-10・03-10 の現行の版と出典は先行作業でそろっており、追加の訂正は不要だった。過去の49.0.2の実測は保った。

依頼の補足で advisories.py の stdout/stderr・設定の写し・report.json の手元のパスを保存時に置き換え、07-03 の記録の説明も直した。置換前に分類と DB のコミットの取得を終え、設定のハッシュは置換前の実際の入力を示す。方針自己検査へ退行一件を加え、修正前の失敗を確認後に修正した。

work は同じ基準の `--only policy_selftest,advisories` を dry-run 後に一度実行し、検査本体0。自己検査26件成功、実照合は両対象とも検出0件で、S03 から新しい勧告なし。保存9ファイルの手元のパスの不在と DB のコミットの保持を確認した。time の real は19.91秒。計時ツールはサンドボックスの sysctl 制限で終了1となり、最大常駐量は取得不能だった。コマンド・二 lock と DB・日時・失敗と修正・環境制限・申し送りは [S04 の結果](s04/results.md)にある。

公開スキル security-advisories への四箇所の参照は S05 が本体を作って閉じる。S04 はツールチェーンの勧告を網羅的に照合したとは扱わず、候補の再照合は Z01b へ渡す。CRL/OneCRL・ca-certificates の案内は docs/todo の TODO-284、sources・Dependabot・独立 Lean 検査器の評価は TODO-286 の残件として取りまとめへ渡す。独立レビューと受け入れは未実施で、取りまとめの担当である。

## S05: 公開スキルの作成とリンクの完了（2026-10-25）

基準 B_WORK は `2247d960974fda379a4e169f541ab9fe5d944b5c`。公開の security-advisories スキルと AGENTS の表の案内を作成し、S04 の四箇所の参照先を解決した。二 lock と四ツールの照合、影響の評価、記録・項目の追記と設計者の判断、手動・周期的な呼び出しをまとめた。公式資料の確認と手元で未確認の利用可否・実動作を分け、架空の入力で手順を自己点検した。実際の勧告照合・LLM の実呼び出し・定期登録は行っていない。

必須の `.agents/skills/security-advisories` の相対リンクは、環境の `.agents/` の書き込み制限により `Operation not permitted` で作成できなかった。その後、2026-10-25 に取りまとめがリンクを作成して追跡対象にし、相対の参照先 `../../.claude/skills/security-advisories` と実体を確認した（`31960eb2`、S05 の結果の「取りまとめの追記」）。リンクの未完は解消した。検査と環境制限、机上確認と申し送りは [S05 の結果](s05/results.md)に記す。独立レビューと S 作業群の受け入れも取りまとめが担当する。

スキルの形式検証と静的点検は成功した。指定基準の work は dry-run の後に一度実行し、文書だけで実行単位0件、検査本体の終了0だった。外側の時間0.087599秒、time の real は0.08秒。計時ツールはサンドボックスの sysctl 制限で終了1となり、最大常駐量は取得できなかった。

## stage S-A0（A07 の後、取りまとめ、2026-10-25）

- 基準: `--base caadeaa397ba46a29f76ab83948a48aac90e6016`（A01a の開始の直前。`--level` と `--only` の併用なので分類はしない）。HEAD は `2d563be9d72a`（A07 の取り込み）。未コミットの差分なし。
- コマンド: `scripts/check.sh --level stage --base caadeaa397ba46a29f76ab83948a48aac90e6016 --only tests_related --test declarations --test checked_args --test named_arguments --test golden --test cli_process`（先に同じ指定の `--dry-run` で選択を確かめた）。
- 結果: 終了0。checked_args 10件、cli_process 33件、declarations 25件（無視1件は既存）、golden 2件、named_arguments 22件が成功し、失敗0件。外側の時間 109.03秒、最大常駐量 1,351,647,232バイト（`/usr/bin/time -l`）。ログは [s-a0/stage.log](s-a0/stage.log)。

## A07 の区切りの short（取りまとめ、2026-10-25）

- 状態: before = B1 `ac992bde2cb34d1861de3eb2943e75443a108189`、after = `2d563be9d72a`（A07 の取り込み）。コマンド: `python3 tools/bench/compare/run.py --tier short --state before=ac992bde… --state after=2d563be9… --name syntax-batch6-a07`。最初の起動は `run.py` に実行の権限がなく終了126（測定前）。`python3` から起動し直した。
- 結果: 終了0。外側の時間 215.64秒（二つの版のビルドを含む）。九族の出力照合はすべて成功。目標21点はすべて達成し、退行の警報は0件。59点は差が計時のぶれ以下などで判定不能。記録は `tools/bench/results/2026-10-25-2d563be9-syntax-batch6-a07/`、ログは [s-a0/short.log](s-a0/short.log)。記録の手元のパスは `<repo>` に伏せた。
- 判断: 退行の疑いなし。型検査の入口・区間解析の土台（A01〜A07）による型検査の時間の増加は、short の点では検出されなかった。

## stage S-A1（A12 の後、取りまとめ、2026-10-25）

- 基準: `--base e61a5b09cf54aecac857b90aaf76580c4d224e7b`（S-A0 の記録の後。`--level` と `--only` の併用なので分類はしない）。HEAD は `3b275ce8`（A12b の取り込み）。未コミットの差分なし。
- コマンド: `scripts/check.sh --level stage --base e61a5b09… --only tests_related --test declarations --test named_arguments --test golden --test cli_process --test test_command`（先に同じ指定の `--dry-run`）。
- 結果: 終了0。cli_process 33件、declarations 27件（無視1件は既存）、golden 2件、named_arguments 22件、test_command 52件が成功し、失敗0件。外側の時間 85.69秒、最大常駐量 1,311,817,728バイト。ログは [s-a1/stage.log](s-a1/stage.log)。

## A12 の区切りの short（取りまとめ、2026-10-25）

- 状態: before = B1 `ac992bde2cb34d1861de3eb2943e75443a108189`、after = `3b275ce8`。コマンド: `python3 tools/bench/compare/run.py --tier short --state before=ac992bde… --state after=3b275ce8… --name syntax-batch6-a12`。
- 結果: 終了0。外側の時間 126.51秒（before のビルドは再利用）。九族の出力照合はすべて成功。目標38点はすべて達成し、退行の警報は0件。56点は差が計時のぶれ以下などで判定不能。記録は `tools/bench/results/2026-10-25-3b275ce8-syntax-batch6-a12/`、ログは [s-a1/short.log](s-a1/short.log)。手元のパスは `<repo>` に伏せた。
- 判断: 退行の疑いなし。

## stage S-A2（A15 の後、取りまとめ、2026-10-25）

- 基準: `--base a6350374`（L13 の基準。`--level` と `--only` の併用なので分類はしない）。HEAD は `6ca6f678`（A15b の取り込み）。未コミットの差分なし。
- コマンド: `scripts/check.sh --level stage --base a6350374… --only tests_related --test checked_args --test declarations --test named_arguments --test golden --test runtime_builtins`（先に同じ指定の `--dry-run`、[s-a2/dry-run.log](s-a2/dry-run.log)）。
- 結果: 終了0。checked_args 10件、declarations 31件（無視1件は既存）、golden 2件、named_arguments 22件、runtime_builtins 23件が成功し、失敗0件。外側の時間 89.03秒、最大常駐量 698,384,384バイト。ログは [s-a2/stage.log](s-a2/stage.log)。

## A15 の区切りの short（取りまとめ、2026-10-25）

- 状態: before = B1 `ac992bde2cb34d1861de3eb2943e75443a108189`、after = `6ca6f678`。コマンド: `python3 tools/bench/compare/run.py --tier short --state before=ac992bde… --state after=6ca6f678… --name syntax-batch6-a15`。
- 結果: 終了0。外側の時間 122.52秒。九族の出力照合はすべて成功。目標39点はすべて達成し、退行の警報は0件。55点は差が計時のぶれ以下などで判定不能。記録は `tools/bench/results/2026-10-25-6ca6f678-syntax-batch6-a15/`、ログは [s-a2/short.log](s-a2/short.log)。手元のパスは `<repo>` に伏せた。
- 判断: 退行の疑いなし。案 II（L13〜L17・A13a〜A15b）を閉じる。

## stage S-A3（A18 の後、取りまとめ、2026-10-26）

- 基準: `--base d2d99542`（L18 の基準。`--level` と `--only` の併用なので分類はしない）。HEAD は `1f1f32ae`（A18b の取り込み）。未コミットの差分なし。
- コマンド: `scripts/check.sh --level stage --base d2d99542… --only tests_related --test declarations --test named_arguments --test golden --test desugar_export`（先に同じ指定の `--dry-run`、[s-a3/dry-run.log](s-a3/dry-run.log)）。
- 結果: 終了0。declarations 31件（無視1件は既存）、desugar_export 31件（無視1件は既存）、golden 2件、named_arguments 22件が成功し、失敗0件。外側の時間 161秒、最大常駐量 3,752,951,808バイト。ログは [s-a3/stage.log](s-a3/stage.log)。

## A18 の区切りの short（取りまとめ、2026-10-26）

- 状態: before = B1 `ac992bde2cb34d1861de3eb2943e75443a108189`、after = `1f1f32ae`。コマンド: `python3 tools/bench/compare/run.py --tier short --state before=ac992bde… --state after=1f1f32ae… --name syntax-batch6-a18`。
- 結果: 終了0。外側の時間 129秒。九族の出力照合はすべて成功。目標35点は達成し、未達は0点（退行の警報なし）。55点は差が計時のぶれ以下などで判定不能。記録は `tools/bench/results/2026-10-26-1f1f32ae-syntax-batch6-a18/`、ログは [s-a3/short.log](s-a3/short.log)。手元のパスは `<repo>` に伏せた。
- 判断: 退行の疑いなし。案 I（L18〜L21V・A16a〜A18b）を閉じる。

## stage S-A4（A21 の後、取りまとめ、2026-10-26）

- 基準: `--base 61e04c64`（A19a の基準。C4 の受け入れと A19〜A21 の置き換えの後。`--level` と `--only` の併用なので分類はしない）。HEAD は `0912b310`（A21c の取り込み）。未コミットの差分なし。
- コマンド: `scripts/check.sh --level stage --base 61e04c64… --only tests_related --test checked_args --test named_arguments --test golden --test cli_process --test l30_http_server --test l32_http_client`（先に同じ指定の `--dry-run`、[s-a4/dry-run.log](s-a4/dry-run.log)）。
- 結果: 終了0。六つのターゲットで92件が成功し、失敗0件、無視0件。外側の時間 166秒、最大常駐量 3,282,157,568バイト。ログは [s-a4/stage.log](s-a4/stage.log)。A21c が標準ライブラリの11モジュールの先頭に `//!` の doc コメントを加えたことによる位置のずれは、ゴールデンと CLI のテストに現れなかった。
- 計画からのずれ: 計画の行の名前（「固定域（シフト）→W0404。操作と HTTP の欄に W0404 を作らないこと」）は D4 の変更に合わせて直した後のもの。指定のターゲットは変えていない。

## A21 の区切りの short（取りまとめ、2026-10-26）

- 状態: before = B1 `ac992bde2cb34d1861de3eb2943e75443a108189`、after = `3d89ec72`（A21d の取り込み）。コマンド: `python3 tools/bench/compare/run.py --tier short --state before=ac992bde… --state after=3d89ec72… --name syntax-batch6-a21`。
- 結果: 終了0。外側の時間 123秒。九族の出力照合はすべて成功。目標は50点で達成、未達は0点（退行の警報なし）。44点は差が計時のぶれ以下などで判定不能。記録は `tools/bench/results/2026-10-26-3d89ec72-syntax-batch6-a21/`、ログは [s-a4/short.log](s-a4/short.log)。手元のパスは `<repo>`・`<home>` に伏せた。
- 判断: 退行の疑いなし。RV-A21 の条件（中1）は A21d で閉じた。案III（L22〜L25T・A19a〜A21d）を閉じる。

## stage S-X（X05 の後）

2026-10-27、X05b 担当。X05a の3回目の K1 全体の成功を引用し、X01〜X05 の接続の証拠を集約した。六入口・独立入力・全関係定義・Rust/Lean の解析・評価関係と VM・Range・案III・最終 manifest が一つの関係状態で一致した。K1 は再実行していない。引用の全欄と件数・除外・失敗の経緯の詳細は [x05/results.md](x05/results.md)にある。RV-X05 の独立レビューと段の受け入れは取りまとめが別に行い、`reviews/RV-X05.md` に記録する。本枝の自己点検を独立レビューの完了とは扱わない。

| 引用の欄 | S-X の証拠 |
|---|---|
| 基準・HEAD・差分 | K1 の B_WORK/HEAD は `d62dbaa1c9293bd32e3dbb1b65b1efbc90a6d44b`。引用先の B_WORK/HEAD は `732b29255e2de0a7116c4fc1dc056944cc5ac860`。着手時の差分・未追跡入力なし。`git diff --stat d62dbaa1 HEAD` は52ファイル・185,294行追加で、X05a の実行・保存・点検記録と時間方針の実績1行だけ（[stat](x05b/relation-diff-stat.log)・[一覧](x05b/relation-diff-files.log)）。本枝の未コミット差分と未追跡ファイルの内容の SHA-256 は [work 前](x05b/state-before-work.json)・[最終状態](x05b/state-final.json)に保存 |
| 入力・道具 | 元の [5,995ソース入力のハッシュ](x05a/run3/source-state-before.json)と検査後・引用時のハッシュが一致。ソース・テスト/期待値・標準ソース・生成元/生成物・設定・交換器・文書例の変更0件。入力 manifest は1,220ファイル、最終 manifest は12,063成果物、SHA-256 `352d37abc00cc6d37878d9bc04a57279e6976b50cefa9d4d620d12ba68c5a5b2`。[元の索引](x05a/run3/k1-records-index.json)と[読み戻し結果](x05b/evidence-check.json)が一致し、七比較実行ファイルと実 CLI のハッシュも一致 |
| 実行・構成・ツールチェーン | 独立の K1 全体 `scripts/check-formal.sh`。Cargo 既定構成、Lean `-M 12288`、逐次ビルド。`CARGO_HOME=<tmp>/benitoite-a01a-cargo` と三出力先 `target/{desugar,coverage,interval}-diff/x05a-k1-run3-20261027` を使用。正確な記録器と外側のコマンドは [X05 の引用欄](x05/results.md#引用する関係状態と入力)・[起動記録](x05a/run3/k1-started.json)にある。Rust/Cargo 1.98.1、Lean **4.34.1**、Lake 5.0.0-src+5045d00、elan 4.2.4、Python 3.9.6、macOS 27.0.1 / arm64 |
| 終了・時間・環境の制限 | [K1 本体](x05a/run3/k1-body.json)は終了0、2636.796秒（43分56.796秒）。[外側](x05a/run3/k1.json)は `/usr/bin/time -l` の sysctl 拒否で終了1、2636.823秒。最大常駐量は取得不能、終了143はない。検査本体と計測の終了状態を分ける |
| 六入口・独立交換の件数 | 脱糖73,849定義、組み込み142,092比較、独立網羅性10,020件・view付き10,028件、プログラム網羅性22,483件が一致。表層の全体報告51,758分類は matched 51,738・outOfScope 19・Q11 1、不一致等0。固定表との1,791入力の対応と Log 公開利用の六入口・五ハッシュも一致。旧コアの型検査失敗419入力を成功へ足さない（[元の六入口要約](x05a/run3/legacy-and-eval-summary.json)） |
| 区間解析・全関係定義 | 全10系統で一致、深さ除外0・段の深さ停止0、各系統に情報を持つ本体がある。最大の programs は区間の型検査成功1,403入力・失敗389入力、99,989比較本体・78,978情報を持つ本体（うち Bottom 以外4,035）。五 profile の独立解析は8/10/41/7/108本体、情報を持つ本体6/8/41/2/54であり、全 Top だけの成功はない（[元の全体要約](x05a/run3/evidence-summary.json)） |
| 対象外・停止・0件の扱い | 外部型の4入力・12元定義・16本体は理由 externalType と観測を残し、親候補・情報を持つ整数区間・独立入力の候補がないことを確認した。意図した予算入力の未解析6本体と全体上限による未着手7件、独立評価の flow 3・domain 62の除外を成功へ足さない。上限0の列挙用の終了1・matched=true・accepted=false・比較0件も解析の成功へ足さない |
| 評価関係と VM | 算術39件・Range37件・域外シフト46行が一致。Range の事前選別9本体、シフトの独立期待値だけの62行（unknownFailure 46・notClosedOrFuel 16）は比較済みへ足さない。標識出力の R0201 も算術の失敗から分ける。有限の比較は A1 の接続証拠であり、全入力の意味保存の証明ではない |
| 元の永続記録・保存範囲 | [X05a の3回目と取りまとめの受け入れ](x05a/results.md)、run3 の要約・索引・ログを引用。ZIP は [x05a-run3-k1-records.zip の索引とハッシュ](work-copies/README.md#f475)、80,046,150バイト、SHA-256 `6986e19acfa40abad5507cca1583c7240f417ee96504b58b4ddd4da0e8e4aa9e`。索引12,064件のうち保存12,055件・大型の再生成可能入力のハッシュのみ9件、報告/ログの省略0件。X05b も全収録ファイルを読み戻して照合した。区間出力683,963,047バイトで2GB以下の目標を満たす 追記（2026-10-28）: 生の記録の元は git の外に置き、同日に取りまとめが削除する予定である（この作業では未削除）。大きさと SHA-256 は[保管対応表](work-copies/README.md#分類と元の対応)に残す。 |
| 初回の失敗・修正・再実行 | 1回目は外部型の列挙未完で本体終了1、固定表にも幅付き警告の1入力が欠落。X05R が理由付き除外・固定表・出力の重複を修正。2回目は W0501 だけの入力を警告欠落の負例に選んで本体終了1。X05S が対象警告の集合を共有し、点検で見つけた最終要約の配列読者も修正。3回目が全体成功。1・2回目は不合格のまま保持する |
| 関係状態の一致・判断者・日付 | コミット間と本枝の変更は記録だけで、5,995入力と8実行ファイルのハッシュが一致するため、K1 の関係状態は変わらない。引用の判断者は **X05b 担当、2026-10-27**。最終状態の入力・道具が変わり影響を説明できなければ、Z01b/取りまとめが K2 全体を実行する。公開候補の版・同梱物・CLI・配布の照合は別途行う |

| 残る作業・検査・測定・レビュー・受け入れ | 担当と時期 | 見込み |
|---|---|---|
| RV-X05 と S-X の受け入れ | 取りまとめが本集約後に別に実施 | 不明 |
| U01〜U03、改造全体の change・short の判断とレビュー・受け入れ | 各担当・G01・取りまとめ、計画の順序に従う | plan の各作業に従う |
| K2、公開候補の release と手動照合・受け入れ | Z01b と取りまとめ、最終の関係状態で引用の可否を判断 | K1 本体の実測43分57秒。K2 の要否・最終時間は不明 |

## RV-X05 による訂正（2026-10-27）

元の本文・表・取りまとめのレビューは実行時の記録として保持する。以下は RV-X05-response.md の判断に従う訂正であり、3回目 K1 を再実行した記録ではない。

stage S-X の記録を訂正する。

「情報を持つ本体」は従来の非 Top の分類であり、Bottom を含む。3回目とその取りまとめのレビューの件数は、次のように分けて読む。`return` の返す区間は交換・比較しておらず、`return` だけで抜ける本体の正常な継続の成分は Bottom になる。

| 系統 | 非 Top の本体 | うち Bottom | Bottom 以外 | 比較した利用者の警告 |
|---|---:|---:|---:|---:|
| programs | 78,978 | 74,943 | 4,035 | 38 |
| identity | 195 | 192 | 3 | 68 |
| manifest/manifest-interval | 249 | 238 | 11 | 8 |
| range/interval | 65 | 65 | 0 | 6 |
| vm/original | 39 | 39 | 0 | 20 |
| vm/instrumented | 39 | 39 | 0 | 14 |
| vm/range/original | 46 | 46 | 0 | 4 |
| vm/range/instrumented | 46 | 46 | 0 | 2 |
| vm/shifts/original | 108 | 108 | 0 | 54 |
| vm/shifts/instrumented | 108 | 108 | 0 | 54 |

10系統の Bottom 以外の本体は延べ4,049件であり、うち programs は4,035件である。他の7系統にはこの本体がない。比較が空虚でないことは、Bottom 以外の本体に加え、上表の位置まで照合した利用者の警告と、比較済み独立入力の値を根拠とする。Bottom だけで満たせる従来の関門では十分でなかったため、X05T で全体と系統ごとの関門を加えた。

`rustLeanMatched: true` と、除外を含む報告の `matched: true` は途中の assert を通った後の定数である。「各系統の比較器が終了まで走った」という記録として読む。独立の件数の証拠は、個別報告の比較数・manifest の解析済み数から除外数を引いた数・集約の件数の照合である。

外部型で除外した4入力・12元定義・16本体について、「Top・Bottom 以外の整数区間0」は本体自身の値に限る。除外した本体の独立入力355件中14件は Top でも Bottom でもない整数区間を持ち、本体14件は Bottom である。これらの正常値は Lean と未比較で残る。除外を認める根拠は親候補・独立入力の候補がともに0件であり、利用者の警告を落とさないことである。「情報を持つ解析や候補を隠さず」などの表現を、正常値全般が比較済みであるとの根拠に使わない。同じ除外は programs と manifest 系統に現れるが、固有の未比較件数へ二重に足さない。

X05T で変更した関門・負例・警告の照合の保存済み出力への適用は [X05T の結果](x05t/results.md)に記す。比較器の関係状態が変わるため、以前の「関係状態が同じ」との説明を X05T 後へそのまま引用しない。S-X は3回目 K1 と X05T の追加照合を合わせて取りまとめが確認する。最終関係状態の K2 全体は Z01b で実行する。戻り値の区間の比較・外部型の交換・観測入口の機能による分離の検討は、取りまとめが後片付けで docs/todo へ登録する。

## U03 の前の short（取りまとめ、2026-10-27）

- 状態: before = B1 `ac992bde2cb34d1861de3eb2943e75443a108189`、after = `dc171a72882bec1c4ac4f8a31a11b05e11c235a3`（U03a の取り込みの後）。A21 の区切りの後の処理系の変更は、X01〜X05T の型検査の記録先を任意で受け取る経路と読むだけの観測（本番の経路は記録先なしで同じ処理を使う）、U01b のテスト専用のモジュールである。コマンド: `python3 tools/bench/compare/run.py --tier short --state before=ac992bde… --state after=dc171a72… --name syntax-batch6-u03`。`cargo clean` の後なので、両状態のビルドを含む。
- 結果: 終了0。外側の時間 3分15秒（ビルドを含む）。九族の出力照合はすべて成功。目標は47点で達成、未達は0点（退行の警報なし）。47点は差が計時のぶれ以下などで判定不能。記録は `tools/bench/results/2026-10-27-dc171a72-syntax-batch6-u03/`、ログは [s-u/short.log](s-u/short.log)。手元のパスは `<repo>`・`<home>` に伏せた。
- 判断: 退行の疑いなし。U03b は生成物と文書だけで処理系の経路を変えないので、G01 の前の最後の short とする。


## U03b: 生成参照と後続への引き渡し（2026-10-27）

B_WORK は `89c7a777c664bc0cd5b728019f0ce983bda4c0cf`。U03a の後の状態で `cargo run -p benitoite --example gen_skill` を実行し、文法・診断・標準ライブラリの生成参照と `src/cli/tools/skill/bundle.rs` が取り込み済みの内容と一致することを確認した。生成物は手で編集していない。作業末の指定検査と自己点検の結果は [U03b の結果](u03b/results.md)へ記録する。

`docs/reference/install.md` は変更しない。導入・更新・Skill の取得とインストール・ハーネスの検査報告から実行への手順は、この改造で変わっていない。追加された区間解析の説明は、既存のリンク先の英語リファレンスと、実行ファイルに同梱する Skill にある。derive の過去の移行節も現行の案内と区別して保つ。0.0.11 という現行の版表記と、0.0.12 の候補・移行案内の整合は Z01a/Z01b の担当であり、この枝で版上げを先取りしない。

U03b では処理系の経路・標準ソース・依存・生成器・Lean・検査入力を変えない。生成参照と bundle に差分がないこと、および最終差分が記録だけであることを確認して、上の「U03 の前の short」の判断を維持する。この枝では測定を追加しない。これは同じ測定を再実行した記録ではなく、取りまとめが済ませた判断へ処理系の変更を追加していないことの確認である。

U01〜U03 の全体レビューと受け入れは取りまとめへ引き渡す。この枝の自己点検・指定検査を、その全体レビューや G01 の change、Z01b の K2/release の完了とは扱わない。版を固定した新しい英語参照は `v0.0.12` を指し、中間コミットを指さない。Z01b は候補のタグに相当する英語リファレンスに `interval-analysis-coverage` と `local-interval-warnings` の見出しがあることを照合する。既存の必須欄と受け入れ規則を説明する `v0.0.11` の参照は維持する。

## G01: 改造全体の回帰（取りまとめ、2026-10-27）

HEAD `0b4979eb` で `scripts/check.sh --level change --base 706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8` を一度実行し、終了0（68分）。二つの構成の全ターゲット・stress・文書テスト・長いテスト・二構成の lint・Lean の既定のビルド・二つの lock の勧告の照合（検出0件）を含む。derive と比較の道具の自己検査も成功した。全体レビュー RV-G は条件付き受け入れ。詳細は [G01 の結果](g01/results.md)。

## Z01: 0.0.12 の候補（取りまとめ、2026-10-27）

Z01a で訳を同期し CHANGELOG を下書きし、Z01b で 0.0.12 へ上げて実 CLI・同梱物・配布を照合した。release（6db695e1）は終了0、K2（44a2c961）は1回目が固定の manifest の登録漏れで終了1、Z01K で直した2回目が終了0。二 lock の勧告は検出0件、Rust・Cargo・Lean・elan は対象外。詳細は [Z01 の結果](z01/results.md)と [security-advisories.md](security-advisories.md)。

## 訳の引き渡し

G01R の追加（2026-10-27）: `crates/benitoite/skill/references/idioms.md` 冒頭の検査方法のコメントに、`Explaining local interval warnings` の `text` のスクリプトをゴールデン入力と照合し、コード・一次位置・区間・文言を検査する例外を加えた。Z01a は `docs/ja/skill/references/idioms.md` の対応する説明へ反映する。例の本文と警告の説明の表は変えていない。既存の一覧・行番号は U03b 時点の記録として保ち、この追加は見出しと本文で照合する。

Z01a は、以下の英語を正として日本語訳を同期する。一覧の比較元は改造開始版 B0 `706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8`、比較先は U03b の B_WORK `89c7a777c664bc0cd5b728019f0ce983bda4c0cf` と再生成後の作業ツリーである。R04/R05/R06、S02b、A 群、U02b/U03a と取りまとめの訂正を含め、この改造全体の英語変更を対象にした。U03b 自身による英語の変更はない。

手書き文書の同期先は次のとおりである。生成参照には現在の `docs/ja/skill/` に対応する訳がないため、生成された英語の原文を照合対象として別表へ全て列挙する。同梱 Skill に日本語訳を追加せず、生成参照を訳のために手で直さない。`docs/reference/install.md` は B0 から変更がないため、段落の翻訳差分は0件である。候補の版表記や移行案内を Z01 で変えた場合は、その英語の変更も同期対象に追加する。

| 英語の文書 | 既存の日本語訳 |
|---|---|
| `docs/reference/benitoite.md` | `docs/ja/reference/benitoite.md` |
| `crates/benitoite/skill/SKILL.md` | `docs/ja/skill/SKILL.md` |
| `crates/benitoite/skill/references/idioms.md` | `docs/ja/skill/references/idioms.md` |
| `crates/benitoite/skill/references/inspection.md` | `docs/ja/skill/references/inspection.md` |
| `docs/reference/install.md`（今回の差分なし） | `docs/ja/reference/install.md` |

以下の各表は、変更を含む段落、箇条書きの項目、表、見出し、コード・出力のブロックを全て列挙したものである。行番号はこの引き渡し時の英語原文を指す。表とコードは、訳や例の対応が欠けないようブロック全体を対象とし、一部に既存の行を含む。各項目の原文全文・変更行・ファイルとブロックの SHA-256・比較範囲は [translation-inventory.json](u03b/translation-inventory.json)に保存した。英語を後で変えた場合は行番号だけに頼らず、見出しと原文・ハッシュを照合する。

新しい二語は `function summary` と `evaluation relation for the target fragment`（対象構文の評価関係）であり、区間解析・構文的な到達可能性の訳は現行の用語集に合わせる。`complete` と `coverage` を区別し、未知・未対応・超過や警告なしを安全の証明へ変えない。W0404 の対象はシフトの直接引数だけであり、操作と HTTP の欄は含めない。Log のテキストと JSON の例は説明だけでなくコードと期待出力も同期する。derive は generator `3.1.0-syntax-batch5`・inventory 3 の現行の段落を直し、過去の移行節の版を一括置換しない。R0906 の同時生存する取っ手100,000件の上限・呼び出し間の保持・drop による返却も漏らさない。

### 手書きの英語文書

#### `docs/reference/benitoite.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 217〜232 | 表 | `Inspection reports: \| Common field \| Meaning \|` |
| 234 | 段落 | `Inspection reports: Every target has targetId, requestIndex, entry, root, sourceId, kind, status, and complete, plus the addition…` |
| 263 | 見出し | `Interval analysis coverage: ### Interval analysis coverage` |
| 265 | 段落 | `Interval analysis coverage: The report and each target include an intervalAnalysis object with basis: "localIntervals". It describes how much of the …` |
| 267〜277 | 表 | `Interval analysis coverage: \| intervalAnalysis field \| Meaning \|` |
| 279 | 段落 | `Interval analysis coverage: All counts and usage values are nonnegative JSON integers. wholeBudgetSkipped does not count bodies that have not yet been …` |
| 281 | 段落 | `Interval analysis coverage: For one check, "all" means analysis started and left no unsupported or stopped range, pending input, or incomplete preparat…` |
| 283 | 段落 | `Interval analysis coverage: For test inspection, the overall coverage is "none" when every target is "none", "all" when every target is "all", an…` |
| 285 | 段落 | `Interval analysis coverage: Already collected analysis information remains available when --deny-warnings rejects a check. A whole-check budget can pre…` |
| 1152 | 見出し | `File and JSON log sinks: #### File and JSON log sinks` |
| 1154 | 段落 | `File and JSON log sinks: Open the Writer once and capture it in the sink. Log.formatRecord is pure: it keeps the default text format and escaping, b…` |
| 1156 | 段落 | `File and JSON log sinks: Both examples construct a fixed Location so their output is reproducible. For the actual call site, pass SourceLocation.he…` |
| 1158〜1181 | コード・出力 | `File and JSON log sinks: benitoite / import Benitoite.Unofficial.IO.Console` |
| 1182〜1185 | コード・出力 | `File and JSON log sinks: output / level=INFO source="app/Main.bnt:12:3" message="first\n\"quoted\"" attr."tag"="common" attr."tag"="event"` |
| 1187 | 段落 | `File and JSON log sinks: Keep the sink and all its calls inside the Writer's with block; using the captured Writer after release is a runtime error.…` |
| 1189 | 段落 | `File and JSON log sinks: The readback happens after release so the checked output includes both writes. File.Read and Console.Write are needed only fo…` |
| 1191 | 段落 | `File and JSON log sinks: For JSON lines, define an application format with a pure conversion function. Keep attributes as an array of {key, value} o…` |
| 1193〜1260 | コード・出力 | `File and JSON log sinks: benitoite / import Benitoite.Unofficial.IO.Console` |
| 1261〜1264 | コード・出力 | `File and JSON log sinks: output / {"attributes":[{"key":"tag","value":"common"},{"key":"tag","value":"event"},{"key":"n","value":42}],"level":"info…` |
| 1266 | 段落 | `File and JSON log sinks: The message's newline and quotes are escaped within one JSON line. The same lifetime, failure, and effect rules as the text s…` |
| 1780 | 段落 | `18. Diagnostics: Width-specific integer helpers also report W0401 for a constant zero divisor, even with an unknown dividend, and W0402 for co…` |
| 1782 | 見出し | `Local interval warnings: ### Local interval warnings` |
| 1784 | 段落 | `Local interval warnings: Local interval analysis tracks inclusive integer bounds through bind, shadow, comparisons with constants, if, short-cir…` |
| 1786〜1790 | 表 | `Local interval warnings: \| Code \| Condition found by local analysis \|` |
| 1792 | 段落 | `Local interval warnings: W0404 applies to direct calls to the standard shiftLeft and shiftRight functions on all integer types, including Byte/…` |
| 1794 | 段落 | `Local interval warnings: These warnings describe failure only **if execution reaches the operation or call and every operand or argument evaluates suc…` |
| 1796 | 段落 | `Local interval warnings: The analysis does not track correlations between variables or propagate intervals between functions. General multiplication a…` |
| 1798 | 段落 | `Local interval warnings: Each body has limits of 100,000 analysis operations and 100,000 simultaneously held items; one check has limits of 1,000,000 …` |
| 1800 | 段落 | `Local interval warnings: The formal guarantee concerns normal-value membership and conditional failure at warning locations in an **evaluation relatio…` |
| 1894 | 段落 | `IO and network behavior: Local interval analysis treats Http.text, Http.html, and Http.json as ordinary functions with unknown results. It does …` |
| 1896〜1907 | コード・出力 | `IO and network behavior: benitoite check / import Benitoite.Unofficial.Network.Http` |
| 1909 | 段落 | `IO and network behavior: This example constructs values only; it sends no response. The default Http.respond implementation still checks the status …` |
| 2349〜2359 | 段落 | `JSON record conversion: JSON and Property generation refuse target modules with file-level uses,` |
| 2402 | 段落 | `Record generators and shrinkers: Custom fields.gen/fields.shrink remain paired, fully qualified pure monomorphic zero-argument functions replacing an entire f…` |
| 2421 | 段落 | `Range: Local interval analysis uses a **function summary** for direct standard Range.checkInteger and Range.value calls. With fi…` |

#### `crates/benitoite/skill/SKILL.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 37 | 項目 | `Workflow for a script: 3. Read the diagnostics on standard error and fix the script. A diagnostic gives a code such as E0230; when its meaning is …` |
| 59 | 段落 | `Before running: The harness must read intervalAnalysis on inspection reports and targets separately from complete. Its basis: "localInte…` |
| 61 | 段落 | `Before running: Unknown values, unsupported forms, and exhausted analysis budgets do not by themselves require a code change or a larger use…` |
| 65 | 項目 | `Before running: 1. Accept an inspection only after checking the complete single JSON object, a known schemaVersion and kind, status: "ok…` |
| 174 | 段落 | `Checked values and local builders: For an already-open file sink, capture the Writer inside its with block and pass Log.formatRecord(record: record) to Fil…` |
| 228〜282 | 段落 | `Reference documents: For pure property trials, import Benitoite.Unofficial.Test.Property and call` |

#### `crates/benitoite/skill/references/idioms.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 35 | 項目 | `Contents: - [Explaining local interval warnings](#explaining-local-interval-warnings)` |
| 37 | 項目 | `Contents: - [File and JSON log sinks](#file-and-json-log-sinks)` |
| 502 | 段落 | `HTTP: Http.text, Http.html, and Http.json construct response values; local interval analysis treats their results as unknown …` |
| 504〜511 | コード・出力 | `HTTP: benitoite check / import Benitoite.Unofficial.Network.Http` |
| 513 | 段落 | `HTTP: The default Http.respond implementation still checks for status 200..599 at runtime. W0404 applies only to direct standard …` |
| 812 | 見出し | `Explaining local interval warnings: ## Explaining local interval warnings` |
| 814 | 段落 | `Explaining local interval warnings: For a local W0401, W0402, or W0404, read the primary location, inferred interval, allowed range when present, and the local-a…` |
| 816 | 段落 | `Explaining local interval warnings: The following complete script produces these three warnings during check, even though main calls none of the functions. I…` |
| 818〜846 | コード・出力 | `Explaining local interval warnings: text / function divide(value: Integer, divisor: Integer) -> Integer` |
| 848〜852 | 表 | `Explaining local interval warnings: \| Warning \| Explanation to give \|` |
| 854 | 段落 | `Explaining local interval warnings: W0404 recognizes direct standard integer and Byte shift calls, including import aliases of the same declaration. Calls throug…` |
| 856 | 段落 | `Explaining local interval warnings: Choose a correction from the intended behavior: for example, reject a zero divisor, validate an input before arithmetic, or c…` |
| 858 | 段落 | `Explaining local interval warnings: Absence of a warning does not prove success. An interval partly overlapping the allowed range, a divisor that may be either z…` |
| 860 | 見出し | `Range success values: ### Range success values` |
| 862 | 段落 | `Range success values: Use Range.checkInteger and match its Result when a value must satisfy inclusive bounds. The following helper saves the re…` |
| 864〜882 | コード・出力 | `Range success values: benitoite test / import Benitoite.Unofficial.Range` |
| 884 | 段落 | `Range success values: For direct standard Range.checkInteger/Range.value calls with fixed Integer bounds, a function summary can retain the bou…` |
| 969 | 見出し | `File and JSON log sinks: ## File and JSON log sinks` |
| 971 | 段落 | `File and JSON log sinks: Open the Writer once and capture it in the sink. Log.formatRecord is pure: it keeps the default text format and escaping, b…` |
| 973 | 段落 | `File and JSON log sinks: Both examples construct a fixed Location so their output is reproducible. For the actual call site, pass SourceLocation.he…` |
| 975〜998 | コード・出力 | `File and JSON log sinks: benitoite / import Benitoite.Unofficial.IO.Console` |
| 999〜1002 | コード・出力 | `File and JSON log sinks: output / level=INFO source="app/Main.bnt:12:3" message="first\n\"quoted\"" attr."tag"="common" attr."tag"="event"` |
| 1004 | 段落 | `File and JSON log sinks: Keep the sink and all its calls inside the Writer's with block; using the captured Writer after release is a runtime error.…` |
| 1006 | 段落 | `File and JSON log sinks: The readback happens after release so the checked output includes both writes. File.Read and Console.Write are needed only fo…` |
| 1008 | 段落 | `File and JSON log sinks: For JSON lines, define an application format with a pure conversion function. Keep attributes as an array of {key, value} o…` |
| 1010〜1077 | コード・出力 | `File and JSON log sinks: benitoite / import Benitoite.Unofficial.IO.Console` |
| 1078〜1081 | コード・出力 | `File and JSON log sinks: output / {"attributes":[{"key":"tag","value":"common"},{"key":"tag","value":"event"},{"key":"n","value":42}],"level":"info…` |
| 1083 | 段落 | `File and JSON log sinks: The message's newline and quotes are escaped within one JSON line. The same lifetime, failure, and effect rules as the text s…` |

#### `crates/benitoite/skill/references/inspection.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 3 | 段落 | `Inspecting before execution: The harness uses inspection reports to explain declared effects to the user before execution. While editing, use ordinary be…` |
| 27〜38 | 表 | `Inspecting before execution: \| Field \| Meaning \|` |
| 44 | 段落 | `Inspecting before execution: File-level uses is merged with the individual declaration in the checked Scheme. After accepting the whole report under the…` |
| 94 | 見出し | `Local interval analysis: ## Local interval analysis` |
| 96 | 段落 | `Local interval analysis: The report and each target carry an additional intervalAnalysis object with basis: "localIntervals". It describes the ran…` |
| 98 | 段落 | `Local interval analysis: Do not require coverage: "all" to accept an otherwise successful inspection, or use all to accept a failed one. Explain a…` |
| 100〜109 | 表 | `Local interval analysis: \| Field in intervalAnalysis \| Meaning \|` |
| 111 | 段落 | `Local interval analysis: Counts and usage are nonnegative JSON integers. Entry/control stops without a body output appear in phaseStops, not in bod…` |
| 113 | 段落 | `Local interval analysis: some includes body and phase stops, remaining original inputs, unprepared entries, unfinished discovery or queues, and disc…` |
| 115 | 段落 | `Local interval analysis: For main, the report summary equals the target summary. For doc tests, each target combines its ordinary entry with all gener…` |
| 117 | 段落 | `Local interval analysis: --deny-warnings preserves the analysis summary even when promoted warnings make inspection fail. Adding unrelated definitio…` |
| 119 | 段落 | `Local interval analysis: For the processor's definition of these additional fields and their aggregation, use the [v0.0.12 English reference](https://…` |

### 生成された英語参照

#### `crates/benitoite/skill/references/diagnostics.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 2693 | 項目 | `W0401: - inferred_range: the inferred divisor interval is {interval}` |
| 2694 | 項目 | `W0401: - local_analysis: this local analysis applies only if execution reaches this operation and all operands are evaluated succe…` |
| 2695 | 項目 | `W0401: - origin: this binding or comparison contributes to the inferred interval` |
| 2697 | 段落 | `W0401: Constant evaluation or local interval analysis shows that the divisor is always zero. If execution reaches this operation and…` |
| 2704 | 項目 | `W0402: - inferred_range: the inferred result interval before the range check is {interval}` |
| 2705 | 項目 | `W0402: - allowed_range: the range of {ty} is {range}` |
| 2706 | 項目 | `W0402: - local_analysis: this local analysis applies only if execution reaches this operation and all operands are evaluated succe…` |
| 2707 | 項目 | `W0402: - origin: this binding or comparison contributes to the inferred interval` |
| 2709 | 段落 | `W0402: Constant evaluation or local interval analysis shows that the result does not fit the type. If execution reaches this operati…` |
| 2720 | 見出し | `W0404: ## W0404` |
| 2722 | 項目 | `W0404: - Kind: check (warning)` |
| 2723 | 項目 | `W0404: - Message: argument {parameter} to {function} is always out of range` |
| 2724 | 項目 | `W0404: - Label: always out of range` |
| 2725 | 項目 | `W0404: - inferred_range: the inferred interval is {interval}` |
| 2726 | 項目 | `W0404: - allowed_range: the allowed range is {range}` |
| 2727 | 項目 | `W0404: - local_analysis: this local analysis applies only if execution reaches this call and all arguments are evaluated successfu…` |
| 2728 | 項目 | `W0404: - origin: this binding or comparison contributes to the inferred interval` |
| 2730 | 段落 | `W0404: Local interval analysis shows that the argument is always out of range. If execution reaches this call and all arguments are …` |
| 2894 | 項目 | `R0906: - component_handles: the external function {function} exceeded the limit of {limit} component handles` |
| 2896 | 段落 | `R0906: Each Store limits core instances, memories, and tables to 16 each, each guest table to 10,000 elements, and simultaneously li…` |

#### `crates/benitoite/skill/references/stdlib/Byte.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 9〜11 | 段落 | `Benitoite.Byte: For direct calls to this module's shift functions, local interval analysis reports W0404 only when the entire inferred interv…` |

#### `crates/benitoite/skill/references/stdlib/Integer.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 9〜11 | 段落 | `Benitoite.Integer: For direct calls to this module's shift functions, local interval analysis reports W0404 only when the entire inferred interv…` |
| 13〜14 | 段落 | `Benitoite.Integer: W0404 applies only to direct arguments of standard shift functions, including the fixed-width and Byte modules and their alia…` |

#### `crates/benitoite/skill/references/stdlib/Integer16.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 9〜11 | 段落 | `Benitoite.Integer16: For direct calls to this module's shift functions, local interval analysis reports W0404 only when the entire inferred interv…` |

#### `crates/benitoite/skill/references/stdlib/Integer32.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 9〜11 | 段落 | `Benitoite.Integer32: For direct calls to this module's shift functions, local interval analysis reports W0404 only when the entire inferred interv…` |

#### `crates/benitoite/skill/references/stdlib/Integer64.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 9〜11 | 段落 | `Benitoite.Integer64: For direct calls to this module's shift functions, local interval analysis reports W0404 only when the entire inferred interv…` |

#### `crates/benitoite/skill/references/stdlib/Integer8.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 9〜11 | 段落 | `Benitoite.Integer8: For direct calls to this module's shift functions, local interval analysis reports W0404 only when the entire inferred interv…` |

#### `crates/benitoite/skill/references/stdlib/Log.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 103〜105 | コード・出力 | `Benitoite.Log: benitoite / public function formatRecord(record: Record) -> String` |
| 107〜114 | 段落 | `Benitoite.Log: Formats any record, including Debug, in the default text format without emitting it.` |
| 116〜122 | コード・出力 | `Benitoite.Log: benitoite test / @test` |
| 124〜126 | コード・出力 | `Benitoite.Log: benitoite / public function withAttributes[T, effect E](attributes: List[Attribute], body: function() -> T uses Log, E) ->…` |

#### `crates/benitoite/skill/references/stdlib/Range.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 9〜10 | 段落 | `Benitoite.Range: Local interval analysis recognizes direct calls to the standard checkInteger and value functions, including import aliases. W…` |

#### `crates/benitoite/skill/references/stdlib/UnsignedInteger.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 9〜11 | 段落 | `Benitoite.UnsignedInteger: For direct calls to this module's shift functions, local interval analysis reports W0404 only when the entire inferred interv…` |

#### `crates/benitoite/skill/references/stdlib/UnsignedInteger16.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 9〜11 | 段落 | `Benitoite.UnsignedInteger16: For direct calls to this module's shift functions, local interval analysis reports W0404 only when the entire inferred interv…` |

#### `crates/benitoite/skill/references/stdlib/UnsignedInteger32.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 9〜11 | 段落 | `Benitoite.UnsignedInteger32: For direct calls to this module's shift functions, local interval analysis reports W0404 only when the entire inferred interv…` |

#### `crates/benitoite/skill/references/stdlib/UnsignedInteger64.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 9〜11 | 段落 | `Benitoite.UnsignedInteger64: For direct calls to this module's shift functions, local interval analysis reports W0404 only when the entire inferred interv…` |

#### `crates/benitoite/skill/references/stdlib/UnsignedInteger8.md`

| 英語原文の行 | 種類 | 見出し・段落の冒頭（原文照合用） |
|---|---|---|
| 9〜11 | 段落 | `Benitoite.UnsignedInteger8: For direct calls to this module's shift functions, local interval analysis reports W0404 only when the entire inferred interv…` |

### 引き渡しの件数と未変更の文書

変更のある英語文書は18ファイル（手書き4、生成14）、上の一覧は118項目である。空行を除く全ての追加・置換行が少なくとも一つの項目に含まれることを照合した。削除・置換前の範囲は比較元のコミットと inventory の changes から追える。削除だけで後継のない段落はない。

`references/grammar.md`、`references/stdlib/index.md` と表にない標準参照、手書きの `common-mistakes.md`・`language-comparison.md`、`docs/reference/benitoite-minimal.md`、`docs/reference/install.md` は B0 から差分がない。生成器は grammar・diagnostics・stdlib 全体を再生成しており、再生成の対象と翻訳差分の対象を混同しない。Z01a で訳を準備し、Z01b で版上げ後の参照版・実行ファイルから抽出した Skill・生成物・同梱物と照合する。

### U03R による訳の引き渡しの補完（2026-10-27）

U03b の上記18ファイル・118項目の一覧は、その時点の記録として保つ。U02b の英語リファレンスの変更は、Inspection reports（表と Target の文）、Interval analysis coverage（節全体）、Local interval warnings（節全体）、IO and network behavior（HTTP の説明・check 例）、Range（function summary の段落）、Diagnostics（幅付き整数の段落）まで既に含まれている。RV-U 軽7(2) の不足の有無をこの一覧と U03b の原文記録で照合し、欠落がないことを確認した。

Z01a は、その一覧に以下の U03R の更新を重ねて訳す。U03R の比較元は `56af9133e2a354770ac8d0dcd1c41a685cd02966`、比較先は本作業ツリーである。現在の原文・行番号・ファイルとブロックの SHA-256 は [U03R の追加一覧](u03r/translation-inventory.json)に保存した。空行を除く英語の全追加・置換行が以下のブロックに含まれることを照合した。移動前の HTTP の段落と例は、移動先の小節と対応させる。

| 英語のファイル | 現在の行 | 見出し | 段落・ブロックの冒頭（原文照合用） |
|---|---:|---|---|
| `docs/reference/benitoite.md` | 267〜277 | Interval analysis coverage | `\| intervalAnalysis field \| Meaning \|` |
| `docs/reference/benitoite.md` | 281〜281 | Interval analysis coverage | `For one check, "all" means analysis started and left no unsupported or stopped range, invalid body, pending input, …` |
| `docs/reference/benitoite.md` | 1800〜1800 | Local interval warnings | `The formal guarantee concerns normal-value membership and conditional failure at warning locations in an **evaluati…` |
| `crates/benitoite/skill/references/idioms.md` | 571〜571 | HTTP | `For HTTP values and fields outside local interval analysis, see [HTTP values are not tracked](#http-values-are-not-…` |
| `crates/benitoite/skill/references/idioms.md` | 837〜841 | Explaining local interval warnings | `\| Warning \| Explanation to give \|` |
| `crates/benitoite/skill/references/idioms.md` | 875〜875 | HTTP values are not tracked | `### HTTP values are not tracked` |
| `crates/benitoite/skill/references/idioms.md` | 877〜877 | HTTP values are not tracked | `Http.text, Http.html, and Http.json construct response values; local interval analysis treats their results as unkn…` |
| `crates/benitoite/skill/references/idioms.md` | 879〜886 | HTTP values are not tracked | `benitoite check` |
| `crates/benitoite/skill/references/idioms.md` | 888〜888 | HTTP values are not tracked | `The default Http.respond implementation still checks for status 200..599 at runtime. W0404 applies only to direct s…` |
| `crates/benitoite/skill/references/inspection.md` | 100〜109 | Local interval analysis | `\| Field in intervalAnalysis \| Meaning \|` |

idioms.md の HTTP の節は従来の使い方から始め、末尾の一文から Explaining local interval warnings の HTTP values are not tracked 小節へ案内する。訳でもこの移動を反映し、旧位置に同じ例を残さない。W0404 の一次位置は引数名のラベルではなく引数の式 `n` とする。coverage は、本体なしが件数0の all、全本体無効が none、有効・無効の混在が some という三つの場合を区別する。英語リファレンスの比較の範囲と phaseStops の説明も同期する。

## 公開候補の short（取りまとめ、2026-10-27）

- 状態: before = B1 `ac992bde2cb34d1861de3eb2943e75443a108189`、after = `3ee601a55e2872fa6a8bed5920ddf7e7ba76950f`（0.0.12 の集約。木は最終の候補と同じ）。U03 の前の short の後の処理系の変更は、G01R の区間解析の診断（区間が取れない候補は W0401・W0402 を作らない）、Z01b の版の文字列と互換性の受理の表、コメントとテストだけである。設計者の指示（2026-10-27）で、公開候補で一度測った。コマンド: `python3 tools/bench/compare/run.py --tier short --state before=ac992bde… --state after=3ee601a5… --name syntax-batch6-z01`。
- 結果: 終了0。外側の時間 2分9秒（after のビルドを含む。before はキャッシュ）。九族の出力照合はすべて成功。目標は38点で達成、未達は0点（退行の警報なし）。56点は差が計時のぶれ以下などで判定不能（U03 の前は47点）。記録は `tools/bench/results/2026-10-27-3ee601a5-syntax-batch6-z01/`、ログは [z01/short.log](z01/short.log)。手元のパスは `<repo>`・`<home>` に伏せた。
- 判断: 退行の疑いなし。この記録を加えた後に履歴を集約し直し、タグを付け直した（記録は保管の後に足したが、同じ公開の準備の中で push の前に加えたものである）。

## 受け入れ（取りまとめ、2026-10-27）

設計者は 2026-10-27 に「問題なければ、push前まで遂行願います」と指示して外出した。取りまとめは、change（G01）・全体レビュー RV-G と G01R・release と K2（Z01）・勧告の再照合が済み、残る所見がないことを確かめて、委任の範囲でこの改造を受け入れる。docs/todo では TODO-280・281・282・284・285・286 を閉じ、TODO-022・206 は残りの論点に書き換え、後の課題を TODO-289〜295 として加えた。改造のディレクトリを `docs/archive/` へ移し、v0.0.11 の後の履歴を一つのコミットに集約してタグ v0.0.12 を付ける。push は設計者の指示を待つ。
