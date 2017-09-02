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

{ pkgs, mail_dir, vmail_group_name, certificate_scheme, cert_dir, host_prefix,
domain, dkim_selector, dkim_dir}:

let
  create_certificate = if certificate_scheme == 2 then
        ''
          # Create certificates if they do not exist yet
          dir="${cert_dir}"
          fqdn="${host_prefix}.${domain}"
          case $fqdn in /*) fqdn=$(cat "$fqdn");; esac
          key="''${dir}/key-${domain}.pem";
          cert="''${dir}/cert-${domain}.pem";

          if [ ! -f "''${key}" ] || [ ! -f "''${cert}" ]
          then
              mkdir -p "${cert_dir}"
              (umask 077; "${pkgs.openssl}/bin/openssl" genrsa -out "''${key}" 2048) &&
                  "${pkgs.openssl}/bin/openssl" req -new -key "''${key}" -x509 -subj "/CN=''${fqdn}" \
                          -days 3650 -out "''${cert}"
          fi
        ''
        else "";

  dkim_key = "${dkim_dir}/${dkim_selector}.private";
  dkim_txt = "${dkim_dir}/${dkim_selector}.txt";
  create_dkim_cert =
        ''
          # Create dkim dir
          mkdir -p "${dkim_dir}"
          chown rmilter:rmilter "${dkim_dir}"

          if [ ! -f "${dkim_key}" ] || [ ! -f "${dkim_txt}" ]
          then

              ${pkgs.opendkim}/bin/opendkim-genkey -s "${dkim_selector}" \
                                                   -d ${domain} \
                                                   --directory="${dkim_dir}"
              chown rmilter:rmilter "${dkim_key}"
          fi
        '';
in
{
  # Make sure postfix gets started first, so that the certificates are in place
  services.dovecot2.after = [ "postfix.service" ];

  # Create certificates and maildir folder
  services.postfix = {
    preStart = 
    ''
      # Create mail directory and set permissions. See
      # <http://wiki2.dovecot.org/SharedMailboxes/Permissions>.
      mkdir -p "${mail_dir}"
      chgrp "${vmail_group_name}" "${mail_dir}"
      chmod 02770 "${mail_dir}"

      ${create_certificate}
    '';
  };

  # Create dkim certificates
  services.rmilter = {
    preStart =
    ''
      ${create_dkim_cert}
    '';
  };
}
