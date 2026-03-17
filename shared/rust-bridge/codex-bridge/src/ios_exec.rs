use std::collections::HashMap;
use std::ffi::CString;
use std::ffi::c_char;
use std::ffi::c_int;
use std::ffi::c_void;
use std::path::Path;

// Defined in Sources/CodexIOS/Bridge/IosSystemBridge.m,
// linked at Xcode build time.
unsafe extern "C" {
    fn codex_ios_system_init();
    fn codex_ios_system_run(
        cmd: *const c_char,
        cwd: *const c_char,
        output: *mut *mut c_char,
        output_len: *mut usize,
    ) -> c_int;
    fn free(ptr: *mut c_void);
}

pub fn init() {
    unsafe { codex_ios_system_init() };
}

fn shell_quote(s: &str) -> String {
    if s.contains(' ') || s.contains('\'') || s.contains('"') || s.contains('\\') {
        format!("'{}'", s.replace('\'', "'\\''"))
    } else {
        s.to_string()
    }
}

pub fn run_command(
    argv: &[String],
    cwd: &Path,
    _env: &HashMap<String, String>,
) -> (i32, Vec<u8>) {
    // Intercept apply_patch: run in-process instead of through ios_system
    // since ios_system can't execute the app binary with special flags.
    if argv.iter().any(|a| a == codex_apply_patch::CODEX_CORE_APPLY_PATCH_ARG1) {
        let patch_arg = argv.iter()
            .skip_while(|a| *a != codex_apply_patch::CODEX_CORE_APPLY_PATCH_ARG1)
            .nth(1);
        if let Some(patch) = patch_arg {
            eprintln!("[ios-exec] apply_patch in-process (cwd={})", cwd.display());
            // apply_patch uses current directory, so chdir first
            let old_cwd = std::env::current_dir().ok();
            let _ = std::env::set_current_dir(cwd);
            let mut stdout_buf = Vec::new();
            let mut stderr_buf = Vec::new();
            let code = match codex_apply_patch::apply_patch(patch, &mut stdout_buf, &mut stderr_buf) {
                Ok(()) => 0,
                Err(e) => {
                    eprintln!("[ios-exec] apply_patch error: {e}");
                    if stderr_buf.is_empty() {
                        stderr_buf = format!("{e}\n").into_bytes();
                    }
                    1
                }
            };
            if let Some(old) = old_cwd {
                let _ = std::env::set_current_dir(old);
            }
            let mut output = stdout_buf;
            output.extend_from_slice(&stderr_buf);
            eprintln!("[ios-exec] apply_patch exit={code} output_len={}", output.len());
            return (code, output);
        }
    }

    let quoted_args: Vec<String> = argv.iter().map(|arg| shell_quote(arg)).collect();
    let cmd = quoted_args.join(" ");
    eprintln!("[ios-exec] run: {cmd} (cwd={})", cwd.display());
    let Ok(cmd_cstr) = CString::new(cmd.clone()) else {
        eprintln!("[ios-exec] invalid command string");
        return (-1, b"invalid command string\n".to_vec());
    };
    let Ok(cwd_cstr) = CString::new(cwd.to_string_lossy().as_ref()) else {
        eprintln!("[ios-exec] invalid cwd string");
        return (-1, b"invalid cwd string\n".to_vec());
    };

    let mut output_ptr: *mut c_char = std::ptr::null_mut();
    let mut output_len: usize = 0;

    let code = unsafe {
        codex_ios_system_run(
            cmd_cstr.as_ptr(),
            cwd_cstr.as_ptr(),
            &mut output_ptr,
            &mut output_len,
        )
    };

    let output = if !output_ptr.is_null() && output_len > 0 {
        let slice = unsafe { std::slice::from_raw_parts(output_ptr as *const u8, output_len) };
        let v = slice.to_vec();
        unsafe { free(output_ptr as *mut c_void) };
        v
    } else {
        Vec::new()
    };

    let preview = String::from_utf8_lossy(&output);
    let preview = if preview.len() > 200 { &preview[..200] } else { &preview };
    eprintln!("[ios-exec] exit={code} output_len={output_len} preview={preview}");

    (code as i32, output)
}
