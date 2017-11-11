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

let
  cfg = config.mailserver;

  create_certificate = if cfg.certificateScheme == 2 then
        ''
          # Create certificates if they do not exist yet
          dir="${cfg.certificateDirectory}"
          fqdn="${cfg.fqdn}"
          case $fqdn in /*) fqdn=$(cat "$fqdn");; esac
          key="''${dir}/key-${cfg.fqdn}.pem";
          cert="''${dir}/cert-${cfg.fqdn}.pem";

          if [ ! -f "''${key}" ] || [ ! -f "''${cert}" ]
          then
              mkdir -p "${cfg.certificateDirectory}"
              (umask 077; "${pkgs.openssl}/bin/openssl" genrsa -out "''${key}" 2048) &&
                  "${pkgs.openssl}/bin/openssl" req -new -key "''${key}" -x509 -subj "/CN=''${fqdn}" \
                          -days 3650 -out "''${cert}"
          fi
        ''
        else "";

  createDomainDkimCert = dom:
    let
      dkim_key = "${cfg.dkimKeyDirectory}/${dom}.${cfg.dkimSelector}.key";
      dkim_txt = "${cfg.dkimKeyDirectory}/${dom}.${cfg.dkimSelector}.txt";
    in
        ''
          if [ ! -f "${dkim_key}" ] || [ ! -f "${dkim_txt}" ]
          then
              ${pkgs.opendkim}/bin/opendkim-genkey -s "${cfg.dkimSelector}" \
                                                   -d "${dom}" \
                                                   --directory="${cfg.dkimKeyDirectory}"
              mv "${cfg.dkimKeyDirectory}/${cfg.dkimSelector}.private" "${dkim_key}"
              mv "${cfg.dkimKeyDirectory}/${cfg.dkimSelector}.txt" "${dkim_txt}"
          fi
        '';
  createAllCerts = lib.concatStringsSep "\n" (map createDomainDkimCert cfg.domains);
  create_dkim_cert =
        ''
          # Create dkim dir
          mkdir -p "${cfg.dkimKeyDirectory}"
          chown rmilter:rmilter "${cfg.dkimKeyDirectory}"

          ${createAllCerts}

          chown -R rmilter:rmilter "${cfg.dkimKeyDirectory}"
        '';
in
{
  config = with cfg; lib.mkIf enable {
    # Make sure postfix gets started first, so that the certificates are in place
    systemd.services.dovecot2.after = [ "postfix.service" ];

    # Create certificates and maildir folder
    systemd.services.postfix = {
      after = (if (certificateScheme == 3) then [ "nginx.service" ] else []);
      preStart =
      ''
      # Create mail directory and set permissions. See
      # <http://wiki2.dovecot.org/SharedMailboxes/Permissions>.
      mkdir -p "${mailDirectory}"
      chgrp "${vmailGroupName}" "${mailDirectory}"
      chmod 02770 "${mailDirectory}"

        ${create_certificate}
      '';
    };

    # Create dkim certificates
    systemd.services.rmilter = {
      requires = [ "rmilter.socket" ];
      after = [ "rmilter.socket" ];
      preStart =
      ''
        ${create_dkim_cert}
      '';
    };
  };
}
