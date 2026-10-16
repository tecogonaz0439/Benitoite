# M8 の訳とサンプルの照合表

## 翻訳元と対応

翻訳元は、M7 取り込み後の `7ffaea1010c25fd6b4f4f70dc159ad30775c26d0` の英語版である。前回の翻訳時点の `5ef09b51` から英語版の変更を読み、以下の6ファイルへ反映した。M7 で更新済みの通常の版宣言と導入例も、改めて照合した。[audit.json](audit.json) に両文書の SHA-256、全コードブロックの位置・情報文字列・ハッシュ、見出しの英日対応とリンク先を記録した。

| 日本語の文書（docs/ja/ からの相対パス） | 英語の原文 | 対応するコードブロック | 対応する見出し | 照合した内容 |
|---|---|---:|---:|---|
| reference/benitoite.md | docs/reference/benitoite.md | 63 | 50 | 四型の属性、record の制限と互換性、明示 try と裸の意味、Show、Process.Exit、報告・ハンドラ・テスト実行器、return の改行、WIT の厳密な一致 |
| reference/install.md | docs/reference/install.md | 10 | 10 | 0.0.6 の翻訳元、導入例、版の表示、リンク。本文の版とコマンドは M7 で更新済み |
| skill/SKILL.md | crates/benitoite/skill/SKILL.md | 4 | 8 | 35語と文脈語、四型、再利用と入口の処置、標準 Show、Process.Exit の利用者向けの説明、return の改行 |
| skill/references/common-mistakes.md | crates/benitoite/skill/references/common-mistakes.md | 56 | 17 | die の予約、明示形の境界と説明の制約、エラー表示、record の分解、return と整形の規則 |
| skill/references/idioms.md | crates/benitoite/skill/references/idioms.md | 46 | 15 | load と main の対比、評価順・停止・ハンドラ・報告、四型と record、全実行例の処置・戻り値・uses |
| skill/references/language-comparison.md | crates/benitoite/skill/references/language-comparison.md | 5 | 3 | Rust の ? と返す形の対応、裸の意味の固定、終了する形、単語集計の実行例 |
| 合計 | 6組 | 184 | 103 | 未照合0件 |

184個のコードブロックは、情報文字列と本文が英日で完全一致した。SKILL.md の訳にだけある原文の前付けは、英語版の冒頭との完全一致を別に確認した。見出しは順序・深さ・節番号を照合し、英日のローカルリンク183件は、参照先のファイルと見出しがすべて存在した。追加した日本語リンクは日本語の見出しへ向け、生成文書への既存のリンクは英語の原文を指す。

6組の文書で try を含む実行用ブロックは各言語20個である。既存の `try_actions_inventory` へ完全なブロックを渡し、`benitoite test` のブロックも含め、両言語で構文・型の検査が成功した。各言語の TryExpr は51件（return 19、die 32、裸0）である。移行器の通常の fence 抽出では解析しないテスト例も、ここでは完全なブロックとして確認した。本文の裸の一般形は、意味の固定の説明として保持する。

英語版の Result.Error を返す契約を教える main、SKILL.md の空ファイルを失敗として返す main、再利用する関数とコールバックには `or return` を使った。終了する入口では英語版と同じ `or die`・Unit・Process.Exit・Process の import に揃え、表示だけの mapError を除いた。output・stderr・diagnostic と各例のハンドラ・assert は、英語版と同一である。移行手順は CHANGELOG への既存の参照を保ち、訳へ別の移行手順を追加していない。翻訳は Skill の配布ディレクトリへ入れていない。

## R1 の全対象の最終走査

最終の日本語本文へ更新後、`python3 -B tools/try-actions-migrate/migrate.py inventory --out /private/tmp/benitoite-m8-final-inventory` を実行した。追跡中の2,995入力・3,850候補を読み、非公開の docs/todo/ は走査していない。分類の件数は次のとおりである。

| 自動分類 | 件数 | 最終の扱い |
|---|---:|---|
| already_explicit | 349 | 明示済み。日本語の完全なコードブロックも別に確認 |
| history | 2,467 | 保管文書・固定した測定入力・移行の記録として保持 |
| keep_test | 651 | 裸の検査と検査の生成器として保持。今回の変更なし |
| notation | 235 | 構文・意味の説明として保持 |
| hold | 148 | 下記の保持理由へ全件対応付けた |
| change / pre_migration | 0 / 0 | 適用を要する候補なし |
| 合計 | 3,850 | 未分類・未確認の現行サンプル0件 |

hold 148件と、現行の非検査・非歴史資料の候補で AST が裸と判定した29件の和集合173件について、[audit.json](audit.json) の reviewed_candidates に、元の分類・位置・実際の行・保持理由を残した。自動分類の hold を削除したり、未解析の断片を型検査済みへ書き換えたりしていない。

| 保持理由 | 件数 | 根拠 |
|---|---:|---|
| 裸の意味の一般形 | 29 | 全件がインラインの `try e`・`try r`・`try result`・`try value`。固定した返す意味を説明する記法であり、実行例ではない |
| 文法・診断・実装の説明 | 127 | EBNF、キーワード列、生成する文言、コメント、処理系の不具合の説明など。位置ごとの実際の行を確認 |
| スタック検査の生成器 | 7 | stack_probe/support.rs。深さ・入れ子を測る検査用の入力とその名前・説明を保つ |
| 移行器自体の説明 | 2 | examples/try_actions_inventory.rs のモジュールコメント |
| 完全な実行用 fence で別に確認 | 8 | 英日の reference・SKILL・idioms の `benitoite test`。上記40ブロックの構文・型検査と既存の実行例テストで確認 |
| 合計 | 173 | 未確認0件 |

最終 inventory の全入力のハッシュを現在のバイト内容と照合した。非検査・非歴史資料の候補を持つ105ファイルのパスとハッシュは audit.json の reviewed_current_hosts にある。日本語訳以外は、M7 取り込み後の HEAD と完全一致した。したがって、M3・M4・M5・G7 の既確認の設計書、英語文書、標準ライブラリ、examples、現在の tools、生成物に、新たなコードの差分はない。最小版リファレンスには try の実行例がなく、旧版の説明を保った。

M5 の確認表で M8 へ引き継いだ日本語5ファイル・46候補（change 8、hold 38）は、今回の英日コードの完全一致とインラインの説明の照合で確認を終えた。導入手順の1ファイルを加えた6ファイルが今回の翻訳の全対象である。裸の検査については、M5 の保持先を変更していない。

## 再確認の方法

読み取りだけの inventory を作り、次のコマンドで照合記録を標準出力へ生成できる。

```sh
python3 -B docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/m8/audit.py --inventory /private/tmp/benitoite-m8-final-inventory/manifest.json
```

[audit.py](audit.py) は、入力・期待値・assert を編集しない。通常のテストや検査から呼ぶ仕組みは加えていない。この結果は、上記の翻訳元と最終の日本語本文に対する作業記録である。後の変更がある場合は inventory から作り直す。
