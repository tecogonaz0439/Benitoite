# W1 の実装結果

2026-10-23、W1 実装担当。基準 B_WORK は `19d12c8a8845da1eea74414c179c55fd941cab16`。開始時の HEAD も同じであり、ブランチは `mod011/W1`、開始時の差分はなかった。git の変更操作は行っていない。

## 実行した検査

| コマンド・対象 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `rtk cargo test -p benitoite --lib base::display_width` | 0 | 未計時 | 新規 4 件成功。固定期待値と前後の空白、全制御境界、一般の連結の非加法性、空白数・必要サイズを確認した |
| `rtk cargo fmt --all` | 0 | 未計時 | 書式を適用した |
| `scripts/check.sh --level work --base 19d12c8a8845da1eea74414c179c55fd941cab16 --test runtime_builtins --dry-run` | 0 | 1 秒未満 | fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally・licenses を選択した |
| `scripts/check.sh --level work --base 19d12c8a8845da1eea74414c179c55fd941cab16 --test runtime_builtins` | 0 | 123.896 秒 | 上記の全選択が成功。lib は 1,256 件成功・0 件失敗・既存の ignore 21 件、runtime_builtins は 15 件成功。clippy・fmt・ソース規約・Skill 生成物の照合・仕様集計・ライセンス検査も成功した |
| 読み取り専用 Python による 03-01・03-06 の文書確認（下記） | 0 | 0.001 秒 | 相対リンク先・フェンスの対・末尾空白に問題なし |
| `rtk git diff --check` | 0 | 1 秒未満 | 差分の空白に問題なし |
| 読み取り専用 Python による新規の幅本体・本記録の確認 | 0 | 1 秒未満 | 末尾空白・最終改行に問題なし |

文書確認のコマンドは次のとおりである。

```sh
python3 - <<'PY'
import pathlib
import re
import time
start = time.monotonic()
paths = [pathlib.Path(p) for p in [
    'docs/design/03-interop/03-01-library-structure.md',
    'docs/design/03-interop/03-06-stdlib.md',
]]
for path in paths:
    text = path.read_text()
    assert not any(line.rstrip() != line for line in text.splitlines()), path
    for target in re.findall(r'\]\(([^\s)]+)\)', text):
        if '://' in target or target.startswith('#'):
            continue
        assert (path.parent / target.split('#', 1)[0]).exists(), (path, target)
    assert text.count('```') % 2 == 0, path
print(f'文書2件の相対リンク先・フェンス・末尾空白: 成功（{time.monotonic() - start:.3f}秒）')
PY
```

## 計画からのずれと申し送り

W1 の範囲と検査の割り当てに変更はなく、言語の規則の追加判断と Lean の変更は行っていない。局所テストと書式適用の外側の時間は未記録である。作業末の検査は Python の `time.monotonic()` でコマンド全体を計時した。一時ログは `/private/tmp/benitoite-w1-work.log`、終了状態と時間の一時記録は `/private/tmp/benitoite-w1-work.json` にある。上表は今回の実行結果であり、別の状態の結果の引用ではない。

W2 へ渡す内部の契約は次のとおりである。

- `base::display_width::width(&str, WidthMode) -> Option<u64>` は、指定された幅 0 の境界で区切った最大の連続部分を数える。`WidthMode::{Default,Cjk}` を用い、整数の変換・集計のあふれは `None` とする。
- `space_padding(&str, i64, WidthMode) -> Option<SpacePadding>` は、加える U+0020 の個数 `spaces: u64` と、出力の UTF-8 バイト数 `byte_len: u64` を返す。確保は行わず、0 以下の目標や元の幅以下の目標には空白 0 個を返す。`i64::MAX` の目標も先に `usize` へ縮めない。
- W2 は `spaces == 0` なら元の値を返し、それ以外では論理上限・実行時の予算を検査し、検査付きで `usize` へ変換した後に確保する。共通本体は VM・Value・Host・Wasmtime に依存しない。
- `UNICODE_VERSION: (u8, u8, u8)` は固定した依存の公開定数を参照する。W2 は CLI の `displayWidthUnicodeVersion` に利用できる。
- `unicode-width = { version = "=0.2.2", default-features = false, features = ["cjk"] }` を通常の直接依存に加えた。Cargo.lock の変更は benitoite の直接依存欄への一項目の追加だけである。ライセンスの許可一覧は変更していない。配布用の第三者表示の生成と照合は計画どおり Z1 が担当する。
- 0.2.2 の実ソースの `width_in_str`・`width_in_str_cjk`・`str_width`・`str_width_cjk` を読み直し、両モードで U+0020 が幅 1 を加えて状態を DEFAULT に戻すことを確認した。03-01・03-06 に固定版の一次資料を付した。
- 新規テスト 4 件は test-audit の作成時の関門を通した。固定期待値により、文字ごとの幅の和への置換、制御境界の無視、CJK の取り違え、表示の幅とバイト数の混同、目標の幅の切り詰めを検出する。既存の幅本体のテストはなく、公開の本体だけを呼び、テスト専用の差し込み口は設けていない。既存テストの削除・緩和はない。Rust の増減は本番 68 行追加・1 行削除、テスト 122 行追加である。
- W1 単独の short は計画どおり実施しない。W2 の取り込み後に取りまとめが一回実施する。独立レビューと受け入れも取りまとめへ渡す。

変更したファイルは Cargo.lock、クレートの Cargo.toml、`src/base/mod.rs`、新規の `src/base/display_width.rs`、03-01、03-06、本記録である。作業末の状態確認では担当範囲外の `reviews/RV-I.md` が未追跡として現れたが、本作業では作成・閲覧・変更していない。`private/` と、それを指すスキルの本文も読んでいない。
