use benitoite::pipeline::{self, CheckOptions};
fn main() {
    let mut original_adts = None;
    for name in ["list", "map", "recursive", "function", "phantom"] {
        let path = std::env::args().nth(1).unwrap() + "/" + name + ".bnt";
        let text = std::fs::read(path).unwrap();
        let output = pipeline::check_text("main.bnt", &text, CheckOptions { require_main: false, deny_warnings: false });
        println!("{name}: errors={}", output.error_count());
        if let Some(program) = output.program {
            for (_, adt) in program.types.adts.adts.iter() {
                if ["A", "B", "FunctionField", "Phantom"].contains(&adt.name.as_str()) {
                    println!("  {} eq={:?} key={:?}", adt.name, adt.eq_summary, adt.key_summary);
                }
            }
            original_adts = Some(program.types.adts.clone());
            let core = pipeline::desugar_checked(&program).unwrap();
            let errors = benitoite::ir::check::check_program(&core);
            println!("  ir_errors={}", errors.len());
            assert!(errors.is_empty(), "{errors:?}");
            assert_ne!(name, "function");
        } else {
            println!("  diagnostics={:?}", output.diagnostics.iter().map(|d| &d.code).collect::<Vec<_>>());
            assert_eq!(name, "function");
            let repair = String::from_utf8(text.clone()).unwrap().replace("Make(function(x: Unit) -> Unit)", "Make(Unit)");
            let prepared = pipeline::check_text("main.bnt", repair.as_bytes(), CheckOptions { require_main: false, deny_warnings: false }).program.unwrap();
            let mut core = pipeline::desugar_checked(&prepared).unwrap();
            for (id, old) in original_adts.as_ref().unwrap().adts.iter() {
                assert_eq!(core.adts.get(id).unwrap().name, old.name);
            }
            core.adts = original_adts.as_ref().unwrap().clone();
            let errors = benitoite::ir::check::check_program(&core);
            println!("  restored_function_field_ir_errors={errors:?}");
            assert!(!errors.is_empty());
        }
    }
}
