use rustyline::DefaultEditor;
use crate::runtime::RuntimeHandle;
use anyhow::Result;

pub fn run_repl() -> Result<()> {
    let rt = RuntimeHandle::load()?;
    let mut rl = DefaultEditor::new()?;

    println!("Luks REPL | :q ou Ctrl+D para sair");
    loop {
        match rl.readline("luau> ") {
            Ok(line) if line.trim().is_empty() => continue,
            Ok(line) if line.trim() == ":q" || line.trim() == "exit" => {
                println!("Bye.");
                break;
            }
            Ok(line) => {
                rl.add_history_entry(&line)?;
                if let Err(e) = rt.execute(&line, "<repl>") {
                    eprintln!("[ERR] {}", e);
                }
            }
            Err(rustyline::error::ReadlineError::Interrupted | rustyline::error::ReadlineError::Eof) => {
                println!("\nBye.");
                break;
            }
            Err(e) => {
                eprintln!("[IO] {}", e);
                break;
            }
        }
    }
    Ok(())
}
