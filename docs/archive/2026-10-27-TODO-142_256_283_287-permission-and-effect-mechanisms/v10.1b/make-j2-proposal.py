"""J2 の提案だけをメモリ上で組み立て、本番には適用しない。"""
import difflib
from pathlib import Path
V=Path(__file__).resolve().parent
ROOT=V.parents[2]
summary='handlers with only an Http.send clause are partial handlers; Http.Connect remains unhandled'
help_text='Http.Connect declares send and sendIn; a handler that handles only Http.send leaves Http.Connect in the effect contract'
changes={}
p='crates/benitoite/src/modules/text.rs'
s=(ROOT/p).read_text();changes[p]=s+'\npub(super) const SCOPED_HTTP_OPERATIONS_CHANGE: &str = "'+summary+'";\npub(super) const SCOPED_HTTP_OPERATIONS_HELP: &str = "'+help_text+'";\n'
p='crates/benitoite/src/modules/package.rs';s=(ROOT/p).read_text()
s=s.replace('    },\n];\n\npub(crate) use', '''    },
    BreakingChange {
        version: Version(0, 0, 13),
        summary: text::SCOPED_HTTP_OPERATIONS_CHANGE,
        help: text::SCOPED_HTTP_OPERATIONS_HELP,
    },
];

pub(crate) use''',1)
s=s.replace('            "0.0.12: each WASM Store limits live component handles to 100,000; excess allocation stops with R0906",','            "0.0.12: each WASM Store limits live component handles to 100,000; excess allocation stops with R0906",\n            "0.0.13: '+summary+'",')
s=s.replace('            "review WASM guests and drop component handles they no longer need, including across stateful calls; review local interval warnings under --deny-warnings, inspection intervalAnalysis fields, and JSON/Property derive targets with file-level uses; update language declarations to the current version and dependency hashes after reviewing the source; see the 0.0.12 section of CHANGELOG.md",','            "review WASM guests and drop component handles they no longer need, including across stateful calls; review local interval warnings under --deny-warnings, inspection intervalAnalysis fields, and JSON/Property derive targets with file-level uses; update language declarations to the current version and dependency hashes after reviewing the source; see the 0.0.12 section of CHANGELOG.md",\n            "'+help_text+'",')
s=s.replace('"0.0.10", "0.0.11", "0.0.12",','"0.0.10", "0.0.11", "0.0.12", "0.0.13",')
s=s.replace('            ("0.0.12", Version(0, 0, 12), 8),','            ("0.0.12", Version(0, 0, 12), 8),\n            ("0.0.13", Version(0, 0, 13), 9),')
s=s.replace('                ("0.0.12", 8),','                ("0.0.12", 8),\n                ("0.0.13", 9),')
changes[p]=s
p='crates/benitoite/src/modules/tests.rs';s=(ROOT/p).read_text()
start=s.index('fn language_versions_check_the_release_boundary_in_each_header_location()')
end=s.index('\n// spec:',start)
f=s[start:end]
f=f.replace('            ("0.0.12", None),\n            ("0.0.13", Some(DiagCode::E0907)),','            ("0.0.12", Some(DiagCode::E0908)),\n            ("0.0.13", None),\n            ("0.0.14", Some(DiagCode::E0907)),')
f=f.replace('                            "0.0.11" => "0.0.12",','                            "0.0.12" => "0.0.13",\n                            "0.0.11" => "0.0.12",')
f=f.replace('                    "0.0.11" => 7,','                    "0.0.12" => 8,\n                    "0.0.11" => 7,')
f=f.replace('                    "0.0.12: each WASM Store limits live component handles to 100,000; excess allocation stops with R0906",','                    "0.0.12: each WASM Store limits live component handles to 100,000; excess allocation stops with R0906",\n                    "0.0.13: '+summary+'",')
f=f.replace('                    "review WASM guests and drop component handles they no longer need, including across stateful calls; review local interval warnings under --deny-warnings, inspection intervalAnalysis fields, and JSON/Property derive targets with file-level uses; update language declarations to the current version and dependency hashes after reviewing the source; see the 0.0.12 section of CHANGELOG.md",','                    "review WASM guests and drop component handles they no longer need, including across stateful calls; review local interval warnings under --deny-warnings, inspection intervalAnalysis fields, and JSON/Property derive targets with file-level uses; update language declarations to the current version and dependency hashes after reviewing the source; see the 0.0.12 section of CHANGELOG.md",\n                    "'+help_text+'",')
f=f.replace('this file needs Benitoite 0.0.13 or later, but this is Benitoite 0.0.12','this file needs Benitoite 0.0.14 or later, but this is Benitoite 0.0.13')
changes[p]=s[:start]+f+s[end:]
patch=''
for p,s in changes.items():
 old=(ROOT/p).read_text()
 assert s!=old
 patch+='diff --git a/'+p+' b/'+p+'\n'+''.join(difflib.unified_diff(old.splitlines(keepends=True),s.splitlines(keepends=True),fromfile='a/'+p,tofile='b/'+p))
(V/'j2-registration-proposal.patch').write_text(patch)
print('提案',len(changes),'ファイル。未適用。版上げと残りのheader更新はV10.3aで同時に行う。')
