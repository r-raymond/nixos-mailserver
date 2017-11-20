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
  cfg = config.mailserver;

  # maildir in format "/${domain}/${user}"
  dovecot_maildir = "maildir:${cfg.mailDirectory}/%d/%n";

in
{
  config = with cfg; lib.mkIf enable {
    services.dovecot2 = {
      enable = true;
      enableImap = enableImap;
      enablePop3 = enablePop3;
      mailGroup = vmailGroupName;
      mailUser = vmailUserName;
      mailLocation = dovecot_maildir;
      sslServerCert = certificatePath;
      sslServerKey = keyPath;
      enableLmtp = true;
      modules = [ pkgs.dovecot_pigeonhole ];
      protocols = [ "sieve" ];

      sieveScripts = {
        before = builtins.toFile "spam.sieve" ''
          require "fileinto";

          if header :is "X-Spam" "Yes" {
              fileinto "Junk";
              stop;
          }
        '';
      };

      extraConfig = ''
        #Extra Config
        ${lib.optionalString debug ''
          mail_debug = yes
          auth_debug = yes
          verbose_ssl = yes
        ''}

        mail_access_groups = ${vmailGroupName}
        ssl = required

        service lmtp {
          unix_listener /var/lib/postfix/queue/private/dovecot-lmtp {
            group = postfix
            mode = 0600
            user = postfix  # TODO: < make variable
          }
        }

        protocol lmtp {
          mail_plugins = $mail_plugins sieve
        }

        service auth {
          unix_listener /var/lib/postfix/queue/private/auth {
            mode = 0660
            user = postfix  # TODO: < make variable
            group = postfix  # TODO: < make variable
          }
        }

        auth_mechanisms = plain login

        namespace inbox {
          inbox = yes

          mailbox "Trash" {
            auto = no
            special_use = \Trash
          }

          mailbox "Junk" {
            auto = subscribe
            special_use = \Junk
          }

          mailbox "Drafts" {
            auto = subscribe
            special_use = \Drafts
          }

          mailbox "Sent" {
            auto = subscribe
            special_use = \Sent
          }
        }

        plugin {
          sieve = file:/var/sieve/%u.sieve
        }
      '';
    };
  };
}
