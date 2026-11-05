"""18名の実ソースの定義位置と、調査した元Defの対応を表へ出す。"""
import json
import os
import re
from inventory import HERE, ROOT, FORMAL, digest, write
from composition_inventory import read_pages
from ledger import normalized


def generate():
    closure = json.loads((HERE / 'resume3-closure-summary.json').read_text())
    bodies = json.loads((HERE / 'resume3-body-sources.json').read_text())
    summary = json.loads((HERE / 'ledger-summary.json').read_text())
    rust = read_pages(summary, 'rust_pages')
    lines = ['# 衝突18名と処理系の実定義の対応', '',
        '宣言の型、本体の操作順、参照する関数を読み、通常側・精密側のどちらの元Defに当たるかを判定した。脱糖後の完全な等号やRust/Leanの全比較の証明ではない。全18名に同名のRust組込み登録はなく、実体はBenitoiteの標準ソースにある。Listの二helperは非公開である。この表の対応をL70が公開名の収集へ適用し、精密側の公開形はU02で別に決める。', '',
        '| 名前 | 実定義（ファイル・行） | Rust登録 | 通常側の元Def／精密側の元Def | 判定と根拠 |',
        '|---|---|---|---|---|']
    records = []
    for name in closure['renamed_names']:
        module, fn = name.split('.')
        file = ROOT / f'crates/benitoite/src/prelude/stdlib/{module}.bnt'
        text = file.read_text()
        match = re.search(r'^(?:public )?function ' + re.escape(fn) + r'(?=[\[(])', text, re.M)
        assert match, name
        line = text.count('\n', 0, match.start()) + 1
        end = text.index('end function', match.end()) + len('end function')
        source = text[match.start():end]
        assert '@builtin' not in source
        assert not [r for r in rust if normalized(r['name']) == name], name
        pair = [b for b in bodies if b['name'] == name]
        assert len(pair) == 2
        ordinary = next(b for b in pair if not b['refined'])
        refined = next(b for b in pair if b['refined'])
        if module == 'List':
            if fn.endswith('From'):
                reason = 'xs・callback・i・accの四引数。getのOption分岐、i+1、appendによる通常の再帰。精密側のhead/tailによる残り列の再帰とは異なる'
            else:
                reason = '通常のListを返し、同名Fromへi=0・空accを渡す。精密側の長さの篩とhead/tail版helperを持たない'
        elif module in {'Map', 'Set'}:
            reason = 'toList→通常List.' + fn + '→fromList。通常の' + module + 'を返す。精密側の大きさの篩を返す契約ではない'
        elif module == 'NonEmptyList':
            reason = 'firstへfを適用しrestをList.mapしてレコードを再構築する。精密側の正の長さを持つListをList.mapへ渡す本体とは異なる'
        else:
            reason = '裸のCheckedInteger/CheckedLength/CheckedIndexレコードを入力に、その通常の欄アクセサを呼ぶ公開ラッパー。精密側の篩付き入力と直接のパターン射影とは異なる'
        def link(path, n):
            rel = os.path.relpath(path, HERE)
            return f'[{path.name}:{n}]({rel}#L{n})'
        if module == 'List':
            ordinary_location = ('StandardListBodies.lean', 'def listFromDefinition' if fn.endswith('From') else 'def listHigherRow')
            refined_location = ('StandardHeadTailBodies.lean', 'def fromDefinition' if fn.endswith('From') else 'def publicDefinition')
        elif module in {'Map', 'Set'}:
            ordinary_location = ('StandardCollectionBodies.lean', 'def collectionHigherRow')
            refined_location = ('StandardCollectionRefinedBodies.lean', 'private def higherRow')
        elif module == 'NonEmptyList':
            ordinary_location = ('StandardOrdinaryCoreProgram.lean', ' | .nonemptyMap => .letIn')
            refined_location = ('StandardHeadTailBodies.lean', 'def nonemptyPublicDefinition')
        else:
            ordinary_location = ('StandardOrdinaryCoreBodies.lean', 'def Getter.publicDefinition')
            refined_location = ('StandardSafeBodies.lean', 'def PreciseGetter.row')
        def location(spec):
            path = FORMAL / spec[0]
            content = path.read_text()
            n = content[:content.index(spec[1])].count('\n') + 1
            return path, n
        ordinary_file, ordinary_line = location(ordinary_location)
        refined_file, refined_line = location(refined_location)
        declaration = FORMAL / 'StandardModelDeclarations.lean'
        decltext = declaration.read_text()
        def origin(b):
            needle = '| .' + b['constructor'] + ' => (' + b['expression']
            n = decltext[:decltext.index(needle)].count('\n') + 1
            return f"`{b['constructor']}: {b['expression']}`（{link(declaration,n)}）"
        lines.append(f"| `{name}` | {link(file,line)} | 該当なし | 通常: {origin(ordinary)}、定義: {link(ordinary_file,ordinary_line)}<br>精密: {origin(refined)}、定義: {link(refined_file,refined_line)} | 通常側。{reason} |")
        records.append({'name': name, 'file': str(file.relative_to(ROOT)), 'line': line,
            'definition': source, 'source': digest(file), 'rust_registration': None,
            'ordinary_body': ordinary['constructor'], 'refined_body': refined['constructor'],
            'ordinary_original': ordinary['expression'], 'refined_original': refined['expression'],
            'ordinary_definition': {'file': str(ordinary_file.relative_to(ROOT)), 'line': ordinary_line},
            'refined_definition': {'file': str(refined_file.relative_to(ROOT)), 'line': refined_line},
            'verdict': '通常側', 'reason': reason})
    lines += ['', '通常側の具体の定義は、Listが `StandardListBodies.lean`・`StandardActualListBodies.lean`、Map/Setが `StandardCollectionBodies.lean`、NonEmptyListが `StandardOrdinaryCoreProgram.lean` の `API.body .nonemptyMap`、Rangeが `StandardOrdinaryCoreBodies.lean` の `Getter.publicDefinition` である。精密側は `StandardHeadTailBodies.lean`・`StandardCollectionRefinedBodies.lean`・`StandardSafeBodies.lean` の対応する定義である。上の本番の保持箇所から、それぞれの元の式を辿れる。', '',
        '集計: 通常側18、精密側0、どちらにも当たらない0、未判定0。公開名から内部名へ写す処理の実装と、実ソースとの最終照合はL70の受け口に残す。']
    (HERE / 'actual-definition-correspondence.md').write_text('\n'.join(lines) + '\n')
    write(HERE / 'resume4-actual-definitions.json', records)
    return records


if __name__ == '__main__':
    print(len(generate()))
