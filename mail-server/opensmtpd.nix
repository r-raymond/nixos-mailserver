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

with (import ./common.nix { inherit config; });

let
  inherit (lib.strings) concatStringsSep;
  cfg = config.mailserver;

  # valiases_postfix :: [ String ]
  valiases_postfix = lib.flatten (lib.mapAttrsToList
    (name: value:
      let to = name;
          in map (from: "${from} ${to}") value.aliases)
    cfg.loginAccounts);

  vmailMaps = lib.flatten (lib.mapAttrsToList
    (name: value: "${name} ${cfg.vmailUserName}") cfg.loginAccounts);

  # catchAllPostfix :: [ String ]
  catchAllPostfix = lib.flatten (lib.mapAttrsToList
    (name: value:
      let to = name;
          in map (from: "@${from} ${to}") value.catchAll)
    cfg.loginAccounts);

  # extra_valiases_postfix :: [ String ]
  # TODO: Remove virtualAliases when deprecated -> removed
  extra_valiases_postfix = (map
    (from:
      let to = cfg.virtualAliases.${from};
      in "${from} ${to}")
    (builtins.attrNames cfg.virtualAliases))
    ++
    (map
    (from:
      let to = cfg.extraVirtualAliases.${from};
      in "${from} ${to}")
    (builtins.attrNames cfg.extraVirtualAliases));

  # all_valiases_postfix :: [ String ]
  all_valiases_postfix = valiases_postfix ++ extra_valiases_postfix ++ catchAllPostfix ++ vmailMaps;

  # accountToIdentity :: User -> String
  accountToIdentity = account: "${account.name} ${account.name}";

  # vaccounts_identity :: [ String ]
  vaccounts_identity = map accountToIdentity (lib.attrValues cfg.loginAccounts);

  # valiases_file :: Path
  valiases_file = builtins.toFile "valias"
                      (lib.concatStringsSep "\n" all_valiases_postfix);

  # vhosts_file :: Path
  vhosts_file = builtins.toFile "vhosts" (concatStringsSep "\n" cfg.domains);

  passwdList = lib.flatten (lib.mapAttrsToList (name : value:
                        "${name}:${value.hashedPassword}:5000:5000::/var/vmail/:/run/current-system/sw/bin/nologin")
                        cfg.loginAccounts);
  passwd = lib.concatStringsSep "\n" passwdList;


  example = 
    ''
    user1@example.com:$6$IsXn9Xe2kUTPETVl$Z.gkkqpwi95/ZsL/FXZaAjMjdv03m5jae6v8Pv7aaNnzdzNd01nbgt3HtKnaS10hZTbXgumqdQyTU0m1wkr76.:5000:5000::/var/vmail:/run/current-system/sw/bin/nologin
    '';

  passwd_file = builtins.toFile "passwd" passwd;

  # vaccounts_file :: Path
  # see
  # https://blog.grimneko.de/2011/12/24/a-bunch-of-tips-for-improving-your-postfix-setup/
  # for details on how this file looks. By using the same file as valiases,
  # every alias is owned (uniquely) by its user. We have to add the users own
  # address though
  vaccounts_file = builtins.toFile "vaccounts" (lib.concatStringsSep "\n"
  (vaccounts_identity ++ all_valiases_postfix));

  submissionHeaderCleanupRules = pkgs.writeText "submission_header_cleanup_rules" ''
     # Removes sensitive headers from mails handed in via the submission port.
     # See https://thomas-leister.de/mailserver-debian-stretch/
     # Uses "pcre" style regex.

     /^Received:/            IGNORE
     /^X-Originating-IP:/    IGNORE
     /^X-Mailer:/            IGNORE
     /^User-Agent:/          IGNORE
     /^X-Enigmail:/          IGNORE
  '';
in
{
  config = with cfg; lib.mkIf enable {

    services.opensmtpd = {
      enable = true;
      procPackages = [ pkgs.opensmtpd-extras ];
      extraServerArgs = [ "-v" ];
      serverConfiguration =
        ''
          # pki setup
          pki ${fqdn} certificate "${certificatePath}"
          pki ${fqdn} key "${keyPath}"

          # tables setup
          # table aliases file:/etc/mail/aliases
          table domains file:${vhosts_file}
          table passwd passwd:${passwd_file}
          table virtuals file:${valiases_file}

          # # listen ports setup
          listen on 0.0.0.0 port 25 tls pki ${fqdn}
          listen on 0.0.0.0 port 587 tls-require pki ${fqdn} auth <passwd> received-auth

          # allow local messages
          accept from any for domain <domains> virtual <virtuals> deliver to lmtp "/run/dovecot/lmtp" rcpt-to

          # DKIM
          listen on lo hostname ${fqdn}
          listen on lo port 10028 tag DKIM hostname ${fqdn}

          accept tagged DKIM \
            for any \
            relay \
            hostname ${fqdn}
          accept from local \
            for any \
            relay via smtp://127.0.0.1:10027
        '';
    };
  };
}
