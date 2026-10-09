# Benitoite のロゴ

- 作成: 2026-10-03
- 採用: ライトテーマは案 A、ダークテーマは案 D、ワードマークは案 E（ほかの場面で使う）

## ファイル

| ファイル（`svg/` と `png/`） | 内容 | 地 |
|---|---|---|
| `benitoite-logo-light` | 案 A。結晶と「Benitoite」の組 | 透明（明るい地に置く） |
| `benitoite-logo-dark` | 案 D。光の輪の付いた結晶と「Benitoite」の組 | 透明（暗い地に置く） |
| `benitoite-icon-light` | 案 A の結晶だけ | 透明 |
| `benitoite-icon-dark` | 案 D の結晶だけ。暗い地の角丸の正方形に収めた | `#0A1033` |
| `benitoite-icon-dark-transparent` | 案 D の結晶と光の輪だけ | 透明（暗い地に置く） |
| `benitoite-wordmark-light` | 案 E。i の点を結晶にした「benitoite」 | 透明（明るい地に置く） |
| `benitoite-wordmark-dark` | 案 E のダークテーマ用 | 透明（暗い地に置く） |

PNG の大きさ:

- アイコン: 16・32・64・128・256・512・1024 px の正方形（`-<大きさ>.png`）
- ロゴとワードマーク: 幅 800 px と 1600 px（`-<幅>w.png`）

## 色

| 用途 | 色 |
|---|---|
| ライトの文字 | `#0E1631` |
| ダークの文字 | `#DDEBFF` |
| 暗い地 | `#0A1033` |
| 結晶（A）の面 | `#2F6BFF`・`#163FB8`・`#0B2A85`・`#8DB5FF` |
| 結晶（D）の面 | `#5FA0FF`・`#2F6BFF`・`#1F4FD1`・`#CFE6FF` |
| 光の輪（D） | `#4FC3FF` |
| ワードマークの結晶 | ライト `#1F4FD1`・`#8DB5FF`、ダーク `#4F86FF`・`#CFE6FF` |

## 書体

文字は Sora（太さ 600）を輪郭に変換して埋め込んだので、閲覧する環境に書体は要らない。Sora は SIL Open Font License 1.1 で配られている（Copyright 2019 The Sora Project Authors）。

## 作り直し方

`make_logos.py` が SVG と PNG を書き出す。Python の `fonttools` と `resvg-py`、Google Fonts のリポジトリの `ofl/sora/Sora[wght].ttf` を `Sora.ttf` として同じディレクトリに置いて、`python make_logos.py <出力先>` で実行する。
