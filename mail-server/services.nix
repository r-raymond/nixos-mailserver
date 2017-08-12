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

{ mail_dir, vmail_user_name, vmail_group_name, valiases, domain, enable_imap,
enable_pop3 }:

let
  # valiasToString :: { from = "..."; to = "..." } -> String
  valiasToString = x: x.from + "@" + domain + " " + x.to "@" + domain + "\n";

  # valias_file :: [ String ]
  valiases_file = map valiasToString valiases;
in
{
  # rspamd
  rspamd = {
    enable = true;
  };

  postfix = import ./postfix.nix {
    valiases_file = ""; vaccounts_file = ""; #< TODO: FIX
  };

  dovecot2 = import ./dovecot.nix {
    inherit vmail_group_name vmail_user_name mail_dir enable_imap
            enable_pop3;
  };
}
