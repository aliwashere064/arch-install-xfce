#!/bin/bash

# Ensure the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# Update system clock
timedatectl set-ntp true

# Partition the disk (assuming /dev/sda for this example)
# You may need to adapt this part based on your system and disk configuration
# Here, we create a single root partition using the entire disk
echo -e "g\nn\n\n\n+512M\nn\n\n\n\nw" | fdisk /dev/sda
mkfs.ext4 /dev/sda1
mount /dev/sda1 /mnt

# Install the base system
pacstrap /mnt base base-devel

# Generate an fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# Change root into the new system
arch-chroot /mnt

# Set the time zone
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
hwclock --systohc

# Uncomment the desired locale in /etc/locale.gen and generate locales
# For example, en_US.UTF-8 UTF-8
sed -i '/en_US.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set the hostname
echo "myarch" > /etc/hostname

# Configure the network
# You may need to replace enp0s3 with your actual network interface name
echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\tmyarch.localdomain\tmyarch" >> /etc/hosts
systemctl enable dhcpcd@enp0s3.service

# Set the root password
echo "root:root" | chpasswd

# Install and configure bootloader (GRUB in this case)
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Install and configure Xorg and XFCE
pacman -S xorg xfce4 xfce4-goodies lightdm lightdm-gtk-greeter arc-gtk-theme
systemctl enable lightdm.service

# Create a regular user
useradd -m -G wheel -s /bin/bash basicusr
echo "basicusr:changeme" | chpasswd

# Allow users in the wheel group to use sudo
sed -i '/%wheel ALL=(ALL) ALL/s/^#//g' /etc/sudoers

# Exit the chroot environment
exit

# Unmount all partitions and reboot
umount -R /mnt
reboot
