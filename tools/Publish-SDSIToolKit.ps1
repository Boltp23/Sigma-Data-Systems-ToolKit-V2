<#
.SYNOPSIS
    Publishes the Sigma Data Systems INC ToolKit to GitHub automatically.

.DESCRIPTION
    Prepared by Sigma Data Systems Inc. - https://sigmadatainc.com/

    Copies the ToolKit files from C:\powershell into a local clone of your GitHub
    repository, runs safety checks, and commits + pushes ONLY when something changed.

    Safety checks before anything is pushed (any failure = nothing is published):
      - Only whitelisted files are copied (the ToolKit, README, LICENSE, CHANGELOG) -
        the rest of C:\powershell (client scripts, exports, credentials) never goes near the repo.
      - The ToolKit must parse as valid PowerShell.
      - Secret scan: passwords, client secrets, API keys, tokens, private keys,
        connection strings.
      - Optional block-list of client names / domains you never want published.

    Sign-in: uses Git for Windows + Git Credential Manager. The FIRST push opens a
    GitHub sign-in in your browser; after that the credential is stored in Windows
    Credential Manager. No password or token is ever written in this script or its config.

.PARAMETER Setup
    First-time setup: asks for the repository URL, clones it, saves the config.

.PARAMETER InstallSchedule
    Creates a scheduled task that runs this script every 30 minutes (and at logon),
    so every ToolKit update is published automatically.

.PARAMETER RemoveSchedule
    Removes that scheduled task.

.PARAMETER DryRun
    Runs every check and shows what WOULD be committed, without committing or pushing.

.EXAMPLE
    .\Publish-SDSIToolKit.ps1 -Setup            # once
    .\Publish-SDSIToolKit.ps1                   # publish now
    .\Publish-SDSIToolKit.ps1 -InstallSchedule  # publish automatically from now on
#>
[CmdletBinding()]
param(
    [switch]$Setup,
    [switch]$InstallSchedule,
    [switch]$RemoveSchedule,
    [switch]$DryRun,
    [string]$SourceFolder = 'C:\powershell',
    [string]$LogDir = 'C:\temp\ToolKitPublish'
)

$ErrorActionPreference = 'Stop'
$ConfigPath = Join-Path $SourceFolder '.toolkit-publish.json'
$LogFile    = Join-Path $LogDir 'publish.log'
$TaskName   = 'SDSI ToolKit - Publish to GitHub'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

function Log([string]$m, [string]$lvl = 'INFO') {
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $lvl, $m
    Add-Content -Path $LogFile -Value $line
    $c = switch ($lvl) { 'ERROR' { 'Red' } 'WARN' { 'Yellow' } 'OK' { 'Green' } default { 'Gray' } }
    Write-Host $line -ForegroundColor $c
}

# git writes normal progress ("Cloning into...", "To https://...") to STDERR. In Windows PowerShell 5.1,
# with ErrorActionPreference = Stop, any stderr line becomes a terminating NativeCommandError. So git is
# always run with ErrorActionPreference = Continue and judged ONLY by its exit code.
function Invoke-GitRaw {
    param([string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $out = @(& git @GitArgs 2>&1 | ForEach-Object { "$_" }) }
    finally { $ErrorActionPreference = $prev }
    $script:GitExit = $LASTEXITCODE
    return $out
}
function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments)][string[]]$GitArgs)
    $out = Invoke-GitRaw (@('-C', $script:Repo) + $GitArgs)
    if ($script:GitExit -ne 0) { throw "git $($GitArgs -join ' ') failed: $($out -join ' ')" }
    return $out
}

# ------------------------------------------------------------------ schedule management
if ($RemoveSchedule) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed scheduled task '$TaskName'." -ForegroundColor Green
    return
}
if ($InstallSchedule) {
    if (-not (Test-Path $ConfigPath)) { throw 'Run with -Setup first.' }
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $action  = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -SourceFolder `"$SourceFolder`""
    $trigger1 = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 3650)
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew
    # Runs as YOU (interactive token) so Git Credential Manager can use your stored GitHub sign-in. No password stored.
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger1, $trigger2 -Settings $settings -Principal $principal -Description 'Publishes C:\powershell\SigmaDataSystems-ToolKit to GitHub when it changes (Publish-SDSIToolKit.ps1).' -Force | Out-Null
    Write-Host "Scheduled task '$TaskName' created: every 30 minutes + at logon, as $env:USERNAME." -ForegroundColor Green
    Write-Host "Log: $LogFile"
    return
}

# ------------------------------------------------------------------ git present?
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $gitDefault = Join-Path $env:ProgramFiles 'Git\cmd'
    if (Test-Path (Join-Path $gitDefault 'git.exe')) { $env:Path += ";$gitDefault" }
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Log 'Git for Windows is not installed.' 'ERROR'
    if ($Setup) {
        $ans = Read-Host 'Download and install Git for Windows (official GitHub release, includes Git Credential Manager) now? Y/N'
        if ($ans -match '^[Yy]') {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            $rel = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/git-for-windows/git/releases/latest'
            $asset = $rel.assets | Where-Object { $_.name -match '^Git-[\d\.]+-64-bit\.exe$' } | Select-Object -First 1
            $exe = Join-Path 'C:\temp\Tools' $asset.name
            New-Item -ItemType Directory -Path 'C:\temp\Tools' -Force | Out-Null
            Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $exe
            $sig = Get-AuthenticodeSignature $exe
            if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Johannes Schindelin|Git') { Remove-Item $exe -Force; throw "Git installer signature check failed ($($sig.Status))." }
            Start-Process $exe -ArgumentList '/VERYSILENT /NORESTART /NOCANCEL /SP- /COMPONENTS="icons,ext\reg\shellhere,assoc,assoc_sh,gitlfs"' -Wait
            $env:Path += ";$(Join-Path $env:ProgramFiles 'Git\cmd')"
            Log "Installed $($asset.name)" 'OK'
        } else { return }
    } else { exit 1 }
}

# ------------------------------------------------------------------ config / setup
if ($Setup -or -not (Test-Path $ConfigPath)) {
    if (-not $Setup) { Log "No config at $ConfigPath - run with -Setup first." 'ERROR'; exit 1 }
    Write-Host "`n=== Sigma Data Systems INC ToolKit - GitHub publishing setup ===" -ForegroundColor Cyan
    $url = Read-Host 'GitHub repository URL (e.g. https://github.com/YourOrg/SDSI-ToolKit.git)'
    if ($url -notmatch '^https://github\.com/[^/]+/[^/]+?(\.git)?/?$') { throw 'Enter the HTTPS URL of the repository.' }
    if ($url -notmatch '\.git$') { $url = $url.TrimEnd('/') + '.git' }
    $branch = Read-Host 'Branch [main]'; if (-not $branch) { $branch = 'main' }
    $name  = Read-Host "Commit author name [$env:USERNAME]"; if (-not $name) { $name = $env:USERNAME }
    $email = Read-Host 'Commit author email (your GitHub email or the noreply address)'
    $block = Read-Host 'Words that must NEVER be published, comma separated (client names / domains; blank = none)'
    $repoDir = Join-Path $SourceFolder ('_github\' + (($url -split '/')[-1] -replace '\.git$', ''))
    $cfg = [ordered]@{
        RepoUrl    = $url
        Branch     = $branch
        RepoDir    = $repoDir
        AuthorName = $name
        AuthorEmail= $email
        Files      = @(
            @{ Source = 'SigmaDataSystems-ToolKit-v2.ps1'; Target = 'SigmaDataSystems-ToolKit.ps1' }
            @{ Source = 'README.md';                        Target = 'README.md' }
            @{ Source = 'LICENSE';                          Target = 'LICENSE' }
            @{ Source = 'CHANGELOG.md';                     Target = 'CHANGELOG.md' }
            @{ Source = 'Publish-SDSIToolKit.ps1';          Target = 'tools/Publish-SDSIToolKit.ps1' }
        )
        BlockWords = @($block -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
    $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigPath -Encoding UTF8
    Log "Config saved to $ConfigPath" 'OK'
    # A previous interrupted clone can leave a half-made folder - check it and start clean if it's broken
    if (Test-Path $repoDir) {
        $null = Invoke-GitRaw @('-C', $repoDir, 'rev-parse', '--git-dir')
        if ($script:GitExit -ne 0) { Log "Removing incomplete clone at $repoDir" 'WARN'; Remove-Item -LiteralPath $repoDir -Recurse -Force }
    }
    if (-not (Test-Path (Join-Path $repoDir '.git'))) {
        New-Item -ItemType Directory -Path (Split-Path $repoDir) -Force | Out-Null
        Log "Cloning $url (a GitHub sign-in window may open the first time)..."
        Invoke-GitRaw @('clone', $url, $repoDir) | ForEach-Object { Log $_ }
        if ($script:GitExit -ne 0) { throw 'Clone failed - check the URL and that your GitHub account can access the repo.' }
        Log 'Clone OK.' 'OK'
    }
}

$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$script:Repo = $cfg.RepoDir
if (-not (Test-Path (Join-Path $Repo '.git'))) { Log "Local clone missing at $Repo - run -Setup again." 'ERROR'; exit 1 }

try {
    Invoke-Git config user.name  $cfg.AuthorName | Out-Null
    $email = $cfg.AuthorEmail
    if (-not $email) { $owner = ($cfg.RepoUrl -split '/')[-2]; $email = "$owner@users.noreply.github.com" }
    Invoke-Git config user.email $email | Out-Null

    # ------------------------------------------------------------------ sync with GitHub first
    $hasRemoteBranch = @(Invoke-GitRaw @('-C', $Repo, 'ls-remote', '--heads', 'origin', $cfg.Branch) | Where-Object { $_ -match 'refs/heads/' })
    if ($hasRemoteBranch) {
        Invoke-Git fetch origin $cfg.Branch | Out-Null
        Invoke-Git checkout -B $cfg.Branch "origin/$($cfg.Branch)" | Out-Null
    } else {
        Invoke-Git checkout -B $cfg.Branch | Out-Null   # brand-new empty repo
    }

    # ------------------------------------------------------------------ copy whitelisted files
    $oldToolkit = Join-Path $Repo (($cfg.Files | Where-Object { $_.Source -like 'SigmaDataSystems-ToolKit*' } | Select-Object -First 1).Target)
    $oldMenu = @()
    if (Test-Path $oldToolkit) { $oldMenu = @(Select-String -Path $oldToolkit -Pattern "Text = '((?:[^']|'')+)'" -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }) }

    foreach ($f in $cfg.Files) {
        $src = Join-Path $SourceFolder $f.Source
        if (-not (Test-Path $src)) { continue }
        $dst = Join-Path $Repo $f.Target
        New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }

    # ------------------------------------------------------------------ auto-update the README
    # Rebuilds the option count and the quick option index from the ToolKit's own menu, so the
    # README on GitHub always matches the script - even when only the script changed.
    $readme = Join-Path $Repo 'README.md'
    $tkFile = Join-Path $Repo (($cfg.Files | Where-Object { $_.Source -like 'SigmaDataSystems-ToolKit*' } | Select-Object -First 1).Target)
    if ((Test-Path $readme) -and (Test-Path $tkFile)) {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($tkFile, [ref]$null, [ref]$null)
        $menuAst = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$Script:Menu' }, $true) | Select-Object -First 1
        # Dates come from the ToolKit file itself (not "today"), so an unchanged ToolKit never causes a README-only commit
        $tkDate = (Get-Item $tkFile).LastWriteTime.ToString('yyyy-MM-dd')
        if ($menuAst) {
            $letters = 'ACDEFGHIJKLMNPSUVWYZ'; $si = -1; $num = 0
            $lines = New-Object System.Collections.Generic.List[string]
            foreach ($h in $menuAst.Right.FindAll({ param($n) $n -is [System.Management.Automation.Language.HashtableAst] }, $true)) {
                $kv = @{}
                foreach ($pair in $h.KeyValuePairs) {
                    $k = $pair.Item1.Extent.Text.Trim("'", '"')
                    $v = $pair.Item2.Extent.Text
                    if ($v -match "^'(.*)'$") { $v = $Matches[1] -replace "''", "'" }
                    $kv[$k] = $v
                }
                if ($kv.Section) { $si++; $lines.Add(''); $lines.Add("**$($letters[$si]). $($kv.Section)**"); $lines.Add(''); continue }
                if ($kv.Text) { $num++; $lines.Add(("{0}. {1}" -f $num, ($kv.Text -replace '\|', '\|'))) }
            }
            $index = "<!-- AUTO-OPTIONS:START -->`r`n<details><summary><b>Quick index of all $num options</b> (auto-generated from the script, $tkDate)</summary>`r`n" + ($lines -join "`r`n") + "`r`n`r`n</details>`r`n<!-- AUTO-OPTIONS:END -->"
            $rm = Get-Content $readme -Raw
            if ($rm -match '(?s)<!-- AUTO-OPTIONS:START -->.*?<!-- AUTO-OPTIONS:END -->') {
                $rm = [regex]::Replace($rm, '(?s)<!-- AUTO-OPTIONS:START -->.*?<!-- AUTO-OPTIONS:END -->', { param($m) $index })
            } else {
                $rm = $rm -replace '(## All options\s*\r?\n)', "`$1`r`n$index`r`n"
            }
            $rm = [regex]::Replace($rm, '\*\*\d+ diagnostics', "**$num diagnostics")
            $dash = [string][char]0x2013   # en dash - kept out of the source so the file stays pure ASCII
            $rm = [regex]::Replace($rm, ('`1`' + $dash + '`\d+`'), ('`1`' + $dash + '`' + $num + '`'))
            $ver = (Select-String -Path $tkFile -Pattern "ToolkitVersion\s*=\s*'([^']+)'" | Select-Object -First 1).Matches.Groups[1].Value
            $dot = [string][char]0x00B7
            $stamp = "<!-- AUTO-VERSION -->**Current version: v$ver** $dot $num options $dot updated $tkDate<!-- /AUTO-VERSION -->"
            if ($rm -match '<!-- AUTO-VERSION -->.*?<!-- /AUTO-VERSION -->') { $rm = [regex]::Replace($rm, '<!-- AUTO-VERSION -->.*?<!-- /AUTO-VERSION -->', { param($m) $stamp }) }
            [System.IO.File]::WriteAllText($readme, $rm, (New-Object System.Text.UTF8Encoding($false)))
            Log "README refreshed: $num options, v$ver"
        }
    }

    # ------------------------------------------------------------------ safety checks
    $problems = @()
    $tk = Join-Path $Repo (($cfg.Files | Where-Object { $_.Source -like 'SigmaDataSystems-ToolKit*' } | Select-Object -First 1).Target)
    if (Test-Path $tk) {
        $tok = $null; $err = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($tk, [ref]$tok, [ref]$err)
        if ($err) { $problems += "ToolKit does not parse: line $($err[0].Extent.StartLineNumber): $($err[0].Message)" }
    }
    $secretPatterns = @(
        @{ N = 'Hardcoded password';    P = '(?i)\b(password|passwd|pwd)\s*=\s*["''][^"''$\s][^"'']{5,}["'']' }
        @{ N = 'NetworkCredential with literal password'; P = '(?i)NetworkCredential\([^)]*,\s*["''][^"'']{4,}["'']\)' }
        @{ N = 'Client secret';         P = '(?i)client_?secret\s*[=:]\s*["''][A-Za-z0-9_\-\.~]{20,}["'']' }
        @{ N = 'GitHub token';          P = '\b(ghp|gho|ghu|ghs|github_pat)_[A-Za-z0-9_]{20,}' }
        @{ N = 'AWS access key';        P = '\bAKIA[0-9A-Z]{16}\b' }
        @{ N = 'Slack token';           P = '\bxox[baprs]-[A-Za-z0-9-]{10,}' }
        @{ N = 'Private key';           P = '-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----' }
        @{ N = 'Connection string';     P = '(?i)(Password|Pwd)=[^;''"\s]{4,};' }
        @{ N = 'Azure storage key';     P = '(?i)AccountKey=[A-Za-z0-9+/=]{40,}' }
    )
    foreach ($f in $cfg.Files) {
        $dst = Join-Path $Repo $f.Target
        if (-not (Test-Path $dst)) { continue }
        foreach ($sp in $secretPatterns) {
            $hit = Select-String -Path $dst -Pattern $sp.P | Select-Object -First 1
            if ($hit) { $problems += "$($sp.N) in $($f.Target) line $($hit.LineNumber)" }
        }
        foreach ($w in @($cfg.BlockWords)) {
            if (-not $w) { continue }
            $hit = Select-String -Path $dst -Pattern ([regex]::Escape($w)) | Select-Object -First 1
            if ($hit) { $problems += "Blocked word '$w' in $($f.Target) line $($hit.LineNumber)" }
        }
    }
    if ($problems) {
        Log 'NOT PUBLISHED - safety check failed:' 'ERROR'
        $problems | ForEach-Object { Log "  $_" 'ERROR' }
        $null = Invoke-GitRaw @('-C', $Repo, 'checkout', '--', '.')
        $null = Invoke-GitRaw @('-C', $Repo, 'clean', '-fd')
        exit 2
    }

    # ------------------------------------------------------------------ anything changed?
    Invoke-Git add -A | Out-Null
    $changed = @(Invoke-Git diff --cached --name-only | Where-Object { $_ })
    if (-not $changed) { Log 'No changes - nothing to publish.'; exit 0 }

    # Commit message: version + which menu options were added / removed
    $ver = ''
    if (Test-Path $tk) { $m = Select-String -Path $tk -Pattern "ToolkitVersion\s*=\s*'([^']+)'" | Select-Object -First 1; if ($m) { $ver = $m.Matches[0].Groups[1].Value } }
    $newMenu = if (Test-Path $tk) { @(Select-String -Path $tk -Pattern "Text = '((?:[^']|'')+)'" -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }) } else { @() }
    $added   = @($newMenu | Where-Object { $oldMenu -notcontains $_ })
    $removed = @($oldMenu | Where-Object { $newMenu -notcontains $_ })
    $title = "ToolKit v$ver update $(Get-Date -Format 'yyyy-MM-dd HH:mm') - $($newMenu.Count) options"
    $body = @("Files: $($changed -join ', ')")
    if ($added)   { $body += ''; $body += 'Added options:';   $body += ($added   | ForEach-Object { "  + $_" }) }
    if ($removed) { $body += ''; $body += 'Removed options:'; $body += ($removed | ForEach-Object { "  - $_" }) }
    $msgFile = Join-Path $LogDir 'commitmsg.txt'
    (@($title, '') + $body) | Set-Content -Path $msgFile -Encoding UTF8

    if ($DryRun) {
        Log "DRY RUN - would commit: $title" 'WARN'
        $body | ForEach-Object { Log "  $_" }
        Invoke-Git reset | Out-Null
        exit 0
    }

    Invoke-Git commit -F $msgFile | Out-Null
    Invoke-Git push origin $cfg.Branch | Out-Null
    Log "Published: $title" 'OK'

    # Tag a release when the ToolKit version number changes (v2.0, v2.1, ...)
    if ($ver) {
        $tag = "v$ver"
        $exists = @(Invoke-GitRaw @('-C', $Repo, 'ls-remote', '--tags', 'origin', $tag) | Where-Object { $_ -match 'refs/tags/' })
        if (-not $exists) { Invoke-Git tag -a $tag -m "Sigma Data Systems INC ToolKit $tag" | Out-Null; Invoke-Git push origin $tag | Out-Null; Log "Tagged $tag" 'OK' }
    }
} catch {
    Log "Publish failed: $($_.Exception.Message)" 'ERROR'
    if ($_.Exception.Message -match 'Authentication|403|401|could not read Username') {
        Log 'GitHub sign-in needed: run this script once interactively (not hidden) so Git Credential Manager can open the browser sign-in.' 'WARN'
    }
    exit 1
}
