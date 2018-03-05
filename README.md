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

See the [mailing list archive](https://www.freelists.org/archive/snm/)

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

Checkout the [Complete Backup Guide](https://github.com/r-raymond/nixos-mailserver/wiki/A-Complete-Backup-Guide). Backups are easy with `SNM`.

## Development

See the [How to Develop SNM](https://github.com/r-raymond/nixos-mailserver/wiki/How-to-Develop-SNM) wiki page.

## Contributors
See the [contributor tab](https://github.com/r-raymond/nixos-mailserver/graphs/contributors)

### Alternative Implementations
 * [NixCloud Webservices](https://github.com/nixcloud/nixcloud-webservices)

### Credits
 * send mail graphic by [tnp_dreamingmao](https://thenounproject.com/dreamingmao)
   from [TheNounProject](https://thenounproject.com/) is licensed under
   [CC BY 3.0](http://creativecommons.org/~/3.0/)
 * Logo made with [Logomakr.com](https://logomakr.com)




[logo]: logo/logo.png
