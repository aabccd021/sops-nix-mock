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

    nodes.server = {
      imports = [
        baseModule
      ];

      sops-mock.secrets = {
        foo.value = "foo";
        lorem.value = "ipsum";
      };

      sops.secrets = {
        foo.sopsFile = "/dev/null";
        lorem.sopsFile = "/dev/null";
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

        sops.secrets = {
          foo.sopsFile = "/dev/null";
          foo.key = "fookey";
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
