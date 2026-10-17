# M3b Skill の日本語訳と最終の公開情報の結果

## 目的と変更

M2b・M3a 後の英語の正に Skill の日本語訳を揃え、ハーネス向け回答の出力例を0.0.7の実 CLI に更新した。開始時の HEAD は `b2b7fe383b192efadc77d8bf3556e84f2ba413b2` で、作業ツリーに差分はなかった。

| 変更ファイル | 内容 |
|---|---|
| [SKILL.md](../../../ja/skill/SKILL.md) | 翻訳元を0.0.7に更新。版と形式の問い合わせ、Skill の取得、検査報告とエフェクト上限を使うスクリプト・テストの手順、E0512、Assert.Check、終了状態、shell 参照、environment の制約と限界を翻訳。原文の frontmatter を示す説明用 text ブロックと実際の YAML frontmatter・版の置換を区別 |
| [idioms.md](../../../ja/skill/references/idioms.md) | 翻訳元を0.0.7に更新。外部コマンドの明示環境設定の拒否、InvalidInput、継承と隔離の限界、非実行のテスト検査から実行までの手順を翻訳 |
| [common-mistakes.md](../../../ja/skill/references/common-mistakes.md) | 翻訳元を0.0.7に更新。検査報告・診断・実行の区別、完全な報告の受理、E0512 と全体拒否、禁止環境変数の失敗と対処の節を翻訳 |
| [language-comparison.md](../../../ja/skill/references/language-comparison.md) | 翻訳元を0.0.7に更新。子プロセスの環境設定の制約と、宣言上限の検査・照合を翻訳 |
| [inspection.md](../../../ja/skill/references/inspection.md) | R29 の申し送りに従い新訳を追加。全九形式、ビルド情報の由来と不明値、報告の欄・部分結果・ハッシュ・shell 参照、上限の比較、実行全体の拒否と集計、終了状態、Skill の論理名と取得を翻訳 |
| [harness-response.md](../harness-response.md) | 再採取した0.0.7の version/producer/build へ例を更新。dirty の null・notCollected を保持し、タグ未作成・未公開を明記。CHANGELOG の0.0.7と互換性の説明へ移行参照を追加 |
| [cli-observations.json](cli-observations.json)・本書 | 入力、引数、終了状態、完全な実出力、全62文書の長さ・ハッシュ、移行の対照、検査と申し送りを記録 |

既存訳に対応する英語の正の変更は、以前の訳を更新したコミット `f31dacd3` から現 HEAD までの四文書の差分で全件を特定した。新しい inspection.md は全文を翻訳した。design.md の段1〜5と decisions.md の関係する Q/R、特に R1〜R6・R8〜R9・R11・R13〜R16・R20・R27〜R29 に沿って照合した。

型・公開シグネチャ・CLI・JSON の契約の変更はない。英語の正・Rust の本体とテスト・埋め込み・生成元・生成物・CHANGELOG・docs/design は変更していない。構文・型の規則・脱糖・形式化も変えず、R4 に従って formal/ と07-04の表は変更していない。

## 文書と実出力の照合

従来の六組に R29 の新訳を加え、七組を最終照合した。一時的な Python の確認で、コードブロックは言語指定・本文・順序まで完全一致、表は全行の列数と inline code の値・出現数が一致した。見出しの階層も一致した。SKILL.md の訳にだけある原文 frontmatter の説明用ブロックは、原文の前付けと完全一致で別に確認した。これは翻訳の確認であり、処理系の文字列検索テストとして追加していない。

| 文書 | 一致するコードブロック | 表の行数 | 見出しの階層 | 有効なローカルリンク |
|---|---:|---:|---:|---:|
| 日本語リファレンス | 67 | 183 | 53 | 58 |
| 日本語の導入の手順 | 11 | 18 | 13 | 9 |
| Skill の SKILL.md | 4 | 25 | 8 | 17 |
| idioms.md | 46 | 15 | 15 | 14 |
| common-mistakes.md | 56 | 0 | 19 | 21 |
| language-comparison.md | 5 | 81 | 3 | 4 |
| inspection.md | 2 | 11 | 1 | 0 |

コードは計191ブロック、表は計333行、リンクは計123件である。ローカルリンクはファイルと見出しの存在まで確かめた。Skill の日本語訳内に0.0.6の残存はない。実行用の例や期待する出力・診断を変更せず、`benitoite test` の fence も英語正と同じである。

| 契約の観点 | 確認した内容 |
|---|---|
| 完全な報告 | 既知の schemaVersion/kind、status:ok、complete:true、終了状態0を要求。null・未知・不完全を空集合にしない。非実行の検査と実行結果の JSON Lines、usageError 内だけの kind:check/code:null を区別 |
| エフェクト上限 | 宣言上限と IO.All の展開、Assert.Check の保持、E0512、全入口の準備後の開始、集計の有無・filesNotRun・interrupted と終了状態を照合 |
| 保証の限界 | 同じ集合内でのファイル・内容・コマンドの変更、shell 参照と到達性の違い、全入力のスナップショットがないこと、静的検査と実行時の隔離の違いを保持 |
| environment | DYLD_/LD_、ASCII 大小比較、LD_RUN_PATH・空値・同値上書き、InvalidInput、子の非起動、変数名だけのメッセージ、通常の不正入力検査の優先を照合。親の継承、env/シェルで変数を設定できる限界、回避を移行案として勧めないことを保持 |
| ビルド・Skill | dirty の null/notCollected と明示した不明値の environment を区別。commit の監視の限界と再採取、論理名、置換後の本文・長さ・ハッシュ、HOME なしの問い合わせ、失敗時の空の標準出力を照合 |

通常構成の `target/debug/benitoite` を再ビルドし、先行の Z6 の入力と22呼び出しを一時ディレクトリで再採取した。すべて同じ期待終了状態となり、ローダ変数の拒否では marker が作られなかった。さらに全62文書を raw show で取得し、list の byteLength と contentHash を独立した Python hashlib と照合した。版置換後の SKILL.md は26298バイト、SHA-256 は `4999bf2f2b69b2d6d37390d45aa62e2dc5d43a4820395fb0789fc2c255802a7e` である。

回答の JSON 例9件は、抜粋の範囲を含めて実出力と構造で一致した。BNT 入力例2件も全バイト列が一致する。main/test のソース数は44/41件、Skill は62件である。version と producer.version は0.0.7、build.commit は `b2b7fe383b192efadc77d8bf3556e84f2ba413b2`、dirty は null、provenance.dirty は notCollected であった。不明値を false に補っていない。

CHANGELOG の `## 0.0.7 (San Benito)`、六機能、破壊的変更と E0908 の移行手順を確認した。回答に追加した二つの移行リンクもファイル・見出しまで有効である。実 CLI の対照でも、0.0.6の宣言は E0908・2、0.0.7は受理・0、0.0.8は E0907・2となった。回答に内部の作業 ID・R/Q の番号・plan.md・results.md・docs/todo への言及はない。ローカルの `git tag --list '*0.0.7*'` は空であり、タグ未作成・未公開の状態を保った。

## 共通の関門 K と検査

既存の assert・期待値・ignore・負の入力は変更していない。テストの追加・変更・削除はなく、test-audit の作成時の関門にかける新しいケースはない。既存の公開の境界のテストを実行し、テスト専用の本番 API は加えていない。本番コードと Rust のテストの行数の増減は各0である。公開契約と生成元を変えないため、gen_skill と新しい R 判断は不要である。

検査名を実行前に知らせ、既定構成で実行した。計画では文書だけの作業だが、今回の明示指示に従い lib・clippy・fmt も実施した。出力の整理には rtk を使った。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1197 passed、0 failed、既存21 ignored。テスト実行84.35秒 |
| `cargo test -p benitoite --test reference_examples --test skill_docs --test skill_examples --test spec_examples` | 4 suites、19 passed、0 failed。テスト実行計15.41秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `cargo build -p benitoite --bin benitoite` | 成功。回答の採取に使用 |
| 一時的な Python による翻訳の対照 | 七組のコード・表・階層・リンクが上表のとおり一致 |
| 一時的な Python による CLI と回答の照合 | 22呼び出し、全62文書、JSON 例9件、入力例2件、移行3件が一致。完全な出力は cli-observations.json に保存 |
| `git diff --check` | 成功 |

依頼に従い scripts/check.sh は dry-run を含めて実行していない。分類の分岐を読むと、今回の変更パスは docs/* の文書の扱いであり追加の検査を選ばず、分類外にも当たらない。これは dry-run の実績ではない。gc-stress、ignore を外す長いテスト、heap/full は実施していない。formal/ に触れていないため lake build の条件には該当しない。

## 計画との差と申し送り

M3b の旧記述は四組を対象としているが、R29 と Z6・M3a の申し送りで追加された inspection.md も翻訳した。既に記録された判断に従う変更であり、新たな計画変更や公開契約の変更はない。文書だけでも Rust の検査を実施し、scripts/check.sh を実行しない点は今回の明示指示による。コミット、docs/todo/ の変更、保管・タグ・公開は行っていない。

- オーケストレータ: san_benito への取り込み後、scripts/check.sh・gc-stress と M3b/F1 の段末検査、両構成の all-targets、G7 と最終の照合を行う。本書の成功を段末や公開前の全体検査の完了とは扱わない。
- F1/F2: 回答のビルド情報は今回採取した実行ファイルの値である。取り込み・ビルド後の再採取が必要かを確認し、後でタグを作成・公開したら実在する値と最終の検査結果を回答へ反映する。
- Skill の手順変更の成功率と修正の負担に対する評価は、R29 のとおり別途行う。今回は LLM を呼ぶ skill-eval を実施していない。
