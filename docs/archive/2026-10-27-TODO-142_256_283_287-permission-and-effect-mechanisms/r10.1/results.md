# R10.1: 対象の代数と字句の境界

## 作業と状態

- B_WORK・開始時 HEAD: `0b684ee4284fac6d6f9f9159fad9bc806e41e369`。作業先は `m013/r10.1` である。git の状態を変える操作は行っていない。
- 閉じた範囲は、正規の path・host・IP・port・endpoint と Top の表現、所属、一原子の被覆、構造比較、IP/CIDR の字句境界、旧 Scope の共通部分への接続である。独立レビューと取り込みは取りまとめの担当である。
- 効果集合・型の添字への組み込み、公開の新構文、新しい標準入口、旧 Scope の IP/CIDR への拡張、HTTP URL の抽出、Lean との実行による比較は本枝の対象外である。
- `private/`・そこを指すスキル・`docs/todo/` は読んでいない。標準宣言・依存・scripts・Lean は変更していない。

## 変更と接続

| ファイル | 内容 |
|---|---|
| `crates/benitoite/src/types/mod.rs` | `pub mod scope` を公開する |
| `crates/benitoite/src/types/scope.rs` | 検査済みの構築、所属 `matches`、外側を self とする一原子の `covers`、構造の Eq/Ord/Hash を置く |
| `crates/benitoite/src/types/scope/ip_text.rs` | `parse_address`・`parse_pattern` と `format_address`・`format_pattern` を数値の代数から分ける |
| `crates/benitoite/src/types/scope/tests.rs` | 公開 API に対する独立期待値のテスト14件を置く |
| `crates/benitoite/src/builtins/checked_scope.rs` | 旧 Scope の path/name の解析・所属とポートの整数変換を代数へ接続する |
| 本ディレクトリ | 結果と検査ログを保存する |

旧 Scope は `HostPattern` へ切り替えず、`NamePattern` と `Name` を使う。そのため IPv4/CIDR/IPv6 は引き続き旧入口で拒否される。パスの対象の `*`、ホストの ASCII 大小文字、既知の部分だけの検査、形式→端点→port→ホスト所属→ポート所属という失敗順、誤り文と番号、成功時の保存内容を保つ。静的検査と実行時検査の既存の呼び出し元は同じ `checked_scope` を使う。

構造比較は derive によるもので、被覆を等号・整列・hash に使わない。パス・ホスト名・IP パターン・ポート区間は、不正な状態を作れないようフィールドを非公開にする。ホストの小文字化と最大 prefix の exact 化を行い、それ以外の不正を補完しない。`Range` の Top は種類を持たず、名前から種類を与える側の照合を前提とする。

既存の純粋な検査の意味も frontend の受理範囲も変えていないため、02-03 の本文は変更していない。公開の新構文と00-04は書いていない。生成元を変えておらず、生成物の差分はない。

R10.1bの修正前では、新規の本番コードは742行、既存の本番コードは32行追加・115行削除であり、本番全体の純増は659行である。新規テストは634行、14関数である。R10.1bの増減は「検査」に記す。旧入口では解析済みのPath/Nameを一時的に所有する分の確保が増えるが、VMの値の保存は変えない。性能の数値は本枝で主張せず、取り込み後のshortは取りまとめへ渡す。

## Lean との対応

表の Lean 名は `Benitoite.Scope.Domain` 内である。D は `formal/Benitoite/Scope/Domain.lean`、C は `Cover.lean`、I は `IPCover.lean`、R は `RangeCover.lean` を指す。Lean は解析済みの値を扱い、字句解析の正しさを証明も仮定もしない。Rust の検査付き構築は、その整形式かつ正規形の部分を保持する。以下は定義の読解による照合であり、実行による形式化との差分比較の成功を意味しない。

| Rust の関数 | Lean の定義・条件 | 意味の照合 |
|---|---|---|
| `Path::parse` | D `PathPartWF`・`PathWordWF` | 絶対形式を要素列へ分け、根を空列とする。空・`.`・`..`・NUL・逆斜線を拒否する |
| `Path::parts` | D `Word` | 根からの順の要素列を借用する |
| `PathPattern::new` | D `PathPattern.WF` | 正規の幹に `*` を許さない |
| `PathPattern::parse` | D `PathPattern.exact/tree`・WF | exact と末尾 `/**` を構築する字句境界である |
| `PathPattern::kind` | D `PathPattern` の構成子 | exact/tree を区別する |
| `PathPattern::stem` | D 同構成子の `stem` | 幹の列を保つ |
| `PathPattern::matches` | D `PathPattern.matches?` | exact は一致、tree は前方の要素列の一致。幹も含む |
| `PathPattern::covers` | C `PathPattern.covers?` | exact は同じ exact、tree は幹が前方の列となる exact/tree を覆う |
| `Name::parse` | D `NameLabelWF`・`NameWordWF` | ASCII 小文字化後のラベル条件と四つの全数字ラベルの除外に一致する |
| `Name::labels` | D `Word` | ラベル列は左から通常の順である |
| `NamePattern::new` | D `NamePattern` | 整形式の幹で exact/one/many を構築する |
| `NamePattern::parse` | D `NamePattern`・WF | 完全一致・`*.`・`**.` の字句境界である |
| `NamePattern::kind` | D `NamePattern` の構成子 | exact/one/many を区別する |
| `NamePattern::stem` | D 同構成子の `stem` | 小文字化した幹を保つ |
| `NamePattern::matches` | D `NamePattern.matches?` | exact は同列、one は先頭一ラベルを除いた列が幹、many は幹より長い末尾一致である |
| `NamePattern::covers` | C `NamePattern.covers?` | 内側 exact は所属、one/one は同じ幹、many は内側 one/many の幹との末尾一致である |
| `Family::width` | D `Family.width` | V4=32、V6=128である |
| `IpAddress::family` | D `IPAddr.family` | 族を数値と独立に保持する。mapped は V6 である |
| `IpAddress::bits` | D `IPAddr.bits.val` | V4 の u32 を無損失で u128 へ広げる。V6 は u128 の値である |
| `IpPattern::exact` | D `IPPattern.exact` | 一つの族と数値を保持する |
| `IpPattern::cidr` | D `CIDR.WF`・`IPPattern.normalize` | prefix の幅と host bits=0を検査し、最大 prefix だけ exact へそろえる |
| `IpPattern::address` | D `IPAddr` / `CIDR.network` | exact の点または CIDR のネットワークを返す |
| `IpPattern::prefix_len` | D `IPPattern`・Canonical | exact は None、CIDR は幅未満の prefix である |
| `IpPattern::lo` | I `IPPattern.lo` | 点またはネットワークの値である |
| `IpPattern::hi` | I `IPPattern.hi`・D `CIDR.hiFin` | host bits=0の値へ下位ビットの mask を OR する。同じ閉区間の上端になる |
| `IpPattern::matches` | D `IPPattern.Matches`・I `matches_iff_interval` | 同族かつ閉区間内である |
| `IpPattern::covers` | I `IPPattern.Covers/covers?` | 同族かつ内側の両端が外側の区間内である |
| `host_mask`（非公開） | D `CIDR.blockSize` と `hi` | `2^hostBits - 1`。128 bit 全体のときは `u128::MAX` を直接使う |
| `HostTarget::parse` | D `HostTarget`・`FourDigitLabels` | Name/IP を分ける字句境界である。不正な四数字ラベルを Name へ戻さない |
| `HostPattern::parse` | D `HostPattern`・WF/Canonical | Name/IP を分け、IP の幹のワイルドカードを拒否する字句境界である |
| `HostPattern::matches` | D `HostPattern.Matches` | Name/Name と IP/IP だけを照合する |
| `HostPattern::covers` | R `HostPattern.covers?` | Name/Name と IP/IP だけを覆う |
| `Port::new` | D `Port = Fin 65536` | u16 の全域を保持する |
| `Port::from_int` | D `Port.ofInt?` | i64 から u16 への try_from により0〜65535だけを受理する |
| `Port::value` | D `Port.val` | 検査済みの値を返す |
| `PortRange::new` | D `PortRange.WF` | lo ≤ hi を要求する |
| `PortRange::lo` | D `PortRange.lo` | 閉区間の下端を保つ |
| `PortRange::hi` | D `PortRange.hi` | 閉区間の上端を保つ |
| `PortRange::matches` | D `PortRange.Mem` | 両端を含む |
| `PortRange::covers` | R `PortRange.covers?` | 区間の包含である |
| `EndpointPattern::matches` | D `EndpointPattern.Matches` | host の所属と port の所属の積である |
| `EndpointPattern::covers` | R `EndpointPattern.covers?` | host と port をともに一原子で覆う |
| `Target::kind` | D `Target.kind` | path/host/endpoint を区別する |
| `Range::kind` | D `Range.kind?` | Top だけが種類を持たない |
| `Range::fits_kind` | D `Range.FitsKind` | Top または同じ種類である |
| `Range::matches` | D `Range.Mem` | Top は全対象、それ以外は同じ構成子の所属を使う |
| `Range::matches_kind` | D `Range.MemK` | 対象の種類との一致と所属をともに要求する |
| `Range::covers` | R `Range.covers?` | Top が全てを覆い、非Topは同じ種類の一原子だけを覆う。Topを覆わない |
| Eq/Ord/Hash の derive | D 各型の `DecidableEq`、原子の構造比較の契約 | 正規形の構成子・幹・族・値・区間を使う。被覆を流用しない。Rust の整列順自体は Lean の意味の順序を主張しない |
| `ip_text::four_digit_labels` | D `FourDigitLabels` | 空でない全数字ラベルがちょうど4個かを判定する |
| `ip_text::parse_address` | D の外側の字句境界 | DET-01 の IPv4 と採択した IPv6 正規形だけを数値へ変換する |
| `ip_text::parse_pattern` | D の外側の字句境界と `CIDR.WF`・normalize | 正規の prefix を読み、数値の検査付き構築を使う |
| `ip_text::format_address` | D の外側の字句境界 | 同じ族の数値を DET-01 の文字列へ表示する |
| `ip_text::format_pattern` | D の外側の字句境界と Canonical | 正規化済みの exact または CIDR を表示する |
| `parse_v4`（非公開） | D の外側、I `Groups` の4個×8 bitとの数値対応 | 四つの十進要素を u8 に検査付きで変換し、上位から u32 へまとめる |
| `parse_v6`（非公開） | D の外側、I `Groups` の8個×16 bitとの数値対応 | mapped は混合表記、他は8個の u16 を上位から u128 へまとめる |
| `parse_v6_groups`（非公開） | D の外側 | 高々8個の16進要素を読む。正規形との字句一致は公開入口が確かめる |
| `format_v4`（非公開） | D の外側 | 四つの u8 の十進表示である |
| `format_v6`（非公開） | D の外側 | 小文字、先頭0除去、2要素以上の最長の零列の圧縮、同長なら左の列という採択済みの表示である |

Lean の所属は整形式性を要求しないが、Rust は検査済み構築により整形式の値だけを公開する。これは範囲を広げる意味の変更ではない。相違が必要となる箇所は見つからなかった。

IPv6 の表示の詳細は [RFC 5952 §4](https://www.rfc-editor.org/rfc/rfc5952.html#section-4) と[§5](https://www.rfc-editor.org/rfc/rfc5952.html#section-5) を照合した（2026-10-28）。適用する入力は DET-01 が採った部分に限る。RFC 全体への適合、RFC 4291 の全ての表記の受理、mapped 以外の混合表記を保証へ加えていない。

## 独立期待値と作成時の関門

公開の `test-audit` の四問に従い、持ち主を代数の公開 API とした。表の期待は固定した値であり、所属や被覆から再計算していない。差し込み口は追加していない。既存テストは旧 Scope の公開入口と失敗位置を扱い、新しい IP/CIDR と被覆へ届かないため、代数に次の14件を置いた。既存テストは変更・削除していない。

| テスト | 守る契約と、捕まえる退行 |
|---|---|
| `path_membership_and_atomic_cover` | 幹を含む tree、要素境界、根、大小文字、exact/tree の向きの誤り |
| `path_lexical_boundary_rejects_repairs` | 不正なパス・ワイルドカードを修復して受理する誤り。対象の `*` は保持する |
| `name_membership_and_atomic_cover` | one/many が幹を含まないこと、一段と多段の混同、被覆の幹の向き |
| `name_and_direct_ip_classification` | ASCII の検査と小文字化、不正な四数字ラベルへの Name fallback、IP の幹の wildcard、短い数値風の名前の誤拒否 |
| `ip_parser_and_formatter_have_independent_numeric_examples` | 14組の固定した文字列と数値。最長・左優先・一要素を圧縮しない表示、mapped の数値と族の消失 |
| `ip_parser_rejects_noncanonical_or_out_of_domain_text` | 非正規 IPv4/IPv6、mapped の16進表記、他の混合表記、zone ID・IPvFuture・角括弧の誤受理 |
| `cidr_normalization_bounds_and_rejection` | `/0`・`/1`・最大直前・最大 prefix の両端、host bits・prefix の先頭0・幅超過、最大 prefix の exact 化 |
| `ip_membership_keeps_family_and_closed_endpoints` | 閉区間の両端と直外、mapped とIPv4、異族の `/0` の混同 |
| `ip_atomic_cover_is_same_family_interval_inclusion` | 同族の区間包含、exact の一点、異族や逆向きの被覆の誤受理 |
| `host_name_and_ip_never_convert_into_each_other` | ホスト名とIPの相互変換を所属・被覆へ加える誤り |
| `ports_and_endpoint_product_use_closed_bounds` | 整数の両端と範囲外、逆転、閉区間とhost/portの積の片側だけの成功 |
| `atomic_cover_does_not_combine_a_union` | endpoint の0..9を0..4と5..9で、IPv4の/24を二つの/25で覆ってしまう誤り |
| `top_and_kinds_follow_domain_instead_of_set_equivalence` | `/**`・IPv4 `/0` によるTopの被覆、種類違いの所属・被覆、MemKの種類の見落とし |
| `equality_hash_and_order_preserve_narrow_atoms` | 包含される狭い原子の削除、被覆による等号、mappedの族消失。最大prefixと大小文字の採択済み正規化も確かめる |

## LR-U8 の点検の材料

| 観点 | 差分の点検結果 |
|---|---|
| 固定幅 | IP は V4(u32)/V6(u128)、要素は u8/u16、prefix は u8、port は u16。数値と族を保持し、V4からu128へは `u128::from` を使う |
| シフト | `host_mask` は検査後の0..=128を受け、`checked_shl` を使う。128ではMAXを返し、128超は処理系の不具合として扱う。mappedは128 bit上の32 bitシフト、IPv6の結合は高々8回の16 bitシフトである |
| 区間の上端 | `network + blockSize - 1` を固定幅で計算せず、host bits=0を確認したnetworkとmaskのORを使う。`2^128` を値として作らず、`/0` の上端もMAXへ収まる |
| 検査付き変換 | 十進要素は文字と桁数を調べてu8へparse、16進要素は高々4桁からu16へparse、prefixはu8へparseした後に族の幅を検査する。整数のportは `u16::try_from(i64)`。prefixからhost bitsを得る入口はchecked_subで検査する。切り詰める `as` 変換はない |
| usize | 数値のアドレス・prefix・portをusizeへ変換しない。usizeはスライス・長さ・添字だけに使う。IPv6のcountはget_mutで上限8を先に検査し、加算は最大16。配列の差・範囲・byte添字は固定長8/16から作る |
| 個数と長さ | IPv4はちょうど4要素、IPv6はちょうど8要素（圧縮時は高々7要素を明記）、四数字ラベルの分類はちょうど4回と余りの確認だけを行う。パス・Nameの要素数は入力長に制限され、再帰を使わない。既存にないDNSのラベル長等の上限を追加しない |
| 依存方向 | 本番のscope.rsは外部のモジュールをimportせず、ip_textは親の数値型だけをimportする。標準の文字列・配列・formatだけを使う。builtins・HTTP・VM・ネットワーク・暗号・Wasmtime・サーバへの直接importもI/Oもない。checked_scope→types::scopeだけである |
| ヒープの不変条件 | Rustの所有するString/Vecを一時的に作るだけで、VMの値・安全点を越える保存・GCの根・ポインタを変えない。H/doc/heap/stressは本枝では追加しない |
| 実ビルドの限界 | 既定workを実行する。32ビットやネットワーク/WASMを外した構成の実ビルドを行ったとは数えない。planの現行Cargo・check入口の制約を引き継ぐ |

## 検査

コマンドはリポジトリの根から実行した。ログ内の手元の絶対パスは `<wt>` 等へ置換し、検査の出力と時間・RSSの原値を保つ。

| 検査 | コマンド | 結果 |
|---|---|---|
| 代数の局所検査 | `cargo test -p benitoite --lib types::scope` | 終了0。14成功、失敗0、無視0。テスト部0.01秒、初回ビルド31.79秒。[ログ](local-scope.log)。その後の表の追加行は作業末のlib全件で検査する |
| 旧入口の局所検査 | `cargo test -p benitoite --test checked_args --test runtime_builtins scope_` | 終了0。checked_args 2件、runtime_builtins 1件が成功。外側25.178秒。[ログ](local-legacy.log) |
| W-R 選択 | `scripts/check.sh --level work --base 0b684ee4284fac6d6f9f9159fad9bc806e41e369 --dry-run` | 終了0。[初回の選択](work-dry-run.log)。fmt・lint_default・lib_default・tests_related（全40ターゲット）・source_rules・skill_generated・spec_tallyの7項目である |
| W-R 実行 | `/usr/bin/time -l scripts/check.sh --level work --base 0b684ee4284fac6d6f9f9159fad9bc806e41e369` | 初回はlint_defaultで終了1、外側33.437秒。[ログ](work.log)。修正後の続行で全選択項目の成功を確認した。外側timeの終了と検査の終了の区別は下記のとおりである |

続行の正確なコマンドは次のとおりである。`--test '*'` は全統合ターゲットであり、当初の `--test` 省略と同じ実行になる。[続行の選択](work-retry-dry-run.log)と[生ログ](work-retry.log)、[計時と終了の原記録](work-retry-exit.json)を保存した。

```sh
/usr/bin/time -l scripts/check.sh --level work \
  --base 0b684ee4284fac6d6f9f9159fad9bc806e41e369 \
  --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally \
  --test '*'
```

| 項目 | 結果 |
|---|---|
| 続行の検査スクリプト | 終了0。ログ末尾の `selected checks passed` と、scripts/check.shの同じ経路が直後にexit 0となることを照合した。7項目が全て成功した |
| 既定lib | 1,347成功、失敗0、既存の無視21。テスト部71.07秒。新規14件を含む |
| 統合 | 全40ターゲット、395成功、失敗0、既存の無視10。対象の除外やignoreの追加はない |
| clippy・fmt・規約 | 成功。Skill再生成の前後でgit statusの差はなく、仕様対応の自己検査・集計も成功した |
| 外側timeの終了 | 1。検査成功後に `sysctl kern.clockrate: Operation not permitted` が出たためである。検査の失敗とは区別する |
| 外側の経過時間 | timeの原値459.20 real秒（1461.89 user秒、44.24 sys秒）。Pythonの外側時計は459.202秒（7分39.202秒）。07:08:59.570562〜07:16:38.773606 UTC |
| time -lの最大常駐量 | sysctlの取得拒否により出力されず、取得不能である。0とは扱わない |
| 最大常駐量の補助値 | 同じ一括実行を待ち終えた `getrusage(RUSAGE_CHILDREN).ru_maxrss` の原値3,287,580,672 bytes。3,135.28125 MiB、3.061798095703125 GiB（約3.062 GiB）である。各プロセスのRSSの合計でも同時の全プロセスの合計でもない |

検査中の公開コメントの整備は、APIの説明と設計書の参照だけを変え、識別子・式・型・入力・期待値・設定を変えていない。この後に古くなったfmtとclippyだけを `scripts/check.sh --level work --base 0b684ee4284fac6d6f9f9159fad9bc806e41e369 --only fmt,lint_default --dry-run` で確認し、同指定の実検査を `/usr/bin/time -p` で包む。計時のアクセス制限は `-p` では起きない。[選択](comments-dry-run.log)・[ログ](comments-check.log)・[終了と時間](comments-check-exit.json)のとおり終了0、外側7.613秒（time原値real 7.61秒）で成功した。これはfmt/clippyの再確認だけであり、全統合の再実行とは数えない。

### R10.1b: RV-R10.1 の指摘修正と再検査

軽1は、R10.2aへの申し送りにRustとLeanの整列順の差と具体例を加えた。順を合わせる実装はR10.7へ残す。軽2は、`equality_hash_and_order_preserve_narrow_atoms` のsort・dedupの後の確認を件数2と両要素の包含へ変えた。狭い原子を消さない契約は保持し、deriveの整列順を固定しない。既存の同じ公開APIのテストを修正し、新しいテストや差し込み口は加えていない。

軽5は、テストのDET-01の引用を設計書01-12「操作の対象の範囲の領域と被覆」へ置き換えた。節の実在と、許可されたソース内のほかの判断・作業IDの引用がないことを`rg`で確認した。軽6は、mappedの表示の定数の添字を配列の分解へそろえ、`host_mask` を`checked_shl`へ変え、`InvalidScope`の全7値と`Endpoint`・`EndpointPattern`の全4公開欄へ`///`を加えた。`host_mask`の128超はassertionで検出し、設計書02-09「panic 境界」に従って処理系の不具合とする。シフト自体はpanicせず、0..=128の結果と公開APIの型は保つ。

軽4も含め、指定されたB_WORKを基準に、全統合・lib全件・clippy・fmt・source_rulesを含むworkを一度再実行し、全7項目が成功した。今回のログは`r10.1b-`の名前で保存し、前回のログは上書きしていない。

| 項目 | 結果 |
|---|---|
| 選択 | `scripts/check.sh --level work --base 0b684ee4284fac6d6f9f9159fad9bc806e41e369 --dry-run` は終了0。fmt・lint_default・lib_default・tests_related（全統合）・source_rules・skill_generated・spec_tallyの7項目。[選択ログ](r10.1b-work-dry-run.log) |
| 実行と終了 | 同じ指定から`--dry-run`を除き、`/usr/bin/time -p`の内側のshから実行した。shはcheck.shの直後の`$?`を直接記録し、その状態でexitする。check.sh自身は終了0（[直接の記録](r10.1b-check-exit.txt)）、外側timeも終了0。[実行ログ](r10.1b-work.log)・[終了と時間](r10.1b-work-exit.json) |
| lib全件 | 1,347成功、失敗0、既存の無視21。テスト部71.55秒。代数の14件を含む |
| 全統合 | 40ターゲット・395成功、失敗0、既存の無視10。除外・ignoreの追加はない |
| clippy・fmt・規約・生成物 | lib/tests/examplesのclippy、fmt、source_rules、Skill生成物の照合、仕様対応の自己検査・集計が成功 |
| 外側の時間 | time原値はreal 443.78秒、user 1408.42秒、sys 45.84秒。Pythonの外側時計は443.786秒（7分23.786秒）。2026-10-28 07:37:31.083434〜07:44:54.870536 UTC |
| 最大常駐量の補助値 | 同じ実行だけを待った`getrusage(RUSAGE_CHILDREN).ru_maxrss`の原値3,147,415,552 bytes（3,001.609375 MiB、約2.931 GiB）。各プロセスのRSSの合計でも同時の全プロセスの合計でもない。timeは`-p`でありRSSを採取しない |

R10.1bの差分は本番19行追加・10行削除（純増9行）、テスト5行追加・2行削除（純増3行）である。テストの追加・削除はなく14関数を保つ。`builtins/checked_scope.rs`と読み取り専用の`reviews/RV-R10.1.md`は開始時のハッシュと一致する。`types/mod.rs`の既存の公開行にも触れていない。検査後は結果の文書とログのパス表記だけを整え、Rustの関係状態は変えていない。

## 初回の失敗と修正

代数と旧入口の初回の局所検査は成功した。初回W-Rはfmtを通過した後、lint_defaultで終了1となった。本番21件の添字・算術の禁止lintと、テスト39箇所のunwrapの禁止lintが原因である。[初回ログ](work.log)と[終了・時間](work-exit.json)を保存した（外側33.437秒、timeのreal原値33.43秒）。

修正では、prefixの引き算をchecked_subにし、検査済みの幅・個数の演算は飽和しない条件を保ってsaturating演算で表した。IPv6の配列の組み立てを固定長の配列パターン・イテレータへ変え、表示もtake/skipで辿る。テストはResultを返して`?`を使う。lint免除・期待値の変更は加えていない。

続行の最初のdry-runは、明示のtests_relatedには`--test`が必要なため終了2になった（[ログ](work-retry-dry-run-invalid.log)）。`--test '*'`を付け、元の全統合ターゲットと同じ選択へ直した。修正で古くなったfmt、失敗したlint_default、未実行のlib_default/tests_related/source_rules/skill_generated/spec_tallyだけを名指しして続行する。自動選択の全項目と一致するため、この部分選択だけを根拠に水準全体の成功とせず、初回の選択との対応を確認する。

初回timeは`sysctl kern.clockrate: Operation not permitted`でRSSを出力しなかった。サンドボックスの制限であり、RSSを0と記録しない。続行でも`/usr/bin/time -l`を使い、補助として同じ実行だけを持つPythonプロセスの`resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss`を採取する。ローカルのmacOS `getrusage(2)`はru_maxrssの単位をbytesと定めている。[ローカルの単位の確認](getrusage-units.txt)も残した。続行の実値と取得不能の範囲は上表のとおりである。

## 計画との差と申し送り

停止条件への該当はない。DET-01/02 の字句・領域・略記、Lean の定義・規則・仮定、公開契約、依存は変えていない。新しいRFC適合保証も加えていない。計画との差は、初回lint失敗後の続行、続行の名指しに必要な全統合の明示指定、timeのRSS取得不能に対するgetrusageの補助採取である。

R10.2a は `types::scope::Range` を効果の原子へ接続し、名前が一致する場合に限って範囲の `covers` を使う。構造の Eq/Ord/Hash を鍵と重複除去に使い、被覆で狭い原子を消さない。`Range::Top` は名前を持たず種類も確定しないので、名前と `fits_kind` の確認は利用側で行う。範囲の列や効果集合の和の判定を本枝で先置きしていない。

Rustのderiveは種類を先に比べるため`exact /b < tree /a`だが、Leanの`Release/Order/Range.lean`は`pathCode = 2 * wordCode s + 種類`によりこの例で`tree /a < exact /b`となる。IPもRustは（族・値・prefix）、Leanはexactを`2 * ipAddrCode`、cidrを`2 * cidrCode + 1`とする偶数・奇数の符号で比べるため、整列済みの列を交換・比較に使うR10.7で順を合わせるか決める。

R10.3 は正規形をこのAPIで構築し、元の字句・位置・略記を別に保持する。R30.1で初めて旧Scopeを `HostPattern` / `HostTarget` のIPも含む入口へ切り替え、保存パターンの正規化と誤り文の変更を行う。URLの数値風hostの拒否・IPv6の正規化はHTTP側の枝であり、この直接入力parserの受理と混同しない。K10で字句境界とLeanの書き出しを接続する。

`check-formal.sh`・Leanビルド・short性能比較は実行していない。それぞれ計画の後続枝・取りまとめの担当とし、本枝の成功から形式化との全比較や測定の成功を主張しない。

## 時間

2026-10-28に着手し、07:19:27 UTCに結果を確定した。最初に採取した時刻は06:54:26 UTC（15:54:26 JST）であり、それ以前にも指定文書を読んでいる。記録した時刻間は約25.0分である。着手直後の時計を採取していないため、全体の外側所要は約30分、能動時間は約20分という概算である。

検査の外側時間は、旧入口の局所25.178秒、初回W-R 33.437秒、続行459.202秒、コメント後のfmt/clippy 7.613秒である。代数の局所検査は初回ビルド31.79秒・テスト0.01秒で、外側の時計を別に採っていない。検査中にも結果記録とコメントの点検を行ったため、これらを能動時間へ足したり外側所要から単純に引いたりしない。性能測定・独立レビュー・回答待ちは本枝では行っていない。10時間の停止条件には達していない。

R10.1bの所要は約13分である。最初に採取した時刻2026-10-28 07:34:05 UTCから、結果と最終差分を確認した07:46:12 UTCまでは12分7秒であり、それ以前の読み込みと記録の仕上げを含む概算とした。work再検査の外側443.786秒を含む。検査後のRustの変更、性能測定、独立レビュー、回答待ちはない。
