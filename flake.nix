{
  description = "Smart folder watcher with desktop notifications";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        python3 = pkgs.python312;
        
        inbox-ai = python3.pkgs.buildPythonApplication rec {
          pname = "inbox-ai";
          version = "0.1.0";
          format = "pyproject";

          src = ./.;

          nativeBuildInputs = with python3.pkgs; [
            hatchling
          ];

          propagatedBuildInputs = with python3.pkgs; [
            asgiref
            inotify
            notify-py
          ] ++ pkgs.lib.optionals (!pkgs.stdenv.isDarwin) [
            systemd
          ];

          buildInputs = with pkgs; [
            libnotify
            systemd
          ];

          # Skip tests that require a display or specific file system setup
          doCheck = false;

          meta = with pkgs.lib; {
            description = "Smart folder watcher with desktop notifications";
            longDescription = ''
              Inbox AI is a file system watcher that monitors directories for changes
              and sends desktop notifications. It integrates well with systemd for
              daemon operation and supports both user and system-wide deployment.
            '';
            homepage = "https://github.com/flyingleafe/inbox-ai";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.linux;
            mainProgram = "inbox";
          };

          # Ensure the package can find system libraries
          postInstall = ''
            # Create wrapper scripts that ensure proper library paths
            wrapProgram $out/bin/inbox \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.libnotify pkgs.systemd ]}
              
            wrapProgram $out/bin/inbox-systemd \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.libnotify pkgs.systemd ]}
          '';
        };

      in
      {
        packages = {
          default = inbox-ai;
          inbox-ai = inbox-ai;
        };

        apps = {
          default = flake-utils.lib.mkApp {
            drv = inbox-ai;
            name = "inbox";
          };
          inbox = flake-utils.lib.mkApp {
            drv = inbox-ai;
            name = "inbox";
          };
          inbox-systemd = flake-utils.lib.mkApp {
            drv = inbox-ai;
            name = "inbox-systemd";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python3
            python3.pkgs.pip
            python3.pkgs.uv
            libnotify
            systemd
            # Development tools
            python3.pkgs.pytest
            python3.pkgs.mypy
            python3.pkgs.ruff
            python3.pkgs.pre-commit
          ];

          shellHook = ''
            echo "Inbox AI development environment"
            echo "Run 'uv sync --extra dev' to install dependencies"
          '';
        };
      }
    ) // {
      # NixOS module
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.inbox-ai;
        in
        {
          options.services.inbox-ai = {
            enable = mkEnableOption "Inbox AI file watcher service";

            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.default;
              description = "The inbox-ai package to use.";
            };

            user = mkOption {
              type = types.str;
              default = "inbox";
              description = "User account under which inbox-ai runs.";
            };

            group = mkOption {
              type = types.str;
              default = "inbox";
              description = "Group account under which inbox-ai runs.";
            };

            watchPath = mkOption {
              type = types.str;
              default = "/var/lib/inbox";
              description = "Directory to watch for file changes.";
            };

            extraArgs = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Extra arguments to pass to inbox-ai.";
            };
          };

          config = mkIf cfg.enable {
            users.users = optionalAttrs (cfg.user == "inbox") {
              inbox = {
                isSystemUser = true;
                group = cfg.group;
                description = "Inbox AI service user";
                home = cfg.watchPath;
                createHome = true;
              };
            };

            users.groups = optionalAttrs (cfg.group == "inbox") {
              inbox = {};
            };

            systemd.services.inbox-ai = {
              description = "Inbox AI File Watcher";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                ExecStart = "${cfg.package}/bin/inbox-systemd --path ${cfg.watchPath} ${concatStringsSep " " cfg.extraArgs}";
                Restart = "always";
                RestartSec = "5";
                
                # Security settings
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                ReadWritePaths = [ cfg.watchPath ];
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectControlGroups = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                LockPersonality = true;
                MemoryDenyWriteExecute = true;
                RestrictNamespaces = true;
                SystemCallFilter = [ "@system-service" "~@privileged" ];
              };

              environment = {
                INBOX_WATCH_PATH = cfg.watchPath;
              };
            };

            # Ensure the watch directory exists
            system.activationScripts.inbox-ai = ''
              mkdir -p ${cfg.watchPath}
              chown ${cfg.user}:${cfg.group} ${cfg.watchPath}
              chmod 755 ${cfg.watchPath}
            '';
          };
        };

      # Home Manager module
      homeManagerModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.inbox-ai;
        in
        {
          options.services.inbox-ai = {
            enable = mkEnableOption "Inbox AI file watcher service";

            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.default;
              description = "The inbox-ai package to use.";
            };

            watchPath = mkOption {
              type = types.str;
              default = "${config.home.homeDirectory}/Inbox";
              description = "Directory to watch for file changes.";
            };

            notifications = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to enable desktop notifications.";
            };

            extraArgs = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Extra arguments to pass to inbox-ai.";
            };
          };

          config = mkIf cfg.enable {
            home.packages = [ cfg.package ];

            systemd.user.services.inbox-ai = {
              Unit = {
                Description = "Inbox AI File Watcher";
                After = [ "graphical-session.target" ];
              };

              Service = {
                Type = "simple";
                ExecStart = concatStringsSep " " ([
                  "${cfg.package}/bin/inbox"
                  "--path ${cfg.watchPath}"
                ] ++ optional (!cfg.notifications) "--no-notify"
                  ++ cfg.extraArgs);
                Restart = "always";
                RestartSec = "5";
              };

              Install = {
                WantedBy = [ "default.target" ];
              };
            };

            # Ensure the watch directory exists
            home.activation.inbox-ai = lib.hm.dag.entryAfter ["writeBoundary"] ''
              mkdir -p ${cfg.watchPath}
            '';
          };
        };
    };
}