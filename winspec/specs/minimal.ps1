# specs/minimal.ps1 - Minimal WinSpec example
# Demonstrates the simplest possible configuration

@{
    Name = "minimal"
    Description = "Minimal configuration example"
    
    # Only registry settings
    Registry = @{
        Explorer = @{
            ShowFileExt = $true
        }
    }
}
