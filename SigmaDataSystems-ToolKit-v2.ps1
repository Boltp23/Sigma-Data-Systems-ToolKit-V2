# Sigma Data Systems INC ToolKit

*Prepared by [Sigma Data Systems Inc.](https://sigmadatainc.com/)*

```
  _____ _____ _____ __  __            _____       _______
 / ____|_   _/ ____|  \/  |   /\     |  __ \   /\|__   __|/\
| (___   | || |  __| \  / |  /  \    | |  | | /  \  | |  /  \
 \___ \  | || | |_ | |\/| | / /\ \   | |  | |/ /\ \ | | / /\ \
 ____) |_| || |__| | |  | |/ ____ \  | |__| / ____ \| |/ ____ \
|_____/|_____\_____|_|  |_/_/    \_\ |_____/_/    \_\_/_/    \_\
```

One PowerShell file you can copy to any Windows workstation or server and run.
It opens a numbered menu of **86 diagnostics, fixes and deployment tasks** for MSP / IT support work.
Each option either checks something and writes a report, or makes a fix after asking you to confirm.

- **One file, nothing to install.** 26 longer scripts are built into the file as plain, readable text.
- **Nothing is tied to one client.** Hostnames, domains, VMs, IPs and users are detected automatically or asked for, with defaults you can accept by pressing ENTER.
- **Changes always ask first.** Options marked `[!]` change the machine, and you must type `YES` before they do anything. Everything else only reads.
- **All output goes to `C:\temp`**, in one subfolder per area.
- **Third-party tools are downloaded when you need them** (Sysinternals, NirSoft, Ninite, Microsoft TSS / SetupDiag / Office Deployment Tool). Each download is checked that it's a real installer and, where the vendor signs it, that the signature is valid. Nothing third-party is bundled in the file.
- **Built-in self-test.** `-SelfTest` runs every read-only option unattended and writes a PASS / WARN / FAIL report.

---

## Contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Using the menu](#using-the-menu)
- [All options](#all-options)
- [Self-test](#self-test)
- [Where output goes](#where-output-goes)
- [Downloaded tools and safety checks](#downloaded-tools-and-safety-checks)
- [Antivirus / EDR (SentinelOne etc.)](#antivirus--edr-sentinelone-etc)
- [How it works](#how-it-works)
- [Adding your own tool](#adding-your-own-tool)
- [Troubleshooting](#troubleshooting)
- [Changelog](#changelog)
- [Credits and third-party licenses](#credits-and-third-party-licenses)
- [Disclaimer](#disclaimer)

---

## Requirements

| | |
|---|---|
| **OS** | Windows 10 / 11, Windows Server 2012 R2 – 2025 |
| **PowerShell** | Windows PowerShell 5.1 (built in). Built-in tools always run in 5.1, even if you start the menu from PowerShell 7. |
| **Rights** | Run as **Administrator**. If you don't, the toolkit offers to restart itself elevated. |
| **Optional modules** | Hyper-V, ActiveDirectory, GroupPolicy, DhcpServer, DnsServer, WebAdministration. Options that need a missing module say so and go back to the menu. |
| **Internet** | Only needed for the download options (Sysinternals, NirSoft, Ninite, Office, SetupDiag, TSS) and the Windows Update search. |

---

## Quick start

1. Copy `SigmaDataSystems-ToolKit-v2.ps1` to the machine (for example to `C:\temp`).
2. Open **PowerShell as Administrator** and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\temp\SigmaDataSystems-ToolKit-v2.ps1
```

If the file came from a browser download or an email, unblock it first:

```powershell
Unblock-File C:\temp\SigmaDataSystems-ToolKit-v2.ps1
```

### Parameters

| Parameter | Purpose |
|---|---|
| `-OutputRoot <path>` | Write reports somewhere other than `C:\temp`. |
| `-SelfTest` | Run every read-only option unattended and write a pass/fail report (see [Self-test](#self-test)). |
| `-IncludeSlow` | With `-SelfTest`: also run the slow checks (event log export, largest folders, inventories...). |
| `-IncludeDownloads` | With `-SelfTest`: also run the checks that download Sysinternals / NirSoft / SetupDiag. |

---

## Using the menu

The home screen shows the banner, a line about the machine (host, domain, OS, admin rights, output folder), and the list of sections.

| Type | Does |
|---|---|
| A section letter (`A`, `C`, `D`...) | Open that section |
| Any option number (`1`–`86`) | Run that option directly, from any screen |
| `ALL` | List every option |
| `B` | Back to the section list |
| `O` | Change the output folder |
| `R` | Open the output folder in Explorer |
| `T` | Run the self-test |
| `X` | Write every built-in script out as a normal `.ps1` file, so you can read or edit it |
| `L2` | Show the official download links for every external tool |
| `Q` | Quit (temporary files are cleaned up) |

Prompts show their default in brackets. Press **ENTER** to accept it.
Any option marked `[!]` stops and asks you to **type `YES`** (capitals) before it changes anything.

---

## All options

Legend: **[!]** = changes the machine (asks first) · **slow** = can take several minutes · **dl** = downloads a tool from the vendor's site.

### A. System health
| # | Option | Notes |
|---|---|---|
| 1 | Quick system snapshot (OS, uptime, RAM, disks, pending reboot, errors) | |
| 2 | Export event logs (Application, System, Security, Setup...) + error summary | `.evtx` files plus a CSV of errors and warnings, zipped. slow |
| 3 | Crash / BSOD / unexpected reboot report | HTML |
| 4 | Display / GPU crash diagnostics (TDR, nvlddmkm, WHEA) | |
| 5 | Memory usage diagnostics | |
| 6 | Reliability history (Reliability Monitor data, stability index) | |
| 7 | Performance snapshot (CPU / RAM / disk latency / network, 30 sec) | |
| 8 | Boot / logon performance (what slows startup) | |
| 9 | Hardware health (SMART, disk errors, driver problems, battery, temps) | |
| 10 | Pending reboot – detailed (CBS, Windows Update, file renames, rename/domain join, ConfigMgr) | |
| 11 | Device join / Entra ID / Workplace join / PIN status (dsregcmd) | Flags stray workplace joins that break Windows Hello PINs |
| 12 | Patch & reboot history report | HTML |
| 13 | **[!]** Enable crash dumps (Automatic memory dump) | |

### C. Windows Update / upgrade / repair
| # | Option | Notes |
|---|---|---|
| 14 | Windows Update – list available updates + history (optional install) | slow |
| 15 | **[!]** Reset Windows Update components (Windows 10/11) | Afterwards it offers to delete the leftover `.bak` folders |
| 16 | **[!]** Repair Windows Update (Windows Server 2016+) | |
| 17 | **[!]** System file repair (DISM RestoreHealth + SFC) | |
| 18 | Windows 11 upgrade troubleshooter | Status, SetupDiag results, logs |
| 19 | Microsoft SetupDiag – why did an upgrade fail? | dl |
| 20 | System Reserved / EFI partition – check & free space | Fixes 0x800f0922. Briefly mounts the partition; deleting asks first |

### D. Disk space
| # | Option | Notes |
|---|---|---|
| 21 | Disk space check – what can be reclaimed | Read-only |
| 22 | **[!]** Disk space cleanup (workstation / general) | Logs free space after each stage. Never raises the System Restore cap. Skips an update cache that's mid-download |
| 23 | Disk space analyze & resolve – servers | Dry run by default |
| 24 | Find largest folders | slow |
| 25 | Event log folder bloat (Archive-*.evtx) – check / clean up | |
| 26 | **[!]** Clear Dell SupportAssist remediation cache | Often 100+ GB |

### E. Network / DHCP / DNS / shares
| # | Option | Notes |
|---|---|---|
| 27 | Ping / port reachability test | Optional live monitor that logs up/down changes |
| 28 | Advanced network diagnostics | DNS per server, packet loss, path MTU, tracert, proxy, Wi-Fi report. slow |
| 29 | Network connections & listening ports by process | |
| 30 | SMTP / scan-to-email relay test + SPF / DMARC / MX lookup | For copier / scanner mail problems |
| 31 | **[!]** Network quick fixes | Flush DNS / DHCP renew / Winsock + TCP/IP reset |
| 32 | DHCP Event 1059 / DC authorization diagnostics | |
| 33 | DHCP mobile device lease audit / cleanup | Audit only by default |
| 34 | DNS server forwarders – check / set | |
| 35 | File shares, sessions and open files | Can force-close locked files |

### F. Remote Desktop (RDP / RDS)
| # | Option | Notes |
|---|---|---|
| 36 | RDP / RDS server health | Services, sessions, licensing, September 2026 update hang |
| 37 | **[!]** RDS fix – September 2026 update hang | Restart services / install the fix update / registry workaround (backed up first) |
| 38 | **[!]** RDP clipboard / drive "redirection" popup | Apply or remove the `RedirectionWarningDialogVersion` stopgap |

### G. Hyper-V / virtual machines
| # | Option | Notes |
|---|---|---|
| 39 | HOST: VM hang / host-side diagnostics | Lists the VMs to pick from |
| 40 | HOST: Guest Status (Hyper-V) failure diagnostics | |
| 41 | HOST: capture evidence from a hung VM (before Turn Off) | Console screenshot, WinRM checks, optional NMI |
| 42 | HOST: integration services (Time Sync, VSS, Heartbeat) check / enable | |
| 43 | GUEST: VM hang diagnostics (run inside the VM) | slow |
| 44 | GUEST: hang timeline / NMI crash-dump readiness | |

### H. Server / Active Directory / backup
| # | Option | Notes |
|---|---|---|
| 45 | Server roles & key services | SQL, IIS, Exchange, QuickBooks, Sage, backup agents |
| 46 | Windows server audit | Roles, shares, software, IIS, SMTP. HTML. slow |
| 47 | Active Directory / DC health | dcdiag, repadmin, FSMO, SYSVOL / DFSR |
| 48 | Group Policy audit | HTML + CSV |
| 49 | Group Policy results for this machine | gpresult HTML + Group Policy errors |
| 50 | AD users – true last logon | Queries every DC. slow |
| 51 | Export BitLocker recovery keys from AD | **Secret output – handle securely** |
| 52 | Export LAPS passwords from AD (legacy + Windows LAPS) | **Secret output – handle securely** |
| 53 | Azure AD / Entra Connect Sync (ADSync) status | Offers to restart the service if it's stopped |
| 54 | Backup / VSS health | VSS writers, shadow storage, Windows Server Backup, backup agents |
| 55 | Folder permissions (ACL) export | |
| 56 | SharePoint / OneDrive migration check | Bad names, long paths, QuickBooks / Access / PST blockers. Optional auto-rename |

### I. Security / incident response / RMM
| # | Option | Notes |
|---|---|---|
| 57 | Security posture | AV, firewall, BitLocker, TPM, Secure Boot, SMBv1, RDP NLA, local admins, expiring certificates, activation |
| 58 | Sysinternals Autoruns – startup / persistence report | Unsigned items flagged. dl |
| 59 | Sysinternals Sigcheck – unsigned executables in user / ProgramData folders | dl |
| 60 | N-central compromise IOC hunt | |
| 61 | Unknown / adware program hunt | Prefetch, browser notification permissions, startup, scheduled tasks |
| 62 | Incident response log collection for a time window | 4688, PowerShell, Defender, WMI, logons. Zipped. slow |
| 63 | N-able Take Control / agent service diagnostics | Local or remote |

### J. Software / inventory / users
| # | Option | Notes |
|---|---|---|
| 64 | Installed software inventory | CSV |
| 65 | User profiles – size, last use | slow |
| 66 | Migration inventory (full machine discovery) | slow |
| 67 | Install provenance for a program (when / how / by whom) | |
| 68 | .NET / Node.js / Java / Python / VC++ runtime versions | |
| 69 | Citrix Workspace app – install state | |
| 70 | Time sync (w32time) check / resync | |

### K. Quick fixes
| # | Option |
|---|---|
| 71 | **[!]** Print spooler reset (clear stuck jobs) |
| 72 | **[!]** Microsoft Teams cache clear (classic + new) |
| 73 | **[!]** Office quick / online repair |
| 74 | **[!]** OneDrive reset |
| 75 | **[!]** Repair `.zip` association / reset default browser (per user) |
| 76 | **[!]** Remove bloatware (OEM + consumer Store apps) |
| 77 | **[!]** Power settings – never sleep / hibernate |

### L. Software deployment (downloads to `C:\temp\Tools`)
| # | Option | Notes |
|---|---|---|
| 78 | **[!]** Install common apps with Ninite | Chrome, Firefox, 7-Zip, Zoom, Notepad++ and more. dl |
| 79 | **[!]** Install apps silently from the vendor | Chrome / Firefox / Edge enterprise MSI, Zoom, Teams, OneDrive. dl |
| 80 | **[!]** Install Microsoft 365 Apps / Office (Office Deployment Tool) | Removes OEM Office first. Turns on Shared Computer Activation for RDS. dl |
| 81 | **[!]** Remove ALL existing Office | OEM preinstalls, extra languages, MSI Office. dl |

### M. Sysinternals / NirSoft / Microsoft tools (downloaded on demand)
| # | Option | Notes |
|---|---|---|
| 82 | NirSoft reports: BlueScreenView, AppCrashView, TurnedOnTimesView, LastActivityView, USBDeview, DriverView | HTML. dl |
| 83 | Sysinternals Handle – what is locking this file? | dl |
| 84 | Sysinternals ProcDump – dump a hung or crashing program | dl |
| 85 | Download & launch a GUI tool | Process Explorer, Process Monitor, Autoruns, TCPView, RAMMap, ShellExView, CurrPorts... dl |
| 86 | Microsoft TSS – official support log collection (SDP) | dl |

---

## Self-test

The self-test checks the toolkit itself on a real machine. It runs every **read-only** option with its default answers and **declines every change**.

```powershell
# Standard (about 5–10 minutes)
powershell -ExecutionPolicy Bypass -File .\SigmaDataSystems-ToolKit-v2.ps1 -SelfTest

# Full coverage (about 20–40 minutes, needs internet)
powershell -ExecutionPolicy Bypass -File .\SigmaDataSystems-ToolKit-v2.ps1 -SelfTest -IncludeSlow -IncludeDownloads
```

You can also type `T` in the menu.

It checks that:

1. every built-in script unpacks and parses,
2. every menu option points to a function that exists,
3. every read-only option runs to the end.

Results go to `C:\temp\SelfTest\SelfTest_<HOST>_<date>.csv` (and a full `.log` transcript):

| Status | Meaning |
|---|---|
| **PASS** | Ran to the end |
| **WARN** | Ran, but a built-in script returned a non-zero exit code. Sometimes that's expected (for example, disk check exit 10 means "below target") |
| **FAIL** | Hit an error that stopped it. Look at the `Detail` column |

The `Errors` column counts minor errors that were handled along the way. Missing roles or modules ("DHCP Server not installed") are normal there.

---

## Where output goes

Everything is written under `C:\temp`. Change it with `-OutputRoot` or menu `O`.

```
C:\temp\
├── Crash\            BSOD / crash HTML reports
├── EventLogs\        .evtx exports + error CSVs + .zip
├── DiskSpace\        cleanup logs, largest-folder CSVs
├── WindowsUpdate\    WU reset / repair logs
├── Network\          connection lists, reachability logs, Wi-Fi reports
├── HyperV\           host / guest / hang captures
├── RDS\              registry backups before RDS changes
├── AD\  ADHealth\    AD exports and DC health output
├── Security\         posture, Autoruns, unsigned files, adware hunt
├── IR\               incident response collections (.zip)
├── NirSoft\          NirSoft HTML reports
├── Software\         inventories, profiles, install provenance
├── SelfTest\         self-test reports
└── Tools\            downloaded tools (Sysinternals, NirSoft, Ninite, Office ODT, TSS, SetupDiag)
```

> **Secret output:** options 51 (BitLocker keys) and 52 (LAPS passwords) write secrets to disk.
> Move those files somewhere secure and delete them from the machine.

---

## Downloaded tools and safety checks

Third-party tools are **not** inside the toolkit. They're downloaded from the official site the first time you use them and kept in `C:\temp\Tools`. Only PowerShell's own `Invoke-WebRequest` is used, with no winget, curl or other programs.

Before a downloaded `.exe` / `.msi` is run:

1. It must be a real Windows program or MSI, not an HTML error page. Otherwise it's deleted and skipped.
2. Where the vendor signs its files (Microsoft, Google, Mozilla, Zoom, Ninite), the **Authenticode signature must be valid** and come from the expected publisher. Otherwise it's deleted and skipped.
3. If a download fails, the toolkit prints the manual link and moves on. It never stops partway.

| Source | Link |
|---|---|
| Sysinternals Suite | https://download.sysinternals.com/files/SysinternalsSuite.zip |
| Sysinternals (single tools) | https://live.sysinternals.com/ |
| NirSoft | https://www.nirsoft.net/utils/index.html |
| Ninite | https://ninite.com/ |
| Office Deployment Tool | https://go.microsoft.com/fwlink/p/?LinkID=626065 |
| Microsoft TSS | https://aka.ms/getTSS |
| Microsoft SetupDiag | https://go.microsoft.com/fwlink/?linkid=870142 |
| Microsoft Update Catalog | https://www.catalog.update.microsoft.com/ |

**Deliberately excluded:** NirSoft password-recovery tools and PsExec. EDR products flag these as hacking tools.

---

## Antivirus / EDR (SentinelOne etc.)

The toolkit is written to avoid malware-like patterns. There's no base64, no compression and no `-EncodedCommand`. Built-in scripts are stored as plain text and run with a normal `powershell.exe -File`.

Some options still do things EDRs watch closely: reading LAPS / BitLocker data, pulling the Security log, reading browser profile settings, injecting an NMI into a VM. If your EDR blocks it:

1. Check the threat details to see which indicator fired.
2. Mark it as a false positive.
3. Add a path or hash exclusion for the script and `%TEMP%\SDSI-ToolKit_*`. Even better, **code-sign** the script with your company certificate and allow that publisher.

---

## How it works

```
SigmaDataSystems-ToolKit-v2.ps1
├── Help header + parameters
├── Helpers          prompts, confirmations, output folders, self-test answers
├── Tool runner      writes a built-in script to %TEMP%\SDSI-ToolKit_xxxx\ and runs it in its own
│                    Windows PowerShell process (a script that exits or errors can't kill the menu)
├── Menu actions     one Invoke-* function per option
├── Self-test
├── Menu definition  sections + options (numbers are assigned automatically)
├── Built-in tools   $Script:Payloads['Name'] = @' ...plain .ps1 text... '@
└── Main loop
```

- Built-in scripts are stored as single-quoted here-strings. A line inside a script that starts with `'@` is saved with a `#SDSI-ESC#` prefix so it can't end the block early, and the prefix is removed when the script is unpacked.
- Unpacked files are written as UTF-8 **with BOM**, so Windows PowerShell 5.1 reads special characters correctly.
- The temp work folder is deleted when you quit.

---

## Adding your own tool

**Small check (inline):**

1. Write a function such as `Invoke-MyCheck` in the *Menu actions* region. Use `Read-Default`, `Read-YesNo`, `Read-Int` and `Read-List` for questions, and `Confirm-Change` before any change. Write files with `Get-OutDir 'MyArea'`.
2. Add a line to `$Script:Menu` in the right section:

   ```powershell
   @{ Test='safe'; Text = 'My new check';  Action = { Invoke-MyCheck } }
   ```

   Use `Test='safe'` for read-only checks, `'slow'` for long ones, `'net'` for ones that download, and leave `Test` out for anything that changes the machine. Numbers renumber automatically.

**Full script (embedded):**

1. Remove anything client-specific: hostnames, IPs, paths, credentials. Make them parameters instead.
2. Add it as `$Script:Payloads['My-Script'] = @' ... '@` (escape any line starting with `'@`).
3. Call it from a menu function with `Invoke-Tool 'My-Script' ([ordered]@{ Param1 = $value; Switch1 = $true })`.
4. Run `-SelfTest` before committing.

**Rules:** never hardcode credentials, client names or IPs. Every change must go through `Confirm-Change`. Test on Windows PowerShell 5.1, not just 7. Some cmdlets behave differently there; for example, `Get-AppxPackage -Name` takes only one name in 5.1.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "running scripts is disabled on this system" | Start it with `-ExecutionPolicy Bypass` (see Quick start) or `Unblock-File` it. |
| Many "Access denied" errors | Run PowerShell **as Administrator**. |
| "module ... is not installed" | That option needs a role or RSAT tools. Run it on the server that has them. |
| A download fails | No internet access or a proxy blocked it. Use the manual link (`L2`) and put the file in the folder shown. |
| An EDR kills the script | See [Antivirus / EDR](#antivirus--edr-sentinelone-etc). |
| An option errors | Run `-SelfTest` and open an issue with the CSV row and the `.log` transcript. |

---

## Changelog

### v2.0 (2026-10)
- Section menu: section letters, direct option numbers, `ALL`, `B` back.
- Built-in **self-test** (`-SelfTest`, `-IncludeSlow`, `-IncludeDownloads`, menu `T`).
- New diagnostics: security posture, hardware / SMART health, reliability history, performance snapshot, boot performance, detailed pending reboot, Windows Update list / install, AD / DC health, backup / VSS health, shares / open files, advanced network, server roles & services, gpresult, software inventory, user profiles, time sync.
- New fixes: SFC / DISM, print spooler, network reset, Teams cache, Office repair, OneDrive reset.
- Software deployment: Ninite, silent vendor installers, Microsoft 365 Apps via the Office Deployment Tool, remove all Office.
- Tool integrations: Sysinternals (Autoruns, Sigcheck, Handle, ProcDump, GUI launcher, full Suite), NirSoft reports and GUI tools, Microsoft SetupDiag and TSS.
- Downloads are checked to be real installers and, where signed, to carry a valid signature.
- Fixes:
  - Disk cleanup could *increase* used space: it no longer raises the System Restore cap or forces an update re-download, and it now removes leftover `SoftwareDistribution.bak` / `catroot2.bak` folders.
  - Temp folder fallback when `%TEMP%` is empty (RMM / SYSTEM context).
  - `Get-AppxPackage` array bug on Windows PowerShell 5.1.

### v1.0 (2026-10)
- First release: 51 options built from the `C:\powershell` script library, with client-specific values removed.
- Banner, `C:\temp` output, event log export, RDP / RDS fixes, options drawn from past troubleshooting.
- Plain-text built-in scripts (no encoding) so EDRs don't flag it.

---

## Credits and third-party licenses

- **[Sigma Data Systems Inc.](https://sigmadatainc.com/)**: toolkit, menu, and most built-in scripts.
- **Built-in third-party scripts** (attribution kept in each script's header):
  - `Get-LAPSPasswords.ps1` – Karl Fosaaen / NetSPI, https://github.com/kfosaaen/Get-LAPSPasswords
  - `Export-Bitlockerkeys.ps1` – Ali Tajran, https://www.alitajran.com/
- **Ideas drawn from** (MIT-licensed, rewritten here): [bcwilhite/PendingReboot](https://github.com/bcwilhite/PendingReboot), [MahmoudNoureddine/SysAdmin-PS-Toolkit](https://github.com/MahmoudNoureddine/SysAdmin-PS-Toolkit), [steviecoaster/PSSysadminToolkit](https://github.com/steviecoaster/PSSysadminToolkit), [ruudmens/LazyAdmin](https://github.com/ruudmens/LazyAdmin).
- **Downloaded tools** keep their own licenses and are not redistributed here:
  - Sysinternals – Microsoft license terms: https://learn.microsoft.com/sysinternals/license-terms. Command-line tools run with `-accepteula` after you confirm.
  - NirSoft – freeware by Nir Sofer: https://www.nirsoft.net
  - Ninite, Microsoft TSS / SetupDiag / Office Deployment Tool – their vendors' terms apply.

---

## Disclaimer

This toolkit is provided **as is**, without warranty. Options marked `[!]` change the system: uninstalling Office, resetting the network stack, clearing caches, deleting files. Read each prompt before typing `YES`, and test on a non-production machine first. Exported BitLocker keys and LAPS passwords are sensitive. Store them securely and delete them from the endpoint when you're done.

---

**Sigma Data Systems Inc.** · https://sigmadatainc.com/