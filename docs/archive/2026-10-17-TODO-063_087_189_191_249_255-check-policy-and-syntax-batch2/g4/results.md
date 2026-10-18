# G4 の実装結果

基準 B: `ccb282dec3d1722f1378b43981b5bcf9280af27e`（G3 取り込み後）。コミット・docs/todo の変更は行わない。

## テストの作成時の関門

1. 観測する契約: 本物の preview/apply で生成した関数を通常の check/test で検査し、宣言順の乱数状態・同じ size・一欄だけの縮小候補・同じ seed の再現・JSON 往復・生成記録の照合を確認する。
2. 捕まえる退行: 二欄への乱数状態の再利用、欄順の入れ替え、size の変更、複数欄の同時縮小、カスタム関数の無視、不正な型や依存の受理、型・設定変更の見落としで失敗する。
3. 既存の検査との差: property_library はライブラリの公開関数、既存の JSON 自己検査は変換と管理を守る。新しい自己検査は実型から生成した Gen/Shrinker を呼ぶ境界を主とし、CLI の非実行の契約は既存 test_command に任せて複製しない。交換の追加一件は、実行では検出できない標準宣言・名前・型の欠落を検査し、既存の Export を使って独立した Lean の入口へ渡す。
4. 差し込み口: 本物の宣言収集・formatter・編集・check/test と VM を使い、段の代用・テスト用の公開 API やフラグを追加しない。既存の assert・期待の厳密さ・ignore は保つ。

## 検査

作業末の work は一回だけ実行した。基準は冒頭の B に固定した。lib・全統合・fmt を個別のコマンドで重ねず、clippy だけを依頼の all-targets に置き換えた。change/release、全件の特殊構成、形式化の全比較はこの作業で実行しなかった。

| 検査 | コマンド | 終了状態 | 外側の時間 |
|---|---|---:|---:|
| 自動の選択確認 | `scripts/check.sh --level work --base "$B" --dry-run` | 0。9単位を選択 | 1秒未満 |
| R103の選択確認 | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test '*' --dry-run` | 0。8単位を選択 | 1秒未満 |
| work G4 | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test '*'` | 0 | 442.696秒 |
| 全ターゲットのlint | `cargo clippy --all-targets` | 0。警告なし | 7.409秒 |
| 生成道具の全自己検査 | `python3 -B tools/derive/test_derive.py` | 0。23件成功 | 29.432秒 |
| 保存した例の再生成照合 | `python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json` | 0 | 0.258秒 |
| 最終の局所交換照合 | 下の Python で既存の比較を生成例と拡張可能な標準型へ適用 | 0 | 0.310秒 |
| 文書と差分 | 変更した文書の275ローカルリンクの宛先・見出しの確認、`git diff --check` | 0 | 1秒未満 |

work はlib 1208件成功・既存21件ignore、全38統合ターゲットは265件成功・既存7件ignoreであった。追加の交換一件も成功した。fmt・ソース規約・Skill生成物・仕様集計・Python構文・移行器の自己検査も成功した。既存のassertを削除せず、期待を緩めず、ignoreを追加していない。提供範囲に伴う期待の変更はR101/R102へ記録した。外側の時間はtime.monotonicで起動から終了まで測った。

最終の局所照合は、今回のworkが出した入力に次を適用したものである。比較の関数は既存の独立したLeanの入口を呼ぶ。正式なLeanのソースを変更せず、lake buildと全件のcheck-formal.shは追加していない。

```sh
python3 -B - <<'PY'
import importlib.util
from pathlib import Path
p = Path('crates/benitoite/tests/desugar_export/check_named.py')
spec = importlib.util.spec_from_file_location('check_named', p)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
manifest = m.read(m.MANIFEST)
entry = next(e for e in manifest['named'] if e['stem'] == 'generated-record-property')
directory = max(Path('target/generated-record-property').glob('export-*'), key=lambda p: p.stat().st_mtime)
m.check_named(directory, entry, manifest['namedVersions'])
extensible = max(Path('target/extensible-package').glob('export-*'), key=lambda p: p.stat().st_mtime)
m.check_extensible_package(extensible)
PY
```

実行時の入力は `target/generated-record-property/export-76540` と `target/extensible-package/export-76540` であった。これは今回の局所結果の記録であり、別の状態での結果の引用ではない。元の四件の期待は、HEADのcheck_named.pyを読み込み、同じ拡張可能な型の入力に適用すると `four extensible standard failure types` で失敗することも確認した（0.019秒）。

途中は次の関係検査だけを使った。外側の時間は未計測であり、テスト実行器が表示する時間とは区別する。

- `cargo build -p benitoite --example derive_inventory --bin benitoite`。生成前に読み取り用の Rust example を更新した。
- `python3 -B tools/derive/test_derive.py <PropertyGeneration の該当メソッド>` と `JsonGeneration`、既存の CLI の拒否例。新規の実行・拒否と既存の JSON の5件を確認した。
- `cargo test -p benitoite --test desugar_export export_generated_record_property`。Property と Codec の標準宣言を含む生成例を書き出した。
- `check_named.py` の既存の `check_named` を生成例だけに適用。manifest の定義27件・表層20件・アクセサ7件・網羅性4件を、独立した desugarDiff/builtinCheck/surfaceCheck/surfaceCheckAll/coverageProgramDiff で照合した。全入力の比較の成功とは呼ばない。
- `cargo run -q -p benitoite --example gen_skill`。再生成後の参照文書・bundle.rs に内容の差分はなく、手書きの SKILL.md の変更を保持した。

途中の失敗と修正は次のとおりである。

- 初期の生成は未提供の List.flatten、List.map/fold のラムダの契約名不一致、Random の as による import を通常の check が拒否した。既存の concatenate と、value の契約を保つ非公開の欄更新関数・部分適用へ直し、エフェクトを宣言する Random の import には as を付けず、対応する正例を通した。
- 新規の空レコードの準備は parser が拒否したため、許可していない構文を受け入れたことにせず、その準備だけを外した。非公開レコード・入れ子 Option・カスタム Character 欄の正例を検査した。この準備の見直しでは既存のテストに手を加えていない。
- 交換の新規の検査は識別名の前置きを fun と誤記して最初に失敗した。既存の交換器の fn へ直し、さらに公開のパラメータ名を厳密に照合する形にした。

## 計画からのずれと申し送り

R101で Integer の既定を全域とする具体化と、Property の提供開始に伴う旧拒否例の変更を記録した。旧拒否例は未対応型へ置き換え、終了状態・説明・標準出力なし・非書き込みの全assertを保持した。R102で生成例の交換用入力と manifest、G2 の ConversionError に対する独立比較側の古い四件の期待を五件へそろえた。既存入力は全定義が inScope である条件を保ち、新入力ではアクセサの内訳も固定した。R103で基準と重複しないlintの指定を計画へ反映した。

生成器と JSON の接続の主なテストは、本物の生成と実行を同時に扱う tools/derive/test_derive.py に置いた。property_library・l21_json・test_command の同じ契約は複製せず、work の全統合で既存の読者を確認した。実装コード（derive.py・宣言収集example）は145行追加・48行削除（差97行）、テストコード（test_derive.py・named.rs・check_named.py）は252行追加・7行削除（差245行）である。JSON と Property の型の参照・カスタム署名・依存の検証を Template に共通化した。

生成規則は `1.2.0-property`、Property ライブラリの規則は既存の `1.0.0` のままである。型の構造から欄間の条件を保証せず、その場合は型全体の手書き Gen/Shrinker を使う。

RV4 では生成・管理・JSON・通常@testの接続をレビューする。全件の形式化の比較・公開候補・版と訳の更新は V1 に残す。新しい独立入力は generated-record-property の stem で通常の desugar_export が書き出し、最終の check_named.py が manifest と照合する。formal/ の正式モデル・規則・定理・仮定は変更していない。コミット・docs/todo の操作は行っていない。
