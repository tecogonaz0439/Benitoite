"""Independent host files exercised through the actual helper and tool commands."""
import hashlib
import json
import pathlib
import subprocess
import tempfile
import unittest

ROOT=pathlib.Path(__file__).resolve().parents[2]
TOOL=ROOT/'tools/named-arguments-migrate/migrate.py'
HELPER=ROOT/'target/debug/examples/named_arguments_inventory'
SOURCE='''import Benitoite.Unofficial.IO.Console
function add(left: Integer, right: Integer) -> Integer
 return left + right
end function
function exercise() -> Unit uses Console.Write, Assert.Check
 // add(3, 4) must stay a comment 日本語
 bind text <- "add(5, 6)"
 bind pair <- Pair(1, 2)
 bind fs: List[function(Integer) -> Integer] <- [lambda(x) return x + 1, lambda(y) return y + 2]
 bind zs <- List.map([1, 2], lambda(n) return add(n, 2))
 Console.writeLine(text)
 Assert.equal(add(7, 8), 15)
end function
'''

class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='.n17-check-',dir=ROOT)
        self.dir=pathlib.Path(self.temp.name)
        self.output=self.dir/'out'
    def tearDown(self): self.temp.cleanup()
    def run_tool(self,*args,ok=True):
        result=subprocess.run(['python3',str(TOOL),*map(str,args)],cwd=ROOT,capture_output=True,text=True)
        if ok: self.assertEqual(result.returncode,0,result.stderr)
        else: self.assertNotEqual(result.returncode,0,result.stdout)
        return result
    def inventory(self):
        self.run_tool('inventory',self.dir.relative_to(ROOT),'--helper',HELPER,'--output',self.output)
        return json.loads((self.output/'manifest.json').read_text())
    def approve(self,manifest):
        for row in manifest['candidates']:
            if row['edits'] and not row['hold_reasons']: row['review']='approved'
        path=self.output/'reviewed.json'
        path.write_text(json.dumps(manifest))
        return path,hashlib.sha256(path.read_bytes()).hexdigest()
    def test_reviewed_manifest_cli_without_inventory(self):
        # 共通部分への接続と、旧 CLI に残す承認・依存の検証を独立に確かめる。
        p=self.dir/'manual.bnt'; before=b'call(1)\n'; p.write_bytes(before)
        relative=str(p.relative_to(ROOT))
        unit={'path':relative,'source_sha256':hashlib.sha256(before).hexdigest()}
        manifest={'version':1,'inputs':[unit],'candidates':[
            {**unit,'id':'replace','review':'approved','hold_reasons':[],
             'depends_on':['insert'],'edits':[{'start':5,'end':6,'before':'1','after':'2'}]},
            {**unit,'id':'insert','review':'pending','hold_reasons':[],
             'edits':[{'start':5,'end':5,'before':'','after':'value: '}]}]}
        self.output.mkdir()
        reviewed=self.output/'reviewed.json'
        def save():
            reviewed.write_text(json.dumps(manifest))
            return hashlib.sha256(reviewed.read_bytes()).hexdigest()
        digest=save()
        self.assertIn('approve dependent component',self.run_tool('apply',reviewed,'--manifest-sha256',digest,ok=False).stderr)
        self.assertEqual(p.read_bytes(),before)
        manifest['candidates'][1]['review']='approved'
        manifest['candidates'][1]['hold_reasons']=['manual_hold']
        digest=save()
        self.assertIn('held candidates cannot be approved',self.run_tool('apply',reviewed,'--manifest-sha256',digest,ok=False).stderr)
        self.assertEqual(p.read_bytes(),before)
        manifest['candidates'][1]['hold_reasons']=[]
        digest=save()
        diff=self.output/'review.diff'
        self.run_tool('diff',reviewed,'--output',diff)
        self.assertIn('-call(1)\n+call(value: 2)\n',diff.read_text())
        self.assertEqual(p.read_bytes(),before)
        self.run_tool('apply',reviewed,'--manifest-sha256',digest)
        self.assertEqual(p.read_bytes(),b'call(value: 2)\n')
        self.assertIn('already applied; no diff',self.run_tool('apply',reviewed,'--manifest-sha256',digest).stdout)
        self.assertEqual(p.read_bytes(),b'call(value: 2)\n')
    def test_host_positions_and_atomic_reviewed_application(self):
        # All three hosts contain the same program, but escape decoding changes byte positions.
        inputs={
            'program.bnt':SOURCE.encode(),
            'raw.rs':('/* ignored: "function fake() end function" */\nconst SCRIPT: &str = r###"'+SOURCE+'"###;\n').encode(),
            'escaped.rs':('const SCRIPT: &str = '+json.dumps(SOURCE,ensure_ascii=False).replace('lambda(n)',r'lambda(\u{6e})').replace('add(n, 2)',r'add(\u{6e}, 2)')+';\n').encode(),
            'guide.md':('# Example\r\n\r\n```benitoite\r\n'+SOURCE.replace('\n','\r\n')+'```\r\n').encode(),
        }
        for name,data in inputs.items(): (self.dir/name).write_bytes(data)
        original={name:p for name,p in inputs.items()}
        manifest=self.inventory()
        self.assertEqual(len(manifest['inputs']),4)
        self.assertTrue(all(u['typed'] for u in manifest['inputs']),manifest['inputs'])
        self.assertTrue(any(r['kind']=='component' and r['names']==['value'] for r in manifest['candidates']))
        self.assertTrue(any(r['kind']=='annotation' or any(s['kind']=='annotation' for s in r['contract_sources']) for r in manifest['candidates']))
        reviewed,digest=self.approve(manifest)
        self.run_tool('apply',reviewed,'--manifest-sha256','0'*64,ok=False)
        self.assertEqual({name:(self.dir/name).read_bytes() for name in inputs},original)
        self.run_tool('apply',reviewed,'--manifest-sha256',digest)
        after={name:(self.dir/name).read_bytes() for name in inputs}
        for name,data in after.items():
            with self.subTest(host=name):
                self.assertIn(b'// add(3, 4) must stay a comment',data)
                self.assertIn(b'add(5, 6)',data)
                self.assertIn(b'Pair(1, 2)',data)
                self.assertIn(b'add(left: 7, right: 8)',data)
                self.assertIn(b'lambda(value) return add(left: value, right: 2)',data)
                self.assertIn(b'List[function(x: Integer) -> Integer]',data)
                self.assertIn(b'lambda(x) return x + 2',data)
        second=self.run_tool('apply',reviewed,'--manifest-sha256',digest)
        self.assertIn('no diff',second.stdout)
        self.assertEqual({name:(self.dir/name).read_bytes() for name in inputs},after)
    def test_stale_source_and_overlapping_ranges_rejected_before_writes(self):
        p=self.dir/'program.bnt'; p.write_text(SOURCE)
        manifest=self.inventory(); reviewed,digest=self.approve(manifest)
        p.write_text(SOURCE+'# changed\n')
        self.run_tool('apply',reviewed,'--manifest-sha256',digest,ok=False)
        self.assertEqual(p.read_text(),SOURCE+'# changed\n')
        p.write_text(SOURCE)
        row=next(r for r in manifest['candidates'] if r['review']=='approved' and r['edits'])
        duplicate=dict(row['edits'][0]); duplicate['after']='wrong: '
        row['edits'].append(duplicate)
        reviewed,digest=self.approve(manifest)
        self.run_tool('apply',reviewed,'--manifest-sha256',digest,ok=False)
        self.assertEqual(p.read_text(),SOURCE)
    def test_unresolved_conflicting_and_collision_components_are_held(self):
        sources=[
            'function main() -> Unit\n bind fs <- [lambda(x) return x, lambda(y)\n bind x <- 1\n return y + x\n end lambda]\nend function\n',
            'function main() -> Unit\n bind f <- lambda(n) return n + 1\n bind xs <- List.map([1], f)\n bind ys <- Result.mapError(Result.Error(2), f)\nend function\n',
            'function main() -> Unit\n bind value <- 10\n bind fs <- List.map([1], lambda(n) return value + n)\nend function\n',
            'public function maker() -> function(Integer) -> Integer\n return lambda(n) return n + 1\nend function\n',
        ]
        for i,s in enumerate(sources): (self.dir/f'case{i}.bnt').write_text(s)
        m=self.inventory()
        self.assertTrue(all(u['typed'] for u in m['inputs']),m['inputs'])
        reasons={reason for r in m['candidates'] for reason in r['hold_reasons']}
        self.assertIn('local_name_collision',reasons)
        self.assertIn('conflicting_expectations',reasons)
        self.assertIn('public_contract',reasons)
        capture=[r for r in m['candidates'] if r['path'].endswith('case2.bnt') and r['kind']=='component']
        self.assertTrue(any('local_name_collision' in r['hold_reasons'] for r in capture))
        for r in m['candidates']:
            if r['hold_reasons']: r['review']='approved'; break
        path,digest=self.approve(m)
        self.run_tool('apply',path,'--manifest-sha256',digest,ok=False)
    def test_format_generated_input_is_recorded_without_edits(self):
        p=self.dir/'generator.rs'; p.write_text('let source = format!(r#"'+SOURCE+'"#);\n')
        fragments=self.dir/'fragments.rs'
        fragments.write_text('let a = format!(r#"String.repeat("a", {count})"#);\nlet b = format!("helper({value}, 2)");\n')
        m=self.inventory()
        self.assertEqual(len(m['inputs']),3)
        fragment_inputs=[u for u in m['inputs'] if u['path'].endswith('fragments.rs')]
        self.assertEqual(len(fragment_inputs),2)
        host=fragments.read_bytes()
        self.assertEqual([host[a:b] for a,b in (u['host_range'] for u in fragment_inputs)],
                         [b'String.repeat("a", {count})',b'helper({value}, 2)'])
        self.assertEqual(m['inputs'][0]['hold'],'generated_or_concatenated_rust')
        self.assertTrue(all('generated_or_concatenated_rust' in r['hold_reasons'] for r in m['candidates']))
        self.assertEqual((self.output/'migration.diff').read_text(),'')

    def test_named_contracts_and_reordered_arguments_need_no_second_migration(self):
        source='''function apply(xs: List[Integer], f: function(value: Integer) -> Integer) -> List[Integer]
 return List.map(f: f, xs: xs)
end function
function main() -> Unit
 bind xs <- apply(f: lambda(value) return Integer.minimum(b: 10, a: value), xs: [1, 2])
end function
'''
        (self.dir/'named.bnt').write_text(source)
        m=self.inventory()
        self.assertTrue(all(u['typed'] for u in m['inputs']),m['inputs'])
        self.assertTrue(any(r['kind']=='component' and r['names']==['value'] for r in m['candidates']))
        self.assertFalse(any(r['edits'] for r in m['candidates']),m['candidates'])
        self.assertEqual((self.output/'migration.diff').read_text(),'')
        self.assertEqual((self.dir/'named.bnt').read_text(),source)

    def test_stdlib_module_identity_and_non_prelude_contracts(self):
        units=[{'path':'crates/benitoite/src/prelude/stdlib/'+name,'source':(ROOT/'crates/benitoite/src/prelude/stdlib'/name).read_text(),'direct':True}
               for name in ['UnsignedInteger64.bnt','Network/Http.bnt']]
        result=subprocess.run([str(HELPER)],input=json.dumps(units),capture_output=True,text=True,check=True)
        unsigned,http=[json.loads(line) for line in result.stdout.splitlines()]
        self.assertTrue(unsigned['typed'],unsigned)
        self.assertTrue(http['typed'],http)
        self.assertEqual(unsigned['calls'],[])
        call=next(c for c in http['calls'] if c['callee']=='clientRequest')
        self.assertEqual(call['contract_sources'][0]['names'],['method','url'])
        for call in http['calls']:
            data=units[1]['source'].encode()
            start,end=call['position']['start'],call['position']['end']
            self.assertTrue(data[start:end].decode().startswith(call['callee']))

    def test_simultaneous_nested_renames_preserve_captured_bindings(self):
        source='''function main() -> Unit
 bind totals <- List.fold([1, 2], Option.Some(0), lambda(acc, item)
  return Option.map(acc, lambda(total) return total + item end lambda)
 end lambda)
end function
'''
        p=self.dir/'nested.bnt'; p.write_text(source)
        m=self.inventory()
        self.assertTrue(all(u['typed'] for u in m['inputs']),m['inputs'])
        components=[r for r in m['candidates'] if r['kind']=='component' and r['edits']]
        self.assertEqual(len(components),2)
        self.assertTrue(all('simultaneous_rename_capture' in r['hold_reasons'] for r in components))
        reviewed,digest=self.approve(m)
        self.run_tool('apply',reviewed,'--manifest-sha256',digest)
        self.assertEqual(p.read_text(),source)

if __name__=='__main__': unittest.main()
