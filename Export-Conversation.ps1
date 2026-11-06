<#
.SYNOPSIS
  Export one iPhone text conversation from a local Windows backup to a printable .txt file.
.EXAMPLE
  .\Export-Conversation.ps1 -Contact 5558675309
.EXAMPLE
  .\Export-Conversation.ps1 -Contact "Jane Doe" -StartDate 2026-01-01 -EndDate 2026-07-01
#>
param(
    # Name (needs Contacts in the backup), phone number digits, or email.
    [Parameter(Mandatory = $true)] [string]$Contact,
    # Backup folder; defaults to the newest backup in the standard Apple locations.
    [string]$BackupPath,
    [string]$OutDir,
    # YYYY-MM-DD. StartDate is inclusive, EndDate exclusive.
    [string]$StartDate,
    [string]$EndDate
)
$ErrorActionPreference = 'Stop'
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot ('export-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }

$Version = '4.3.0'
$Sha256 = '31E482940E4D97B650773B7553E81B2B0F80504C10D8C02E1ADC59F6423680CB'
$Exe = Join-Path $PSScriptRoot "imessage-exporter-$Version.exe"

if (-not (Test-Path $Exe)) {
    $url = "https://github.com/ReagentX/imessage-exporter/releases/download/$Version/imessage-exporter-x86_64-pc-windows-gnu.exe"
    Write-Host "Downloading imessage-exporter $Version ..."
    Invoke-WebRequest -Uri $url -OutFile "$Exe.part" -UseBasicParsing
    if ((Get-FileHash "$Exe.part" -Algorithm SHA256).Hash -ne $Sha256) {
        Remove-Item "$Exe.part"
        throw "Checksum mismatch on downloaded imessage-exporter; refusing to run it."
    }
    Move-Item "$Exe.part" $Exe
}

if (-not $BackupPath) {
    $roots = @(
        (Join-Path $env:USERPROFILE 'Apple\MobileSync\Backup'),       # Apple Devices app / Store iTunes
        (Join-Path $env:APPDATA 'Apple Computer\MobileSync\Backup')   # iTunes from apple.com
    )
    $BackupPath = Get-ChildItem -Path $roots -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'Manifest.plist') } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $BackupPath) {
        throw "No iPhone backup found in:`n  $($roots -join "`n  ")`nBack up the iPhone first (see README), or pass -BackupPath."
    }
}
Write-Host "Using backup: $BackupPath"

$exArgs = @('-f', 'txt', '-a', 'iOS', '-p', $BackupPath, '-o', $OutDir, '-t', $Contact)
if ($StartDate) { $exArgs += @('-s', $StartDate) }
if ($EndDate) { $exArgs += @('-e', $EndDate) }

# Encrypted backups: the exporter prompts for the password itself.
& $Exe @exArgs
if ($LASTEXITCODE -ne 0) { throw "imessage-exporter failed (exit code $LASTEXITCODE)." }

Write-Host "`nExported conversation file(s):"
Get-ChildItem $OutDir -Filter *.txt | ForEach-Object { Write-Host "  $($_.FullName)" }
