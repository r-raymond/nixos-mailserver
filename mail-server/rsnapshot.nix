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

  preexecDefined = cfg.backup.cmdPreexec != null;
  preexecWrapped = pkgs.writeScript "rsnapshot-preexec.sh" ''
    #!${pkgs.stdenv.shell}
    set -e

    ${cfg.backup.cmdPreexec}
  '';
  preexecString = optionalString preexecDefined "cmd_preexec	${preexecWrapped}";

  postexecDefined = cfg.backup.cmdPostexec != null;
  postexecWrapped = pkgs.writeScript "rsnapshot-postexec.sh" ''
    #!${pkgs.stdenv.shell}
    set -e

    ${cfg.backup.cmdPostexec}
  '';
  postexecString = optionalString postexecDefined "cmd_postexec	${postexecWrapped}";
in {
  config = mkIf (cfg.enable && cfg.backup.enable) {
    services.rsnapshot = {
      enable = true;
      cronIntervals = cfg.backup.cronIntervals;
      # rsnapshot expects intervals shortest first, e.g. hourly first, then daily.
      # tabs must separate all elements
      extraConfig = ''
        ${preexecString}
        ${postexecString}
        snapshot_root	${cfg.backup.snapshotRoot}/
        retain	hourly	${toString cfg.backup.retain.hourly}
        retain	daily	${toString cfg.backup.retain.daily}
        retain	weekly	${toString cfg.backup.retain.weekly}
        backup	${cfg.mailDirectory}/	localhost/
      '';
    };
  };
}
