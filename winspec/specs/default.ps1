# specs/default.ps1 - Default WinSpec configuration
# This is the base specification that other specs can import

@{
    Name = "default"
    Description = "Default Windows configuration"
    
    # Registry settings
    Registry = @{
        # Clipboard settings
        Clipboard = @{
            EnableHistory = $true
        }
        
        # File Explorer settings
        Explorer = @{
            ShowHidden = $true
            ShowFileExt = $true
        }
        
        # Theme settings
        Theme = @{
            AppTheme = "dark"
            SystemTheme = "dark"
        }
    }
    
    # Package management
    Package = @{
        Installed = @(
            "git",
            "7zip"
        )
    }
}
