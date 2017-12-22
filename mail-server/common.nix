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

{ config, lib }:

let
  cfg = config.mailserver;
  # passwd :: [ String ]
  passwd = lib.mapAttrsToList
    (name: value: "${name}:${value.hashedPassword}:${builtins.toString cfg.vmailUID}:${builtins.toString cfg.vmailUID}::${cfg.mailDirectory}:/run/current-system/sw/bin/nologin:")
            cfg.loginAccounts;
in
{
  # cert :: PATH
  certificatePath = if cfg.certificateScheme == 1
             then cfg.certificateFile
             else if cfg.certificateScheme == 2
                  then "${cfg.certificateDirectory}/cert-${cfg.fqdn}.pem"
                  else if cfg.certificateScheme == 3
                       then "/var/lib/acme/${cfg.fqdn}/fullchain.pem"
                       else throw "Error: Certificate Scheme must be in { 1, 2, 3 }";

  # key :: PATH
  keyPath = if cfg.certificateScheme == 1
        then cfg.keyFile
        else if cfg.certificateScheme == 2
             then "${cfg.certificateDirectory}/key-${cfg.fqdn}.pem"
              else if cfg.certificateScheme == 3
                   then "/var/lib/acme/${cfg.fqdn}/key.pem"
                   else throw "Error: Certificate Scheme must be in { 1, 2, 3 }";
  # passwdFile :: PATH
  passwdFile = builtins.toFile "passwd" (lib.concatStringsSep "\n" passwd);
}
