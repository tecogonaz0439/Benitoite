# R02 の実装結果

2026-10-24。R02 の実装と指定検査を完了した。基準 B_WORK は `3b41e44be63eef7a1a6f89257935e259a57a69a3`。開始時の HEAD は基準と一致し、ブランチは `mod012/R02`、未コミット差分はなかった。private/ とそこを指すスキルのリンクは読んでいない。git は状態・差分の読み取りだけに使い、変更操作をしていない。

## 変更と再現

`tools/derive/derive.py` の prepare 共通入口で、生成対象のモジュールの fileUses と選択機能を照合する。Property または JSON を要求していれば、生成計画・本文・レビュー成果物を作る前に derive.file_effects で拒否する。対象型、選択機能、宣言原文、宣言元の UTF-8 バイト位置と、通常のトップレベル関数にファイルの効果が加わるため純粋さを保てない理由を示す。初回 apply は既存の入力照合後に同じ prepare を通る。receipt の再適用・復旧の経路は変更していない。

生成器の版は 3.1.0-syntax-batch5 のままにした。既に純粋さの契約に反する生成を事前拒否する追加は、受理入力の生成規則を変更しないため版を上げる変更に当たらない、と版定数の直前にコメントを加えた。inventory・manifest・receipt・記録・意味ハッシュ・設定・Property.libraryVersion の版も変更していない。

実装前に、一時プロジェクトの People.bnt に次の入力を置き、旧 Manager の preview → apply → derive check → 通常の check を実行した。設定は People.Person と People.Group をそれぞれ JSON の生成対象とし、関数名は encodePerson/decodePerson、encodeGroup/decodeGroup とした。

```text
import Benitoite.Unofficial.Json as J
import Benitoite.Unofficial.Json.Codec as C
uses Log
public record Person
 name: String
end record
public record Group
 people: List[Person]
end record
function main() -> Unit
 ()
end function
```

preview・apply（1ファイル）・derive check は成功した。通常の check は終了2で、Codec.encodeList に渡す encodePerson と Codec.decodeList に渡す decodePerson の2箇所で E0401 になった。期待される純粋な関数型と、実際の uses Log 付き関数型との不一致である。E0303・E0414 はなかった。生成後の同じ入力からファイル単位の uses Log だけを除くと、通常の check は終了0になった。再現全体の外側の時間は2.612秒であった。

`tools/derive/test_derive.py` の既存の生成後の失敗を観察するテストを、Property・JSON・両方について preview/check の拒否と非書き込みを確かめる表へ置き換えた。必要な import を先に用意し、純粋さの理由、対象、機能、宣言原文と位置を検査する。日本語の説明を前置し、位置が文字数ではなく UTF-8 バイト数であることも確かめる。ソース・設定・記録等の全ファイルのバイト列を比較し、レビュー用ディレクトリも作られないことを確かめる。本番の差し込み口やコンパイラの段の置換は追加していない。

既存の import 配置のテストは Show の要求へ切り替え、今回の純粋さの拒否に先回りされず、従来の import 配置の拒否を検査できるようにした。JSON/Property のカスタム署名の既存表は、対象ファイルに uses を足す行だけ新しい早期拒否を期待し、ほかの行の純粋さ・単相性の検査を保った。

型グラフより先にファイル単位の宣言と opaque を判定するため、TypeGraph の構築を対象の検査の後へ並べ替えた。拒否する入力の報告順だけが変わる。

## 実行した検査

コマンドはリポジトリの根で実行した。時間は、特記した初回ビルドを除き外側の実測である。`/usr/bin/time -p` は計測用で、rtk はコマンドのプロキシである。

| コマンド・入力 | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| `rtk cargo build -p benitoite --bin benitoite --example derive_inventory` | 0 | 外側は未計測。Cargo 表示は5.32秒。実 inventory と formatter/通常 check の実行ファイルをビルド |
| `rtk proxy python3 -B -`（上記の一時入力を作成し、旧 Manager と通常 check を呼ぶスクリプトを標準入力から実行） | 0 | 2.612秒。上記の E0401 と宣言を除いた後の成功を確認 |
| `/usr/bin/time -p rtk proxy python3 -B tools/derive/test_derive.py FileEffects.test_generated_pure_functions_reject_file_effects_without_writes`（実装前・初回） | 1 | 0.80秒。Property の拒否欠落で失敗。残りのケースは初回のレビュー成果物と衝突したため、ケースごとに出力先を分けた |
| 同コマンド（実装前・出力先を修正後） | 1 | 0.78秒。Property・JSON・両方の3ケースとも拒否欠落で意図どおり失敗 |
| `/usr/bin/time -p rtk proxy python3 -B tools/derive/test_derive.py FileEffects`（実装後） | 0 | 3.85秒。4テスト成功 |
| `/usr/bin/time -p rtk proxy python3 -B tools/derive/test_derive.py` | 0 | 70.27秒。実 inventory・formatter・通常 check/test を使う47テストすべて成功。既存の再適用・receipt 復旧・旧版拒否の検査も含む |
| `/usr/bin/time -p rtk proxy scripts/check.sh --level work --base 3b41e44be63eef7a1a6f89257935e259a57a69a3 --only python_syntax --dry-run` | 0 | 0.26秒。計画どおり python_syntax だけを選択 |
| `/usr/bin/time -p rtk proxy scripts/check.sh --level work --base 3b41e44be63eef7a1a6f89257935e259a57a69a3 --only python_syntax` | 0 | 0.10秒。指定された各 tools ディレクトリの Python 構文解析に成功 |
| `/usr/bin/time -p rtk git diff --check` | 0 | 0.04秒。追跡ファイルの差分の空白検査に成功 |

## 計画との差と申し送り

- 共通依頼文の「処理系と設計書を同じ状態へそろえる」に従い、R02 の対象ファイルの列にない `docs/design/03-interop/03-06-stdlib.md`「外部生成の管理と照合」も更新した。生成後の純粋さの違反の説明を事前拒否へ置き換え、対象・機能・非書き込み・Show/Order の扱いを記した。言語規則、Lean、Rust、公開の型・診断登録、生成物の版は変更していない。
- 初回ビルドで外側の時間を計測し忘れたため、Cargo の表示時間と区別して記録した。それ以外は計画の R02/T-D の検査に従った。
- R03 担当は計画どおり、Show/Order/両方、Log 以外、空設定、対象外の依存先、複数対象、初回 apply の拒否、受理入力の固定した旧本文・意味ハッシュ・記録との一致を拡充して確認する。R02 で追加した診断識別子は derive.file_effects である。
- R04 担当は計画どおり、個別 uses または型定義と生成対象を純粋なモデルモジュールへ移す対処、旧道具での復旧を先に終える手順、現行版表記を案内する。今回の診断も、型定義と生成対象を一緒に移すことを示している。
- 言語規則の変更や Lean の言明・公理の変更を要する点は見つからなかった。独立レビュー・取り込み・後続作業の受け入れは取りまとめが担当する。
