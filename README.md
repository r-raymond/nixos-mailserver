# nixos-mailserver
![license](https://img.shields.io/badge/license-GPL3-brightgreen.svg)

## Work in progress...

### What works and what is missing for first release v 1.0
 * Postfix
    - [x] starts
    - [x] receive email on port 25
    - [x] receive email on submission port 587
    - [x] lmtp with dovecot
 * Dovecot
    - [x] lmtp with postfix
    - [x] creates maildir folders, saves mails
    - [x] imap retrieval
    - [x] pop3 retrieval
 * Certificates
    - [x] manual certificates
    - [x] on the fly creation
    - [ ] TODO: Let's Encrypt (postponed to future release)
 * Spam Filtering
    - [x] scans emails
 * Virus Scanning
    - [x] Checks incoming mail for viruses
 * DKIM Signing
    - [x] Works
 * User Management
    - [x] Creates Users
    - [x] Set Passwords in config file
 * Update Documentation
    - [ ] Remove all `TODO`s
    - [ ] Write a Starter Guide
    - [ ] Make a Small Homepage
    - [ ] Flesh Out Documentation
 * Test
    - [ ] Test
    - [ ] Squash Bugs
    - [ ] Test
    - [ ] ...

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

## Ideas for future releases
 * Fine grained control over ownership of aliases
 * More than one domain
 * Let's Encrypt

## Contributors
 * Special thanks to @Infinisil for the module rewrite
 * @danbst
