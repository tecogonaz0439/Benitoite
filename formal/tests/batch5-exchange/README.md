# 書式付き補間の独立交換入力

corpus 14 / sidecar 6 の入力である。`python3 -B formal/tests/test_batch5_exchange.py` は Cargo を起動せず、ビルド済みの六つの Lean 実行器を使う。先に `cd formal && lake build` を実行する。

29定義の期待コアと整形の七定数は、D29の契約から独立に記した。Rustの交換器・Leanの脱糖器・書式の符号化器からは生成していない。全14型、全種類、左右と中央の寄せ、符号、基数接頭辞、ゼロ埋め、幅1/65535、精度省略/0/28を含む。空の断片、連続する補間と全式評価後の変換、書式付きと書式なしのString、従来のconverted、空補間も比較する。網羅性の独立期待は各1件である。数の丸めと表示の幅の出力は検査しない。

書式は `formatted: {ty, spec}` として渡す。specのkind/align/sign/alternate/zero/width/precisionはすべて必須であり、width/precisionのnullだけが省略を表す。kindはdefault/d/b/o/x/X/f/s/c、alignはdefault/left/right/center、signはdefault/plusである。内部の引数列では精度省略を-1、幅省略を0にするが、表層の交換には省略を残す。

検証器は入力を変異させ、型不適合・不正指定・必須欄・個数・頭の直接性と型・組み込みの名前と固定署名・旧版の拒否・新旧のsidecar選択を照合する。版の互換の正例には既存の独立入力を使う。Rustの出力を照合するモードと全比較は、接続を閉じる後続作業で追加する。
