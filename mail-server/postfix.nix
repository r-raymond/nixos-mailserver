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

{ mail_dir, domain, valiases }:

let
  # valiasToString :: { from = "..."; to = "..." } -> String
  valiasToString = x: "${x.from}@${domain} ${x.to}@${domain}\n";

  # valiases_postfix :: [ String ]
  valiases_postfix = map valiasToString valiases;

  # concatString :: [ String ] -> String
  concatString = l: if l == []
                    then ""
                    else (builtins.head l) + (concatString (builtins.tail l));

  # valiases_file :: Path
  valiases_file = builtins.toFile "valias" (concatString valiases_postfix);

  # vhosts_file :: Path
  vhosts_file = builtins.toFile "vhosts" domain;
in
{
  enable = true;
  networksStyle = "host";
  mapFiles."valias" = valiases_file;
  #  mapFiles."vaccounts" = vaccounts_file; 
  #  sslCert = "/etc/nixos/cert/${cert_file}";
  #  sslKey = "/etc/nixos/cert/${key_file}";

  extraConfig = 
  ''

    # Extra Config

    smtpd_banner = $myhostname ESMTP NO UCE
    smtpd_tls_auth_only = yes
    disable_vrfy_command = yes
    message_size_limit = 20971520

    milter_rcpt_macros = i {rcpt_addr}

    # virtual mail system
    virtual_uid_maps = static:5000
    virtual_gid_maps = static:5000
    virtual_mailbox_base = ${mail_dir}
    virtual_mailbox_domains = ${vhosts_file}
    virtual_alias_maps = hash:/var/lib/postfix/conf/valias
    virtual_transport = lmtp:unix:private/dovecot-lmtp

    # sasl with dovecot
    smtpd_sasl_type = dovecot
    smtpd_sasl_path = private/auth
    smtpd_sasl_auth_enable = yes
    smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination
  '';

  extraMasterConf =
  ''
    # Extra Config
    #submission inet n - n - - smtpd
    #  -o smtpd_tls_security_level=encrypt
    #  -o smtpd_sasl_auth_enable=yes
    #  -o smtpd_sasl_type=dovecot
    #  -o smtpd_sasl_path=private/auth
    #  -o smtpd_sasl_security_options=noanonymous
    #  -o smtpd_sasl_local_domain=$myhostname
    #  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
    #  -o smtpd_sender_login_maps=hash:/etc/postfix/virtual
    #  -o smtpd_sender_restrictions=reject_sender_login_mismatch
    #  -o smtpd_recipient_restrictions=reject_non_fqdn_recipient,reject_unknown_recipient_domain,permit_sasl_authenticated,reject
  '';
}
