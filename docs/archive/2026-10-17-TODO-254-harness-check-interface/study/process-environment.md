# 外部コマンドに渡す環境変数と拒否の返し方

## 現在のデータと実行

[03-07「IO のモジュール」](../../../design/03-interop/03-07-io-modules.md) と `crates/benitoite/src/prelude/stdlib/IO/Process.bnt` の Command は、program、arguments、workingDirectory、environment、input の五欄を持つ。environment は `Map[String, String]` である。Process.command は空の Map を作り、利用者はレコードの更新で変更する。

`src/builtins/funcs/process.rs::read_command` は Map を所有する String の組の Vec に移し、OwnedCommand を作る。run/runAttached はそれを WorkerWait の仕事へ渡し、共通の execute で外部コマンドを起動する。execute は NUL、空の変数名、名前に含まれる `=` などを検査した後、Rust の Command に `.envs(command.environment)` を渡す。env_clear と env_remove は呼んでいない。

Rust の Command は既定で親の環境を引き継ぎ、envs は明示した名前を加えるか上書きする。変数名は Windows で大文字小文字を区別せず、ほかのプラットフォームでは区別する。根拠は [Rust の Command::envs](https://doc.rust-lang.org/std/process/struct.Command.html#method.envs)（2026-10-17 確認）である。現在の空の Map は空の子環境を意味しない。

shell は environment を空の Vec にした OwnedCommand で `/bin/sh -c` を起動し、同じ execute を通る。environment の明示設定だけを拒否しても、shell を含め親からの継承は続く。

## 拒否を Result.Error にできる箇所

execute の戻り値は `Result<CommandOutput, file::IoFailure>` であり、不正な引数には既に `io::ErrorKind::InvalidInput` を返している。完了の処理 `complete_output` などはそれを IOError の値にし、言語の Result.Error として返す。IOErrorKind には InvalidInput と PermissionDenied が既にある。

明示的なローダ変数の拒否も execute の入力検査で、子を起動する前に InvalidInput を返す案が小さい。read_command は現在 `Result<OwnedCommand, Stop>` なので、ここで誤りを Stop にすると捕捉できない失敗へ変わってしまう。PermissionDenied は OS が拒否した既存の説明と異なり、今回は処理系が受け付けない引数なので InvalidInput を推す。

エラーの文には拒否した変数名と、Command.environment で設定できない理由を入れ、値は含めない。複数の禁止名があれば名前の辞書順で最初の一件を示す。通常の IOError の値として返すため、新しい E の診断コードは要らない。利用者が処理すれば正常終了もでき、or die に渡せば既存の kind: die と状態 1 となる。

## ローダの一次資料と制限の範囲

Linux の [ld.so(8)](https://man7.org/linux/man-pages/man8/ld.so.8.html) は LD_LIBRARY_PATH、LD_PRELOAD、LD_AUDIT などの作用と、保護条件によって無効になる場合を記す。Apple の [DyldProcessConfig.cpp](https://github.com/apple-oss-distributions/dyld/blob/main/dyld/DyldProcessConfig.cpp) は DYLD_ の変数を扱い、保護条件による除去も持つ（ともに 2026-10-17 確認）。これらから、特定の変数がどの OS・実行形式でも同じ効果を持つとは言えない。

判断の案では、個別一覧より広い `DYLD_` と `LD_` の接頭辞を拒否対象とする。LD_DEBUG なども含むため、これは既知の注入用変数だけの一覧という意味ではない。将来の同系列の変数を毎回追加する負担を減らす処理系の入力制約である。大文字小文字の扱いも、OS の模倣か、すべての OS で ASCII の大小を区別しない規則かを Q10 で比較する。

Windows は現行の正式な配布対象と同じ保証へ広げない。今回の接頭辞の規則を共通で適用しても、Windows の DLL の探索・読み込みを制限する保証にはならない。PATH などローダ系列の名前でない変数、起動するコマンドの引数・設定ファイル、孫プロセスはこの制約の外である。

## TODO-058 との分担

docs/todo の TODO-058 は親の環境を引き継がない手段や個別削除を扱い、inheritEnvironment の欄などを候補に挙げている。今回は Command の欄と型を変えず、明示的に設定するローダ変数の拒否に限る案を推す。引き継いだ同名の変数は現状どおり子へ渡ることを受け入れ条件に明記する。

継承された禁止変数も含めて拒否する案や、黙って取り除く案は、外部コマンドだけでなく処理系を起動する環境の扱いにも影響する。処理系自身の起動前にローダが読む変数は、処理系の main が始まった後の制約では防げない。ハーネスの初回起動時の環境構築と OS の隔離が別に必要である。TODO-058 全体をこの改造で解決したとはしない。

無条件の拒否を採ると、これまで通った Command が失敗へ変わる。CHANGELOG に対象名・拒否の種類・継承の限界を記し、E0908 の変更表へ登録する案を Q13 に示す。旧い language 宣言だけを見てローダ変数の制約を解除する実装は採らない。
