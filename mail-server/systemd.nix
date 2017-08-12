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

{ mail_dir, vmail_group_name }:

{
  # Set the correct permissions for dovecot vmail folder. See
  # <http://wiki2.dovecot.org/SharedMailboxes/Permissions>. We choose
  # to use the systemd service to set the folder permissions whenever
  # dovecot gets started.
  services.dovecot2.preStart =
  ''
    mkdir -p ${mail_dir}
    chgrp ${vmail_group_name} ${mail_dir}
    chmod 02770 ${mail_dir}
  '';
}
