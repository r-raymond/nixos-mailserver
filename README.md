# ![Simple Nixos MailServer][logo]
![license](https://img.shields.io/badge/license-GPL3-brightgreen.svg)
![status](https://travis-ci.org/r-raymond/nixos-mailserver.svg?branch=master)


## Stable Releases

* [SNM v2.1.3](https://github.com/r-raymond/nixos-mailserver/releases/v2.1.3)

[Latest Release (Candidate)](https://github.com/r-raymond/nixos-mailserver/releases/latest)

[Subscribe to SNM Announcement List](https://www.freelists.org/list/snm)
This is a very low volume list where new releases of SNM are announced, so you
can stay up to date with bug fixes and updates. All announcements are signed by
the gpg key with fingerprint

```
D9FE 4119 F082 6F15 93BD  BD36 6162 DBA5 635E A16A
```


## Features
### v2.0
 * [x] Continous Integration Testing
 * [x] Multiple Domains
 * Postfix MTA
    - [x] smtp on port 25
    - [x] submission port 587
    - [x] lmtp with dovecot
 * Dovecot
    - [x] maildir folders
    - [x] imap starttls on port 143
    - [x] pop3 starttls on port 110
 * Certificates
    - [x] manual certificates
    - [x] on the fly creation
    - [x] Let's Encrypt
 * Spam Filtering
    - [x] via rspamd
 * Virus Scanning
    - [x] via clamav
 * DKIM Signing
    - [x] via opendkim
 * User Management
    - [x] declarative user management
    - [x] declarative password management
 * Sieves
    - [x] A simple standard script that moves spam
    - [x] Allow user defined sieve scripts
    - [x] ManageSieve support
 * User Aliases
    - [x] Regular aliases
    - [x] Catch all aliases

### In the future

  * DKIM Signing
    - [ ] Allow a per domain selector

### Changelog

#### v1.0 -> v1.1
 * Changed structure to Nix Modules
 * Adds Sieve support

#### v1.1 -> v2.0
 * rename domain to fqdn, seperate fqdn from domains
 * multi domain support

### Quick Start

```nix
{ config, pkgs, ... }:
{
  imports = [
    (builtins.fetchTarball "https://github.com/r-raymond/nixos-mailserver/archive/v2.1.3.tar.gz")
  ];

  mailserver = {
    enable = true;
    fqdn = "mail.example.com";
    domains = [ "example.com" "example2.com" ];
    loginAccounts = {
        "user1@example.com" = {
            hashedPassword = "$6$/z4n8AQl6K$kiOkBTWlZfBd7PvF5GsJ8PmPgdZsFGN1jPGZufxxr60PoR0oUsrvzm2oQiflyz5ir9fFJ.d/zKm/NgLXNUsNX/";

            aliases = [
                "info@example.com"
                "postmaster@example.com"
                "postmaster@example2.com"
            ];
        };
    };
  };
}
```

For a complete list of options, see `default.nix`.



## How to Set Up a 10/10 Mail Server Guide
Check out the [Complete Setup Guide](https://github.com/r-raymond/nixos-mailserver/wiki/A-Complete-Setup-Guide) in the project's wiki.

## How to Backup

This is really easy. First off you should have a backup of your
`configuration.nix` file where you have the server config (but that is already
in a git repository right?)

Next you need to backup `/var/vmail` or whatever you have specified for the
option `mailDirectory`. This is where all the mails reside. Good options are a
cron job with `rsync` or `scp`. But really anything works, as it is simply a
folder with plenty of files in it. If your backup solution does not preserve the
owner of the files don't forget to `chown` them to `virtualMail:virtualMail` if you copy
them back (or whatever you specified as `vmailUserName`, and `vmailGoupName`).

Finally you can (optionally) make a backup of `/var/dkim` (or whatever you
specified as `dkimKeyDirectory`). If you should lose those don't worry, new ones
will be created on the fly. But you will need to repeat step `B)5` and correct
all the `dkim` keys.

## How to Test for Development

You can test the setup via `nixops`. After installation, do

```
nixops create nixops/single-server.nix nixops/vbox.nix -d mail
nixops deploy -d mail
nixops info -d mail
```

You can then test the server via e.g. `telnet`. To log into it, use

```
nixops ssh -d mail mailserver
```

To test imap manually use

```
openssl s_client -host mail.example.com -port 143 -starttls imap
```


## A Complete Mail Server Without Moving Parts

### Used Technologies
 * Nixos
 * Nixpkgs
 * Dovecot
 * Postfix
 * Rmilter
 * Rspamd
 * Clamav
 * Opendkim
 * Pam

### Features
 * unlimited domain
 * unlimited mail accounts
 * unlimited aliases for every mail account
 * spam and virus checking
 * dkim signing of outgoing emails
 * imap (optionally pop3)
 * startTLS

### Nonfeatures
 * moving parts
 * SQL databases
 * configurations that need to be made after `nixos-rebuild switch`
 * complicated storage schemes
 * webclients / http-servers

## Contributors
 * Special thanks to @Infinisil for the module rewrite
 * Special thanks to @jbboehr for multidomain implementation
 * @danbst
 * @phdoerfler
 * @eqyiel

### Alternative Implementations
 * [NixCloud Webservices](https://github.com/nixcloud/nixcloud-webservices)

### Credits
 * send mail graphic by [tnp_dreamingmao](https://thenounproject.com/dreamingmao)
   from [TheNounProject](https://thenounproject.com/) is licensed under
   [CC BY 3.0](http://creativecommons.org/~/3.0/)
 * Logo made with [Logomakr.com](https://logomakr.com)




[logo]: logo/logo.png
