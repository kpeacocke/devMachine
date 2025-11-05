<#
Installs: Sysinternals, mkcert (local TLS), ripgrep/fd/fzf/bat, git-delta,
chezmoi, and optional Kubernetes CLIs; security hygiene tools.
#>
$ErrorActionPreference = 'Stop'

Write-Host "🧰 Dev UX tools"
winget install Microsoft.Sysinternals `
  FiloSottile.mkcert `
  BurntSushi.ripgrep `
  sharkdp.fd `
  junegunn.fzf `
  sharkdp.bat `
  dandavison.delta `
  twpayne.chezmoi `
  --silent --accept-source-agreements --accept-package-agreements

Write-Host "🔐 Trust a local CA for dev TLS (mkcert)"
try { mkcert -install } catch { Write-Warning "mkcert: open an elevated console once and re-run 'mkcert -install' if needed." }

Write-Host "☁️ (Optional) Kubernetes CLI set"
$installK8s = $true
if ($installK8s) {
  winget install Kubernetes.kubectl Helm.Helm derailed.k9s `
    --silent --accept-source-agreements --accept-package-agreements
}

Write-Host "🧪 Security hygiene via pipx/go"
try {
  pipx install pre-commit --force
  pipx install semgrep --force
  pipx install detect-secrets --force
  pipx install bandit --force
} catch {}
if (Get-Command go -ErrorAction SilentlyContinue) {
  go install github.com/gitleaks/gitleaks/v8@latest
  $gobin = "$env:USERPROFILE\go\bin"
  if ($env:PATH -notlike "*$gobin*") { [Environment]::SetEnvironmentVariable('Path', $env:Path + ";$gobin", 'User') }
}

Write-Host "🔒 Additional Security Scanning"
winget install Snyk.Snyk aquasecurity.trivy `
  --silent --accept-source-agreements --accept-package-agreements

Write-Host "🌐 Network monitoring: GlassWire"
try {
  winget install GlassWire.GlassWire --silent --accept-source-agreements --accept-package-agreements
} catch {
  Write-Warning "GlassWire installation via winget failed. Please install manually from https://www.glasswire.com/"
}

Write-Host "🛡️ Malware protection: Malwarebytes"
try {
  winget install Malwarebytes.Malwarebytes --silent --accept-source-agreements --accept-package-agreements
} catch {
  Write-Warning "Malwarebytes installation via winget failed. Please install manually from https://www.malwarebytes.com/"
}

Write-Host "🧪 Testing & CI/CD tools"
winget install nektos.act --silent --accept-source-agreements --accept-package-agreements
try {
  npm install -g newman
  pipx install pytest-cov --force
  pipx install tox --force
} catch { Write-Warning "Some npm/pipx tools failed to install" }

Write-Host "📦 Winget hygiene (export + source refresh)"
$export = Join-Path $env:USERPROFILE "Desktop\winget-installed.json"
winget export -o $export -accept-source-agreements -accept-package-agreements | Out-Null
winget source update | Out-Null
Write-Host "✅ Optional goodies installed. Winget export saved to $export"
