<#
Installs: Sysinternals Suite, mkcert (local TLS), ripgrep/fd/fzf/bat, git-delta,
chezmoi, and optional Kubernetes CLIs; security hygiene tools.
#>
$ErrorActionPreference = 'Stop'

Write-Host "[DEV UX] Installing developer experience tools..."
winget install Microsoft.Sysinternals.Suite `
  FiloSottile.mkcert `
  sharkdp.fd `
  junegunn.fzf `
  sharkdp.bat `
  dandavison.delta `
  twpayne.chezmoi `
  --source winget --silent --accept-source-agreements --accept-package-agreements

Write-Host "[MISE] Installing ripgrep via mise for better version management..."
if (Get-Command mise -ErrorAction SilentlyContinue) {
  mise use -g ripgrep@latest
} else {
  Write-Warning "mise not found, skipping ripgrep installation"
}

Write-Host "[MKCERT] Trusting local CA for dev TLS..."
try { mkcert -install } catch { Write-Warning "mkcert: open an elevated console once and re-run 'mkcert -install' if needed." }

Write-Host "[K8S] Installing Kubernetes CLI tools (optional)..."
$installK8s = $true
if ($installK8s) {
  winget install Kubernetes.kubectl Helm.Helm derailed.k9s `
    --source winget --silent --accept-source-agreements --accept-package-agreements
}

Write-Host "[SECURITY] Installing security hygiene tools..."
Write-Host "  Note: pre-commit, semgrep, detect-secrets, bandit moved to 13-linters-formatters.ps1" -ForegroundColor Yellow
if (Get-Command go -ErrorAction SilentlyContinue) {
  Write-Host "  Installing gitleaks..."
  go install github.com/zricethezav/gitleaks/v8@latest
  $gobin = "$env:USERPROFILE\go\bin"
  if ($env:PATH -notlike "*$gobin*") { [Environment]::SetEnvironmentVariable('Path', $env:Path + ";$gobin", 'User') }
}

Write-Host "[SECURITY] Installing additional security scanning tools..."
winget install Snyk.Snyk aquasecurity.trivy `
  --source winget --silent --accept-source-agreements --accept-package-agreements

Write-Host "[NOTE] GlassWire and Malwarebytes moved to 11-licensed-apps.ps1" -ForegroundColor Yellow

Write-Host "[CI/CD] Installing testing and CI/CD tools..."
winget install nektos.act --source winget --silent --accept-source-agreements --accept-package-agreements
try {
  npm install -g newman
  Write-Host "  Note: pytest, pytest-cov, tox moved to 13-linters-formatters.ps1" -ForegroundColor Yellow
} catch { Write-Warning "newman installation failed" }

Write-Host "[WINGET] Exporting installed packages and refreshing sources..."
$export = Join-Path $env:USERPROFILE "Desktop\winget-installed.json"
winget export -o $export --accept-source-agreements --accept-package-agreements | Out-Null
winget source update | Out-Null
Write-Host "[OK] Optional goodies installed. Winget export saved to $export"
