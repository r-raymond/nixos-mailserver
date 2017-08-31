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

{ lib, vmail_id_start, vmail_user_name, vmail_group_name, domain, mail_dir,
login_accounts }:

let
  vmail_user = [{
    name = vmail_user_name;
    isNormalUser = false;
    uid = vmail_id_start;
    home = mail_dir;
    createHome = true;
    group = vmail_group_name;
  }];

  # accountsToUser :: String -> UserRecord
  accountsToUser = account: {
    name = account.name + "@" + domain;
    isNormalUser = false;
    group = vmail_group_name;
    inherit (account) hashedPassword;
  };

  # mail_user :: [ UserRecord ]
  mail_user = map accountsToUser (lib.attrValues login_accounts);

in
{
  # set the vmail gid to a specific value
  groups = {
    vmail = { gid = vmail_id_start; };
  };

  # define all users
  extraUsers = vmail_user ++ mail_user;
}
