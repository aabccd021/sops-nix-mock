{ pkgs, lib, config, ... }:
let
  cfg = config.sops-mock;

  sopsYaml = pkgs.writeText ".sops.yaml" ''
    creation_rules:
      - path_regex: mock-secrets.yaml$
        key_groups:
          - age:
              - age1j04356vjzwwfdykjtsm4rect97zsjw49672qsfd572tw09dx7vjqvrt5up
  '';

  mockSecretsYaml = pkgs.writeText "mock-secrets.yaml" (
    pkgs.lib.generators.toYAML { } cfg.secrets
  );

  sopsFile = pkgs.runCommand "mock-sops-file" { } ''
    ${lib.getExe pkgs.sops} --config ${sopsYaml} encrypt ${mockSecretsYaml} > "$out"
  '';

in
{

  options.sops-mock = {
    enable = lib.mkEnableOption "Enable the sops-mock module";
    secrets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      example = {
        foo_secret = "value_of_foo_secret";
        bar_secret = "value_of_bar_secret";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    sops.secrets = builtins.mapAttrs (name: value: { sopsFile = lib.mkForce "${sopsFile}"; }) cfg.secrets;

    sops.age.keyFile = "/run/sops-mock-nix-keys.txt";

    boot.initrd.postDeviceCommands = ''
      printf "AGE-SECRET-KEY-1MXG0E35QY2PWSQQF6C55C9PHP6YVDFYA6HZF8U7C4P4YPP6GQVYSF5F2TU" > /run/sops-mock-nix-keys.txt
      chmod -R 400 /run/sops-mock-nix-keys.txt
    '';
  };
}
