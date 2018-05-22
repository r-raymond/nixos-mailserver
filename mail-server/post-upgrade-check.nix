#  nixos-mailserver: a simple mail server
#  Copyright (C) 2016-2018  Robin Raymond
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <http://www.gnu.org/licenses/>

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.mailserver;
in
{
  config = mkIf (cfg.enable && cfg.rebootAfterKernelUpgrade.enable) {
    systemd.services.nixos-upgrade.serviceConfig.ExecStartPost = pkgs.writeScript "post-upgrade-check" ''
      #!${pkgs.stdenv.shell}

      # Checks whether the "current" kernel is different from the booted kernel
      # and then triggers a reboot so that the "current" kernel will be the booted one.
      # This is just an educated guess. If the links do not differ the kernels might still be different, according to spacefrogg in #nixos.

      current=$(readlink -f /run/current-system/kernel)
      booted=$(readlink -f /run/booted-system/kernel)

      if [ "$current" == "$booted" ]; then
        echo "kernel version seems unchanged, skipping reboot" | systemd-cat --priority 4 --identifier "post-upgrade-check";
      else
        echo "kernel path changed, possibly a new version" | systemd-cat --priority 2 --identifier "post-upgrade-check"
        echo "$booted" | systemd-cat --priority 2 --identifier "post-upgrade-kernel-check"
        echo "$current" | systemd-cat --priority 2 --identifier "post-upgrade-kernel-check"
        ${cfg.rebootAfterKernelUpgrade.method}
      fi
    '';
  };
}
