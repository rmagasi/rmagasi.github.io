---
title: "Renewing your Citrix certificate? Don't forget the Cloud Connectors"
date: 2026-08-07 09:00:00 +0200
author: robert
categories: ["Citrix"]
tags: ["citrix-cloud", "cloud-connector", "certificates", "ssl", "netsh", "storefront", "powershell"]
description: "StoreFront and NetScaler get renewed. The Cloud Connectors hold a bound certificate too, and netsh will refuse to add it a second time."
image:
  path: /assets/img/posts/og-cloud-connector-ssl-renewal.png
  alt: "Renewing SSL certificates on Citrix Cloud Connectors"
---

Certificate renewal season has a checklist, and in most Citrix environments that checklist has two entries: StoreFront and NetScaler. Both get updated, both get verified, and the change record gets closed. Then a few weeks later launches start failing through Gateway and nobody can explain why.

The Cloud Connectors hold a certificate too.

## Why the Cloud Connector has a certificate at all

When you enable HTTPS on a Cloud Connector, you bind a certificate to port 443 so StoreFront and NetScaler Gateway can reach the XML service over TLS instead of plain HTTP. Citrix documents this as the recommended configuration, not an option ([Cloud Connector Installation, HTTPS Configuration](https://docs.citrix.com/en-us/citrix-cloud/citrix-cloud-resource-locations/citrix-cloud-connector/installation.html#https-configuration)).

The part people forget: in a Citrix Cloud deployment **the Cloud Connectors are your STAs**. If your StoreFront Secure Ticket Authority URLs start with `https://`, that TLS terminates on a Cloud Connector, using a certificate that expires like any other.

![StoreFront Secure Ticket Authority URLs pointing at the Cloud Connectors over HTTPS](/assets/img/posts/cloud-connector-ssl-renewal-sta.png){: w="800" }
_The STA URLs are Cloud Connector FQDNs, over HTTPS_

## Find what is bound today

The binding is not in IIS and it is not in Citrix Studio. It lives in the HTTP.sys store, so `netsh` is the only place you will see it:

```powershell
netsh http show sslcert ipport=0.0.0.0:443
```

Note the **Application ID**. Then pull the thumbprint of the new certificate after you have imported it:

```powershell
Get-ChildItem -Path Cert:\LocalMachine\My |
    Select-Object FriendlyName, Thumbprint, Subject, NotBefore, NotAfter
```

![netsh http show sslcert output next to the certificate thumbprint in the MMC](/assets/img/posts/cloud-connector-ssl-renewal-netsh.png){: w="800" }
_The Certificate Hash in the binding is the thumbprint from the MMC_

## Update the binding, do not add it

This is where most renewals go wrong. Running `netsh http add sslcert` on a port that already has a binding fails with:

```text
SSL Certificate add failed, Error: 183
Cannot create a file when that file already exists
```

Citrix documents deleting the binding first, then adding it back ([CTX331603](https://support.citrix.com/external/article/CTX331603/error-while-renewing-certificate-on-clou.html)). That works, but it leaves the connector with no binding at all between the two commands, and it forces you to supply the Application ID by hand. Use `update` instead:

```powershell
netsh http update sslcert ipport=0.0.0.0:443 `
    certhash=<thumbprint-of-the-new-certificate> `
    appid={<application-id-from-the-existing-binding>}
```

> The Application ID is **not** a constant. It is generated per installation, which is why the command above carries a placeholder. Read yours out of the existing binding. Never copy a GUID from a blog post or a KB article, several of them publish one.
{: .prompt-warning }

## Verify

Read the binding back and check the Certificate Hash against the new thumbprint:

```powershell
netsh http show sslcert ipport=0.0.0.0:443
```

No service restart is needed. HTTP.sys picks up the new binding immediately. Repeat on every Cloud Connector in the resource location, they each hold their own binding.

## Add it to the checklist

Three places, not two:

| Component | Where the certificate lives |
|---|---|
| StoreFront | IIS binding |
| NetScaler Gateway | Certificate bound to the vServer |
| **Cloud Connector** | **`netsh http` binding on port 443** |

---

<br>

*Renewing certificates across a Citrix estate and hitting something this article missed? Reach out on [LinkedIn](https://www.linkedin.com/in/robertmagasi/).*

<br>

> *This post was written with assistance from Claude (Anthropic) as a drafting and editing tool. All technical content, solutions, and recommendations reflect my own hands-on experience and professional judgment.*
