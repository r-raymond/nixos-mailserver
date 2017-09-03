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
        builtins.readFile ./script/create_certificate
        else "";

  dkim_key = "${cfg.dkimKeyDirectory}/${cfg.dkimSelector}.private";
  dkim_txt = "${cfg.dkimKeyDirectory}/${cfg.dkimSelector}.txt";
  create_dkim_cert = builtins.readFile ./script/create_dkim_certificate;
in
{
  config = with cfg; lib.mkIf enable {
    # Make sure postfix gets started first, so that the certificates are in place
    systemd.services.dovecot2.after = [ "postfix.service" ];

    # Create certificates and maildir folder
    systemd.services.postfix = {
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
      preStart =
      ''
        ${create_dkim_cert}
      '';
    };

  };
}
