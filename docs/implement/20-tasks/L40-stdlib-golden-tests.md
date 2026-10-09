# L40 標準ライブラリのゴールデンテスト

- 依存する作業: [L01](L01-unicode-functions.md)〜[L03](L03-bytes.md)、[L10](L10-console-clock-process.md)〜[L14](L14-random.md)、[L20](L20-path.md)〜[L25](L25-encoding-and-hash.md)、[C10](C10-golden-runner.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 大（テストのスクリプトと期待値が多い）
- ブランチ: impl/L40-stdlib-golden-tests

## 目的

[ADR 0137](../../design/decisions/0137-first-release-library-scope.md) が初回リリース版に入れた各モジュールの主な機能を、スクリプトとして確かめるゴールデンテストを、`stdlib` と `io` の区分に加える（07-03「ゴールデンテストの形式（初回リリース版）」）。組み込みの関数の意味は、項目ごとの単体テスト（L01〜L25）が確かめた。本作業は、利用者のスクリプトから、非公式のモジュールの取り込みの名前、型、エフェクト、関数の組み合わせが期待どおりに働くことを、CLI と同じ経路で確かめる。ネットワークの区分は L33 が書く。

## 読む設計書の節

- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「ゴールデンテスト」「ゴールデンテストの形式（初回リリース版）」「差分テスト」（どのテストが差分テストの対象になるか）、「テストの設計の原則」
- [標準ライブラリ](../../design/03-interop/03-06-stdlib.md)、[IO のモジュール](../../design/03-interop/03-07-io-modules.md)、[テキストとデータの処理](../../design/03-interop/03-08-text-and-data.md)（各章の例）
- [標準ライブラリ](../../design/03-interop/03-06-stdlib.md)の「標準のモジュールと非公式のモジュール（初回リリース版）」
- ADR: [0137](../../design/decisions/0137-first-release-library-scope.md)、[0224](../../design/decisions/0224-golden-test-format-for-first-release.md)、[0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)、[0322](../../design/decisions/0322-stdlib-details-from-u3-preflight.md)、[0327](../../design/decisions/0327-fmt-symlink-and-process-attached-details.md)、[0328](../../design/decisions/0328-path-and-json-details-from-u3-preflight.md)、[0329](../../design/decisions/0329-csv-and-time-details-from-u3-preflight.md)（U3 の事前点検で決めた細部。境界の規則をテストの材料にする）

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の全体（ソースの宣言が、スクリプトから使える関数と型の一覧である）
- C10 の作業の文書（ゴールデンテストの形式と実行器、`.files/`・`.stdin`・`.args` のファイル、テストごとの一時ディレクトリ、回収の強制と差分テストの対象の選び方）

## 作るもの

- `crates/benitoite/testdata/stdlib/` と `testdata/io/` のゴールデンテスト

## 手順の要点

- モジュールごとに、少なくとも一つのテストを置く。03-06〜03-08 の章の例（`totalAmount`・`extractDates`・`fingerprint`・`countLines` など）は、非公式のモジュールの import を取り込みの名前（`import Benitoite.Unofficial.…`）に書き換えてテストにする（ADR 0286 の帰結）。章の例の `import Benitoite.Json` の形をそのまま写すと、E0321 になる。
- 取り込みの名前: 非公式のモジュールを `import Benitoite.Json` と書いたスクリプトの `check` が E0321 と、正しい取り込みの名前への修正案を示すことを、`check` のテストとして置く（診断の文言は期待値として記録する）。標準のモジュール（`Bytes`・`Map` など）は import なしで使えること、`import Benitoite.Unofficial.Bytes` が E0321 になること。
- `io` の区分のテストは、C10 の実行器がテストごとに作る一時ディレクトリを基準のディレクトリとして走る（C10「実行の手順」の `working_directory`）。読むファイルは `.files/` に置き、実行器が一時ディレクトリに写したものを相対パスで読む。書くファイルも一時ディレクトリの中に相対パスで作る。並べて走らせても、テストどうしが干渉しない。
- 差分テストでは、VM と参照インタプリタが同じ一時ディレクトリで続けて走る（`tests/golden/differential.rs` の `compare_on_stage` は、同じ `RunInput` の `working_directory` を両方に渡し、間でディレクトリを作り直さない）。そのため、`io` のテストは、二度続けて走らせても同じ出力になるように書く。書くファイルは最初に `File.writeText` で作り直すか、作ったものを最後に消す（既存の `testdata/io/c12-write-append.bnt` が、最初に `writeText` で作り直す形である）。`createDirectory` のように二度目に `AlreadyExists` になる操作は、最後に消す形にする。
- 空のディレクトリは git に残らないので、`.files/` に置かず、スクリプトの中で `File.createDirectory` で作る。
- 作業ディレクトリのパスを出力にも比較にも使わない。macOS では `std::env::temp_dir()` が `/var/folders/...` を返し、`canonicalize` は `/private/var/...` を返すので、同じディレクトリでも字面が違う。`Process.workingDirectory`・`File.canonicalize`・`Process.scriptDirectory` の値は、そのまま書かず、`Path.fileName` で末尾の名前だけを出力する（`scriptDirectory` なら `io`）などの形にする。
- 環境変数は、定義されていない名前（`BENITOITE_GOLDEN_UNSET_…` のような名前）を読んで `Option.None` を出力する形なら、差分テストに残せる（参照インタプリタの `environment_variable` は常に `None` を返す）。定義済みの変数（`HOME`・`PATH` など）の値は出力しない。
- IO の失敗は、`IOError.message` でなく `IOError.kind` で出力する。`message` の文面と OS の誤りの番号は OS によって違う。
- `File.listDirectory` と `File.walk` の並び順は、03-07 の定め（名前または相対パスを UTF-8 のバイト列として比べた辞書式の順）に従い、期待値もその順で書く。
- 外部コマンドのテストは、`/bin/sh` のような、対応環境（macOS と Linux）に必ずあるコマンドだけを使う。
- 実行のたびに値が変わる関数（`Clock.now`・`Random.integer` など）は、値そのものを出力しない。性質（範囲に入る、前後の関係）だけを出力するか、`handle` で値を固定する（01-07）。
- U3 の事前点検で決めた境界の規則（ADR 0322・0327〜0329。`-0` の扱い、`Path.join("a", "")`、`Csv.format([[""]])`、`Process.runAttached` の `input` など）を、それぞれ少なくとも一つのテストに入れる。期待値は ADR と 03-06〜03-08 の本文から決める。
- 差分テストの対象の選び方は C10 のとおりである（タスクを起動するテストと `.stdin` を持つテストは外れる）。対象に入るテストは、参照インタプリタと VM で同じ結果になる。
- 時計・乱数を使い、参照インタプリタと VM で値が食い違うので比べられないケースは、`tests/golden.rs` の `NONDETERMINISTIC_CASES` に名前で足してよい（本作業に限り許す。C12 は足すことを禁じた）。ただし、`handle` で値を固定する形と `Random.fromSeed` で書ける場合はそちらを優先し、足すのはそれで書けないケースに限る。
- `Clock.sleep` を `handle` で処理しない（実際に待つ）テストは、必ず `NONDETERMINISTIC_CASES` に足す。参照インタプリタは作業用のスレッドの待ちのほかの待ちを扱えず、`Clock.sleep` で内部の誤り（`src/refinterp/convert.rs` の `unsupported reference builtin wait` の `Stop::Internal`）で止まるので、値の食い違いではなく比較そのものが落ちる。待つ時間は 1 ミリ秒程度にする。
- `NONDETERMINISTIC_CASES` に書く名前は、`testdata/io/foo.bnt` の形の、クレートの根からの相対パスである（実行器はこの形の名前で比べる）。足した名前と、それぞれを足した理由を完了の報告に書く。
- `STRESS_EXCLUDED_CASES` に名前を足さない。`scripts/check.sh` はゴールデンテストを、通常のテストのビルドと回収の強制（機能 `gc-stress`）のビルドで走らせ、どちらでもケースごとに CLI の二つの IO の方式と差分テスト（VM と参照インタプリタ）で数回実行する。回収の強制のビルドでは生きている構造の大きさに比例した走査が安全点ごとに起きて二次の時間になる。コレクションと文字列は数十〜数百の要素に抑え、長いループを書かない。大きな規模のケースを置くなら、まず小さな規模で回収の強制のビルドの時間を測って見積もる。
- 期待する結果は設計書から決め、実際の結果と比べる（C11・C12 と同じ規則）。実際の結果が設計書と食い違うときは、期待値を実際の結果に合わせない（書き直しの指定 `BENITOITE_BLESS` で作った期待値は、設計書と照らしてから残す）。食い違ったテストは `testdata/` に置かず、スクリプトと、設計書から決めた期待値と、実際の結果と、設計書の節を、完了の報告に添える（`scripts/check.sh` を通すために期待値を曲げない）。`tests/golden.rs` の CLI の外の検査（期待する終了状態が 0 の `check` のケースの脱糖とコア IR の検査、`run` のケースの VM と参照インタプリタの比較、直接呼び出しと要求と応答の比較、フォーマッタの性質の確かめ（D04。[ADR 0224](../../design/decisions/0224-golden-test-format-for-first-release.md) の決定 4））だけで落ちるケースも、処理系の不具合として同じく `testdata/` に置かずに報告する。`NONDETERMINISTIC_CASES` のほかに、`tests/golden.rs` に除外の表を足さない。

## 受け入れテスト

- `stdlib`: `Character`・`String` の Unicode の関数、`Map`・`Set` の関数（関数を引数にとる関数と `Trait` の実装を含む）、`Bytes`・`ByteOrder`、`Path`・`Json`・`Regex`（`replaceAllWith` を含む）・`Csv`・`Time`・`Encoding`・`Hash`、取り込みの名前の診断。
- `io`: `Console.readAllLines`・`readAllBytes`（`.stdin` のファイルで入力を与える）、`File` のファイルとディレクトリの操作とリソースの関数、`Process` の環境変数・作業ディレクトリ・`scriptDirectory`・外部コマンド、`Clock`、`Random`（`handle` で固定した値と、生成器の決まった列）。
- すべてのテストが、C10 の実行器で、回収の強制で通る。

## 完了条件

- `scripts/check.sh` が通る
- ADR 0137 の決定 2 の、Network（L33 が書く）を除く各モジュールに、少なくとも一つのテストがある
- `src/` を変えていない。処理系の不具合を見つけたら、直さずに完了の報告に書いている
- `tests/golden.rs` の変更が `NONDETERMINISTIC_CASES` への名前の追加だけであり、足した名前と理由を完了の報告に書いている

## 確認の観点

- テストが、スクリプトの出力と終了状態だけを期待値にしているか（処理系の内部の値を読んでいないか。スキル `test-audit`）。
- 期待値が、設計書の例の値と一致しているか。今の処理系の出力を、確かめずに期待値にしていないか。
- 環境や実行の時刻によって結果が変わるテストがないか。

## 難易度の理由

書くのはスクリプトと期待値だけであり、仕組みは揃っている。量が多く、環境に依存しない書き方に注意が要る。
