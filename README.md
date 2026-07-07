# .files

Setting up nixOS machines

### Detailed Documentation for Manual Installation of NixOS (Minimal ISO)

This guide will take you through the process of installing NixOS using the minimal ISO, configuring a LUKS-encrypted root partition, setting up UEFI (GPT) partitioning, and other installation steps. We'll also use SSH for remote installation to make copying commands and configurations easier.

#### **Step 1: Create a Bootable USB**

Use **balena Etcher** to create a bootable USB drive from the NixOS minimal ISO:
1. Download the minimal NixOS ISO from the [NixOS Downloads Page](https://nixos.org/download.html).
2. Install and open **balena Etcher**.
3. Select the NixOS ISO, choose your USB drive, and click "Flash".

#### **Step 2: Boot into Live CD**

1. Insert the USB drive into your machine and boot from the USB.
2. At the NixOS boot menu, select the **first option** to enter the live environment.

#### **Step 3: Configure Network**

For wireless network configuration, follow these steps:

1. Start the wireless service:

   ```bash
   sudo systemctl start wpa_supplicant
   ```

2. Open the wireless control interface:

   ```bash
   wpa_cli
   ```

3. Configure your network:

   Inside `wpa_cli`:

   ```bash
   add_network
   set_network 0 ssid "myhomenetwork"
   set_network 0 psk "mypassword"
   set_network 0 key_mgmt WPA-PSK
   enable_network 0
   ```

4. You should see a message like this if the network is successfully connected:

   ```bash
   <3>CTRL-EVENT-CONNECTED - Connection to 32:85:ab:ef:24:5c completed [id=0 id_str=]
   ```

5. Check your IP address:

   ```bash
   ip a
   ```

#### **Step 4: Set a Root Password and Start SSH**

1. Set a password for the `root` user:

   ```bash
   passwd
   ```

2. Start the SSH service:

   ```bash
   sudo systemctl start sshd
   ```

#### **Step 5: Connect via SSH from Another System**

Now, connect to the live environment from another computer:

1. On your other system, use SSH to connect:

   ```bash
   ssh root@<ip_address>
   ```

   Replace `<ip_address>` with the IP you found in Step 3.5.

#### **Step 6: UEFI (GPT) Partitioning and Formatting**

You will now partition and format your disk. **Note:** Replace `/dev/nvme0n1` with your actual disk device if it's different.

1. To identify your target disk:

   ```bash
   lsblk
   ```

   In this example, we assume `/dev/nvme0n1` is the intended disk. Adjust commands as needed for your disk.

2. Partition the disk using **parted**:

   ```bash
   parted /dev/nvme0n1 -- mklabel gpt
   parted /dev/nvme0n1 -- mkpart primary 512MiB -100MiB
   parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 512MiB
   parted /dev/nvme0n1 -- set 2 boot on
   ```

3. Format the **/boot** partition:

   ```bash
   mkfs.vfat -F 32 -n BOOT /dev/nvme0n1p2
   ```

4. Set up **LUKS encryption** for the root partition:

   ```bash
   cryptsetup luksFormat /dev/nvme0n1p1
   cryptsetup open /dev/nvme0n1p1 root
   mkfs.ext4 /dev/mapper/root
   ```

5. Mount the partitions:

   ```bash
   mount /dev/mapper/root /mnt
   mkdir -p /mnt/boot
   mount /dev/nvme0n1p2 /mnt/boot
   ```

#### **Step 7: Generate and Update NixOS Configuration**

1. Generate the default NixOS configuration:

   ```bash
   nixos-generate-config --root /mnt
   ```

2. Edit `/mnt/etc/nixos/configuration.nix` and replace its content with the configuration from your repo or personal setup.

#### **Step 8: Install NixOS**

1. Install NixOS:

   ```bash
   nixos-install
   ```

2. During installation, you’ll be asked to set the root password.

3. Set a password for your user (replace `dhilipsiva` with your actual username):

   ```bash
   nixos-enter --root /mnt -c 'passwd dhilipsiva'
   ```

#### **Step 9: Reboot into Your New System**

After installation, reboot the system:

```bash
reboot
```

Your system should now boot into your new NixOS installation.

#### **Step 10: Troubleshooting Boot Issues**

If your system has trouble booting or logging in, you can boot back into the live USB, decrypt and mount the LUKS-encrypted partition, and make any necessary changes to the configuration.

1. List available block devices to find your partitions:

   ```bash
   lsblk
   ```

2. Open the LUKS-encrypted partition:

   ```bash
   cryptsetup luksOpen /dev/nvme0n1p1 luks-root
   ```

3. Mount the partitions:

   ```bash
   mount /dev/mapper/luks-root /mnt
   mount /dev/nvme0n1p2 /mnt/boot
   ```

4. Make changes to the NixOS configuration:

   ```bash
   nano /mnt/etc/nixos/configuration.nix
   ```

5. Reinstall the configuration:

   ```bash
   nixos-install --root /mnt
   ```

6. Reboot:

   ```bash
   reboot
   ```

---

### Additional Notes:

- For systems with 16GB+ RAM, swap is generally unnecessary.
- If issues arise with networking or disk detection, ensure you check the partition layout and use tools like `lsblk` and `fdisk` to verify the correct devices.
