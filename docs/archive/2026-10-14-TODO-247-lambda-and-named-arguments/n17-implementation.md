# N17 移行道具と基準の manifest

## 実装の範囲

`tools/named-arguments-migrate/` に抽出器、manifest・確認表・diff の出力、確認済み manifest の適用と道具の検査を追加した。Rust の `examples/named_arguments_inventory.rs` と非公開の補助 `named_inventory/index.rs` は、既存の parser・モジュールの読み込み・resolve・typeck の公開境界から宣言、呼び出し、型注釈、ラムダの束縛と参照、適合の成分の材料を取得する。通常の処理系の経路、公開の型とシグネチャは変更していない。AGENTS.md の表に道具を登録した。

宣言から取得した実名と、Q10 で追加する内側の期待名を区別した。期待名がなければ成分内の最初のラムダの実名を候補にする。局所の宣言に加え、外側から参照した名前への捕捉も衝突として保留する。公開契約、複数期待、複雑な成分、負の入力、生成する文字列などは理由付きで保留する。取得できる成分と N1 の生成入力の扱いは [decisions.md の R45](decisions.md#r45-n17-の公開の型情報から取得できる成分と生成入力の照合) に記録した。

Rust の通常・raw 文字列と Markdown のコードブロックは UTF-8 のバイト境界を保持する。復号後の範囲と元ファイルの範囲を別に記録し、編集の `before` は元ファイルの内容と比較する。確認済み manifest の SHA-256、全入力のハッシュ、編集範囲の内容、成分への依存を検査してから適用する。適用後の記録が一致する場合だけ、同じ manifest の再適用を差分なしで終える。

## 全対象の成果物と N1 との照合

全追跡ファイルを対象に生成した。除外と使い方は [道具の README](../../tools/named-arguments-migrate/README.md) に書いた。

| 成果物・分類 | 件数・内容 |
|---|---|
| [manifest.json](n17/manifest.json) の入力 | 3,895 |
| 候補 | 5,605。全件 `review: pending` |
| 保留 | 3,057 |
| 保留のない案 | 2,548。うち編集を含むものは 2,381 |
| [migration.diff](n17/migration.diff) | 保留のない案を重ねた 259 ファイルの差分。未適用 |
| [review.md](n17/review.md) | 全候補の分類別の確認表 |
| [reconciliation.json](n17/reconciliation.json) | N1 の全字句候補・全合流・生成入力の snapshot の照合 |

N1 の合流 194 件（list 45・return 127・if 22）のうち、追跡ファイルの 67 件はすべて一致した。生成器の 127 件は生成元を変更して再生成する N29 へ保留し、300 入力の seed・段・ハッシュも残した。N1 の字句候補 5,593 件は、AST の一候補と一致 3,042、複数候補のため保留 234、字句候補として個別確認が必要 713、設計上の除外 1,604 に分かれた。件数を合わせるために候補を消したり、曖昧な対応を一致と扱ったりしていない。

カタログの JSON は一記録を一行で保存する。通常の JSON と同じ情報を持ち、確認表と diff で変更の内容を読む。既存の入力、期待値、生成元は書き換えていない。

## test-audit の作成時の関門

新しいテストは道具の実際の入口を境界とする Python の 4 テストである。本物の処理系と一時ファイルを使い、処理系の段をテストダブルに置き換えない。

| テスト | 守る契約と退行 | 既存のテストでは届かない理由 |
|---|---|---|
| `test_host_positions_and_atomic_reviewed_application` | 四つのホストの位置対応、Unicode のエスケープ、CRLF、コメント・文字列・構成子の維持、注釈と同じ束縛の参照の改名、同じ位置のラベル挿入と改名、再適用の差分なし。復号後の位置で元ファイルを編集する退行を捕まえる | 既存の処理系テストは、この Python の抽出と元ファイルへの適用を通らない |
| `test_stale_source_and_overlapping_ranges_rejected_before_writes` | 古いソースや重複した範囲を、書き込み前に拒否する。manifest の確認後に変わった入力を編集する退行を捕まえる | manifest と適用の契約は新しい道具が持つ |
| `test_unresolved_conflicting_and_collision_components_are_held` | 型検査に成功する独立入力で、局所名・外側の名前の捕捉、複数期待、公開される関数値の保留を確かめる。単に別の型エラーで拒否されるテストにはしない | 旧型検査には契約名の移行案と保留の判断がない |
| `test_format_generated_input_is_recorded_without_edits` | 生成する Rust 文字列を記録し、diff に出さない。生成元の一部を完成入力として適用する退行を捕まえる | 生成元とホストの分類は道具の責務である |

四つとも本番のコードが必要としない公開の範囲・フラグ・注入用の引数を追加していない。既存のテストを削除・弱化・ignore にする変更はない。処理系本体の増減は 0 行、読み取り用の Rust と Python の道具は +1,453 行、道具のテストは +119 行である。

## 検査

以下はすべて成功した。

| コマンド | 結果 |
|---|---|
| `cargo build -p benitoite --example named_arguments_inventory` | 成功 |
| `python3 tools/named-arguments-migrate/test_migrate.py` | 4 テスト成功 |
| `cargo test -p benitoite --lib --test golden` | ライブラリと golden の計 1,131 成功、既存の ignore 21。検査本体 110.29 秒 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `cargo fmt --all --check` | 成功 |
| 全対象の `inventory` と manifest からの diff の再生成 | 成功。入力への書き込みなし |

依頼に従い scripts/check.sh（dry-run を含む）と gc-stress の検査は実行していない。formal は変更していないため、lake build と形式化の検査も実行していない。コミットと docs/todo の変更は行っていない。

## 後の作業への申し送り

N18 以降で AST・静的な型の欄を追加するときは、この example と索引も新しい表現に合わせる。現在の manifest は旧処理系で確認した移行前の基準であり、名前付きの一般入力の受理が接続されるまでは diff を適用しない。

N27〜N30 は対象と依存する成分を確認し、保留を個別に解消して新しい manifest を作る。負の入力の元の診断と、新仕様で変わる診断の承認は別に行う。N29 は生成元を変更して同じ seed で再生成し、snapshot と合流の保留を照合する。期待値の一括更新は行わない。最後の共通の検査はオーケストレータが行う。
