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

  postfixCfg = config.services.postfix;
  rspamdCfg = config.services.rspamd;
  rspamdSocket = if rspamdCfg.socketActivation
    then "rspamd-rspamd_proxy-1.socket"
    else "rspamd.service";
in
{
  config = with cfg; lib.mkIf enable {
    services.rspamd = {
      enable = true;
      socketActivation = false;
      extraConfig = ''
        extended_spam_headers = yes;
      '' + (lib.optionalString cfg.virusScanning ''
        antivirus {
          clamav {
            action = "reject";
            symbol = "CLAM_VIRUS";
            type = "clamav";
            log_clean = true;
            servers = "/run/clamav/clamd.ctl";
          }
        }
      '');

      workers.rspamd_proxy = {
        type = "proxy";
        bindSockets = [{
          socket = "/run/rspamd/rspamd-milter.sock";
          mode = "0664";
        }];
        count = 1; # Do not spawn too many processes of this type
        extraConfig = ''
          milter = yes; # Enable milter mode
          timeout = 120s; # Needed for Milter usually

          upstream "local" {
            default = yes; # Self-scan upstreams are always default
            self_scan = yes; # Enable self-scan
          }
        '';
      };
      workers.controller = {
        type = "controller";
        count = 1;
        bindSockets = [{
          socket = "/run/rspamd/worker-controller.sock";
          mode = "0666";
        }];
        includes = [];
      };

    };
    systemd.services.rspamd = {
      requires = (lib.optional cfg.virusScanning "clamav-daemon.service");
      after = (lib.optional cfg.virusScanning "clamav-daemon.service");
    };

    systemd.services.postfix = {
      after = [ rspamdSocket ];
      requires = [ rspamdSocket ];
    };

    users.extraUsers.${postfixCfg.user}.extraGroups = [ rspamdCfg.group ];
  };
}

