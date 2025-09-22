{
  pkgs,
  inputs,
  sops-nix-mock,
}:
let
  baseModule = {
    imports = [
      inputs.sops-nix.nixosModules.default
      sops-nix-mock.nixosModules.default
    ];
    # allow-import-from-derivation = false;
    sops.validateSopsFiles = false;
    sops-mock.enable = true;

  };

in
{
  test1 = pkgs.nixosTest {
    name = "test1";

    nodes.server =
      { config, ... }:
      {
        imports = [
          baseModule
        ];

        sops-mock.secrets = {
          foo = {
            key = "foo";
            value = "fooValue";
          };
          lorem = {
            key = "ipsum";
            value = "loremValue";
          };
          dolor.value = "dolorValue";
        };

        sops = {
          age.keyFile = config.sops-mock.age.keyFile;
          secrets = {
            foo.sopsFile = config.sops-mock.secrets.foo.sopsFile;
            lorem = {
              key = "ipsum";
              sopsFile = config.sops-mock.secrets.lorem.sopsFile;
            };
            dolor = {
              sopsFile = config.sops-mock.secrets.dolor.sopsFile;
              key = "sit";
            };
          };
        };

      };

    # The server should fail to start because the database is not created
    testScript = ''
      def assertStdout(exp: str, cmd: str) -> None:
          act = server.succeed(cmd)
          if exp != act:
              raise Exception(f"{exp!r} != {act!r}")

      start_all()
      server.wait_for_unit("multi-user.target")
      assertStdout("fooValue", "cat /run/secrets/foo")
      assertStdout("loremValue", "cat /run/secrets/lorem")
      assertStdout("dolorValue", "cat /run/secrets/dolor")
    '';
  };

  test2 = pkgs.nixosTest {
    name = "test2";

    nodes.server =
      { config, ... }:
      {
        imports = [
          baseModule
        ];

        sops-mock.secrets.foo.value = "fooValue";

        sops.secrets.foo.sopsFile = config.sops-mock.secrets.foo.sopsFile;
        sops.age.keyFile = config.sops-mock.age.keyFile;

        environment.systemPackages = [
          (pkgs.writeShellScriptBin "catFoo" ''
            cat ${config.sops.secrets.foo.path}
          '')
        ];

      };

    # The server should fail to start because the database is not created
    testScript = ''
      def assertStdout(exp: str, cmd: str) -> None:
          act = server.succeed(cmd)
          if exp != act:
              raise Exception(f"{exp!r} != {act!r}")

      start_all()
      server.wait_for_unit("multi-user.target")
      assertStdout("fooValue", "catFoo")
    '';
  };

}
