#!/usr/bin/env bash
# Copyright (C) 2026 Vasiliy Stelmachenok <ventureo@cachyos.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

declare -r LOCKFILE="/.cachyos-recovery.lock"

function show_error() {
    local header="CachyOS Recovery"
    local title="${1}"
    local msg="${2}"

    for user in $(users | sed 's| |\n|g' | sort | uniq); do
        # If no notification daemon is running (e.g. a TTY-only login), the call below makes the bus try to
        # start one, and an activation that never completes blocks pacman for the default 25 s timeout.
        # Give activation a short window instead, so daemons started on demand still show the popup.
        local timeout=25
        busctl --machine="${user}@.host" --user status org.freedesktop.Notifications &>/dev/null || timeout=2

        # See https://specifications.freedesktop.org/notification-spec/1.2/protocol.html#command-notify
        busctl --machine="${user}@.host" --user --timeout="$timeout" call \
            org.freedesktop.Notifications \
            /org/freedesktop/Notifications \
            org.freedesktop.Notifications  \
            Notify \
            susssasa\{sv\}i \
            "$header" \
            0 \
            error \
            "$title" \
            "$msg" \
            0 \
            1 urgency y 0x2 \
            10000 &>/dev/null
    done
}

function main() {
    local action="$1"
    local subvol="$2"
    local fstype="$3"

    # Don't try to copy anything if ESP is not mounted to /boot
    if ! mountpoint -q "/boot" 2>/dev/null; then
        return 0
    fi

    # Only handle root Btrfs snapshots
    if [[ "$subvol" != "/" || "$fstype" != "btrfs" ]]; then
        return 0
    fi

    if [[ "$action" != "create-snapshot-pre" ]]; then
        return 0
    fi

    # Make sure that is performed atomically
    if ! touch "$LOCKFILE"; then
        show_error "Failed to create lock file" \
            "Created snapshot may be corrupted and cannot be restored"
        return 1
    fi

    if ! rsync -a --quiet --delete --mkpath /boot/ /.boot/; then
        show_error \
            "Failed to create proper snapshot" \
            "Rsync failed, created snapshot may be corrupted and cannot be restored"
        return 1
    fi

    if cp -aT --reflink=always /.boot/ "${subvol}/.boot"; then
        show_error \
            "Failed to create proper snapshot" \
            "cp failed, created snapshot may be corrupted and cannot be restored"
        return 1
    fi

    if ! rm "$LOCKFILE"; then
        show_error \
            "Failed to remove lock file" \
            "Remove it manually to allow new snaphosts to be created"
    fi

    return 0
}

main "$@"
