# coding: utf-8
from pathlib import Path
import subprocess
p=Path('crates/benitoite/tests/v1_manifest_refresh.rs')
assert not p.exists()
extra='''
// 一時的なデータの書き出し。既存の公開パイプラインと交換の書き出しを使う。
#[test]
fn export_v1_hash_match() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let checked = pipeline::check_path(&root.join("testdata/packages/hash-match"), CheckOptions { require_main: true, deny_warnings: false }).unwrap();
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let mut export = named::Export::new();
    export.push("golden", "testdata/packages/hash-match", checked.program.as_ref().unwrap(), &exchange::complete_stdlib());
    let out = root.join("../../target/formal-v1/hash-match");
    fs::create_dir_all(&out).unwrap();
    export.write(&out);
}
'''
try:
 p.write_text(Path('crates/benitoite/tests/desugar_export.rs').read_text()+extra)
 result=subprocess.run(['cargo','test','-p','benitoite','--test','v1_manifest_refresh','export_v1_hash_match','--','--exact','--nocapture'])
 result.check_returncode()
finally:p.unlink(missing_ok=True)
