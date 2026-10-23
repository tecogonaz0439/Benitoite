# 作業 Z1 の結果

2026-10-24、Z1 実装担当。対象は 0.0.11 のソース候補の版・文書・移行案内と、候補に対する検査・手動照合である。候補は未リリースであり、委任は版上げと release の検査までである。

## 基準と範囲

- B_WORK と HEAD: `e0ed5eb2888349dbb0d251843627c527d7ffc0b0`。開始時のブランチは `mod011/Z1`、作業ツリーに差分はなかった。
- B0: `a9c4132e6451904698cf344db1794c4d03affcd6`。work は B_WORK、release は B0 を基準とした。
- private と private を指すリンク、docs/todo は読まず、更新していない。Git は状態・差分・HEAD・追跡対象の読み取りと、検査内部の読み取りに限った。add・commit・branch の変更・merge・stash・reset・checkout・タグ・push は行っていない。build_info の指定された既存テストは、一時 fixture 内で Git の状態を作る。
- 言語の規則、成功した型・エフェクトの意味、VM・ランタイム、Lean の定義・主定理・公理を変更していない。本番の変更は委任された版境界と移行診断の登録だけである。
- CHANGELOG は既存の版と同じ日付なしの見出し `0.0.11 (San Benito)` とし、本文で未リリースの候補と明示した。履歴の集約・タグの際に公開の状態へ直す必要がある。性能の増減は記していない。

## 変更した内容

Cargo の版を一度だけ 0.0.11 へ上げ、BREAKING_CHANGES に D37 の要約と修正案を加えた。0.0.10 以前には該当する案内を版順に出し、0.0.11 は案内不要、0.0.12 以降は E0907 とする。01-03 と 06-09 の版別案内もそろえ、01-02 の現役の成功例を更新した。

CHANGELOG・README・英語の現行リファレンスと導入手順を候補へ合わせた。Skill 本体と inspection の仕様リンクは v0.0.11 に固定し、英語の第5弾の変更を日本語へ反映した。最小実行版のリファレンスと過去の CHANGELOG 節、archive は変更していない。生成参照は gen_skill で再生成し、内容の差分がないことを確認する。

版境界を登録すると、現役の成功入力の旧版宣言も拒否される。そのため lib・CLI・文書例の補助・交換・ゴールデンの成功入力を 0.0.11 に更新し、E0907/E0908 の期待値を候補へそろえた。ハッシュ入力の変更に対応する三つの固定値は、入力のバイト列から独立に SHA-256 を求めた。固定ハッシュ、診断の数・順・位置、ignore、入力の大きさ、時間制限は緩めていない。

## 申し送りの全項目への対応

[集約の申し送り](../results.md#z1と取りまとめへの申し送り)と [A6R の表](../a6r/results.md#z1-への互換性変更と移行の申し送り)を合わせて照合する。

| 申し送りの項目 | Z1 での処理・引き渡す条件 |
|---|---|
| 全比較 K2 | 新しい `target/z1-k2/` で全体を実行し、六入口・独立入力・組み込み表・全定義・manifest と、候補の HEAD/未コミット差分を記録する。K1 は引用しない。結果は後掲する。 |
| 0.0.11 と移行診断 | Cargo の版、D37 の summary/help、CHANGELOG、01-03・06-09、英語・日本語の移行案内をそろえた。旧版・現版・未来版の境界は既存テストと実 CLI で確認する。 |
| derive inventory 2→3 | 必須の module.fileUses/importInsertLimit、現行 Rust/Python の組、旧 inventory の拒否を CHANGELOG に記した。 |
| derive 生成器 3.1.0 | 記録・manifest/receipt・意味ハッシュ算法の版3を維持し、旧生成器の記録や manifest を互換としないこと、元本文・ハッシュ検証付きの新 preview、確認済みハッシュで apply 後の check/test/derive check を案内した。設定1・Property.libraryVersion 2.0.0 も区別した。 |
| derive の import 挿入境界 | 既存 import の後、ファイルの uses の前へ置くこと、案内された import を入れた後に再 preview することを記した。管理領域やハッシュの手直しは案内しない。 |
| try-actions inventory/manifest 2 | 版欄のない旧 inventory と manifest1 は拒否されること、個別の uses と file_uses/effective_effects の区別、候補の再生成と再確認を記した。版欄だけを書き換えない。 |
| try-actions の新しい保留理由 | unknown_effective_contract と unmapped_contract_boundary、以前の候補も保留になりうること、null は空集合でないこと、共有宣言や保留理由の変更で適用しないことを記した。 |
| package の Log とファイルの宣言 | 裸の Log・Benitoite.Log、隠蔽、外部公開の直下の関数があるファイルの一度だけの追加、旧ソースの記録も変わりうることを記した。構文集計は型検査でなく、import の別名を正当化しない。実 CLI で update の追加・削除・unchanged を照合する。 |
| Skill の固定リンク・文書・同梱物 | Skill 本体と inspection を v0.0.11 へ更新し、日本語訳を同期した。コード例、抽出した本文と版・producer、生成参照、第三者表示、配布対象は後掲の照合を行う。 |
| 一時防御の解除 | 検査・実行、package、derive、整形器、try-actions、共通補助の unsupported_file_uses、E0262 の pending が残らないことを確認した。書式の成功と失敗を実 CLI でも照合する。package.bnt の禁止と契約不明の保留は維持する。 |
| 後の課題・任意項目 | RV-A36 軽9、RV-F13 L5、RV-II L2 は取りまとめへ渡す。RV-F13 L8 の並べ替え案は申し送りどおり省略した。docs/todo は操作せず、TODO-206 全体を完了とはしない。 |
| 受け入れ・公開操作 | この記録を取りまとめがレビューして受け入れを判断する。履歴の集約・タグ・タグ後のアーカイブ・push・改造文書の保管は実施しない。集約後に commit 依存のビルド情報と Skill producer の再照合が必要である。 |

## テストの作成時の関門

既存の版境界テストの表へ 0.0.10/0.0.11/0.0.12 の行と新しい独立した期待文を加え、過去版に新しい変更を先取りして出さない対照も維持した。守る契約は、入口・根の設定・依存のいずれでも旧版の移行案内を落とさず、現版を通し、未来版を拒否することである。BREAKING_CHANGES の登録漏れや順序の逆転、上限なしの案内があれば既存の表が失敗する。新しいテスト関数や本番 API・フラグ・差し込み口は追加していない。

版に依存する成功 fixture は、その目的である公開の読み込み・CLI・ハッシュ・交換の境界へ到達するために宣言だけを更新した。ハッシュの固定値は旧値を消して検査を弱めず、更新後のバイト列に対する独立した期待値へ変えた。実装本体を写すテストは追加していない。Rust は計64行追加・45行削除であり、そのうち本番は変更表の5行と文言定数の3行の追加だけである。残りは既存テストの版・期待値の追随で、テスト関数の増減はない。内訳は [rust-change-counts.json](rust-change-counts.json) にある。

## 検査と結果

各検査は同じ基準・指定の dry-run で選択と理由を確認してから実行した。通常の work と失敗後の続行の正確な引数は [plan.md](../plan.md#z1-の検査の続行2026-10-24) と各 JSON に保存した。外側の時間は Python の time.monotonic による子プロセスの開始から終了までである。

| コマンド・実行 | 終了状態・結果 | 外側の時間 | 永続の実行記録 |
|---|---|---|---|
| `cargo run -p benitoite --example gen_skill` | 0、再生成成功。生成参照と bundle.rs の内容差分なし | 19.440秒 | [gen-skill.json](gen-skill.json) |
| work Z1、初回 | 1。lib の共通の成功 fixture が旧版宣言のため3件失敗。E0908 の追加を確認した | 131.671秒 | [work.json](work.json) |
| 同じ work、fixture の版・固定ハッシュ更新後 | 1。lib 1,271件、CLI 32件、脱糖交換30件は成功。golden のハッシュ不一致例に旧計算値が残った | 183.055秒 | [work-final.json](work-final.json) |
| 未完了部分の続行、golden 期待値更新後 | 1。golden 2件は成功。package_command の設定を含む固定ハッシュに旧値が残った | 63.558秒 | [work-remaining.json](work-remaining.json) |
| package_command 期待値更新後の続行 | 0。古くなった fmt/lint、関連統合と未実行の規約・生成物・仕様集計・依存ライセンスが成功 | 34.851秒 | [work-finish.json](work-finish.json) |
| `cargo test -p benitoite --test build_info -- --ignored` | 0、5件成功 | 21.420秒 | [build-info-ignored.json](build-info-ignored.json) |
| `scripts/check.sh --level release --base a9c4132e6451904698cf344db1794c4d03affcd6 --dry-run` | 0、release_stack だけを自動選択。手動照合が別途必要なことを確認 | 0.025秒 | [release-dry.json](release-dry.json) |
| 同じ指定の release 本実行 | 0、最適化ビルドの深い再帰10件成功・失敗0件。実行器も成功10件を確認 | 81.402秒 | [release.json](release.json) |
| `cargo build --release -p benitoite` | 0、通常構成の候補をビルド | 26.826秒 | [release-build.json](release-build.json) |
| 実 CLI の照合（51呼び出し＋同梱物の追加確認2呼び出し） | 全呼び出しの出力・終了状態が期待どおり。詳細は後掲。追加確認で両ライセンスを含む73ファイルの本文が一致 | 0.604秒＋追加0.205秒 | [manual-cli.json](manual-cli.json)、[全コマンドの表](manual-cli-table.md) |
| `scripts/release/licenses.sh aarch64-apple-darwin target/z1-work/THIRD_PARTY_LICENSES` | 0、host は rustc -vV の aarch64-apple-darwin に固定 | 3.979秒 | [licenses.json](licenses.json) |
| `cargo build --release -p benitoite --features bundled-licenses` | 0、上記の生成物をクレートの licenses/ へ置いてビルド | 27.399秒 | [bundled-build.json](bundled-build.json) |
| bundled 構成の `target/release/benitoite --licenses` | 0、自身のライセンスと見出しの後の113,432バイトが生成物と一致 | 0.022秒 | [bundled-licenses.json](bundled-licenses.json) |
| 通常構成へ戻した後の `cargo build --release -p benitoite` と版/ライセンスの再確認 | 0、候補の実行ファイル SHA-256・版・通常構成の表示が先の実 CLI と一致 | ビルド0.292秒、問い合わせの外側は未計時（1秒未満） | [release-restore.json](release-restore.json)、[candidate-final.json](candidate-final.json) |
| 読み取り専用 Python の文書・対訳確認 | 相対リンク・見出し・フェンス・末尾空白・対訳のコードブロックを照合、誤りなし | 最新値は JSON 参照 | [document-check.json](document-check.json) |
| `git diff --check` | 0、空白の誤りなし | 外側は未計時、ツール呼び出し1秒未満 | 本書 |

work に割り当てた全対象は、失敗したものと古くなったものだけをやり直して成功をそろえた。成功済みの lib の後の変更は、golden の診断期待値と package_command の固定ハッシュだけであり、lib のソース・入力・構成は変わらない。golden の成功後は package_command の固定ハッシュだけを変更したため、golden も再実行していない。いずれも新しい本番の動作修正ではない。最終の入力状態は後掲の HEAD・差分一覧・SHA-256 に保存し、同じ状態の入力を K2 でも用いる。

| work の単位・対象 | 最終の成功結果 |
|---|---|
| fmt・lint_default | 整形確認と、既定の gc-mark-sweep 構成の lib/tests の clippy が成功 |
| lib_default | 1,271件成功、既存の ignored 21件 |
| build_info の通常対象 | 対象0件・既存の ignored 5件。別の上記コマンドで5件とも実行済み |
| 関連統合 | cli_process 32件、desugar_export 30件、golden 2件、package_command 16件、reference_examples 1件、skill_docs 8件、skill_examples 3件、spec_examples 7件、stdlib_doc_examples 1件、test_command 52件、計152件成功。脱糖の既存 ignored 1件は K2 が担当 |
| source_rules | placeholder の allow と unsafe の許可範囲の二検査が成功 |
| skill_generated | 再生成後も生成参照・bundle.rs に内容差分なし。skill_docs も本文を独立に再生成して照合した |
| spec_tally | 自己検査と集計成功。初回リリースの受け入れ条件の未記入0件 |
| licenses | 依存ライセンスの検査成功 |

失敗の詳細は上表に残した。固定ハッシュは、lib 共通 fixture が `103c40ca…`、hash-match/hash-mismatch の同じ依存が `33de0b1b…`、package_command が `765d2da3…` である。最初の値は OS の shasum でも独立に確認し、[hash-fixture.json](hash-fixture.json) に記した。Python の値から既存の旧入力のハッシュが再現することも確認した。テストの期待する振る舞いや入力の大きさを緩めてはいない。

CLI の初回照合も51呼び出しすべて成功したが、実行メタデータと観察記録の保存名が重なり、詳細記録を上書きした。保存先を分けて同じ照合を再実行し、完全な出力を残した。ライセンスの最初の比較は自身のライセンスと見出しを含む全出力を本文だけと比べて失敗したため、正式な接頭辞と本文の和として照合し直した。どちらも確認用の記録・比較の修正であり、処理系の修正はしていない。

## 実候補の CLI・同梱物・配布の照合

[全53コマンドの表](manual-cli-table.md)に、実際の引数・出力の要点・終了状態・判定を残した。完全な出力は [manual-cli-observations.json](manual-cli-observations.json)、候補の構成と実行ファイルの SHA-256 は [manual-summary.json](manual-summary.json) にある。

| 照合した契約・操作 | 出力の要点・判定 |
|---|---|
| `--version`・`--version=json` | テキストは厳密に二行。0.0.11、Character/表示の幅とも Unicode 17.0.0。JSON の既存形式版を保つ |
| ビルドと producer | commit は B_WORK の完全ID、target=aarch64-apple-darwin、commit 由来 git、dirty は null・由来 notCollected。作業ツリーには本書に記した差分があり、null を変更なしと扱わない。検査報告・Skill の producer も候補と一致 |
| 書式12例の check/run | 十進、二進、八進、大小の十六進、Decimal の2桁、String/Character、符号、ゼロ埋め、中央揃え、幅だけの指定が成功。例の `2.675m:.2f` は2.68、`-42:#08x` は-0x0002a |
| 失敗の JSON | 空書式 E0262、型不適合 E0468、終了2。単一報告は checkError・complete=false・aggregateEffects=null。失敗を成功した空集合としない |
| ファイル単位の uses | 空の Log の操作も含め、報告の上限は Console.Write/Log。両方を許すと実行成功。Log を許さなければ E0512・終了2でファイルの宣言の副位置を示す |
| language 境界 | 0.0.9 は0.0.10と0.0.11の順の案内、0.0.10 は新案内、0.0.11 は成功、0.0.12 は E0907。package.bnt の uses は E0912 で拒否 |
| fmt | 新書式を保ってコロンの前の空白を除き、fmt --check が成功。再整形と同一 |
| Skill list/show/install | 正式な CLI で一時プロジェクトへ抽出。版0.0.11、producer、本文を照合し、全ファイルが元の本文の版置換後と一致。両ライセンスを含む全73ファイルの一致は [skill-complete-check.json](skill-complete-check.json) に記した。確認用の Skill は同じ CLI で削除した |
| package add/update | ファイルの Log を記録。旧空記録へ +Log、Log→State の +State/-Log、個別 Benitoite.Log への +Log/-State、次回 unchanged を確認 |
| 英語と日本語 | 言語リファレンス100、導入手順11、Skill4、inspection2、idioms57、common-mistakes56、language-comparison5ブロックのコードが一致。Skill の訳だけは説明用の前付けの text ブロックを除いて比較した |
| 生成参照と仕様リンク | gen_skill の内容差分なし。Skill 本体・inspection の CLI 仕様リンクは v0.0.11 に固定。リンク先タグの公開は後の操作であり、候補をリリース済みとは表示していない |
| 第三者表示 | rustc の host に対して再生成し、unicode-width 0.2.2 と著作者表示を含む。bundled 構成は接頭辞と生成本文に完全一致。本文 SHA-256 は `7ee565ad75d2a3040e54f9b3dbede205662911723e81f4057916179ba5957752` |
| 通常構成との区別 | 通常のソースビルドは自身のライセンスと第三者一覧を含まない旨を表示。bundled 確認後は、保存した通常構成の実行ファイルを SHA-256 照合して target/release/benitoite へ戻した。bundled の実行ファイルは別名で一時保存した |
| ソース配布の対象・除外 | 追跡対象8,471件を読み取り、Cargo・ツールチェーン・両ライセンス・Skill/生成参照・文書・ライセンス生成道具が含まれることを確認。.git/private/docs/todo/target/reference/dist が含まれない。候補の未追跡の結果記録は取りまとめが取り込む必要がある。正式なタグのアーカイブは作っていない。詳細は [distribution-check.json](distribution-check.json) |

## K2 の最終の関係状態

K2 は次の指定で最後の関係状態に対して全体を一度実行し、終了0で完了した。外側の時間は1,012.736秒（約16分53秒）である。新しい出力先を使い、K1 の結果を引用していない。

```sh
BENITOITE_DESUGAR_DIFF_DIR=target/z1-k2/desugar \
BENITOITE_COVERAGE_DIFF_DIR=target/z1-k2/coverage \
scripts/check-formal.sh
```

コマンド・終了状態・時間・ログの SHA-256 は [k2.json](k2.json)、全体と各入口の件数・各入力/manifest/報告の SHA-256 は [k2-summary.json](k2-summary.json)、通過した段の記録は [k2-stages.log](k2-stages.log) に保存した。一時的な target のログだけを成功の根拠にしない。

| K2 の対象 | 入力・成功件数 | 不一致・対象外・照合 |
|---|---|---|
| 既定の Lean と実行器 | sorry なしの既定 lake build と六実行器のビルド成功 | 主定理・公理の変更なし |
| 全件の入力 | golden790＋random1,000＝1,790入力、73,840定義 | 1,371入力を比較し、既存の検査エラー419入力を除外。入力の識別・除外理由・scope・網羅性の件数は routing manifest と一致 |
| 脱糖 | golden1,062・random72,778定義一致 | 定義の不一致0・対象外0 |
| 組み込み表 | 1,371入力、要約比較141,998件一致 | 不一致0、収束しない入力0、prim/構成子の欠落0、errors は空 |
| 全定義の表層検査 | 51,729件一致 | 不一致0・準備失敗0、既存の対象外19件・Q11分類1件を維持。理由も manifest と一致 |
| プログラム内の網羅性 | match16,443＋束縛6,039＝22,482件一致 | 不一致0・対象外0・燃料切れ0 |
| 独立した網羅性 | 通常10,020件・view付き10,028件一致 | 不一致0・燃料切れ0、独立入力の全件を実行 |
| 第5弾の六入口 | 局所32定義（書式28・ファイル uses2・個別 uses2）すべて対象内。全14頭を実表で確認 | corpus14、builtins/stdlib6。書式付き補間28箇所、String3箇所、Stringの脱落0。ファイル/個別の契約と E2 atoms が一致 |
| 独立交換・入力別の全比較 | 幅、名前付き、extensible、try、第2〜5弾を実行。入力別の表層検査も1,790入力を走査 | 六入口と exchange/routing manifest が一致。契約3・穴/パイプ6・名前付き6の変異は意図した理由で拒否。外部パッケージの view と定数宣言も一致 |

K2 の HEAD は B_WORK と同じ完全IDであり、[input-state.json](input-state.json) に作業ツリーの差分一覧、各変更入力の SHA-256、未コミットのバイナリ差分の SHA-256、ツールチェーン、構成を保存した。未追跡の K2 入力はない。関係する4,449ファイルの名前と内容ハッシュをまとめた SHA-256 は `7da0ff460e10379663510d4908e02d8d010831c529a1b10c016d98796de1c866`、`git diff --binary HEAD -- <関係するパス>` の SHA-256 は `8ca62ce9b1d5fdd34bbd70e6f9615b3d09b6c3144b6e195e7c637efa9203948c` である。関係パスと実際の diff 引数は JSON に列挙した。

K2 後の [input-state-final.json](input-state-final.json) は、HEAD・差分・変更入力・未追跡入力・全入力の内容ハッシュが K2 前と同じであることを確認した。候補と同じ処理系、標準ソース、生成参照、テスト入力、Lean、check-formal の道具で走らせている。K2 開始後に編集したのは改造の結果と照合表・記録だけであり、K2 の入力は変えていない。このため文書の記録を確定した後に K2 を重ねる必要はないと、Z1実装担当Codexが2026-10-24に判断した。ソースからの通常構成への再ビルドも入力の内容を変えない。

環境は aarch64-apple-darwin、Rust/Cargo1.98.1、Lean4.34.1、Python3.9.6である。完全な版表示は input-state.json に残した。長い検査は進行と出力を監視し、K2 は生成済み random の件数と入力別比較の件数も確認した。割り当てた検査に環境による未実施はなく、見込みの2倍を超えた検査もなかった。

## 計画との差と取りまとめへの引き渡し

work Z1 の行と「Z1 の検査の続行」の節の書き換えは、取りまとめが 2026-10-24 に承認（RV-Z1 の L5）。

long_only は、Z1 で変えたテストのファイルに ignored のテストがなく、変更は構成に依らない版の宣言と期待値なので再実行しない。build_info の ignored 5件は別に実行済みである。

版境界に伴う成功入力の更新により、work Z1 に golden・spec_examples・test_command・desugar_export を追加した。01-02 の成功例と、同じ版別案内を持つ01-03も06-09とそろえた。ハッシュを含む fixture の更新漏れは初回の失敗として残し、同じ作業の中で修正・検査を終えた。処理系の本体の動作修正、言語の規則の変更、Lean の主な定理の前提・結論や公理の変更を必要とする停止事項はなかった。

Z1 に割り当てられた実装・翻訳・検査・手動照合に未完了のものはない。取りまとめは本書と集約をレビューし、委任範囲の受け入れを判断する。候補の公開は行っていない。

| 後の手順 | 担当・条件 | 見込み時間 |
|---|---|---|
| 差分・申し送り全項目・検査証拠の独立レビューと受け入れ | 取りまとめ | 20〜40分（計画の仮予算） |
| docs/todo の今回の範囲と後の課題の処理、改造文書の保管 | 取りまとめ、受け入れ後 | 不明 |
| 履歴の集約、CHANGELOG/README等の候補表示の更新、タグとビルド情報・Skill producer の再照合、タグ後のアーカイブ・push | 設計者の指示を待つ。Z1 は実施しない | 不明 |


最終の同じ指定の work dry-run は終了0（0.138秒）であり、続行で成功をそろえた八単位と同じ選択・コマンドであった（[work-candidate-dry.json](work-candidate-dry.json)）。結果文書のリンク・アンカー・フェンス・末尾空白、JSON の読み取り、Git 差分の空白、許されていない編集範囲と記録内の手元の絶対パスがないことも確認した。文書確認の補助記録に一度絶対パスが入ったため、相対パスで作り直して全記録を再確認した。処理系と K2 の入力は変更していない。
