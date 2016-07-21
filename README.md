# nixos-mailserver

## A Complete Mail Server Without Moving Parts

### Used Technologies
 * nixos 16.03
 * nixpkgs
 * dovecot
 * postfix
 * rmilter
 * rspamd
 * clamav
 * opendkim
 * pam

### Features
 * unlimited domains
 * unlimited mail accounts for every domain
 * unlimited aliases for every mail account
 * spam and virus checking
 * dkim signing of outgoing emails

### Nonfeatures
 * moving parts
 * SQL databases
 * configurations that need to be made after `nixos-rebuild switch`
 * complicated storage schemes
 * webclients / http-servers
