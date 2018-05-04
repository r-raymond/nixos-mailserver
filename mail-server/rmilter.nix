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

  clamav = if cfg.virusScanning
           then
           ''
             clamav {
               servers = /var/run/clamav/clamd.ctl;
             };
           ''
           else "";
  postfixCfg = config.services.postfix;
  rmilter = config.services.rmilter;
in
{
  config = with cfg; lib.mkIf enable {
    services.rspamd = {
        enable = true;
    };

    services.rmilter = {
      inherit debug;
      enable = true;
      rspamd = {
        enable = true;
        extraConfig = "extended_spam_headers = yes;";
      };
      extraConfig =
      ''
      use_redis = true;
      max_size = 20M;

      ${clamav}
      '';
    };
    users.extraUsers.${postfixCfg.user}.extraGroups = [ rmilter.group ];
  };
}

