# P1 の基準と対象一覧

## 目的と範囲

Q6・Q12、R1・R2、および plan.md の P1 に従い、後続の移行と検査の比較元を固定する。処理系・現行設計書・入力・期待値は変更しない。実行した検査と作業結果は [results.md](results.md)、ファイル別の移行候補は [migration.md](migration.md) に記す。

## HEAD と入力ハッシュ

| 項目 | P1 開始時の値 |
|---|---|
| HEAD | `dc375420073cf71f8fcd0a85aa4c29c19078715e` |
| study の基準 | `5ef09b51f4f5fabb321eab610ba0a709441d16eb` |
| 作業ツリー | `git status --porcelain=v1` の出力なし。追跡・非追跡とも変更なし |
| study の入力 | 1,195 ファイル、ハッシュ不一致 0 件 |
| study 入力集合の SHA-256 | `9dbee34a0d3c00c85c8a198283ac1ae9e912142ed78903513ccf8c34bd22ef81` |
| P1 の追加一覧 | 4,272 ファイル、Cargo 46 ターゲット |
| P1 入力集合の SHA-256 | `8228da8aa784c2067a758fb7549d3c48a319a5e0a3ea8826c00023e3e4bcc87a` |

集合の SHA-256 は、パス順に並べた `path + NUL + sha256 + LF` の UTF-8 バイト列から計算した。各入力のハッシュは [inputs.json](inputs.json) の files にある。シンボリックリンク 6 件はリンク先の文字列をハッシュにし、リンク先を重複走査しない。今回の改造ディレクトリ自身は集合に含めない。

旧基準から HEAD までの差は、この改造ディレクトリ内の文書・調査用 Python・JSON の 16 ファイルだけである。二つの study スクリプトを `python3 -B` で再実行した結果は、保存済み JSON と **head 以外の全項目が一致**した。HEAD の差に伴う件数・入力の差はない。保存済みの study は調査時点の記録として保持する。

| 再実行に使ったファイル | SHA-256 |
|---|---|
| `study/inventory.py` | `e03255f51b8b87cb33e944c4c51436d52add1faf5d7d2f9c7daf649aa3d77535` |
| `study/inventory.json` | `a8288647c9e3a2a809bc4e4a43135ebd4e4f10c61d75fe1a4014743caff71f55` |
| `study/failure-types.py` | `713ba55bc2379d8643b63a4414893d743ebe3f6c36effe39b29b9dab5ff4f921` |
| `study/failure-types.json` | `6c6573c757456cf5a9fce48f54af41060b53328cbe789e22ebe85352d743c1f2` |

## 四つの失敗型と既存の照合

標準ライブラリの `.bnt` 52 ファイル、公開 data/record 22 宣言、関連語 163 候補を再確認した。専用の公開の失敗型は次の四型である。以下のパスの `stdlib/` は `crates/benitoite/src/prelude/stdlib/` を表す。

| 型 | 宣言 | 現在の構成子数 | 新たに包括的な分岐が必要な既存の照合 |
|---|---|---:|---:|
| IOErrorKind | `stdlib/IOErrorKind.bnt:4`、data | 9 | 0 |
| NetworkErrorKind | `stdlib/NetworkErrorKind.bnt:4`、data | 9 | 0 |
| Json.ParseError | `stdlib/Json.bnt:15`、record | 1 | 0 |
| Csv.ParseError | `stdlib/Csv.bnt:4`、record | 1 | 0 |

IOError・NetworkError は不透明な組み込み型なので、構成子で照合できる型の対象から除く。Regex.compile・Encoding の復号・Time の変換と解析などが返す String は、失敗専用の宣言型ではない。Result・Option は設計者の指定により閉じた二択を維持する。残る 18 宣言（Json.Value、File.EntryKind、Process.Output、Time.DateTime など）は、失敗の種類・失敗そのものを表す型ではない。

| 既存の match の位置 | 対象 | 包括的な分岐 |
|---|---|---|
| `crates/benitoite/src/builtins/funcs/file/resource_tests.rs:660` | IOErrorKind | `case _` |
| 同ファイル `:726` | IOErrorKind | `case _` |
| `crates/benitoite/tests/l32_http_client.rs:331` | NetworkErrorKind | `case _` |
| `crates/benitoite/skill/references/idioms.md:152` | IOErrorKind | `case otherKind` |
| `docs/design/01-spec/01-09-errors.md:96` | IOErrorKind | `case otherKind` |
| `docs/ja/skill/references/idioms.md:155` | IOErrorKind | `case otherKind` |

6 件の本体を読み、既知の Other の列挙だけで済ませていないことを確認した。二つの ParseError を構成子で分解する match/bind は候補にない。`Json.ParseError.message(error)` などの getter、Result.Error(error) の error 全体の束縛、pure-json/Scan.bnt と wasm-json/Codec.bnt の構築は分解ではない。型名・個別の構成子名・別名 import・case/bind の別検索も行い、新たな分解は見つからなかった。名前解決のテストの `import ...Json as J` は import の検査であり、ParseError の分解を伴わない。

追加分岐 0 件は、今回調べた既存入力についての結論である。R2 による外部の record の分解の拒否、入れ子の網羅性、生成入力の網羅性を新規則で検査した結果ではない。D6c〜D9 で属性の受理後に両構成の全ターゲットと六入口を確認し、差が出たら型・照合・保持する契約を対応付ける。

## 全サンプルと全ターゲットの入力

[inputs.json](inputs.json) の files は、Git の追跡ファイルをパスごとの役割とハッシュに対応付けた一覧である。try のないファイル、期待値、依存の控え、生成器も含める。cargo_targets は `cargo metadata --no-deps --format-version 1` の 46 ターゲット（lib 1、bin 1、統合テスト 35、example 9）の入口である。入口が読む子モジュール、include_str、format!/concat! の材料は files で追跡する。fuzz はワークスペース外として別に files に含める。

| 区分 | 対象と後続作業 |
|---|---|
| 手本 | docs/design 全章のブロック・インライン、英語リファレンス、Skill 手書き、examples、現在の tools の入力と README。M2〜M4 で実行例を明示形にする |
| 標準ライブラリの実装 | IO/File.bnt の 1 候補と Network/Http.bnt の 2 候補。M4 で `or return` にし、戻り値・uses・失敗値を維持 |
| 検査 | testdata、Rust の lib/統合テスト、fuzz、ランダム生成器、開発用 stack_probe。裸の形と観測を保持。新処置の検査を別に追加する場合も既存検査を減らさない |
| 記法 | 構文名、EBNF、型/IR の擬似記法、用語の参照。他言語の try も一律に明示形へ変換しない |
| 歴史資料 | reference、docs/archive、過去の bench/skill-eval の記録、syntax-measure の比較実験の固定入力。編集しない |
| 生成元・生成物 | diag/codes.rs の実行可能な修正例と Skill の生成元を確認。生成 Skill は gen_skill で再生成。生成器の役割が検査か手本かも確認 |
| 翻訳 | docs/ja/reference・docs/ja/skill の 6 ファイルを一覧化。M8 で最終の英語版から訳す |
| 最小版リファレンス | 別枠で全文検索し try は 0 件。旧版へ未対応の構文を混ぜない |

study の抽出は 646 候補 / 166 ファイルで変わらない。これは AST の TryExpr の数でも、移行する例の数でもない。内訳と全ファイルは [migration.md](migration.md) にある。

補完の raw_hits はコメント・文字列・補間・Markdown のインラインも除かずに走査した位置の一覧である。try 1,040 件 / 220 ファイル、language 319 件、64 桁のハッシュらしい語 431 件を残した。Python の try、診断の用語、Cargo.lock のクレートの checksum も含むため、これらの増分を新たな Benitoite の実行例とは数えない。候補の位置はホストの行・文字列上の列であり、移行器の編集バイト範囲ではない。Rust の分割・復号・連結と括弧を含む正確な範囲は M1/M2 が確定する。

language の行頭だけを読む旧集計（102 候補 / 64 ファイル）に依存しない。M6a/M7 は raw_hits と files から、Rust の文字列/format!/concat!、tests/runtime_builtins.rs、現在の tools の参照解、package.bnt と依存の控えを再確認する。通常入力、旧/未来/不正な版の検査、ハッシュ不一致を試す入力、歴史資料を分け、通常入力だけを版と同時に更新する。Cargo.lock の checksum や過去の測定値を package の控えと混同しない。

## 裸の try の検査の基準

入力の保持は件数だけで判定しない。下表の契約に加え、inputs.json の study_try_candidates が持つ元ファイル・snippet・行・バイト位置・hold と、files の本体全体の SHA-256 を比較元にする。golden_try_baseline は該当 66 ファイルと同名の期待値・付属入力を対応付ける。全 testdata のハッシュも files にあり、パッケージの補助ファイルや離れた期待値を漏らさない。

| 主な持ち主の境界と既存の検査 | 維持する観測・捕まえる退行 |
|---|---|
| parser/effects.rs の try の表 | パイプを含む operand が Try の内側に入る。lazy/guard の E0218、外国語風の try/catch の E0235 と原因位置・回復、入れ子の上限。処置追加で既存 operand の末尾を変えない |
| typeck/effects/tests.rs::specification_examples_and_output_tables | first-release-try.bnt の三つが TryKind::Result、囲む loadConfig の戻り型と一致 |
| 同 ::try_infers_return_types_and_reports_incompatible_types | Option/Result の型推論、最内側ラムダ、入れ子 2 件、非 Result/Option の E0440、戻り型の E0441、失敗型の E0442、未解決型の E0407、help |
| 同 ::try_notes_follow_lambda_and_placeholder_return_boundaries | lambda と穴の作る関数の戻り型、診断 1 件、note・副位置。外側の型の誤りへ取り違えない |
| 同 ::try_error_type_escape_does_not_annotate_a_deferred_return_mismatch、rigid_types_keep_operation_names_in_body_diagnostics | 失敗型と流出した型変数の原因を保持。他の不一致へ try の脱出情報を誤転用しない |
| ir/desugar/tests.rs::try_reconstructs_failure_using_function_return_type_arguments | Result/Option の 2 分岐、失敗側 Escape が囲む戻り型を使う、成功側は入力の型、try の起点位置 |
| refinterp/tests.rs::escape_and_try_stop_at_the_called_function_boundary | 出力 `12\nbad\n`。失敗後の成功処理へ進まず、呼び出した関数の境界で戻る |
| testdata/eval/named_escape.bnt と types/todo178-placeholder-try-run.bnt | callee/引数の順序、穴で作った関数の try の戻り先。stdout と終了状態の厳密な比較を保持 |
| testdata/io/c12-with-try-release.bnt、refinterp のリソースの検査 | try による早期戻りでも Reader を解放。stdout `early\n` と、解放後の使用の失敗を含む既存の期待を保持 |
| testdata/effects/c11-try-not-result.bnt、types/todo178-placeholder-try-error.bnt | E0440 / E0441 の主文・位置・help、穴の関数の副位置と note。別の早い拒否へ付け替えて通さない |
| formatter/print/tests.rs の PARENS と with の表 | `try(f(x))` の正規形 `try (f(x))`、リソースの裸の try、二度目の整形の一致 |
| tests/random_programs/generator.rs と random_programs.rs | try-option/try-result の生成・必要項目の到達、Result/Option の成功/失敗、VM と参照実行の一致。生成件数・時間制限・対象外理由を維持 |
| tests/desugar_export.rs と tests/desugar_export/、tests/coverage_export.rs | 元入力と生成入力の交換、通常入力の振り分けと corpus の厳密な照合。六入口の実行自体は D/B の指定作業で確認 |

testdata の 195 候補 / 66 ファイルは、run 144 候補 / 43 ファイル、check 15 / 9、test 4 / 3、mode なしの補助 32 / 11 である。成功するコードだけの件数ではなく、負の入力も含む。Rust ホストの 206 候補 / 38 ファイルは lib 側 115、統合テスト側 89、開発用 example 側 2 である。lib 側には診断の文言や生成元も含むため、206 件すべてを裸の try の実行検査と見なさない。

M5 ではこの表と元の入力・assert・期待値を照合する。手本を兼ねる例を明示形へ移すときは、同じ境界で裸の形の既存の観測を保持する。全ファイルのハッシュが変わったこと自体を弱化と判定せず、具体的な契約と観測の差をレビューする。

## 前回 G1〜G8b と今回の関門の対応

前回の記録は作業漏れの調査だけに用いた。仕様の根拠は現行の設計書と今回の design.md・decisions.md である。参照先は `docs/archive/2026-10-14-TODO-247-lambda-and-named-arguments/reviews/` の各報告である。

| 前回の所見 | 今回の作業・関門と確認する証拠 |
|---|---|
| G1: 内外の短いラムダ、do/then、演算子の後の誤導する help、本文と実装の不一致 | A1/A2、B6/B7、K4/K6/K8。現在の深さだけで処置を読む、改行と括弧の対照、診断位置、AST の意味・整形の冪等性 |
| G2: NamesWF による前提の追加、型クラスの実装名がモデルにない | P2、D1〜D4/G2、B1〜B5/G4、K5。変更前後の言明と定義、前提の一覧、交換で運ぶ情報の対応表 |
| G3: 型保存だけでは評価順・値の配置を保証しない | B2/B5/B10a-2/B12、K5。定理の保証と実行の観測を分ける。独立した期待コアで失敗側だけの let・一回性を確認 |
| G4/N7: 辞書付きの実装名の JSON 接続、axiom 監査の対象漏れ | D4、B4/B5/B10a-3、K5。六入口、独立した正負の入力、定義も含む sorry/axiom 依存と言明の確認 |
| G5: 型検査とコア検査の受理の差、遅延した呼び出しの型、旧経路の暫定差 | D6/B10a/B11、K1/K4/K5/K8。表層→型→脱糖→コア→交換の一貫した検査。暫定の未接続は作業と解除時期を明記 |
| G6: 注釈だけの入力の振り分け漏れ、順序で変わる受理、文脈の復元漏れ | D5/D6b/D6c、B4/B10a-3/B11、K5。属性だけ/新処置だけの入力も通常の全出力へ残す。局所注釈や入れ子の前後も比較 |
| G6: 全入力の JSON を同時保持してメモリ増大 | D6b/B10a-3、K5。既存の一入力ずつの出力を維持し、件数・対象外理由・ハッシュを照合 |
| G7: const の特殊経路、診断の付け替えと副位置の消失、spec の印 | D8、B10a-1/B11、M3/M6/M7、K2/K4/K6。元の失敗理由の維持先、主文/help/主副位置/終了状態の旧→新の対応 |
| G8a: 手書きの複数行例・仕様の一般例・診断の生成元の移行漏れ | P1 の raw_hits、M1〜M5、K6。全ブロック/インライン/コメント/文字列の分類、E0201 question と生成物、全サンプルの確認表 |
| G8a: tests/runtime_builtins.rs の旧入力が個別検査をすり抜けた | P1 の cargo_targets/files、A3/D9/B14/M7、K1/K7。各段の両構成 workspace all-targets と、版・固定ハッシュの入力一覧 |
| G8a: 通常の検査が改造ディレクトリの manifest に依存 | M1/M2/M5/M9、K の作業記録の規約。通常の manifest は tests/formal/tests に置く。P1 の一覧と集計は通常の検査から読ませない |
| G8a/G8b: Lean の写し、最終規則と文書/訳/生成物の不一致 | D9/B13/M3/M5/M8、K6/K8。先行モデルの注記と解除、写しのその場の更新、英日と生成元の照合 |
| G8b: 新診断・付け替え・推奨の CHANGELOG の漏れ、E0908 が一変更固定 | M6/M6a/M7/M9、K4/K6。全変更の help、版境界、移行と診断の対応、通常入力と固定ハッシュの同時更新 |

## 後続で使うときの条件

P2 はこの基準から型・依存・診断・定理の対応表を作る。M2 は候補を本物の AST へ対応付け、編集範囲と処置を一件ずつ確定する。M6a は、その時点の入力へ一覧を更新して版と固定ハッシュの patch を先に示す。P1 の JSON は比較用の記録であり、適用可能な manifest ではない。旧移行器の BASE や確認済み manifest を今回へ流用しない。
