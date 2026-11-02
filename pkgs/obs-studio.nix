# Stable OBS 33 while Nixpkgs still packages the pre-33 module layout.
{ pkgs }:
let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).obs-studio;
  corePaths = pkgs.lib.replaceStrings [ "$out/lib/obs-plugins" ] [ "$out/lib/obs-modules/core" ];
  cef = pkgs.stdenv.mkDerivation {
    pname = "obs-cef-with-wrapper";
    inherit (pkgs.cef-binary) version;
    src = pkgs.cef-binary;
    nativeBuildInputs = [
      pkgs.cmake
      pkgs.ninja
    ];
    postPatch = ''
      cp ${pkgs.writeText "cef-wrapper-CMakeLists.txt" ''
        cmake_minimum_required(VERSION 3.21)
        project(cef-wrapper)
        set(CEF_ROOT "''${CMAKE_CURRENT_SOURCE_DIR}")
        list(APPEND CMAKE_MODULE_PATH "''${CEF_ROOT}/cmake")
        find_package(CEF REQUIRED)
        add_subdirectory(''${CEF_LIBCEF_DLL_WRAPPER_PATH} libcef_dll_wrapper)
      ''} CMakeLists.txt
    '';
    cmakeFlags = [ "-DUSE_SANDBOX=OFF" ];
    ninjaFlags = [ "libcef_dll_wrapper" ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/libcef_dll_wrapper"
      cp -a ${pkgs.cef-binary}/. "$out/"
      cp libcef_dll_wrapper/libcef_dll_wrapper.a "$out/libcef_dll_wrapper/"
      runHook postInstall
    '';
    # The binary package is already patched; retain its working shared libraries.
    dontFixup = true;
  };
in
pkgs.obs-studio.overrideAttrs (
  old:
  let
    oldCef = builtins.head (
      builtins.filter (package: (package.pname or "") == "cef-binary") old.buildInputs
    );
    # OBS 33's browser permission API needs a current CEF, not the older OBS 32
    # bundle selected inside Nixpkgs' recipe. Keep the cached stable CEF package.
    replaceCef = pkgs.lib.replaceStrings [ (toString oldCef) ] [ (toString cef) ];
  in
  {
    inherit (release) version;
    # The official source asset includes the required submodules.
    src = pkgs.fetchurl {
      url = "https://github.com/obsproject/obs-studio/releases/download/${release.version}/OBS-Studio-${release.version}-Sources.tar.gz";
      inherit (release) hash;
    };
    # OBS 33 resolves its core modules relative to the executable. Its former
    # obs-nix.c path table (and the patch for that table) no longer exists.
    patches = builtins.filter (
      patch: builtins.baseNameOf patch != "fix-nix-plugin-path.patch"
    ) old.patches;
    cmakeFlags = old.cmakeFlags ++ [
      "-DCMAKE_INSTALL_BINDIR=bin"
      "-DCMAKE_INSTALL_LIBDIR=lib"
      "-DCMAKE_INSTALL_DATAROOTDIR=share"
    ];
    buildInputs = map (package: if package == oldCef then cef else package) old.buildInputs;
    postUnpack = replaceCef old.postUnpack;
    preFixup = corePaths old.preFixup;
    postFixup = replaceCef (corePaths old.postFixup);
    # NixOS's existing wrapOBS removes this legacy data directory after merging
    # plugin outputs. Keep the empty directory for compatibility with that wrapper.
    postInstall = (old.postInstall or "") + ''
      mkdir -p "$out/share/obs/obs-plugins"
    '';
  }
)
