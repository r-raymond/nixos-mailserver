# nixos-mailserver
![license](https://img.shields.io/badge/license-GPL3-brightgreen.svg)

## Work in progress...

### What works and what is missing for first release
 * Postfix
    - [x] starts
    - [x] receive email on port 25
    - [ ] receive email on submission port 587 (to check)
    - [x] lmtp with dovecot
 * Dovecot
    - [x] lmpto with postfix
    - [x] creates maildir folders, saves mails
    - [x] imap retrieval
    - [ ] pop3 retrieval (to check)
 * Certificates
    - [x] manual certificates
    - [x] on the fly creation
    - [ ] TODO: Let's Encrypt
 * Spam Filtering
    - [x] scans emails
    - [ ] Dovecot moves spam to spam folder (to check)
 * Virus Scanning
    - [ ] TODO: Implement
 * DKIM Signing
    - [ ] TODO: Implement
 * User Management
    - [x] Creates Users
    - [ ] TODO: Set Passwords in config file

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
