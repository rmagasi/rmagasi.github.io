---
title: "USB Devices from IGEL OS into Citrix: Optimized First, Generic Last"
date: 2099-12-31 09:00:00 +0200
author: robert
categories: ["IGEL", "Best Practices"]
tags: ["igel", "citrix", "igel-os-12", "citrix-workspace-app", "usb-redirection", "generic-usb", "client-drive-mapping", "hdx"]
description: "IGEL calls it Native USB Redirection, Citrix calls it Generic USB. Here is when to use it, when client drive mapping or an optimized HDX channel is the better choice, and how both sides must be configured."
image:
  path: /assets/img/posts/og-igel-citrix-usb-redirection.png
  alt: "USB Devices from IGEL OS into Citrix: Optimized First, Generic Last"
---

In my daily work I see a lot of different EUC environments, managed by customers, partners or service providers. I like that part of the job, because every environment solves the same problems in its own way. One scenario comes up again and again: USB redirection from a thin client into the Citrix session.

When I first had to dig into it, the right configuration was anything but obvious. IGEL and Citrix use different names for the same thing, the settings live in several places, and every device type, from a USB stick to a dictation microphone, needs its own approach. IGEL's **Native USB Redirection** is Citrix's **Generic USB redirection**, to name just one example.

For the last one or two years I did not work much with IGEL thin clients. Now I have IGEL customers again, and IGEL OS 12 is the new standard, so it was time for a refresh. Not much has changed in that sense. It is still not obvious how to configure it correctly. IGEL and Citrix both have plenty of material in their knowledge bases, but it is spread over many articles. Since I had to refresh my knowledge anyway, I tried to put the pieces together in one post. Maybe it saves someone else the same search.

> **Quick answer**
>
> Use the optimized HDX path for every device that has one: client drive mapping for storage, HDX audio, webcam, smart card, printing, SANE scanning, COM port mapping and vendor virtual channels. Use Native (Generic) USB redirection only for devices without a channel, allow them one by one by VID/PID, and install the driver in the VDA image.
{: .prompt-tip }

## Optimized vs Generic

The difference decides where the driver lives and who owns the device.

| | Optimized (HDX virtual channel) | Generic (IGEL: Native USB Redirection) |
|---|---|---|
| Driver | On the IGEL endpoint | On the VDA, in the Citrix Worker image |
| Device on the endpoint | Stays usable locally | Taken away from the endpoint |
| Bandwidth | Built for WAN | Chatty, isochronous devices only on low-latency LAN |
| Configuration | Usually on by default | Deny by default on both sides, allow per device |

With Generic, the VDA sees the raw USB device. If the Worker image has no driver for it, the device shows up as **unknown** in Device Manager inside the session. That is the first thing to check when a redirected device "does not work".

> The policy **Client USB device optimization rules** does not switch a device to an optimized channel. It only applies to devices that are already redirected over Generic USB and tells the VDA how to handle their data: `Mode=00000002` (interactive) keeps 3D mice and pen tablets responsive under latency, `Mode=00000004` (capture) records every pen point of a signature pad. Without a rule nothing is optimized.
{: .prompt-warning }

## The Decision Path

![Decision flow for USB devices from IGEL OS into a Citrix session: mass storage to client drive mapping, devices with an optimized channel to HDX, composite devices to splitting, everything else to generic USB redirection](/assets/img/posts/igel-citrix-usb-redirection-decision.png){: w="900" }

Four questions, in this order:

1. **Is it mass storage?** Use client drive mapping.
2. **Is there an optimized or vendor channel?** Use it.
3. **Is it a composite device with audio or mouse interfaces?** Split it and redirect only the interfaces that need the VDA.
4. **Everything else** goes through Generic USB redirection.

## Per Device Class

| Device | Preferred | Fallback |
|---|---|---|
| USB stick, disk | Client drive mapping | Generic, only for safe removal in the session or hardware-encrypted sticks |
| Headset, microphone | HDX audio | None, Generic USB audio is blocked on multi-session VDAs by default |
| Webcam | HDX webcam compression or UC optimization | Generic as a whole device, LAN only |
| Smart card reader | Smart card virtual channel | None, Generic is not supported on Server VDA |
| Printer | Client printer mapping with the Universal Print Driver | Generic |
| Scanner | SANE redirection, TWAIN redirection is Windows-client only | Generic, poor scan quality |
| Signature pad | Vendor virtual channel (signotec, StepOver) | Generic with capture mode |
| Dictation | Vendor channel or composite split | Whole device Generic, loses local audio |
| Serial device | COM port mapping | None, virtual COM ports do not work over Generic |
| 3D mouse | Generic by VID/PID, Windows 10/11 VDA only | - |

IGEL's own guidance adds a hard rule: never redirect whole classes such as Audio, Bluetooth, HID, Hubs, Smart Card, Video input or Wireless. Redirect a single device from them by VID/PID instead.

## USB Sticks: Client Drive Mapping

Client drive mapping keeps the stick on the endpoint and shows it in the session as `T on IGEL-123456789`. No driver on the VDA, no USB traffic.

1. On the VDA, keep **Client drive redirection**, **Client removable drives** and **Auto connect client drives** on Allowed. They are by default.
2. In IGEL OS 12, enable **Client Drive Mapping** under `Apps > Citrix > Global Settings`. It is off by default in the IGEL Citrix app, even though the VDA allows it.
3. Enable dynamic client drive mapping under `Devices > Storage Devices > Storage Hotplug`.
4. Keep mass storage (class 08) out of your Native USB Redirection rules. A matching generic rule redirects the stick as a USB device instead of mapping it.

## Generic Redirection per Device

1. Get the VID and PID on the IGEL endpoint. Open a shell on the IGEL over the **Secure Terminal**. Enable it on the device under `System > Remote Access > Secure Terminal` (off by default, or for all devices in the UMS under `UMS Administration > Global Configuration > Remote Access`). Then right-click the device in the UMS, choose **Secure Terminal** and accept the device certificate. Log in as `user`, switch to root with `su` and list the devices:

   ```bash
   su
   lsusb
   ```

   Unplug the device and run `lsusb` again if the name is not clear.

   > `lsusb` shows each device as `ID VID:PID`, for example `Bus 001 Device 005: ID 0554:1001 Nuance PowerMic`. The first number (`0554`) is the Vendor ID, the second (`1001`) the Product ID.
   {: .prompt-tip }

2. In IGEL OS 12, open `Apps > Citrix > Global Settings > Native USB Redirection`. Turn it on, keep the default rule on **Deny** and add a product rule with the VID and PID.
3. Use **Connect**, not Allow. Connect also redirects a device that was plugged in before the session started. Allow only catches devices plugged in later, and Citrix Workspace app for Linux stopped auto-redirecting by default with 2207.
4. On the VDA, set **Client USB device redirection** to Allowed for the users who need it and add a matching line to **Client USB device redirection rules (Version 2)**. Set both auto-connect policies to automatic.
5. Install the device driver and vendor software in the Worker image.
6. Check Device Manager in the session.

Both sides must allow the device. The IGEL rule decides what the endpoint offers, the VDA policy decides what the Worker accepts. A Deny on either side blocks it.

## Composite Devices: Split Them

A dictation microphone is one cable but several USB interfaces: audio in and out, a mouse, and HID interfaces for the buttons. Redirecting the whole device takes the audio away from HDX and the mouse away from the endpoint. Splitting redirects only the interfaces the dictation software needs.

To see the interfaces of a device, run `lsusb` in verbose mode for its VID:PID and keep only the interface numbers and the HID lines:

```bash
lsusb -d 0554:1001 -vv | grep -e bInterfaceNumber -e HID
```

Each `bInterfaceNumber` is one interface, the HID lines show which of them are buttons or controls. Those numbers go into `intf=`. The output does not always tell which HID interface carries the buttons, the device vendor does.

Citrix now publishes official rules for this in the Nuance OEM guide of 2607 LTSR (CVAD and VDA 2402 or later, Workspace app for Linux 2601 or later):

```plaintext
Connect: VID=0554 PID=0064 split=1 intf=04,05,06,07 #PowerMic4 HID
Deny: VID=0554 PID=0064 split=1 intf=00,01,02 #PowerMic4 audio
Deny: VID=0554 PID=0064 split=1 intf=03 #PowerMic4 mouse
Connect: VID=0911 PID=0c1c split=1 intf=03,04,05,06 #SpeechMike
Deny: VID=0911 PID=0c1c split=1 intf=00,01,02 #SpeechMike audio
```
{: file="Client USB device redirection rules (Version 2)" }

On IGEL the same rule goes into the product rule of Native USB Redirection: VID, PID, rule type Connect, and `split=1 intf=03,04,05,06` in **Extra Config**. If the vendor ships a virtual channel for IGEL (Philips Speech Extensions, Olympus), prefer that and add it to the VDA's virtual channel allow list.

> A deny on a single interface of an unsplit composite device denies the whole device. Citrix also advises against splitting webcams.
{: .prompt-info }

## Troubleshooting

- **Unknown device in the session:** the driver is missing in the Worker image.
- **Device not redirected although the IGEL rule allows it:** the VDA policy or its default rules deny it. `CtxUsbDiagnostics.exe` on the VDA shows which rule blocked it, and the VDA event log records allowed and denied redirections.
- **Redirection stopped after a Workspace app update:** switch the IGEL rule from Allow to Connect.
- **Mixed Allow and Deny rules ignored:** Workspace app for Linux 2508.0 had this bug, 2508.10 fixed it (HDX-95546).
- **USB stick visible on the IGEL but not in the session:** a generic rule grabbed it, or Client Drive Mapping is still off in the IGEL OS 12 Citrix app.

## Summary

| Question | Answer |
|---|---|
| Native vs Generic | Same thing, IGEL name vs Citrix name |
| Default | Optimized channel, Generic only without one |
| Where is the driver for Generic | In the VDA image |
| USB sticks | Client drive mapping, not USB redirection |
| Dictation and headsets with buttons | Vendor channel or composite split |
| Rule type on IGEL | Connect |
| Who must allow | Both the IGEL endpoint and the VDA |

## References

- [Citrix - USB devices policy settings](https://docs.citrix.com/en-us/citrix-virtual-apps-desktops/policies/reference/ica-policy-settings/usb-devices-policy-settings)
- [Citrix - Generic USB devices](https://docs.citrix.com/en-us/citrix-daas/generic-usb-devices)
- [Citrix - Generic USB redirection and client drive considerations](https://docs.citrix.com/en-us/citrix-daas/general-content-redirection/usb)
- [Citrix - Composite devices and device splitting (2607 LTSR)](https://docs.citrix.com/en-us/citrix-virtual-apps-desktops/2607-ltsr/devices/usb-devices/composite-devices-and-device-splitting)
- [Citrix - Nuance OEM guide, configuration (2607 LTSR)](https://docs.citrix.com/en-us/citrix-virtual-apps-desktops/2607-ltsr/oem-guides/nuance/configuration)
- [Citrix - USB troubleshooting and USB diagnostics tool](https://docs.citrix.com/en-us/citrix-daas/devices/usb-devices/troubleshooting)
- [Citrix Workspace app for Linux - USB](https://docs.citrix.com/en-us/citrix-workspace-app-for-linux/usb)
- [Citrix Workspace app for Linux - What's new](https://docs.citrix.com/en-us/citrix-workspace-app-for-linux/whats-new)
- [CTX132716 - Allowing Mapping of Specific USB Devices to Virtual Desktops](https://support.citrix.com/external/article/132716/allowing-mapping-of-specific-usb-devices.html)
- [IGEL KB - When to Use USB Redirection](https://kb.igel.com/en/igel-os/current/when-to-use-usb-redirection)
- [IGEL KB - How to Map USB Storage Media into Citrix Sessions](https://kb.igel.com/en/igel-os/current/how-to-map-usb-storage-media-into-citrix-sessions)
- [IGEL KB - Configuration of the Citrix Workspace App on IGEL OS](https://kb.igel.com/en/igel-apps/current/configuration-of-the-citrix-workspace-app-on-igel-)
- [IGEL KB - Storage Hotplug in IGEL OS 12](https://kb.igel.com/en/igel-os-base-system/12.9.0/storage-hotplug-in-igel-os-12)
- [VirtualBrat - Citrix USB composite device splitting with IGEL OS](https://virtualbrat.com/2023/09/29/citrix-usb-composite-device-splitting-with-igel-os-the-why-and-how-digital-dictation-and-more/)

---

<br>

*Which USB device gives you the most trouble on IGEL thin clients? Reach out on [LinkedIn](https://www.linkedin.com/in/robertmagasi/).*

<br>

> *This post was written with assistance from Claude (Anthropic) as a drafting and editing tool. All technical content, solutions, and recommendations reflect my own hands-on experience and professional judgment.*
