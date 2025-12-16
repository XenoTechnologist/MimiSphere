# **MimiSphere Configuration & Setup**

# **Hardware & BIOS**
You can use anything laptop or desktop as a Proxmox server. The more cores and threads a CPU has, the more containers you can run (RAM dependent).

## Hardware
Model: Dell Optiplex 5050 Micro
CPU: i7-6700T 3.6GHz | 4 cores 8 threads
RAM: 32GB DDR4 SO-DIMM 3200MHz
Onboard Storage: 60GB SSD
Additional Storage: 1TB SSD

## BIOS Configuration
The key to access BIOS/UEFI settings varies by manufacturer. [This reference](https://www.tomshardware.com/reviews/bios-keys-to-access-your-firmware,5732.html) contains a list of common BIOS keys by manufacture.

Proxmox is a virtualization platform. To ensure optimized performance, enable virtualization settings in the BIOS/UEFI. *Note that these settings may differ depending on your specific hardware.*

- Boot Option: UEFI - Disable Legacy Support
- Integrated NIC: Enabled
- TPM 2.0 Security: TPM, Attestation, Key Storage, SHA-256
- Secure Boot: Disabled
- Multi Core Support: All
- Intel SpeedStep: Enabled
- C States Control: Enabled
- Intel TurboBoost: Enabled
- Fast Boot: Disabled
- Virtualization Technology: Enabled
- VT for Direct I/O

# **Installing Proxmox - Initial Install**
Proxmox is a free and open source, and can be installed from a ISO. MimiSphere was installed using the VE 9.1 ISO installer, but you can use any of [the provided versions](https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso).

You will need software to write the ISO to a USB. I used [Ventoy](https://www.ventoy.net/en/download.html), but [Rufus](https://rufus.ie/en/), [Balena Etcher](https://etcher.balena.io/), and various other methods exist. Use a USB with at least 5GB storage to write the ISO installer.

1. Boot to the USB, and run the Proxmox ISO.
<br>
2. Select the GUI installation method and follow the prompts to create a root password
    - This will also be the root users password for the web UI on 8006.
<br>
3. Configure your network settings:
    - Hostname: pve-01
    - IP: 10.0.0.2/24
    - Gateway: 10.0.0.1
    - DNS: Any, none, or your own if you have a DNS server
<br>
4. Continue and reboot the server.
<br>
5. Verify that you can login to the server as the `root` user.
<br>
6. Open your browser and navigate to 10.0.0.2:8006 (or your choosen IP). Verify that you can login to the web UI as the `root` user.

**Note**

When you login to the web UI, you will get a warning that this server is not subscribed to Proxmox. You can ignore this message if you do not need a subscription for you environment. This guide will be configuring the **no-subscription** version.

# **Setup The Proxmox Environment**
With the initial installation complete, we can apply security and configurations that we'll need later.

## Change Update Repository
Proxmox by default configure the subscription based repositories for updating. These will need to be changed to the no-subscription version.

1. On the server, login as `root` and nagivate to `/etc/apt/sources.list.d/`.
<br>
2. Copy `pve-enterprise.sources` and rename it to `proxmox.sources`.
<br>
3. Run `nano proxmox.sources`, paste the below contents, and save the file:
    ```
    Types: deb
    URIs: http://download.proxmox.com/debian/pve
    Suites: trixie
    Components: pve-no-subscription
    Architectures: amd64
    Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
    ```
<br>
4. Modify the files in `/etc/apt/sources.list.d` to appear as follows:
    Before:
    ```
    ceph.sources
    debian.sources
    proxmox.sources
    pve-enterprise.sources
    ```

    After:
    ```
    ceph.sources.disabled
    debian.sources
    proxmox.sources
    pve-enterprise.sources.disabled
    ```
<br>
6. Navigate to `/etc/apt/`, and make a backup of `sources.list` then run `echo "" > sources.list` to empty the file.
<br>
7. Run `apt update && apt upgrade` and verify the update and upgrade complete successfully.

## Install Software
Proxmox does not ship with software like `sudo`. We will be installing an admin user later that will run commands as root. Install `sudo` with `apt install sudo`

## Create An Admin User
1. Create a new user:
    `useradd -m -s /bin/bash adminuser`
<br>
2. Create a new password:
    `passwd adminuser`
<br>
3. Add the user to the `sudo` and `adm` group:
    `usermod -aG sudo,adm adminuser`
<br>
4. Add the user to the Proxmox user database so we can login to the web UI with it:
    `pveum user add adminuser@pam`
<br>
5. Grant the user administration privileges:
    `pveum acl modify / -user adminuser@pam -role Administrator`
<br>
6. Verify that you can switch to `adminuser` and that `sudo` runs as `root`:
    ```
    root@pve-01:~# su - adminuser
    adminuser@pve-01:~$ sudo whoami
    root
    adminuser@pve-01:~$ whoami
    adminuser
    ```
<br>
7. Verify that you can login to the web UI as the `adminuser`.

## Create An SSH Key Pair For AdminUser
You will need to manage multiple SSH keys on your local host. I've used the default file name for keys, but it's encouraged to use names that you can identify later and manage them with a `...\.ssh\config` file.

1. On your local PC, open a terminal and generate an SSH key pair. This command is cross functional across Windows, Linux, and Mac:
    `ssh-keygen -t ed25519 -f pve-01 -C "adminuser@pve-01_YYYY"`
<br>
2. Open another terminal window and run ssh-copy-id to copy your public key to the server. This is not cross-functional. My local runs Windows 11 so my command looks like:
    `scp $env:USERPROFILE/.ssh/id_ed25519.pub adminuser@10.0.0.2:~/.ssh/authorized_keys`
<br>
3. Open another terminal window and verify that you can SSH to `adminuser` without being prompted for a password. You should be prompted to add the server to your `known_hosts` file. **Do not close your original terminal window for the next change.**

## Create .ssh\config
From your `home\.ssh` direcrtory create a `config` file with no extension. You can use to manage SSH keys for your Proxmox host and containers. Below is an example of a `.ssh\config` file with multiple keys.

```
# Proxmox host
Host pve-01
    HostName 10.0.0.2
    User adminuser
    IdentityFile C:\Users\<user>\.ssh\pve-01
    IdentitiesOnly yes

# Web server
Host webserver-01
    HostName 10.0.0.3
    User webuser
    IdentityFile C:\Uses\<user>\.ssh\webserver-01
    IdentitiesOnly yes
```

## Modify The Config For Passwordless SSH
Login as the root user and keep this terminal window open until you verify that SSH login is working properly. You may lock yourself out and have to undo the configs from the Proxmox web UI.

1. Run `nano /etc/ssh/sshd_config` and modify the following lines nad save the file:
    ```
    # Change to 'no' to disable root SSH
    PermitRootLogin no

    # Uncomment and set to 'yes'
    PubkeyAuthentication yes

    # Uncomment and set to 'no' to disable password logins
    PasswordAuthentication no
    ```
<br>
2. Restart the SSH service:
    `systemctl restart ssh`
<br>
3. Open a new terminal window and attempt to login as `root`. You should receive a permission denied warning. Attempt to login as `adminuser`