# resources

  ###/ɡrimˈwär/

  # 📜 Security Guide: Analyze the Threat Model

## Table of Contents
- [Analyze the Threat Model](#analyze-the-threat-model)
- [Linux Files Hierarchy](#linux-files-hierarchy)
- [Kernel Hardening](#kernel-hardening)
  - [Sysctl Settings](#sysctl-settings)
  - [Boot Parameters](#boot-parameters)

---

## 🔍 Analyze the Threat Model

When approaching a system to secure, it's crucial to ask yourself a series of questions. Even if some of these questions seem trivial, simplifying the problem is essential for effective security.

- [ ] Why do you want to secure your server and services?
- [ ] How much security do you desire?
- [ ] How many devices, apps, software, and databases need securing?
- [ ] How much convenience are you willing to compromise for security? (People often prefer convenience over security.)
- [ ] What threats do you want to protect against?
- [ ] What are the specifics of your situation?
- [ ] Is physical access to your server/network a possible attack vector?
- [ ] Do you need to address known vulnerabilities in hardware, software, or libraries?
- [ ] How are you hosting it? Is it accessible from the public?
- [ ] Do you have a recovery plan if your security measures lock you out of your own server? (e.g., if you disabled root login or password-protected GRUB and deleted your SSH public key.)

---

## 🗂️ Linux Files Hierarchy

Understanding your system is the most critical aspect of security. Security is not merely about software, services, or patches; it requires constant effort and in-depth knowledge of your system, including which services run and which ports are used.

The Linux kernel and its related files reside in the `/boot` directory, which is read-write by default. Changing it to read-only reduces the risk of unauthorized modifications to critical boot files. To do this, edit the `/etc/fstab` file and insert the following line:

```bash
# Example entry for read-only boot partition
/dev/sda1 /boot ext4 ro 0 2
```

It's essential to mount several partitions with specific options and their own partitions. A good example is the `/tmp` partition, which is often exploited for privilege escalation.

Many hardening or security guides spread misinformation. They are not only lacking but also far from being battle-ready for the internet.

One of the most important steps in securing your environment is developing your threat model. For more information on threat modeling, refer to the guidelines below:

- [Linux Hardening Guide](https://madaidans-insecurities.github.io/guides/linux-hardening.html)

Consider using tools such as:
- CrowdSec
- SpoofDPI
- AmneziaWG
- EBTABLES
- eBPF & XDP
- Thor (YARA detections)
- Automating IPSet blacklist
- Setting up bridged VLANs
- Debloating to reduce attack surface

---

## 🛡️ Kernel Hardening

### 1.1. Sysctl Settings

Create or edit a file like [`/etc/sysctl.d/99-hardening.conf`](https://codeberg.org/TwilightAlicorn/Fedora-Hardening-Guide/src/branch/main/etc/sysctl.d/99-security.conf) and add the following settings. Apply them with:




# Create an Ed25519 key with ssh-keygen instead of using RSA :

```
ssh-keygen -t ed25519
sudo groupadd sudousers
sudo groupadd jailedusers
sudo groupadd sshusers
sudo usermod -a -G sshusers user1
sudo cp --preserve /etc/sudoers /etc/sudoers.$(date +"%Y%m%d%H%M%S")
sudo visudo
sudo cp --preserve /etc/ssh/sshd_config /etc/ssh/sshd_config.$(date +"%Y%m%d%H%M%S")
sudo sed -i -r -e '/^#|^$/ d' /etc/ssh/sshd_config
%sudousers   ALL=(ALL:ALL) ALL
```

sudo cp --preserve /etc/ssh/moduli /etc/ssh/moduli.$(date +"%Y%m%d%H%M%S")

Remove short moduli:

sudo awk '$5 * = 3071' /etc/ssh/moduli | sudo tee /etc/ssh/moduli.tmp
sudo mv /etc/ssh/moduli.tmp /etc/ssh/moduli






Install ntp if you need it.

On Debian based systems:

sudo apt install ntp

Make a backup of the NTP client's configuration file /etc/ntp.conf:

sudo cp --preserve /etc/ntp.conf /etc/ntp.conf.$(date +"%Y%m%d%H%M%S")


sudo sed -i -r -e "s/^((server|pool).*)/# \1         # commented by $(whoami) on $(date +"%Y-%m-%d @ %H:%M:%S")/" /etc/ntp.conf
echo -e "\npool pool.ntp.org iburst         # added by $(whoami) on $(date +"%Y-%m-%d @ %H:%M:%S")" | sudo tee -a /etc/ntp.conf

sudo service ntp restart


Steps

    Make a backup of /etc/fstab:

    sudo cp --preserve /etc/fstab /etc/fstab.$(date +"%Y%m%d%H%M%S")
echo -e "\nproc     /proc     proc     defaults,hidepid=2     0     0         # added by $(whoami) on $(date +"%Y-%m-%d @ %H:%M:%S")" | sudo tee -a /etc/fstab

sudo sed -i -r -e "s/^(password\s+requisite\s+pam_pwquality.so)(.*)$/# \1\2         # commented by $(whoami) on $(date +"%Y-%m-%d @ %H:%M:%S")\n\1 retry=3 minlen=10 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 maxrepeat=3 gecoschec         # added by $(whoami) on $(date +"%Y-%m-%d @ %H:%M:%S")/" /etc/pam.d/common-password


sudo psad -R
sudo psad --sig-update
sudo psad -H
sudo cp --preserve /etc/psad/psad.conf /etc/psad/psad.conf.$(date +"%Y%m%d%H%M%S")
sudo apt install aide
sudo cp -p /etc/default/aide /etc/default/aide.$(date +"%Y%m%d%H%M%S")
sudo cp -pr /etc/aide /etc/aide.$(date +"%Y%m%d%H%M%S")
sudo aideinit
sudo aide.wrapper --check


# if you are not sure the change worked , verify the configuration with this
sudo touch /etc/test.sh
sudo touch /root/test.sh
sudo aide.wrapper --check
sudo rm /etc/test.sh
sudo rm /root/test.sh
sudo aideinit -y -f
