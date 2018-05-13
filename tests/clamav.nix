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
    server = { config, pkgs, lib, ... }:
      let
        clamav-db = pkgs.srcOnly {
          name = "ClamAV-db";
          src = pkgs.fetchurl {
            url = "https://files.griff.name/ClamAV-db.tar";
            sha256 = "eecad99f4c071d216bd91565f84c0d90a1f93e5e3e22d8f3087686ba3bd219e7";
          };
        };
      in
        {
            imports = [
                ../default.nix
            ];

            virtualisation.memorySize = 1500;

            services.rsyslogd = {
              enable = true;
              defaultConfig = ''
              *.*   /dev/console
              '';
            };

            services.clamav.updater.enable = lib.mkForce false;
            systemd.services.old-clam = {
              before = [ "clamav-daemon.service" ];
              requiredBy = [ "clamav-daemon.service" ];
              description = "ClamAV virus database";

              preStart = ''
                mkdir -m 0755 -p /var/lib/clamav
                chown clamav:clamav /var/lib/clamav
              '';

              script = ''
                cp ${clamav-db}/bytecode.cvd /var/lib/clamav/
                cp ${clamav-db}/main.cvd     /var/lib/clamav/
                cp ${clamav-db}/daily.cvd    /var/lib/clamav/
                chown clamav:clamav /var/lib/clamav/*
              '';

              serviceConfig = {
                Type = "oneshot";
                PrivateTmp = "yes";
                PrivateDevices = "yes";
              };
            };

            mailserver = {
              enable = true;
              debug = true;
              fqdn = "mail.example.com";
              domains = [ "example.com" "example2.com" ];
              dhParamBitLength = 512;
              virusScanning = true;

              loginAccounts = {
                  "user1@example.com" = {
                      hashedPassword = "$6$/z4n8AQl6K$kiOkBTWlZfBd7PvF5GsJ8PmPgdZsFGN1jPGZufxxr60PoR0oUsrvzm2oQiflyz5ir9fFJ.d/zKm/NgLXNUsNX/";
                      aliases = [ "postmaster@example.com" ];
                      catchAll = [ "example.com" ];
                  };
                  "user@example2.com" = {
                      hashedPassword = "$6$u61JrAtuI0a$nGEEfTP5.eefxoScUGVG/Tl0alqla2aGax4oTd85v3j3xSmhv/02gNfSemv/aaMinlv9j/ZABosVKBrRvN5Qv0";
                  };
              };
              enableImap = true;
            };

            environment.etc = {
              "root/eicar.com.txt".text = "X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*";
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
      in {
        environment.systemPackages = with pkgs; [
          fetchmail msmtp procmail findutils grep-ip
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
          "root/.procmailrc" = {
            text = "DEFAULT=$HOME/mail";
          };
          "root/.msmtprc" = {
            text = ''
              account        test2
              host           ${serverIP}
              port           587
              from           user@example2.com
              user           user@example2.com
              password       user2
            '';
          };
          "root/virus-email".text = ''
            From: User2 <user@example2.com>
            Content-Type: multipart/mixed;
              boundary="Apple-Mail=_2689C63E-FD18-4E4D-8822-54797BDA9607"
            Mime-Version: 1.0 (Mac OS X Mail 11.3 \(3445.6.18\))
            Subject: Testy McTest
            Message-Id: <94550DD9-1FF1-4ED1-9F09-8812FF2E59AA@example.com>
            Date: Sat, 12 May 2018 14:15:44 +0200
            To: User1 <user1@example.com>
            X-Mailer: Apple Mail (2.3445.6.18)


            --Apple-Mail=_2689C63E-FD18-4E4D-8822-54797BDA9607
            Content-Transfer-Encoding: 7bit
            Content-Type: text/plain;
              charset=us-ascii

            Hello

            I have attached a dangerous virus.

            Mfg.
            User2


            --Apple-Mail=_2689C63E-FD18-4E4D-8822-54797BDA9607
            Content-Disposition: attachment;
              filename=eicar.com.txt
            Content-Type: text/plain;
              x-unix-mode=0644;
              name="eicar.com.txt"
            Content-Transfer-Encoding: 7bit

            X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*
            --Apple-Mail=_2689C63E-FD18-4E4D-8822-54797BDA9607--
          '';
          "root/email2".text = ''
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

      # fetchmail returns EXIT_CODE 1 when no new mail
      $client->succeed("fetchmail -v || [ \$? -eq 1 ] >&2");

      # Verify that mail can be sent and received before testing virus scanner
      $client->execute("rm ~/mail/*");
      $client->succeed("msmtp -a test2 --tls=on --tls-certcheck=off --auth=on user1\@example.com < /etc/root/email2 >&2");
      # give the mail server some time to process the mail
      $server->waitUntilFails('[ "$(postqueue -p)" != "Mail queue is empty" ]');
      $client->execute("rm ~/mail/*");
      # fetchmail returns EXIT_CODE 0 when it retrieves mail
      $client->succeed("fetchmail -v >&2");
      $client->execute("rm ~/mail/*");


      subtest "virus scan file", sub {
        $server->fail("clamscan --follow-file-symlinks=2 -r /etc/root/ >&2");
      };

      subtest "virus scanner", sub {
          $client->fail("msmtp -a test2 --tls=on --tls-certcheck=off --auth=on user1\@example.com < /etc/root/virus-email >&2");
          # give the mail server some time to process the mail
          $server->waitUntilFails('[ "$(postqueue -p)" != "Mail queue is empty" ]');
      };

      subtest "no warnings or errors", sub {
          $server->fail("journalctl -u postfix | grep -i error >&2");
          $server->fail("journalctl -u postfix | grep -i warning >&2");
          $server->fail("journalctl -u dovecot2 | grep -i error >&2");
          $server->fail("journalctl -u dovecot2 | grep -i warning >&2");
      };

    '';
}
