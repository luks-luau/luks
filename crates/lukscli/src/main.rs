mod cli;
mod repl;
mod runtime;

use anyhow::Result;
use clap::{CommandFactory, Parser};
use cli::{Cli, Commands};
use std::path::PathBuf;

fn main() -> Result<()> {
    let cli = Cli::parse();

    // Handle global flags immediately (before command resolution)
    if cli.show_version {
        cmd_version()?;
        return Ok(());
    }
    if cli.show_help {
        Cli::command().print_help()?;
        return Ok(());
    }

    // Apply permissions BEFORE loading the runtime.
    if cli.strict {
        std::env::set_var("LUKS_STRICT", "1");
    }
    if cli.no_read {
        std::env::set_var("LUKS_DENY_READ", "1");
    }
    if cli.no_native {
        std::env::set_var("LUKS_DENY_NATIVE", "1");
    }
    if cli.no_import {
        std::env::set_var("LUKS_DENY_IMPORT", "1");
    }

    // Command resolution (legacy fallback behavior).
    let cmd = match cli.command {
        Some(c) => c,
        None => {
            if cli.trailing.is_empty() {
                Commands::Repl
            } else {
                Commands::Run {
                    path: PathBuf::from(&cli.trailing[0]),
                }
            }
        }
    };

    match cmd {
        Commands::Run { path } => cmd_run(&path)?,
        Commands::Eval { code } => cmd_eval(&code)?,
        Commands::Repl => repl::run_repl()?,
        Commands::Version => cmd_version()?,
        Commands::Help => Cli::command().print_help()?,
    }
    Ok(())
}

fn cmd_run(path: &PathBuf) -> Result<()> {
    let rt = runtime::RuntimeHandle::load()?;
    let absolute_path = std::fs::canonicalize(path)?;
    let source = std::fs::read_to_string(&absolute_path)?;
    let chunk_name = absolute_path.to_string_lossy().to_string();
    rt.execute(&source, &chunk_name)
}

fn cmd_eval(code: &str) -> Result<()> {
    let rt = runtime::RuntimeHandle::load()?;
    rt.execute(code, "<eval>")
}

fn cmd_version() -> Result<()> {
    let cli_ver = env!("CARGO_PKG_VERSION");
    let rt = runtime::RuntimeHandle::load()?;
    let (rt_ver, luau_ver) = rt.get_versions()?;

    println!("╭────────────────────────────────────╮");
    println!("│  Luks CLI    {:<20} │", cli_ver);
    println!("│  Runtime     {:<20} │", rt_ver);
    println!("│  Luau VM     {:<20} │", luau_ver);
    println!("╰────────────────────────────────────╯");
    Ok(())
}
