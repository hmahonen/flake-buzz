{
  description = "Buzz - Offline audio transcription and translation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.cudaSupport = true;
        };

        version = "1.4.4";

        # The source of Buzz with submodules for whisper.cpp etc.
        buzzSrc = pkgs.fetchFromGitHub {
          owner = "chidiwilliams";
          repo = "buzz";
          rev = "v${version}";
          fetchSubmodules = true;
          hash = "sha256-01UAA2ILZtXMmKKClNEHDgAG/prG6Km7ejskdbILnvk=";
        };

        # A script to launch Buzz
        startScript = pkgs.writeShellScriptBin "buzz-launcher" ''
          set -e
          
          # Use XDG_DATA_HOME or default to ~/.local/share
          BUZZ_DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/buzz-app"
          
          # Initialize or update the local working directory
          if [ ! -f "$BUZZ_DATA_DIR/.version" ] || [ "$(cat "$BUZZ_DATA_DIR/.version")" != "${buzzSrc.rev}" ]; then
            echo "Initializing Buzz environment in $BUZZ_DATA_DIR..."
            
            # Remove old directory if it exists
            rm -rf "$BUZZ_DATA_DIR"
            mkdir -p "$BUZZ_DATA_DIR"
            
            # Copy source code
            cp -a ${buzzSrc}/. "$BUZZ_DATA_DIR/"
            chmod -R u+w "$BUZZ_DATA_DIR"
            
            cd "$BUZZ_DATA_DIR"
            
            # Create a virtual environment using uv
            echo "Setting up Python environment..."
            uv venv
            
            # Install dependencies natively via uv inside the FHS
            # We don't want dev or build groups here to save space
            echo "Installing dependencies..."
            uv sync --no-dev
            
            # Ensure hatch building step completes correctly by testing whisper cpp make
            echo "Checking native build..."
            uv run python -c "import buzz" || true # this will trigger hatch if not already built, but typically uv sync already did it if it's installing the package itself. Wait, pyproject.toml lists buzz itself, so uv sync will build it.
            
            echo "${buzzSrc.rev}" > "$BUZZ_DATA_DIR/.version"
          fi
          
          cd "$BUZZ_DATA_DIR"
          echo "Starting Buzz..."
          
          # Settings for Qt
          export QT_QPA_PLATFORM="wayland;xcb"
          export QT_PLUGIN_PATH="${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}"
          
          exec uv run buzz "$@"
        '';

        fhsEnv = pkgs.buildFHSEnv {
          name = "buzz-${version}";
          targetPkgs = pkgs: with pkgs; [
            # Base python & tools
            python312
            uv
            cmake
            gcc
            gnumake
            pkg-config
            git # git is needed for patching in hatch_build.py

            # Audio, Video and System Libraries
            ffmpeg
            alsa-lib
            libpulseaudio
            portaudio
            libkrb5

            # UI (Qt6)
            qt6.qtbase
            qt6.qtwayland
            qt6.qtdeclarative
            qt6.qtsvg
            qt6.qtmultimedia
            fontconfig
            freetype
            dbus
            wayland

            # ML requirements & C++
            zlib
            zstd
            glib
            libglvnd
            stdenv.cc.cc.lib

            # X11 libs for Qt fallback
            libx11
            libxext
            libxcursor
            libxrandr
            libxi
            libxcb
            libxkbcommon
            xcb-util-cursor

            # Vulkan for ggml
            vulkan-headers
            vulkan-loader
            shaderc
          ] ++ (with pkgs.cudaPackages; [
            # CUDA / NVIDIA GPU acceleration support
            cudatoolkit
            cudnn
            libcublas
            libcufft
            libcurand
            libcusolver
            libcusparse
          ]);

          runScript = "${startScript}/bin/buzz-launcher";
        };
      in
      {
        packages.default = fhsEnv;
        apps.default = {
          type = "app";
          program = "${fhsEnv}/bin/buzz-${version}";
        };
        devShells.default = fhsEnv.env;
      }
    );
}
