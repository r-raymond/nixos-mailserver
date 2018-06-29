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
  dovecot2Cfg = config.services.dovecot2;

  stateDir = "/var/lib/dovecot";

  pipeBin = pkgs.stdenv.mkDerivation {
    name = "pipe_bin";
    src = ./dovecot/pipe_bin;
    buildInputs = with pkgs; [ makeWrapper coreutils bash rspamd ];
    buildCommand = ''
      mkdir -p $out/pipe/bin
      cp $src/* $out/pipe/bin/
      chmod a+x $out/pipe/bin/*
      patchShebangs $out/pipe/bin

      for file in $out/pipe/bin/*; do
        wrapProgram $file \
          --set PATH "${pkgs.coreutils}/bin:${pkgs.rspamd}/bin"
      done
    '';
  };
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
          mail_plugins = $mail_plugins imap_sieve
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
          sieve_plugins = sieve_imapsieve sieve_extprograms
          sieve = file:/var/sieve/%u/scripts;active=/var/sieve/%u/active.sieve
          sieve_default = file:/var/sieve/%u/default.sieve
          sieve_default_name = default

          # From elsewhere to Spam folder
          imapsieve_mailbox1_name = Junk
          imapsieve_mailbox1_causes = COPY
          imapsieve_mailbox1_before = file:${stateDir}/imap_sieve/report-spam.sieve

          # From Spam folder to elsewhere
          imapsieve_mailbox2_name = *
          imapsieve_mailbox2_from = Junk
          imapsieve_mailbox2_causes = COPY
          imapsieve_mailbox2_before = file:${stateDir}/imap_sieve/report-ham.sieve

          sieve_pipe_bin_dir = ${pipeBin}/pipe/bin

          sieve_global_extensions = +vnd.dovecot.pipe +vnd.dovecot.environment
        }

        lda_mailbox_autosubscribe = yes
        lda_mailbox_autocreate = yes
      '';
    };

    systemd.services.dovecot2.preStart = ''
      rm -rf '${stateDir}/imap_sieve'
      mkdir '${stateDir}/imap_sieve'
      cp -p "${./dovecot/imap_sieve}"/*.sieve '${stateDir}/imap_sieve/'
      for k in "${stateDir}/imap_sieve"/*.sieve ; do
        ${pkgs.dovecot_pigeonhole}/bin/sievec "$k"
      done
      chown -R '${dovecot2Cfg.mailUser}:${dovecot2Cfg.mailGroup}' '${stateDir}/imap_sieve'
    '';
  };
}
