{
  network.description = "mail server";

  mailserver =
    { config, pkgs, ... }:
    {
        imports = [
            ./../mail-config.nix
        ];
    };
}
