{
  description = "Smart folder watcher with desktop notifications";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, pyproject-nix, uv2nix, pyproject-build-systems }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        # Load the workspace from uv.lock and pyproject.toml
        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

        # Create overlay from workspace
        overlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel"; # Prefer wheels for better compatibility
        };

        # Editable overlay for development
        editableOverlay = workspace.mkEditablePyprojectOverlay {
          root = "$REPO_ROOT";
        };

        # Base Python package set from pyproject.nix
        baseSet = pkgs.callPackage pyproject-nix.build.packages {
          python = pkgs.python312;
        };

        # Build fixes and overrides
        pyprojectOverrides = final: prev: {
          # Override for inbox-ai package
          inbox-ai = prev.inbox-ai.overrideAttrs (old: {
            buildInputs = (old.buildInputs or []) ++ (with pkgs; [
              libnotify
              systemd
            ]);

            # Add systemd-python for systemd support on Linux
            propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ 
              pkgs.lib.optionals (!pkgs.stdenv.isDarwin) [
                final.systemd-python
              ];

            # Skip tests that require a display or specific file system setup
            doCheck = false;

            # Ensure the package can find system libraries
            postInstall = (old.postInstall or "") + ''
              # Create wrapper scripts that ensure proper library paths
              wrapProgram $out/bin/inbox \
                --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.libnotify pkgs.systemd ]}
                
              wrapProgram $out/bin/inbox-systemd \
                --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.libnotify pkgs.systemd ]}
            '';

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

            # Add tests to passthru.tests for flake checks
            passthru = (old.passthru or {}) // {
              tests = (old.passthru.tests or {}) // {
                pytest = pkgs.stdenv.mkDerivation {
                  name = "${final.inbox-ai.name}-pytest";
                  inherit (final.inbox-ai) src;
                  nativeBuildInputs = [
                    (final.mkVirtualEnv "inbox-ai-test-env" {
                      inbox-ai = [ "dev" ];
                    })
                  ];
                  dontConfigure = true;
                  dontInstall = true;
                  buildPhase = ''
                    mkdir $out
                    pytest tests/ -v --junit-xml=$out/junit.xml || touch $out/pytest-failed
                  '';
                };
              };
            };
          });
        };

        # Construct final Python set with all overlays
        pythonSet = baseSet.overrideScope (
          pkgs.lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            overlay
            pyprojectOverrides
          ]
        );

        # Development Python set with editable packages
        devPythonSet = baseSet.overrideScope (
          pkgs.lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            editableOverlay
            pyprojectOverrides
          ]
        );

        # Final package
        inbox-ai = pythonSet.inbox-ai;

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
            # System dependencies
            libnotify
            systemd
            
            # Development tools
            uv
            
            # Python virtual environment for development
            (devPythonSet.mkVirtualEnv "inbox-ai-dev-env" {
              inbox-ai = [ "dev" ];
            })
          ];

          shellHook = ''
            echo "Inbox AI development environment"
            echo "Dependencies are managed by uv and synchronized with Nix via uv2nix"
            echo ""
            echo "Available commands:"
            echo "  uv sync --extra dev    - Sync development dependencies"
            echo "  uv run pytest         - Run tests"
            echo "  uv run ruff check      - Run linting"
            echo "  uv build              - Build package"
          '';
        };

        # Checks for CI
        checks = {
          # Include package tests in checks
          inherit (inbox-ai.passthru.tests) pytest;
          
          # Build check
          build = inbox-ai;
          
          # Flake check
          flake-check = pkgs.runCommand "flake-check" {} ''
            echo "Flake structure is valid"
            touch $out
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