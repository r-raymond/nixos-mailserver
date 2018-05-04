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

let
  cfg = config.mailserver;

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

  createDhParameterFile = let
     dovecotVersion = builtins.fromJSON
       (builtins.readFile (pkgs.callPackage ./dovecot-version.nix {}));
    in lib.optionalString
      (dovecotVersion.major == 2 && dovecotVersion.minor >= 3)
      ''
        # Create a dh parameter file
        if [ ! -s "${cfg.certificateDirectory}/dh.pem" ]
        then
            mkdir -p "${cfg.certificateDirectory}"
            ${pkgs.openssl}/bin/openssl \
                  dhparam ${builtins.toString cfg.dhParamBitLength} \
                  > "${cfg.certificateDirectory}/dh.pem"
        fi
      '';

  preliminarySelfsigned = config.security.acme.preliminarySelfsigned;
  acmeWantsTarget = [ "acme-certificates.target" ]
    ++ (lib.optional preliminarySelfsigned "acme-selfsigned-certificates.target");
  acmeAfterTarget = if preliminarySelfsigned
    then [ "acme-selfsigned-certificates.target" ]
    else [ "acme-certificates.target" ];
in
{
  config = with cfg; lib.mkIf enable {
    # Add target for when certificates are available
    systemd.targets."mailserver-certificates" = {
      wants = lib.mkIf (cfg.certificateScheme == 3) acmeWantsTarget;
      after = lib.mkIf (cfg.certificateScheme == 3) acmeAfterTarget;
    };

    # Create self signed certificate
    systemd.services.mailserver-selfsigned-certificate = lib.mkIf (cfg.certificateScheme == 2) {
      wantedBy = [ "mailserver-certificates.target" ];
      after    = [ "local-fs.target" ];
      before   = [ "mailserver-certificates.target" ];
      script = ''
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
      '';
      serviceConfig = {
        Type = "oneshot";
        PrivateTmp = true;
      };
    };

    # Create maildir folder and dh parameters before dovecot startup
    systemd.services.dovecot2 = {
      after = [ "mailserver-certificates.target" ];
      wants = [ "mailserver-certificates.target" ];
      preStart = ''
        # Create mail directory and set permissions. See
        # <http://wiki2.dovecot.org/SharedMailboxes/Permissions>.
        mkdir -p "${mailDirectory}"
        chgrp "${vmailGroupName}" "${mailDirectory}"
        chmod 02770 "${mailDirectory}"

        ${createDhParameterFile}
      '';
    };

    # Postfix requires rmilter socket, dovecot lmtp socket, dovecot auth socket and certificate to work
    systemd.services.postfix = {
      after = [ "rmilter.socket" "dovecot2.service" "mailserver-certificates.target" ];
      wants = [ "mailserver-certificates.target" ];
      requires = [ "rmilter.socket" "dovecot2.service" ];
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
