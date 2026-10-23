# F4a 書式の型集合・適合と回復の接続

2026-10-23、実装担当。基準 B_WORK は `7c492d86d7eb62ca07d150f8dbe794fb72c3b595`。作業は `mod011/F4a` で行い、開始時の差分はなかった。

## 変更と作業範囲

- `TySet` に、Byte を含む整数八型の `FORMAT_INT`、小数三型の `FORMAT_FIXED`、符号・ゼロ埋め用の数十一型の `FORMAT_NUMBER` を加えた。幅・寄せだけは従来の14型、`s` と `c` は各一型、これらと符号・ゼロ埋めの併用は空集合とする。構文の妥当性は既存の解析器へ委ねた。
- 書式付きも通常の `OneOf` 制約で検査し、`ReasonKind::InterpFormat` に値と書式の元位置を保持する。具体化した型は既存の `TypeckOutput.interp_types` に、書式なしと同じ式のノード番号で記録する。AST の書式と各部分の span は変更しない。
- E0468 を登録し、コロンを含む書式全体を主位置、値の式を関連位置として、実際の型と許す型を示す。整数への `f` には `d` か意図に応じた明示変換を案内し、自動修正は付けない。型パラメータには E0468、未確定な推論変数には既存の E0407 を使い、書式なしの E0422 は保つ。
- C2 の由来をそのまま利用し、型全体が診断済み原因から未知になった値の E0468 を抑える。`List[Error]` などの既知の外側、束縛自身の明示契約、正常な関数が宣言した結果型からの不適合は残す。既存の書式なし・演算子の回復の条件は変えていない。
- 一時防御を制約生成中から `Body::solve` の末尾へ移した。`pending_formats` に書式の元位置を記録し、適合・回復・後検査を終えてから E0262 の未接続の注記で拒否する。定数も評価に入る前に止まり、既存の定数評価器と脱糖の防御も残る。
- 01-06・02-05・02-10 を現在の実装へ揃えた。途中状態の説明がある 01-02・02-03・英語リファレンスも更新し、`gen_skill` で診断一覧を作り直した。

## 検査の指定と結果

コマンドはリポジトリの根から実行した。途中の rtk のラッパーは省略して表記する。失敗の詳細と外側の時間を保存する実行は通常のコマンドをログへ出し、外側の時間は `/usr/bin/time -p` で測った。途中で外側を測っていない実行は未計測と記した。

作業末の指定 W は次のとおりである。計画の declarations・golden に、変更した構文の章・英語リファレンス・生成 Skill・一時防御の CLI を読む四ターゲットを追加した。

```sh
scripts/check.sh --level work --base 7c492d86d7eb62ca07d150f8dbe794fb72c3b595 --test declarations --test golden --test spec_examples --test reference_examples --test skill_docs --test fmt_command
```

| コマンド | 終了状態・結果 | 外側の時間 |
|---|---|---|
| `cargo test -p benitoite --lib typeck::tests::interpolation_formats::format_type_matrix_and_locations -- --nocapture`（E0468 の登録後、適合を未接続の状態） | 101、追加した受理表の検査が失敗することを確認 | 未計測、Cargo の検査表示0.21秒 |
| `cargo test -p benitoite --lib typeck::tests::interpolation_formats:: -- --nocapture`（途中に複数回） | 最終は0、2件成功。14型×21書式の294組、UTF-8・CRLF の元位置と型表、別名・通常の型パラメータ・Show制約・未確定型・書式なしを確認 | 最終12.46秒、途中は未計測 |
| `cargo test -p benitoite --test declarations interpolation_formats_preserve_recovery_and_execution_guard -- --nocapture`（途中に2回） | 最後は0、1件成功。3原因×6対照の18入力と関数・定数の2防御を確認 | 未計測、最後の Cargo の検査表示1.23秒 |
| `cargo build -p benitoite --examples` | 0、AST・型情報の読者を含む全 examples のビルド成功 | 15.12秒 |
| `cargo fmt --all`、`cargo run -p benitoite --example gen_skill` | 0、整形と生成を実施。生成物の変更は診断一覧だけ | 最後の生成14.64秒、途中は未計測 |
| W に `--dry-run` を追加 | 0、fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally を選択。仕様例・リファレンス例・Skill文書は tests_related にまとめることを確認 | 0.07秒 |
| W | 0。fmt・clippy・ソース規約・生成 Skill の照合・仕様集計成功。lib は1,269件成功・21件ignore。declarations は24件成功・1件ignore、fmt_command は21件、golden は2件、reference_examples は1件、skill_docs は8件、spec_examples は7件が成功 | 185.96秒 |
| `scripts/check.sh --level work --base 7c492d86d7eb62ca07d150f8dbe794fb72c3b595 --only fmt,lint_default --dry-run` | 0、固定文言の移動後に関係する整形とclippyを選択 | 0.00秒（表示精度未満） |
| 上と同じ指定の実行（`--dry-run`なし） | 0、fmt・clippy成功 | 7.22秒 |
| `cargo test -p benitoite --lib typeck::tests::interpolation_formats:: -- --nocapture`（固定文言の移動後） | 0、局所2件成功 | 5.64秒 |
| 変更した設計書5文書と英語リファレンスの既存見出し・相対リンク・フェンス・末尾空白の Python 確認 | 0、6文書成功 | 0.08秒 |

途中の失敗は、書式全体の span がコロンを含むのにテストが含まない位置を期待したこと、利用者のソースに内部専用の `ordered` を書いたこと、短いラムダの終端を省略して次の文まで含めたこと、テスト用の `main` が String を返したことによる。型の適合を調べる入力を本来の構文と入口の契約へ直した。型の取り出しを確かめるテストの `Box<Expr>` の参照も修正した。期待する診断の削除や、既存の入力の大きさ・ignore・時間制限の緩和は行っていない。

作業末の検査中の自己確認で、空集合の説明の固定文言を `typeck/text.rs` へ移した。文言の内容と振る舞いは同じである。先に実行したfmt・clippyと、E0468の空集合の説明を通る型検査の局所2件を再実行した。成功した他の対象は重ねて実行していない。

最終の静的確認でも、6文書と本記録のフェンス・末尾空白、既存文書の見出し・相対リンク、`git diff --check` が成功した（外側1秒未満）。本番のRustは131行追加・15行削除、テストは270行追加・削除なしである。F4aの範囲に未実施・未解決の検査は残っていない。

## 計画からのずれと申し送り

- 一時防御を後検査の後へ移すため `context.rs` を、理由の種類を保持する読者として `infer.rs`・`solve/effect_key.rs` を、固定文言の配置に `text.rs` を変更した。既存の型情報表の形式と実行用 Ty は変えず、形式化・交換・ヒープ・VM・参照評価器は変更していない。
- テストは型検査の公開境界の二つの表と、公開パイプラインの一つの表にまとめた。書式の無視、Byte の漏れ、数以外への符号・ゼロ埋めの許可、回復の由来の取り落としと過剰な抑制、型表・元位置の欠落を捕まえる。既存の書式なし・解析・整形のテストはこの適合検査を通らず、公開パイプラインの表は SourceLocation の誤用を Error へ置き換える経路と実行拒否を別に確かめる。テスト用の公開API・フラグ・差し込み口は増やしていない。テストの削除や監査は行っていない。
- F4b は `interp_types` の具体化した型と `InterpSegment.format` の解析済み書式・元位置を使う。型と書式の不適合は E0468、未知は E0407、書式なしは E0422 である。値側の由来を利用側の期待型で置き換えない。
- F4b が定数評価・脱糖・全実行経路を接続した後に、`generate.rs` の `pending_formats` への登録、`context.rs` のフィールド・初期化・`solve` 末尾の E0262、`consts.rs::eval_interp` と `ir/desugar/exprs.rs::interp` の既存の拒否を外す。E0262 の `pending` の文言と文書の途中状態、今回の関数・定数の防御の期待、既存 fmt_command の実行拒否の期待も同じ変更で更新する。F4a だけでは書式付き機能全体の完了ではない。
- 言語の規則や Lean の主な定理の前提・結論、公理を変える判断は生じていない。ヒープの不変条件・安全点を越える保持方式を変えていないため、追加の heap/stress・Miri・Lean 全比較はこの作業では実行しない。全比較は F5 と最終候補に割り当て済みである。
- 取り込み後の short 測定、独立レビューと受け入れは取りまとめの担当である。change・release、版上げ、翻訳は担当外である。private とそのリンク、docs/todo、過去の文書は読んでいない。git の変更操作・コミット・取り込み・公開操作は行っていない。
- 作業中に `reviews/RV-F13.md` が未追跡ファイルとして現れた。F4aが作成・編集したファイルではなく、担当外のまま保持している。

## 取りまとめの性能の比較 short（F4a の取り込みの後）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=78c34404b4283c4731d460ce6bd87a81fe440960 --name batch5-f4a`（比べる元は decisions.md の D41）。
- 終了 0、外側の時間 108 秒（ビルドを含む）。
- 判定: 63 点が「判定不能」、残りが「達成」（しきい値の内側）。W1 比で higher-0-300 +3.3%、functions-modules-1000-1 +3.8%。退行の疑いはない。
- 記録: `tools/bench/results/2026-10-23-78c34404-batch5-f4a/`（手元の絶対パスは `<repo>` に伏せた）。
