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

import <nixpkgs/nixos/tests/make-test.nix> {

  nodes = {
    server = { config, pkgs, ... }:
        {
            imports = [
                ../default.nix
            ];

            services.rsyslogd = {
              enable = true;
              defaultConfig = ''
              *.*   /dev/console
              '';
            };


            mailserver = {
              enable = true;
              debug = true;
              fqdn = "mail.example.com";
              domains = [ "example.com" "example2.com" ];
              dhParamBitLength = 512;
              rewriteMessageId = true;

              loginAccounts = {
                  "user1@example.com" = {
                      hashedPassword = "$6$/z4n8AQl6K$kiOkBTWlZfBd7PvF5GsJ8PmPgdZsFGN1jPGZufxxr60PoR0oUsrvzm2oQiflyz5ir9fFJ.d/zKm/NgLXNUsNX/";
                      aliases = [ "postmaster@example.com" ];
                      catchAll = [ "example.com" ];
                  };
                  "user2@example.com" = {
                      hashedPassword = "$6$u61JrAtuI0a$nGEEfTP5.eefxoScUGVG/Tl0alqla2aGax4oTd85v3j3xSmhv/02gNfSemv/aaMinlv9j/ZABosVKBrRvN5Qv0";
                      aliases = [ "chuck@example.com" ];
                  };
                  "user@example2.com" = {
                      hashedPassword = "$6$u61JrAtuI0a$nGEEfTP5.eefxoScUGVG/Tl0alqla2aGax4oTd85v3j3xSmhv/02gNfSemv/aaMinlv9j/ZABosVKBrRvN5Qv0";
                  };
                  "lowquota@example.com" = {
                      hashedPassword = "$6$u61JrAtuI0a$nGEEfTP5.eefxoScUGVG/Tl0alqla2aGax4oTd85v3j3xSmhv/02gNfSemv/aaMinlv9j/ZABosVKBrRvN5Qv0";
                      quota = "1B";
                  };
              };

              extraVirtualAliases = {
                "single-alias@example.com" = "user1@example.com";
                "multi-alias@example.com" = [ "user1@example.com" "user2@example.com" ];
              };

              enableImap = true;
            };
        };
      client = { nodes, config, pkgs, ... }: let
        serverIP = nodes.server.config.networking.primaryIPAddress;
        clientIP = nodes.client.config.networking.primaryIPAddress;
        grep-ip = pkgs.writeScriptBin "grep-ip" ''
          #!${pkgs.stdenv.shell}
          echo grep '${clientIP}' "$@" >&2
          exec grep '${clientIP}' "$@"
        '';
        check-mail-id = pkgs.writeScriptBin "check-mail-id" ''
          #!${pkgs.stdenv.shell}
          echo grep '^Message-ID:.*@mail.example.com>$' "$@" >&2
          exec grep '^Message-ID:.*@mail.example.com>$' "$@"
        '';
      in {
        environment.systemPackages = with pkgs; [
          fetchmail msmtp procmail findutils grep-ip check-mail-id
        ];
        environment.etc = {
          "root/.fetchmailrc" = {
            text = ''
                poll ${serverIP} with proto IMAP
                user 'user1@example.com' there with password 'user1' is 'root' here
                mda procmail
            '';
            mode = "0700";
          };
          "root/.fetchmailRcLowQuota" = {
            text = ''
                poll ${serverIP} with proto IMAP
                user 'lowquota@example.com' there with password 'user2' is 'root' here
                mda procmail
            '';
            mode = "0700";
          };
          "root/.procmailrc" = {
            text = "DEFAULT=$HOME/mail";
          };
          "root/.msmtprc" = {
            text = ''
              account        test
              host           ${serverIP}
              port           587
              from           user2@example.com
              user           user2@example.com
              password       user2

              account        test2
              host           ${serverIP}
              port           587
              from           user@example2.com
              user           user@example2.com
              password       user2

              account        test3
              host           ${serverIP}
              port           587
              from           chuck@example.com
              user           user2@example.com
              password       user2

              account        test4
              host           ${serverIP}
              port           587
              from           postmaster@example.com
              user           user1@example.com
              password       user1

              account        test5
              host           ${serverIP}
              port           587
              from           single-alias@example.com
              user           user1@example.com
              password       user1
            '';
          };
          "root/email1".text = ''
            Message-ID: <12345qwerty@host.local.network>
            From: User2 <user2@example.com>
            To: User1 <user1@example.com>
            Cc:
            Bcc:
            Subject: This is a test Email from user2 to user1
            Reply-To:

            Hello User1,

            how are you doing today?
          '';
          "root/email2".text = ''
            Message-ID: <232323abc@host.local.network>
            From: User <user@example2.com>
            To: User1 <user1@example.com>
            Cc:
            Bcc:
            Subject: This is a test Email from user@example2.com to user1
            Reply-To:

            Hello User1,

            how are you doing today?

            XOXO User1
          '';
          "root/email3".text = ''
            Message-ID: <asdfghjkl42@host.local.network>
            From: Postmaster <postmaster@example.com>
            To: Chuck <chuck@example.com>
            Cc:
            Bcc:
            Subject: This is a test Email from postmaster\@example.com to chuck
            Reply-To:

            Hello Chuck,

            I think I may have misconfigured the mail server
            XOXO Postmaster
          '';
          "root/email4".text = ''
            Message-ID: <sdfsdf@host.local.network>
            From: Single Alias <single-alias@example.com>
            To: User1 <user1@example.com>
            Cc:
            Bcc:
            Subject: This is a test Email from single-alias\@example.com to user1
            Reply-To:

            Hello User1,

            how are you doing today?

            XOXO User1 aka Single Alias
          '';
          "root/email5".text = ''
            Message-ID: <789asdf@host.local.network>
            From: User2 <user2@example.com>
            To: Multi Alias <multi-alias@example.com>
            Cc:
            Bcc:
            Subject: This is a test Email from user2\@example.com to multi-alias
            Reply-To:

            Hello Multi Alias,

            how are we doing today?

            XOXO User1
          '';
        };
      };
    };

  testScript =
      ''
      startAll;

      $server->waitForUnit("multi-user.target");
      $client->waitForUnit("multi-user.target");

      $client->execute("cp -p /etc/root/.* ~/");
      $client->succeed("mkdir -p ~/mail");
      $client->succeed("ls -la ~/ >&2");
      $client->succeed("cat ~/.fetchmailrc >&2");
      $client->succeed("cat ~/.procmailrc >&2");
      $client->succeed("cat ~/.msmtprc >&2");

      subtest "imap retrieving mail", sub {
          # fetchmail returns EXIT_CODE 1 when no new mail
          $client->succeed("fetchmail -v || [ \$? -eq 1 ] >&2");
      };

      subtest "submission port send mail", sub {
          # send email from user2 to user1
          $client->succeed("msmtp -a test --tls=on --tls-certcheck=off --auth=on user1\@example.com < /etc/root/email1 >&2");
          # give the mail server some time to process the mail
          $server->waitUntilFails('[ "$(postqueue -p)" != "Mail queue is empty" ]');
      };

      subtest "imap retrieving mail 2", sub {
          $client->execute("rm ~/mail/*");
          # fetchmail returns EXIT_CODE 0 when it retrieves mail
          $client->succeed("fetchmail -v >&2");
      };

      subtest "remove sensitive information on submission port", sub {
        $client->succeed("cat ~/mail/* >&2");
        ## make sure our IP is _not_ in the email header
        $client->fail("grep-ip ~/mail/*");
        $client->succeed("check-mail-id ~/mail/*");
      };

      subtest "have correct fqdn as sender", sub {
        $client->succeed("grep 'Received: from mail.example.com' ~/mail/*");
      };

      subtest "dkim singing, multiple domains", sub {
          $client->execute("rm ~/mail/*");
          # send email from user2 to user1
          $client->succeed("msmtp -a test2 --tls=on --tls-certcheck=off --auth=on user1\@example.com < /etc/root/email2 >&2");
          $server->waitUntilFails('[ "$(postqueue -p)" != "Mail queue is empty" ]');
          # fetchmail returns EXIT_CODE 0 when it retrieves mail
          $client->succeed("fetchmail -v");
          $client->succeed("cat ~/mail/* >&2");
          # make sure it is dkim signed
          $client->succeed("grep DKIM ~/mail/*");
      };

      subtest "aliases", sub {
          $client->execute("rm ~/mail/*");
          # send email from chuck to postmaster
          $client->succeed("msmtp -a test3 --tls=on --tls-certcheck=off --auth=on postmaster\@example.com < /etc/root/email2 >&2");
          $server->waitUntilFails('[ "$(postqueue -p)" != "Mail queue is empty" ]');
          # fetchmail returns EXIT_CODE 0 when it retrieves mail
          $client->succeed("fetchmail -v");
      };

      subtest "catchAlls", sub {
          $client->execute("rm ~/mail/*");
          # send email from chuck to non exsitent account
          $client->succeed("msmtp -a test3 --tls=on --tls-certcheck=off --auth=on lol\@example.com < /etc/root/email2 >&2");
          $server->waitUntilFails('[ "$(postqueue -p)" != "Mail queue is empty" ]');
          # fetchmail returns EXIT_CODE 0 when it retrieves mail
          $client->succeed("fetchmail -v");

          $client->execute("rm ~/mail/*");
          # send email from user1 to chuck
          $client->succeed("msmtp -a test4 --tls=on --tls-certcheck=off --auth=on chuck\@example.com < /etc/root/email2 >&2");
          $server->waitUntilFails('[ "$(postqueue -p)" != "Mail queue is empty" ]');
          # fetchmail returns EXIT_CODE 1 when no new mail
          # if this succeeds, it means that user1 recieved the mail that was intended for chuck.
          $client->fail("fetchmail -v");
      };

      subtest "extraVirtualAliases", sub {
          $client->execute("rm ~/mail/*");
          # send email from single-alias to user1
          $client->succeed("msmtp -a test5 --tls=on --tls-certcheck=off --auth=on user1\@example.com < /etc/root/email4 >&2");
          $server->waitUntilFails('[ "$(postqueue -p)" != "Mail queue is empty" ]');
          # fetchmail returns EXIT_CODE 0 when it retrieves mail
          $client->succeed("fetchmail -v");

          $client->execute("rm ~/mail/*");
          # send email from user1 to multi-alias (user{1,2}@example.com)
          $client->succeed("msmtp -a test --tls=on --tls-certcheck=off --auth=on multi-alias\@example.com < /etc/root/email5 >&2");
          $server->waitUntilFails('[ "$(postqueue -p)" != "Mail queue is empty" ]');
          # fetchmail returns EXIT_CODE 0 when it retrieves mail
          $client->succeed("fetchmail -v");
      };

      subtest "quota", sub {
          $client->execute("rm ~/mail/*");
          $client->execute("mv ~/.fetchmailRcLowQuota ~/.fetchmailrc");

          $client->succeed("msmtp -a test3 --tls=on --tls-certcheck=off --auth=on lowquota\@example.com < /etc/root/email2 >&2");
          $server->waitUntilFails('[ "$(postqueue -p)" != "Mail queue is empty" ]');
          # fetchmail returns EXIT_CODE 0 when it retrieves mail
          $client->fail("fetchmail -v");

      };

      subtest "no warnings or errors", sub {
          $server->fail("journalctl -u postfix | grep -i error >&2");
          $server->fail("journalctl -u postfix | grep -i warning >&2");
          $server->fail("journalctl -u dovecot2 | grep -i error >&2");
          $server->fail("journalctl -u dovecot2 | grep -i warning >&2");
      };

    '';
}
