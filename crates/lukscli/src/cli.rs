use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(
    name = "luks",
    about = "Luks Luau CLI",
    disable_version_flag = true,
    disable_help_flag = true,
    allow_hyphen_values = true,
)]
pub struct Cli {
    /// Mostra a versão do CLI, Runtime e VM
    #[arg(short = 'v', long = "version", global = true, action = clap::ArgAction::SetTrue)]
    pub show_version: bool,

    /// Mostra a ajuda
    #[arg(short = 'h', long = "help", global = true, action = clap::ArgAction::SetTrue)]
    pub show_help: bool,

    /// Arquivo/código para execução rápida (fallback legacy)
    #[arg(trailing_var_arg = true)]
    pub trailing: Vec<String>,

    #[command(subcommand)]
    pub command: Option<Commands>,

    // Flags Globais (Allow-by-Default -> Deny Flags)
    #[arg(long, global = true)] pub no_read: bool,
    #[arg(long, global = true)] pub no_native: bool,
    #[arg(long, global = true)] pub strict: bool,
}

#[derive(Subcommand, Clone, Debug)]
pub enum Commands {
    /// Executa um script Luau
    #[command(alias = "r")]
    Run { path: PathBuf },

    /// Avalia uma expressão Luau (one-shot)
    Eval { #[arg(short, long)] code: String },

    /// Mostra versões
    #[command(alias = "v")]
    Version,

    /// Mostra ajuda
    #[command(alias = "h")]
    Help,

    /// REPL interativo (usado internamente para fallback)
    #[command(hide = true)]
    Repl,
}
