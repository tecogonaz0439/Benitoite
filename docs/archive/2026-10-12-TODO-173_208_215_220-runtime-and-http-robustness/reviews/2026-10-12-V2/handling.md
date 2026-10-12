# V2 のレビューへの対応

作業 Z1（f63f5d86）で直した。

- 中: `heap_constants_keep_identity_when_only_the_cache_roots_them` に辞書の定数の種類を加えた。レジスタも根になる 3 件には、その旨のコメントを置いた。
- 低: 閾値のコメント、回収回数の増加の表明、補助の関数の前提、対象の数の下限を直した。
- `constants.last()` で観察の根を読む 4 か所は直さず、後の課題として docs/todo に残した。
