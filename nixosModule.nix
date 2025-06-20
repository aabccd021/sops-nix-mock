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
              - ${builtins.readFile pkgs.mock-secrets.age.alice.public}
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
      cp -Lr "${pkgs.mock-secrets.age.alice.private}" /run/sops-mock-nix-keys.txt
      chmod -R 400 /run/sops-mock-nix-keys.txt
    '';
  };
}
