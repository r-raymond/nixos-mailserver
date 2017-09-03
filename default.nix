
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

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.mailserver;
in
{
  options.mailserver = {
    enable = mkEnableOption "nixos-mailserver";

    domain = mkOption {
      type = types.str;
      example = "example.com";
      description = "The domain that this mail server serves. So far only one domain is supported";
    };

    host_prefix = mkOption {
      type = types.str;
      default = "mail";
      description = ''
        The prefix of the FQDN of the server. In this example the FQDN of the server
        is given by 'mail.example.com'
      '';
    };

    login_accounts = mkOption {
      type = types.loaOf (types.submodule ({ name, ... }: {
        options = {
          name = mkOption {
            type = types.str;
            example = "user1";
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
    };

    valiases = mkOption {
      type = types.attrsOf (types.enum (builtins.attrNames cfg.login_accounts));
      example = {
        info = "user1";
        postmaster = "user1";
        abuse = "user1";
      };
      description = ''
        Virtual Aliases. A virtual alias `info = "user1"` means that
        all mail to `info@example.com` is forwarded to `user1@example.com`. Note
        that it is expected that `postmaster@example.com` and `abuse@example.com` is
        forwarded to some valid email address. (Alternatively you can create login
        accounts for `postmaster` and (or) `abuse`).
      '';
    };

    vmail_id_start = mkOption {
      type = types.int;
      default = 5000;
      description = ''
        The unix UID where the login_accounts are created. 5000 means that the first
        user will get 5000, the second 5001, ...
      '';
    };

    vmail_user_name = mkOption {
      type = types.str;
      default = "vmail";
      description = ''
        The user name and group name of the user that owns the directory where all
        the mail is stored.
      '';
    };

    vmail_group_name = mkOption {
      type = types.str;
      default = "vmail";
      description = ''
        The user name and group name of the user that owns the directory where all
        the mail is stored.
      '';
    };

    mail_dir = mkOption {
      type = types.path;
      default = "/var/vmail";
      description = ''
        Where to store the mail.
      '';
    };

    certificate_scheme = mkOption {
      type = types.enum [ 1 2 ];
      default = 2;
      description = ''
        Certificate Files. There are three options for these.

        1) You specify locations and manually copy certificates there.
        2) You let the server create new (self signed) certificates on the fly.
        3) You let the server create a certificate via `Let's Encrypt`. Note that
           this implies that a stripped down webserver has to be started. This also
           implies that the FQDN must be set as an `A` record to point to the IP of
           the server. TODO: Explain more details

        TODO: Only certificate scheme 1) and 2) work as of yet.
      '';
    };

    cert_file = mkOption {
      type = types.path;
      example = "/root/mail-server.crt";
      description = ''
        Scheme 1)
        Location of the certificate
      '';
    };

    key_file = mkOption {
      type = types.path;
      example = "/root/mail-server.key";
      description = ''
        Scheme 1)
        Location of the key file
      '';
    };

    cert_dir = mkOption {
      type = types.path;
      default = "/var/certs";
      description = ''
        Sceme 2)
        This is the folder where the certificate will be created. The name is
        hardcoded to "cert-<domain>.pem" and "key-<domain>.pem" and the
        certificate is valid for 10 years.
      '';
    };

    enable_imap = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable imap / pop3. Both variants are only supported in the
        (sane) startTLS configuration. (TODO: Allow SSL ports). The ports are

        110 - Pop3
        143 - IMAP
        587 - SMTP with login
      '';
    };

    enable_pop3 = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable POP3. Both variants are only supported in the
        (sane) startTLS configuration. (TODO: Allow SSL ports). The ports are

        110 - Pop3
        143 - IMAP
        587 - SMTP with login
      '';
    };

    # imapSsl = mkOption {} #< TODO
    # pop3Ssl = mkOption {} #< TODO

    virus_scanning = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to activate virus scanning. Note that virus scanning is _very_
        expensive memory wise.
      '';
    };

    dkim_signing = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to activate dkim signing.
        TODO: Explain how to put signature into domain record
      '';
    };

    dkim_selector = mkOption {
      type = types.str;
      default = "mail";
      description = ''

      '';
    };

    dkim_dir = mkOption {
      type = types.path;
      default = "/var/dkim";
      description = ''

      '';
    };
  };

  config = mkIf cfg.enable {
    services = import ./mail-server/services.nix {
      inherit lib;
      inherit (cfg) mail_dir vmail_user_name vmail_group_name valiases domain
              enable_imap enable_pop3 virus_scanning dkim_signing dkim_selector
              dkim_dir certificate_scheme cert_file key_file cert_dir;
    };

    environment = import ./mail-server/environment.nix {
      inherit pkgs;
      inherit (cfg) certificate_scheme;
    };

    networking = import ./mail-server/networking.nix {
      inherit (cfg) domain host_prefix enable_imap enable_pop3;
    };

    systemd = import ./mail-server/systemd.nix {
      inherit pkgs;
      inherit (cfg) mail_dir vmail_group_name certificate_scheme cert_dir host_prefix
              domain dkim_selector dkim_dir;
    };

    users = import ./mail-server/users.nix {
      inherit lib;
      inherit (cfg) vmail_id_start vmail_user_name vmail_group_name domain mail_dir
              login_accounts;
    };
  };
}
