# Surface Pro (ARM64) Dev Bootstrap — **Latest Everything**

This repo contains a clean set of scripts to build, harden, and maintain your **Windows on ARM (Snapdragon)** dev machine and WSL.

## Order of operations (Windows)

1. **PowerShell first** – make PowerShell 7 default  
   ```
   scripts/windows/00-pwsh-first.ps1
   ```
2. **Windows tooling** (VS Code, Docker, runtimes, CLIs, apps)  
   ```
   scripts/windows/10-windows-bootstrap.ps1
   ```
3. **Optimize + Harden** (safe defaults)  
   ```
   scripts/windows/30-optimize-and-harden.ps1
   ```
4. **Performance tuning** (Ultimate plan, storage sense, indexing)  
   ```
   scripts/windows/31-performance-tuning.ps1 -SetUltimateNow
   ```
5. **Auto power plan toggle** (AC→Ultimate, Battery→Balanced)  
   ```
   scripts/windows/32-powerplan-auto-toggle.ps1
   ```
6. **(Optional) Move caches to Dev Drive**  
   ```
   scripts/windows/40-devdrive-caches.ps1
   ```
7. **Doctor check**  
   ```
   scripts/windows/50-doctor.ps1 -VerboseOut
   ```
8. **.NET maintainer** (one-off or weekly)  
   ```
   scripts/windows/60-dotnet-maintain.ps1 -ScheduleWeekly
   ```

## Insider channels

- Opt-in to **Windows Canary/Dev**, **Office BetaChannel**, **VS Code Insiders**  
  ```
  scripts/windows/70-insiders-optin.ps1
  scripts/windows/72-vscode-insiders-setup.ps1
  ```
- Revert to stable  
  ```
  scripts/windows/71-insiders-revert.ps1
  ```

## Optional dev goodies
```
scripts/windows/33-optional-dev-goodies.ps1
```

## WSL (Ubuntu) setup

1. Bootstrap languages & tools (Temurin latest, Node current, mise for Kotlin/Gradle, R/PHP/Ruby, linters):
   ```
   scripts/wsl/20-ubuntu-bootstrap.sh
   ```
2. Tune WSL (wsl.conf, mkcert trust, QoL):
   ```
   scripts/wsl/21-wsl-tune.sh
   ```
3. Health check:
   ```
   scripts/wsl/doctor-ubuntu.sh
   ```

## Tests

- Windows Pester tests:
  ```
  pwsh -NoProfile -File .\tests\pester.Windows.Tests.ps1
  ```
- WSL smoke test:
  ```
  bash ./tests/ubuntu-smoke-test.sh
  ```

---

### Notes

- Java uses **Eclipse Temurin (rolling GA)** so it always pulls the latest major (e.g., 25 → 26 automatically when GA).
- Node uses **Current** (not LTS).
- Python uses the **3.13** stream (latest stable at time of writing).
- Kotlin/Gradle stay latest via **mise**.
- .NET maintainer keeps **latest SDK** installed, prunes extras, updates workloads, and can **self-schedule weekly**.

Happy building!
