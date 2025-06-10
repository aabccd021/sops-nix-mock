{
  pkgs,
  sops-nix,
  sops-nix-mock,
}:
let
  baseModule = {
    imports = [
      sops-nix.nixosModules.default
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
          foo.value = "foo";
          lorem.value = "ipsum";
          lorem.key = "loremkey";
          dolor = {
            key = "sit";
            value = "dolorValue";
          };
        };

        sops.age.keyFile = config.sops-mock.age.keyFile;

        sops.secrets = {
          foo.sopsFile = config.sops-mock.secrets.foo.sopsFile;
          lorem.sopsFile = config.sops-mock.secrets.lorem.sopsFile;
          lorem.key = "loremkey";
          dolor.key = "sit";
          dolor.sopsFile = config.sops-mock.secrets.dolor.sopsFile;
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
      assertStdout("foo", "cat /run/secrets/foo")
      assertStdout("ipsum", "cat /run/secrets/lorem")
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

        sops.age.keyFile = config.sops-mock.age.keyFile;
        sops.secrets.foo = {
          sopsFile = config.sops-mock.secrets.foo.sopsFile;
          key = "fookey";
        };

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
