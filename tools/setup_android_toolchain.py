"""Install the portable tools needed for Godot's prebuilt Android APK export.

Downloads official artifacts with their published checksums. No administrator
installation, system PATH changes, or deletion of existing SDKs is performed.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

CACHE = Path.home() / '.cache/donutsgame/android'
SDK = CACHE / 'sdk'
REPORT = Path(__file__).resolve().parents[1] / 'playtest-reports/android'
REPORT.mkdir(parents=True, exist_ok=True)
CACHE.mkdir(parents=True, exist_ok=True)

def read_url(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 GoldenHourBuild/1.0'}), timeout=90) as response:
        return response.read()

def download(url, path, expected, algorithm):
    actual = None
    if path.exists():
        with path.open('rb') as source:
            actual = hashlib.file_digest(source, algorithm).hexdigest()
    if actual != expected:
        partial = path.with_suffix(path.suffix + '.partial')
        request=urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 GoldenHourBuild/1.0'})
        with urllib.request.urlopen(request, timeout=120) as response, partial.open('wb') as target:
            shutil.copyfileobj(response, target, 1024 * 1024)
        with partial.open('rb') as source:
            actual = hashlib.file_digest(source, algorithm).hexdigest()
        if actual != expected:
            raise RuntimeError(f'Checksum mismatch for {path.name}')
        partial.replace(path)
    print(f'Verified {path.name}', flush=True)
    return path

def extract_safe(archive, destination):
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as source:
        for entry in source.infolist():
            target = (destination / entry.filename).resolve()
            if not target.is_relative_to(destination.resolve()):
                raise RuntimeError('Archive path escaped its installation folder')
        source.extractall(destination)

jdk_data = json.loads(read_url('https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse'))[0]
jdk_package = jdk_data['binary']['package']
repository = ET.fromstring(read_url('https://dl.google.com/android/repository/repository2-1.xml'))
remote = next(node for node in repository.iter() if node.tag.endswith('remotePackage') and node.get('path') == 'cmdline-tools;latest')
archive = next(node for node in remote.findall('./archives/archive') if node.findtext('host-os') == 'windows')
complete = archive.find('complete')
commandline_name = complete.findtext('url')
commandline_hash = complete.find('checksum').text
commandline_url = 'https://dl.google.com/android/repository/' + commandline_name
with ThreadPoolExecutor(max_workers=2) as pool:
    jdk_download = pool.submit(download, jdk_package['link'], CACHE / jdk_package['name'], jdk_package['checksum'], 'sha256')
    sdk_download = pool.submit(download, commandline_url, CACHE / commandline_name, commandline_hash, 'sha1')
    jdk_zip, sdk_zip = jdk_download.result(), sdk_download.result()

jdk_root = CACHE / 'java'
if not list(jdk_root.glob('*/bin/java.exe')):
    extract_safe(jdk_zip, jdk_root)
java_home = next(jdk_root.glob('*/bin/java.exe')).parents[1]
sdk_manager = SDK / 'cmdline-tools/latest/bin/sdkmanager.bat'
if not sdk_manager.exists():
    unpack = CACHE / ('commandline-' + commandline_hash[:12])
    extract_safe(sdk_zip, unpack)
    shutil.copytree(unpack / 'cmdline-tools', SDK / 'cmdline-tools/latest', dirs_exist_ok=True)

env = dict(os.environ, JAVA_HOME=str(java_home), ANDROID_HOME=str(SDK), ANDROID_SDK_ROOT=str(SDK))
env['PATH'] = str(java_home / 'bin') + os.pathsep + env.get('PATH', '')
android_cli = sdk_manager.with_name('android.exe')
commands = [[str(android_cli), '--no-metrics', '--sdk=' + str(SDK), 'sdk', 'install',
             'platform-tools', 'build-tools/35.0.1', 'platforms/android-35']] if android_cli.exists() else [
             [str(sdk_manager), '--sdk_root=' + str(SDK), '--licenses'],
             [str(sdk_manager), '--sdk_root=' + str(SDK), 'platform-tools', 'build-tools;35.0.1', 'platforms;android-35']]
with (REPORT / 'sdk-install.log').open('w', encoding='utf-8') as log:
    for args in commands:
        print('SDK setup: ' + ' '.join(args), flush=True)
        result = subprocess.run(args,
                                input='y\n' * 100, text=True, stdout=log, stderr=subprocess.STDOUT,
                                env=env, creationflags=subprocess.CREATE_NO_WINDOW)
        if result.returncode:
            raise RuntimeError('Android SDK setup failed; see sdk-install.log')
for required in ['platform-tools/adb.exe', 'build-tools/35.0.1/apksigner.bat', 'platforms/android-35/android.jar']:
    if not (SDK / required).is_file():
        raise RuntimeError('SDK package is missing despite successful command: ' + required)

templates = Path(os.environ['APPDATA']) / 'Godot/export_templates/4.7.2.stable'
templates.mkdir(parents=True, exist_ok=True)
template_archive = Path.home() / '.cache/donutsgame/godot/Godot_v4.7.2-stable_export_templates.tpz'
with zipfile.ZipFile(template_archive) as source:
    for name in ['android_debug.apk', 'android_release.apk', 'android_source.zip']:
        target = templates / name
        if not target.exists():
            with source.open('templates/' + name) as data, target.open('wb') as output:
                shutil.copyfileobj(data, output)
        print('Android export template ready: ' + name, flush=True)

result = {'java_home': str(java_home), 'android_sdk': str(SDK), 'godot_templates': str(templates),
          'jdk_version': jdk_data['version']['semver'], 'jdk_url': jdk_package['link'],
          'jdk_sha256': jdk_package['checksum'], 'commandline_url': commandline_url,
          'commandline_sha1': commandline_hash, 'packages': ['platform-tools', 'build-tools;35.0.1', 'platforms;android-35']}
(REPORT / 'toolchain.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, indent=2), flush=True)
