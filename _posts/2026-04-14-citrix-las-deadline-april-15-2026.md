---
title: "Citrix LAS Deadline Countdown"
date: 2026-04-14 09:00:00 +0200
author: robert
categories: ["Citrix"]
tags: ["citrix", "licensing", "las", "deadline"]
description: "Citrix file-based licensing goes end of life on April 15, 2026. Environments that haven't migrated to LAS will stop working. No grace period."
toc: false
image:
  path: /assets/img/posts/og-citrix-las-deadline.png
  alt: "Citrix LAS Deadline Countdown"
---

Citrix file-based licensing goes end of life on **April 15, 2026**. Environments that haven't migrated to the License Activation Service (LAS) can have issues. Not clear what will happen with environments which are not updated to LAS ready versions.

<div style="margin:2.5rem 0;">
  <div id="las-timer" style="display:flex;gap:clamp(0.25rem,1.5vw,1rem);width:100%;">
    <div style="flex:1;background:#f8fafc;border:2px solid #0056b2;border-radius:10px;padding:clamp(0.75rem,2vw,1.5rem) clamp(0.25rem,1vw,1rem);text-align:center;min-width:0;">
      <div id="cd-d" style="font-size:clamp(1.6rem,7vw,4rem);font-weight:900;color:#0056b2;line-height:1;">--</div>
      <div style="font-size:clamp(0.6rem,1.8vw,0.8rem);font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:#656d76;margin-top:6px;">Days</div>
    </div>
    <div style="flex:1;background:#f8fafc;border:2px solid #0056b2;border-radius:10px;padding:clamp(0.75rem,2vw,1.5rem) clamp(0.25rem,1vw,1rem);text-align:center;min-width:0;">
      <div id="cd-h" style="font-size:clamp(1.6rem,7vw,4rem);font-weight:900;color:#0056b2;line-height:1;">--</div>
      <div style="font-size:clamp(0.6rem,1.8vw,0.8rem);font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:#656d76;margin-top:6px;">Hours</div>
    </div>
    <div style="flex:1;background:#f8fafc;border:2px solid #0056b2;border-radius:10px;padding:clamp(0.75rem,2vw,1.5rem) clamp(0.25rem,1vw,1rem);text-align:center;min-width:0;">
      <div id="cd-m" style="font-size:clamp(1.6rem,7vw,4rem);font-weight:900;color:#0056b2;line-height:1;">--</div>
      <div style="font-size:clamp(0.6rem,1.8vw,0.8rem);font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:#656d76;margin-top:6px;">Minutes</div>
    </div>
    <div style="flex:1;background:#f8fafc;border:2px solid #0056b2;border-radius:10px;padding:clamp(0.75rem,2vw,1.5rem) clamp(0.25rem,1vw,1rem);text-align:center;min-width:0;">
      <div id="cd-s" style="font-size:clamp(1.6rem,7vw,4rem);font-weight:900;color:#0056b2;line-height:1;">--</div>
      <div style="font-size:clamp(0.6rem,1.8vw,0.8rem);font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:#656d76;margin-top:6px;">Seconds</div>
    </div>
  </div>
  <div id="las-expired" style="display:none;font-size:2rem;font-weight:900;color:#d1242f;letter-spacing:.04em;padding:1.5rem;text-align:center;">DEADLINE PASSED</div>
  <div style="margin-top:0.75rem;font-size:0.8rem;color:#656d76;text-align:center;">
    Counting to April 15, 2026 00:00 UTC — exact cutoff time not published by Citrix.
  </div>
</div>

<script>
/* LAS countdown */
(function() {
  var target = new Date('2026-04-15T00:00:00Z').getTime();
  function pad(n) { return String(n).padStart(2, '0'); }
  function tick() {
    var diff = target - Date.now();
    if (diff <= 0) {
      document.getElementById('las-timer').style.display = 'none';
      document.getElementById('las-expired').style.display = 'block';
      return;
    }
    document.getElementById('cd-d').textContent = pad(Math.floor(diff / 86400000));
    document.getElementById('cd-h').textContent = pad(Math.floor((diff % 86400000) / 3600000));
    document.getElementById('cd-m').textContent = pad(Math.floor((diff % 3600000) / 60000));
    document.getElementById('cd-s').textContent = pad(Math.floor((diff % 60000) / 1000));
    setTimeout(tick, 1000);
  }
  tick();
})();
</script>

Not migrated yet? → [Citrix LAS Migration Guide](https://support.citrix.com/external/article/CTX695107/license-activation-service-replacing-our.html)
