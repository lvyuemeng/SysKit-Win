# specs/developer.ps1 - Developer workstation configuration
# Demonstrates composition by importing default.ps1

@{
    Name = "developer"
    Description = "Developer workstation setup"
    
    # Import base configuration (composition)
    Import = @(
        ".\default.ps1"
    )
    
    # === DECLARATIVE PROVIDERS (Idempotent) ===
    
    # Additional registry settings (merged with base)
    Registry = @{
        # Desktop settings
        Desktop = @{
            MenuShowDelay = "0"
        }
    }
    
    # Additional packages (merged with base)
    Package = @{
        Installed = @(
            "neovim",
            "nodejs",
            "python",
            "ripgrep",
            "fd",
            "fzf",
            "lazygit",
            "starship"
        )
    }
    
    # Windows Features
    Feature = @{
        "Microsoft-Windows-Subsystem-Linux" = "enabled"
        "VirtualMachinePlatform" = "enabled"
    }
    
    # Windows Services
    Service = @{
        # Disable Windows Update (optional for dev machines)
        wuauserv = @{
            State = "stopped"
            Startup = "disabled"
        }
    }
    
    # === TRIGGERS (Non-Idempotent) ===
    # These are explicitly separated because they are NOT idempotent
    
    Trigger = @{
        # Run Windows/Office activation
        Activation = $true
        
        # Run debloat with silent mode
        Debloat = "silent"
    }
}
