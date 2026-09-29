# 0130. 組み込みのエフェクトを `Benitoite.IO` の各モジュールの中で宣言し、まとめたエフェクトを `IO.All` とする

- 状態: 採択（決定 1 の `Benitoite.IO.Network` の行、決定 4 の `IO.All` の範囲、決定 5 の `main` のエフェクトを、[0140](0140-network-separated-from-local-io.md) で改めた。決定 3 の `State` を型に持つ関数に、リソースを解放する関数を [0150](0150-resource-release-as-state.md) で加えた）
- 日付: 2026-09-28
- 関連章: [エフェクト](../01-spec/01-07-effects.md), [標準ライブラリ](../03-interop/03-06-stdlib.md), [型システム](../01-spec/01-06-type-system.md), [コア計算と脱糖](../01-spec/01-12-core-calculus.md), [並行処理](../01-spec/01-11-concurrency.md), [セキュリティモデル](../07-quality/07-01-security-model.md), [利用者プログラムのテスト](../06-tooling/06-04-test-runner.md), [他の言語の調査記録](../08-appendix/08-03-language-surveys.md)
- 関連する未決事項: [OPEN-045](../open-issues.md#open-045), [OPEN-012](../open-issues.md#open-012)

## 背景

初回リリース版の組み込みのエフェクトは、`Console`・`FileRead`・`FileWrite`・`Command`・`Exit`・`Environment`・`Network`・`Clock`・`Random`・`State` の十個であり、`IO` はそれらをまとめた名前である（[ADR 0116](0116-builtin-fine-grained-effects.md)）。テストの期待の確認は、組み込みのエフェクト `Assert` の操作で行う（[ADR 0120](0120-test-functions-and-assert-effect.md)）。

エフェクトはモジュールの中で宣言し、その操作をモジュールの関数とする（[ADR 0129](0129-effects-declared-in-modules.md)）。IO を行うモジュールは `Benitoite.IO` の下に置く（[ADR 0128](0128-prelude-and-benitoite-namespace.md)）。組み込みのエフェクトを、この規則に合わせて置き直す必要がある。

Koka と Flix は、操作を持たず、ハンドラで処理できない基本のエフェクト（Koka の `div`、Flix の `IO`）を標準ライブラリで宣言し、処理系が特別に扱う。Koka の `io` は、複数のエフェクトをまとめたライブラリの別名である（[他の言語の調査記録](../08-appendix/08-03-language-surveys.md)の「組み込みのエフェクトの名前」）。

## 決定

1. 組み込みのエフェクトを、次のモジュールの中で宣言する。

   | モジュール | エフェクト | 表す操作 | これまでの名前 |
   |---|---|---|---|
   | `Benitoite.IO.Console` | `Write` | 標準出力と標準エラー出力への書き込み | `Console` |
   | 〃 | `Read` | 標準入力の読み取り | `Console` |
   | `Benitoite.IO.File` | `Read` | ファイルとディレクトリの読み取り | `FileRead` |
   | 〃 | `Write` | ファイルとディレクトリの作成・書き込み・削除・移動 | `FileWrite` |
   | `Benitoite.IO.Process` | `Run` | 外部コマンドの起動と、シェルによるコマンドの実行 | `Command` |
   | 〃 | `Exit` | 終了状態を指定したプロセスの終了 | `Exit` |
   | 〃 | `Environment` | コマンドライン引数・環境変数・実行を始めるスクリプトのディレクトリの読み取り | `Environment`、`Console`（コマンドライン引数） |
   | `Benitoite.IO.Clock` | `Time` | 時刻の読み取りと、時間の経過を待つこと | `Clock` |
   | `Benitoite.IO.Random` | `Generate` | 乱数の生成 | `Random` |
   | `Benitoite.IO.Network` | [OPEN-045](../open-issues.md#open-045) で定める | ネットワークの待ち受けと接続 | `Network` |
   | `Benitoite`（prelude） | `State` | 可変のセルとタスクの集まりの操作 | `State` |
   | `Benitoite.Assert`（prelude） | `Check` | テストの期待の確認 | `Assert` |

   取り込んだモジュールのエフェクトは、`uses Console.Write, File.Read` のように、使う側のモジュールの名前で修飾して書く。
2. 各モジュールの IO の関数は、そのモジュールのエフェクトの操作である（`Console.writeLine` は `Console.Write` の操作）。ハンドラで処理でき、どのハンドラも処理しなければ処理系が実際に行う。
3. `State` は操作を持たないエフェクトとし、ハンドラで処理できない。`Reference` と `TaskGroup` の関数は、`State` を型に持つ組み込みの関数である。
4. prelude のモジュール `IO`（`Benitoite.IO`）に、`State` と `Benitoite.IO` の下のすべての組み込みのエフェクトをまとめたエフェクト `All` を置く。`uses IO.All` は、それらをすべて書いたのと同じ意味である。`Check` は含めない。`IO.All` を書くのに import は要らない。`Benitoite.IO` の下のモジュールの関数を呼ぶには、これまでどおり import が要る。
5. `main` のエフェクトは、組み込みのエフェクト（`IO.All` に含まれるもの）の任意の集まりとする。

## 検討した代替案

- **これまでの名前（`FileRead`・`Console` など）を prelude の直下に置く**: 名前は短い。しかし、エフェクトの名前と関数のモジュールの名前が揃わず、`Console` がモジュールとエフェクトの両方を指す。
- **`Console` のエフェクトを一つにまとめる**: 名前は一つで済む。しかし、画面に出力するだけで入力を待たない関数を、型で区別できない。
- **コマンドライン引数を `Console.Read` に含める**: 端末からの入力として扱える。しかし、コマンドライン引数は、環境変数と同じく起動のときに与えられる値であり、標準入力のように実行中に待つものではない。
- **まとめたエフェクトを prelude の直下の `IO` とする（これまでの形）**: 最小実行版と同じ書き方で済む。しかし、名前空間の `Benitoite.IO` と、エフェクトの `IO` が同じ綴りで別のものを指す。

## 帰結

- ADR 0116 の決定 1 と 2 の名前、ADR 0120 のエフェクトの名前（`Assert` を `Assert.Check` に）、ADR 0063 のセルの操作のエフェクトの名前を、この ADR の名前に読み替える。ADR 0116 の粒度の考え方と、ADR 0117 の影響の大きい操作の規則は変わらない。影響の大きい操作のエフェクトは `Process.Run`・`Process.Exit`・`File.Write` になる。
- 最小実行版のスクリプトの `uses IO` は、初回リリース版では誤りになる。診断は `uses IO.All` を修正案として示す。
- 処理系は、組み込みのエフェクトを `Benitoite` の名前空間のどの名前かで照合する（[ADR 0128](0128-prelude-and-benitoite-namespace.md)）。
- 権限の種類と関数の対応（[ADR 0074](0074-static-permission-check-by-name-reference.md)）は、関数の新しい名前で表に書き直す。
