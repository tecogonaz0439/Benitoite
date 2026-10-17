# F1 入力・版・ハッシュ・文書の最終照合

## 範囲と再検索

[contracts.md](contracts.md) と同じ開始時 HEAD の全追跡ファイルを対象に、P1 の分類と M2a/M2b の対応を確認した。開始時のツリーは clean であった。無視された `docs/todo/`、ビルド生成物、F1 の一時入力、新規の f1 記録自身は検索件数に含めない。履歴資料は保持理由の照合だけを行い、現在の設計の根拠にしていない。

全件のパス・M2a の分類・M2a 以降の変更の有無・現在の SHA-256・検索行は [inputs.json](inputs.json) に記録した。これは読み取り照合の記録であり、編集を承認する manifest や通常検査の入力ではない。SHA-256 はファイル内容を識別するための値であり、後述のパッケージの集約ハッシュとは別である。

検索は `git ls-files -z` で追跡項目を列挙し、rg で版・language・SHA-256・環境設定・test fence を探した。独立した一時 Python でも元のバイト列を LF で分け、同じ系統を確認した。通常ファイルの一致954件は両者で一致し、rgがたどったスキルのリンク先の重複2件だけを除いた。検索式は inputs.json の searchPatterns に実際の正規表現として残す。IPv4や説明中の単語を、言語版の通常宣言と混同しない。

| 確認対象 | 最終結果 |
|---|---|
| P1 の通常 testdata | 50件すべて language 0.0.7。全パスは inputs.json の normalTestdata |
| M2a の分類 | 994件を全件対応。現在の検索に一致しなくなったファイルも行を残す |
| M2a 後の追加の検索一致 | 10件。改造の作業記録9件と、R29/M3b の日本語 inspection.md 一件。未分類なし |
| 現在の検索一致 | 954ファイル。version 359、language 505、hash 338、environment 218、testFence 6ファイル。系統の重複を含む |
| M2b の編集 | 74件すべて afterSha256 と現在の実バイト列が一致。正負のハッシュに伴う診断も含む |
| 生成物 | M2b の56件すべて記録の SHA-256 と一致。生成処理との一致は既存 skill_docs で確認 |
| 評価の参照解・runtime_builtins | 11本の参照解と runtime_builtins.rs は M2a とバイト単位で一致。固定language宣言を新設していない |
| シンボリックリンク | 六件のリンク先を保持。実体を重複編集していない |

## P1/M2a の分類から最終差分への対応

| 分類 | 最終の扱い・担当結果 | 確かめる境界 |
|---|---|---|
| edit（73件） | M2b で版・通常入力・診断・固定ハッシュを同時更新。R30 の hash-mismatch 診断一件を加え、最終74件を全バイト照合 | lib の版境界、golden/package_command/spec_examples |
| generate（56件） | gen_skill の生成物を保持。M2b の二回生成の結果と同一で、手書き変更なし | skill_docs の生成と実ファイルの比較 |
| history | archive・測定・過去の改造・今回の基準/調査/判断/実測を保持。過去の版を一律置換しない | 最終差分と remainingOldVersion の理由 |
| reference | 最小実行版の資料を保持。現行版の入力として扱わない | 最終差分に変更なし |
| syntax | parser/fmt の旧い綴りを保持。整形と版の意味の検査を混同しない | lib の parser/formatter、fmt_command、golden |
| negative-or-fixed-version | 旧版・未来版・不正版・注入した current・改名履歴・独立probe・metadata の負例を保持。実版の未来は0.0.8、現行は0.0.7、旧0.0.6はE0908 | modules の表と診断の全文・全件、CLI の版境界 |
| dynamic | CARGO_PKG_VERSION から問い合わせ・producer・置換へ渡す。固定リテラルへ変えない | cli_process の版・Skill の比較 |
| handwritten | 英語 Skill の5文書を保持。SKILL.md の placeholder、inspection の九形式と保証の限界を確認 | skill_examples/skill_docs/cli_process |
| m3a（2件） | 言語リファレンス・導入の訳を英語版へ同期済み | 下の七組の対照、reference_examples |
| m3b（4件と追加1件） | Skill の既存四文書と新しい inspection の訳を同期済み。埋め込みに訳を入れない | 下の七組の対照、skill_docs |
| resample | harness-response の実出力は M3b の0.0.7へ採取済み。採取元コミットと抜粋を明示 | F1 の再実行との比較。取り込み後の最終採取は F2 |
| fuzz | 別クレート自身の版と既知の古い Cargo.lock を保持。M2a 以降 lock に差分なし | 今回再解決・fuzz実行の成功とは扱わない |
| tool | 旧移行器・ベンチの条件と評価の参照解を保持。11本の参照解に変更なし | 段末の python/skill_eval はオーケストレータ担当 |
| design-existing | 過去の変更、保証、用語、出典を保持。現行機能は D1〜D3/Z6 の各章・M2b の版更新へ対応 | contracts.md、spec_examples/reference_examples |
| implementation-existing | 開発用変数・既存の処理・検査器を保持。新契約は本番へ接続済み | lib/clippy と contracts.md の所有・型の確認 |
| fixture-existing | 意図した負例・診断・Wasm・checksum・単一ソースhash・通常環境/IP を保持。変更後の依存の computed だけ R30 に従う | golden/runtime_builtins、下の独立計算 |
| project-existing | 初回リリースの説明・スキル運用・検査スクリプト・形式化を保持。今回の版へ一律置換しない | 最終差分と check.sh の静的な分類確認 |

## 意図して残す0.0.6

全追跡ファイルの `0.0.6` は72ファイル・476一致行であった。同じ行の複数出現は一件と数える。全行番号と保持理由は inputs.json の remainingOldVersion にある。日本語訳・通常入力の取り残しはない。

| 対象 | ファイル数 | 保持する理由 |
|---|---:|---|
| docs/archive | 26 | 読み取り専用の歴史資料 |
| 今回の改造ディレクトリ | 36 | 移行前の基準、調査、判断、実測、回答の旧宣言の説明 |
| CHANGELOG | 1 | 過去の節と移行前の宣言 |
| modules/package.rs・modules/tests.rs・older-language.diag.json | 3 | 注入版と実版の境界、過去の変更案内の全文・全件の比較 |
| fmt の入力・期待値・fmt_command.rs | 3 | 旧い版の綴りを保つ整形の契約 |
| 現行設計01-03・06-01・06-09 | 3 | 既存の互換性の変更と、dieを含む形式1の基準の説明 |

さらに0.0.1〜0.0.5、0.0.8、99.0.0、CARGO_PKG_VERSION、benitoite-version の一致も分類表から照合した。版の解析・改名の説明・未来版の負例・独立ビルドのprobe・IPは更新漏れと扱わない。処理系の Cargo.toml とルート lock の自身の項目は0.0.7で、lock の依存の解決結果を変えていない。

## 正負のハッシュ

Python hashlib で、現在のディスクの Hashkit 全ファイル、現在の Rust の CONFIG/READ と fixture のバイト列を取り出して再計算した。M2a/M2b の予定値を計算の入力には使わず、計算後に記録と実際の期待値へ突き合わせた。相対パスの UTF-8 順、二つの空白・パス・LF、CRLF・非UTF-8を保持した。

| 固定値 | 現在の SHA-256（sha256: の後） |
|---|---|
| hash-match の Hashkit | `5d12e17f6e1522ec49837e741d7b5a28145b94f6aa6ab95c6b72b683c534dd65` |
| modules/hash.rs の fixture | `dfa96801c59264be45ff137fedbfd84bf176c3941b66c751cadbca0692c82fec` |
| package_command.rs の Words | `ec9bf643e50197c98e9aa736bb08ef612cf253cb682ef4936f800cf57dacbbed` |
| test_command.rs の不変な単一本文 | `14c52fc2838594adb45ee1ec151457617d8e5ed2347dbb1ba70d6570ced86307` |

パッケージの集約行は inputs.json の hashPairs に記録した。hash-mismatch の入力と expected はゼロのまま、E0919 の computed は変更後の Hashkit と一致する。parser・ヘッダ編集の繰返しa/bは構文用の値として保持し、バイナリ・測定条件の checksum と混同しない。

## 生成元・訳・公開状態

| 対応 | 最終照合 |
|---|---|
| 構文章 → grammar.md | 現行構文と生成元を保持し、既存 skill_docs が生成結果の全内容を比較 |
| diag::codes → diagnostics.md | E0512 の定義・本文・notes/helps と生成物を確認 |
| Process.bnt の文書コメント → stdlib/IO.Process.md | 二接頭辞・ASCII比較・InvalidInput・非起動・継承の限界が一致 |
| HAND_WRITTEN → bundle.rs | inspection.md を含む手書き5文書と生成55文書、ライセンス2文書で62件。日本語訳は含めない |
| 英語版 → 日本語訳七組 | コード191ブロック、表333行の inline code と見出し階層が一致。SKILL.md の訳だけにある説明用 frontmatter は英語の前付けと完全一致 |
| JSON例 | design.md の8件と harness-response.md の9件がすべて JSON として妥当。回答の抜粋・実出力の対応は contracts.md と results.md を参照 |
| 公開状態 | 0.0.7 の実装と未作成のタグ・未公開を区別。回答の実測元は M3b のコミットを維持し、F1 の HEAD へ数字だけを書き換えない |

版の残存・生成物・訳を根拠とする修正は見つからず、本作業では生成元・生成物・訳・harness-response を変更していない。
