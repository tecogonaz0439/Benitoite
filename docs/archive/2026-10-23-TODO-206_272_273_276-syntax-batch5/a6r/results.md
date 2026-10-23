# A6R の結果

2026-10-23、A6R 実装担当。[RV-A36](../reviews/RV-A36.md) の中1〜3、軽1〜8・10を対象とした。plan.md に A6R の節はないため、依頼文による読み替えに従い、A3〜A6 の節・検査と A2R の結果を参照した。

## 基準と操作の範囲

- B_WORK と HEAD: `a573772a59ba2c98f954587852f918d9d586654c`。
- ブランチ: `mod011/A6R`。開始時の差分はなかった。
- git は状態・差分・HEAD の読み取りと check.sh 内部の読み取りだけに使用した。add・commit・branch の変更・merge・stash・reset・checkout 等の変更操作は行っていない。
- private とそれを指すリンクは読まず、docs/todo・過去の文書・レビュー本文は編集していない。言語の規則、Lean の定義・主定理・公理、ヒープの不変条件・安全点での保持は変更していない。

## 各指摘への対応

| 指摘 | 対応 |
|---|---|
| 中1 | 01-02 と 02-03 の未接続入口の拒否を、完成した各入口の記述へ改めた。元の AST を読む package・整形器・inventory と、合併済み契約を読む型検査の利用側を区別し、`package.bnt` の禁止を保った。 |
| 中2 | 公開契約の参照にファイル由来の印を保持した。ファイル由来の E0329 は `handle` を案内せず、宣言から効果を外すか公開関数を別ファイルへ移す案内と、直下の公開関数すべてに加わる注記を付ける。最も広い公開範囲の代表一つによる件数・編集の制御は維持した。既存の六対照に案内・注記の照合を加え、編集後の再検査も成功した。02-10 と生成診断参照も更新した。 |
| 中3 | 英語リファレンスの Program structure に一回だけのファイル単位の `uses` を記した。10章に File-level effect declarations の小節を設け、ログの小節の冒頭にあった二段落を移した。Inspection reports と Effect limits before execution から参照を加えた。 |
| 軽1 | Skill の Before running の重複段落を手順1へ統合し、個別の `uses` とファイル単位の `uses` の両方と比較するようにした。v0.0.11 へのリンクの固定し直しは依頼どおり実施せず、下記の Z1 への申し送りへ記した。 |
| 軽2 | W0501 の置換が空で本体の効果が残る場合は、ファイルの宣言の有無によらず `covered` の案内を使う。既存の編集・再検査の表に、個別の `uses IO.All, Console.Write` だけで賄う行を加えた。 |
| 軽3 | 下記に D37 の三項目、新しい保留理由、旧 inventory の拒否、および D36 の防御を外した入口の一覧を集約した。try-actions README にも保留理由を明記した。BREAKING_CHANGES と版別の移行案内そのものは Z1 の担当とする。 |
| 軽4 | 既存の test_command のテストへ、doc の例自身の先頭に `uses Log` を置く対照を加えた。例一件・成功報告・`docExamples[0].effects.expanded == ["Log"]` と集約の同じ上限を確認した。既存実装で成功したため、06-04 の規則と実装は変えていない。 |
| 軽5 | `--helper` に版欄なし・版1の JSON を返す実行スクリプトを指定する自己検査を一件加えた。両方とも `unsupported inventory version` で終了1となり、manifest を出力せず、入力を書き換えない。既存実装で成功した。本番の関数やプロセス呼び出しは差し替えていない。 |
| 軽6 | 現行の設計書にある「共通宣言」「ファイル宣言」を「ファイルの宣言」へそろえた。用語集の語は変えず、新しい略記は登録していない。07-04 の変更も対応表のこの表記だけである。 |
| 軽7 | 06-03 の段落を「字下げ」の基本規則の後へ、02-05 の段落を警告の既存一覧の後へ、06-01 の二段落をそれぞれ上限の照合・検査報告の基本の決定の後へ移した。既存見出しは改名していない。 |
| 軽8 | 理由付きで現状を維持する。既存の公開 API だけで表示用の文字列を解析せずに正規名を得る入口はなく、代替案は下記の理由で採らなかった。本作業では公開 API を追加・拡大していない。 |
| 軽9 | 依頼どおり修正しない。Property の生成先にファイルの宣言がある場合の preview での拒否は、取りまとめが docs/todo へ登録する。 |
| 軽10 | 06-09 と英語リファレンスへ、型検査を行わない集計なので、検査では拒否するエフェクトの import の別名も構文どおりに数えることを追記した。集計の規則は変えていない。 |

### 軽8の現状維持の理由

`TyNames` は型表示の名前の表であり、エフェクト一つの正規名を返す公開メソッドを持たない。既存の `Ty::show` は関数型全体の表示で、IO の全効果を `IO.All` にまとめ、効果変数の NoFail の条件も表示する。inventory の原子的な名前の配列をここから作るには、表示用の書式を解析するか、各効果だけの仮の関数型を作って表示を切り出す必要がある。これは表示の変更と道具のプロトコルを結び付けるため採らない。

`BuiltinEffectId::def` の公開情報から名前を組み立てる案は、Log と IO・Network の名前の規則を example に複製する。検査報告の `cli::inspection::effect_name` は非公開であり、これを公開する案でも公開 API が増える。このため、型表示・検査報告・inventory が同じ正規名の変換を使う現状を維持する。03-01 の構成と外部に作用する関数の規則も確認した。本関数は言語の組み込みの追加や外部操作の入口ではない。`IO.All` を許可名として受理する判断には使わず、検査報告の層が引き続き拒否する。

## Z1 への互換性変更と移行の申し送り

| 対象 | 0.0.11 で登録・案内する内容 | 移行時に行うこと |
|---|---|---|
| derive inventory | 版2から3へ変更。module の `fileUses` と `importInsertLimit` が必須。`preambleEnd` の意味は維持。 | 旧 inventory は拒否される。現行の Rust helper と Python を組にして使用する。 |
| derive 生成器・記録 | 生成器は `3.0.0-syntax-batch4` から `3.1.0-syntax-batch5` へ変更。生成記録・manifest/receipt の版3、意味ハッシュの算法版3は維持するが、旧生成器の記録の check と旧 manifest の apply は互換としない。 | 元の本文・ハッシュの照合を経た新しい preview で再確認し、確認済み manifest ハッシュで apply、check、必要なら再適用を行う。記録や管理領域のハッシュを手で変更しない。 |
| derive の挿入境界 | import は既存 import の後、ファイル単位の `uses` の前に限る。既存管理領域を使っても境界を越える生成を拒否する。 | 新しい import が必要な場合、案内された import を宣言の前へ置いて再 preview する。同梱例の更新は A5 済み。 |
| try-actions inventory・manifest | 版欄のない旧 inventory から必須の `version: 2` へ変更。manifest は1から2へ変更。owner の `uses` は個別の原文のまま、`file_uses` と `effective_effects` を必須にする。 | 旧 inventory と旧 manifest を拒否する。現行 helper で候補を作り直して再確認する。旧 manifest の版番号だけを書き換えて適用しない。 |
| try-actions の新しい保留理由 | `unknown_effective_contract`: owner またはその上限が取得できない。型検査済みでも、例として文脈の効果変数を持つラムダなどは `effective_effects: null` となり得る。`unmapped_contract_boundary`: ファイルの宣言の範囲を元ホストの範囲へ対応付けられない。 | 以前は適用候補になった断片が保留となる場合がある。null を空集合にせず、共通の宣言を一関数用に編集しない。保留理由や分類だけを書き換えて適用しない。 |
| package の Log とファイルの宣言の記録 | 裸の `Log` と `Benitoite.Log` を個別・ファイルの両リストで識別する。外部公開の直下の関数があるファイルの追加分だけを一度加える。ファイル単位の宣言がない既存ソースでも Log の記録が変わり得る。 | `package update` の追加・削除と記録をハーネスで確認する。ソースを確認した後に language 宣言と依存ハッシュを更新する。型検査なしの構文集計であり、エフェクトの import の別名を許す意味ではない。 |
| Skill の固定リンク（軽1） | `crates/benitoite/skill/SKILL.md` の手順1と `references/inspection.md` の CLI 仕様リンクは v0.0.10 のままである。 | Z1 で両方を v0.0.11 へ固定し直す。日本語訳の更新も Z1 が行う。 |

D37 の BREAKING_CHANGES の summary/help には、上表の derive の版・再確認、try-actions の版・旧記録の再生成、package の Log の記録の変化を含める。移行の案内には保留理由の追加も含める。CHANGELOG とリリース文書へ性能の増減を書かない。

### D36 の一時防御の確認

| 入口・補助 | 現在の状態 |
|---|---|
| 検査・実行（modules/load.rs、A2） | 元の宣言を保持し、名前解決・宣言収集で合併する。一時的な未接続の拒否はない。`package.bnt` の禁止は言語の規則として残す。 |
| package（A4） | 元の AST を集計する。未対応の拒否はない。 |
| derive inventory（A5） | 版3のファイルの宣言・挿入上限と合併済み Scheme を出す。未対応の拒否はない。 |
| 整形器（A6） | `Module.file_uses` を import 群の後で走査する。未対応の拒否はない。 |
| try-actions inventory（A6） | 元の個別契約・ファイルの宣言・有効契約を版2で分ける。未対応の拒否はない。契約不明の保留は完成後の適用条件である。 |
| 共通の補助・診断表（A6） | `syntax/header.rs` の `unsupported_file_uses` と診断の `pending` 注記は削除済み。src と examples の検索でもこれらの一時防御は見つからない。 |

## テストの作成時の関門

test-audit を読み、追加・変更の前に次の四点を確認した。新しい本番 API・フラグ・ラッパー・注入用引数は追加していない。

| 対象 | 観察可能な契約と現実的な退行 | 既存の検査との差・境界 |
|---|---|---|
| E0329 | ファイル由来では handle を案内せず、ファイルの宣言の意味を示す。由来を落として通常の効果と同じ案内へ戻せば失敗する。 | 既存の六対照は件数・編集・修正後の成功だけを見ていた。同じ pipeline::check_text のテストを強めた。修正前に handle の案内で失敗した。 |
| W0501 | 実効果が残る削除案内は残りの宣言で賄えると述べ、編集後も検査できる。ファイルの宣言の有無で案内が変わる退行を捕まえる。 | 既存の型検査境界の表へ個別宣言だけの一行を加え、両行の文言を照合した。修正前に「効果なし」という文言で失敗した。 |
| doc の例自身の uses | 独立した仮想モジュールの先頭宣言が、実際の報告に Log の上限として現れる。包み方の変更で宣言が遅いと判定されれば失敗する。 | 既存テストは外側から継承しない場合だけだった。同じ test CLI の報告で、非 null の例一件と独立した期待値を確認する。既存実装が成功したため修正は不要。 |
| 旧 inventory | 実行した helper の旧出力を拒否し、空の候補として成功させない。版の確認を削除すれば成功扱いとなり失敗する。 | 実 helper は常に版2なので既存の実行では通らない分岐であった。既存の CLI の --helper から小さなプロセスを起動し、拒否理由・出力なし・入力不変を確認する。内部の関数を置き換えていない。 |

Rust の新しいテスト関数は追加せず、既存の三テストを強めた。Python の自己検査は一件追加し、版欄なし・版1の二対照を含む。テストの削除、ignore・期待値・入力の大きさ・時間制限の緩和はない。本番 Rust は22行追加・9行削除、Rust と Python のテストは70行追加・11行削除である。

## 実行と結果

以下の Cargo・check.sh・Python は `rtk proxy /usr/bin/time -p` 経由で実行した。時間は外側の real である。

| コマンド・確認 | 終了状態・結果 | 外側の時間 |
|---|---|---|
| `cargo test -p benitoite --test declarations file_uses_visibility_reports_once_and_repairs_all_public_functions -- --exact`（修正前） | 101。handle を付けない条件で失敗し、指摘を再現した。 | 3.87秒 |
| 同じ E0329 の局所検査（修正後） | 0。一件成功、六対照を確認した。 | 4.01秒 |
| `cargo test -p benitoite --lib io_all_warnings_preserve_shared_file_contracts -- --exact` | 0だが対象0件。lib の完全なテスト名を指定していなかったためであり、検証の成功には数えない。 | 5.07秒 |
| `cargo test -p benitoite --lib io_all_warnings_preserve_shared_file_contracts`（修正前） | 101。個別宣言だけの対照で「効果なし」の文言となって失敗した。 | 8.96秒 |
| 同じ W0501 の局所検査（修正後） | 0。一件成功。二つの削除編集の適用後の再検査も成功した。 | 8.61秒 |
| `cargo test -p benitoite --test test_command file_effects_reach_test_contracts_but_not_outer_doc_examples -- --exact` | 0。一件成功。doc の例自身の `uses Log` の報告を確認した。 | 8.55秒 |
| `python3 -B tools/try-actions-migrate/test_migrate.py TryMigrationTests.test_old_inventory_response_is_rejected` | 0。一件成功、版欄なし・版1の二対照を確認した。 | 0.49秒 |
| `cargo fmt --all` | 0。変更した Rust を整形した。 | 2.19秒 |
| `cargo run -p benitoite --example gen_skill` | 0。生成物の差分は E0329 の追加注記・案内の二行だけであり、文法・標準署名の差分はない。 | 2.69秒 |
| 下記 work の指定に `--dry-run` を追加 | 0。指定した関連統合テストと、自動選択の10単位を確認した。 | 0.08秒 |
| 下記 work の本実行（一回） | 0。選択した全検査が成功した。件数は下表を参照。作業末の失敗・再実行はない。 | 216.56秒 |
| `python3 -B -` による変更文書13件の相対リンク・フェンス・末尾空白、新小節の見出しと参照、現行設計書の用語の読み取り専用確認 | 0。相対リンク546件を確認した。外部リンクの到達性は検査せず、新しい小節へのアンカーを照合した。 | 0.34秒 |
| `python3 -B -` による本結果記録の指摘13件・Z1への申し送り・リンク・フェンス・末尾空白の読み取り専用確認 | 0。記録の検査であり、Rust の検査入力を変更していない。 | 0.02秒 |
| `git diff --check`（work 後） | 0。空白の誤りなし。 | 0.02秒 |
| 結果記録の作成後、同じ指定の最終 dry-run | 0。差分は23ファイルとなり、実行済み work と検査の単位・コマンドは一致した。 | 0.07秒 |

work の指定は次のとおりである。A3 の関連対象と A6 の対象を合わせ、診断変更の回帰を確認する golden を加えた。変更のない derive の自己検査や property_library、段・改造全体・公開候補の検査は先取りしていない。

```sh
scripts/check.sh --level work \
  --base a573772a59ba2c98f954587852f918d9d586654c \
  --test declarations --test checked_args --test test_command \
  --test cli_process --test reference_examples --test skill_docs \
  --test skill_examples --test golden --test fmt_command
```

| work の検査 | 結果 |
|---|---|
| fmt・lint_default | 整形の確認と、lib・tests の clippy（`--no-default-features --features gc-mark-sweep`）が成功。 |
| lib_default | 1,262件成功・0件失敗・既存の ignore 21件。 |
| tests_related | checked_args 10件、cli_process 32件、declarations 18件、fmt_command 20件、golden 2件、reference_examples 1件、skill_docs 8件、skill_examples 3件、test_command 52件、計146件成功。 |
| source_rules | placeholder の allow と unsafe の許可範囲の二検査が成功。 |
| skill_generated | 再生成と生成物が一致。標準署名の変更なし。 |
| spec_tally・spec_examples | 集計の自己検査・集計と仕様例7件が成功。未記入の初回リリースの受け入れ条件は0件。 |
| python_syntax・migrate_selftests | Python の構文確認、source-migrate 6件、try-actions 10件と実 helper のビルドが成功。 |

実行ログは一時的に `/private/tmp/benitoite-a6r-work.log` へ保存した。本書の完了根拠は本書に記したコマンド・終了状態・外側の時間・件数であり、一時ログの存続を前提にしない。過去の作業の検査結果を引用して、この作業の検査に代えてはいない。

## 計画との差と後続の担当

- A6R の専用 work 行はないため、依頼どおり実際の変更から関連対象を名指しした。軽6の表記の統一に伴い、07-04 の対応表の一箇所も修正した。形式化の意味と入力は変更していないため、check-formal・Lean のビルド・heap の特殊検査の追加条件は発生していない。
- 軽8は上記の理由による現状維持、軽9は依頼による対象外、軽1の版リンク・日本語訳・D37の登録は Z1 の担当である。言語の規則や Lean の主定理について設計者の判断を要する停止事項はない。
- 取り込み後の short の測定、独立レビュー、段 S-A の接続検査、受け入れ、コミットと取り込みは取りまとめの担当とする。本結果をそれらの完了とは扱わない。
