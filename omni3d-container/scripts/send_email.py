#!/usr/bin/env python3
"""Send manual testing checklist email."""
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
import sys

sender       = os.environ.get("GMAIL_USER", "")
password     = os.environ.get("GMAIL_APP_PASS", "")
recipient    = os.environ.get("TESTER_EMAIL", "")
submodule    = os.environ.get("SUBMODULE", "")
pusher       = os.environ.get("PUSHER", "")
checklist    = os.environ.get("CHECKLIST", "")
approval_url = os.environ.get("APPROVAL_URL", "")

if not recipient:
    print("No tester email — skipping")
    sys.exit(0)

msg = MIMEMultipart()
msg["From"]    = sender
msg["To"]      = recipient
msg["Subject"] = f"[OMNI3D] Manual testing required — {submodule}"

body = f"""Automated CI passed for {submodule} pushed by {pusher}.
Manual testing is now required before release.

{checklist}

---
Approve or reject the release here:
{approval_url}

Click 'Review deployments' to approve and trigger the release build.
"""

msg.attach(MIMEText(body, "plain"))

with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
    smtp.login(sender, password)
    smtp.sendmail(sender, recipient, msg.as_string())

print(f"Email sent to {recipient}")
