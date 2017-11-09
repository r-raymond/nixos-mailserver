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
              "user1@example.com" = {
                  hashedPassword = "$6$/z4n8AQl6K$kiOkBTWlZfBd7PvF5GsJ8PmPgdZsFGN1jPGZufxxr60PoR0oUsrvzm2oQiflyz5ir9fFJ.d/zKm/NgLXNUsNX/";
              };
          };
          virtualAliases = {
              "user1@example2.com" = "user1@example.com";
              "info@example.com" = "user1@example.com";
              "postmaster@example.com" = "user1@example.com";
              "abuse@example.com" = "user1@example.com";
              "info@example2.com" = "user1@example.com";
              "postmaster@example2.com" = "user1@example.com";
              "abuse@example2.com" = "user1@example.com";
          };
        };
    };
}
