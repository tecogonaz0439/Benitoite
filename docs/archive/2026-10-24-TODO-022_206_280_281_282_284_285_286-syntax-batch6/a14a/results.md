# A14a の結果

2026-10-25。基準 B_WORK は `58d2fcb5f7449db6011972947b665dda04033f80`、作業枝は `mod012/A14a`。開始時の HEAD は基準と一致し、未コミット差分・未追跡入力はなかった。plan.md「計画の変更（2026-10-25、RV-C2 を受けて）」の A14a を実装した。

## 変更

`interval::arithmetic` の型域を整数の種類で指定し、既存の Integer64 に加えて六幅の加減算と除数0、符号付き三幅の一般の負号、UnsignedInteger16/32 と符号付き三幅の定数倍を接続した。中間計算は i128 とし、対象型の値域との交差を正常値にする。一部だけが値域外なら候補を作らず、全域外だけをあふれ候補にする。一般の積と商・剰余の結果は対象型の Top を保つ。UnsignedInteger64 の乗算は従来の未対応の経路に残した。

`flow` は左右が同じ整数型の対象算術を親で直接解析し、`range_kind` から読んだ区間を同じ種類の正常値成分へ戻す。左・右・演算自身の順序、子の失敗可能性と return、正常値のない子の後続の skip を保つ。候補に整数の種類を保存し、診断の型名は既存の組み込み型の表示規則、許容範囲はその種類の上下限を使う。候補を保存する作業枠・Warning の確保・追加・返却の順序と回数は変更していない。

既存の幅別の型検査テストの表へ、正常区間・途中失敗・一般の積と商／剰余の Top、および診断の型名・型域・一次位置・補助位置の表を追加した。本物の型検査と入力収集を通し、期待値は数学上の端点と Lean の定義に合わせた。テスト専用の本番の引数・公開範囲・状態は追加していない。01-04・02-05 の対応する本文も、接続した範囲へ更新した。

## 途中の検査と修正

コマンドはリポジトリの根で実行した。出力を保存する検査は `rtk proxy` を通し、生の Cargo の出力を残した。途中検査の外側の時間は別途計測していないため、以下の時間は Cargo が表示したビルドとテストの時間である。

| コマンド（Cargo の引数） | 終了 | 時間・結果 | 記録 |
|---|---:|---|---|
| `cargo test -p benitoite --lib arithmetic_keeps_each_width_and_intermediate_failure -- --nocapture`（実装前） | 101 | Integer8 の加算の結果が `[-128,127]`、期待値が `[3,5]` で失敗。raw 出力での再実行はビルド0.06秒・テスト0.07秒 | [arithmetic-before.log](arithmetic-before.log) |
| 同じコマンド（接続後の初回） | 101 | ビルド14.10秒・テスト0.10秒。区間の期待値は一致したが mayFail の期待値で失敗 | [arithmetic-after.log](arithmetic-after.log) |
| 同じコマンド（期待値の照合後） | 0 | ビルド9.54秒・テスト0.60秒、1件成功 | [arithmetic-after-2.log](arithmetic-after-2.log) |
| `cargo test -p benitoite --lib arithmetic_warnings_keep_the_integer_kind_range_and_primary -- --nocapture` | 0 | ビルド11.36秒・テスト2.88秒、1件成功 | [diagnostics-local.log](diagnostics-local.log) |
| `cargo test -p benitoite --test call_allocations bounded -- --nocapture --test-threads=1` | 0 | ビルド9.50秒・テスト9.78秒、指定の2件成功 | [allocations-local.log](allocations-local.log) |
| `cargo test -p benitoite --lib budget_matches_lean -- --nocapture` | 0 | ビルド10.91秒・テスト2.59秒、本体表と全体／集計表の2テスト成功 | [budget-local.log](budget-local.log) |

最初の実装前の呼び出しは `rtk cargo test` であり、要約により失敗理由が保存されなかったため、同じ入力を `rtk proxy cargo test` で再実行した。以後の保存は raw 出力に統一した。

mayFail の期待値の失敗はテスト側の誤りだった。`BudgetAnalyze.expr` の `.local` は、型付き整数位置にも `baseIntegerKind width range true` を返すため、局所参照を含む表の期待値を true に直した。リテラルだけの安全な式は false のままである。本番の解析を Lean より精密にする変更や、mayFail を診断・受け入れに使う変更は行っていない。その後、右辺での途中失敗・最大値同士の定数倍・負の定数による部分的なあふれの行も追加し、最終の work の lib 全件へ含めた。

割り当て量は次のとおりで、上限・入力・期待値は変更していない。A13b の申し送りの値と二件とも一致した。

| テスト | 確保した総バイト数 | 元の上限 |
|---|---:|---:|
| `long_constant_chain_has_bounded_check_allocations` | 442,662,821 | 536,870,912（512 MiB 未満） |
| `repeated_constant_diagnostics_share_bounded_origin_work` | 254,897,076 | 268,435,456（256 MiB 未満） |

固定表三表・生成元・再生成器・README の7ファイルは、基準の内容とバイト単位で一致する。[fixed-input-sha256.json](fixed-input-sha256.json) にハッシュを保存した。表を作り直したり、幅付きの形を追加したりしていない。

## 作業末の work

実行前に `scripts/check.sh --level work --base 58d2fcb5f7449db6011972947b665dda04033f80 --dry-run` を行い、終了0で選択を確認した。選択は fmt、examples を含む lint_default、lib_default、全統合の tests_related、source_rules、skill_generated、spec_tally である。仕様の例の検査は全統合に含まれる。[work-dry-run.log](work-dry-run.log) に保存した。

同じ基準で `scripts/check.sh --level work --base 58d2fcb5f7449db6011972947b665dda04033f80` を一度実行し、`/usr/bin/time -l` で包んだ。初回は fmt・lint_default が成功し、lib_default が1件の失敗で終了1になった（1,305件成功・1件失敗・21件 ignored、lib は71.70秒）。検査本体の外側は84.110秒、time の real は84.13秒である。[work.log](work.log)・[work-result.json](work-result.json) に保存した。

失敗は、既存の算術表の `otherWidth`（`bind n <- 1s8 + 2s8` の後に `return 7`）が、新しく接続した幅付き加算を未対応とみなして mayFail を true と期待していたことによる。単独で再現し、実値 false・期待値 true の不一致を確認した。Lean の値域内のリテラルと `baseOwnKind` の加算、`addMayOverflow` の定義に合わせ、この行だけ false に直した。入力・候補数・正常区間は保ち、本番コードは変更していない。単独での修正前と修正後の記録は [old-case-before.log](old-case-before.log)（終了101、Cargo のビルド0.07秒・テスト0.07秒）と [old-case-after.log](old-case-after.log)（終了0、ビルド3.99秒・テスト0.09秒）に保存した。

再実行は、テスト修正により古くなった fmt・lint_default・lib_default と、初回に未実施だった全統合以降の単位を名指しした。指定は `scripts/check.sh --level work --base 58d2fcb5f7449db6011972947b665dda04033f80 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test '*'` である。元の自動選択と同じ七単位で、全統合を省いていない。同じ指定の dry-run は終了0で [work-after-dry-run.log](work-after-dry-run.log) に保存した。再実行は lib_default が成功し（1,306件成功・失敗0件・21件 ignored、71.58秒）、全統合の declarations の旧期待値の一行で終了1になった。検査本体の外側は130.007秒、time の real は130.03秒である。[work-after.log](work-after.log)・[work-after-result.json](work-after-result.json) に保存した。

全統合での失敗は `bind z <- 0s8; bind n <- 10s8 div z` に対して、既存の declarations の表が未対応だった頃の警告なしを期待していたことである。実際には今回の接続により W0401 が出るため、この行を W0401 一件と局所解析の注記ありへ更新した。入力と本番コードは変更していない。`cargo test -p benitoite --test declarations local_intervals_report_only_reached_arithmetic_failures -- --nocapture` は終了0（ビルド0.75秒・テスト4.00秒）で、[declarations-local.log](declarations-local.log) に保存した。

この修正は別の統合ターゲットだけなので、成功済み lib_default は繰り返さず、`scripts/check.sh --level work --base 58d2fcb5f7449db6011972947b665dda04033f80 --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally --test '*'` を最終の指定とした。成功済み lib の引用根拠は [lib-evidence.json](lib-evidence.json) に保存した。基準・HEAD の完全ID、未コミット差分と入力のハッシュ、コマンド・構成・固定版・件数・終了・時間・環境の制限・元ログ・以後の変更・判断者と日付を記録し、統合テストの変更後も lib の入力が全件一致することを確認した。未追跡の lib 入力はない。最終の指定も実行前に同じ指定の dry-run を行い、終了0で [work-final-dry-run.log](work-final-dry-run.log) に保存した。最終の検査本体は終了0、外側329.151秒、time の real は329.17秒だった。[work-final.log](work-final.log)・[work-final-result.json](work-final-result.json) に保存した。最終の六単位と、入力の一致を確認して引用する lib_default により、元の work の全七単位が成功した。

| 検査 | 最終の結果 |
|---|---|
| fmt | 成功 |
| lint_default | lib・tests・examples、`--no-default-features --features gc-mark-sweep` で成功 |
| lib_default | 1,306件成功・失敗0件・21件 ignored。上記の成功結果と入力一致の証拠を引用 |
| tests_related | 全40統合ターゲット、382件成功・失敗0件・10件 ignored。仕様・リファレンスの例、既存の割り当て量のテストも含む |
| source_rules | 仮置きの許可と unsafe の許可の検査が成功 |
| skill_generated | 生成器による照合に成功。生成物に差分なし |
| spec_tally | 仕様集計の自己検査と集計が成功 |

最大常駐量は最終の実行でも取得できなかった。検査本体は0だが、計時ラッパーは `sysctl kern.clockrate: Operation not permitted` により1で終了した。この環境の制限を検査の不合格や測定の成功とは扱わない。

最大常駐量は初回の `/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告し、サンドボックス内では取得できなかった。検査本体と計時の終了を別に記録し、最大常駐量を測定済みとは扱わない。

## 計画からのずれと申し送り

型付きの算術結果を診断までつなぐため、arithmetic.rs に加えて flow.rs・diagnostics.rs・domain.rs と既存の幅別テストを変更した。work で見つかった旧期待値の修正として interval/tests.rs と tests/declarations.rs の各一行も変更した。公開の型検査の署名、言語の規則、実行時検査、Lean の定義・中心二命題・主定理の前提・結論・公理は変更していない。VM 値・ヒープの不変条件・安全点を越える保持も変更していない。

UnsignedInteger64 の u128 による定数倍は A14b、六幅の比較の認定・絞り込み・短絡の条件環境・match と幅付きの固定表は A14c に残す。今回の幅別テストは Boolean の引数による分岐と既存の種類付きの合流を使い、未接続の六幅の比較から事実を得ていない。A15 は全幅の診断・文書・生成 Skill とその区切りの検査を担当する。既存の見出し名は、その参照をそろえて改名する U02 まで保持した。

Lean のビルド、Rust/Lean・VM の全比較、stage・change・release、heap/stress、性能比較は、本枝の割り当て外として実行していない。今回の固定表比較の成功を、全構文・任意深さ・全関係状態の比較の完了と扱わない。32ビット環境での実行・クロスビルドは未実施であり、言語の幅と中間計算へ usize を使っていない。

独立レビュー・受け入れ・コミット・取り込みと後続の検査は取りまとめの担当である。private/ とそれを指すスキルは読まず、git の変更操作は行っていない。


本番 Rust の差分は77行追加・37行削除、テスト Rust は269行追加・3行削除である。テスト関数の削除はなく、既存の幅別の表を使う二つのテストを追加し、既存の二表の各一行を Lean の接続後の期待値に合わせた。最終の検査を開始してから、本番 Rust・テスト・設計書・固定表を変更していない。以後の編集は本結果・証拠・ログだけである。最終の入力ハッシュは [final-inputs-sha256.json](final-inputs-sha256.json) に保存した。生ログ中の手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に置換した。

A14a が受け持つ未実施・不合格の検査と、言語規則や主要定理についての判断待ちは残っていない。独立レビューと受け入れは取りまとめへ引き渡す。

## 取りまとめのレビュー（2026-10-25）

六幅の加減算・除数0・符号付き三幅の一般の負号・定数倍（UnsignedInteger64 を除く）を接続し、候補に整数の種類を保存して診断の型名と許容範囲を正しく出す。直した既存の期待値は、Integer8 の `10s8 div z`（`z` は `0s8`）が六幅の接続で W0401 を出すようになったもので、Lean の定義と一致する。固定表は基準とバイト単位で一致する。受け入れる。
