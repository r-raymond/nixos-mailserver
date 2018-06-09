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

let
  cfg = config.mailserver.borgbackup;

  methodFragment = lib.optional (cfg.compression.method != null) cfg.compression.method;
  autoFragment =
    if cfg.compression.auto && cfg.compression.method == null
    then throw "compression.method must be set when using auto."
    else lib.optional cfg.compression.auto "auto";
  levelFragment =
    if cfg.compression.level != null && cfg.compression.method == null
    then throw "compression.method must be set when using compression.level."
    else lib.optional (cfg.compression.level != null) (toString cfg.compression.level);
  compressionFragment = lib.concatStringsSep "," (lib.flatten [autoFragment methodFragment levelFragment]);
  compression = lib.optionalString (compressionFragment != "") "--compression ${compressionFragment}";

  encryptionFragment = cfg.encryption.method;
  passphraseFile = lib.escapeShellArg cfg.encryption.passphraseFile;
  passphraseFragment = lib.optionalString (cfg.encryption.method != "none")
                         (if cfg.encryption.passphraseFile != null then ''env BORG_PASSPHRASE="$(cat ${passphraseFile})"''
                          else throw "passphraseFile must be set when using encryption.");

  locations = lib.escapeShellArgs cfg.locations;
  name = lib.escapeShellArg cfg.name;

  repoLocation = lib.escapeShellArg cfg.repoLocation;

  extraInitArgs = lib.escapeShellArgs cfg.extraArgumentsForInit;
  extraCreateArgs = lib.escapeShellArgs cfg.extraArgumentsForCreate;

  cmdPreexec = lib.optionalString (cfg.cmdPreexec != null) cfg.cmdPreexec;
  cmdPostexec = lib.optionalString (cfg.cmdPostexec != null) cfg.cmdPostexec;

  borgScript = ''
    export BORG_REPO=${repoLocation}
    ${cmdPreexec}
    ${passphraseFragment} ${pkgs.borgbackup}/bin/borg init ${extraInitArgs} --encryption ${encryptionFragment} || true
    ${passphraseFragment} ${pkgs.borgbackup}/bin/borg create ${extraCreateArgs} ${compression} ::${name} ${locations}
    ${cmdPostexec}
  '';
in {
  config = lib.mkIf (config.mailserver.enable && cfg.enable) {
    environment.systemPackages = with pkgs; [
      borgbackup
    ];

    systemd.services.borgbackup = {
      description = "borgbackup";
      unitConfig.Documentation = "man:borgbackup";
      script = borgScript;
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
        ProtectSystem = "full";
      };
      startAt = cfg.startAt;
    };
  };
}
