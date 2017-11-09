{
  network.description = "mail server";

  mailserver =
    { config, pkgs, ... }:
    {
        imports = [
            ./../default.nix
        ];

        mailserver = {
          enable = true;
          domain = "example.com";
          extraDomains = [ "example2.com" ];

          hostPrefix = "mail";
          loginAccounts = {
              "user1" = {
                  hashedPassword = "$6$/z4n8AQl6K$kiOkBTWlZfBd7PvF5GsJ8PmPgdZsFGN1jPGZufxxr60PoR0oUsrvzm2oQiflyz5ir9fFJ.d/zKm/NgLXNUsNX/";
              };
          };
          virtualAliases = {
              "info" = "user1";
              "postmaster" = "user1";
              "abuse" = "user1";
              "user1@example2.com" = "user1";
              "info@example2.com" = "user1";
              "postmaster@example2.com" = "user1";
              "abuse@example2.com" = "user1";
          };
        };
    };
}
