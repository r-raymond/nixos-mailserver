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

{ pkgs, mailDirectory, vmailGroupName, certificateScheme, certificateDirectory, hostPrefix,
domain, dkimSelector, dkimKeyDirectory}:

let
  create_certificate = if certificateScheme == 2 then
        ''
          # Create certificates if they do not exist yet
          dir="${certificateDirectory}"
          fqdn="${hostPrefix}.${domain}"
          case $fqdn in /*) fqdn=$(cat "$fqdn");; esac
          key="''${dir}/key-${domain}.pem";
          cert="''${dir}/cert-${domain}.pem";

          if [ ! -f "''${key}" ] || [ ! -f "''${cert}" ]
          then
              mkdir -p "${certificateDirectory}"
              (umask 077; "${pkgs.openssl}/bin/openssl" genrsa -out "''${key}" 2048) &&
                  "${pkgs.openssl}/bin/openssl" req -new -key "''${key}" -x509 -subj "/CN=''${fqdn}" \
                          -days 3650 -out "''${cert}"
          fi
        ''
        else "";

  dkim_key = "${dkimKeyDirectory}/${dkimSelector}.private";
  dkim_txt = "${dkimKeyDirectory}/${dkimSelector}.txt";
  create_dkim_cert =
        ''
          # Create dkim dir
          mkdir -p "${dkimKeyDirectory}"
          chown rmilter:rmilter "${dkimKeyDirectory}"

          if [ ! -f "${dkim_key}" ] || [ ! -f "${dkim_txt}" ]
          then

              ${pkgs.opendkim}/bin/opendkim-genkey -s "${dkimSelector}" \
                                                   -d ${domain} \
                                                   --directory="${dkimKeyDirectory}"
              chown rmilter:rmilter "${dkim_key}"
          fi
        '';
in
{
  # Set the correct permissions for dovecot vmail folder. See
  # <http://wiki2.dovecot.org/SharedMailboxes/Permissions>. We choose
  # to use the systemd service to set the folder permissions whenever
  # dovecot gets started.
  services.dovecot2.after = [ "postfix.service" ];

  # Check for certificate before both postfix and dovecot to make sure it
  # exists.
  services.postfix = {
    preStart = 
    ''
      # Create mail directory and set permissions
      mkdir -p "${mailDirectory}"
      chgrp "${vmailGroupName}" "${mailDirectory}"
      chmod 02770 "${mailDirectory}"

      ${create_certificate}
    '';
  };

  services.rmilter = {
    preStart =
    ''
      ${create_dkim_cert}
    '';
  };
}
