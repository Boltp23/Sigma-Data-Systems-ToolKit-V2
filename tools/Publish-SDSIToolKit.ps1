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

    Code signing: after the checks pass, changed .ps1 files are Authenticode-signed with
    Sign-SDSIToolKit.ps1 (settings in SDSI-Signing.json). Unchanged scripts keep their existing
    signature. If signing is configured and fails, nothing is published. If it is not configured,
    the ToolKit is published unsigned with a warning.

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

    # ------------------------------------------------------------------ keep signed scripts byte-exact
    # Git line-ending conversion would break Authenticode signatures, so .ps1/.psm1/.psd1 are stored as-is.
    $gaPath = Join-Path $Repo '.gitattributes'
    $gaNeed = @('*.ps1 -text', '*.psm1 -text', '*.psd1 -text')
    $gaHave = if (Test-Path $gaPath) { @(Get-Content $gaPath) } else { @() }
    $gaAdd  = @($gaNeed | Where-Object { $gaHave -notcontains $_ })
    if ($gaAdd) { Add-Content -Path $gaPath -Value $gaAdd; Log ".gitattributes updated: $($gaAdd -join ', ')" }

    # Remember the currently published (signed) scripts, so an unchanged script keeps its existing
    # signature instead of being re-signed (a new timestamp) and committed every 30 minutes.
    $SigBlock = '(?s)\r?\n# SIG # Begin signature block.*?# SIG # End signature block\r?\n?'
    function Get-ScriptBody([string]$file) {
        $t = [System.IO.File]::ReadAllText($file)   # detects the BOM, defaults to UTF-8
        (([regex]::Replace($t, $SigBlock, '')) -replace "`r`n", "`n").TrimEnd()
    }
    $prevScripts = @{}
    foreach ($f in $cfg.Files) {
        if ($f.Target -notmatch '\.ps(m|d)?1$') { continue }
        $dst = Join-Path $Repo $f.Target
        if (Test-Path $dst) {
            $bytes = [System.IO.File]::ReadAllBytes($dst)
            $prevScripts[$f.Target] = @{
                Bytes  = $bytes
                Body   = Get-ScriptBody $dst
                Signed = [bool](Select-String -Path $dst -Pattern '^# SIG # Begin signature block' -Quiet)
            }
        }
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
            # Read/write explicitly as UTF-8: Windows PowerShell 5.1 would otherwise read a BOM-less README as ANSI and garble it
            $rm = [System.IO.File]::ReadAllText($readme, [System.Text.Encoding]::UTF8)
            if ($rm -match '(?s)<!-- AUTO-OPTIONS:START -->.*?<!-- AUTO-OPTIONS:END -->') {
                $rm = [regex]::Replace($rm, '(?s)<!-- AUTO-OPTIONS:START -->.*?<!-- AUTO-OPTIONS:END -->', { param($m) $index })
            } else {
                $rm = $rm -replace '(## All options\s*\r?\n)', "`$1`r`n$index`r`n"
            }
            $rm = [regex]::Replace($rm, '\*\*\d+ diagnostics', "**$num diagnostics")
            $rm = [regex]::Replace($rm, '`1`(-|\u2013)`\d+`', ('`1`-`' + $num + '`'))
            $ver = (Select-String -Path $tkFile -Pattern "ToolkitVersion\s*=\s*'([^']+)'" | Select-Object -First 1).Matches.Groups[1].Value
            $stamp = "<!-- AUTO-VERSION -->**Current version: v$ver** | $num options | updated $tkDate<!-- /AUTO-VERSION -->"
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

    # ------------------------------------------------------------------ code-sign scripts
    # Runs AFTER all checks and README edits - any later change to a signed file breaks its signature.
    # Signing settings: SDSI-Signing.json (see Sign-SDSIToolKit.ps1 -InitConfig). No config = publish unsigned.
    $signScript = Join-Path $SourceFolder 'Sign-SDSIToolKit.ps1'
    $signConfig = Join-Path $SourceFolder 'SDSI-Signing.json'
    $toSign = @()
    foreach ($f in $cfg.Files) {
        if ($f.Target -notmatch '\.ps(m|d)?1$') { continue }
        $dst = Join-Path $Repo $f.Target
        if (-not (Test-Path $dst)) { continue }
        $prev = $prevScripts[$f.Target]
        if ($prev -and $prev.Signed -and $prev.Body -eq (Get-ScriptBody $dst)) {
            [System.IO.File]::WriteAllBytes($dst, $prev.Bytes)   # unchanged - keep the existing signature
        } else {
            $toSign += $dst
        }
    }
    if ($toSign) {
        if ($DryRun) {
            Log "DRY RUN - would sign: $(($toSign | ForEach-Object { Split-Path $_ -Leaf }) -join ', ')" 'WARN'
        } elseif (-not (Test-Path $signScript) -or -not (Test-Path $signConfig)) {
            Log "Code signing not configured ($signConfig missing) - publishing UNSIGNED." 'WARN'
        } else {
            Log "Signing: $(($toSign | ForEach-Object { Split-Path $_ -Leaf }) -join ', ')"
            & $signScript -Path $toSign -ConfigPath $signConfig *>&1 | ForEach-Object { Log "$_" }
            if ($LASTEXITCODE -ne 0) {
                Log 'NOT PUBLISHED - code signing failed.' 'ERROR'
                $null = Invoke-GitRaw @('-C', $Repo, 'checkout', '--', '.')
                $null = Invoke-GitRaw @('-C', $Repo, 'clean', '-fd')
                exit 3
            }
            Log 'Code signing OK.' 'OK'
        }
    }

    # ------------------------------------------------------------------ anything changed?
    Invoke-Git add -A | Out-Null
    Invoke-Git add --renormalize . | Out-Null
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

# SIG # Begin signature block
# MIIfmwYJKoZIhvcNAQcCoIIfjDCCH4gCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCGQc/9DHmtUTaY
# /ua3INtoMjidr2csmNwrTc9vP8Y6g6CCGLAwggVyMIIDWqADAgECAhAyh/1qfWXo
# p0pwi2mBzP4RMA0GCSqGSIb3DQEBCwUAMFExIDAeBgNVBAoMF1NpZ21hIERhdGEg
# U3lzdGVtcyBJbmMuMS0wKwYDVQQDDCRTaWdtYSBEYXRhIFN5c3RlbXMgSW5jLiBD
# b2RlIFNpZ25pbmcwHhcNMjYxMTE5MTQzODIxWhcNMzExMTE5MTQ0ODIxWjBRMSAw
# HgYDVQQKDBdTaWdtYSBEYXRhIFN5c3RlbXMgSW5jLjEtMCsGA1UEAwwkU2lnbWEg
# RGF0YSBTeXN0ZW1zIEluYy4gQ29kZSBTaWduaW5nMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEAnYx/oIEdiyv8jpaYkOj+318pQHVmsHlP+NyXCmDyVBtF
# 9d0j+ZhoG49Wygte2snHWreUXxSXmd6sR/CPLVbDv5rohLw449i6g7QImME464Aq
# QfWfy/6tGJ9UD6j/pyv+PCO1SPq4+k0px99z7wtTdgrW0aw0jth3uJ7iJ9V/KLkc
# rUl6+cXC2tFsfCq51ZazC7R0ar7rIvOatFRYBrEug6szJ5yTPRCeS8PYCwViOUHF
# gUZZQOgQ29JDs+PfZyS/SyBvqcCFrsm6Yg4rTGNye/ciQOIO0V4LuLmb76VPb7/r
# B9wEOWapIDksOJgparESh+BTeYrFxLcPg38GhdEXxyzAjzp453b32H7qcWEl8L26
# cE8tJnxhjlmG3qJKdVHT0GxOOby3n6/D7V2Cv7M8a6pgKnvRq0ipXyYxeqzWvxg2
# /+jYfV0wkOSpm2UDlvVjjvpWB32AdiAp6kIOtEnLIpHZUNiKBRwjMgL09lUc5krW
# PxDRjXmxjtnLicBCl40NGTIjIoQgJxosOt1VwWWusjIarDw3K8eZowXZzLVwZ4SL
# Yw692+SgBk2Ny1dc9UReaIYGj+qExoIXyuHXhL1/evkLgCgZ7sh47kqa72ID5dvY
# N0+f0IYUGJ8XMiqoTHs79mfZuIksRSaA8ykgjWQcsXm9EvpLrj1s5HFjFH+2L6UC
# AwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0G
# A1UdDgQWBBQNoS0BfQ/sycltRqtB0Dn3rez0gzANBgkqhkiG9w0BAQsFAAOCAgEA
# LIfDUDCfiD0IcNut51N7tY0vQsFM0UH80HLRjCcYC0Is12aTAOBhjMrdpzOtDzjT
# u3qmyTO67weRzQmbwdaZXnteC+kfjR0Cl86oogw5nM7L4KkTAYcRWWtuct/x+ck4
# qKvbqw24eXEa1xsCsWtJf/qcIi6EwceUYRAhU3wQfnR/MUvT8wp3tP9SPZBVhLDN
# wcN10gD1F1TqTVEYlrrCkoUkTYkySEALDNIq20Hw7C9k1xOh2VgxRaiBRWVPQZAF
# eOjPQWKtC+L5rTs9Fast1RqVzrPPvLWoUtuvhNTCktZHMKpNXm1cqegQCQhAuzbO
# Da1pPaQ0NhWcwX5ZDifuWCX1Ca2G+TQsBJMqxWs3s1HrxIK3qRLLLRo3/w9HZ7HE
# V0ia4tbPFhmw6rJWaCrnTcu20y97GW1ej1Uc0dWxi4h2hTdX8HD9Dk9Cn2Y7uELB
# q5/cdVA/k7/I3VNzxZ/m1g/T2sRffDpD/n24JOUJX61eZeE89FCGvAy/JZeM5iMC
# ZYQlKImCbYUxG1AtVvlit6yw6ghhrKtvZtMkYW14/yA8unJHoIhUhw2vuy4OtoRA
# lJnbN4PnuBIfeaHHrAUQizwDoZ+HKAXvyeT31ecwtiPv8GNICb72YBt13x5bFayN
# AVda4rQWIFKWRPOJVEfAnmwwPChpzZ+HIi748DMjFZwwggWNMIIEdaADAgECAhAO
# mxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# JDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEw
# MDAwMDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxE
# aWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMT
# GERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprN
# rnsbhA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVy
# r2iTcMKyunWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4
# IWGbNOsFxl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13j
# rclPXuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4Q
# kXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQn
# vKFPObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu
# 5tTvkpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/
# 8tWMcCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQp
# JYls5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFf
# xCBRa2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGj
# ggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/
# 57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8B
# Af8EBAMCAYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2Nz
# cC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6
# oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEB
# AHCgv0NcVec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0a
# FPQTSnovLbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNE
# m0Mh65ZyoUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZq
# aVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCs
# WKAOQGPFmCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9Fc
# rBjDTZ9ztwGpn1eqXijiuZQwgga0MIIEnKADAgECAhANx6xXBf8hmS5AQyIMOkmG
# MA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAwMDBaFw0zODAxMTQyMzU5
# NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8G
# A1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBT
# SEEyNTYgMjAyNSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC0
# eDHTCphBcr48RsAcrHXbo0ZodLRRF51NrY0NlLWZloMsVO1DahGPNRcybEKq+Ruw
# OnPhof6pvF4uGjwjqNjfEvUi6wuim5bap+0lgloM2zX4kftn5B1IpYzTqpyFQ/4B
# t0mAxAHeHYNnQxqXmRinvuNgxVBdJkf77S2uPoCj7GH8BLuxBG5AvftBdsOECS1U
# kxBvMgEdgkFiDNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2Ws3IfDReb6e3mmdglTca
# arps0wjUjsZvkgFkriK9tUKJm/s80FiocSk1VYLZlDwFt+cVFBURJg6zMUjZa/zb
# CclF83bRVFLeGkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9oHRaQT/aofEnS5xLrfxnG
# pTXiUOeSLsJygoLPp66bkDX1ZlAeSpQl92QOMeRxykvq6gbylsXQskBBBnGy3tW/
# AMOMCZIVNSaz7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+rx3rKWDEJlIqLXvJWnY0v
# 5ydPpOjL6s36czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvUBDx6z1ev+7psNOdgJMoi
# wOrUG2ZdSoQbU2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl9VnePs6BaaeEWvjJSjNm
# 2qA+sdFUeEY0qVjPKOWug/G6X5uAiynM7Bu2ayBjUwIDAQABo4IBXTCCAVkwEgYD
# VR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU729TSunkBnx6yuKQVvYv1Ensy04w
# HwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGG
# MBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8v
# Y2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBD
# BgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgB
# hv1sBwEwDQYJKoZIhvcNAQELBQADggIBABfO+xaAHP4HPRF2cTC9vgvItTSmf83Q
# h8WIGjB/T8ObXAZz8OjuhUxjaaFdleMM0lBryPTQM2qEJPe36zwbSI/mS83afsl3
# YTj+IQhQE7jU/kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy9lMDPjTLxLgXf9r5nWMQ
# wr8Myb9rEVKChHyfpzee5kH0F8HABBgr0UdqirZ7bowe9Vj2AIMD8liyrukZ2iA/
# wdG2th9y1IsA0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1UH410ANVko43+Cdmu4y81
# hjajV/gxdEkMx1NKU4uHQcKfZxAvBAKqMVuqte69M9J6A47OvgRaPs+2ykgcGV00
# TYr2Lr3ty9qIijanrUR3anzEwlvzZiiyfTPjLbnFRsjsYg39OlV8cipDoq7+qNNj
# qFzeGxcytL5TTLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0vw9vODRzW6AxnJll38F0
# cuJG7uEBYTptMSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/DJbg3s6KCLPAlZ66RzIg9
# sC+NJpud/v4+7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHbxtl5TPau1j/1MIDpMPx0
# LckTetiSuEtQvLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAPvIXKUjPSxyZsq8WhbaM2
# tszWkPZPubdcMIIG7TCCBNWgAwIBAgIQCE/cM09+RU7bww+P+ZIYNTANBgkqhkiG
# 9w0BAQsFADBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4x
# QTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQw
# OTYgU0hBMjU2IDIwMjUgQ0ExMB4XDTI2MDgwNTAwMDAwMFoXDTM3MTEwNDIzNTk1
# OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYD
# VQQDEzJEaWdpQ2VydCBTSEEyNTYgUlNBNDA5NiBUaW1lc3RhbXAgUmVzcG9uZGVy
# IDIwMjYgMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALZ7pvLJ/s1K
# +NSbTGWz/TjGMPh8CQ6RucZCLv5anHzWJjF/NWJrFIhy24fcpKXlgRiky4WAawDf
# U3YP0BMxt9l3Dm5oCG5Z69AqEN1kgHg2epx+l+lZBcmJCcN0ASURML5uFIS80sZs
# DwO3BSkUxDjLJhBI+qiZP3aixAC/qEGLjsBNlLol9VZ7pfGEXiMlneJIC5/YKuiz
# VzNFKZZEeoy/0B8Zm+nzKBgSWG52lCO1w+nCg6XpCtklTJXeIg283hw7TmmsZXR+
# SMbjbrEOvZ3fP2VxIgeR28Y90ZStd3F9VuA5RVynb/whITPAo9b75Zr4Ta6Mj3UR
# m26QZYMn/FnbuTegcoRcFEZ9FOqM5T6MTdtr/n74lIT/ug0eeOzmZ6QTFg33otX+
# bFRsIolvykE1jive4PuESaT8zzVeFWDAMDtozNgLctkGD1ZjkEyZtJrLl5ya0m5d
# oH/ScpaZCZVl6pNUOCybMc/kxC6EAmSJY24L0yYKD1Nkddsnb/ItVKi/2nXpQNMu
# 1PT5prW83vV8d67WowuUs0HdY4H8AMLGvdL/WHEj3ZnqMqAQQP9u3Ai9t+5eQ02G
# Dwy0ODjdzi0xlp70W+ow63/0++YDEX1M0iwgUHwbrJvfpklkZQvw3+kv3vUPItdw
# roczk9icflf55W1zOEKAcJVAIXpcMCU9AgMBAAGjggGVMIIBkTAMBgNVHRMBAf8E
# AjAAMB0GA1UdDgQWBBQUyWOKMC7USvtulPPm40B+9ezN4jAfBgNVHSMEGDAWgBTv
# b1NK6eQGfHrK4pBW9i/USezLTjAOBgNVHQ8BAf8EBAMCB4AwFgYDVR0lAQH/BAww
# CgYIKwYBBQUHAwgwgZUGCCsGAQUFBwEBBIGIMIGFMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC5kaWdpY2VydC5jb20wXQYIKwYBBQUHMAKGUWh0dHA6Ly9jYWNlcnRz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQw
# OTZTSEEyNTYyMDI1Q0ExLmNydDBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vY3Js
# My5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0
# MDk2U0hBMjU2MjAyNUNBMS5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZI
# AYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQCNxTphHp1SCt+ZrAmAfn0oQLFr0mLy
# wSLaDXQIENoyKqxrFbJblzCVP/pkXmwXOdrOpWygLzlT12os5ipDCy35RBCg2UMe
# ApEtrfGhz45F4Wt4WGdNdIbRWt3YTYJmpR+b7lr4d7Uwn+H600u4D7RnOGf8Wj4U
# NgAdZkfHhHv1mx9EVh71SJelcEN/oORSjXzdjfw1iZH9d8Nh/thn6hH23d+VsPAr
# 6GAYyzSA02nXD1nYLI7Ijmiv+xLCiYC41DSFYL3GhTiy0PxpawPtGRyaBVGzq+Ui
# TfM8pD7KVyF5aQyWP4KhVGUUTnmm/RlYJoW3TiXA/+t0YcT2oRVBm3JETjajHug2
# AL+v5jhtKVnd3D0rbHXEu27o+Q8p4sEWPMqKDB+qbceb6T/6WcwTwXmQ9lOCLLYc
# sQeSWmvKqzpAec9etE14jOQAzLKWdE3w/TCaKtLRaRT7LCkRYVnhA2D73FLje1O5
# b3HR5eHs0NzU/+xX7NbEdcofy0W3Wdwd1XOqtlpg/JgwtKfZM5dqO94lbUveOiJB
# I+xZEbGRsMNbXmMREUTgu+Oca7Y73MPWcslIx2VhkSKSXjDbD6rgg39H5Mh7Qfie
# AIjWagkJNt68Yfim6cjEzVSiLSeZfdkr5dtFPTW6jATlWJdYeeDRGCyatf8R1hSj
# zSvdN8yWQPT9gzGCBkEwggY9AgEBMGUwUTEgMB4GA1UECgwXU2lnbWEgRGF0YSBT
# eXN0ZW1zIEluYy4xLTArBgNVBAMMJFNpZ21hIERhdGEgU3lzdGVtcyBJbmMuIENv
# ZGUgU2lnbmluZwIQMof9an1l6KdKcItpgcz+ETANBglghkgBZQMEAgEFAKCBhDAY
# BgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3
# AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEi
# BCB8mA/BKYqxyAKF6zSFR3IjF6ZFCM1rzgDa+r7awOSjUjANBgkqhkiG9w0BAQEF
# AASCAgCHBW+7F6ABTU9YxNyN8tZlaP0bEJRAO6jSMxWuxWfxclFPN2p2bWGQkEph
# RGruXPflOIAyHBbHoGC/J3WgOBgjmSwnATaRqPWa4qwt0mAwas39Cn9nQrKEtvcl
# Ia5LvXSPAFywy8Gn94p0AEuQlgHvKeYSgenGsI+fr20APMXKOA3E5ovdIMy9W9tH
# oS6LsoadMzrbGwohaPkk+h+s+MAFxPrT1cbCu/kCH8SrKImAHtA7HJiSVgLyx542
# eI+8mByUsSU4iEli1wzu032mqOcWnBCndJd8gCfQ3TnAkNDsV7aBVtyl/3ayXcBU
# WNfrf6NYan0v5LOr4SM7dP//5dATj6tulWvSjKrPD+TgdZrYEzHcb48vaPURFvTf
# VUHLF3QyXaMNR8Uyq2W9+4RaZequMxjh8xz/rs4SzlAmr0lZlcEJIFitspeBSy6v
# OJVIJcKvJQtbPZcQvP8KQcV5wSOMI/55fpVo1zk+vOWqh6Kk4HqBOKOj7fW6ZBGt
# 3YxyNgh+4GFewBFT0AOcm8fOJlJ+ckJIT9rO+VVhKdJ0sxbTn4O4Ti0Sz+bljA+6
# e75alXLkoIhPsmSeTI/Hem6siQYkv5Fp3xjEGapEtdq7Wvp2Wc7qrXdNWTsTboMO
# HGNW+P8MzCEUCR96K2aE0axUVETcogaldxTanyOHHUzHUADH9qGCAyYwggMiBgkq
# hkiG9w0BCQYxggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5E
# aWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1l
# U3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAhP3DNPfkVO28MPj/mS
# GDUwDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwG
# CSqGSIb3DQEJBTEPFw0yNjExMTkxNTMyMDlaMC8GCSqGSIb3DQEJBDEiBCCQfMYQ
# pelkjqh76d36A4jcCBjTYOlM+L+PbgtzUipAOTANBgkqhkiG9w0BAQEFAASCAgA6
# Sg5P546BFIKam6VSkTrb2W6lG27k7G3/bp9EHOZE1l9FkRLIJYO6HJ3cz4sZD5t/
# Ha6OTlVYo6TkNxvOYtfD9ntsgVNHaipGAtWbqY/Ar1FoMYMGQzutd/bLrqfcPghW
# xK9R3NP02X1vN5toMRg8OKLvfgRZfrM5muawRjyU+wJs54XeUbPIS0uLOemL6Urp
# vB3y0Rx9bWhdshes37/Kb/o2v90c58OY/vsX944PaYlJEwdVDsxNSbzDa39ki0QQ
# 3pxURYHIZq03C8WdAvGKLxuDEzHh4gqD14urL5c6AZar/jXZOhvmtLGeViF9Os7K
# l0KUTPCMZIjTAyKbT2NwQvMHLSnT8eVFN7f9FPeH18Jn4mVM3AcR87MrikRXDjJX
# nM141vczyRykS/yYCWdEayLD90ubWe4gHSeBfNNdggNXEuS7E+WVcxvndO0ejem/
# PKNt6lnoTpGaRtT0AEIGazRUl0aYduPMb1UKr13GiIkRjJJZDulnryf/zE7DqLdU
# PCV9KEc4Y0n3juxRAmgtsmLVY05WMNUKaGt05dM/lqGw78C3sdufF0lcmaV96pVy
# 6lTHV9Mt0I4TC/VMDH3ZYRtLvX68MhMbjwa5DMEW8PU2i2UTVgBOZ8uXnleR92yl
# +xnQhfzn9r/GrnZroe0N/6hM6w4f+W90bMeCSz8ang==
# SIG # End signature block
