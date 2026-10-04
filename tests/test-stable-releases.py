"""Guard the metadata decisions that feed unattended boot-generation updates."""

import importlib.util
import sys
import unittest

spec = importlib.util.spec_from_file_location("updater", sys.argv.pop(1))
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class StableReleaseTests(unittest.TestCase):
    def test_compiler_tracks_exact_stable_driver_bundle(self):
        release = {'tag_name': 'v1.38.0', 'draft': False, 'prerelease': False,
                   'assets': [{'name': 'linux-npu-driver-v1.38.0.build-ubuntu2404.tar.gz',
                               'digest': 'sha256:' + 'a' * 64, 'browser_download_url': 'https://example.invalid/bundle'}]}
        self.assertEqual(updater.npu_compiler_pin(release)['version'], '1.38.0')
        for change in ({'prerelease': True}, {'assets': []}, {'tag_name': 'v1.39.0'}):
            with self.assertRaises(ValueError):
                updater.npu_compiler_pin(dict(release, **change))

    def test_openvino_requires_stable_matching_non_yanked_wheel(self):
        wheel = {'filename': 'openvino-2026.4.1-build-cp313-cp313-manylinux_2_28_x86_64.whl',
                 'digests': {'sha256': 'a' * 64}, 'url': 'https://example.invalid/wheel'}
        metadata = {'info': {'version': '2026.4.1'}, 'urls': [wheel]}
        self.assertEqual(updater.openvino_wheel_pin(metadata, '2026.4.1')['hash'], 'sha256:' + 'a' * 64)
        for version in ('2026.4.0', '2026.4.1rc1'):
            with self.assertRaises(ValueError):
                updater.openvino_wheel_pin(metadata, version)
        for changes in ({'yanked': True}, {'digests': {'sha256': 'bad'}}, {'filename': 'wrong-platform.whl'}):
            with self.assertRaises(ValueError):
                updater.openvino_wheel_pin(dict(metadata, urls=[dict(wheel, **changes)]), '2026.4.1')

    def test_nvidia_requires_recommended_production_release(self):
        info = {"IsBeta": "0", "IsFeaturePreview": "0", "IsRecommended": "1", "DisplayVersion": "595.104.02"}

        def response(data):
            return {"Success": "1", "IDS": [{"downloadInfo": data}]}

        self.assertEqual(updater.production_driver(response(info)), "595.104.02")
        for field, value in [("IsBeta", "1"), ("IsFeaturePreview", "1"), ("IsRecommended", "0")]:
            with self.assertRaises(ValueError):
                updater.production_driver(response(dict(info, **{field: value})))

    def test_numeric_version_is_not_proof_of_current_stable(self):
        channels = {"editor": {"version": "2.1.0", "source": "https://example.invalid/stable"}}
        updater.compare_channels({"editor": "2.1.0"}, channels)
        for actual in ({"editor": "2.0.0"}, {"editor": "2.2.0"}, {}, {"editor": "2.1.0-rc1"}):
            with self.assertRaises(ValueError):
                updater.compare_channels(actual, channels)

    def test_github_rejects_prereleases_and_missing_digests(self):
        release = {
            "tag_name": "v1.2.3", "draft": False, "prerelease": False,
            "assets": [{"name": "binary", "digest": "sha256:" + "a" * 64}],
        }
        self.assertEqual(updater.github_pin(release, "binary")["version"], "1.2.3")
        for field in ("draft", "prerelease"):
            with self.assertRaises(ValueError):
                updater.github_pin(dict(release, **{field: True}), "binary")
        for tag in ("v2.0.0-rc1", "nightly", "v2.0.0beta1"):
            with self.assertRaises(ValueError):
                updater.github_pin(dict(release, tag_name=tag), "binary")
        for digest in (None, "", "sha256:abc", "md5:" + "a" * 32):
            with self.assertRaises(ValueError):
                updater.github_pin(dict(release, assets=[{"name": "binary", "digest": digest}]), "binary")

    def test_python_uses_highest_stable_minor_not_latest_release_date(self):
        def release(name, prerelease=False, published=True):
            return {"name": name, "pre_release": prerelease, "is_published": published}
        versions = [
            release("Python 3.13.12"), release("Python 3.14.8"),
            release("Python 3.15.0rc3", True), release("Python 3.15.0", published=False),
            release("Python install manager 26.3"),
        ]
        self.assertEqual(updater.newest_python(versions), "3.14.8")
        versions.append(release("Python 3.15.0"))
        self.assertEqual(updater.newest_python(versions), "3.15.0")

    def test_nixos_requires_an_official_released_installer_link(self):
        page = """
        https://channels.nixos.org/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso
        https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso
        https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso
        https://github.com/nixos/nixpkgs/tree/nixos-26.11
        """
        self.assertEqual(updater.stable_series(page), "26.05")
        with self.assertRaises(ValueError):
            updater.stable_series("unexpected upstream page")

    def test_advances_both_branches_without_changing_state_version(self):
        flake = '''nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
        url = "github:nix-community/home-manager/release-26.05";
        system.stateVersion = "25.11";'''
        updated = updater.update_branches(flake, "26.11")
        self.assertIn("nixos-26.11", updated)
        self.assertIn("release-26.11", updated)
        self.assertIn('stateVersion = "25.11"', updated)
        with self.assertRaises(ValueError):
            updater.update_branches(flake, "25.11")
        with self.assertRaises(ValueError):
            updater.update_branches(flake + flake, "26.11")

    def test_version_order_does_not_downgrade_or_accept_prereleases(self):
        updater.no_downgrade("example", "1.9.9", "1.10.0")
        with self.assertRaises(ValueError):
            updater.no_downgrade("example", "1.10.0", "1.9.9")
        with self.assertRaises(ValueError):
            updater.no_downgrade("example", "1.10.0", "2.0.0-rc.1")


if __name__ == "__main__":
    unittest.main()
