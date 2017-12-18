# ![Simple Nixos MailServer][logo]
![license](https://img.shields.io/badge/license-GPL3-brightgreen.svg)
![status](https://travis-ci.org/r-raymond/nixos-mailserver.svg?branch=master)


## Stable Releases

* [SNM v2.0.3](https://github.com/r-raymond/nixos-mailserver/releases/v2.0.3)

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

### In the future

  * User Aliases
    - [ ] More complete alias support (Differentiate between forwarding addresses and sending aliases)
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
    (builtins.fetchTarball "https://github.com/r-raymond/nixos-mailserver/archive/v2.0.2.tar.gz")
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
Mail servers can be a tricky thing to set up. This guide is supposed to run you
through the most important steps to achieve a 10/10 score on `mail-tester.com`.

What you need:

  * A server with a public IP (referred to as `server-IP`)
  * A Fully Qualified Domain Name (`FQDN`) where your server is reachable,
    so that other servers can find yours. Common FQDN include `mx.example.com`
    (where `example.com` is a domain you own) or `mail.example.com`. The domain
    is referred to as `server-domain` (`example.com` in the above example) and
    the `FQDN` is referred to by `server-FQDN` (`mx.example.com` above).
  * A list of domains you want to your email server to serve. (Note that this
    does not have to include `server-domain`, but may of course). These will be
    referred to as `domains`. As an example, `domains = [ example1.com,
    example2.com ]`.

### A) Setup server

The following describes a server setup that is fairly complete. Even though
there are more possible options (see `default.nix`), these should be the most
common ones.

```nix
{ config, pkgs, ... }:
{
  imports = [
    (builtins.fetchTarball "https://github.com/r-raymond/nixos-mailserver/archive/v2.0.3.tar.gz")
  ];

  mailserver = {
    enable = true;
    fqdn = <server-FQDN>;
    domains = [ <domains> ];

    # A list of all login accounts. To create the password hashes, use
    # mkpasswd -m sha-512 "super secret password"
    loginAccounts = {
        "user1@example.com" = {
            hashedPassword = "$6$/z4n8AQl6K$kiOkBTWlZfBd7PvF5GsJ8PmPgdZsFGN1jPGZufxxr60PoR0oUsrvzm2oQiflyz5ir9fFJ.d/zKm/NgLXNUsNX/";

            aliases = [
                "postmaster@example.com"
                "postmaster@example2.com"
            ];

            # Make this user the catchAll address for domains example.com and
            # example2.com
            catchAll = [
                "example.com"
                "example2.com"
            ];
        };

        "user2@example.com" = { ... };
    };

    # Extra virtual aliases. These are email addresses that are forwarded to
    # loginAccounts addresses.
    extraVirtualAliases = {
        # address = forward address;
        "abuse@example.com" = "user1@example.com";
    };

    # Use Let's Encrypt certificates. Note that this needs to set up a stripped
    # down nginx and opens port 80.
    certificateScheme = 3;

    # Enable IMAP and POP3
    enableImap = true;
    enablePop3 = true;
    enableImapSsl = true;
    enablePop3Ssl = true;

    # whether to scan inbound emails for viruses (note that this requires at least
    # 1 Gb RAM for the server. Without virus scanning 256 MB RAM should be plenty)
    virusScanning = false;
  };
}
```

After a `nixos-rebuild switch --upgrade` your server should be good to go. If
you want to use `nixops` to deploy the server, look in the subfolder `nixops`
for some inspiration.


### B) Setup everything else

#### Step 1: Set DNS entry for server

Add a DNS record to the domain `server-domain` with the following entries

| Name (Subdomain) | TTL   | Type | Priority | Value             |
| ---------------- | ----- | ---- | -------- | ----------------- |
| `server-FQDN`    | 10800 | A    |          | `server-IP`       |

This resolved DNS equries for `server-FQDN` to `server-IP`. You can test if your
setting is correct by

```
ping <server-FQDN>
64 bytes from <server-FQDN> (<server-IP>): icmp_seq=1 ttl=46 time=21.3 ms
...
```

Note that it can take a while until a DNS entry is propagated.

#### Step 2: Set rDNS (reverse DNS) entry for server
Wherever you have rented your server, you should be able to set reverse DNS
entries for the IP's you own. Add an entry resolving `server-IP` to
`server-FQDN`

You can test if your setting is correct by

```
host <server-IP>
<server-IP>.in-addr.arpa domain name pointer <server-FQDN>.
```

Note that it can take a while until a DNS entry is propagated.

#### Step 3: Set `MX` Records

For every `domain` in `domains` do:
  * Add a `MX` record to the domain `domain`

    | Name (Subdomain) | TTL   | Type | Priority | Value             |
    | ---------------- | ----- | ---- | -------- | ----------------- |
    | `domain`         |       | MX   | 10       | `server-FQDN`     |

You can test this via
```
dig -t MX <domain>

...
;; ANSWER SECTION:
<domain>    10800   IN  MX  10 <server-FQDN>
...
```

Note that it can take a while until a DNS entry is propagated.

#### Step 4: Set `SPF` Records

For every `domain` in `domains` do:
  * Add a `SPF` record to the domain `domain`

    | Name (Subdomain) | TTL   | Type | Priority | Value                         |
    | ---------------- | ----- | ---- | -------- | -----------------             |
    | `domain`         | 10800 | TXT  |          | `v=spf1 ip4:<server-IP> -all` |

You can check this with `dig -t TXT <domain>` similar to the last section.

Note that it can take a while until a DNS entry is propagated. If you want to
use multiple servers for your email handling, don't forget to add all server
IP's to this list.

#### Step 5: Set `DKIM` signature

In this section we assume that your `dkimSelector` is set to `mail`. If you have a different selector, replace
all `mail`'s below accordingly.

For every `domain` in `domains` do:
  * Go to your server and navigate to the dkim key directory (by default
    `/var/dkim`). There you will find a public key for any domain in the
    `domain.txt` file. It will look like
    ```
    mail._domainkey IN TXT "v=DKIM1; r=postmaster; g=*; k=rsa; p=<really-long-key>" ; ----- DKIM mail for domain.tld
    ```
  * Add a `DKIM` record to the domain `domain`

    | Name (Subdomain)         | TTL   | Type | Priority | Value                          |
    | ----------------         | ----- | ---- | -------- | -----------------              |
    | mail._domainkey.`domain` | 10800 | TXT  |          | `v=DKIM1; p=<really-long-key>` |


You can check this with `dig -t TXT mail._domainkey.<domain>` similar to the last section.

Note that it can take a while until a DNS entry is propagated.


### C) Test your Setup

Write an email to your aunt (who has been waiting for your reply far too long),
and sign up for some of the finest newsletters the Internet has. Maybe you want
to sign up for the [SNM Announcement List](https://www.freelists.org/list/snm)?

Besides that, you can send an email to [mail-tester.com](https://www.mail-tester.com/) and see how you score,
and let [mxtoolbox.com](http://mxtoolbox.com/) take a look at your setup, but if you followed
the steps closely then everything should be awesome!


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
