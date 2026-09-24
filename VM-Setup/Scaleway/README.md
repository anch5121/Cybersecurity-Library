# Scaleway lab desktop setup

This sets up the **Elastic Metal Ubuntu host GUI**. The course Ubuntu VM and nested Windows 7 VM are later steps.

## Before starting

- Provision an x86_64 Elastic Metal server with **Ubuntu 26.04 LTS** and working SSH-key access for `ubuntu`.
- On your Mac, have **Windows App** and [em-lab-desktop.sh](./em-lab-desktop.sh) in `~/Downloads/`.
- Replace `SERVER_IP` in the commands with the server's current public IPv4 address.

## 1. Set up the server from a Mac Terminal

```bash
scp ~/Downloads/em-lab-desktop.sh ubuntu@SERVER_IP:~
ssh ubuntu@SERVER_IP
sudo bash ~/em-lab-desktop.sh server
```

If SSH reports a *changed host key*, stop and verify the server's identity. The script prompts for a **new, unique Ubuntu login password**; it does not print or save that password. Wait for `Ready: RDP listens on 127.0.0.1:3389`. Run this step through SSH because it stops and starts xRDP.

## 2. Open the SSH tunnel from a second Mac Terminal

```bash
bash ~/Downloads/em-lab-desktop.sh tunnel ubuntu@SERVER_IP
```

Keep this Terminal open while using the desktop. A successful tunnel remains running.

## 3. Connect with Windows App on the Mac

1. **Devices -> + -> Add PC**. Set **PC Name** to `127.0.0.1:3390`; choose **Ask when required** for credentials.
2. Turn **Clipboard** and **Folders/Storage** redirection off. Save the device and double-click it.
3. At the xRDP login, select **Xorg**, then enter `ubuntu` and the password created in step 1. Stop and inspect any unexpected certificate or identity warning.

Windows App now displays the **physical Ubuntu host**. Do not open public RDP port 3389. Before running any sample, separately verify nested virtualization and the Windows 7 VM's lack of internet access.
