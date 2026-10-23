# 実候補の CLI の照合表

全53呼び出しの出力と終了状態を確認した。実行ファイルは通常の release 構成（既定の gc-mark-sweep、bundled-licenses なし）である。下表の `<cli>` は `target/release/benitoite`、`<inputs>` は `<repo>/target/z1-cli` を表す。実際の引数と完全な出力は [manual-cli-observations.json](manual-cli-observations.json)、実行ファイルの SHA-256 と版は [manual-summary.json](manual-summary.json) に保存した。

| 番号 | 実行したコマンド | 出力の要点 | 終了状態・判定 |
|---|---|---|---|
| 1 | `<cli> --version` | benitoite 0.0.11 / Unicode 17.0.0 | 0、期待どおり |
| 2 | `<cli> --version=json` | 0.0.11、文字/幅 Unicode とも17.0.0、commit=e0ed5eb…、dirty=null、target=aarch64-apple-darwin | 0、期待どおり |
| 3 | `<cli> --licenses` | benitoite is licensed under either of the MIT License or the Apache License, Version 2.0, at your option. / This build does not include the list of third-party licenses. | 0、期待どおり |
| 4 | `<cli> check <inputs>/formats/d.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 5 | `<cli> run --allow-effects=Console.Write <inputs>/formats/d.bnt` | 42 | 0、期待どおり |
| 6 | `<cli> check <inputs>/formats/b.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 7 | `<cli> run --allow-effects=Console.Write <inputs>/formats/b.bnt` | 0b101 | 0、期待どおり |
| 8 | `<cli> check <inputs>/formats/o.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 9 | `<cli> run --allow-effects=Console.Write <inputs>/formats/o.bnt` | 0o11 | 0、期待どおり |
| 10 | `<cli> check <inputs>/formats/x.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 11 | `<cli> run --allow-effects=Console.Write <inputs>/formats/x.bnt` | 0x2a | 0、期待どおり |
| 12 | `<cli> check <inputs>/formats/X.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 13 | `<cli> run --allow-effects=Console.Write <inputs>/formats/X.bnt` | 0X2A | 0、期待どおり |
| 14 | `<cli> check <inputs>/formats/f.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 15 | `<cli> run --allow-effects=Console.Write <inputs>/formats/f.bnt` | 2.68 | 0、期待どおり |
| 16 | `<cli> check <inputs>/formats/s.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 17 | `<cli> run --allow-effects=Console.Write <inputs>/formats/s.bnt` | 猫 | 0、期待どおり |
| 18 | `<cli> check <inputs>/formats/c.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 19 | `<cli> run --allow-effects=Console.Write <inputs>/formats/c.bnt` | A | 0、期待どおり |
| 20 | `<cli> check <inputs>/formats/sign.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 21 | `<cli> run --allow-effects=Console.Write <inputs>/formats/sign.bnt` | +42 | 0、期待どおり |
| 22 | `<cli> check <inputs>/formats/zero.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 23 | `<cli> run --allow-effects=Console.Write <inputs>/formats/zero.bnt` | -0x0002a | 0、期待どおり |
| 24 | `<cli> check <inputs>/formats/center.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 25 | `<cli> run --allow-effects=Console.Write <inputs>/formats/center.bnt` | x | 0、期待どおり |
| 26 | `<cli> check <inputs>/formats/width.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 27 | `<cli> run --allow-effects=Console.Write <inputs>/formats/width.bnt` | 42 | 0、期待どおり |
| 28 | `<cli> check --report=json <inputs>/effects/main.bnt` | status=ok、complete=true、上限={'basis': 'declaredUpperBound', 'expanded': ['Console.Write', 'Log']} | 0、期待どおり |
| 29 | `<cli> run --allow-effects=Console.Write,Log <inputs>/effects/main.bnt` | ok | 0、期待どおり |
| 30 | `<cli> run --diagnostics=json --allow-effects=Console.Write <inputs>/effects/main.bnt` | E0512、effects of `main` exceed `--allow-effects`、ファイルの宣言を副位置に表示 | 2、期待どおり |
| 31 | `<cli> check --diagnostics=json <inputs>/errors/syntax.bnt` | E0262、invalid interpolation format | 2、期待どおり |
| 32 | `<cli> check --report=json <inputs>/errors/syntax.bnt` | status=checkError、complete=false、上限=None | 2、期待どおり |
| 33 | `<cli> check --diagnostics=json <inputs>/errors/type.bnt` | E0468、a value of type `String` is incompatible with this interpolation format、値の型の位置を副位置に表示、受け付ける型を注記に表示 | 2、期待どおり |
| 34 | `<cli> check --report=json <inputs>/errors/type.bnt` | status=checkError、complete=false、上限=None | 2、期待どおり |
| 35 | `<cli> check --diagnostics=json <inputs>/versions/v0.0.9.bnt` | E0908、this file was written for Benitoite 0.0.9, and the language changed incompatibly in 0.0.10 | 2、期待どおり |
| 36 | `<cli> check --diagnostics=json <inputs>/versions/v0.0.10.bnt` | E0908、this file was written for Benitoite 0.0.10, and the language changed incompatibly in 0.0.11 | 2、期待どおり |
| 37 | `<cli> check --diagnostics=json <inputs>/versions/v0.0.11.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 38 | `<cli> check --diagnostics=json <inputs>/versions/v0.0.12.bnt` | E0907、this file needs Benitoite 0.0.12 or later, but this is Benitoite 0.0.11 | 2、期待どおり |
| 39 | `<cli> check --diagnostics=json <inputs>/forbidden/main.bnt` | E0912、`package.bnt` can contain only `language`, `dependency`, and `package` | 2、期待どおり |
| 40 | `<cli> fmt <inputs>/fmt/main.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 41 | `<cli> fmt --check <inputs>/fmt/main.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 42 | `<cli> fmt <inputs>/fmt/main.bnt` | 標準出力・標準エラーとも空 | 0、期待どおり |
| 43 | `<cli> skill list --format=json` | producer=0.0.11、同梱文書73件 | 0、期待どおり |
| 44 | `<cli> skill show --format=json SKILL.md` | producer=0.0.11、SKILL.md の版欄=0.0.11、本文・長さ・ハッシュあり | 0、期待どおり |
| 45 | `<cli> skill install --project --agent codex (cwd: <inputs>/skill-install)` | 空の確認用プロジェクトへ Skill を抽出/削除。抽出中の全ファイルは元の本文と版置換後に一致 | 0、期待どおり |
| 46 | `<cli> skill uninstall --project --agent codex (cwd: <inputs>/skill-install)` | 空の確認用プロジェクトへ Skill を抽出/削除。抽出中の全ファイルは元の本文と版置換後に一致 | 0、期待どおり |
| 47 | `<cli> package add Kit --path deps/kit <inputs>/package/main.bnt` | added dependency Kit (package Kit) to <repo>/target/z1-cli/package/main.bnt /   hash: sha256:f2bd067f1a9eb472bb8a739d106d2ccb3891f3b9b6284eba89bc82bdd38e8fa3 /   effects: Log /   components: (none) | 0、期待どおり |
| 48 | `<cli> package update Kit <inputs>/package/main.bnt` | updated dependency Kit (package Kit) in <repo>/target/z1-cli/package/main.bnt /   hash: sha256:f2bd067f1a9eb472bb8a739d106d2ccb3891f3b9b6284eba89bc82bdd38e8fa3 /   effects: + Log /   components: (none) | 0、期待どおり |
| 49 | `<cli> package update Kit <inputs>/package/main.bnt` | updated dependency Kit (package Kit) in <repo>/target/z1-cli/package/main.bnt /   hash: sha256:f2bd067f1a9eb472bb8a739d106d2ccb3891f3b9b6284eba89bc82bdd38e8fa3 -> sha256:0b0a015af107be1edade36ef0db167ad8e2c4791003d1c17493cafc28d38f2ca /   effects: + State /            - Log /   componen… | 0、期待どおり |
| 50 | `<cli> package update Kit <inputs>/package/main.bnt` | updated dependency Kit (package Kit) in <repo>/target/z1-cli/package/main.bnt /   hash: sha256:0b0a015af107be1edade36ef0db167ad8e2c4791003d1c17493cafc28d38f2ca -> sha256:0702786de3a364d62d353843d62b6e85dc6c06e4862e56fc237bb1f71e08d2ee /   effects: + Log /            - State /   componen… | 0、期待どおり |
| 51 | `<cli> package update Kit <inputs>/package/main.bnt` | unchanged dependency Kit (package Kit) in <repo>/target/z1-cli/package/main.bnt | 0、期待どおり |
| 52 | `<cli> skill install --project --agent codex (cwd: <repo>/target/z1-skill-complete)` | 空の確認用プロジェクトへ Skill を抽出/削除。抽出中の全ファイルは元の本文と版置換後に一致 | 0、期待どおり |
| 53 | `<cli> skill uninstall --project --agent codex (cwd: <repo>/target/z1-skill-complete)` | 空の確認用プロジェクトへ Skill を抽出/削除。抽出中の全ファイルは元の本文と版置換後に一致 | 0、期待どおり |

12の書式例は、十進、二進、八進、十六進の小文字/大文字、Decimal の小数点以下二桁、String の右寄せ、Character、正符号、符号と接頭辞の後のゼロ埋め、中央揃え、種別なしの幅指定である。成功時の実出力をそれぞれ独立した期待文字列と照合した。
