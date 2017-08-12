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

{ config, pkgs, ... }:

let
  domain = "example.com";
  host_prefix = "mail";
  login_accounts = [ "user1" "user2" ];
  valiases = [
    { from = "info";
      to = "user1";
    }
    { from = "postmaster";
      to = "user1";
    }
    { from = "abuse";
      to = "user1";
    }
  ];
  extra_vaccounts = [ "localuser" "user1" ];
  vmail_id_start = 5000;
  vmail_user_name = "vmail";
  vmail_group_name = "vmail";
  mail_dir = "/var/vmail";
  cert_file = "mail-server.crt";
  key_file = "mail-server.key";
  enable_imap = true;
  enable_pop3 = false;
  imap_ssl = false;
  pop3_ssl = false;
  virus_scanning = false;
in
{
  services = import ./mail-server/services.nix {
    inherit mail_dir vmail_user_name vmail_group_name valiases domain
            enable_imap enable_pop3;
  };

  environment = import ./mail-server/environment.nix {
    inherit pkgs;
  };

  networking = import ./mail-server/networking.nix {
    inherit domain host_prefix;
  };

  systemd = import ./mail-server/systemd.nix {
    inherit mail_dir vmail_group_name;
  };

  users = import ./mail-server/users.nix {
    inherit vmail_id_start vmail_user_name vmail_group_name domain mail_dir
            login_accounts;
  };
}
