{ mockSecrets }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.sops-mock;

  sopsYaml = pkgs.writeText ".sops.yaml" ''
    creation_rules:
      - path_regex: ".*"
        key_groups:
          - age:
              - ${builtins.readFile mockSecrets.age.alice.public}
  '';

  mkSopsFile =
    name: cfg:
    let
      key = config.sops.secrets.${name}.key;
      myml = pkgs.writeText "${name}.yaml" (pkgs.lib.generators.toYAML { } { ${key} = cfg.value; });
    in
    pkgs.runCommand "${name}-mock-secrets.yaml" { } ''
      ${lib.getExe pkgs.sops} --config ${sopsYaml} encrypt ${myml} > "$out"
    '';

in
{

  options.sops-mock = {
    enable = lib.mkEnableOption "Enable the sops-mock module";
    secrets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, ... }:
          {
            options = {
              value = lib.mkOption {
                type = lib.types.str;
              };
              sopsFile = lib.mkOption {
                type = lib.types.path;
                readOnly = true;
              };
            };
            config = {
              sopsFile = mkSopsFile config._module.args.name config;
            };
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable {
    sops.age.keyFile = "/run/sops-mock-nix-keys.txt";
    boot.initrd.postDeviceCommands = ''
      cp -Lr "${mockSecrets.age.alice.private}" /run/sops-mock-nix-keys.txt
      chmod -R 400 /run/sops-mock-nix-keys.txt
    '';
  };
}
