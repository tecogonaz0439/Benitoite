# V1 の実装結果

基準 B は Z2 の取り込み `443e1faff532a66352986150d3f36e8e72be3319` である。今回の依頼に従い、版の更新・文書・訳・生成物の照合までを担当する。担当範囲と作業末の検査は decisions.md の R105 と plan.md の work V1 行に固定した。change・最終の check-formal・性能の本測定・release と実候補の CLI・配布の照合は、V1 取り込み後に取りまとめ担当が行う。これらの未実施を成功とせず、公開候補全体の受け入れ完了とはしない。

## 変更

- Cargo の自クレートの版と lock を 0.0.8 に更新した。別ワークスペースの fuzz/Cargo.lock に残っていた 0.0.1 も、根と共通の依存の版をそろえて更新した（R106）。言語版の照合は CARGO_PKG_VERSION を読む既存の方式を保ち、別の版の定数は作らない。通常の language 宣言、埋め込みの入力、現行設計と利用者向けの文書を更新した。
- 互換性の表へ Character の全域を覆った後の分岐の拒否を 0.0.8 として追加した。E0908 は既存の変更に続けて今回の変更と移行案内を示す。到達しない分岐の処置、E0601 の文字の反例の期待値、language 宣言と依存ハッシュの更新を案内する。
- 通常入力と負の入力を区別した。0.0.7 を旧版として拒否し、0.0.8 を受理し、0.0.9 を未来版として拒否する。過去の current=0.0.6/0.0.7 の表は残した。99.0.0 の未来版、不正な宣言、older-language の 0.0.4 は保持した。fmt/header の 0.0.6 は、互換性を検査せず綴りを保つフォーマッタの契約なので保持した。過去の CHANGELOG・archive・測定記録は書き換えていない。分類は version-inputs.json に残した。
- ハッシュの一致例と固定値を独立の Python hashlib で計算し直した。hash-mismatch は期待するゼロのハッシュを保持し、変更された実内容の computed だけを更新した。版の変更による診断本文と移行案内の追加を、ゴールデンの厳密な期待へ反映した。
- CHANGELOG に六項目の変更・制限・移行をまとめ、README と導入の手順を更新した。英語リファレンスの古い「レコード生成器は未提供」という記述と、Failure/Test.Property の一覧の不足を補い、それを正として日本語訳を更新した。同梱 SKILL.md の非公式モジュール一覧にも Failure を加えた。
- 日本語の言語リファレンスへ制約付き操作、型付き Fail、Character の全域、JSON Codec、Property とレコード生成の契約を反映した。手書き Skill 文書の訳も更新した。言語リファレンスの57ブロック、SKILL.md の4ブロック、idioms の45ブロックのコード・期待出力等は英語版と完全に一致する（translation-examples.json）。訳は同梱物に追加していない。
- gen_skill で再生成した結果、生成ファイルの差分はなかった。derive の config・型の構造・テンプレート・管理領域の本文は版の更新で変わらないため、規則の版と生成記録も保持する。同梱物・生成物・例の68ファイルの SHA-256 は generated-files.json に記した。

## テストの作成時の関門

1. 守る契約は、入口・根の設定・依存それぞれの言語版の受理と拒否、互換性の変更を示す順序・全文・位置・自動編集の不在、宣言した内容に対する依存ハッシュの一致と不一致である。
2. 交換から Z2 の相関の二関数を落とす、旧版を受理する、未来版を受理する、0.0.8 の移行案内を落とす、過去の版へ未来の案内を出す、通常入力の版か固定ハッシュを更新し忘れる退行で失敗する。
3. 新しいスイートは追加せず、公開の読み込み境界と既存の互換性の表に 0.0.8/0.0.9 の行・案内を追加する。CLI の golden は位置と終了状態まで確認する既存のものを使う。ハッシュの固定期待は本番の package_hash から作らず、独立の hashlib で求めた。
4. 公開範囲の拡大、テスト用のフラグや差し込み口は追加していない。assert の削除、期待値の緩和、ignore の追加はない。0.0.7 の受理から拒否への変更は、今回の互換性の境界そのものである。期待する診断の本文・案内の件数・固定ハッシュの変更は、この意味の変更と入力の版の変更による。

## 検査

コマンド、終了状態、外側の時間は各 JSON、出力は同名の .log に保存した。外側の時間は Python の time.monotonic でプロセスの起動から終了まで測る。

途中は `cargo test -p benitoite --lib modules::` だけを局所検査として実行し、39件成功、終了0（37.245秒）だった。gen_skill による生成は終了0（18.599秒）。文書のリンク検査の初回は、コード内のテンプレート `[...](...)` をリンクとして拾ったため一件を報告した。検査対象を本文のリンクへ直し、コード内の表記を除いて再確認した。文書のリンク自体の修正は不要だった。

作業末の work は次の指定を一度だけ実行した。自動 dry-run と固定した指定の dry-run はともに終了0であり、spec_examples・reference_examples・skill_docs は全統合に含まれるため独立に重ねない。clippy は依頼の all-targets に置き換える。根の Cargo.lock は自クレートの版だけの変更であり、根の依存とライセンスの入力は変わらないため licenses は省く。

```sh
scripts/check.sh --level work --base 443e1faff532a66352986150d3f36e8e72be3319 --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs --test '*'
```

work は終了1（124.692秒）で tests_related の途中に停止した。fmt、lib 全件1209件（既存21件ignore）、先行する build_info・call_allocations・cli_process・coverage_export・declarations は成功した。desugar_export の export_batch2_character が、Z2 の入力の定義4件に対して古い2件を期待して失敗した。期待を正確な4件へ更新し、classify・correlatedBoolean・correlatedCharacter・main の名前と順も照合するよう補った（R107）。これは Z2 の追加関数を含めた正確な件数であり、比較する範囲の縮小ではない。変更は統合テストだけであり、成功済みの lib 全件はやり直さない。

失敗した desugar_export と未実行の後続32統合ターゲットを、integration-remaining.json に記録した一つの Cargo コマンドで続けた。Character の交換は成功したが、package_command の固定ハッシュの更新漏れで終了101（142.946秒）となった。CONFIG の版を0.0.7へ戻した入力から旧ハッシュが再現することを確かめ、0.0.8の入力の新ハッシュを独立に計算して期待値を更新した（R108、package-command-hash.json）。出力・書き換えた内容・不変なときに更新しないこと・エフェクト差の assert はすべて保った。

成功済みの対象を除き、package_command と未実行の後続12統合ターゲットを integration-final.json の一つの Cargo コマンドで実行した。終了0（184.376秒）だった。source_rules は scripts/check.sh の元の二関数を抽出して一度実行し、spec_tally の自己検査と集計も一度実行してすべて終了0だった。fmt は各修正で古くなった結果だけを更新し、最後の状態で終了0を確認した。

| 作業末と補完の検査 | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| work（上記の一回） | 1。lib と先行5統合は成功。古い Character の件数で停止 | 124.692秒 |
| 失敗・未実行の33統合（integration-remaining.json） | 101。Character は成功。package_command の固定ハッシュで停止 | 142.946秒 |
| 失敗・未実行の13統合（integration-final.json） | 0 | 184.376秒 |
| source_rules の二関数 | 0 | 0.145秒 |
| spec_tally の自己検査 / 集計 | 0 / 0 | 0.081秒 / 0.129秒 |
| `cargo fmt --check`（R107の修正後 / R108の修正後） | 0 / 0 | 2.636秒 / 2.184秒 |
| `cargo clippy --all-targets` | 0、警告なし | 16.129秒 |
| `cargo build -p benitoite --example derive_inventory --bin benitoite` | 0 | 0.914秒 |
| `python3 -B tools/derive/test_derive.py` | 0、23件成功 | 31.055秒 |
| `python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json` | 0、管理領域と生成記録が一致 | 0.266秒 |
| `cargo run -q -p benitoite --example gen_skill` と68ファイルのSHA-256の照合 | 0、再生成による変更なし | 0.836秒（生成） |

最終的に lib 1209件成功・既存21件ignore、全38統合ターゲットの通常対象267件成功・既存7件ignore、失敗0件である。test-summary.json は各ターゲットの最終の成功と元のログを示す。build_info の既存の ignored 5件や形式化の書き出し等を実行済みとは数えない。ignore の追加はない。本番の Rust は8行追加・削除0行、Rust のテストは73行追加・46行削除であり、版とハッシュの文字列の置き換えを含む。テスト関数の削除はない。

変更文書19ファイルの本文のローカルリンク423件は、宛先・見出しの不一致0件だった（links.json、0.229秒）。コード内のテンプレートはリンクに数えていない。最終の空白の検査 `git diff --check` のコマンド・終了状態・外側の時間は diff-check.json、出力は diff-check.log に保存する。

## 計画からのずれと申し送り

R105 のとおり、依頼で指定された V1 の実装担当と取りまとめ担当の範囲を plan の work 行で区別した。clippy の all-targets を別に一度実行し、work の lint_default と重ねない。R106 では古い fuzz の lock の更新を追加した。最初の offline update が共通依存まで更新したため採らず、根の lock と既存の fuzz 固有の記録から Cargo に再解決させた。offline/locked の tree は benitoite 0.0.8 を確認し、終了0（0.158秒）だった。根のソース・検査入力は変わらず、work は繰り返さない。英語の記述の不足の補完以外に仕様・公開 API は変えていない。formal/・Lean の定義・定理・仮定とヒープの不変条件は変更していない。

取りまとめ担当はこの差分を取り込んだ後、plan の change、最終関係状態の check-formal と全件 manifest、性能の本測定、release と実際の候補・実 CLI・配布の照合、RV5 を行う。exchange-manifest.json の batch2Character の定義件数2は、Z2 が追加した相関の二関数を含めて4へ照合する必要がある（R107）。全件 manifest の更新を部分的な推定で代行してはいない。P1 の全比較以後に G2〜G4・Z2 の標準宣言と例、今回の版と入力が変わっているため、P1 の成功をそのまま最終候補の成功とはしない。コミット・タグ・push・保管・docs/todo の更新は行っていない。
