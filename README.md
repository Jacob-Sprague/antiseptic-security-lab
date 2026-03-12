# Antiseptic Security — IAM Home Lab

**A hybrid identity lab environment built for a fictional cybersecurity firm, designed to demonstrate enterprise IAM architecture, RBAC design, PowerShell automation, and cloud identity integration.**

The name *Antiseptic* comes from its medical definition — an antimicrobial substance that destroys or inhibits microorganisms and prevents infection. The metaphor maps directly to cybersecurity: eliminate threats before they spread, protect living systems without disrupting the host.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        HOST MACHINE                             │
│                   Windows 11 / 32GB RAM                         │
│                       VirtualBox                                │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              VirtualBox Internal Network                   │  │
│  │                    (intnet)                                │  │
│  │                                                           │  │
│  │   ┌─────────────┐   ┌──────────────┐  ┌──────────────┐   │  │
│  │   │    DC01      │   │   Client 1   │  │   Client 2   │   │  │
│  │   │ Win Server   │   │  Win 10/11   │  │  Win 10/11   │   │  │
│  │   │   2022       │   │              │  │              │   │  │
│  │   │             │   │  (Planned)   │  │  (Planned)   │   │  │
│  │   │ AD DS / DNS  │   │              │  │              │   │  │
│  │   │ 192.168.     │   │              │  │              │   │  │
│  │   │   252.10     │   │              │  │              │   │  │
│  │   └─────────────┘   └──────────────┘  └──────────────┘   │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│         ┌──────────────────────────────────────┐                │
│         │     Future: Azure AD Connect         │                │
│         │     Sync to Entra ID Tenant          │                │
│         │     Conditional Access / MFA / PIM   │                │
│         └──────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Environment Specs

| Component | Details |
|---|---|
| Hypervisor | Oracle VirtualBox |
| Domain Controller | DC01 — Windows Server 2022 (Evaluation) |
| RAM | 6 GB allocated |
| CPUs | 2 |
| Storage | 50 GB VDI |
| Network | VirtualBox Internal Network (intnet) |
| IP Address | 192.168.252.10/24 (static) |
| DNS | 127.0.0.1 (self-referencing) |
| Domain | antisepticsec.local |
| NetBIOS | ANTISEPTIC |
| Forest Functional Level | Windows 2016 |
| Domain Functional Level | Windows 2016 |

---

## Organizational Unit Structure

The OU hierarchy is designed to mirror a realistic mid-size cybersecurity firm. Each department maps to a function within a security organization, with SOC broken into tiered sub-OUs to reflect the distinct access levels between analyst tiers.

```
antisepticsec.local
└── Antiseptic Security
    ├── SOC
    │   ├── SOC-L1          (Tier 1 Analysts — monitoring and triage)
    │   ├── SOC-L2          (Tier 2 Analysts — investigation and escalation)
    │   └── SOC-L3-IR       (Tier 3 / Incident Response — containment and remediation)
    ├── Red Team             (Offensive security and adversary simulation)
    ├── Threat Intelligence  (Threat research and indicator analysis)
    ├── IAM                  (Identity and Access Management engineering)
    ├── GRC                  (Governance, Risk, and Compliance)
    ├── Security Engineering (Security tooling and DevSecOps)
    ├── IT Operations        (Infrastructure and systems administration)
    ├── Executive            (C-suite leadership)
    ├── HR                   (Human Resources)
    ├── Finance              (Finance and Accounting)
    ├── Workstations         (Computer objects — future use)
    └── Service Accounts     (Non-human accounts — future use)
```

All OUs are protected from accidental deletion.

---

## RBAC Model

Access control follows a layered group model. **Department groups** define who someone is. **Resource groups** define what they can access. Users are assigned to both, and permissions are always granted to groups — never directly to individual users.

### Department Groups

| Group | OU | Description |
|---|---|---|
| SG-SOC-L1 | SOC-L1 | SOC Level 1 Analysts |
| SG-SOC-L2 | SOC-L2 | SOC Level 2 Analysts |
| SG-SOC-L3-IR | SOC-L3-IR | SOC Level 3 and Incident Response |
| SG-RedTeam | Red Team | Red Team Operators |
| SG-ThreatIntel | Threat Intelligence | Threat Intelligence Analysts |
| SG-IAM | IAM | Identity and Access Management |
| SG-GRC | GRC | Governance Risk and Compliance |
| SG-SecEng | Security Engineering | Security Engineering and DevSecOps |
| SG-ITOps | IT Operations | IT Operations and Infrastructure |
| SG-Executive | Executive | Executive Leadership |
| SG-HR | HR | Human Resources |
| SG-Finance | Finance | Finance and Accounting |

### Resource and Role Groups

| Group | Purpose | Assigned To |
|---|---|---|
| SG-AllEmployees | All active employees | Every user |
| SG-Managers | Department managers and team leads | Team leads and above |
| SG-SIEM-ReadOnly | Read-only access to SIEM console | SOC L1, SOC L2, Threat Intel |
| SG-SIEM-Admin | Full admin access to SIEM platform | SOC L3/IR, CISO |
| SG-VPN-Access | Remote VPN access | All employees |
| SG-PrivilegedAccess | Elevated privileges for admin tasks | SOC L3/IR, Red Team, IAM, SecEng, IT Ops |

### Design Decisions

- **SOC L1 analysts get SIEM-ReadOnly, not SIEM-Admin.** L1 monitors and triages — they don't need to modify SIEM configurations or detection rules. L3/IR gets admin access because incident response requires full platform control.
- **Red Team gets PrivilegedAccess.** Offensive operators need elevated system access to simulate real adversaries. Without it, the Red Team can't perform realistic engagements.
- **Executives do not get PrivilegedAccess.** Seniority does not equal technical access. The CEO doesn't need admin rights to domain infrastructure. The CISO gets SIEM-Admin because that role requires visibility into security operations.
- **HR and Finance get no elevated access.** These departments interact with business systems, not security infrastructure. Their access is scoped to department-level resources only.
- **SG-AllEmployees exists for baseline policies.** Company-wide resources like the intranet, shared drives, or all-hands communications can be granted to this single group rather than managing 12 department groups individually.

---

## User Population

30 employees provisioned via PowerShell bulk script from CSV. All accounts are enabled with a default password and forced change at first logon.

| Department | Headcount | Titles |
|---|---|---|
| SOC - L1 | 4 | SOC Analyst I |
| SOC - L2 | 3 | SOC Analyst II |
| SOC - L3/IR | 2 | Senior Incident Responder, IR Lead |
| Red Team | 2 | Red Team Operator |
| Threat Intelligence | 2 | Threat Intelligence Analyst, Senior Threat Analyst |
| IAM | 2 | IAM Engineer, IAM Analyst |
| GRC | 2 | GRC Analyst, Compliance Manager |
| Security Engineering | 3 | Security Engineer, DevSecOps Engineer, Senior Security Engineer |
| IT Operations | 3 | Systems Administrator, Network Administrator, IT Operations Manager |
| Executive | 3 | CEO, CTO, CISO |
| HR | 2 | HR Manager, HR Coordinator |
| Finance | 2 | Finance Manager, Financial Analyst |

Username format: first initial + last name (e.g., `mchen`, `psharma`).

---

## Provisioning Automation

User accounts were created using a PowerShell bulk provisioning script (`Provision-Users.ps1`) that reads from a CSV roster (`employees.csv`).

**What the script does:**
1. Imports the employee CSV with name, department, title, OU, and group assignments.
2. For each employee, constructs the correct OU path (including nested SOC sub-OUs).
3. Creates the AD user account with all attributes — display name, UPN, title, department.
4. Sets a default password with forced change at first logon.
5. Enables the account.
6. Assigns all specified security group memberships.
7. Checks for existing accounts before creating (safe to re-run).
8. Outputs color-coded results with a final summary.

Both files are in the [`/scripts`](scripts/) directory.

---

## Build Progress

- [x] **Phase 1** — Domain Controller setup (DC01, antisepticsec.local, static IP, DNS)
- [x] **Phase 2** — OU structure, security groups, bulk user provisioning
- [ ] **Phase 3** — Group Policy Objects (password policy, lockout, department restrictions)
- [ ] **Phase 4** — NTFS permissions and shared folder structure
- [ ] **Phase 5** — User lifecycle workflows and SOPs
- [ ] **Phase 6** — PowerShell reporting and audit scripts
- [ ] **Phase 7** — Azure AD Connect hybrid sync to Entra ID tenant
- [ ] **Phase 8** — Entra ID Conditional Access, MFA, PIM
- [ ] **Phase 9** — Intune compliance policies
- [ ] **Phase 10** — SIEM integration (Microsoft Sentinel or Splunk)

---

## Tools Used

- Windows Server 2022
- Active Directory Domain Services
- DNS Server
- PowerShell
- Oracle VirtualBox

---

## Author

**Jacob Sprague**
[GitHub](https://github.com/Jacob-Sprague) · CompTIA Security+ Certified
