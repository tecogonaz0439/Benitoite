# R20.0b の交換の実装と局所照合

## 変更

`tests/desugar_export/builtins.rs` の通常の表の書き出しで、完全な標準宣言の `Benitoite.Network.Http.ClientRequest` のレコードを、既存の補充・束縛番号の移し替えの表を通して同じ入力の名前空間へ写す。その `data:N` の型を `scope::table_data` へ渡し、`valContents` に書く。`table_data` は内容を型の JSON として受け、文字列の型名を作らない。レコードを不透明型へ変換しない。

合成の F-table は、要求の型を `data:1003` の五欄のレコードへ直した。Pair は `data:1004` の二欄のレコードとし、宣言・構成子・要約・データ型の一覧を手書きの独立期待値へ加えた。二署名と `valContents` も `data:1003` を指す。scopeAcceptance の空の patterns/hosts と明示した limits は、従来どおりこの合成入力だけに残す。

## テストの作成時の関門

追加した `scope_tables::exports_request_content_as_the_same_record_type_in_declarations_and_signatures` は、通常のソースを解析・型検査・脱糖し、検査→同じ Ok の照合→射影→url の欄の参照が交換の対象内に残ることを確かめる。内容の型の名前と二署名・dataDecls の一致は Lean の読者が検査しない独立した契約である。レコードの欄名・順序・五つの型、純粋、endpoint の一変数、RequestIn の名前を独立期待値で確かめる。期待するデータ型は dataDecls の ClientRequest として識別した宣言の名前から直接組み、書き出し対象の `Surface::ty`・`data_name`・束縛の移し替えの実装を呼んで算出し直さない。異なる data:N を内容や署名へ入れる退行、内容を不透明型に戻す退行、通常の定義を対象外へ落とす退行を捕まえる。旧の合成入力とパス側のテストだけでは実際の ClientRequest の登録経路を通らないため不足する。本番の差し込み口と公開範囲は増やしていない。

既存の未 import 操作の書き出しテストは、旧の「valContents が空」の期待だけを一項目の期待へ追随させた。他の名前集合・補充項目・未使用操作の確認は保った。テストの削除はない。新しい裸の `Http.RequestIn` の型注釈は追加していない。

## 実行

正確なコマンド・UTC 時刻・終了・外側の時間・RSS は同名の JSON、生ログは同名の log に保存した。`run_exchange.py` は `/usr/bin/time -p` と、コマンド直後の終了状態の表示を使う。time -l は使わない。RSS は macOS の `getrusage(RUSAGE_CHILDREN).ru_maxrss` の bytes の補助値であり、終了した子孫の最大値で、同時常駐量の合計ではない。

| 記録 | 終了 | 外側の秒 | RSS bytes | MiB |
|---|---:|---:|---:|---:|
| f-table-export | 0 | 9.477 | 1,430,224,896 | 1363.969 |
| f-table-builtin | 0 | 1.160 | 39,698,432 | 37.859 |
| f-table-desugar | 0 | 1.135 | 39,682,048 | 37.844 |
| export-unused（初回） | 101 | 9.745 | 2,210,922,496 | 2108.500 |
| export-request | 0 | 2.632 | 687,800,320 | 655.938 |
| export-unused-retry | 0 | 0.401 | 77,889,536 | 74.281 |

`export-unused` の初回は、並行実装中の Http.bnt の RequestCheckError が `InvalidUrl(message: String)`・`Scope(error: Scope.ScopeError)` と書かれていたため、構成子引数の位置で E0201 となった。担当が既存の引数構文へ直した後、同じ対象は終了0となった。交換本体に関する失敗はなかった。

F-table は corpus 15・sidecar 7 として各入口を一度実行した。builtinCheck は入力1、prim 13、dataDecls 4、constructors 6、summaryComparisons 8、summaryMismatchCount 0、errors 0 だった。desugarDiff は golden definitions matched 2、mismatched 0、outside 0、excluded 0、nonTopRanges 18 だった。空の定義や除外だけの成功ではない。保存先は `f-table/`、入力と出力・実行ファイルの SHA-256 は `f-table-hashes.json` にある。

B-Lean はユーザーから示された 2026-10-29 の L40.3c 後の排他ビルド（573 jobs、終了0、sorry 0、175.22秒、RSS 3,575,087,104 bytes）を前提とした。この担当は lake build・check-formal.sh を実行していない。F-table の成功を本番全入力や全比較の成功と数えない。

通常の要求側の証拠は `request-in-export/` の corpus/builtins/stdlib と `request-export-hashes.json` に保存した。scopeAcceptance・limits・区間・全書き出し元の版と欄の最終接続は K10 に残る。Lean の読者が内容の宣言の存在・二署名との一致を検査するかの判断も K10.1 の申し送りを保つ。

## 差分と時間

交換関連の追跡済み差分は4ファイルである。`builtins.rs` は17行追加・3行削除、`scope.rs` は5行追加・8行削除、`scope_tables.rs` は102行追加・6行削除、手書き期待値は148行追加・11行削除である。追加テストの準備を含むため、本番処理系の公開範囲の変更ではない。対象ファイルを rustfmt で整形し、git diff --check は終了0だった。

担当内の能動時間は個別に計時していない。実行待ちの外側の合計は上の六実行で24.961秒であり、枝全体の時間は results.md に集計する。git の状態を変える操作、private と docs/todo の読取、formal の変更、新しい CARGO_TARGET_DIR、target 外の一時ビルドや基準版の展開は行っていない。停止条件へ該当する変更は不要だった。
