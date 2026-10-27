# A21b の結果

着手: 2026-10-26 15:20:51 JST（最初の時刻記録）。終了: 2026-10-26 15:41:52 JST。所要時間: 21分01秒（最初の時刻記録から）。

B_WORK・HEAD は `c52acdd1bd1da5a15b2d56e771629c11e7e45f20`、ブランチは `mod012/A21b`。着手時の差分はなかった。

状態: A21b の実装、CLI の局所検査、指定 work と失敗修正後の必要単位の再検査、自己点検を完了した。担当範囲に未完・不合格は残っていない。独立レビューと受け入れは取りまとめへ引き渡す。

## 実装した範囲

plan.md「計画の変更（2026-10-26、L25R・L25S を受けて）」の A21b の行と、依頼の補足を優先した。共通依頼文、前提と依存、受け渡す契約、作業群 A21、D4 の変更・D19 と追記・D20、A19a/A19b/A21a の申し送りと取りまとめのレビュー、RV-C4-response.md、README の設計者の決定と preflight を確認した。rtk・test-audit・japanese-tech-writing を適用した。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/typeck/interval/diagnostics.rs` | A19b の標準 call の候補を受け、元の call と契約位置の引数の一次位置を照合する。OutsideDomain の正常区間と契約の正常域が不交差の場合だけ W0404 を組み立てる |
| `crates/benitoite/tests/cli_process.rs` | 実 CLI の表形式の検査、子のあふれとの統合、ハンドラで処理する Process.exit の三件を追加した |
| `crates/benitoite/testdata/stdlib/width-bits-s8-invalid.diag.json`・`width-bits-u64-invalid.diag.json` | 域外シフトの W0404 を各一件追加した。既存の R0701 の行はそのまま保った |

解決済みの標準宣言・型・元キーの認定は、A19b の候補生成が担う。診断側では同じ元 call の出現であることと、契約位置の引数の span を確かめる。診断用の関数名は契約の標準名から `Benitoite.` を除き、import の別名にも標準の宣言名を表示する。推定区間と正常域を閉区間で示し、local_analysis の注記と由来の補助位置を既存の DiagBuilder と renderer へ渡す。修正案は付けない。

既存の候補の採用順、旧定数警告の優先、元 NodeId・原因・一次位置による重複除去、最大8件の由来の順序をそのまま使う。正常区間がない候補と正常域との交差を診断へ広げず、候補の正常域も契約と照合する。操作・HTTP の status/timeout の候補は追加していない。

Rust の既存の型・シグネチャ、言語の規則、Lean の定義・定理・公理、予算の固定表、割り当て量テストの入力・期待値・上限は変更していない。診断の表・文法・標準ソースなど生成元に変更がないため、別途の T-G は不要である。指定 work の skill_generated が生成器を実行して照合する。設計書と生成 Skill の文書の整理は A21c へ渡す。

## テストの作成時の関門と CLI の確認

本物の解決・型検査・解析・診断・renderer を通す実 CLI の三件を加えた。本番の差し込み口や公開範囲は増やしていない。既存の A19 のテストは内部候補を検査するため、W0404 の発行漏れ、表示位置・補助位置・注記・JSON・strict の退行には届かない。既存の算術 CLI 検査は固定域の入力を含まない。操作の差し替えは実行までを境界にする必要がある。これらを追加の理由とした。

- 表形式の12入力を text/JSON × 通常/strict の48通りで検査する。Integer の primName、Integer64 の funName と import の別名、Byte の primName、負の全域外、比較による絞り込み、10段の別名のうち新しい8位置だけの選択、入れ子の独立入力の診断一件を確かめる。域内・交差・Top・未到達・return する子は診断なしとする。一次位置の offset とソース断片、補助位置の選択とラベル、主文、全注記、helps の空、strict の重大度・終了状態も独立した期待値で照合する。
- 子のあふれの三入力で、先行・後続の対象外引数の Bottom と対象引数の Bottom に W0404 を重ねず、旧定数警告と統合後の W0402 一件だけを出す。
- RV-C4-response.md の Process.exit(300) のスクリプトを text/JSON × check/run の四通りで実行する。全て `--deny-warnings` を付け、check が診断なし・終了0、run が `handled 300` を出して終了0となる。

追加前のコードでは、最初の Integer.shiftLeft の CLI 検査が「期待一件に対して診断0件」で失敗した（[詳細](cli-before-detail.log)）。接続後は表形式の検査が成功した。最初の [cli-before.log](cli-before.log) は rtk の要約だけで理由が残らなかったため、生出力を保存する `rtk proxy` で詳細を取り直した。

途中で試した定数展開の例は、シフト呼び出し自体が既存の E0433 で断られた（[記録](cli-domain-final.log)）。定数の規則は変えず、その例を除いた。定数中のシフトの重複を検査済みとはしない。入れ子の独立入力は一件だけを出すことを表形式の入力で確認し、既存の定数・算術の重複の検査は全統合で実行する。既存テストの削除、上限・期待値・入力規模の緩和、ignore の変更はない。

[保存したシフトの入力](shift-cli.bnt)を実 CLI で check した [JSON](shift-json.log) と [text](shift-text.log) は、Integer・Integer64・Byte の域外の三件だけを含む。後半の域内・交差・Top には警告がない。[ハンドラの入力](handled-exit.bnt)も保存し、[check](handler-check.log) は診断なし・終了0、[run](handler-run.log) は `handled 300`・終了0だった。これらの小さい入力は出力を直接確認するための保存資料であり、テスト用の別の実行器は設けていない。

## 検査と結果

実行場所は `<repo>`。固定版 Rust 1.98.1 と、書き込み可能な既存の `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。[実行器](run.py)が手元のパスを伏せ、コマンド・終了状態・外側時間を同名の JSON に保存した。

| 検査 | 結果・外側時間 | 記録 |
|---|---|---|
| W0404 接続前の退行確認（詳細） | 期待した失敗、終了101、1.031秒 | [出力](cli-before-detail.log)・[JSON](cli-before-detail.json) |
| 接続後の初回 CLI | 一件成功、終了0、10.791秒 | [出力](cli-after.log)・[JSON](cli-after.json) |
| ハンドラの check/run | 一件成功、終了0、1.236秒 | [出力](handled-exit.log)・[JSON](handled-exit.json) |
| 子のあふれを追加、定数の例を試した局所検査 | 一件成功・一件失敗、終了101、4.102秒。上記 E0433 | [出力](cli-domain-final.log)・[JSON](cli-domain-final.json) |
| 定数の例を除いた局所 CLI | 二件成功、終了0、5.106秒 | [出力](cli-domain-corrected.log)・[JSON](cli-domain-corrected.json) |
| 警告のゴールデン | 二テスト成功、終了0、0.525秒。警告9例・コアIR6例・フォーマッタ8例 | [出力](golden-warnings.log)・[JSON](golden-warnings.json) |
| 指定 work の dry-run | 終了0、0.086秒。七単位を確認した | [出力](work-dry-run.log)・[JSON](work-dry-run.json) |

局所ゴールデンの初回は、フィルタをカンマで列挙したため対象0件で終了101となった（[記録](golden-local.log)）。単一の `warnings` の指定へ直して、上記9例の成功を確認した。対象0件を検査成功として数えていない。

作業末の指定は次のとおりである。`--test` を省き全統合とした。先に同じ指定の `--dry-run` を実行した。

```sh
scripts/check.sh --level work --base c52acdd1bd1da5a15b2d56e771629c11e7e45f20
```

[work-check.py](work-check.py) から一度呼び、外側を `/usr/bin/time -l` で包んだ。検査本体の終了状態を [work-check.json](work-check.json)、外側を [work.json](work.json)、出力を [work.log](work.log) に記録した。

初回の指定 work は **検査本体1、224.085秒、外側224.115秒・終了1** だった。fmt・examples を含む clippy・lib 全件は成功した。全統合はゴールデンの二例で止まり、その後のソース規約・生成 Skill・仕様集計は未実行だった。二例は `Integer8.shiftRightUnsigned(a: 1s8, n: -1)` と `UnsignedInteger64.shiftLeft(a: 1u64, n: 64)` であり、新しい W0404 が既存の R0701 の前へ追加された点だけが期待値と異なった。依頼の補足に従い、各 JSON にその W0404 を一件追加した。実行時の診断の本文・位置・注記・trace・終了状態は変えていない。

併せて、新しいテストのコメント二行から作業 ID を除いた。Rust の実行するコードは初回 work から変わっていない。失敗した全統合と未実行の三単位、コメント変更後の fmt だけを同じ基準で再実行した。`--only` による部分選択では `tests_related` に `--test` が必須であるため、`--test '*'` を一引数として渡し、初回と同じ全統合を選んだ。lib 全件と clippy は繰り返していない。

```sh
scripts/check.sh --level work --base c52acdd1bd1da5a15b2d56e771629c11e7e45f20 \
  --only fmt,tests_related,source_rules,skill_generated,spec_tally --test '*'
```

先に同じ指定の [dry-run](work-final-dry-run.log) を実行し、同じ40統合ターゲットを起動するコマンドと五単位を確認した。[work-final-check.py](work-final-check.py) から呼び、今回も外側を `/usr/bin/time -l` で包んだ。検査本体は [work-final-check.json](work-final-check.json)、外側は [work-final.json](work-final.json)、出力は [work-final.log](work-final.log) に保存した。

再検査は **五単位成功、検査本体0、347.090秒。外側は347.122秒・終了1（計測の制限）** だった。初回の clippy・lib 全件の成功と合わせ、指定された七単位が全て成功した。lib は **1,332件成功・失敗0・既存 ignored 21件**、最終の全統合は **40ターゲット・391件成功・失敗0・既存 ignored 10件** である。[件数の詳細](work-counts.json)にターゲット別の数を保存した。`call_allocations` は512 MiB・256 MiBの上限を持つ二件を含む3件が成功した。本枝で割り当て量の追加の実測はしていない。

生成 Skill の照合で新たな差分はなく、仕様集計の初回リリース版の完了条件の未記入は none だった。ゴールデンの入力は805例で、既存の除外を保ち、VM と参照インタプリタの差分286例、check のコアIR66例、フォーマッタ651例が通った。新しいゴールデンの例は加えず、既存の二例の期待値だけを更新した。

**最大常駐量（maximum resident set size）はサンドボックスの制約で取得できなかった。** 初回・再検査とも time が `sysctl kern.clockrate: Operation not permitted` を報告して終了1となった。再検査の本体は終了0である。初回の real/user/sys は224.10 / 1069.37 / 61.60秒、再検査は347.11 / 900.91 / 13.86秒である。最大常駐量の未取得を0とせず、取得のための再実行もしていない。

## 最終点検と申し送り

[自己点検器](self-review.py)と[結果](self-review.json)で、検査中の入力ハッシュ、差分の四ファイルへの限定、Python の構文、記録のパスの伏せ方、`git diff --check`、40統合ターゲットの件数を確認した。初回の [入力ハッシュ](work-inputs-sha256.json)と最終の [入力ハッシュ](work-final-inputs-sha256.json)を分けた。初回以降の Rust の変更がテストのコメント二行だけであることは、それを戻した文字列のハッシュが初回と一致することで確認した。更新した二つのゴールデンの既存の R0701 の行は B_WORK とバイト単位で一致した。診断の本番コード、Lean の設定、予算の固定表、割り当て量のテストは初回の検査開始から変わっていない。

本番 Rust は40行追加・3行削除、Rust のテストは153行追加・削除0、ゴールデンの期待値は2行追加・削除0である。追加したテスト関数は三つであり、既存のテストは削除していない。最終の検査後の変更は本ディレクトリの結果記録と点検器・集計だけである。

範囲の変更はない。初回 work のゴールデンの不一致を本枝で直し、失敗・修正と再検査を上に記録した。言語規則・Rust の型やシグネチャ・Lean の主定理や公理の変更を要する停止条件には当たっていない。6時間の上限による中断もない。stage・change・release、check-formal.sh、Lean のビルド、性能測定は実施していない。本枝の検査を別の状態の結果の引用で省いていない。

A21c へは、シフトの直接引数だけに W0404 が出る接続済みの状態を渡す。02-05・02-10・03-06 と生成 Skill の文書の整理は A21c の範囲である。操作と HTTP の欄についての文書を広げる必要はない。実交換・Rust/Lean の全関係状態と実 VM の比較は計画の X 作業の範囲であり、本枝の CLI 検査をその代用とはしない。

private/ とそこを指すリンクは読まず、git の変更操作、コミット・取り込み・docs/todo の更新・保管・公開、担当の委任は行っていない。

| 残る手順 | 担当・時期 | 見込み |
|---|---|---|
| A21b の独立レビュー・受け入れと取り込み | 取りまとめ、本結果の引き渡し後 | 不明 |
| 診断の文書・生成 Skill の同期、work・レビュー | A21c と取りまとめ、A21b の受け入れ後 | 計画の1〜2時間、work 3〜10分。独立レビューは不明 |
| 案III の接続の stage・short の測定と区切りの受け入れ | 取りまとめ、A21c の後 | stage 3〜10分。測定と受け入れは不明 |

## 取りまとめのレビュー（2026-10-26）

受け入れる。既存のゴールデン二例（`width-bits-s8-invalid`・`width-bits-u64-invalid`）に加わった W0404 は、域外の定数のシフト量への警告で、注記の区間と許される範囲も正しい。ハンドラで処理した `Process.exit(300)` は check が警告なし、run が `handled 300` で終了0である。Lean・予算の固定表は変わらず、work は七単位とも成功した。最初の起動は Codex のモデルの混雑で着手前に終わり、取りまとめが再起動した（作業ツリーの変更はなかった）。A21c へ進む。
