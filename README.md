# Sigma Data Systems INC ToolKit

*Prepared by [Sigma Data Systems Inc.](https://sigmadatainc.com/)*

<!-- AUTO-VERSION -->**Current version: v2.0** | 124 options | updated 2026-10-03<!-- /AUTO-VERSION -->

```
  _____ _____ _____ __  __            _____       _______
 / ____|_   _/ ____|  \/  |   /\     |  __ \   /\|__   __|/\
| (___   | || |  __| \  / |  /  \    | |  | | /  \  | |  /  \
 \___ \  | || | |_ | |\/| | / /\ \   | |  | |/ /\ \ | | / /\ \
 ____) |_| || |__| | |  | |/ ____ \  | |__| / ____ \| |/ ____ \
|_____/|_____\_____|_|  |_/_/    \_\ |_____/_/    \_\_/_/    \_\
```

One PowerShell file you can copy to any Windows workstation or server and run.
It opens a numbered menu of **124 diagnostics, fixes, Microsoft 365 and deployment tasks** for MSP / IT support work.
Each option either checks something and writes a report, or makes a fix after asking you to confirm.

- **One file, nothing to install.** 34 longer scripts (plus 2 data files) are built into the file as plain, readable text.
- **Nothing is tied to one client.** Hostnames, domains, VMs, IPs and users are detected automatically or asked for, with defaults you can accept by pressing ENTER.
- **Changes always ask first.** Options marked `[!]` change the machine, and you must type `YES` before they do anything. Everything else only reads.
- **All output goes to `C:\temp`**, in one subfolder per area.
- **Third-party tools are downloaded when you need them** (Sysinternals, NirSoft, Ninite, Ookla Speedtest, Microsoft TSS / SetupDiag / Office Deployment Tool). Each download is checked that it's a real installer and, where the vendor signs it, that the signature is valid. Nothing third-party is bundled in the file.
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
- [Publishing to GitHub automatically](#publishing-to-github-automatically)
- [Troubleshooting](#troubleshooting)
- [Changelog](#changelog)
- [Credits and third-party licenses](#credits-and-third-party-licenses)
- [Disclaimer](#disclaimer)

---

## Requirements

| | |
|---|---|
| **OS** | Windows 10 / 11, Windows Server 2012 R2 - 2025 |
| **PowerShell** | Windows PowerShell 5.1 (built in). Built-in tools always run in 5.1, even if you start the menu from PowerShell 7. |
| **Rights** | Run as **Administrator**. If you don't, the toolkit offers to restart itself elevated. |
| **Optional modules** | Hyper-V, ActiveDirectory, GroupPolicy, DhcpServer, DnsServer, WebAdministration. Options that need a missing module say so and go back to the menu. |
| **Microsoft 365** | ExchangeOnlineManagement 3.7+ and Microsoft.Graph.Authentication (the full Microsoft.Graph SDK for the compromised-account and posture audits). Option **92** installs them for the current user. Sign in with an Exchange / Global Reader role for audits and an admin role for changes. |
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
| Any option number (`1`-`124`) | Run that option directly, from any screen |
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

<!-- AUTO-OPTIONS:START -->
<details><summary><b>Quick index of all 124 options</b> (auto-generated from the script, 2026-10-03)</summary>

**A. SYSTEM HEALTH**

1. Quick system snapshot (OS, uptime, RAM, disks, pending reboot, errors)
2. Export event logs (Application, System, Security, Setup...) + error summary
3. Crash / BSOD / unexpected reboot report (HTML)
4. Display / GPU crash diagnostics (TDR, nvlddmkm, WHEA)
5. Memory usage diagnostics
6. Reliability history (Reliability Monitor data, stability index)
7. Performance snapshot (CPU / RAM / disk latency / network, 30 sec)
8. Boot / logon performance (what slows startup)
9. Hardware health (SMART, disk errors, driver problems, battery, temps)
10. Pending reboot - detailed (CBS, WU, file renames, rename/join, ConfigMgr)
11. Device join / Entra ID / Workplace join / PIN status (dsregcmd)
12. Patch & reboot history report (HTML)
13. [!] Enable crash dumps (Automatic memory dump)

**C. WINDOWS UPDATE / UPGRADE / REPAIR**

14. Windows Update - list available updates + history (optional install)
15. [!] Reset Windows Update components (Windows 10/11)
16. [!] Repair Windows Update (Windows Server 2016+)
17. [!] System file repair (DISM RestoreHealth + SFC)
18. Windows 11 upgrade troubleshooter (status, SetupDiag, logs...)
19. Microsoft SetupDiag - why did an upgrade fail? (downloads from Microsoft)
20. System Reserved / EFI partition - check & free space

**D. DISK SPACE**

21. Disk space check - what can be reclaimed (read-only)
22. [!] Disk space cleanup (workstation / general)
23. Disk space analyze & resolve - servers (dry run by default)
24. Find largest folders
25. Event log folder bloat (Archive-*.evtx) - check / clean up
26. [!] Clear Dell SupportAssist remediation cache

**E. NETWORK / DHCP / DNS / SHARES**

27. What is my public IP? (IPv4/IPv6, ISP, location, proxy check)
28. Internet speed test (built-in Cloudflare test or Ookla Speedtest CLI)
29. Ping / port reachability test (optional live monitor)
30. Advanced network diagnostics (DNS per server, loss, MTU, tracert, proxy, Wi-Fi)
31. Wi-Fi deep diagnostics (signal, channels & congestion, neighbors, roaming, driver, drops)
32. Wi-Fi live monitor (signal / roams / channel changes / drops / lag over time)
33. Network connections & listening ports by process
34. SMTP / scan-to-email relay test + SPF/DMARC/MX lookup
35. [!] Network quick fixes (flush DNS / renew / Winsock + TCP/IP reset)
36. DHCP Event 1059 / DC authorization diagnostics
37. DHCP mobile device lease audit / cleanup
38. DNS server forwarders - check / set
39. File shares, sessions and open files (close locked files)

**F. REMOTE DESKTOP (RDP / RDS)**

40. RDP / RDS server health (services, sessions, licensing, Sept 2026 update hang)
41. [!] RDS fix - September 2026 update hang (restart / OOB KB / override)
42. [!] RDP clipboard/drive "redirection" popup - apply / remove stopgap

**G. HYPER-V / VIRTUAL MACHINES**

43. HOST: VM hang / host-side diagnostics (pick a VM)
44. HOST: Guest Status (Hyper-V) failure diagnostics
45. HOST: capture evidence from a HUNG VM (before Turn Off)
46. HOST: integration services (Time Sync, VSS, Heartbeat) check / enable
47. GUEST: VM hang diagnostics (run inside the VM)
48. GUEST: hang timeline / NMI crash-dump readiness

**H. SERVER / ACTIVE DIRECTORY / BACKUP**

49. Server roles & key services (SQL, IIS, Exchange, QuickBooks, Sage, backup...)
50. Windows server audit (roles, shares, software, IIS, SMTP) HTML
51. Active Directory / DC health (dcdiag, repadmin, FSMO, SYSVOL/DFSR)
52. Group Policy audit (HTML + CSV)
53. Group Policy results for this machine (gpresult HTML + GP errors)
54. AD users - true last logon (all DCs)
55. Export BitLocker recovery keys from AD
56. Export LAPS passwords from AD (legacy + Windows LAPS)
57. Azure AD / Entra Connect Sync (ADSync) status + self-heal
58. Backup / VSS health (VSS writers, shadow storage, WSB, backup agents)
59. Folder permissions (ACL) export
60. SharePoint/OneDrive migration - bad names, long paths, QB/Access/PST blockers

**I. SECURITY / INCIDENT RESPONSE / RMM**

61. Security posture (AV, firewall, BitLocker, TPM, SMBv1, admins, certs, activation)
62. Sysinternals Autoruns - startup/persistence report (unsigned flagged)
63. Sysinternals Sigcheck - unsigned executables in user/ProgramData folders
64. N-central compromise IOC hunt
65. Unknown / adware program hunt (Prefetch, browser notifications, startup)
66. Incident response log collection for a time window (4688, PS, Defender, WMI)
67. N-able Take Control / agent service diagnostics

**J. SOFTWARE / INVENTORY / USERS**

68. Installed software inventory (CSV)
69. User profiles - size, last use (stale / temp profiles)
70. Migration inventory (full machine discovery)
71. Install provenance for a program (when/how/by whom)
72. .NET / Node.js / Java / Python / VC++ runtime versions
73. Citrix Workspace app - install state
74. Time sync (w32time) check / resync

**K. QUICK FIXES**

75. [!] Print spooler reset (clear stuck jobs)
76. [!] Microsoft Teams cache clear (classic + new)
77. [!] Office quick / online repair
78. [!] OneDrive reset
79. [!] Repair .zip association / reset default browser (per user)
80. [!] Remove bloatware (OEM + consumer Store apps)
81. [!] Power settings - never sleep / hibernate

**L. SOFTWARE DEPLOYMENT (downloads to C:\temp\Tools)**

82. [!] Install common apps with Ninite (Chrome, Firefox, 7-Zip, Zoom...)
83. [!] Install apps silently from the vendor (Chrome/Firefox/Edge MSI, Zoom, Teams, OneDrive)
84. [!] Install Microsoft 365 Apps / Office (ODT, removes OEM Office first)
85. [!] Remove ALL existing Office (OEM preinstalls, extra languages, MSI)

**M. SYSINTERNALS / NIRSOFT / MICROSOFT TOOLS (downloaded on demand)**

86. NirSoft reports: BlueScreenView, AppCrashView, TurnedOnTimes, LastActivity, USB
87. Sysinternals Handle - what is locking this file?
88. Sysinternals ProcDump - dump a hung / crashing program
89. Download & launch a GUI tool (ProcExp, ProcMon, Autoruns, TCPView, ShellExView...)
90. Microsoft TSS - official support log collection (SDP)

**N. MICROSOFT 365 (Exchange Online / Entra ID / Intune)**

91. M365: set admin account & client tenant (GDAP / partner) for the options below
92. M365: install / repair PowerShell modules (EXO, Graph, SPO, Teams; EXO 3.7.1 conflict fix)
93. M365: compromised account AUDIT (rules, forwarding, sign-ins, MFA, apps - HTML)
94. [!] M365: CONTAIN compromised account (block, revoke, reset, rules, forwarding, unblock send)
95. M365: inbox rules - one or all mailboxes, suspicious flagged, WHEN created (audit log)
96. M365: forwarding audit (mailbox forwarding, external forward rules, tenant policy)
97. M365: message trace (sender / recipient / subject, up to 90 days, delivery detail)
98. M365: quarantine - find & release messages (shows Spam / Bulk / Phish reason)
99. M365: why is this sender filtered? (rules, BCL vs SCL, TABL, impersonation) + fixes
100. M365: SPF / DKIM / DMARC / MX check for all domains (lookup count, DKIM status)
101. M365: Direct Send / connectors (scanner connector, RejectDirectSend)
102. M365: top inbound sender / outbound recipient domains (90 days)
103. M365: mailbox permissions (Full Access / Send As / Send on Behalf)
104. M365: mailbox sizes, quotas, archive status
105. M365: mobile devices for a user (lost phone/iPad) + account-only / full wipe
106. M365: unified audit log search (user / operation / IP, up to 180 days)
107. M365: sign-in log for a user (IPs, countries, legacy protocols)
108. M365: MFA registration report (admins without MFA flagged)
109. M365: stale / never-used / guest / disabled-but-licensed accounts
110. M365: admin role members (Global Admin count check)
111. M365: license report (subscriptions, who has what, wasted licenses)
112. [!] M365: assign / remove licenses (users, group-based, remove direct)
113. [!] M365: create a new user (random temp password, license, groups)
114. M365: app consent audit + admin-consent link (risky app permissions)
115. M365: app registration secrets / certificates expiring soon
116. M365: Intune devices (compliance, stale, BitLocker key missing in Entra)
117. M365: OneDrive folder sharing / permissions for a user
118. [!] M365: exclude a SharePoint site from a retention policy
119. M365: tenant hardening audit (legacy auth, forwarding, audit log, Defender, alerts)
120. M365: security posture audit (134 checks, license-aware, client HTML report)
121. M365: remediation plan from a posture audit (technical + client summary)
122. [!] M365: create app registration for unattended automation (cert auth)
123. [!] THIS PC: force a Hybrid Entra ID join attempt
124. [!] THIS PC: back up BitLocker recovery key to Entra ID

</details>
<!-- AUTO-OPTIONS:END -->

Legend: **[!]** = changes the machine (asks first) | **slow** = can take several minutes | **dl** = downloads a tool from the vendor's site.

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
| 10 | Pending reboot - detailed (CBS, Windows Update, file renames, rename/domain join, ConfigMgr) | |
| 11 | Device join / Entra ID / Workplace join / PIN status (dsregcmd) | Flags stray workplace joins that break Windows Hello PINs |
| 12 | Patch & reboot history report | HTML |
| 13 | **[!]** Enable crash dumps (Automatic memory dump) | |

### C. Windows Update / upgrade / repair
| # | Option | Notes |
|---|---|---|
| 14 | Windows Update - list available updates + history (optional install) | slow |
| 15 | **[!]** Reset Windows Update components (Windows 10/11) | Afterwards it offers to delete the leftover `.bak` folders |
| 16 | **[!]** Repair Windows Update (Windows Server 2016+) | |
| 17 | **[!]** System file repair (DISM RestoreHealth + SFC) | |
| 18 | Windows 11 upgrade troubleshooter | Status, SetupDiag results, logs |
| 19 | Microsoft SetupDiag - why did an upgrade fail? | dl |
| 20 | System Reserved / EFI partition - check & free space | Fixes 0x800f0922. Briefly mounts the partition; deleting asks first |

### D. Disk space
| # | Option | Notes |
|---|---|---|
| 21 | Disk space check - what can be reclaimed | Read-only |
| 22 | **[!]** Disk space cleanup (workstation / general) | Logs free space after each stage. Never raises the System Restore cap. Skips an update cache that's mid-download |
| 23 | Disk space analyze & resolve - servers | Dry run by default |
| 24 | Find largest folders | slow |
| 25 | Event log folder bloat (Archive-*.evtx) - check / clean up | |
| 26 | **[!]** Clear Dell SupportAssist remediation cache | Often 100+ GB |

### E. Network / DHCP / DNS / shares
| # | Option | Notes |
|---|---|---|
| 27 | What is my public IP? | IPv4 / IPv6, ISP, location, reverse DNS. Flags a proxy or web filter when the web and DNS lookups disagree |
| 28 | Internet speed test | Built-in test against Cloudflare's speed servers (nothing to download), or the Ookla Speedtest CLI (dl). Keeps a history per machine in `C:\temp\Network\SpeedTest_History.csv` |
| 29 | Ping / port reachability test | Optional live monitor that logs up/down changes |
| 30 | Advanced network diagnostics | DNS per server, packet loss, path MTU, tracert, proxy, Wi-Fi report. slow |
| 31 | Wi-Fi deep diagnostics | Signal in dBm, link rate, band, every nearby AP (fresh scan) with channel, client count and **channel utilization**. 2.4 GHz overlap scoring on 1/6/11, 5 GHz congestion per 80 MHz block, DFS warnings, sticky-client and wrong-band detection, driver age, adapter power saving, 7-day disconnect reasons, gateway loss/lag. Plain-English findings with the best channel to move to. Optional fix: adapter power saving off |
| 32 | Wi-Fi live monitor | Samples signal, AP, channel, link rate and gateway/internet ping every few seconds. Flags roams, channel changes (DFS/auto-channel), disconnects, loss and lag. CSV log - run it while the problem is happening |
| 33 | Network connections & listening ports by process | |
| 34 | SMTP / scan-to-email relay test + SPF / DMARC / MX lookup | For copier / scanner mail problems |
| 35 | **[!]** Network quick fixes | Flush DNS / DHCP renew / Winsock + TCP/IP reset |
| 36 | DHCP Event 1059 / DC authorization diagnostics | |
| 37 | DHCP mobile device lease audit / cleanup | Audit only by default |
| 38 | DNS server forwarders - check / set | |
| 39 | File shares, sessions and open files | Can force-close locked files |

### F. Remote Desktop (RDP / RDS)
| # | Option | Notes |
|---|---|---|
| 40 | RDP / RDS server health | Services, sessions, licensing, September 2026 update hang |
| 41 | **[!]** RDS fix - September 2026 update hang | Restart services / install the fix update / registry workaround (backed up first) |
| 42 | **[!]** RDP clipboard / drive "redirection" popup | Apply or remove the `RedirectionWarningDialogVersion` stopgap |

### G. Hyper-V / virtual machines
| # | Option | Notes |
|---|---|---|
| 43 | HOST: VM hang / host-side diagnostics | Lists the VMs to pick from |
| 44 | HOST: Guest Status (Hyper-V) failure diagnostics | |
| 45 | HOST: capture evidence from a hung VM (before Turn Off) | Console screenshot, WinRM checks, optional NMI |
| 46 | HOST: integration services (Time Sync, VSS, Heartbeat) check / enable | |
| 47 | GUEST: VM hang diagnostics (run inside the VM) | slow |
| 48 | GUEST: hang timeline / NMI crash-dump readiness | |

### H. Server / Active Directory / backup
| # | Option | Notes |
|---|---|---|
| 49 | Server roles & key services | SQL, IIS, Exchange, QuickBooks, Sage, backup agents |
| 50 | Windows server audit | Roles, shares, software, IIS, SMTP. HTML. slow |
| 51 | Active Directory / DC health | dcdiag, repadmin, FSMO, SYSVOL / DFSR |
| 52 | Group Policy audit | HTML + CSV |
| 53 | Group Policy results for this machine | gpresult HTML + Group Policy errors |
| 54 | AD users - true last logon | Queries every DC. slow |
| 55 | Export BitLocker recovery keys from AD | **Secret output - handle securely** |
| 56 | Export LAPS passwords from AD (legacy + Windows LAPS) | **Secret output - handle securely** |
| 57 | Azure AD / Entra Connect Sync (ADSync) status | Offers to restart the service if it's stopped |
| 58 | Backup / VSS health | VSS writers, shadow storage, Windows Server Backup, backup agents |
| 59 | Folder permissions (ACL) export | |
| 60 | SharePoint / OneDrive migration check | Bad names, long paths, QuickBooks / Access / PST blockers. Optional auto-rename |

### I. Security / incident response / RMM
| # | Option | Notes |
|---|---|---|
| 61 | Security posture | AV, firewall, BitLocker, TPM, Secure Boot, SMBv1, RDP NLA, local admins, expiring certificates, activation |
| 62 | Sysinternals Autoruns - startup / persistence report | Unsigned items flagged. dl |
| 63 | Sysinternals Sigcheck - unsigned executables in user / ProgramData folders | dl |
| 64 | N-central compromise IOC hunt | |
| 65 | Unknown / adware program hunt | Prefetch, browser notification permissions, startup, scheduled tasks |
| 66 | Incident response log collection for a time window | 4688, PowerShell, Defender, WMI, logons. Zipped. slow |
| 67 | N-able Take Control / agent service diagnostics | Local or remote |

### J. Software / inventory / users
| # | Option | Notes |
|---|---|---|
| 68 | Installed software inventory | CSV |
| 69 | User profiles - size, last use | slow |
| 70 | Migration inventory (full machine discovery) | slow |
| 71 | Install provenance for a program (when / how / by whom) | |
| 72 | .NET / Node.js / Java / Python / VC++ runtime versions | |
| 73 | Citrix Workspace app - install state | |
| 74 | Time sync (w32time) check / resync | |

### K. Quick fixes
| # | Option |
|---|---|
| 75 | **[!]** Print spooler reset (clear stuck jobs) |
| 76 | **[!]** Microsoft Teams cache clear (classic + new) |
| 77 | **[!]** Office quick / online repair |
| 78 | **[!]** OneDrive reset |
| 79 | **[!]** Repair `.zip` association / reset default browser (per user) |
| 80 | **[!]** Remove bloatware (OEM + consumer Store apps) |
| 81 | **[!]** Power settings - never sleep / hibernate |

### L. Software deployment (downloads to `C:\temp\Tools`)
| # | Option | Notes |
|---|---|---|
| 82 | **[!]** Install common apps with Ninite | Chrome, Firefox, 7-Zip, Zoom, Notepad++ and more. dl |
| 83 | **[!]** Install apps silently from the vendor | Chrome / Firefox / Edge enterprise MSI, Zoom, Teams, OneDrive. dl |
| 84 | **[!]** Install Microsoft 365 Apps / Office (Office Deployment Tool) | Removes OEM Office first. Turns on Shared Computer Activation for RDS. dl |
| 85 | **[!]** Remove ALL existing Office | OEM preinstalls, extra languages, MSI Office. dl |

### M. Sysinternals / NirSoft / Microsoft tools (downloaded on demand)
| # | Option | Notes |
|---|---|---|
| 86 | NirSoft reports: BlueScreenView, AppCrashView, TurnedOnTimesView, LastActivityView, USBDeview, DriverView | HTML. dl |
| 87 | Sysinternals Handle - what is locking this file? | dl |
| 88 | Sysinternals ProcDump - dump a hung or crashing program | dl |
| 89 | Download & launch a GUI tool | Process Explorer, Process Monitor, Autoruns, TCPView, RAMMap, ShellExView, CurrPorts... dl |
| 90 | Microsoft TSS - official support log collection (SDP) | dl |


### N. Microsoft 365 (Exchange Online / Entra ID / Intune)
Each option runs in its own PowerShell window and signs in only to the services it needs, so Exchange Online and Microsoft Graph never conflict. Set the admin account / client tenant once with **91** and every option reuses it, including partner / GDAP access to client tenants. Graph calls use `Invoke-MgGraphRequest`, so most options only need the `Microsoft.Graph.Authentication` module.

| # | Option | Notes |
|---|---|---|
| 91 | Set admin account & client tenant | Admin UPN, `DelegatedOrganization` (Exchange) and tenant (Graph) |
| 92 | Install / repair PowerShell modules | EXO, Graph, SPO, Teams. Also installs EXO 3.7.1 side by side to fix the EXO + Graph "method not found" conflict |
| 93 | Compromised account **audit** | Rules, forwarding, sign-ins and risk, MFA methods, delegates, OAuth apps, recent sends, admin roles. HTML report |
| 94 | **[!]** **Contain** a compromised account | Step 1 (Entra): block sign-in, revoke sessions, reset password (cloud or on-prem AD), review MFA methods and app consents. Step 2 (Exchange): remove forwarding, disable malicious rules, lift the outbound-spam send restriction, check delegates |
| 95 | Inbox rules - one or all mailboxes | Flags forward / delete / hide rules, and uses the **audit log to show when each rule was created** (useful for proving a "new rules" alert is wrong) |
| 96 | Forwarding audit | Mailbox forwarding, external-forwarding rules, tenant auto-forward policy |
| 97 | Message trace | Sender / recipient / subject, up to 90 days (10-day chunks), delivery detail |
| 98 | Quarantine - find & release | Shows *why*: Spam / **Bulk (BCL)** / Phish / Malware. Never releases malware or high-confidence phish |
| 99 | Why is this sender filtered? | Mail flow rules, BCL vs SCL, Tenant Allow/Block List, impersonation exclusions. One-step fixes: allow sender, exclude domain from impersonation, add `BulkStamping=0` to a rule |
| 100 | SPF / DKIM / DMARC / MX check | Every accepted domain. Flags SPF lookup count, multiple SPF records, `+all`, DMARC `p=none`, missing or disabled M365 DKIM |
| 101 | Direct Send / connectors | Lists connectors. **[!]** Creates an IP-restricted connector for scanners and apps, and turns RejectDirectSend on or off |
| 102 | Top inbound / outbound domains | 90 days. Useful for pre-whitelisting top senders before a mail-filter cut-over |
| 103 | Mailbox permissions | Full Access / Send As / Send on Behalf |
| 104 | Mailbox sizes, quotas, archive | |
| 105 | Mobile devices for a user | Lost phone or iPad: last sync. **[!]** Account-only wipe, block, or full wipe |
| 106 | Unified audit log search | User / operation / free text (IP, file name...), up to 180 days |
| 107 | Sign-in log for a user | IPs, countries, legacy-protocol sign-ins (needs Entra ID P1) |
| 108 | MFA registration report | Admins without MFA flagged. Falls back to a per-user lookup without P1 |
| 109 | Stale / never-used / guest / disabled-but-licensed accounts | |
| 110 | Admin role members | Global Admin count check |
| 111 | License report | Subscriptions, who has what, licenses wasted on disabled users. Uses Microsoft's friendly-name list |
| 112 | **[!]** Assign / remove licenses | Users (sets usage location), group-based licensing, remove direct assignments |
| 113 | **[!]** Create a new user | Random temporary password, license, groups |
| 114 | App consent audit + admin-consent link | User-consent setting, admin-consent workflow, risky delegated permissions, a ready-made tenant-wide consent URL |
| 115 | App registration secrets / certificates expiring | Catches app secrets that break integrations (room panels, scanners, backup apps) when they expire |
| 116 | Intune devices | Compliance, stale devices, **BitLocker key missing in Entra** |
| 117 | OneDrive folder sharing / permissions for a user | Flags "Anyone" links |
| 118 | **[!]** Exclude a SharePoint site from a retention policy | Security & Compliance PowerShell |
| 119 | Tenant hardening audit | Legacy auth, forwarding, audit log, Defender policies, alert policies, admins |
| 120 | Security posture audit | 134 checks, license-aware, client-ready HTML + JSON |
| 121 | Remediation plan from a posture audit | Technical HTML (exact commands) + plain-English client summary |
| 122 | **[!]** Create an app registration for unattended automation | Certificate auth, admin consent granted in code |
| 123 | **[!]** THIS PC: force a Hybrid Entra ID join attempt | gpupdate + Automatic-Device-Join task, with troubleshooting hints |
| 124 | **[!]** THIS PC: back up the BitLocker recovery key to Entra ID | |

---

## Self-test

The self-test checks the toolkit itself on a real machine. It runs every **read-only** option with its default answers and **declines every change**.

```powershell
# Standard (about 5-10 minutes)
powershell -ExecutionPolicy Bypass -File .\SigmaDataSystems-ToolKit-v2.ps1 -SelfTest

# Full coverage (about 20-40 minutes, needs internet)
powershell -ExecutionPolicy Bypass -File .\SigmaDataSystems-ToolKit-v2.ps1 -SelfTest -IncludeSlow -IncludeDownloads
```

You can also type `T` in the menu.

Microsoft 365 options are not part of the self-test because they need you to sign in.

It checks that:

1. every built-in script unpacks and parses, and every data file is valid JSON,
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
+-- Crash\            BSOD / crash HTML reports
+-- EventLogs\        .evtx exports + error CSVs + .zip
+-- DiskSpace\        cleanup logs, largest-folder CSVs
+-- WindowsUpdate\    WU reset / repair logs
+-- Network\          connection lists, reachability logs, Wi-Fi reports
+-- HyperV\           host / guest / hang captures
+-- RDS\              registry backups before RDS changes
+-- AD\  ADHealth\    AD exports and DC health output
+-- Security\         posture, Autoruns, unsigned files, adware hunt
+-- IR\               incident response collections (.zip)
+-- NirSoft\          NirSoft HTML reports
+-- Software\         inventories, profiles, install provenance
+-- M365\             Microsoft 365 reports (rules, traces, quarantine, licenses, audits...)
+-- SelfTest\         self-test reports
+-- Tools\            downloaded tools (Sysinternals, NirSoft, Ninite, Office ODT, TSS, SetupDiag)
```

> **Secret output:** options 55 (BitLocker keys) and 56 (LAPS passwords) write secrets to disk.
> Options 94 and 113 show a new temporary password **once** on screen; it is never written to disk.
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
| Ookla Speedtest CLI | https://www.speedtest.net/apps/cli |
| Built-in speed test servers | https://speed.cloudflare.com/ |

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
+-- Help header + parameters
+-- Helpers          prompts, confirmations, output folders, self-test answers
+-- Tool runner      writes a built-in script to %TEMP%\SDSI-ToolKit_xxxx\ and runs it in its own
|                    Windows PowerShell process (a script that exits or errors can't kill the menu)
+-- Menu actions     one Invoke-* function per option
+-- Self-test
+-- Menu definition  sections + options (numbers are assigned automatically)
+-- Built-in tools   $Script:Payloads['Name'] = @' ...plain .ps1 text... '@
+-- Main loop
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


## Publishing to GitHub automatically

`tools/Publish-SDSIToolKit.ps1` keeps this repository in sync with the copy of the ToolKit in `C:\powershell`. When the ToolKit changes, it commits and pushes the new version, refreshes this README, and tags a release when the version number changes.

```powershell
# One time: asks for the repo URL, installs Git for Windows if needed, clones the repo
.\Publish-SDSIToolKit.ps1 -Setup
# First publish, run by hand so the GitHub sign-in window can open
.\Publish-SDSIToolKit.ps1
# From now on: publish automatically every 30 minutes and at logon
.\Publish-SDSIToolKit.ps1 -InstallSchedule
# Show what would be published, without publishing
.\Publish-SDSIToolKit.ps1 -DryRun
```

- **Only whitelisted files are published:** the ToolKit, README, LICENSE, CHANGELOG and the publisher itself. Nothing else in `C:\powershell` (client scripts, exports) can reach the repo.
- **Safety gate:** nothing is pushed if the ToolKit doesn't parse, or if a secret scan finds a password, client secret, token, private key or connection string. The same applies if it finds any word on your block-list (client names or domains).
- **README stays current:** the option count, the version line and the quick option index above are rebuilt from the script's own menu on every publish.
- **Commit messages** list which menu options were added or removed.
- **Sign-in:** Git Credential Manager stores your GitHub sign-in in Windows Credential Manager. No password or token is written in the script or its config.
- **Log:** `C:\temp\ToolKitPublish\publish.log`.

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
- **Microsoft 365 section (options 91-124)**: compromised-account audit and containment, inbox rules with audit-log timestamps, forwarding, message trace, quarantine release, sender filtering diagnosis (BCL vs SCL), SPF / DKIM / DMARC, Direct Send connectors, mobile device wipe, audit log, sign-ins, MFA, stale accounts, admin roles, licenses, new users, app consent, expiring app secrets, Intune / BitLocker escrow, OneDrive sharing, retention exclusions, tenant hardening, posture audit and remediation plan, app registration, hybrid join and BitLocker-to-Entra on the PC. Works for client tenants via GDAP.
- Section menu: section letters, direct option numbers, `ALL`, `B` back.
- **Wi-Fi deep diagnostics and live monitor**: channel overlap and congestion scoring, channel utilization, DFS, sticky-client / wrong-band detection, driver and power-saving checks, disconnect history, roam/drop/lag monitoring.
- **Public IP** lookup (also shown in the quick snapshot) and an **internet speed test** (built-in Cloudflare test or Ookla CLI, with history).
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
  - Section letters started at C instead of A.
  - Self-test crashed on menu options that don't start with `Invoke-`.

### v1.0 (2026-10)
- First release: 51 options built from the `C:\powershell` script library, with client-specific values removed.
- Banner, `C:\temp` output, event log export, RDP / RDS fixes, options drawn from past troubleshooting.
- Plain-text built-in scripts (no encoding) so EDRs don't flag it.

---

## Credits and third-party licenses

- **[Sigma Data Systems Inc.](https://sigmadatainc.com/)**: toolkit, menu, and most built-in scripts.
- **Built-in third-party scripts** (attribution kept in each script's header):
  - `Get-LAPSPasswords.ps1` - Karl Fosaaen / NetSPI, https://github.com/kfosaaen/Get-LAPSPasswords
  - `Export-Bitlockerkeys.ps1` - Ali Tajran, https://www.alitajran.com/
- **Ideas drawn from** (MIT-licensed, rewritten here): [bcwilhite/PendingReboot](https://github.com/bcwilhite/PendingReboot), [MahmoudNoureddine/SysAdmin-PS-Toolkit](https://github.com/MahmoudNoureddine/SysAdmin-PS-Toolkit), [steviecoaster/PSSysadminToolkit](https://github.com/steviecoaster/PSSysadminToolkit), [ruudmens/LazyAdmin](https://github.com/ruudmens/LazyAdmin).
- **Microsoft 365**: the security posture audit's check library (`data/all-checks.json`) is modeled on SaaS posture-management checks and maintained by Sigma Data Systems. Microsoft's licensing friendly-name list is downloaded at run time from download.microsoft.com.
- **Downloaded tools** keep their own licenses and are not redistributed here:
  - Sysinternals - Microsoft license terms: https://learn.microsoft.com/sysinternals/license-terms. Command-line tools run with `-accepteula` after you confirm.
  - NirSoft - freeware by Nir Sofer: https://www.nirsoft.net
  - Ninite, Ookla Speedtest CLI (its license and privacy terms are accepted when you run it), Microsoft TSS / SetupDiag / Office Deployment Tool - their vendors' terms apply.

---

## Disclaimer

This toolkit is provided **as is**, without warranty. Options marked `[!]` change the system: uninstalling Office, resetting the network stack, clearing caches, deleting files. Read each prompt before typing `YES`, and test on a non-production machine first. Exported BitLocker keys and LAPS passwords are sensitive. Store them securely and delete them from the endpoint when you're done.

---

**Sigma Data Systems Inc.** | https://sigmadatainc.com/
