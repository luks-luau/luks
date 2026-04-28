use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(
    name = "luks",
    about = "Luks Luau CLI",
    disable_version_flag = true,
    disable_help_flag = true,
    allow_hyphen_values = true
)]
pub struct Cli {
    /// Shows CLI, Runtime, and VM versions.
    #[arg(short = 'v', long = "version", global = true, action = clap::ArgAction::SetTrue)]
    pub show_version: bool,

    /// Shows help output.
    #[arg(short = 'h', long = "help", global = true, action = clap::ArgAction::SetTrue)]
    pub show_help: bool,

    /// File/code for quick execution (legacy fallback).
    #[arg(trailing_var_arg = true)]
    pub trailing: Vec<String>,

    #[command(subcommand)]
    pub command: Option<Commands>,

    // Global flags (allow-by-default model with deny flags).
    #[arg(long, global = true)]
    pub no_read: bool,
    #[arg(long, global = true)]
    pub no_native: bool,
    #[arg(long, global = true)]
    pub no_import: bool,
    #[arg(long, global = true)]
    pub strict: bool,
}

#[derive(Subcommand, Clone, Debug)]
pub enum Commands {
    /// Runs a Luau script.
    #[command(alias = "r")]
    Run { path: PathBuf },

    /// Evaluates one-shot Luau code.
    Eval {
        #[arg(short, long)]
        code: String,
    },

    /// Shows versions.
    #[command(alias = "v")]
    Version,

    /// Shows help.
    #[command(alias = "h")]
    Help,

    /// Interactive REPL (used internally for fallback mode).
    #[command(hide = true)]
    Repl,
}
