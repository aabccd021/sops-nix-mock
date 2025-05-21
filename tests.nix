{
  pkgs,
  sops-nix,
  sops-nix-mock,
}:
let

  baseModule = {
    sops-mock.enable = true;
    sops-mock.secrets = {
      foo = "foo";
      lorem = "ipsum";
    };

    sops.secrets = {
      foo.sopsFile = "/this/path/should/be/overridden";
      lorem.sopsFile = "/this/path/should/be/overridden";
    };

    # Make sops-nix-mock works with nixConfig.allow-import-from-derivation = false;
    sops.validateSopsFiles = false;
  };

in
{
  test1 = pkgs.nixosTest {
    name = "test1";

    nodes.server = {
      imports = [
        sops-nix.nixosModules.default
        sops-nix-mock.nixosModules.default
        baseModule
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
      assertStdout("foo", "cat /run/secrets/foo")
      assertStdout("ipsum", "cat /run/secrets/lorem")
    '';
  };
}
