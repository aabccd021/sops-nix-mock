{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.sops-mock;

  sopsConfig = config.sops;

  sopsYaml = pkgs.writeText ".sops.yaml" ''
    creation_rules:
      - path_regex: ".*"
        key_groups:
          - age:
              - age1d6s9ne45qkchp5y9v5s527jw7zzu055jcwd2smgy70epwyz7pd8qmx82ft
  '';

  mkSopsFile =
    cfg:
    let
      name = cfg._module.args.name;
      myml = pkgs.writeText "${name}.yaml" (pkgs.lib.generators.toYAML { } { ${cfg.key} = cfg.value; });
    in
    pkgs.runCommand "${name}-mock-secrets.yaml" { } ''
      ${lib.getExe pkgs.sops} --config ${sopsYaml} encrypt ${myml} > "$out"
    '';

in
{

  options.sops-mock = {
    enable = lib.mkEnableOption "Enable the sops-mock module";
    age.keyFile = lib.mkOption {
      type = lib.types.path;
      default = "/run/sops-mock-nix-keys.txt";
      readOnly = true;
    };
    secrets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, ... }:
          {
            options = {
              key = lib.mkOption {
                type = lib.types.str;
                default = sopsConfig.secrets.${config._module.args.name}.key;
              };
              value = lib.mkOption {
                type = lib.types.str;
              };
              sopsFile = lib.mkOption {
                type = lib.types.path;
                readOnly = true;
              };
            };
            config = {
              sopsFile = mkSopsFile config;
            };
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.postDeviceCommands = ''
      printf "AGE-SECRET-KEY-14YX9K83AY8RAZX3P0CYGK60RRE9XHYC6ZY9XSM7PMTRGL6QVAH2SSFPGLS" > /run/sops-mock-nix-keys.txt
      chmod -R 400 /run/sops-mock-nix-keys.txt
    '';
  };
}
