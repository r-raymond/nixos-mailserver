#  nixos-mailserver: a simple mail server
#  Copyright (C) 2016  Robin Raymond
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

{ config, pkgs, vmail_group_name, vmail_user_name, dovecot_maildir, enable_imap,
enable_pop3, ... }:
{
  # Set the correct permissions for dovecot vmail folder. See
  # <http://wiki2.dovecot.org/SharedMailboxes/Permissions>. We choose
  # to use the systemd service to set the folder permissions whenever
  # dovecot gets started.
  systemd.services.dovecot2.preStart = "chmod 02770 /var/vmail";

  services.dovecot2 = {
    enable = true;
    enableImap = enable_imap;        # IMAP
    enablePop3 = enable_pop3;        # POP3
    mailGroup = vmail_group_name;
    mailUser = vmail_user_name;
    mailLocation = dovecot_maildir;  # maildir in format "/${domain}/${user}/"
   };
}
