# 🧠 Distractions--(Distractions minus minus)
_(lame ahh name ik)_

![banner](assets/banner.png)

> A script that hard-blocks distracting or explicit websites for a **user-defined duration** — with **no manual override**.

---

## 🚀 Features

✅ Blocks access to social media, explicit, and custom websites  
✅ Locks `/etc/hosts` with `chattr +i` to **prevent even root edits**  
✅ Accepts **human-readable durations** (e.g., `3 hours`, `2 days`)  
✅ Schedules **auto-unblock** after duration using `at`  
✅ Uses **Zenity**  
✅ Optional **real-time CLI countdown**  
✅ Fully compatible with **all major Linux distros** _(or so i believe)_
✅ Custom domain input  

---

## 🖥️ How It Works

1. You run the script with `sudo ./distractions--.sh`
2. Enter:
   - The duration (e.g., `2 hours`, `1 day`)
   - Extra sites you want to block (optional)
3. The script:
   - Adds block entries to `/etc/hosts`
   - Locks it with `chattr +i`
   - Schedules auto-unblock using `at`
4. Optional: View the countdown live in your terminal
5. After time is up: `at` job unlocks `/etc/hosts` and restores backup

---
## ⚠️ WARNING:
Please proceed with caution and read the script file before actually executing anything. I am no professional developer. I just created this a week before my IGCSEs as i got too distracted by social media and some websites (pH, insta and shit like that).

---
## 📦 Dependencies required

- `zenity`
- `at`
- `chattr` (part of `e2fsprogs`)
- `bash`

Install them using:

```bash
sudo apt install zenity at e2fsprogs -y
```

Enable `atd` if needed:

```bash
sudo systemctl enable --now atd
```

---

## 🔐 What Makes It Different? _(or so i believe it is)_

| Feature | Distractions | Normal Blockers |
|--------|---------------|------------------|
| Root-proof lock | ✅ | ❌ |
| GUI (Zenity) | ✅ | ❌ |
| Works offline | ✅ | ❌ |
| Countdown view | ✅ | ❌ |
| Auto unblock | ✅ | ⚠️ (manual) |

---

## 📷 Screenshots

| Blocking Prompt | Countdown View |
|------------------|----------------|
| ![block](assets/block_prompt.png) | ![countdown](assets/countdown.gif) |

---

## 🧪 Tested On

- Linux Mint XFCE
_(please let me know by knocking me on discord if it works with other systems too, i believe it should but not sure)_

---

## 💻 Usage

```bash
chmod +x distractions--.sh
sudo ./distractions--.sh
```

---

## 📝 To-Do / Ideas

- [ ] Add auto-restart blocker on reboot (via cron)
- [ ] Block on schedule (e.g., 8am–10am daily)
- [ ] GUI version with GTK or Python frontend

---

## 🧑‍💻 Author & Contact

**Distractions--** by [moron]

- 📧 Email: govinpaul2008@gmail.com
- 🌐 Discord: @moron65
- 🐙 GitHub: (https://github.com/moron6554)

---

## 🖼️ License
GNU GENERAL PUBLIC LICENSE License.

---

> ✨ Stay focused, stay free from distractions. You deserve to win king. 💪
