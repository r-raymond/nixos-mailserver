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

with (import ./common.nix { inherit config lib; });

let
  cfg = config.mailserver;

  maildirLayoutAppendix = lib.optionalString cfg.useFsLayout ":LAYOUT=fs";

  # maildir in format "/${domain}/${user}"
  dovecotMaildir = "maildir:${cfg.mailDirectory}/%d/%n${maildirLayoutAppendix}";

  postfixCfg = config.services.postfix;
in
{
  config = with cfg; lib.mkIf enable {
    services.dovecot2 = {
      enable = true;
      enableImap = enableImap;
      enablePop3 = enablePop3;
      enablePAM = false;
      enableQuota = true;
      mailGroup = vmailGroupName;
      mailUser = vmailUserName;
      mailLocation = dovecotMaildir;
      sslServerCert = certificatePath;
      sslServerKey = keyPath;
      enableLmtp = true;
      modules = [ pkgs.dovecot_pigeonhole ];
      protocols = [ "sieve" ];

      sieveScripts = {
        after = builtins.toFile "spam.sieve" ''
          require "fileinto";

          if header :is "X-Spam" "Yes" {
              fileinto "Junk";
              stop;
          }
        '';
      };

      mailboxes = cfg.mailboxes;

      extraConfig = ''
        #Extra Config
        ${lib.optionalString debug ''
          mail_debug = yes
          auth_debug = yes
          verbose_ssl = yes
        ''}

        protocol imap {
          mail_max_userip_connections = ${toString cfg.maxConnectionsPerUser}
        }

        protocol pop3 {
          mail_max_userip_connections = ${toString cfg.maxConnectionsPerUser}
        }

        mail_access_groups = ${vmailGroupName}
        ssl = required
        ${lib.optionalString (lib.versionAtLeast (lib.getVersion pkgs.dovecot) "2.3") ''
          ssl_dh = <${certificateDirectory}/dh.pem
        ''}

        service lmtp {
          unix_listener dovecot-lmtp {
            group = ${postfixCfg.group}
            mode = 0600
            user = ${postfixCfg.user}
          }
        }

        protocol lmtp {
          mail_plugins = $mail_plugins sieve
        }

        passdb {
          driver = passwd-file
          args = ${passwdFile}
        }

        userdb {
          driver = passwd-file
          args = ${passwdFile}
        }

        service auth {
          unix_listener auth {
            mode = 0660
            user = ${postfixCfg.user}
            group = ${postfixCfg.group}
          }
        }

        auth_mechanisms = plain login

        namespace inbox {
          separator = ${cfg.hierarchySeparator}
          inbox = yes
        }

        plugin {
          sieve = file:/var/sieve/%u/scripts;active=/var/sieve/%u/active.sieve
          sieve_default = file:/var/sieve/%u/default.sieve
          sieve_default_name = default
        }

        lda_mailbox_autosubscribe = yes
        lda_mailbox_autocreate = yes
      '';
    };
  };
}
