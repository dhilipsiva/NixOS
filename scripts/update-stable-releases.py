#!/usr/bin/env python3
"""Refresh stable release pins in a writable flake; never build or activate it."""

import argparse
import base64
import hashlib
import gzip
import json
from pathlib import Path
import re
import shutil
import subprocess
import tomllib
import urllib.request
import urllib.error


GITHUB_ASSETS = {
    "atuin": ("atuinsh/atuin", "atuin-x86_64-unknown-linux-musl.tar.gz"),
    "herdr": ("herdrdev/herdr", "herdr-linux-x86_64"),
    "ollama": ("ollama/ollama", "ollama-linux-amd64.tar.zst"),
    "uv": ("astral-sh/uv", "uv-x86_64-unknown-linux-musl.tar.gz"),
    "obs-studio": ("obsproject/obs-studio", "OBS-Studio-{version}-Sources.tar.gz"),
}
CLAUDE_URL = "https://downloads.claude.ai/claude-code-releases"
ANTIGRAVITY_URL = ("https://antigravity-cli-auto-updater-974169037036.us-central1.run.app"
                   "/manifests/linux_amd64.json")
ZCODE_DOWNLOADS_URL = "https://zcode.z.ai/en/docs/install"
ZCODE_RELEASES_URL = "https://cdn-zcode.z.ai/zcode/electron/releases"
# The same non-beta production-branch query used by NVIDIA's Unix Drivers page.
NVIDIA_URL = ("https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php"
              "?func=DriverManualLookup&psid=133&pfid=1075&osID=12&languageCode=1033"
              "&beta=0&isWHQL=0&dltype=-1&dch=0&upCRD=null&qnf=0&ctk=null&sort1=&numberOfResults=1")
GITHUB_CHANNELS = {
    "intel-npu-driver": ("intel/linux-npu-driver", "v"),
    "openvino-npu": ("openvinotoolkit/openvino", ""),
    "codex": ("openai/codex", "rust-v"),
    "zed-editor": ("zed-industries/zed", "v"),
    "helix": ("helix-editor/helix", "v"),
    "alacritty": ("alacritty/alacritty", "v"),
    "fish": ("fish-shell/fish-shell", "v"),
    "tuigreet": ("apognu/tuigreet", "v"),
    "hyprland": ("hyprwm/Hyprland", "v"),
    "hypridle": ("hyprwm/hypridle", "v"),
    "hyprlock": ("hyprwm/hyprlock", "v"),
    "zoxide": ("ajeetdsouza/zoxide", "v"),
    "ripgrep": ("BurntSushi/ripgrep", "v"),
}


def release_version(release, prefix="v"):
    if release["prerelease"] or release["draft"]:
        raise ValueError("Upstream returned a draft or prerelease")
    version = release["tag_name"].removeprefix(prefix)
    version_tuple(version)
    return version


def antigravity_pin(manifest):
    version = manifest["version"]
    version_tuple(version)
    url = manifest["url"]
    expected = (r"https://storage\.googleapis\.com/antigravity-public/antigravity-cli/"
                + re.escape(version) + r"-[0-9]+/linux-x64/cli_linux_x64\.tar\.gz")
    if not re.fullmatch(expected, url):
        raise ValueError("Antigravity manifest has a mismatched Linux release URL")
    if not re.fullmatch(r"[0-9a-f]{128}", manifest["sha512"]):
        raise ValueError("Antigravity manifest is missing its Linux SHA-512")
    return {"version": version, "url": url, "hash": "sha512:" + manifest["sha512"]}


def zcode_version(page):
    versions = re.findall(re.escape(ZCODE_RELEASES_URL)
                          + r"/([0-9.]+)/linux-x64/ZCode-\1-linux-x64\.AppImage", page)
    if not versions:
        raise ValueError("ZCode download page has no stable Linux release")
    return max(versions, key=version_tuple)


def zcode_pin(manifest, version):
    version_tuple(version)
    if manifest["schemaVersion"] != 1 or manifest["version"] != version:
        raise ValueError("ZCode runtime manifest does not match the stable release")
    archives = [a for a in manifest["archives"] if a["target"] == "linux-x64"]
    if len(archives) != 1:
        raise ValueError("ZCode runtime manifest needs exactly one Linux x64 archive")
    archive = archives[0]
    filename = "zcode-server-linux-x64.tar.gz"
    url = f"{ZCODE_RELEASES_URL}/{version}/{filename}"
    if (archive["version"] != version or archive["fileName"] != filename
            or not any(u in (filename, url) for u in archive["urls"])):
        raise ValueError("ZCode runtime manifest has a mismatched Linux archive")
    if not re.fullmatch(r"[0-9a-f]{64}", archive["sha256"]):
        raise ValueError("ZCode runtime manifest is missing its Linux SHA-256")
    return {"version": version, "url": url, "hash": "sha256:" + archive["sha256"]}


def compare_channels(actual, channels):
    if set(actual) != set(channels):
        raise ValueError("The evaluated package list and tracked stable channels differ")
    for name, version in actual.items():
        expected = channels[name]["version"]
        if version_tuple(version) != version_tuple(expected):
            raise ValueError(f"{name}: packaged {version}, official stable {expected}; packaging needs updating")


def production_driver(response):
    if response["Success"] != "1" or len(response["IDS"]) != 1:
        raise ValueError("NVIDIA returned an ambiguous production channel")
    info = response["IDS"][0]["downloadInfo"]
    if info["IsBeta"] != "0" or info["IsFeaturePreview"] != "0" or info["IsRecommended"] != "1":
        raise ValueError("NVIDIA returned a beta, feature preview or non-recommended driver")
    version = info["DisplayVersion"]
    version_tuple(version)
    return version


def verify(repo):
    channels = json.loads((repo / "pkgs/stable-channels.json").read_text())
    actual = json.loads(subprocess.check_output(
        ["nix", "eval", "--json", f"path:{repo}#lib.stableVersions"], text=True))
    compare_channels(actual, channels)
    print(f"All {len(channels)} selected tools match their pinned official stable channels.")


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "nixos-stable-updater"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        # Public metadata can exhaust GitHub's shared anonymous quota. Let gh
        # use the checkout owner's existing authentication, without exposing a
        # token in command arguments, logs, or the Nix source tree.
        if (url.startswith('https://api.github.com/') and exc.code in (403, 429)
                and shutil.which('gh')):
            result = subprocess.run(['gh', 'api', '--hostname', 'github.com', url],
                                    capture_output=True, timeout=60)
            if result.returncode == 0:
                return result.stdout
            raise ValueError(f'Authenticated GitHub metadata unavailable: {url}') from exc
        raise ValueError(f'Stable metadata unavailable: {url}: {exc.reason}') from exc
    except urllib.error.URLError as exc:
        raise ValueError(f"Stable metadata unavailable: {url}: {exc.reason}") from exc


def version_tuple(version):
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,3}", version):
        raise ValueError(f"Not a stable numeric release: {version!r}")
    return tuple(map(int, version.split(".")))


def no_downgrade(name, old, new):
    if version_tuple(new) < version_tuple(old):
        raise ValueError(f"Refusing to downgrade {name}: {old} -> {new}")


def github_pin(release, asset_name):
    if release["prerelease"] or release["draft"]:
        raise ValueError("Upstream returned a draft or prerelease")
    version = release["tag_name"].removeprefix("v")
    version_tuple(version)
    asset = next(a for a in release["assets"] if a["name"] == asset_name)
    digest = asset.get("digest", "")
    if not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise ValueError(f"Missing upstream SHA-256 for {asset_name}")
    return {"version": version, "hash": digest}


def newest_python(releases):
    versions = [
        release["name"].removeprefix("Python ")
        for release in releases
        if release["is_published"] and not release["pre_release"]
        and re.fullmatch(r"Python 3\.[0-9]+\.[0-9]+", release["name"])
    ]
    return max(versions, key=version_tuple)


def npu_compiler_pin(release):
    """Use the compiler bundle from the exact driver release, never an RC URL."""
    version = release_version(release)
    assets = [a for a in release['assets']
              if a['name'].startswith(f'linux-npu-driver-v{version}.')
              and a['name'].endswith('-ubuntu2404.tar.gz')]
    if len(assets) != 1:
        raise ValueError('Expected one Ubuntu 24.04 NPU compiler bundle')
    asset = assets[0]
    return dict(github_pin(release, asset['name']), url=asset['browser_download_url'])


def openvino_wheel_pin(metadata, version):
    version_tuple(version)
    if metadata['info']['version'] != version:
        raise ValueError('OpenVINO wheel metadata differs from its stable release')
    wheels = [a for a in metadata['urls'] if not a.get('yanked', False)
              and a['filename'].endswith('-cp313-cp313-manylinux_2_28_x86_64.whl')]
    if len(wheels) != 1:
        raise ValueError('Expected one OpenVINO CPython 3.13 Linux wheel')
    wheel = wheels[0]
    digest = wheel['digests']['sha256']
    if not re.fullmatch(r'[0-9a-f]{64}', digest):
        raise ValueError('Missing OpenVINO wheel SHA-256')
    return {'version': version, 'url': wheel['url'], 'hash': 'sha256:' + digest}


def stable_series(download_page):
    # The official installer links advertise released channels, unlike branch
    # names, which exist before release. Fail if the page format changes.
    versions = re.findall(
        r"https://channels\.nixos\.org/nixos-([0-9]{2}\.(?:05|11))/latest-nixos-",
        download_page,
    )
    return max(versions, key=version_tuple)


def update_branches(flake, series):
    for prefix in ("github:nixos/nixpkgs/nixos-", "github:nix-community/home-manager/release-"):
        pattern = re.escape(prefix) + r"([0-9]{2}\.(?:05|11))"
        matches = re.findall(pattern, flake)
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one {prefix} input")
        no_downgrade(prefix, matches[0], series)
        flake = re.sub(pattern, prefix + series, flake)
    return flake


def atomic_write(path, contents):
    temporary = path.with_name(path.name + ".new")
    temporary.write_text(contents)
    temporary.replace(path)


def update(repo, check_only=False):
    pins_path = repo / "pkgs/releases.json"
    old_pins = json.loads(pins_path.read_text())
    pins = dict(old_pins)
    channels = {}
    pins["antigravity-cli"] = antigravity_pin(json.loads(fetch(ANTIGRAVITY_URL)))
    if "antigravity-cli" in old_pins:
        no_downgrade("antigravity-cli", old_pins["antigravity-cli"]["version"],
                     pins["antigravity-cli"]["version"])
    channels["antigravity-cli"] = {"version": pins["antigravity-cli"]["version"],
                                  "source": ANTIGRAVITY_URL}
    zcode = zcode_version(fetch(ZCODE_DOWNLOADS_URL).decode())
    manifest_url = f"{ZCODE_RELEASES_URL}/{zcode}/source-server-release.json"
    pins["zcode-cli"] = zcode_pin(json.loads(fetch(manifest_url)), zcode)
    if "zcode-cli" in old_pins:
        no_downgrade("zcode-cli", old_pins["zcode-cli"]["version"], zcode)
    resources_url = f"{ZCODE_RELEASES_URL}/{zcode}/linux-x64/ZCode-{zcode}-linux-x64.AppImage"
    previous_zcode = old_pins.get("zcode-cli", {})
    if previous_zcode.get("resourcesUrl") == resources_url and previous_zcode.get("resourcesHash"):
        resources_hash = previous_zcode["resourcesHash"]
    else:
        # The runtime omits its public provider catalogue; take it from the
        # matching official desktop release, hashing only when the URL changes.
        digest = base64.b64encode(hashlib.sha256(fetch(resources_url)).digest()).decode()
        resources_hash = "sha256-" + digest
    pins["zcode-cli"].update(resourcesUrl=resources_url, resourcesHash=resources_hash)
    channels["zcode-cli"] = {"version": zcode, "source": ZCODE_DOWNLOADS_URL}
    kernel_url = "https://www.kernel.org/releases.json"
    kernel = max((r for r in json.loads(fetch(kernel_url))["releases"] if r["moniker"] == "stable"),
                 key=lambda r: version_tuple(r["version"]))
    kernel_version = kernel["version"]
    if "linux" in old_pins:
        no_downgrade("linux", old_pins["linux"]["version"], kernel_version)
    sums = fetch(f"https://cdn.kernel.org/pub/linux/kernel/v{kernel_version.split('.')[0]}.x/sha256sums.asc").decode()
    digest, = re.findall(r"^([0-9a-f]{64})  linux-" + re.escape(kernel_version) + r"\.tar\.xz$", sums, re.M)
    pins["linux"] = {"version": kernel_version, "hash": "sha256:" + digest}
    channels["linux"] = {"version": kernel_version, "source": kernel_url}
    channels["nvidia"] = {"version": production_driver(json.loads(fetch(NVIDIA_URL))), "source": NVIDIA_URL}
    for name, (project, asset) in GITHUB_ASSETS.items():
        release = json.loads(fetch(f"https://api.github.com/repos/{project}/releases/latest"))
        asset = asset.format(version=release_version(release))
        pins[name] = github_pin(release, asset)
        if name in old_pins:
            no_downgrade(name, old_pins[name]["version"], pins[name]["version"])
        channels[name] = {"version": pins[name]["version"], "source": f"https://api.github.com/repos/{project}/releases/latest"}

    for name, (project, prefix) in GITHUB_CHANNELS.items():
        url = f"https://api.github.com/repos/{project}/releases/latest"
        channels[name] = {"version": release_version(json.loads(fetch(url)), prefix), "source": url}
    hyprlock_version = channels['hyprlock']['version']
    if old_pins.get('hyprlock', {}).get('version') != hyprlock_version:
        # Hyprlock has no source release asset with a published digest. Pin the
        # exact stable tag archive, retaining its digest on subsequent refreshes.
        archive = fetch(f'https://github.com/hyprwm/hyprlock/archive/refs/tags/v{hyprlock_version}.tar.gz')
        digest = base64.b64encode(hashlib.sha256(archive).digest()).decode()
        pins['hyprlock'] = {'version': hyprlock_version, 'hash': 'sha256-' + digest}
    pins['intel-npu-compiler'] = npu_compiler_pin(json.loads(fetch(channels['intel-npu-driver']['source'])))
    if pins['intel-npu-compiler']['version'] != channels['intel-npu-driver']['version']:
        raise ValueError('NPU release changed during metadata refresh; retry')
    channels['intel-npu-compiler'] = dict(channels['intel-npu-driver'])
    ov_version = channels['openvino-npu']['version']
    pins['openvino-npu'] = openvino_wheel_pin(
        json.loads(fetch(f'https://pypi.org/pypi/openvino/{ov_version}/json')), ov_version)
    channels['ollama-vulkan'] = dict(channels['ollama'])
    for name in ('intel-npu-compiler', 'openvino-npu'):
        if name in old_pins:
            no_downgrade(name, old_pins[name]['version'], pins[name]['version'])
    fuzzel_url = "https://codeberg.org/api/v1/repos/dnkl/fuzzel/releases/latest"
    channels["fuzzel"] = {"version": release_version(json.loads(fetch(fuzzel_url))), "source": fuzzel_url}
    # UWSM publishes stable version tags without GitHub Release objects.
    uwsm_url = "https://api.github.com/repos/Vladimir-csp/uwsm/tags?per_page=100"
    uwsm_tags = [tag["name"].removeprefix("v") for tag in json.loads(fetch(uwsm_url))
                 if re.fullmatch(r"v?[0-9]+\.[0-9]+\.[0-9]+", tag["name"])]
    channels["uwsm"] = {"version": max(uwsm_tags, key=version_tuple), "source": uwsm_url}
    rust_url = "https://static.rust-lang.org/dist/channel-rust-stable.toml"
    rust_version = tomllib.loads(fetch(rust_url).decode())["pkg"]["rust"]["version"].split()[0]
    version_tuple(rust_version)
    channels["rust-toolchain"] = {"version": rust_version, "source": rust_url}

    chrome_url = "https://dl.google.com/linux/chrome/deb/dists/stable/main/binary-amd64/Packages.gz"
    chrome_packages = gzip.decompress(fetch(chrome_url)).decode().split("\n\n")
    stable_package = next(p for p in chrome_packages if p.startswith("Package: google-chrome-stable\n"))
    chrome_version = re.search(r"^Version: ([0-9.]+)-[0-9]+$", stable_package, re.M).group(1)
    channels["google-chrome"] = {"version": chrome_version, "source": chrome_url}

    slack_url = "https://slack.com/downloads/instructions/linux"
    slack_versions = re.findall(r"desktop-releases/linux/x64/([0-9.]+)/slack-", fetch(slack_url).decode())
    slack_version = max(slack_versions, key=version_tuple)
    channels["slack"] = {"version": slack_version, "source": slack_url}
    if pins.get("slack", {}).get("version") != slack_version:
        deb_url = f"https://downloads.slack-edge.com/desktop-releases/linux/x64/{slack_version}/slack-desktop-{slack_version}-amd64.deb"
        digest = base64.b64encode(hashlib.sha256(fetch(deb_url)).digest()).decode()
        pins["slack"] = {"version": slack_version, "hash": "sha256-" + digest}

    python_releases = json.loads(fetch("https://www.python.org/api/v2/downloads/release/?is_published=true"))
    python_version = newest_python(python_releases)
    no_downgrade("python", old_pins["python"]["version"], python_version)
    if python_version != old_pins["python"]["version"]:
        source = fetch(f"https://www.python.org/ftp/python/{python_version}/Python-{python_version}.tar.xz")
        digest = base64.b64encode(hashlib.sha256(source).digest()).decode()
        pins["python"] = {"version": python_version, "hash": "sha256-" + digest}
    channels["python-latest"] = {"version": python_version, "source": "https://www.python.org/api/v2/downloads/release/?is_published=true"}

    claude_version = fetch(f"{CLAUDE_URL}/stable").decode().strip()
    version_tuple(claude_version)
    manifest_path = repo / "pkgs/claude-code-manifest.json"
    no_downgrade("claude", json.loads(manifest_path.read_text())["version"], claude_version)
    manifest = json.loads(fetch(f"{CLAUDE_URL}/{claude_version}/manifest.zst.json"))
    if manifest["version"] != claude_version:
        raise ValueError("Claude manifest does not match the stable channel")
    if not re.fullmatch(r"[0-9a-f]{64}", manifest["platforms"]["linux-x64"]["checksum"]):
        raise ValueError("Claude manifest is missing its Linux SHA-256")
    channels["claude-code"] = {"version": claude_version, "source": f"{CLAUDE_URL}/stable"}

    series = stable_series(fetch("https://nixos.org/download/").decode())
    # Home Manager must have its matching release available before advancing.
    fetch(f"https://raw.githubusercontent.com/nix-community/home-manager/release-{series}/flake.nix")
    flake_path = repo / "flake.nix"
    flake = update_branches(flake_path.read_text(), series)

    lanzaboote = release_version(json.loads(fetch("https://api.github.com/repos/nix-community/lanzaboote/releases/latest")))
    pattern = r"github:nix-community/lanzaboote/v([0-9.]+)"
    old_lanzaboote, = re.findall(pattern, flake)
    no_downgrade("lanzaboote", old_lanzaboote, lanzaboote)
    flake = re.sub(pattern, "github:nix-community/lanzaboote/v" + lanzaboote, flake)
    channels_path = repo / "pkgs/stable-channels.json"
    if channels_path.exists():
        for name, old in json.loads(channels_path.read_text()).items():
            no_downgrade(name, old["version"], channels[name]["version"])

    print(f"NixOS and Home Manager: {series}")
    for name, pin in pins.items():
        print(f"{name}: {old_pins.get(name, {}).get('version', 'new')} -> {pin['version']}")
    print(f"Claude stable: {claude_version}")
    if not check_only:
        # Resolve and validate all remote metadata before touching any file.
        atomic_write(pins_path, json.dumps(pins, indent=2) + "\n")
        atomic_write(manifest_path, json.dumps(manifest, indent=2) + "\n")
        atomic_write(flake_path, flake)
        atomic_write(channels_path, json.dumps(channels, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo", type=Path, help="writable flake directory")
    parser.add_argument("--check-only", action="store_true", help="report without changing files")
    parser.add_argument("--verify", action="store_true", help="compare evaluated packages with pinned official channel metadata")
    args = parser.parse_args()
    if args.verify:
        verify(args.repo.resolve())
    else:
        update(args.repo.resolve(), args.check_only)
