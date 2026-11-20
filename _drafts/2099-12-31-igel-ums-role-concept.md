---
title: "IGEL UMS Role Concept: Administrators, Operators and Service Desk without the Deny Trap"
date: 2099-12-31 09:00:00 +0200
author: robert
categories: ["IGEL", "Best Practices"]
tags: ["igel", "igel-ums", "rbac", "least-privilege", "active-directory", "entra-id", "secure-terminal", "shadowing"]
description: "IGEL UMS has no built-in roles. Here is a three-tier role concept built from imported groups with Allow and not-set only, the full permission matrix, and the traps around Deny, Remote access and logging."
image:
  path: /assets/img/posts/og-igel-ums-role-concept.png
  alt: "IGEL UMS Role Concept: Administrators, Operators and Service Desk without the Deny Trap"
---

<!-- DRAFT NOTES FOR ROBERT, delete before publishing
     1. Intro: the first paragraph is neutral on purpose. Replace it with the real trigger (which kind of customer, what the starting point was).
     2. Lab-test list at the end: every item you confirm can move from "Test Before You Rely on It" into the body as a fact.
     3. OG image og-igel-ums-role-concept.png does not exist yet.
     4. Statements marked (agent) in the review file were not re-read by Claude on the live KB page. -->

The IGEL UMS has no role model. There is no "Helpdesk" or "Operator" role to tick, only single rights on accounts, groups and tree objects. Every role concept is therefore self-built, and most of the ones I see grew over the years: local accounts, a few Deny entries nobody remembers, and a superuser password that half the team knows.

This post is the concept I use as a starting point: three tiers, managed through groups, built so that it stays predictable when somebody is a member of two groups.

> **Quick answer**
>
> Import three groups (Administrators, Operators, Service Desk) and build every role from **Allow** and **not set** only. Never use Deny as a design tool. Deny always wins, across groups and down the tree, and it cannot be taken back further down.
{: .prompt-tip }

**Applies to**

- IGEL UMS 12.08.100 or later, UMS Console and UMS Web App
- Checked against the documentation of UMS 12.15.100
- Groups imported from Active Directory, or mapped from a cloud IdP such as Entra ID

## Four Layers, No Roles

A role in the UMS is the sum of four things:

1. **The UMS superuser.** Created during installation, always full access, cannot be restricted. It is not the database user, that is a separate account.
2. **General administrator rights.** Global switches per account or group under `System > Administrator accounts`. Each one is not set, Allow or Deny.
3. **Object-related access rights.** ACLs on the structure tree, set with right-click `> Access control`, inherited from a directory to its contents.
4. **Access rights in the UMS Administration area.** Browse, Read, Write and Access Control per administration node.

The Web App and the Console share the same permissions. Three general rights exist only for the Web App: App Management, Delete Log Messages and Device Bulk Action.

## Why Deny Is a Trap

IGEL documents three precedence rules, and together they decide the design:

- A right granted directly on an account beats a right that comes from a group.
- Deny beats Allow. Always, also between groups, and even against a direct Allow.
- A Deny on a directory or node applies to everything below it and cannot be withdrawn there.

Now picture a colleague who moves from the service desk to operations and sits in both groups for a while. If the Service Desk group carries a single Deny, he loses that right as an Operator too, and the Effective Rights dialog is the only place that tells you why.

With Allow and not-set only, group memberships simply add up. That is the whole trick. I use Deny only for a deliberate, documented exception, never to build a role.

## The Three Tiers

| Role | Group | Purpose |
|---|---|---|
| **Administrators** | `IGEL-UMS-Admins` | Everything: accounts, licensing, firmware, server configuration |
| **Operators** | `IGEL-UMS-Operators` | Daily device and profile work, rollouts |
| **Service Desk** | `IGEL-UMS-ServiceDesk` | Read devices, shadow, reboot, send a message |

Membership lives in the directory, the rights live on the group in the UMS.

### General Administrator Rights

| Right | Administrators | Operators | Service Desk |
|---|---|---|---|
| Administrator accounts | Allow | not set | not set |
| Firmware management | Allow | not set | not set |
| License management | Allow | not set | not set |
| Logging (events and messages) | Allow | Allow | not set |
| WebDAV access (ums-filetransfer) | Allow | not set | not set |
| Scan for devices | Allow | Allow | not set |
| Host Assignment (Jobs) | Allow | not set | not set |
| Public Holidays Management | Allow | not set | not set |
| SQL Console | Allow | not set | not set |
| HA Health Check | Allow | not set | not set |
| Save support information | Allow | not set | not set |
| App Management (Web App) | Allow | Allow | not set |
| Delete Log Messages (Web App) | Allow | not set | not set |
| Device Bulk Action (Web App) | Allow | Allow | not set |

> **Administrator accounts** is full control in disguise. Whoever can edit accounts can grant himself everything else. IGEL says the same: give it only to users who should have full access.
{: .prompt-warning }

Two more rights deserve a second look. The **SQL Console** can damage the database, so consider leaving it not set even for Administrators and granting it only when needed. **App Management** decides which apps reach your OS 12 endpoints. If that decision belongs to a change board, keep it in the admin tier.

**Device Bulk Action** only limits the Web App. Without it a user acts on one device at a time there, the Console is not restricted by it.

### Devices

Set the ACL on the Devices root and let it inherit.

| Permission | Administrators | Operators | Service Desk |
|---|---|---|---|
| Browse, Read | Allow | Allow | Allow |
| Move, Write, Edit configuration, Edit System Information | Allow | Allow | not set |
| Access Control | Allow | not set | not set |
| Remote access | Allow | Allow | Allow |
| Send message | Allow | Allow | Allow |
| Assign (priority) profile, Assign file, Assign CIC, Assign Template Value / Value Group | Allow | Allow | not set |
| Assign Base System / Firmware Update | Allow | Allow | not set |
| Assign Shared Workplace User | Allow | Allow, if you use SWP | not set |
| Reboot, Suspend, Shutdown, Wake up | Allow | Allow | Allow |
| Update | Allow | Allow | not set |
| Reset | Allow | not set | not set |
| File transfer | Allow | Allow | not set |
| Generic command | Allow | not set | not set |
| UMS -> Device, Device -> UMS | Allow | Allow | not set |

Three details from the rights list that are easy to miss:

- **Assign (priority) profile** is also the right for assigning apps to OS 12 devices, because apps are assigned through profiles.
- **Assign Base System / Firmware Update** decides which version a device gets. **Update** only executes it. If you want separation of duties for rollouts, give Operators Update and keep the Assign right with the Administrators.
- **File transfer** only pushes a file that is already assigned. Assigning it needs **Assign file**.

### Other Tree Roots

| Root | Administrators | Operators | Service Desk |
|---|---|---|---|
| Profiles | All | Browse, Read, Write, Move, Assign | Browse, Read |
| Master / Priority Profiles | All | Browse, Read | not set |
| Firmware Customizations / CIC | All | Browse, Read, Write, Assign | not set |
| Files | All | Browse, Read | not set |
| Universal Firmware Update | All | Browse, Read, Assign | not set |
| Views | All | Browse, Read, Write | Browse, Read |
| Jobs | All | Browse, Read, Write | not set |

Service Desk needs Read on Profiles to see what is assigned to a device. Prepare a few views for them, such as all devices of a site or devices offline for more than 24 hours.

### UMS Administration Area

Administrators get Browse, Read, Write and Access Control on all nodes. Operators and Service Desk get nothing.

That has a side effect in the Web App, because some of its settings pages are tied to administration nodes:

| Administration node | Web App pages |
|---|---|
| Server Network Settings | Apps > Settings (UMS as an Update Proxy, App Portal, Automatic Updates), Network > Settings > UMS Network Nickname, Search > Settings |
| UMS Features | Apps > Settings > UMS as an Update Proxy, Network > Settings > UMS Features |
| First-authentication Keys | Devices > Settings > First Authentication Keys |

Operators can manage apps and profiles under this concept, but not these settings. If they should own the App Portal source or automatic updates, grant them Read and Write on exactly those nodes.

## The Remote Access Problem

There is one right called **Remote access**, and it covers VNC shadowing and the secure terminal. You cannot allow shadowing and withhold the terminal through ACLs.

For a service desk that is a real least-privilege problem. Shadowing shows the user's screen, ideally with consent. The secure terminal is a shell on the device, and from there the way to root is short, as I showed in the [USB redirection post](/posts/igel-citrix-usb-redirection/).

It got more relevant with UMS 12.15.100. Until then the secure terminal needed the Console. Now the Web App offers secure terminal sessions for IGEL OS 12 devices, so a browser is enough.

The separation has to happen on the feature, not on the permission:

- Leave `UMS Administration > Global Configuration > Remote Access > Enable secure terminal globally` off. That is the default.
- Keep the secure terminal disabled by profile on the devices in Service Desk scope, and enable it only where the Operators need it.

Shadowing has its own device-side settings. The device profile must allow it, and the consent prompt for the user is configured there as well. On OS 12, shadowing through the UMS always runs encrypted over the Unified Protocol. On OS 11, secure VNC is off by default and must be enabled per device or globally.

## Where the Groups Come From

### Active Directory

1. Link the directory under `UMS Administration > Global Configuration > Active Directory / LDAP`. Use LDAPS.
2. Enter a service user on the connection. Since UMS 12.08.100 this is mandatory, the UMS uses it to refresh user data. Read access to accounts and group memberships is enough.
3. Import the three groups under `System > Administrator accounts > Import`.
4. Set the rights on the groups.

An import cannot be undone, and an imported account or group is not removed when it disappears from the directory. Put the UMS on your leaver checklist.

### Entra ID or Another Cloud IdP

Since UMS 12.08.100 the Console and the Web App share one login, and that login supports cloud identity providers such as Entra ID, Okta and Ping Identity, including MFA. You map an IdP role to a UMS group, in the Console under `System > Administrator accounts > IDP Roles` or in the Web App under `User Management > Identity Provider Roles`. A user who signs in with that role lands in the group and gets its rights.

The role concept stays exactly the same. Only the source of the membership changes.

I recommend this route at least for the Administrators. I found no MFA of its own in the UMS documentation for local or AD-imported accounts, so the IdP is how admin logins get MFA and Conditional Access. With Entra ID it also opens the door to just-in-time membership through PIM.

The requirements are strict about names: the UMS web certificate must contain every address that admins use to log in, FQDN, short name and IP address, and the same addresses must be registered as redirect URIs.

## The Superuser Is Your Break-Glass Account

The superuser is often confused with the database user. They are two accounts. The Web App rejects the login data of the database user, the superuser works in both the Console and the Web App.

One detail makes it the natural break-glass account: a local login as superuser with `localhost` as the server address is always possible, also when the IdP or the directory is down.

Treat it that way. Put the password in a vault, do not use it for daily work, and change it under `UMS Administrator > Datasource` when somebody who knew it leaves. In an HA environment, expect temporary issues while the servers exchange files after the change.

## Make the Audit Trail Attributable

A role concept without a usable log does not pass an audit. The defaults do not help here:

- Enable logging under `UMS Administration > Global Configuration > Logging` and make sure **Log administrator data** is on. Without it, entries carry no admin name.
- Under `Global Configuration > Remote Access`, enable **Log user for secure VNC** and **Log user for secure terminal**. Both are off by default. Sessions are logged either way, but without the name of the admin who opened them.
- Console and Web App log separately. Actions done in the Web App do not show up in the Console log. An audit has to cover both.
- For a SIEM, activate security logging. The UMS then writes dedicated security log files that a log collector can pick up.

> These logs contain personal data of your administrators and, for shadowing, relate to your users. In the DACH region, clear them with data protection and the works council before you switch them on.
{: .prompt-info }

## Beyond the Three Tiers

Three tiers cover least privilege inside the UMS. For an environment with ISO 27001, BSI IT-Grundschutz or CIS requirements, I add these points:

- **Named admin accounts.** No shared accounts, and a dedicated admin account separate from the daily one.
- **A defined access path.** IGEL's own Grundschutz guide recommends limiting Console and Web App access to a designated admin host, with MFA at that host or at the IdP.
- **Scoping.** For several sites or customers, multiply the tiers by site and set the ACL on the site directory instead of the root. An ACL on `/Devices/SiteA` scopes the role to Site A.
- **Access reviews.** Review the group memberships and the imported objects in the UMS on a schedule.
- **New tree roots.** A new top-level directory does not inherit from its siblings. Keep the ACL sets in a runbook.

## Test Before You Rely on It

Check every role with a test user and finish with **Effective Rights** (`System > Administrator accounts > Effective Rights`, or in the Access control dialog of an object). It shows the resulting rights and where each one comes from.

Two things cost time during testing:

- To see devices in the Web App, a group needs Read on the device **directory**. Rights on the devices alone are not enough.
- The Web App does not apply permission changes to a running session. The test user must log out and log in again.

The IGEL documentation is silent on a few points. I would not publish a design to a customer without testing them on their UMS version:

- Are nested AD groups resolved for imported groups?
- What happens to a running session when the AD user is disabled?
- Does deleting an object need Write on the object and on its parent directory?
- Can an Operator with App Management, but without Firmware management, import apps from the App Portal?
- Which right controls the new IGEL Managed Hypervisor area of the Web App in 12.15.100? It contains wipe and reimage actions for VMs.

## Related

- [USB Devices from IGEL OS into Citrix: Optimized First, Generic Last](/posts/igel-citrix-usb-redirection/) - uses the secure terminal to read VID and PID on the device, which is exactly the access the Remote access right hands to the Service Desk

## References

- [IGEL KB - Administrator Accounts in the IGEL UMS](https://kb.igel.com/en/universal-management-suite/current/how-to-create-administrator-accounts-in-the-igel-u)
- [IGEL KB - Effective Rights in IGEL UMS](https://kb.igel.com/en/universal-management-suite/current/access-rights)
- [IGEL KB - General Administrator Rights in IGEL UMS](https://kb.igel.com/en/universal-management-suite/current/general-administrator-rights-in-igel-ums)
- [IGEL KB - Object-Related Access Rights](https://kb.igel.com/en/universal-management-suite/current/object-related-access-rights)
- [IGEL KB - Available Rights](https://kb.igel.com/en/universal-management-suite/current/available-rights)
- [IGEL KB - Access Rights in the Administration Area](https://kb.igel.com/en/universal-management-suite/current/access-rights-in-the-administration-area)
- [IGEL KB - Importing Active Directory Users](https://kb.igel.com/en/universal-management-suite/current/importing-active-directory-users)
- [IGEL KB - Important Information for the IGEL UMS Web App](https://kb.igel.com/en/universal-management-suite/current/important-information-for-the-igel-ums-web-app)
- [IGEL KB - Feature Matrix: UMS Web App vs. UMS Console](https://kb.igel.com/en/universal-management-suite/current/feature-matrix-ums-web-app-vs-ums-console)
- [IGEL KB - New Features IGEL UMS 12.15.100](https://kb.igel.com/en/universal-management-suite/current/new-features-igel-ums-12-15-100)
- [IGEL KB - UMS Login Requirements](https://kb.igel.com/en/universal-management-suite/current/ums-login-requirements)
- [IGEL KB - How to Set Up UMS Login with SSO](https://kb.igel.com/en/universal-management-suite/current/how-to-set-up-ums-login-with-sso)
- [IGEL KB - Changing the UMS Superuser](https://kb.igel.com/en/universal-management-suite/current/changing-the-ums-superuser)
- [IGEL KB - Remote Access Configuration in IGEL UMS](https://kb.igel.com/en/universal-management-suite/current/remote-access-configuration-in-igel-ums)
- [IGEL KB - Remote Security Logging in IGEL](https://kb.igel.com/en/universal-management-suite/12.08.100/remote-security-logging-in-igel)
- [IGEL KB - Standard-Anforderungen von OPS.1.1.2 (IT-Grundschutz guide)](https://kb.igel.com/en/security-safety/current/standard-anforderungen-von-ops-1-1-2)
- [CIS Controls v8.1 - Control 6, Access Control Management](https://cas.docs.cisecurity.org/en/latest/source/Controls6/)
- [Microsoft Learn - Best practices for Microsoft Entra roles](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/best-practices)

---

<br>

*Checked against the IGEL documentation for UMS 12.15.100 in November 2026.*

<br>

*How do you separate shadowing from the secure terminal for your service desk? Reach out on [LinkedIn](https://www.linkedin.com/in/robertmagasi/).*

<br>

> *This post was written with assistance from Claude (Anthropic) as a drafting and editing tool. All technical content, solutions, and recommendations reflect my own hands-on experience and professional judgment.*
