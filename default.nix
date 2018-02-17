
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

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.mailserver;
in
{
  options.mailserver = {
    enable = mkEnableOption "nixos-mailserver";

    fqdn = mkOption {
      type = types.str;
      example = "mx.example.com";
      description = "The fully qualified domain name of the mail server.";
    };

    domains = mkOption {
      type = types.listOf types.str;
      example = [ "example.com" ];
      default = [];
      description = "The domains that this mail server serves.";
    };

    loginAccounts = mkOption {
      type = types.loaOf (types.submodule ({ name, ... }: {
        options = {
          name = mkOption {
            type = types.str;
            example = "user1@example.com";
            description = "Username";
          };

          hashedPassword = mkOption {
            type = types.str;
            example = "$6$evQJs5CFQyPAW09S$Cn99Y8.QjZ2IBnSu4qf1vBxDRWkaIZWOtmu1Ddsm3.H3CFpeVc0JU4llIq8HQXgeatvYhh5O33eWG3TSpjzu6/";
            description = ''
              Hashed password. Use `mkpasswd` as follows

              ```
              mkpasswd -m sha-512 "super secret password"
              ```
            '';
          };

          aliases = mkOption {
            type = with types; listOf types.str;
            example = ["abuse@example.com" "postmaster@example.com"];
            default = [];
            description = ''
              A list of aliases of this login account.
            '';
          };

          catchAll = mkOption {
            type = with types; listOf (enum cfg.domains);
            example = ["example.com" "example2.com"];
            default = [];
            description = ''
              For which domains should this account act as a catch all?
            '';
          };

          sieveScript = mkOption {
            type = with types; nullOr lines;
            default = null;
            example = ''
              require ["fileinto", "mailbox"];

              if address :is "from" "notifications@github.com" {
                fileinto :create "GitHub";
                stop;
              }

              # This must be the last rule, it will check if list-id is set, and
              # file the message into the Lists folder for further investigation
              elsif header :matches "list-id" "<?*>" {
                fileinto :create "Lists";
                stop;
              }
            '';
            description = ''
              Per-user sieve script.
            '';
          };
        };

        config.name = mkDefault name;
      }));
      example = {
        user1 = {
          hashedPassword = "$6$evQJs5CFQyPAW09S$Cn99Y8.QjZ2IBnSu4qf1vBxDRWkaIZWOtmu1Ddsm3.H3CFpeVc0JU4llIq8HQXgeatvYhh5O33eWG3TSpjzu6/";
        };
        user2 = {
          hashedPassword = "$6$oE0ZNv2n7Vk9gOf$9xcZWCCLGdMflIfuA0vR1Q1Xblw6RZqPrP94mEit2/81/7AKj2bqUai5yPyWE.QYPyv6wLMHZvjw3Rlg7yTCD/";
        };
      };
      description = ''
        The login account of the domain. Every account is mapped to a unix user,
        e.g. `user1@example.com`. To generate the passwords use `mkpasswd` as
        follows

        ```
        mkpasswd -m sha-512 "super secret password"
        ```
      '';
      default = {};
    };

    extraVirtualAliases = mkOption {
      type = types.attrsOf (types.enum (builtins.attrNames cfg.loginAccounts));
      example = {
        "info@example.com" = "user1@example.com";
        "postmaster@example.com" = "user1@example.com";
        "abuse@example.com" = "user1@example.com";
      };
      description = ''
        Virtual Aliases. A virtual alias `"info@example2.com" = "user1@example.com"` means that
        all mail to `info@example2.com` is forwarded to `user1@example.com`. Note
        that it is expected that `postmaster@example.com` and `abuse@example.com` is
        forwarded to some valid email address. (Alternatively you can create login
        accounts for `postmaster` and (or) `abuse`). Furthermore, it also allows
        the user `user1@example.com` to send emails as `info@example2.com`.
      '';
      default = {};
    };

    virtualAliases = mkOption {
      type = types.attrsOf (types.enum (builtins.attrNames cfg.loginAccounts));
      example = {
        "info@example.com" = "user1@example.com";
        "postmaster@example.com" = "user1@example.com";
        "abuse@example.com" = "user1@example.com";
      };
      description = ''
        Alias for extraVirtualAliases. Deprecated.
      '';
      default = {};
    };

    vmailUID = mkOption {
      type = types.int;
      default = 5000;
      description = ''
        The unix UID of the virtual mail user.  Be mindful that if this is
        changed, you will need to manually adjust the permissions of
        mailDirectory.
      '';
    };

    vmailUserName = mkOption {
      type = types.str;
      default = "virtualMail";
      description = ''
        The user name and group name of the user that owns the directory where all
        the mail is stored.
      '';
    };

    vmailGroupName = mkOption {
      type = types.str;
      default = "virtualMail";
      description = ''
        The user name and group name of the user that owns the directory where all
        the mail is stored.
      '';
    };

    mailDirectory = mkOption {
      type = types.path;
      default = "/var/vmail";
      description = ''
        Where to store the mail.
      '';
    };

    certificateScheme = mkOption {
      type = types.enum [ 1 2 3 ];
      default = 2;
      description = ''
        Certificate Files. There are three options for these.

        1) You specify locations and manually copy certificates there.
        2) You let the server create new (self signed) certificates on the fly.
        3) You let the server create a certificate via `Let's Encrypt`. Note that
           this implies that a stripped down webserver has to be started. This also
           implies that the FQDN must be set as an `A` record to point to the IP of
           the server. In particular port 80 on the server will be opened. For details
           on how to set up the domain records, see the guide in the readme.
      '';
    };

    certificateFile = mkOption {
      type = types.path;
      example = "/root/mail-server.crt";
      description = ''
        Scheme 1)
        Location of the certificate
      '';
    };

    keyFile = mkOption {
      type = types.path;
      example = "/root/mail-server.key";
      description = ''
        Scheme 1)
        Location of the key file
      '';
    };

    certificateDirectory = mkOption {
      type = types.path;
      default = "/var/certs";
      description = ''
        Sceme 2)
        This is the folder where the certificate will be created. The name is
        hardcoded to "cert-<domain>.pem" and "key-<domain>.pem" and the
        certificate is valid for 10 years.
      '';
    };

    enableImap = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable imap / pop3. Both variants are only supported in the
        (sane) startTLS configuration. The ports are

        110 - Pop3
        143 - IMAP
        587 - SMTP with login
      '';
    };

    enableImapSsl = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable IMAPS, setting this option to true will open port 993
        in the firewall.
      '';
    };

    enablePop3 = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable POP3. Both variants are only supported in the (sane)
        startTLS configuration. The ports are

        110 - Pop3
        143 - IMAP
        587 - SMTP with login
      '';
    };

    enablePop3Ssl = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable POP3S, setting this option to true will open port 995
        in the firewall.
      '';
    };

    enableManageSieve = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable ManageSieve, setting this option to true will open
        port 4190 in the firewall.

        The ManageSieve protocol allows users to manage their Sieve scripts on
        a remote server with a supported client, including Thunderbird.
      '';
    };

    virusScanning = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to activate virus scanning. Note that virus scanning is _very_
        expensive memory wise.
      '';
    };

    dkimSigning = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to activate dkim signing.
      '';
    };

    dkimSelector = mkOption {
      type = types.str;
      default = "mail";
      description = ''

      '';
    };

    dkimKeyDirectory = mkOption {
      type = types.path;
      default = "/var/dkim";
      description = ''

      '';
    };

    dhParamBitLength = mkOption {
      type = types.int;
      default = 2048;
      description =
        ''
        Length of the Diffie Hillman prime used (in bits). It might be a good
        idea to set this to 4096 for security purposed, but it will take a _very_
        long time to create this prime on startup.
        '';
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable verbose logging for mailserver related services.  This
        intended be used for development purposes only, you probably don't want
        to enable this unless you're hacking on nixos-mailserver.
      '';
    };

    localDnsResolver = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Runs a local DNS resolver (kresd) as recommended when running rspamd. This prevents your log file from filling up with rspamd_monitored_dns_mon entries.
      '';
    };
  };

  imports = [
    ./mail-server/clamav.nix
    ./mail-server/users.nix
    ./mail-server/environment.nix
    ./mail-server/networking.nix
    ./mail-server/systemd.nix
    ./mail-server/dovecot.nix
    ./mail-server/postfix.nix
    ./mail-server/rmilter.nix
    ./mail-server/nginx.nix
    ./mail-server/kresd.nix
  ];

  config = lib.mkIf config.mailserver.enable {
    warnings = if (config.mailserver.virtualAliases != {}) then [ ''
      virtualAliases had been derprecated. Use extraVirtualAliases instead or
      use the `aliases` field of the loginAccount attribute set
      '']
      else [];
  };
}
