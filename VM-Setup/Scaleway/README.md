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

----
----
----

# em-lab2: reconnect to the Ubuntu desktop

This is for the existing Scaleway server with Xfce, xRDP, and VirtualBox already installed.

1. **Start:** In Scaleway, open **Bare Metal > Elastic Metal > em-lab2**. If **Stopped**, choose **Power on**. If **Ready**, try SSH. After a reboot, allow several minutes for Ubuntu to boot.
2. **SSH from the Mac:** Copy the SSH command under the server's **Access** section. It should use `ubuntu@SERVER_PUBLIC_IP`, not the Dell console IP.
3. **Check RDP in the Ubuntu SSH session:**

   ```bash
   sudo ss -ltnp | grep ':3389' || echo 'No RDP listener'
   ```

   It must show **127.0.0.1:3389** as the listening address. If there is no listener, run `sudo systemctl start xrdp-sesman xrdp` and check again. If it listens on a public address, run `sudo systemctl stop xrdp` and fix the configuration before connecting.
4. **Open a second Terminal tab on the Mac** (the `zsh` prompt, not `ubuntu@em-lab2`). Replace the IP with the current public IP shown by Scaleway:

   ```bash
   ssh -N -T -o ExitOnForwardFailure=yes -L 127.0.0.1:3390:127.0.0.1:3389 ubuntu@SERVER_PUBLIC_IP
   ```

   Leave this tab open. A successful tunnel normally prints nothing. Do not copy your Mac's private SSH key to the server.
5. **Open Windows App:** Connect to the saved device **127.0.0.1:3390**. Log in as `ubuntu` with its desktop password. Keep folder and clipboard redirection off.

**When finished:** Shut down any running VMs safely, then run `sudo shutdown -h now` on Ubuntu. Once the OS has halted, use Scaleway's **Power off** control. Next time, use **Power on**. Scaleway continues billing the allocated Elastic Metal server while it is powered off.

**If SSH times out while Scaleway says Ready:** Confirm the public IP and give Ubuntu several minutes after boot. If it remains unreachable, use **Reboot > Normal reboot** once, then check again. Do not choose **Reinstall** or **Rescue mode** as a routine startup step.

**Lab boundary:** This reconnects to the physical Ubuntu host. The course appliance and its Windows analysis VM still require import and network isolation checks before any malware is run.
