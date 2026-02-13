use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "ark")]
#[command(about = "Ark — version control for large binary files", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Initialize a new Ark workspace
    Init,
    /// Push local changes to the server
    Push,
    /// Sync workspace with the latest server state
    Sync,
    /// Show workspace status
    Status,
    /// Acquire an exclusive lock on a file
    Lock {
        /// Path to the file to lock
        path: String,
    },
    /// Release an exclusive lock on a file
    Unlock {
        /// Path to the file to unlock
        path: String,
    },
    /// Show revision history
    Log,
    /// Check out a specific revision
    Checkout {
        /// Revision identifier
        revision: String,
    },
}

fn main() {
    let cli = Cli::parse();

    match &cli.command {
        Commands::Init => println!("ark init: not implemented yet"),
        Commands::Push => println!("ark push: not implemented yet"),
        Commands::Sync => println!("ark sync: not implemented yet"),
        Commands::Status => println!("ark status: not implemented yet"),
        Commands::Lock { path } => println!("ark lock {path}: not implemented yet"),
        Commands::Unlock { path } => println!("ark unlock {path}: not implemented yet"),
        Commands::Log => println!("ark log: not implemented yet"),
        Commands::Checkout { revision } => {
            println!("ark checkout {revision}: not implemented yet")
        }
    }
}
