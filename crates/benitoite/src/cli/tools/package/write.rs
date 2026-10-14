//! 設定ファイルの新規作成は、並行して作られたファイルを上書きしない（設計書 06-09「`benitoite package`」）。

use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use std::io::Write;
use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};
use std::path::Path;

pub(super) fn create(
    path: &Path,
    permissions_from: &Path,
    bytes: &[u8],
) -> Result<(), Box<Diagnostic>> {
    let temp = path.with_file_name(format!(
        ".{}.package-{}",
        crate::modules::package::CONFIG_NAME,
        std::process::id()
    ));
    let builder = |error: &std::io::Error| {
        DiagBuilder::new(DiagCode::E0126)
            .arg("path", path.display().to_string())
            .arg("reason", error.to_string())
            .note("reason")
    };
    let mut file = std::fs::OpenOptions::new()
        .create_new(true)
        .write(true)
        .mode(0o600)
        .open(&temp)
        .map_err(|e| Box::new(builder(&e).build()))?;
    let result = (|| {
        file.write_all(bytes)?;
        file.sync_all()?;
        file.set_permissions(std::fs::Permissions::from_mode(
            std::fs::metadata(permissions_from)?.permissions().mode() & !0o111,
        ))?;
        std::fs::hard_link(&temp, path)
    })();
    drop(file);
    let cleanup = std::fs::remove_file(&temp);
    match result {
        Ok(()) => {
            if let Err(error) = cleanup {
                let mut diagnostic = builder(&error)
                    .arg("temp", temp.display().to_string())
                    .note("temp_left");
                if let Err(rollback) = std::fs::remove_file(path) {
                    diagnostic = diagnostic
                        .arg("config", path.display().to_string())
                        .arg("rollback_reason", rollback.to_string())
                        .note("create_rollback");
                }
                return Err(Box::new(diagnostic.build()));
            }
            Ok(())
        }
        Err(error) => {
            let mut diagnostic = builder(&error);
            if cleanup.is_err() {
                diagnostic = diagnostic
                    .arg("temp", temp.display().to_string())
                    .note("temp_left");
            }
            Err(Box::new(diagnostic.build()))
        }
    }
}
