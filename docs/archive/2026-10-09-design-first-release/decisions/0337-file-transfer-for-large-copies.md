# 0337. 初回リリース版の後に、開いたリソースどうしを流す `File.transfer` を加え、`File.copy` をそれで書き直して 1 GiB の上限をなくす

- 状態: 採択
- 日付: 2026-10-08
- 関連章: [IO のモジュール](../03-interop/03-07-io-modules.md)
- 関連 ADR: [0291](0291-file-copy-limit-and-http-server-details.md), [0049](0049-size-limit-for-built-values.md), [0150](0150-resource-release-as-state.md), [0236](0236-compatibility-during-0x.md)
- 関連する未決事項: [OPEN-086](../open-issues.md#open-086)

## 背景

初回リリース版の `File.copy` は、`File.readBytes` と `File.writeBytes` を呼ぶ標準ライブラリのソースの関数であり、写せるファイルの大きさは `Bytes` の上限（2^30 バイト、1 GiB）までである（[ADR 0291](0291-file-copy-limit-and-http-server-details.md) の決定 1）。上限の元は、一つの操作で作る `String`・`Bytes` の値の大きさの上限である（[ADR 0049](0049-size-limit-for-built-values.md)、[ランタイム](../02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」）。ADR 0291 は、`File.copy` を組み込みの関数にする案を、二つの組み込みのエフェクト（`File.Read` と `File.Write`）にまたがる組み込みの関数を置く仕組みが `File.copy` のためだけに要るとして退け、帰結に「1 GiB を超えるファイルを写す必要が生じたら、後の版で組み込みの関数に改めてよい」と書いた。

1 GiB を超えるファイル（導入のパッケージ、バックアップなど）を写す場面は少なくない。利用者のスクリプトは、`File.openReader`・`File.readChunk`・`File.openWriter`・`File.writeChunk` で少しずつ読み書きすれば今でも上限なく写せるが、それを一つの関数で書ける形がない。設計者は 2026-10-03 に次の三つの案を比べ、(B) を採ると決めた（[コマンドを代替するライブラリの検討メモ](../sources/post-first-release/post-first-release-command-libraries.md)の「1 GiB を超えるファイルの扱い」）。

- (A) `File.copy` を、`File.readChunk` と `File.writeChunk` を繰り返す標準ライブラリのソースの関数に書き直す。
- (B) 開いたリソースどうしを流す操作（`File.transfer`）を加え、`File.copy` をそれで書く。
- (C) 二つのエフェクトにまたがる組み込みの関数を置く仕組みを作る。

設計者は、この改造を初回リリース版の実装を終えた後、初回リリースの前に行うとしていた。2026-10-08 に設計者は、初回リリース版（`0.1.0`）には入れず、後の版の改造とすることにした。初回リリース版の実装プランと実装は ADR 0291 の決定 1 に従っており、それを変えないためである。

## 決定

1. `Benitoite.IO.File` に、開いたリソースどうしを流す操作 `File.transfer(reader, writer)` を加える。`reader` の残りをすべて `writer` に書く。`File.Write` の操作とし、`File.Read` には属させない。読む権限は `File.openReader` で、書く権限は `File.openWriter` で、開くときに確かめ済みであり（[IO のモジュール](../03-interop/03-07-io-modules.md)の「File」の「権限は、開くときに一度だけ判定する」）、一つの操作が一つのエフェクトに属する規則を保てる。処理系は、流す処理を IO 実行器の作業用のスレッドの中でまとめて行う。
2. `File.copy` は、`File.openReader` と `File.openWriter` で開き、`File.transfer` で流し、閉じる標準ライブラリのソースの関数に書き直す。写せるファイルの大きさの上限（1 GiB）はなくなる。リソースを `with` で開くと解放のエフェクト `State` が要る（[ADR 0150](0150-resource-release-as-state.md)）ので、`File.copy` の型は `function(String, String) -> Result[Unit, IOError] uses File.Read, File.Write, State` になる。
3. 決定 1・2 は初回リリース版（`0.1.0`）に入れず、その後のマイナーの版で行う。決定 2 の型の変更は、`uses File.Read, File.Write` と細かく書いて `File.copy` を呼ぶスクリプトを型の誤りにするので、互換性を壊す変更である。メジャーバージョンが 0 の間はマイナーの版で行い、`CHANGELOG` に移行の手順（呼び出し元の `uses` に `State` を加える）を記録する（[ADR 0236](0236-compatibility-during-0x.md) の決定 1〜3）。`uses IO.All` と書いたスクリプトは、`IO.All` が `State` を含むので影響を受けない。
4. 決定 2 を行う版から、ADR 0291 の決定 1 を本 ADR の決定 2 で改める。初回リリース版は ADR 0291 の決定 1 のままとする。

`File.transfer` の戻り値の型（書いたバイトの数を返すかなど）と、流す単位の大きさは、この改造の実装プランを作るときに決める。

## 検討した代替案

- **(A) `File.copy` を、少しずつ読み書きする標準ライブラリのソースの関数に書き直す**: 新しい操作が要らず、上限もなくなる。型に `State` が加わるのは (B) と同じである。しかし、一回の読みと書きのたびに作業用のスレッドとの受け渡しと `Bytes` の確保が起き、OS の速いコピーの機能も使えない。(B) なら流す処理を作業用のスレッドの中で一度に行えるので、受け渡しの回数が減る。また、(B) の形はダウンロードや外部コマンドの出力を `Writer` に流す操作にも使える（[OPEN-086](../open-issues.md#open-086)）。設計者は、初回リリース版の実装にも (A) を入れないことにした。
- **(C) 二つのエフェクトにまたがる組み込みの関数を置く仕組みを作る**: `File.copy` の型を `uses File.Read, File.Write` のまま保てる。しかし、この関数はどのエフェクトの操作でもないので、`File.Read` を処理するハンドラ（テストの差し替えなど）がコピーの読みを捕らえられない。ハンドラで差し替えられない IO を作ることは、エフェクトの規則の例外になる。処理系が行う操作だけが実行時の権限制御の対象になる規則（[エフェクト](../01-spec/01-07-effects.md)）との関係も決め直す必要がある。
- **初回リリースの前に (B) を行う**（設計者の当初の予定）: リリースした版の利用者にとって、`File.copy` の型の変更が互換性を壊す変更にならない。しかし、初回リリース版の実装プランと実装を改めることになる。互換性を壊す変更は 0.x の間はマイナーの版で行えるので、初回リリース版は ADR 0291 の決定 1 のままとした。

## 帰結

- [IO のモジュール](../03-interop/03-07-io-modules.md)に「大きなファイルを流す操作（初回リリース版の後）」を設け、本 ADR の決定を【決定】として書く。初回リリース版の「File」の節は変えない。
- ADR 0291 の状態を「採択（決定 1 を [0337](0337-file-transfer-for-large-copies.md) で改めた）」とする。
- `File.transfer` は `File.Read` の操作ではないので、`File.Read` を処理するハンドラは、`File.transfer` が行う読みを捕らえない。テストで `File.copy` を差し替えるときは、`File.Write` の `File.transfer` と、`File.openReader`・`File.openWriter` を処理する。
- 同じ形で、HTTP の応答の本体を `Writer` に流す操作（`Http.sendTo` など）、外部コマンドの出力を `Writer` に流す設定、少しずつ計算するハッシュの関数を加えるか、`File.copy` が途中で失敗したときに書きかけのファイルを残さない手順を設けるか、OS の速いコピーの機能を使えるかは、[OPEN-086](../open-issues.md#open-086) で決める。
