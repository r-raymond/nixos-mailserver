# ![Simple Nixos MailServer][logo]
![license](https://img.shields.io/badge/license-GPL3-brightgreen.svg)
![status](https://travis-ci.org/r-raymond/nixos-mailserver.svg?branch=master)


## Stable Releases

None so far.

[Latest Release Candidate](https://github.com/r-raymond/nixos-mailserver/releases/latest)

## Features
### v1.1
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
 * Spam Filtering
    - [x] via rspamd
    - [x] hard coded sieve script to move spam into Junk folder
 * Virus Scanning
    - [x] via clamav
 * DKIM Signing
    - [x] via opendkim
 * User Management
    - [x] declarative user management
    - [x] declarative password management


### v1.2
  * Certificates
    - [x] Let's Encrypt
  * Sieves
    - [ ] Allow user defined sieve scripts
  * User Aliases
    - [ ] More complete alias support

### v2.0
  * [ ] Multiple Domains

### Changelog

#### v1.0 -> v1.1
 * Changed structure to Nix Modules
 * Adds Sieve support

### How to Deploy

```nix
{ config, pkgs, ... }:
{
  imports = [
    (builtins.fetchTarball "https://github.com/r-raymond/nixos-mailserver/releases/tag/v1.1-rc2")
  ];

  mailserver = {
    enable = true;
    domain = "example.com";
    login_accounts = {
      user1 = {
        name = "test";
        hashedPassword = "$6$Mmmx1U68$Twd8acMxqHoqFyfz3SPz1pzjY/D36gayAdpUTFMvfrHQUwObF3acuLz2GYAGFzsjHLEK/dPIv3pCwj3kZ5T2u.";
      };
    };
    virtualAliases = {
      admin = "user1";
    };
  };
}
```

For a complete list of options, see `default.nix`.


### How to Test

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
 * one domain
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
 * @danbst
 * @phdoerfler
 * @eqyiel


### Credits
 * send mail graphic by [tnp_dreamingmao](https://thenounproject.com/dreamingmao)
   from [TheNounProject](https://thenounproject.com/) is licensed under
   [CC BY 3.0](http://creativecommons.org/~/3.0/)
 * Logo made with [Logomakr.com](https://logomakr.com)

[logo]: logo/logo.png
