# cachyos-recovery

<img width="1600" height="900" alt="image" src="https://github.com/user-attachments/assets/9d837def-07c5-4ae8-bd78-de9c68c1bf1f" />


## Description

This is the CachyOS recovery environment. It comes as a self-contained UKI
image, built by mkosi, which you can boot at any time from your bootloader or
directly from UEFI. This simplifies the system recovery process, as it does not
require a LiveCD device and provides an ready-to-use set of actions via TUI.

## Features

This recovery image has the following features and advantages:

- [x] Stateless. This means that it can restore the system from any Btrfs snapshot.

- [x] Self-contained, no runtime dependencies needed

- [x] Takes only ~70 Mb on your ESP partition

- [x] Bootloader agnostic (almost)

- [x] Snapper independent

- [x] Btrfs snapshots restoring (see below for more details)

- [x] Btrfs snapshots booting with writable root via overlayfs

> [!NOTE]
> For now all main actions are related to restoring Btrfs snapshots, but in the future we will add much more.

## Btrfs snapshots

Btrfs snapshots is a good way to create backups, but their restoring comes with
some complications. The main issue is that if your ESP partition is mounted in
``/boot``, it creates a desynchronization between ``initramfs`` and ``vmlinuz``
versions on it and module versions in the snapshot. So if you simply try to
restore snapshot, you likely will get a mismatch between the initramfs version
and modules files inside your new root.

The classic approach to solving this problem is copying of initramfs and
vmlinux for your kernel into ``/boot`` when creating a snapshot, so that we can
take back the old initramfs/vmlinux version that matches the modules in old
root. The problem with this approach is that it greatly bloats ESP partition
and limits the number of snapshots you can restore because of that. It also
always ties you to a specific bootloader so that you can boot the snapshot to
restore it.

Compared to this, cachyos-recovery uses a more practical way:

1. It doesn’t copy anything into your ``/boot`` until the snapshot rollback
   process itself, which eliminates the persistent issues from
desynchronization between ``/boot`` and ``/``.

2. To boot snapshot from recovery environment, we're using kexec with temporary
   generated initramfs image.

3. To avoid image booting errors due to read-only filesystem, we’re monting
   overlayfs as root.

After boot, user is prompted to restore the current snapshot. The snapshot
recovery operation consists of the following steps:

1. Create and mount temporary ``/boot`` directory.

2. Create new initramfs and vmlinuz files for current snapshot, and stage them
   in temporary directory.

3. Remove orphan entities from the current active root.

4. Regenerate boot loader configuration (depends on bootloader, rEFInd doesn't
   need that)

5. Create new root from snapshot

6. Save the current active (old) root as subvolume.

7. Swap old root and new root.

8. Move nested subvolumes from old root to the new one.

9. Copy staged new ``/boot`` files from temporary directory to the ESP
   partition.

10. Old root removal.

If any of the steps fail, we always try to go backwards. That means any step
here is revertable, if we can't create a new root, then we don’t even try to
copy the new ``/boot`` files into ESP, just like if new ``/boot`` files can't
be generated, then we don’t do anything with your current root.

## Matinainer

- Vasiliy Stelmachenok <venutureo@cachyos.org>

## License

This is licensed under GPL-v3.0. See LICENSE.md.
