let
  domain = "example.com";
  host_prefix = "mail";
  login_accounts = [ "user1" "user2" ];
  vmail_id_start = 5000;
  vmail_user_name = "vmail";
  vmail_group_name = "vmail";
  mail_dir = "/var/vmail";
  cert_file = "mail-server.crt";
  key_file = "mail-server.key";
in
let
  vmail_user = [{
    name = vmail_user_name;
    isNormalUser = false;
    uid = vmail_id_start;
    home = mail_dir;
    createHome = true;
    group = vmail_group_name;
  }];
  accountsToUser = x: {
    name = x + "@" + domain;
    isNormalUser = false;
    group = vmail_group_name;
  };
  mail_user = map accountsToUser login_accounts;
in
{
  networking.hostName = host_prefix + "." + domain;
  
  environment.systemPackages = with pkgs; [
    dovecot opendkim openssh postfix clamav rspamd rmilter
  ];
  
  # set the vmail gid to a specific value
  users.groups = {
    vmail = { gid = vmail_id_start; };
  }
}
