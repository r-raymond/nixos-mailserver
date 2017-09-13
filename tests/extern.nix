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

import ./../../nixpkgs/nixos/tests/make-test.nix {

  nodes =
    { server = { config, pkgs, ... }:
        {
            imports = [
                ./../default.nix
            ];

            mailserver = {
              enable = true;
              domain = "example.com";

              hostPrefix = "mail";
              loginAccounts = {
                  user1 = {
                      hashedPassword = "$6$/z4n8AQl6K$kiOkBTWlZfBd7PvF5GsJ8PmPgdZsFGN1jPGZufxxr60PoR0oUsrvzm2oQiflyz5ir9fFJ.d/zKm/NgLXNUsNX/";
                  };
              };

              enableImap = true;
            };
        };
      client = { config, pkgs, ... }:
      {
        environment.systemPackages =with pkgs; [ fetchmail ];
      };
    };

  testScript =
  let
    fetchmailRc =
    ''
    poll SERVER with proto IMAP
        user 'user1\@example.com' there with password 'user1' is 'root' here
    '';
  in
    ''
      startAll;

      $server->waitForUnit("multi-user.target");
      $client->waitForUnit("multi-user.target");

      subtest "imap", sub {
          $client->succeed("echo '${fetchmailRc}' > ~/.fetchmailrc");
          $client->succeed("sed -i s/SERVER/`getent hosts server | awk '{ print \$1 }'`/g ~/.fetchmailrc");
          $client->succeed("chmod 0700 ~/.fetchmailrc");
          $client->succeed("cat ~/.fetchmailrc >&2");
          $client->succeed("fetchmail -v || [ \$? -eq 1 ] >&2");
      };
    '';
}
