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
  inherit (lib.strings) concatStringsSep;
  cfg = config.mailserver;

  # valiases_postfix :: [ String ]
  valiases_postfix = lib.flatten (lib.mapAttrsToList
    (name: value:
      let to = name;
          in map (from: "${from} ${to}") (value.aliases ++ lib.singleton name))
    cfg.loginAccounts);

  # catchAllPostfix :: [ String ]
  catchAllPostfix = lib.flatten (lib.mapAttrsToList
    (name: value:
      let to = name;
          in map (from: "@${from} ${to}") value.catchAll)
    cfg.loginAccounts);

  # extra_valiases_postfix :: [ String ]
  extra_valiases_postfix =
    (map
    (from:
      let to = cfg.extraVirtualAliases.${from};
          aliasList = (l: let aliasStr = builtins.foldl' (x: y: x + y + ", ") "" l;
                          in builtins.substring 0 (builtins.stringLength aliasStr - 2) aliasStr);
      in if (builtins.isList to) then "${from} " + (aliasList to)
                                 else "${from} ${to}")
    (builtins.attrNames cfg.extraVirtualAliases));

  # all_valiases_postfix :: [ String ]
  all_valiases_postfix = valiases_postfix ++ extra_valiases_postfix;

  # valiases_file :: Path
  valiases_file = builtins.toFile "valias"
                      (lib.concatStringsSep "\n" (all_valiases_postfix ++
                                                  catchAllPostfix));

  reject_recipients_postfix = (map
    (recipient:
      "${recipient} REJECT")
    (cfg.rejectRecipients));
  # rejectRecipients :: [ Path ]
  reject_recipients_file = builtins.toFile "reject_recipients" (lib.concatStringsSep "\n" (reject_recipients_postfix))  ;

  # vhosts_file :: Path
  vhosts_file = builtins.toFile "vhosts" (concatStringsSep "\n" cfg.domains);

  # vaccounts_file :: Path
  # see
  # https://blog.grimneko.de/2011/12/24/a-bunch-of-tips-for-improving-your-postfix-setup/
  # for details on how this file looks. By using the same file as valiases,
  # every alias is owned (uniquely) by its user. 
  # The user's own address is already in all_valiases_postfix.
  vaccounts_file = builtins.toFile "vaccounts" (lib.concatStringsSep "\n" all_valiases_postfix);

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

    services.postfix = {
      enable = true;
      hostname = "${fqdn}";
      networksStyle = "host";
      mapFiles."valias" = valiases_file;
      mapFiles."vaccounts" = vaccounts_file;
      mapFiles."reject_recipients" = reject_recipients_file;
      sslCert = certificatePath;
      sslKey = keyPath;
      enableSubmission = true;

      extraConfig =
      ''
        # Extra Config
        mydestination =

        smtpd_banner = ${fqdn} ESMTP NO UCE
        disable_vrfy_command = yes
        message_size_limit = 20971520

        # virtual mail system
        virtual_uid_maps = static:5000
        virtual_gid_maps = static:5000
        virtual_mailbox_base = ${mailDirectory}
        virtual_mailbox_domains = ${vhosts_file}
        virtual_mailbox_maps = hash:/var/lib/postfix/conf/valias
        virtual_alias_maps = hash:/var/lib/postfix/conf/valias
        virtual_transport = lmtp:unix:private/dovecot-lmtp

        # sasl with dovecot
        smtpd_sasl_type = dovecot
        smtpd_sasl_path = private/auth
        smtpd_sasl_auth_enable = yes
        smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination

        # reject selected recipients, quota
        smtpd_recipient_restrictions = check_recipient_access hash:/var/lib/postfix/conf/reject_recipients, check_policy_service inet:localhost:12340

        # TLS settings, inspired by https://github.com/jeaye/nix-files
        # Submission by mail clients is handled in submissionOptions
        smtpd_tls_security_level = may
        # strong might suffice and is computationally less expensive
        smtpd_tls_eecdh_grade = ultra
        # Disable predecessors to TLS
        smtpd_tls_protocols = !SSLv2, !SSLv3
        # Allowing AUTH on a non encrypted connection poses a security risk
        smtpd_tls_auth_only = yes
        # Log only a summary message on TLS handshake completion
        smtpd_tls_loglevel = 1

        # Disable weak ciphers as reported by https://ssl-tools.net
        # https://serverfault.com/questions/744168/how-to-disable-rc4-on-postfix
        smtpd_tls_exclude_ciphers = RC4, aNULL
        smtp_tls_exclude_ciphers = RC4, aNULL

        # Configure a non blocking source of randomness
        tls_random_source = dev:/dev/urandom
      '';

      submissionOptions =
      {
        smtpd_tls_security_level = "encrypt";
        smtpd_sasl_auth_enable = "yes";
        smtpd_sasl_type = "dovecot";
        smtpd_sasl_path = "private/auth";
        smtpd_sasl_security_options = "noanonymous";
        smtpd_sasl_local_domain = "$myhostname";
        smtpd_client_restrictions = "permit_sasl_authenticated,reject";
        smtpd_sender_login_maps = "hash:/etc/postfix/vaccounts";
        smtpd_sender_restrictions = "reject_sender_login_mismatch";
        smtpd_recipient_restrictions = "reject_non_fqdn_recipient,reject_unknown_recipient_domain,permit_sasl_authenticated,reject";
        cleanup_service_name = "submission-header-cleanup";
      };

      extraMasterConf = ''
        submission-header-cleanup unix n - n    -       0       cleanup
            -o header_checks=pcre:${submissionHeaderCleanupRules}
      '';
    };
  };
}
