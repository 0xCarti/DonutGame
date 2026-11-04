"""Build and verify the signed offline Android APK without changing system PATH.

Run setup_android_toolchain.py once first. Signing credentials remain outside the
repository; keep them backed up to preserve the ability to update installations.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import secrets
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CACHE = Path.home() / '.cache/donutsgame/android'
REPORT = ROOT / 'playtest-reports/android'
GODOT = Path.home() / '.cache/donutsgame/godot/Godot_v4.7.2-stable_win64_console.exe'
PACKAGE = 'com.goldenhourgame.minidonuts'
FLAGS = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0


def run(args, log_name, env, timeout=900):
    log = REPORT / log_name
    with log.open('w', encoding='utf-8') as output:
        result = subprocess.run([str(arg) for arg in args], cwd=ROOT, env=env,
                                stdout=output, stderr=subprocess.STDOUT,
                                timeout=timeout, creationflags=FLAGS)
    text = log.read_text(encoding='utf-8', errors='replace')
    if result.returncode or re.search(r'(^|\n)(SCRIPT ERROR:|ERROR:|FAIL:)', text):
        raise RuntimeError(f'{log_name} failed (exit {result.returncode}); inspect {log}')
    print(f'Passed: {log_name}', flush=True)
    return text


def configure_editor(java_home, sdk):
    path = Path(os.environ['APPDATA']) / 'Godot/editor_settings-4.7.tres'
    original = path.read_text(encoding='utf-8')
    updated = original
    for name, value in [('java_sdk_path', java_home), ('android_sdk_path', sdk)]:
        line = f'export/android/{name} = "{value.as_posix()}"'
        pattern = rf'^export/android/{name} = .*?$'
        if re.search(pattern, updated, flags=re.M):
            updated = re.sub(pattern, lambda _: line, updated, flags=re.M)
        else:
            updated += '\n' + line + '\n'
    if updated != original:
        backup = CACHE / 'editor-settings-before-android.tres'
        if not backup.exists():
            shutil.copy2(path, backup)
        path.write_text(updated, encoding='utf-8')


def signing_env(java_home, env):
    signing = CACHE / 'signing'
    signing.mkdir(parents=True, exist_ok=True)
    keystore = signing / 'golden-hour-release.keystore'
    credentials_path = signing / 'credentials.json'
    if keystore.exists() and not credentials_path.exists():
        raise RuntimeError('Existing signing key has no credentials. Restore its credentials; do not replace it.')
    if not credentials_path.exists():
        credentials_path.write_text(json.dumps({'alias': 'golden-hour', 'password': secrets.token_urlsafe(36)}), encoding='utf-8')
    credentials = json.loads(credentials_path.read_text(encoding='utf-8'))
    env['GOLDEN_HOUR_SIGN_PASSWORD'] = credentials['password']
    if not keystore.exists():
        run([java_home / 'bin/keytool.exe', '-genkeypair', '-keystore', keystore,
             '-alias', credentials['alias'], '-keyalg', 'RSA', '-keysize', '3072',
             '-validity', '10000', '-dname', 'CN=Golden Hour, OU=Game Development',
             '-storepass:env', 'GOLDEN_HOUR_SIGN_PASSWORD',
             '-keypass:env', 'GOLDEN_HOUR_SIGN_PASSWORD'], 'signing-key-creation.log', env)
    # Godot reads these directly; never place passwords in a preset or command.
    env['GODOT_ANDROID_KEYSTORE_RELEASE_PATH'] = str(keystore)
    env['GODOT_ANDROID_KEYSTORE_RELEASE_USER'] = credentials['alias']
    env['GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD'] = credentials['password']
    return env


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--skip-tests', action='store_true', help='Re-export after the unchanged source already passed checks.')
    args = parser.parse_args()
    REPORT.mkdir(parents=True, exist_ok=True)
    setup = json.loads((REPORT / 'toolchain.json').read_text(encoding='utf-8'))
    java_home = Path(setup['java_home'])
    sdk = Path(setup['android_sdk'])
    version = re.search(r'config/version="([^"]+)"', (ROOT / 'project.godot').read_text(encoding='utf-8')).group(1)
    output = ROOT / 'builds/android' / version
    output.mkdir(parents=True, exist_ok=True)
    apk = output / f'GoldenHour-{version}-Android.apk'
    env = dict(os.environ, JAVA_HOME=str(java_home), ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk))
    env['PATH'] = str(java_home / 'bin') + os.pathsep + env.get('PATH', '')
    configure_editor(java_home, sdk)
    signing_env(java_home, env)
    run([GODOT, '--headless', '--path', ROOT, '--editor', '--import'], 'import.log', env)
    if not args.skip_tests:
        for name in ['mobile_input', 'mobile_controller', 'mobile_ui', 'mobile_quality', 'stand_controller']:
            run([GODOT, '--headless', '--path', ROOT, '--script', f'res://tests/test_{name}.gd'], f'{name}.log', env)
    run([GODOT, '--headless', '--path', ROOT, '--export-release', 'Android', apk], 'export.log', env)
    if not apk.is_file():
        raise RuntimeError('Godot did not create the expected APK')
    build_tools = sdk / 'build-tools/35.0.1'
    # Invoke the signer JAR directly to avoid batch-file quoting and password leaks.
    signature = run([java_home / 'bin/java.exe', '-jar', build_tools / 'lib/apksigner.jar',
                     'verify', '--verbose', '--print-certs', apk], 'signature.log', env)
    if 'Verified using v2 scheme (APK Signature Scheme v2): true' not in signature:
        raise RuntimeError('APK v2 signature was not verified')
    badging = run([build_tools / 'aapt.exe', 'dump', 'badging', apk], 'package.log', env)
    if f"package: name='{PACKAGE}'" not in badging or f"versionName='{version}'" not in badging:
        raise RuntimeError('APK identity/version did not match the project')
    if "sdkVersion:'24'" not in badging or "targetSdkVersion:'36'" not in badging:
        raise RuntimeError('APK Android API requirements changed; review the template and release notes')
    if "uses-permission:" in badging:
        raise RuntimeError('Offline APK unexpectedly requests Android permissions')
    for abi in ['armeabi-v7a', 'arm64-v8a', 'x86_64']:
        if abi not in badging:
            raise RuntimeError('APK missing expected architecture: ' + abi)
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        for notice in ['docs/licenses/Godot-LICENSE.txt', 'docs/licenses/Godot-COPYRIGHT.txt', 'assets/fonts/OFL.txt']:
            if not any(name.endswith(notice) for name in names):
                raise RuntimeError('APK missing license notice: ' + notice)
        if any('/unity/' in name or '/tests/' in name for name in names):
            raise RuntimeError('APK contains unrelated development files')
    with apk.open('rb') as source:
        digest = hashlib.file_digest(source, 'sha256').hexdigest()
    manifest = {'game': 'Golden Hour', 'version': version, 'package': PACKAGE,
                'file': apk.name, 'bytes': apk.stat().st_size, 'sha256': digest,
                'architectures': ['armeabi-v7a', 'arm64-v8a', 'x86_64'], 'minimum_android_api': 24,
                'target_android_api': 36, 'signature_verified': True,
                'physical_device_validation': 'pending'}
    (output / 'build-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    (output / (apk.name + '.sha256')).write_text(digest + '  ' + apk.name + '\n', encoding='utf-8')
    for doc in ['README.md', 'docs/ANDROID.md']:
        if (ROOT / doc).exists():
            shutil.copy2(ROOT / doc, output / ('INSTALL-ANDROID.md' if 'ANDROID' in doc else 'README.md'))
    shutil.copy2(ROOT / 'docs/ANDROID_QUICKSTART.txt', output / 'Read Me - Android.txt')
    print(json.dumps(manifest, indent=2), flush=True)


if __name__ == '__main__':
    main()
