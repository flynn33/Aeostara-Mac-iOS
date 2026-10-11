# Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
"""Assemble only the SDK allowlist from a clean final build and committed docs."""
import argparse
import hashlib
import json
import os
import pathlib
import shutil
import stat
import subprocess
import zipfile
from artifact_inventory import framework_inventory


DOCUMENTS = ('Integration.md', 'Public_API.md', 'Safety_and_Recovery.md', 'Diagnostics.md', 'Compatibility.md', 'Migration.md')
FORBIDDEN = {'.git', '.build', '.DS_Store', '__MACOSX', 'DerivedData', 'Sources', 'Tests', 'Fixtures', 'specs', 'ci', 'corpora', 'quarantine'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory(root, modules):
    for module in modules:
        framework_inventory(root / 'Frameworks' / (module + '.xcframework'), module)
    fixed = {'Package.swift', 'README.md', 'LICENSE', 'NOTICE'} | {'Documentation/' + d for d in DOCUMENTS}
    result = []
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root)
        name = relative.as_posix()
        if name == 'SDK_MANIFEST.json':
            continue
        if any(piece in FORBIDDEN for piece in relative.parts) or '..' in relative.parts or relative.is_absolute():
            raise SystemExit('Forbidden SDK entry: ' + name)
        framework = len(relative.parts) > 1 and relative.parts[0] == 'Frameworks' and relative.parts[1] in {m + '.xcframework' for m in modules}
        directory = path.is_dir() and not path.is_symlink()
        if name not in fixed and not framework and not (directory and name in {'Frameworks', 'Documentation'}):
            raise SystemExit('Entry outside the SDK allowlist: ' + name)
        if any(marker in name for marker in ('DevelopmentDiagnostics', 'AeostaraMacCLI', 'AeostaraApp', '.app/', '.log', '.xcresult', '.xcodeproj', '.xcworkspace')):
            raise SystemExit('Non-SDK payload: ' + name)
        if path.is_symlink():
            destination = path.resolve(strict=True)
            target = os.readlink(path)
            if os.path.isabs(target) or root not in destination.parents:
                raise SystemExit('SDK symlink escapes its payload: ' + name)
            result.append({'path': name, 'type': 'symlink', 'target': target,
                           'sha256': hashlib.sha256(os.fsencode(target)).hexdigest()})
        elif directory:
            result.append({'path': name, 'type': 'directory'})
        elif path.is_file():
            result.append({'path': name, 'type': 'file', 'bytes': path.stat().st_size, 'sha256': sha(path)})
        else:
            raise SystemExit('Unsupported SDK filesystem entry: ' + name)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-root', required=True, type=pathlib.Path)
    parser.add_argument('--output', required=True, type=pathlib.Path)
    args = parser.parse_args()
    source = pathlib.Path(__file__).resolve().parents[2]
    config = json.loads((source / 'SDK/ReleaseConfiguration.json').read_text())
    build_root = args.build_root.resolve()
    build = json.loads((build_root / 'BUILD_MANIFEST.json').read_text())
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source, text=True).strip()
    dirty = subprocess.check_output(['git', 'status', '--porcelain=v1', '--untracked-files=all'], cwd=source, text=True).strip()
    if dirty or not build.get('final_release_build') or build.get('source_dirty') or build.get('source_commit') != head:
        raise SystemExit('Packaging requires the exact clean source and a final release build')
    if build.get('platform') != config['platform'] or build.get('sdk_version') != config['sdk_version']:
        raise SystemExit('Build/configuration identity mismatch')
    output = args.output.expanduser().resolve()
    if output.exists() or output == source or source in output.parents:
        raise SystemExit('Packaging output must be a new directory outside source')
    output.mkdir(parents=True)
    platform = 'macOS' if config['platform'] == 'macos' else 'iOS'
    root = output / ('Aeostara-' + platform + '-SDK')
    root.mkdir()
    documentation = root / 'Documentation'; documentation.mkdir()
    for name in DOCUMENTS:
        document = source / 'SDK/Documentation' / name
        if not document.is_file() or not document.read_text().strip():
            raise SystemExit('Missing SDK documentation: ' + name)
        shutil.copyfile(document, documentation / name)
    for src, dst in [('SDK/README.md', 'README.md'), ('LICENSE', 'LICENSE')]:
        file = source / src
        if not file.is_file() or not file.read_text().strip():
            raise SystemExit('Missing committed SDK file: ' + src)
        shutil.copyfile(file, root / dst)
    if (source / 'NOTICE').is_file():
        shutil.copyfile(source / 'NOTICE', root / 'NOTICE')
    modules = [config['domain_module'], config['services_module']]
    frameworks = root / 'Frameworks'; frameworks.mkdir()
    for module in modules:
        origin = build_root / 'Frameworks' / (module + '.xcframework')
        if not origin.is_dir():
            raise SystemExit('Missing compiled XCFramework: ' + module)
        if framework_inventory(origin, module) != build.get('framework_payloads', {}).get(module):
            raise SystemExit('Framework bytes differ from the recorded final build: ' + module)
        shutil.copytree(origin, frameworks / origin.name, symlinks=True)
        if framework_inventory(frameworks / origin.name, module) != build['framework_payloads'][module]:
            raise SystemExit('Copied framework differs from the recorded final build: ' + module)
    package_name = 'AeostaraMacSDK' if config['platform'] == 'macos' else 'AeostaraIOSSDK'
    minimum = '.macOS(.v13)' if config['platform'] == 'macos' else '.iOS(.v16)'
    (root / 'Package.swift').write_text('''// swift-tools-version: 5.9
// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
import PackageDescription
let package = Package(
    name: "%s",
    platforms: [%s],
    products: [
        .library(name: "%s", targets: ["%s"]),
        .library(name: "%s", targets: ["%s", "%s"])
    ],
    targets: [
        .binaryTarget(name: "%s", path: "Frameworks/%s.xcframework"),
        .binaryTarget(name: "%s", path: "Frameworks/%s.xcframework")
    ]
)
''' % (package_name, minimum, modules[0], modules[0], modules[1], modules[1], modules[0], modules[0], modules[0], modules[1], modules[1]))
    entries = inventory(root, modules)
    def confirm_source():
        now_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source, text=True).strip()
        now_dirty = subprocess.check_output(['git', 'status', '--porcelain=v1', '--untracked-files=all'], cwd=source, text=True).strip()
        if now_head != head or now_dirty:
            raise SystemExit('Source identity or cleanliness changed during packaging; no final package receipt issued')
    confirm_source()
    manifest = {'schema_version': '1.0', 'sdk_version': config['sdk_version'], 'platform': config['platform'],
                'source_commit': head, 'base_commit': config['base_commit'], 'ash_commit': config['ash_commit'],
                'build_manifest_sha256': sha(build_root / 'BUILD_MANIFEST.json'), 'toolchain': build['toolchain'],
                'signing': build['signing'], 'framework_inspection': build['framework_inspection'],
                'products': {modules[0]: [modules[0]], modules[1]: [modules[1], modules[0]]},
                'payload_hash_rule': 'Regular file bytes; symlink target bytes; SDK_MANIFEST.json excluded', 'payload': entries}
    (root / 'SDK_MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
    if inventory(root, modules) != entries:
        raise SystemExit('Staged SDK changed during inventory')
    package = subprocess.run(['swift', 'package', '--package-path', str(root), 'dump-package'], text=True, capture_output=True)
    if package.returncode:
        raise SystemExit('Invalid binary package: ' + package.stderr)
    graph = json.loads(package.stdout)
    if len(graph['targets']) != 2 or any(t['type'] != 'binary' for t in graph['targets']) or graph['dependencies']:
        raise SystemExit('Binary package includes unexpected targets/dependencies')
    archive = output / ('Aeostara-' + platform + '-SDK-' + config['sdk_version'] + '.zip')
    subprocess.run(['/usr/bin/ditto', '-c', '-k', '--keepParent', '--norsrc', str(root), str(archive)], check=True)
    with zipfile.ZipFile(archive) as zipped:
        names = set()
        for entry in zipped.infolist():
            name = pathlib.PurePosixPath(entry.filename)
            if name.is_absolute() or '..' in name.parts or not name.parts or name.parts[0] != root.name or entry.filename in names:
                raise SystemExit('Unsafe or duplicate ZIP entry: ' + entry.filename)
            names.add(entry.filename)
            mode = entry.external_attr >> 16
            if stat.S_ISLNK(mode):
                target = zipped.read(entry).decode('utf8')
                if pathlib.PurePosixPath(target).is_absolute():
                    raise SystemExit('Absolute ZIP symlink')
        expected = {root.name + '/' + e['path'] + ('/' if e['type'] == 'directory' else '') for e in entries}
        expected |= {root.name + '/', root.name + '/SDK_MANIFEST.json'}
        if names != expected:
            raise SystemExit('ZIP contents differ from the exact staged allowlist')
        for item in entries:
            name = root.name + '/' + item['path']
            if item['type'] == 'file':
                data = zipped.read(name)
                if len(data) != item['bytes'] or hashlib.sha256(data).hexdigest() != item['sha256']:
                    raise SystemExit('ZIP bytes differ from the recorded payload: ' + name)
            elif item['type'] == 'symlink' and zipped.read(name) != os.fsencode(item['target']):
                raise SystemExit('ZIP symlink differs from the recorded payload: ' + name)
        if zipped.read(root.name + '/SDK_MANIFEST.json') != (root / 'SDK_MANIFEST.json').read_bytes():
            raise SystemExit('ZIP manifest differs from the staged manifest')
    receipt = {'sdk_version': config['sdk_version'], 'source_commit': head, 'archive': archive.name,
               'bytes': archive.stat().st_size, 'sha256': sha(archive), 'sdk_manifest_sha256': sha(root / 'SDK_MANIFEST.json'),
               'payload_entries': len(entries), 'exact_zip_inventory_verified': True}
    confirm_source()
    (output / 'PACKAGE_RECEIPT.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    main()
