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
        };
    };
}
