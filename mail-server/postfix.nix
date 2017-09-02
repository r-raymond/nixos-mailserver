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

{ lib, mailDirectory, domain, virtualAliases, cert, key }:

let
  # valiases_postfix :: [ String ]
  valiases_postfix = map
    (from:
      let to = virtualAliases.${from};
      in "${from}@${domain} ${to}@${domain}")
    (builtins.attrNames virtualAliases);

  # valiases_file :: Path
  valiases_file = builtins.toFile "valias" (lib.concatStringsSep "\n" valiases_postfix);

  # vhosts_file :: Path
  vhosts_file = builtins.toFile "vhosts" domain;

  # vaccounts_file :: Path
  # see
  # https://blog.grimneko.de/2011/12/24/a-bunch-of-tips-for-improving-your-postfix-setup/
  # for details on how this file looks. By using the same file as valiases,
  # every alias is owned (uniquely) by its user.
  vaccounts_file = valiases_file;

in
{
  enable = true;
  networksStyle = "host";
  mapFiles."valias" = valiases_file;
  mapFiles."vaccounts" = vaccounts_file; 
  sslCert = cert;
  sslKey = key;
  enableSubmission = true;

  extraConfig = 
  ''

    # Extra Config

    smtpd_banner = $myhostname ESMTP NO UCE
    smtpd_tls_auth_only = yes
    disable_vrfy_command = yes
    message_size_limit = 20971520

    # virtual mail system
    virtual_uid_maps = static:5000
    virtual_gid_maps = static:5000
    virtual_mailbox_base = ${mailDirectory}
    virtual_mailbox_domains = ${vhosts_file}
    virtual_alias_maps = hash:/var/lib/postfix/conf/valias
    virtual_transport = lmtp:unix:private/dovecot-lmtp

    # sasl with dovecot
    smtpd_sasl_type = dovecot
    smtpd_sasl_path = private/auth
    smtpd_sasl_auth_enable = yes
    smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination
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
  };
}
