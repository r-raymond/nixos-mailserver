#  nixos-mailserver: a simple mail server
#  Copyright (C) 2016-2017  Robin Raymond
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

with config.mailserver;

let
  vmail_user = {
    name = vmailUserName;
    isNormalUser = false;
    uid = vmailUID;
    home = mailDirectory;
    createHome = true;
    group = vmailGroupName;
  };

  # accountsToUser :: String -> UserRecord
  accountsToUser = account: {
    isNormalUser = false;
    group = vmailGroupName;
    inherit (account) hashedPassword name;
  };

  # mail_users :: { [String]: UserRecord }
  mail_users = lib.foldl (prev: next: prev // { "${next.name}" = next; }) {}
    (map accountsToUser (lib.attrValues loginAccounts));

  virtualMailUsersActivationScript = pkgs.writeScript "activate-virtual-mail-users" ''
    #!${pkgs.stdenv.shell}

    set -euo pipefail

    # Create directory to store user sieve scripts if it doesn't exist
    if (! test -d "/var/sieve"); then
      mkdir "/var/sieve"
      chown "${vmailUserName}:${vmailGroupName}" "/var/sieve"
      chmod 770 "/var/sieve"
    fi

    # Copy user's sieve script to the correct location (if it exists).  If it
    # is null, remove the file.
    ${lib.concatMapStringsSep "\n" ({ name, sieveScript }:
      if lib.isString sieveScript then ''
        if (! test -d "/var/sieve/${name}"); then
          mkdir -p "/var/sieve/${name}"
          chown "${name}:${vmailGroupName}" "/var/sieve/${name}"
          chmod 770 "/var/sieve/${name}"
        fi
        cat << EOF > "/var/sieve/${name}/default.sieve"
        ${sieveScript}
        EOF
        chown "${name}:${vmailGroupName}" "/var/sieve/${name}/default.sieve"
      '' else ''
        if (test -f "/var/sieve/${name}/default.sieve"); then
          rm "/var/sieve/${name}/default.sieve"
        fi
        if (test -f "/var/sieve/${name}.svbin"); then
          rm "/var/sieve/${name}/default.svbin"
        fi
      '') (map (user: { inherit (user) name sieveScript; })
            (lib.attrValues loginAccounts))}
  '';
in {
  config = lib.mkIf enable {
    # set the vmail gid to a specific value
    users.groups = {
      "${vmailGroupName}" = { gid = vmailUID; };
    };

    # define all users
    users.users = mail_users // {
      "${vmail_user.name}" = lib.mkForce vmail_user;
    };

    systemd.services.activate-virtual-mail-users = {
      wantedBy = [ "multi-user.target" ];
      before = [ "dovecot2.service" ];
      serviceConfig = {
        ExecStart = virtualMailUsersActivationScript;
      };
      enable = true;
    };
  };
}
