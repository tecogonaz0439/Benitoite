# 宣言情報の範囲の保持

## 対象と判断

基準 B_WORK は `42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab` である。設計者の2026-10-29の決定に従い、R30.2c の依存の反転を採り、宣言情報の JSON に範囲を保持する。言語の公開名、型とエフェクトの意味、Lean の定義は変えない。既存の勧告照合と「組み込まない」の判断を引き継ぎ、依存とツールチェーンを変えない。

`private/`・それを指すリンク・`docs/todo/` は読まない。変更する Git 操作、`lake build`・`check-formal.sh`・short、新しい `CARGO_TARGET_DIR` は使わない。実装の分担とレビューは公開の AGENTS.md の規定に従う。

## JSON の契約

宣言情報の `version` と Python の `INVENTORY_VERSION` を 3 から 4 へ上げる。型の application と効果の名前の各原子に必須の `ix` を加える。型コンストラクタのパラメータへの application にも `ix: {"fixed":"top"}` を付ける。

添字は既存の交換の書き出し（`tests/desugar_export/scope.rs`）と同じ次の形である。内部の Debug 表示や新しい正規の表示は使わない。

| 内容 | JSON |
|---|---|
| Top | `{"fixed":"top"}` |
| 閉じた範囲 | `{"fixed": Range}` |
| 署名内の範囲変数 | `{"rvar": 0}`（番号は宣言内の番号） |

`Range` は `"top"`、`{"path":{"exact":[部分...]}}`、`{"path":{"tree":[部分...]}}`、`{"host":Host}`、`{"endpoint":{"host":Host,"ports":{"lo":整数,"hi":整数}}}` である。`Host` は `{"name":{"exact|one|many":[ラベル...]}}`、`{"ip":{"exact":{"family":"v4|v6","bits":整数}}}`、`{"ip":{"cidr":{"family":"v4|v6","network":整数,"prefixLen":整数}}}` の既存の形を用いる。IP の全幅を保持し、最終 JSON の bits/network は文字列ではなく整数とする。serde_json の Value の制限には、既存の交換の書き出しと同じ、限定した中間の十進文字列を最終出力で整数として書く方法で対応する。依存の機能は変えない。

署名には `rkinds`（宣言内の範囲変数の順の `path`・`host`・`endpoint`）、`admission`（`"any"` または `{"covers":{"inner":番号,"outer":番号}}`）、`shape`（`"untargeted"`、`{"topTargeted":{"kind":種類}}`、`{"single":{"kind":種類,"position":番号}}`）を加える。これらは収集済みの `range_signatures` から読み、未登録の署名は範囲変数なし・any・untargeted とする。範囲変数だけを保存して拡大の被覆条件を失うことを避ける。入れ子の関数型は外側の署名の範囲変数を参照する。

型の一覧の各行に `rangeKind: null | "path" | "host" | "endpoint"` を加える。Python が型名から独自に範囲の種類を推測しないためである。出力器と読取側で、添字の種類、変数番号の上限、非範囲型の Top、閉じた範囲の構造、admission と shape の参照を検査する。効果の原子にも範囲を保持し、同じ効果名で異なる範囲を持つ原子を重複として捨てない。

## 意味のハッシュと表示

意味型に `ix`、意味署名に `rkinds`・`admission`・`shape`、意味効果に原子の `ix` を含める。既存の意味ハッシュの構造が変わるため `HASH_VERSION` は 4 とする。位置、元の注釈、表示文字列は引き続き意味のハッシュから除く。生成本文とテンプレートの規則を変更しないため `GENERATOR_VERSION` は `3.1.0-syntax-batch5` を保つ。

Python の解決済みの型の説明では非 Top の添字を既存の交換構造で明示する。ソースの注釈が必要な場合は現行の言語の範囲注釈の規則に従い、範囲変数を利用者の型パラメータとして生成しない。カスタム関数は従来どおり純粋で単相でなければならず、`rkinds` が空でない署名は理由を添えて拒否する。

## 互換と既存の承認

設定は version 1、manifest・receipt・生成記録の外枠は version 3 を保つ。manifest と生成記録は `inventoryVersion: 4`・`hashVersion: 4` に更新する。receipt は従来どおり正確な manifest のハッシュと `recordSha256` でその版の記録へ結び付く。旧 inventory は受理せず、Rust の読取器を再ビルドする。

既存の確認済み manifest の保存済みバイト列とその SHA-256 は変えない。ただし、新しい道具は旧 inventory/hash 版の manifest の apply を `derive.incompatible_manifest` で拒否する。新しい preview は道具・バイナリ・入力のハッシュと新しい意味構造を含むため、manifest のハッシュは変わり、以前の承認と receipt は流用できない。

旧生成記録の check は `derive.migration_required` とする。新しい preview は旧本文を旧 `outputSha256` で認証し、旧記録とハッシュを移行欄へ残す。新しい意味ハッシュを旧承認として扱わない。本文が同じ場合も生成記録の移行と再確認が必要である。同梱の例はこの移行を行い、生成本文が変わらないことを確認する。

## テストの作成時の関門

Rust では既存の宣言情報の境界のテストを拡張し、実際に収集した標準署名を手書きの独立期待値と比べる。範囲を Top に落とす退行、変数の番号と被覆の向きの逆転、整数の精度の消失を検出する。従来の二つの検査は範囲を表せない出力器で失敗した記録が R30.2c に残る。Python では実際の reader を使う既存の生成管理のテストを拡張し、import による拒否、範囲情報の欠落・不正な番号、古い承認の再利用、範囲変数を持つカスタム関数の受理を検出する。Rust の出力契約だけでは Python の検証と生成管理の失敗を検出できない。どちらもテストのための本番の差し込み口は増やさない。

## 見込みと検査の割り当て

設計は着手後30分以内にまとめた。残りは約1.5〜3時間を見込み、4時間を超えないため続行する。長い測定を新たに開始しない。

| 手順 | 検査・受け入れの内容 | 残りの見込み |
|---|---|---:|
| 実装と文書 | Rust の出力器、Python の検証・ハッシュ・表示、README・03-06の追随 | 40〜70分 |
| 局所検査 | reader/CLIのビルド、指定のdeclarations二件と範囲の独立期待値、File・Scope・Httpを加えた例のpreview/check、範囲変数を持つカスタム関数の拒否 | 10〜20分 |
| 道具の自己検査 | `python3 -B tools/derive/test_derive.py`。W-Rが選ばなければ別実行 | 5〜15分 |
| 作業末の検査 | 下記W-R。全lib・統合テスト・clippy・fmt・ソース規約・Skill生成物・仕様集計とPython道具の選択を確認 | 5〜20分 |
| レビューと記録 | 差分の担当外レビュー、修正、両作業の結果と停止理由の解決を照合 | 15〜30分 |
| 取りまとめの受け入れ | 独立レビュー・取り込み後のshort・Rust/Lean全比較等は従来の担当と時期を維持 | 不明 |

作業末は `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab --dry-run` の後、同じ指定から `--dry-run` を外し、`/usr/bin/time -p` で包んで一度実行する。check.sh 自身の戻り値、外側の時間、getrusage の最大常駐量を別々に記録する。ログの絶対パスは保存前に `<wt>`・`<home>` へ伏せる。
