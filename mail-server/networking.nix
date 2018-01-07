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
in
{
  config = with cfg; lib.mkIf enable {

    networking.firewall = {
      allowedTCPPorts = [ 25 587 ]
        ++ lib.optional enableImap 143
        ++ lib.optional enableImapSsl 993
        ++ lib.optional enablePop3 110
        ++ lib.optional enablePop3Ssl 995
        ++ lib.optional enableManageSieve 4190
        ++ lib.optional (certificateScheme == 3) 80;
    };
  };
}
