---
layout: page
title: Contact
icon: fas fa-envelope
order: 6
---

Whether you have a question about something I've written, want to discuss an EUC challenge, or are looking for consulting help - feel free to reach out. I typically respond within a few business days.

<form class="contact-form" action="https://formspree.io/f/xlgpwpow" method="POST" id="contact-form">
  <div class="form-field">
    <label for="name">Name</label>
    <input type="text" id="name" name="name" required>
  </div>

  <div class="form-field">
    <label for="email">Email</label>
    <input type="email" id="email" name="email" required>
  </div>

  <div class="form-field">
    <label for="subject">Subject</label>
    <input type="text" id="subject" name="subject">
  </div>

  <div class="form-field last">
    <label for="message">Message</label>
    <textarea id="message" name="message" rows="6" required></textarea>
  </div>

  <div class="honeypot" aria-hidden="true">
    <label for="website">Website (leave blank)</label>
    <input type="text" id="website" name="_gotcha" tabindex="-1" autocomplete="off">
  </div>

  <button type="submit">Send Message</button>

  <div class="contact-form-status" id="contact-form-status" role="status" aria-live="polite"></div>
</form>

<script>
(function () {
  var form = document.getElementById('contact-form');
  if (!form) return;
  var status = document.getElementById('contact-form-status');
  form.addEventListener('submit', function (ev) {
    ev.preventDefault();
    status.className = 'contact-form-status';
    status.textContent = '';
    var data = new FormData(form);
    fetch(form.action, {
      method: 'POST',
      body: data,
      headers: { 'Accept': 'application/json' }
    }).then(function (response) {
      if (response.ok) {
        status.className = 'contact-form-status success';
        status.textContent = 'Thanks — your message has been sent. I\u2019ll get back to you shortly.';
        form.reset();
      } else {
        response.json().then(function (d) {
          status.className = 'contact-form-status error';
          status.textContent = (d && d.errors && d.errors.map(function (e) { return e.message; }).join(', ')) || 'Something went wrong. Please try again or reach me on LinkedIn.';
        }).catch(function () {
          status.className = 'contact-form-status error';
          status.textContent = 'Something went wrong. Please try again or reach me on LinkedIn.';
        });
      }
    }).catch(function () {
      status.className = 'contact-form-status error';
      status.textContent = 'Network error. Please try again or reach me on LinkedIn.';
    });
  });
}());
</script>

<br>

Prefer a direct channel? Connect with me on [LinkedIn](https://www.linkedin.com/in/robertmagasi/).
