{
  description = "Self-hosted game stream host for Moonlight.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, ... }:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import (inputs.nixpkgs) {
          inherit system;
          config.allowUnfree = true;
        };

        inherit (inputs.nixpkgs) lib;
        inherit (pkgs) stdenv;

        nativeBuildInputs = with pkgs; [
          cmake
          pkg-config
          python3
          makeWrapper
          wayland-scanner
          autoPatchelfHook

          #cuda
          autoAddDriverRunpath
          cudaPackages.cuda_nvcc
          (lib.getDev cudaPackages.cuda_cudart)
        ];

        buildInputs = with pkgs; [
          avahi
          libevdev
          libpulseaudio
          xorg.libX11
          xorg.libxcb
          xorg.libXfixes
          xorg.libXrandr
          xorg.libXtst
          xorg.libXi
          openssl
          libopus
          boost
          libdrm
          wayland
          libffi
          libevdev
          libcap
          libdrm
          curl
          pcre
          pcre2
          libuuid
          libselinux
          libsepol
          libthai
          libdatrie
          xorg.libXdmcp
          libxkbcommon
          libepoxy
          libva
          libvdpau
          numactl
          libgbm
          amf-headers
          svt-av1
          libappindicator
          libnotify
          miniupnpc
          nlohmann_json
          cudaPackages.cudatoolkit
          cudaPackages.cuda_cudart
          intel-media-sdk
        ];

        runtimeDependencies = with pkgs; [
          avahi
          libgbm
          xorg.libXrandr
          xorg.libxcb
          libglvnd
        ];
        stdenv' = pkgs.cudaPackages.backendStdenv;

      in {
        packages.default = stdenv'.mkDerivation rec {
          inherit buildInputs nativeBuildInputs runtimeDependencies;

          name = "sunshine";
          version = "2025.508.45332";

          src = ./.;
          ui = pkgs.buildNpmPackage {
            inherit src version;
            pname = "sunshine-ui";
            npmDepsHash = "sha256-1xfGxyn7Ut8MHsIY3dpaKvlRyEul3IYNjISQ8maYn8U=";

            postPatch = ''
              cp ${./package-lock.json} ./package-lock.json
            '';

            installPhase = ''
              mkdir -p $out
              cp -r * $out/
            '';
          };
          cmakeFlags = [
            "-Wno-dev"
            (pkgs.lib.cmakeBool "UDEV_FOUND" true)
            (pkgs.lib.cmakeBool "SYSTEMD_FOUND" true)
            (pkgs.lib.cmakeFeature "UDEV_RULES_INSTALL_DIR" "lib/udev/rules.d")
            (pkgs.lib.cmakeFeature "SYSTEMD_USER_UNIT_INSTALL_DIR"
              "lib/systemd/user")
            (pkgs.lib.cmakeBool "BOOST_USE_STATIC" false)
            (pkgs.lib.cmakeBool "BUILD_DOCS" false)
            (pkgs.lib.cmakeFeature "SUNSHINE_PUBLISHER_NAME" "nixpkgs")
            (pkgs.lib.cmakeFeature "SUNSHINE_PUBLISHER_WEBSITE"
              "https://nixos.org")
            (pkgs.lib.cmakeFeature "SUNSHINE_PUBLISHER_ISSUE_URL"
              "https://github.com/NixOS/nixpkgs/issues")
          ];

          env = {
            BUILD_VERSION = "${version}";
            BRANCH = "master";
            COMMIT = "";
          };

          postPatch = ''
            substituteInPlace cmake/packaging/linux.cmake \
              --replace-fail 'find_package(Systemd)' "" \
              --replace-fail 'find_package(Udev)' ""

            substituteInPlace cmake/targets/common.cmake \
              --replace-fail 'find_program(NPM npm REQUIRED)' ""

            substituteInPlace packaging/linux/sunshine.desktop \
              --subst-var-by PROJECT_NAME 'Sunshine' \
              --subst-var-by PROJECT_DESCRIPTION 'Self-hosted game stream host for Moonlight' \
              --subst-var-by SUNSHINE_DESKTOP_ICON 'sunshine' \
              --subst-var-by CMAKE_INSTALL_FULL_DATAROOTDIR "$out/share" \
              --replace-fail '/usr/bin/env systemctl start --u sunshine' 'sunshine'

            substituteInPlace packaging/linux/sunshine.service.in \
              --subst-var-by PROJECT_DESCRIPTION 'Self-hosted game stream host for Moonlight' \
              --subst-var-by SUNSHINE_EXECUTABLE_PATH $out/bin/sunshine \
              --replace-fail '/bin/sleep' '${pkgs.coreutils}/bin/sleep'
          '';

          preBuild = ''
            cp -r ${ui}/build ../
          '';

          buildFlags = [ "sunshine" ];

          postFixup = ''
            wrapProgram $out/bin/sunshine \
              --set LD_LIBRARY_PATH ${
                pkgs.lib.makeLibraryPath [ pkgs.vulkan-loader ]
              }
          '';

          installPhase = ''
            runHook preInstall
            cmake --install .
            runHook postInstall
          '';

          postInstall = ''
            install -Dm644 ../packaging/linux/${name}.desktop $out/share/applications/${name}.desktop
          '';

          meta = with pkgs.lib; {
            description = "Sunshine is a Game stream host for Moonlight";
            homepage = "https://github.com/LizardByte/Sunshine";
            license = licenses.gpl3Only;
            mainProgram = "sunshine";
            maintainers = with pkgs.maintainers; [ devusb ];
            platforms = platforms.linux;
          };
        };

        devShell = pkgs.mkShell {
          name = "sunshine-shell";
          inherit nativeBuildInputs;

          buildInputs = [ buildInputs pkgs.git pkgs.cmake pkgs.nodejs ];

        };
      });
}
