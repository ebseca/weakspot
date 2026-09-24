# Creates the Play upload signing key for Weakspot.
#
# The password is generated here, written straight to key.properties, and never
# printed. Nothing sensitive is echoed to the console, so it does not end up in
# shell history, terminal scrollback, or an agent transcript.
#
# Run once. Losing the resulting keystore means losing the ability to ship
# updates to the app, so back up the vault directory somewhere private.
#
# Usage:
#   powershell -File tool\create_upload_key.ps1 -VaultDir C:\bigideas\vault\flashcards

param(
    [string]$VaultDir = "C:\bigideas\vault\flashcards",
    [string]$Alias = "upload",
    [string]$Dname = "CN=Weakspot, O=bigideas, C=GB"
)

$ErrorActionPreference = 'Stop'

$keytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
if (-not (Test-Path $keytool)) {
    try { $keytool = (Get-Command keytool -ErrorAction Stop).Source }
    catch { throw "keytool not found. Install a JDK or Android Studio." }
}

if (-not (Test-Path $VaultDir)) {
    New-Item -ItemType Directory -Force -Path $VaultDir | Out-Null
    Write-Host "created $VaultDir"
}

$storePath = Join-Path $VaultDir 'weakspot-upload.p12'
$propsPath = Join-Path $VaultDir 'key.properties'

if (Test-Path $storePath) {
    Write-Host "REFUSING: a keystore already exists at $storePath"
    Write-Host "Overwriting it would permanently break your ability to update the app."
    Write-Host "Delete it deliberately if you really mean to start over."
    exit 1
}

# Cryptographically random, alphanumeric so it cannot upset either the
# properties parser or keytool's argument handling.
$alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
$bytes = New-Object byte[] 40
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$sb = New-Object System.Text.StringBuilder
foreach ($b in $bytes) { [void]$sb.Append($alphabet[$b % $alphabet.Length]) }
$password = $sb.ToString()

# PKCS12 rather than the legacy JKS format. keytool writes its banner to stderr
# even on success; redirecting it would make PowerShell abort, so success is
# judged on the exit code and the file instead.
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $keytool -genkeypair `
    -keystore $storePath `
    -storetype PKCS12 `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias $Alias `
    -dname $Dname `
    -storepass $password `
    -keypass $password
$keytoolExit = $LASTEXITCODE
$ErrorActionPreference = $previousPreference

if ($keytoolExit -ne 0) { throw "keytool failed with exit code $keytoolExit" }
if (-not (Test-Path $storePath)) { throw "keytool did not produce a keystore" }

# Forward slashes: Gradle treats backslashes as escapes in properties files.
$storeForGradle = $storePath -replace '\\', '/'
$contents = @"
# Play upload signing key for Weakspot.
# SECRET. Never commit this file or the keystore it points at.
storePassword=$password
keyPassword=$password
keyAlias=$Alias
storeFile=$storeForGradle
"@
[System.IO.File]::WriteAllText($propsPath, $contents)

Write-Host "keystore  : $storePath"
Write-Host "properties: $propsPath"
Write-Host "alias     : $Alias"
Write-Host "password  : generated, $($password.Length) chars, written to key.properties only"
Write-Host ""
Write-Host "BACK UP THE VAULT DIRECTORY. Losing it means you can never update this app."
