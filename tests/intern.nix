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

import <nixpkgs/nixos/tests/make-test.nix> {

  machine =
    { config, pkgs, ... }:
    {
        imports = [
            ./../default.nix
        ];

        mailserver = {
          enable = true;
          fqdn = "mail.example.com";
          domains = [ "example.com" ];

          loginAccounts = {
              "user1@example.com" = {
                  hashedPassword = "$6$/z4n8AQl6K$kiOkBTWlZfBd7PvF5GsJ8PmPgdZsFGN1jPGZufxxr60PoR0oUsrvzm2oQiflyz5ir9fFJ.d/zKm/NgLXNUsNX/";
              };
          };

          vmailGroupName = "vmail";
          vmailUIDStart = 5000;
        };
    };

  testScript =
    ''
      $machine->start;
      $machine->waitForUnit("multi-user.target");

      subtest "user exists", sub {
            $machine->succeed("cat /etc/shadow | grep 'user1\@example.com'");
      };

      subtest "password is set", sub {
            $machine->succeed("cat /etc/shadow | grep 'user1\@example.com:\$6\$/z4n8AQl6K\$kiOkBTWlZfBd7PvF5GsJ8PmPgdZsFGN1jPGZufxxr60PoR0oUsrvzm2oQiflyz5ir9fFJ.d/zKm/NgLXNUsNX/:1::::::'");
      };

      subtest "vmail gid is set correctly", sub {
            $machine->succeed("getent group vmail | grep 5000");
      };

    '';
}
