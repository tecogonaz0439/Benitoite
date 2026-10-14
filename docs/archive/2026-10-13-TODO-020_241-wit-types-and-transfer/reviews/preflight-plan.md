# 実装プランの事前点検

2026-10-13。P1〜P40 を現行コード・設計書・詳細設計 C・Q1〜Q14 と突き合わせた。
大枠の分担は使えるが、【重大】の指摘が 6 件あり、そのままでは途中のビルド・実行または完了の判定を保てない。
最も重い点は、P32 の共有条件と構築予算の食い違い、P33 の公開が上限と失敗の分類の完成より先になることである。
ほかに、凍結したコア定数の承認漏れ、演算子の専用命令への誤った振り分け、実行されない形式化の検査がある。
点検時の HEAD は `a85be5fb580884bf1cfbcec5c3d9cfc7500a0685`、観測したブランチは `mod/P1` であった。P1 の並行変更は読むだけとした。
以下の `src/`・`tests/`・`testdata/` は `crates/benitoite/` の下を指す。箇所は並行変更に耐えるよう関数・型名を主に示す。
計画のコマンド・テスト・測定は実行していない。時間超過の指摘は責任範囲からの見積もりであり、実測ではない。

## P1 への補足

- `formal/Benitoite/Release/Syntax.lean` の `Const.patternAllowed`・`Const.matches` と `Surface/CheckPatterns.lean` も責任範囲に含める。新しい定数を追加した直後から、定数パターンを許さない判定を揃える必要がある。
- `Exchange/Convert.lean` の `baseTy`・定数の変換など、Release の列挙に依存する読み手のビルド修正は P4 を待てない。P1 では既存入力の互換と網羅性、P4 では新しい入力の受理を担当する、と分ける。
- 保存・進行に加え、型代入・正準形・網羅性の証明まで変更するため、55 分の見積もりには余裕がない。既に着手した P1 の残作業を証明群ごとに数え、未完了なら基本定義と証明更新を分ける。

## P2 への補足

- P2 以降の「依存: 直前のレビュー完了」は共通規則と Q14 の「まとまりごとにレビュー」と食い違う。各作業の依存を先行実装と短い検査の完了とし、まとまりの境目だけレビューを条件にする。R23 の「一作業ずつレビュー」より後の Q14 を採る。

## P5 への補足

- `src/prelude/mod.rs` の `STDLIB` へ加える各モジュールの `prelude` の値を明記する。新しい型・正の名前・`UnsignedInteger` を import なしで使うかで名前解決と生成文書が変わるため、担当者の判断に残さない。
- `src/resolve/collect.rs` の標準モジュール内の組み込み型の採集と `stdlib_names` の索引にも別名を登録する。ルートの型名だけを追加すると、`Integer64.Integer64` などの修飾名や import したモジュールから同じ ID を引けない。

## P6 への補足

- 現在のゴールデンの場所は `testdata/lexical/` であり、`testdata/lex/` はない。新しいディレクトリを作る理由がなければ既存へ足す。
- `testdata/fmt/` のケースは `tests/fmt_command.rs` からは読まれない。整形のケースを足すなら `BENITOITE_GOLDEN_FILTER=fmt cargo test -p benitoite --test golden` を加える。字句のゴールデンも選ぶなら `BENITOITE_GOLDEN_FILTER=lexical` で同じ実行器を走らせる。

## P7 への補足

- 【重大】`ConstValue` の追加は、P10 の `src/ir/desugar.rs::constant`・`bytecode/codegen/tables.rs::const_value`、P36 の `tests/desugar_export/exchange.rs::constant`・`Surface::literal` の網羅的な照合を直ちに壊す。追加と同じ P7 で読み手を更新する範囲を具体的に列挙し、P10・P36 へビルド修正を先送りしない。
- 算術を受理する入口を P7 で開くと、P11〜P14 の本体と表が揃う前に `ir/desugar/exprs.rs::binary_prim` が `missing operator_builtin` を返す。各幅の入口を本体完成と同時に開く順序と、途中で拒否する診断を明記する。
- 現行のリテラル・演算子の生成は `src/typeck/generate.rs::literal/binary/unary`、制約の解決は `solve.rs` にある。`exprs`・`constraints` という実在しない子モジュール名を実ファイルへ直す。
- Float32 の鍵の拒否は `solve.rs::bounds` だけでなく `typeck/decls.rs::summary` と `ir/check.rs::satisfies` にも要る。現在はいずれも Float だけを例外にするため、Float32 を含むレコード・data の鍵の判定も P7 から揃える。

## P8 への補足

- `src/typeck/consts/key.rs` で新しい整数の Map/Set 定数を扱うには、P14 の `base/prim.rs::KeyAtom` の追加が先に要る。KeyAtom と定数用の順序を P8 へ前倒しし、実行時の値の比較を P14 に残す。
- `testdata/typecheck/` はなく、既存は `testdata/types/` と `testdata/warnings/` である。const の拒否と通常式の警告をそこへ置く場合、`--lib typeck::consts` だけでは読まないため、それぞれのゴールデンを選ぶコマンドも指定する。

## P10 への補足

- 【重大】`src/ir/core_ir.rs::Const` は新しい七種を持たず、`ir/desugar.rs::constant` から VM までの定数の経路に必要な追加が計画と C の Q13 の表から漏れている。10-06 の `file=src/ir/core_ir.rs` に凍結した型なので、AGENTS.md「型とシグネチャを変えない」に従い、追加範囲の承認を実装前の前提へ加える。Q13 の既存回答で了承済みと扱わない。
- `src/codegen/tables.rs` はなく、正しくは `src/bytecode/codegen/tables.rs` である。`Core Const` の表現の等値・`ir/check.rs::constant_type`・`bytecode/codegen/emit.rs::const_ty` と参照インタプリタの定数も責任範囲へ明記する。
- `ConstDesc` の追加では `src/bytecode/codegen/tests.rs::nested_constants_are_shared_and_children_precede_parents` など、テスト側の網羅的な照合も同時に直す。C0 の `--all-targets` はこれらもコンパイルする。

## P11 への補足

- 【重大】`src/builtins/table.rs::builtin_intrinsic` は `EntryKind::Operator` をすべて `Intrinsic::Operator` にする。新しい幅を `OPERATORS` へ足すだけでは、`bytecode/codegen/emit.rs::plan` が `unsupported operator and operand type` で止まり、C の「既存の組み込み呼び出しへ脱糖」を実現しない。
- 旧型だけを専用命令にし、新しい七種は `builtin_intrinsic` で `None` とする変更を P11 へ含める。P12・P13・P14 もこの条件を使い、旧命令の分岐を保つ。
- `table.rs::tests::internal_lookup_functions_supply_the_language_types_and_intrinsics` は全演算子が専用命令を持つと期待している。この契約を新しい区分へ更新し、`cargo test -p benitoite --lib builtins::table` でも確かめる。

## P13 への補足

- NaN の比較を P13 の完了条件にするなら、P14 の Float32 の比較・等値が先に要る。算術の丸め・零・除算を P13 の主な確認とし、NaN の等値・大小比較・Order の相違は P14・P18 へ割り当てる。

## P14 への補足

- `src/builtins/table.rs::OPERATORS`・`INTERPOLATION` の追加も明記する。比較・補間の本体だけでは脱糖がその関数を引けない。新しい `toString` の Rust の本体と登録は P14、標準モジュールの公開宣言は P15〜P17、と分けると依存が揃う。
- 新しい数のパターンの拒否は P7 に加え、`src/ir/check.rs` の定数パターンの判定にも反映する。型検査を経ないコア IR の検査で新しい Const を受け付けてしまわないようにする。

## P18 への補足

- C の 5 節は組み込み呼び出しの変更にも G を求めるが、P15〜P18 の完了条件にはない。少なくとも数の本体と表を揃えた P18 に G を加え、P15〜P17 で旧共通部を変える場合も適用する。
- 最後の測定に渡す「数の追加後」の release バイナリは P18 の時点で別の場所へ保存し、版・機能・大きさを記録する。最後になってから同じ `target/release` の上書き済みファイルでは復元できない。

## P19 への補足

- `src/external/tests.rs::unmapped_component_types_omit_declaration_notes` は `s32` と `list<s32>` に宣言の修正案が付かないことを期待している。幅の逆変換を追加する同じ P19 で期待値を更新する。指定の `--lib external::` はこの既存試験も走らせる。
- `WitPlan` の追加時は `mod.rs::TypedKind::of`・`ExternalRoute::of`、`convert.rs` の予算・子の走査・両方向の変換、`types.rs` の各表示も同時に更新する。型付きの具体化を増やさない条件は `TypedKind` を増やさず `None` を返すことで保つ。

## P20 への補足

- `src/external/tests.rs::generic_recursive_and_multi_argument_types_are_rejected_before_reading_components` の Generic の二行は P20 で成立しなくなる。再帰と複数引数の拒否は必要な作業まで残し、具体的な型引数の受理を同じパイプラインの境界で確かめる。
- 現在 `external::types` にテストはなく、既存試験は `external::tests` 配下である。`tests.rs` へ追加するなら `cargo test -p benitoite --lib external::tests::generic` など実名に合うフィルタへ直す。既存の指定のままなら新しい型モジュール内の試験が必要になる。
- `typeck/external.rs::contains_external` は型引数をすべて辿り、各宣言を一度だけ調べる。具体的な代入と「使われる欄だけ」の判定へ変更し、`Phantom[外部の型]` のような未使用の型引数に State を要求しない確認を明記する。

## P21 への補足

- `src/runtime/map.rs` が再公開する Cursor は `pub(super)`、`map/tree.rs::Cursor` と `map/set/next` は `pub(in crate::runtime)` であり、`external` から呼べない。Set 用の本番の走査入口を `pub(crate)` で設ける変更を P21 の責任範囲に含め、P22・P26 でも使う。List の既存カーソルとは可視性が異なる。

## P22 への補足

- `src/external/convert.rs::check_arguments` と統計の戻り値の計数も map の責任範囲へ加える。動的な map は一組に `size_of::<(Val, Val)>()`、子の可変長の量も加算する。Wasmtime 49.0.2 の一次資料は `/Users/tecogonaz/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/wasmtime-49.0.2/src/runtime/component/values.rs:1051–1090` の `load_map`（[版を固定したソース](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/crates/wasmtime/src/runtime/component/values.rs#L1051-L1090)）である。
- `src/external/tests.rs::unsupported_types_are_rejected_at_the_declared_type` は `Map[String,Integer]` に E1010 を期待する。対応後は WIT との不一致へ進むため、この行を更新し、未対応鍵の拒否を残す。

## P23 への補足

- P20 から残る `src/external/tests.rs::generic_recursive_and_multi_argument_types_are_rejected_before_reading_components` の Many の拒否も、この作業で更新する。従来の一構成子 variant を tuple へ決め打ちしない試験は残す。
- `convert.rs` の既存 Tuple は `tags::PAIR/TRIPLE` を使うため、新しい組のタグ・欄の分配は新しい WitPlan の種類で扱う。型の照合だけでなく、引数の予算・子の走査・戻り値の組み直しの各読み手も責任範囲へ明記する。

## P26 への補足

- C の 8.3 は magic の幅だけを定め、実際の 4 バイトと不正な版の扱いを定めていない。P26 で版 1 の固定値、ヘッダの整合、詰め物・非選択領域の規則を一つの wire の定義へ置き、P27〜P31 が同じ契約を使うようにする。
- 根の record や ABI の tuple は言語の値とは限らない。構築予算の加算位置を「言語の出現」として表に定め、ABI の都合の中間の組を余分に数えない。共有時に変わる費用は P32 の指摘を解決してから生成器へ渡す。

## P27 への補足

- `src/runtime/list.rs::from_iter_exact` は `Iterator<Item=Value>` だけを受ける。入れ子の復号・値の確保は Stop を返しうるので、既存の関数へそのまま渡せない。要素ごとの失敗を返せる本番用の葉の構築入口を別に追加し、既存シグネチャを保つ。全要素の `Vec<Value>` へ戻して解決しない。
- 転送形式全体の検査と、言語の値の構築を明確に分ける。Map の重複で消える値も前者で検査・予算へ含め、後者でのみ正規化する。

## P28 への補足

- 確保器・報告関数の取り込み・コア命令生成・コンポーネント合成・直接／間接の数の往復を、初めて一つにつなぐ作業である。55 分の超過が懸念されるため、「メモリ・realloc・失敗の接続」と「固定値の呼び出しと合成の検証」に分ける案を推す。
- `adapter-fail` の段階・条件の番号と Rust の専用エラー型は P35 ではなく P28 で定義し、試験の Linker で確認する。P35 には報告と統計の仕上げを残す。番号の割り当てを各 emit の担当者へ委ねない。

## P29 への補足

- string/list の行き帰り、入れ子、0 サイズの要素、UTF-8、予算の検査まであるため、55 分の超過が懸念される。文字列と単純なリスト、入れ子と結果の再配置・予算の二段に分ける案を推す。
- 宣言の深さだけで Wasm の呼び出しの深さが増える形と、要素数だけで作業領域が増える形を分けて点検する。C の 8.4 の明示した作業列・Wasm のループをこの作業の条件にも記す。

## P32 への補足

- 【重大・要判断】C の 8.2／R19 は WIT の形だけで生成コードを共有するが、9.1／R21 の構築予算は言語の値の出現を数える。同じ `list<u8>` でも Bytes と List[Byte] で費用が違い、`One(Pair[A,B])` と `Two(A,B)` でも構成子の数が違う。ヘッダの「構築予算」の上限値だけから、共有した補助は正しい費用を決められない。
- 推す修正 A: タグ番号を除いた「構築量の数え方」を生成・共有の鍵と書き出しへ加える。判定は単純になり、作業量は B より小さいが、補助の Wasm が増えうる。ホスト実行ファイルの増分・性能は未確認で、言語の中核の意味は変えない。C／R19 の変更として設計者の判断を得る。
- 代案 B: 数え方を実行時の追加データで渡し、共有する補助で解釈する。共有は保てるが、転送形式と走査の実装が増え、転送量と命令数も増える。実行ファイルの増分・性能は未確認で、中核への影響はない。単に全宣言の最大費用を使うと、本来通る Bytes の値まで拒否する。
- 解決後は、同じ WIT の書き出しを異なる言語の形で宣言し、小さい構築上限で結果が各宣言の費用どおりになる試験を P26・P29〜P32 へ割り当てる。

## P33 への補足

- 【重大】補助経路の利用者の入口を P33 で開いた後、P34 で上限、P35 で専用エラーの分類を完成させる順序は、共通規則の「経路が揃うまで公開しない」と C の 9 節を満たさない。P33 は内部の接続までとし、P34・P35 の処理と必須試験が通った最後に経路を切り替える順序を推す。
- P32 の共有単位に合わせ、`ExternalRuntime.components` の元ソース単位のキャッシュと、補助のコンパイル済み Component のキャッシュを分ける必要がある。同じ元コードの resource の経路と補助の経路が互いを上書きしない管理を明記する。

## P36 への補足

- 【重大】`tests/desugar_export.rs::export_desugar_corpus` は `#[ignore = "formal: ..."]` 付きで、計画の `cargo test --test desugar_export` では走らない。`lake build` も入力の読み込みと比較を行わないため、指定コマンドだけでは「出力・読み込みできる」を確認できない。
- 全 corpus を `--include-ignored` で走らせると、最後の全体検査を前倒しすることになる。短い新しい数の入力だけを既存の書き出し処理へ渡す試験と、その JSON を `desugarDiff`・`builtinCheck`・`surfaceCheckAll` に渡すコマンドを具体的に定める。通常の Rust テストが数件走ったことを接続の確認として数えない。
- Rust の交換形式のコンパイル修正は P7・P10、意味の対応と短い往復は P36 と分ける。符号付き最小値・u64 上半分・Float32 のビットと各幅の演算を含め、対象外の表示で除外されていないことも確認する。

## P37 への補足

- `docs/design/01-spec/01-08-evaluation.md` の「整数の溢れ」と「0 による除算」の表も変更対象へ加える。現在は Integer の範囲と関数だけを具体的に列挙しているため、新しい幅・符号なしの減算・各標準関数の停止条件を追加しないと、01-04・03-06 と実行時エラーの一覧が食い違う。

## P38 への補足

- `tests/spec_examples.rs::spec_files` は `01-spec/` と付録 08-04 を読む。`cargo test --test spec_examples` は 03-10 の外部の関数の例を検査しない。P38 の例を `testdata/external/` の本物のゲストのケースに対応させ、該当ゴールデンを走らせる条件へ直す。
- 前段・中間表現・VM・ランタイム・外部境界・CLI・安全モデルの 12 章を一作業で更新して検査するため、55 分の超過が懸念される。数の表現とコンパイラの章、外部境界と上限・報告の章へ分ける案を推す。

## P39 への補足

- `src/cli/tools/skill/generate.rs::module_reference` は標準モジュールの AST だけから文書を作り、組み込みの型の表を読まない。P5 で表だけへ登録した別名・正の名前も生成文書に出るよう、この作業で名前の表を参照する箇所と期待する表示を定める。薄い関数の宣言だけでは型の同一性の説明は生成されない。

## P40 への補足

- 九種類の契約のゲスト・入力・再生成のソースと、計時・RSS・統計を集める新しい道具を同時に作るため、55 分の超過が懸念される。P19〜P36 の独立したゲストを再利用する範囲を列挙し、比較入力と記録の道具を分ける案を推す。
- `ExternalRuntime` のキャッシュは実行内だけに生きる。繰り返しは同じ Benitoite の実行内で外部の関数を複数回呼び、別プロセスでの初回と区別する。生成・コンパイル・インスタンス化・実行を分ける時間の取得箇所を測定用の例で明記し、既存 stats の合計だけから推測しない。
- 数の追加後は P18、補助の追加後は経路を完成させた時点で release を保存する条件を前の作業へ戻す。`--quick` はその二つの中間版を再ビルドせず、用意した小さい入力と最終版の動作だけを確認する。
