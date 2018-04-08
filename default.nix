
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
              Note: Use list entries like "@example.com" to create a catchAll
              that allows sending from all email addresses in these domain.
            '';
          };

          catchAll = mkOption {
            type = with types; listOf (enum cfg.domains);
            example = ["example.com" "example2.com"];
            default = [];
            description = ''
              For which domains should this account act as a catch all?
              Note: Does not allow sending from all addresses of these domains.
            '';
          };

          quota = mkOption {
            type = with types; nullOr types.str;
            default = null;
            example = "2G";
            description = ''
              Per user quota rules. Accepted sizes are `xx k/M/G/T` with the
              obvious meaning. Leave blank for the standard quota `100G`.
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
      type = types.loaOf (mkOptionType {
        name = "Login Account";
        check = (ele:
          let accounts = builtins.attrNames cfg.loginAccounts;
          in if (builtins.isList ele)
            then (builtins.all (x: builtins.elem x accounts) ele) && (builtins.length ele > 0)
            else (builtins.elem ele accounts));
      });
      example = {
        "info@example.com" = "user1@example.com";
        "postmaster@example.com" = "user1@example.com";
        "abuse@example.com" = "user1@example.com";
        "multi@example.com" = [ "user1@example.com" "user2@example.com" ];
      };
      description = ''
        Virtual Aliases. A virtual alias `"info@example.com" = "user1@example.com"` means that
        all mail to `info@example.com` is forwarded to `user1@example.com`. Note
        that it is expected that `postmaster@example.com` and `abuse@example.com` is
        forwarded to some valid email address. (Alternatively you can create login
        accounts for `postmaster` and (or) `abuse`). Furthermore, it also allows
        the user `user1@example.com` to send emails as `info@example.com`.
        It's also possible to create an alias for multiple accounts. In this
        example all mails for `multi@example.com` will be forwarded to both
        `user1@example.com` and `user2@example.com`.
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

    useFsLayout = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Sets whether dovecot should organize mail in subdirectories:

        - /var/vmail/example.com/user/.folder.subfolder/ (default layout)
        - /var/vmail/example.com/user/folder/subfolder/  (FS layout)

        See https://wiki2.dovecot.org/MailboxFormat/Maildir for details.
      '';
    };

    hierarchySeparator = mkOption {
      type = types.string;
      default = ".";
      description = ''
        The hierarchy separator for mailboxes used by dovecot for the namespace 'inbox'.
        Dovecot defaults to "." but recommends "/".
        This affects how mailboxes appear to mail clients and sieve scripts.
        For instance when using "." then in a sieve script "example.com" would refer to the mailbox "com" in the parent mailbox "example".
        This does not determine the way your mails are stored on disk.
        See https://wiki.dovecot.org/Namespaces for details.
      '';
    };

    mailboxes = mkOption {
      description = ''
        The mailboxes for dovecot.
        Depending on the mail client used it might be necessary to change some mailbox's name.
      '';
      default = [
        {
          name = "Trash";
          auto = "no";
          specialUse = "Trash";
        }

        {
          name = "Junk";
          auto = "subscribe";
          specialUse = "Junk";
        }

        {
          name = "Drafts";
          auto = "subscribe";
          specialUse = "Drafts";
        }

        {
          name = "Sent";
          auto = "subscribe";
          specialUse = "Sent";
        }
      ];
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
        Whether to enable verbose logging for mailserver related services. This
        intended be used for development purposes only, you probably don't want
        to enable this unless you're hacking on nixos-mailserver.
      '';
    };

    maxConnectionsPerUser = mkOption {
      type = types.int;
      default = 100;
      description = ''
        Maximum number of IMAP/POP3 connections allowed for a user from each IP address.
        E.g. a value of 50 allows for 50 IMAP and 50 POP3 connections at the same
        time for a single user.
      '';
    };

    localDnsResolver = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Runs a local DNS resolver (kresd) as recommended when running rspamd. This prevents your log file from filling up with rspamd_monitored_dns_mon entries.
      '';
    };

    monitoring = {
      enable = mkEnableOption "monitoring via monit";

      alertAddress = mkOption {
        type = types.string;
        description = ''
          The email address to send alerts to.
        '';
      };

      config = mkOption {
        type = types.string;
        default = ''
          set daemon 120 with start delay 60
          set mailserver
              localhost

          set httpd port 2812 and use address localhost
              allow localhost
              allow admin:obwjoawijerfoijsiwfj29jf2f2jd

          check filesystem root with path /
                if space usage > 80% then alert
                if inode usage > 80% then alert

          check system $HOST
                if cpu usage > 95% for 10 cycles then alert
                if memory usage > 75% for 5 cycles then alert
                if swap usage > 20% for 10 cycles then alert
                if loadavg (1min) > 90 for 15 cycles then alert
                if loadavg (5min) > 80 for 10 cycles then alert
                if loadavg (15min) > 70 for 8 cycles then alert

          check process sshd with pidfile /var/run/sshd.pid
                start program  "${pkgs.systemd}/bin/systemctl start sshd"
                stop program  "${pkgs.systemd}/bin/systemctl stop sshd"
                if failed port 22 protocol ssh for 2 cycles then restart

          check process postfix with pidfile /var/lib/postfix/queue/pid/master.pid
                start program = "${pkgs.systemd}/bin/systemctl start postfix"
                stop program = "${pkgs.systemd}/bin/systemctl stop postfix"
                if failed port 25 protocol smtp for 5 cycles then restart

          check process dovecot with pidfile /var/run/dovecot2/master.pid
                start program = "${pkgs.systemd}/bin/systemctl start dovecot2"
                stop program = "${pkgs.systemd}/bin/systemctl stop dovecot2"
                if failed host ${cfg.fqdn} port 993 type tcpssl sslauto protocol imap for 5 cycles then restart

          check process rspamd with pidfile /var/run/rspamd.pid
                start program = "${pkgs.systemd}/bin/systemctl start rspamd"
                stop program = "${pkgs.systemd}/bin/systemctl stop rspamd"
        '';
        description = ''
          The configuration used for monitoring via monit.
          Use a mail address that you actively check and set it via 'set alert ...'.
        '';
      };
    };

    borgbackup = {
      enable = mkEnableOption "backup via borgbackup";

      repoLocation = mkOption {
        type = types.string;
        default = "/var/borgbackup";
        description = ''
          The location where borg saves the backups.
          This can be a local path or a remote location such as user@host:/path/to/repo.
          It is exported and thus available as an environment variable to cmdPreexec and cmdPostexec.
        '';
      };

      startAt = mkOption {
        type = types.string;
        default = "hourly";
        description = "When or how often the backup should run. Must be in the format described in systemd.time 7.";
      };

      user = mkOption {
        type = types.string;
        default = "virtualMail";
        description = "The user borg and its launch script is run as.";
      };

      group = mkOption {
        type = types.string;
        default = "virtualMail";
        description = "The group borg and its launch script is run as.";
      };

      compression = {
        method = mkOption {
          type = types.nullOr (types.enum ["none" "lz4" "zstd" "zlib" "lzma"]);
          default = null;
          description = "Leaving this unset allows borg to choose. The default for borg 1.1.4 is lz4.";
        };

        level = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = ''
            Denotes the level of compression used by borg.
            Most methods accept levels from 0 to 9 but zstd which accepts values from 1 to 22.
            If null the decision is left up to borg.
          '';
        };
        
        auto = mkOption {
          type = types.bool;
          default = false;
          description = "Leaves it to borg to determine whether an individual file should be compressed.";
        };
      };

      encryption = {
        method = mkOption {
          type = types.enum [
            "none"
            "authenticated"
            "authenticated-blake2"
            "repokey"
            "keyfile"
            "repokey-blake2"
            "keyfile-blake2"
          ];
          default = "none";
          description = ''
            The backup can be encrypted by choosing any other value than 'none'.
            When using encryption the password / passphrase must be provided in passphraseFile.
          '';
        };
        
        passphraseFile = mkOption {
          type = types.nullOr types.path;
          default = null;
        };
      };

      name = mkOption {
        type = types.string;
        default = "{hostname}-{user}-{now}";
        description = ''
          The name of the individual backups as used by borg.
          Certain placeholders will be replaced by borg.
        '';
      };

      locations = mkOption {
        type = types.listOf types.path;
        default = [cfg.mailDirectory];
        description = "The locations that are to be backed up by borg.";
      };

      extraArgumentsForInit = mkOption {
        type = types.listOf types.string;
        default = ["--critical"];
        description = "Additional arguments to add to the borg init command line.";
      };

      extraArgumentsForCreate = mkOption {
        type = types.listOf types.string;
        default = [ ];
        description = "Additional arguments to add to the borg create command line e.g. '--stats'.";
      };

      cmdPreexec = mkOption {
        type = types.nullOr types.string;
        default = null;
        description = ''
          The command to be executed before each backup operation.
          This is called prior to borg init in the same script that runs borg init and create and cmdPostexec.
          Example:
            export BORG_RSH="ssh -i /path/to/private/key"
        '';
      };

      cmdPostexec = mkOption {
        type = types.nullOr types.string;
        default = null;
        description = ''
          The command to be executed after each backup operation.
          This is called after borg create completed successfully and in the same script that runs
          cmdPreexec, borg init and create.
        '';
      };

    };

    backup = {
      enable = mkEnableOption "backup via rsnapshot";

      snapshotRoot = mkOption {
        type = types.path;
        default = "/var/rsnapshot";
        description = ''
          The directory where rsnapshot stores the backup.
        '';
      };

      cmdPreexec = mkOption {
        type = types.nullOr types.string;
        default = null;
        description = ''
          The command to be executed before each backup operation. This is wrapped in a shell script to be called by rsnapshot.
        '';
      };

      cmdPostexec = mkOption {
        type = types.nullOr types.string;
        default = null;
        description = "The command to be executed after each backup operation. This is wrapped in a shell script to be called by rsnapshot.";
      };

      retain = {
        hourly = mkOption {
          type = types.int;
          default = 24;
          description = "How many hourly snapshots are retained.";
        };
        daily = mkOption {
          type = types.int;
          default = 7;
          description = "How many daily snapshots are retained.";
        };
        weekly = mkOption {
          type = types.int;
          default = 54;
          description = "How many weekly snapshots are retained.";
        };
      };

      cronIntervals = mkOption {
        type = types.attrsOf types.string;
        default = {
                   # minute, hour, day-in-month, month, weekday (0 = sunday)
          hourly = " 0  *  *  *  *"; # Every full hour
          daily  = "30  3  *  *  *"; # Every day at 3:30
          weekly = " 0  5  *  *  0"; # Every sunday at 5:00 AM
        };
        description = ''
          Periodicity at which intervals should be run by cron.
          Note that the intervals also have to exist in configuration
          as retain options.
        '';
      };
    };
  };

  imports = [
    ./mail-server/borgbackup.nix
    ./mail-server/rsnapshot.nix
    ./mail-server/clamav.nix
    ./mail-server/monit.nix
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
}
