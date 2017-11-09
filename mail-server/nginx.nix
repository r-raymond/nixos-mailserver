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

with (import ./common.nix { inherit config; });

let
  inherit (lib.attrsets) genAttrs;
  cfg = config.mailserver;
  allDomains = [ cfg.domain ] ++ cfg.extraDomains;
  acmeRoot = "/var/lib/acme/acme-challenge";
in
{
  config = with cfg; lib.mkIf (certificateScheme == 3) {
    services.nginx = {
      enable = true;
      virtualHosts = genAttrs allDomains (domain: {
           serverName = "${hostPrefix}.${domain}";
           forceSSL = true;
           enableACME = true;
           locations."/" = {
             root = "/var/www";
           };
           acmeRoot = acmeRoot;
       });
    };
    security.acme.certs."mailserver" = {
      # @todo what user/group should this run as?
      user = "postfix"; # cfg.user;
      group = "postfix"; # lib.mkDefault cfg.group;
      domain = "${hostPrefix}.${domain}";
      extraDomains = map (domain: "${hostPrefix}.${domain}") extraDomains;
      webroot = acmeRoot;
      # @todo should we reload postfix here?
      postRun = ''
        systemctl reload nginx
      '';
    };
  };
}
