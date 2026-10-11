# Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
"""Archive genuine native dynamic frameworks. Keep all output outside the checkout."""
import argparse
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import time
from artifact_inventory import framework_inventory


def capture(command, cwd=None):
    return subprocess.check_output(command, cwd=cwd, text=True, stderr=subprocess.STDOUT).strip()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relativize_abi_source_paths(framework, source):
    """Keep compiler ABI data intact while removing local ConstValues locations."""
    receipts = []
    for path in sorted(framework.rglob('*.abi.json')):
        original = path.read_bytes()
        data = json.loads(original)
        abi_before = json.dumps(data.get('ABIRoot'), sort_keys=True, separators=(',', ':'))
        locations = []
        for value in data.get('ConstValues', []):
            location = value.get('filePath')
            if not isinstance(location, str):
                raise SystemExit('Missing compiler constant source location')
            absolute = pathlib.Path(location)
            if not absolute.is_absolute() or source not in absolute.parents or not absolute.is_file():
                raise SystemExit('Unexpected compiler constant source location')
            relative = absolute.relative_to(source).as_posix()
            if not relative.startswith('Sources/') or not relative.endswith('.swift'):
                raise SystemExit('Compiler ABI location is outside native source membership')
            value['filePath'] = relative
            locations.append(relative)
        if json.dumps(data.get('ABIRoot'), sort_keys=True, separators=(',', ':')) != abi_before:
            raise SystemExit('ABI declarations changed during source-location normalization')
        normalized = (json.dumps(data, indent=2, ensure_ascii=False) + '\n').encode('utf-8')
        if b'/Users/' in normalized or b'\\/Users\\/' in normalized:
            raise SystemExit('Machine-private path remains in compiler ABI metadata')
        path.write_bytes(normalized)
        receipts.append({'path': path.relative_to(framework).as_posix(), 'remapped_location_count': len(locations),
                         'source_files': sorted(set(locations)), 'compiler_sha256': hashlib.sha256(original).hexdigest(),
                         'normalized_sha256': hashlib.sha256(normalized).hexdigest(), 'abi_declarations_unchanged': True})
    return receipts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-commit', required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--output', required=True, type=pathlib.Path)
    parser.add_argument('--investigation', action='store_true', help='Permit dirty source; output is never a final release candidate')
    args = parser.parse_args()
    source = pathlib.Path(__file__).resolve().parents[2]
    config = json.loads((source / 'SDK/ReleaseConfiguration.json').read_text())
    head = capture(['git', 'rev-parse', 'HEAD'], source)
    dirty = capture(['git', 'status', '--porcelain=v1', '--untracked-files=all'], source)
    if args.source_commit != head or not re.fullmatch('[0-9a-f]{40}', head):
        raise SystemExit('Source commit must equal the exact checkout HEAD')
    if args.version != config['sdk_version']:
        raise SystemExit('Requested version differs from committed release configuration')
    if dirty and not args.investigation:
        raise SystemExit('Final SDK builds require a clean, committed checkout')
    output = args.output.expanduser().resolve()
    if output == source or source in output.parents or output.exists():
        raise SystemExit('Output must be a new directory outside the checkout')
    output.mkdir(parents=True)
    commands = []

    def run(name, command):
        log = output / (name + '.log')
        began = datetime.datetime.now(datetime.timezone.utc).isoformat()
        start = time.monotonic()
        with log.open('xb') as stream:
            result = subprocess.run(command, cwd=source, stdout=stream, stderr=subprocess.STDOUT)
        receipt = {'name': name, 'command': command, 'started_utc': began, 'elapsed_seconds': time.monotonic() - start,
                   'exit_code': result.returncode, 'log': log.name, 'log_sha256': sha(log)}
        commands.append(receipt)
        (output / 'COMMAND_RECEIPTS.json').write_text(json.dumps(commands, indent=2) + '\n')
        print(json.dumps(receipt), flush=True)
        if result.returncode:
            raise SystemExit(result.returncode)
        return log

    swift = capture(['xcrun', 'swift', '--version'])
    match = re.search(r'\((swiftlang-[0-9.]+) (clang-[0-9.]+)\)', swift)
    if not match:
        raise SystemExit('Cannot identify the actual compiler provenance')
    compiler = match.group(1) + '-' + match.group(2)
    xcode = capture(['xcodebuild', '-version'])
    modules = [config['domain_module'], config['services_module']]
    generated = output / 'ProjectMembership'
    run('generate-membership', [sys.executable, str(source / 'Tools/SDK/generate_framework_project.py'),
                               '--platform', config['platform'], '--source', str(source), '--output', str(generated)])
    committed_project = source / 'SDK/AeostaraSDK.xcodeproj'
    regenerated_project = generated / 'AeostaraSDK.xcodeproj'
    expected = {p.relative_to(regenerated_project): sha(p) for p in regenerated_project.rglob('*') if p.is_file()}
    observed = {p.relative_to(committed_project): sha(p) for p in committed_project.rglob('*') if p.is_file()}
    if expected != observed:
        raise SystemExit('Committed framework membership is stale; regenerate and commit before final build')
    if sha(generated / 'FrameworkInfo.plist') != sha(source / 'SDK/FrameworkInfo.plist'):
        raise SystemExit('Committed framework metadata differs from the generated template')
    pbx = (committed_project / 'project.pbxproj').read_text()
    if pbx.count('productType = "com.apple.product-type.framework"') != 2 or 'DevelopmentDiagnostics' in pbx:
        raise SystemExit('Unexpected release framework target graph')
    variants = [('macos', 'generic/platform=macOS', 'arm64 x86_64', 'macos', '13.0')] if config['platform'] == 'macos' else [
        ('device', 'generic/platform=iOS', 'arm64', 'ios', '16.0'),
        ('simulator', 'generic/platform=iOS Simulator', 'arm64 x86_64', 'iossimulator', '16.0')]
    inspection = []
    abi_location_receipts = []
    for variant, destination, architectures, platform, minimum in variants:
        archive = output / 'Archives' / (variant + '.xcarchive')
        for module in modules:
            settings_log = run(variant + '-' + module + '-settings', ['xcodebuild', '-showBuildSettings', '-json', '-project',
                str(committed_project), '-scheme', module, '-configuration', 'Release', '-destination', destination,
                'ARCHS=' + architectures, 'CODE_SIGNING_ALLOWED=NO'])
            settings = json.loads(settings_log.read_text())
            item = next((s['buildSettings'] for s in settings if s['target'] == module), None)
            if item is None:
                raise SystemExit('Missing resolved framework settings: ' + module)
            for key, value in {'BUILD_LIBRARY_FOR_DISTRIBUTION': 'YES', 'DEFINES_MODULE': 'YES', 'SKIP_INSTALL': 'NO',
                               'ONLY_ACTIVE_ARCH': 'NO', 'MACH_O_TYPE': 'mh_dylib', 'ENABLE_TESTABILITY': 'NO'}.items():
                if item.get(key) != value:
                    raise SystemExit('Unexpected resolved setting: ' + module + ':' + key)
            deployment = 'MACOSX_DEPLOYMENT_TARGET' if config['platform'] == 'macos' else 'IPHONEOS_DEPLOYMENT_TARGET'
            if item.get(deployment) != minimum:
                raise SystemExit('Deployment minimum changed')
        run(variant + '-archive', ['xcodebuild', 'archive', '-project', str(committed_project), '-scheme', modules[1],
            '-configuration', 'Release', '-destination', destination, '-archivePath', str(archive),
            '-derivedDataPath', str(output / 'DerivedData' / variant), 'ARCHS=' + architectures,
            'AEOSTARA_SOURCE_COMMIT=' + ('' if args.investigation else head),
            'AEOSTARA_TOOLCHAIN=' + compiler, 'BUILD_LIBRARY_FOR_DISTRIBUTION=YES',
            'OTHER_SWIFT_FLAGS=$(inherited) -file-prefix-map ' + str(source) + '=SDKSource -debug-prefix-map ' + str(source) + '=SDKSource -file-prefix-map ' + str(output) + '=SDKBuild -debug-prefix-map ' + str(output) + '=SDKBuild',
            'SKIP_INSTALL=NO', 'ONLY_ACTIVE_ARCH=NO', 'CODE_SIGNING_ALLOWED=NO'])
        for module in modules:
            framework = archive / 'Products/Library/Frameworks' / (module + '.framework')
            binary = framework / module
            if not binary.is_file():
                raise SystemExit('Archive did not install genuine framework: ' + module)
            archs = capture(['xcrun', 'lipo', '-archs', str(binary)]).split()
            if set(archs) != set(architectures.split()):
                raise SystemExit('Unexpected framework architectures: ' + module)
            info_path = framework / ('Resources/Info.plist' if config['platform'] == 'macos' else 'Info.plist')
            info = json.loads(capture(['plutil', '-convert', 'json', '-o', '-', str(info_path)]))
            if info.get('CFBundleIdentifier') != 'com.aeostara.sdk.' + module or info.get('CFBundleExecutable') != module or info.get('CFBundlePackageType') != 'FMWK':
                raise SystemExit('Framework ownership identity differs from the public module')
            if info.get('AeostaraSDKVersion') != args.version or info.get('AeostaraToolchain') != compiler:
                raise SystemExit('Framework identity was not stamped')
            if not args.investigation and info.get('AeostaraSourceCommit') != head:
                raise SystemExit('Framework does not identify the exact clean source commit')
            for arch in archs:
                links = capture(['xcrun', 'otool', '-arch', arch, '-L', str(binary)])
                headers = capture(['xcrun', 'otool', '-arch', arch, '-hv', str(binary)])
                if 'DYLIB' not in headers:
                    raise SystemExit('Framework is not a dynamic Mach-O library')
                libraries = [line.strip().split(' (')[0] for line in links.splitlines() if '(compatibility version' in line]
                version_directory = 'Versions/A/' if config['platform'] == 'macos' else ''
                own = '@rpath/' + module + '.framework/' + version_directory + module
                domain = '@rpath/' + modules[0] + '.framework/' + version_directory + modules[0]
                for library in libraries:
                    if library != own and not library.startswith(('/System/Library/', '/usr/lib/')) and not (module == modules[1] and library == domain):
                        raise SystemExit('Unexpected framework linkage: ' + library)
                if own not in libraries or (module == modules[1] and domain not in libraries):
                    raise SystemExit('Missing public framework install/link closure')
                build = capture(['xcrun', 'vtool', '-arch', arch, '-show-build', str(binary)])
                expected_platform = {'macos': 'MACOS', 'ios': 'IOS', 'iossimulator': 'IOSSIMULATOR'}[platform]
                if not re.search(r'platform\s+' + expected_platform + r'\b', build) or not re.search(r'minos\s+' + re.escape(minimum) + r'\b', build):
                    raise SystemExit('Mach-O platform or deployment minimum differs')
                interfaces = list((framework / 'Modules' / (module + '.swiftmodule')).glob(arch + '-*.swiftinterface'))
                public = [p for p in interfaces if not p.name.endswith('.private.swiftinterface')]
                if not public:
                    raise SystemExit('Missing public Swift interface for ' + arch)
                for interface in public:
                    text = interface.read_text()
                    if not re.search(r'\bimport\s+' + re.escape(modules[0]) + r'\b', text) and module == modules[1]:
                        raise SystemExit('Services interface lacks its Domain dependency')
                    if re.search(r'DevelopmentDiagnostics|AeostaraMacCLI|AeostaraApp|Forsetti', text):
                        raise SystemExit('Forbidden release interface closure')
                inspection.append({'variant': variant, 'module': module, 'architecture': arch,
                    'platform': platform, 'minimum_os': minimum, 'dynamic_library': True, 'libraries': libraries,
                    'public_interfaces': [p.name for p in public], 'binary_sha256': sha(binary),
                    'framework_metadata': {key: info[key] for key in ('CFBundleIdentifier', 'CFBundleExecutable', 'CFBundlePackageType',
                        'CFBundleShortVersionString', 'CFBundleVersion', 'AeostaraSDKVersion', 'AeostaraSourceCommit',
                        'AeostaraToolchain', 'DTSDKName', 'DTSDKBuild', 'DTPlatformName', 'DTPlatformVersion',
                        'DTPlatformBuild', 'DTXcode', 'DTXcodeBuild', 'MinimumOSVersion', 'LSMinimumSystemVersion') if key in info}})
            abi_location_receipts.append({'variant': variant, 'module': module,
                                          'descriptors': relativize_abi_source_paths(framework, source)})
    frameworks = output / 'Frameworks'; frameworks.mkdir()
    for module in modules:
        command = ['xcodebuild', '-create-xcframework']
        for variant, *_ in variants:
            command += ['-framework', str(output / 'Archives' / (variant + '.xcarchive') / 'Products/Library/Frameworks' / (module + '.framework'))]
        command += ['-output', str(frameworks / (module + '.xcframework'))]
        run(module + '-xcframework', command)
    manifest = {'schema_version': '1.0', 'sdk_version': args.version, 'platform': config['platform'],
                'source_commit': head, 'source_dirty': bool(dirty), 'final_release_build': not args.investigation,
                'toolchain': {'xcode': xcode, 'swift': swift, 'identity': compiler}, 'signing': 'unsigned',
                'modules': modules, 'framework_inspection': inspection, 'commands': commands,
                'abi_source_location_policy': 'repository-relative ConstValues locations; ABI declarations unchanged',
                'abi_source_location_receipts': abi_location_receipts}
    manifest['framework_payloads'] = {module: framework_inventory(frameworks / (module + '.xcframework'), module) for module in modules}
    final_head = capture(['git', 'rev-parse', 'HEAD'], source)
    final_dirty = capture(['git', 'status', '--porcelain=v1', '--untracked-files=all'], source)
    if final_head != head or final_dirty != dirty or (final_dirty and not args.investigation):
        raise SystemExit('Source identity or cleanliness changed during archive production; no build manifest issued')
    (output / 'BUILD_MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(str(output / 'BUILD_MANIFEST.json'))


if __name__ == '__main__':
    main()
