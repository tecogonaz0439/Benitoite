# パッケージ管理

- 状態: 草稿
- 関連ADR: [0126](../decisions/0126-import-by-module-name.md), [0127](../decisions/0127-directory-run-and-root.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0137](../decisions/0137-first-release-library-scope.md), [0139](../decisions/0139-external-functions-via-wasm.md), [0154](../decisions/0154-public-contract-includes-effects-and-supertraits.md), [0156](../decisions/0156-module-loading-and-whole-program-checking.md), [0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md), [0190](../decisions/0190-ssh-signatures-for-scripts.md), [0202](../decisions/0202-signature-details.md), [0209](../decisions/0209-reserved-subcommand-names.md), [0233](../decisions/0233-distribution-via-github-releases.md), [0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md)
- 未決事項: [OPEN-048](../open-issues.md#open-048), [OPEN-049](../open-issues.md#open-049), [OPEN-051](../open-issues.md#open-051), [OPEN-073](../open-issues.md#open-073), [OPEN-074](../open-issues.md#open-074), [OPEN-075](../open-issues.md#open-075), [OPEN-076](../open-issues.md#open-076), [OPEN-077](../open-issues.md#open-077), [OPEN-078](../open-issues.md#open-078), [OPEN-081](../open-issues.md#open-081)
- 移行元: [設計メモ](../sources/fp-language-design.md) なし（18 の密結合）、[パッケージ管理の検討メモ](../sources/post-first-release/post-first-release-package-management.md)（2026-10-02〜06）

## 目的と範囲

パッケージ管理を扱う。パッケージ管理は、利用者の根のディレクトリの外で作られたモジュールの集まり（パッケージ）を、スクリプトの依存として書き、取得し、版を選び、中身を固定して検査に渡す仕組みである。本章は、初回リリース版の範囲と、初回リリース版の後に設けるときの検討の方向と未決事項を記す。

パッケージのモジュールを取り込む構文と名前空間は[名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)と [OPEN-049](../open-issues.md#open-049) で、取得した後のモジュールの探索と検査は[名前解決とモジュール読込](../02-impl/02-04-resolver.md)で、外部の関数の層は[外部の関数](../04-extensions/04-01-external-functions.md)で扱う。

## 前提

- 初回リリース版は、パッケージ管理と外部の関数の層を含めない（[ADR 0137](../decisions/0137-first-release-library-scope.md)、[ロードマップ](../00-overview/00-03-roadmap.md)の「将来拡張」）。
- 初回リリース版は設定ファイルを設けず、根のディレクトリを実行を始めるファイルのあるディレクトリとする（[ADR 0126](../decisions/0126-import-by-module-name.md)、[ADR 0127](../decisions/0127-directory-run-and-root.md)）。設定ファイルを設けるかは [OPEN-048](../open-issues.md#open-048) で決める。
- 標準ライブラリは名前空間 `Benitoite` に置き、吟味の前のモジュールは `Benitoite.Unofficial` の下の名前で取り込む（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)、[ADR 0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md)）。
- 処理系は、取り込むモジュールのソースをすべて読み、プログラム全体を検査する（[ADR 0156](../decisions/0156-module-loading-and-whole-program-checking.md)）。
- 後の版の外部の関数は、WASM のモジュールの関数に限る（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）。
- サーバモードの登録では、方針が求めるときにスクリプトの署名を確かめる。署名は、読み込むファイルの相対パスとハッシュの一覧に付けた SSH の署名である（[ADR 0190](../decisions/0190-ssh-signatures-for-scripts.md)、[ADR 0202](../decisions/0202-signature-details.md)、[サーバモード](06-07-server.md)の「署名」）。
- サブコマンドの名前 `package` を予約している（[ADR 0209](../decisions/0209-reserved-subcommand-names.md)）。

## 仕様

### パッケージ管理の範囲（初回リリース版）

【方針】初回リリース版はパッケージ管理を持たない（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。スクリプトがほかのファイルのコードを使う手段は、根のディレクトリの下に置いたモジュールの取り込みと、処理系に同梱する標準ライブラリの取り込みだけである。スクリプトで要る機能は、標準ライブラリにそろえておく。

### パッケージ管理の設計の条件（初回リリース版の後）

パッケージ管理を設けるときは、次の条件を前提に方式を比べる。どれも新しい決定ではなく、既存の ADR から導かれる性質である。

1. パッケージのエフェクトが型に現れる。公開の関数の契約はエフェクトを含む（[ADR 0154](../decisions/0154-public-contract-includes-effects-and-supertraits.md)）ので、パッケージが行いうる外部の操作は、ソースを読まなくても型から分かり、版を上げてエフェクトが増えれば型が変わる。
2. 導入のときにコードを実行する仕組みが要らない。処理系はソースを読んで全体を検査し（ADR 0156）、外部の関数はビルド済みの WASM のモジュールに限る（ADR 0139）ので、ビルドのスクリプトに当たるものがない。
3. 依存の書き手は主に LLM、確認するのは人間である。名前だけで取得できる方式では、LLM が書いた存在しない名前や似た名前を攻撃者が先に登録していれば、そのパッケージを取得してしまう。
4. 一つのファイルのスクリプトと Agent Skill が主な用途である。Skill はディレクトリを単位に配るので、依存を Skill のディレクトリに写して置く形と組み合わせやすい。設定ファイルを親のディレクトリへ辿って探す方式は、起動した場所で効く設定が変わるので避けた（ADR 0127）。
5. サーバモードの署名で依存まで覆うには、依存の中身をハッシュで固定する必要がある。
6. 吟味の前のモジュールを標準へ移す仕組みがある（ADR 0286）。処理系と別に配る公式のライブラリを設けるなら、標準ライブラリとの線引きが要る。

### 検討の方向（初回リリース版の後）

2026-10-02〜06 に設計者が検討した方向を、論点ごとに記す（[パッケージ管理の検討メモ](../sources/post-first-release/post-first-release-package-management.md)）。どれも決定ではない。細目と比べた方式は各 OPEN に記す。メモが挙げた他の言語の方式は、一次資料で確かめていない【要検証】。

#### パッケージ管理を設ける時期と、依存の記述・版の選び方

【未決】パッケージ管理を設けるか、どの版で設けるかを決める（[OPEN-073](../open-issues.md#open-073)）。設けない場合は、標準ライブラリを厚くし、手元のファイルを写して使うだけにする。

【未決】設ける場合の有力な案は次のとおりである（OPEN-073）。

- 初めは中央のレジストリを持たず、取得元と中身のハッシュで依存を固定する。運営の手間が要らず、条件 3 の攻撃が名前だけで取得する方式より通りにくく、条件 5 の署名と組み合わせられる。
- 依存は根ごとに一か所（実行を始めるファイルか、プロジェクトの設定ファイル。[OPEN-048](../open-issues.md#open-048)）に書き、モジュールのファイルごとには書かない。一つの依存の記述は、取り込みの別名、取得元、版、コミットの ID、中身のハッシュを含む。後の二つは処理系の命令が取得して書き込み、ハッシュのない記述は取得せずに誤りとする。ロックファイルを別に設けず、記述にハッシュまで書く。
- 版は、大きな版ごとに一つとし、その中では依存が求めた版のうち最大のものを選ぶ（最小版選択）。選んだ結果は、依存の依存も含めて根の記述に書き出す。
- 取得したものは、利用者のキャッシュのディレクトリに中身のハッシュを名前にして読み取り専用で置き、共有の導入先を持たない。サーバモードは登録のときに取得し、実行のときには取得しない。

#### 取得元

【未決】取得元を、git のリモートリポジトリ（HTTPS と SSH）、手元のパス、公式の追加のライブラリの短い名前に限る方向で検討する。アーカイブの URL は、要望が出てから考える。git からは、指したコミットの木を作業ツリーに展開せずに読み、hooks と filter を起動しない（[OPEN-074](../open-issues.md#open-074)）。

#### パッケージのエフェクトと権限

【未決】依存を加える・更新するときに、パッケージが使うエフェクトと前の版からの差分を利用者に示すか、利用する側がパッケージに許すエフェクトを制限できるようにするかを決める（[OPEN-075](../open-issues.md#open-075)）。条件 1 により、エフェクトの差分は型から求められる。ただし、パッケージが宣言してハンドラで処理するエフェクトは `main` の型に現れないので、そうしたエフェクトを権限の表示にどう出すかは [OPEN-081](../open-issues.md#open-081) とあわせて決める。

#### 署名

【未決】署名の一覧の対象を、`@external` が指す WASM のモジュールと依存の記述まで広げ、スクリプトの作者の署名一つで依存の中身まで固定する方向で検討する。公式の追加のライブラリにはプロジェクトの鍵で署名し、有志のパッケージの署名は任意とする案である（[OPEN-076](../open-issues.md#open-076)）。

#### 依存関係地獄を言語仕様で防ぐ手段

【未決】同じパッケージの互換性のない版の共存、公開の依存と非公開の依存の区別、公開の契約の差分による版の付け方の検査など、型とエフェクトを静的に追跡する言語の規則で依存関係の問題を減らす手段を決める（[OPEN-077](../open-issues.md#open-077)）。

#### 公式の追加のライブラリ

【未決】標準ライブラリに入れず処理系と別に配る公式のライブラリ（公式の追加のライブラリ）の名前と取得元と、吟味を終えた非公式のモジュールの行き先にそれを加えるかを決める（[OPEN-078](../open-issues.md#open-078)）。有力な案は、予約した短い名前を、処理系に埋め込んだ対応表で取得元と中身のハッシュに変える形である。

#### パッケージに WASM を含める場合

【未決】パッケージにビルド済みの WASM のモジュールを含めるかを、外部の関数の層の設計とあわせて決める（[OPEN-051](../open-issues.md#open-051)）。WASM のモジュールはホストの関数を通してしか外に作用できない（ADR 0139 の決定 4）ので、含めても条件 1・2 は保たれる。

## 未決事項

- [OPEN-048](../open-issues.md#open-048): プロジェクトの設定ファイルと、根のディレクトリの指定（依存を書く場所）
- [OPEN-049](../open-issues.md#open-049): パッケージの名前空間と取り込み方
- [OPEN-051](../open-issues.md#open-051): 外部の関数（WASM）の詳細（パッケージに WASM を含める場合）
- [OPEN-073](../open-issues.md#open-073): パッケージ管理を設ける時期と、依存の記述・版の選び方
- [OPEN-074](../open-issues.md#open-074): パッケージの取得元と取得の制約
- [OPEN-075](../open-issues.md#open-075): パッケージのエフェクトと権限
- [OPEN-076](../open-issues.md#open-076): パッケージと WASM の署名、プロジェクトの鍵
- [OPEN-077](../open-issues.md#open-077): 依存関係地獄を言語仕様で防ぐ手段
- [OPEN-078](../open-issues.md#open-078): 公式の追加のライブラリの配り方と、非公式のモジュールの行き先
- [OPEN-081](../open-issues.md#open-081): 外部のライブラリのエフェクトを、権限の表示にどう出すか
