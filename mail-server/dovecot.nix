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

{ vmail_group_name, vmail_user_name, mail_dir, enable_imap, enable_pop3,
... }:
let
  # maildir in format "/${domain}/${user}/"
  dovecot_maildir = "maildir:${mail_dir}/%d/%n/";
in
{
  enable = true;
  enableImap = enable_imap;
  enablePop3 = enable_pop3;
  mailGroup = vmail_group_name;
  mailUser = vmail_user_name;
  mailLocation = dovecot_maildir;
  #sslServerCert = "/etc/nixos/cert/${cert_file}"; // TODO: Define
  #sslServerKey = "/etc/nixos/cert/${key_file}";   // TODO: Define
  enableLmtp = true;
  extraConfig = ''
    #Extra Config
    mail_access_groups = ${vmail_group_name}
    ssl = required

    service lmtp {
      unix_listener /var/lib/postfix/queue/private/dovecot-lmtp {
        group = postfix
        mode = 0600
        user = postfix  # TODO: < make variable
      }
    }

    service auth {
      unix_listener /var/lib/postfix/queue/private/auth {
        mode = 0660
        user = postfix  # TODO: < make variable
        group = postfix  # TODO: < make variable
      }
    }

    auth_mechanisms = plain login

    namespace inbox {

    #prefix = INBOX.
    # the namespace prefix isn't added again to the mailbox names.
    inbox = yes
    # ... 

    mailbox "Trash" {
      auto = no
      special_use = \Trash
    }

    mailbox "Junk" {
      auto = subscribe
      special_use = \Junk
    }

    mailbox "Drafts" {
      auto = subscribe
      special_use = \Drafts
    }

    mailbox "Sent" {
      auto = subscribe
      special_use = \Sent
      }
    }
  '';
}
