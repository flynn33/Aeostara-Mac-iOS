# Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
"""Validate the exact unsigned Xcode framework structure and bind every byte."""
import hashlib
import os
import pathlib
import plistlib


def framework_inventory(root, module):
    root = pathlib.Path(root).resolve()
    if root.name != module + '.xcframework' or not root.is_dir():
        raise ValueError('Unexpected XCFramework identity')
    with (root / 'Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    if info.get('XCFrameworkFormatVersion') != '1.0':
        raise ValueError('Unsupported XCFramework format')
    libraries = info.get('AvailableLibraries')
    if not isinstance(libraries, list) or not libraries:
        raise ValueError('Missing XCFramework libraries')
    files, optional_files = {'Info.plist'}, set()
    directories, links, variants = set(), {}, set()
    for library in libraries:
        platform = library.get('SupportedPlatform')
        variant = library.get('SupportedPlatformVariant')
        architectures = library.get('SupportedArchitectures')
        identifier = library.get('LibraryIdentifier')
        if not isinstance(architectures, list) or not architectures or len(set(architectures)) != len(architectures):
            raise ValueError('Invalid XCFramework architectures')
        if platform == 'macos' and variant is None:
            kind, triple = 'macos', 'apple-macos'
            expected_architectures = {'arm64', 'x86_64'}
        elif platform == 'ios' and variant is None:
            kind, triple = 'device', 'apple-ios'
            expected_architectures = {'arm64'}
        elif platform == 'ios' and variant == 'simulator':
            kind, triple = 'simulator', 'apple-ios-simulator'
            expected_architectures = {'arm64', 'x86_64'}
        else:
            raise ValueError('Unsupported XCFramework platform variant')
        if set(architectures) != expected_architectures or kind in variants:
            raise ValueError('Unexpected or duplicate XCFramework slice')
        variants.add(kind)
        expected_identifier = platform + '-' + '_'.join(sorted(architectures)) + ('-simulator' if variant else '')
        if identifier != expected_identifier or library.get('LibraryPath') != module + '.framework':
            raise ValueError('Unexpected XCFramework library path')
        base = identifier + '/' + module + '.framework'
        directories |= {identifier, base}
        if platform == 'macos':
            directories |= {base + '/Versions', base + '/Versions/A'}
            for name in [module, 'Headers', 'Modules', 'Resources']:
                links[base + '/' + name] = 'Versions/Current/' + name
            links[base + '/Versions/Current'] = 'A'
            body = base + '/Versions/A'
            files.add(body + '/Resources/Info.plist')
            directories.add(body + '/Resources')
        else:
            body = base
            files.add(body + '/Info.plist')
        files |= {body + '/' + module, body + '/Headers/' + module + '-Swift.h', body + '/Modules/module.modulemap'}
        directories |= {body + '/Headers', body + '/Modules', body + '/Modules/' + module + '.swiftmodule'}
        for architecture in architectures:
            prefix = body + '/Modules/' + module + '.swiftmodule/' + architecture + '-' + triple
            files |= {prefix + suffix for suffix in ['.swiftinterface', '.private.swiftinterface', '.swiftdoc', '.abi.json']}
            optional_files.add(prefix + '.swiftmodule')
    expected_variants = {'macos'} if module.startswith('AeostaraMac') else {'device', 'simulator'}
    if variants != expected_variants:
        raise ValueError('Incomplete platform XCFramework closure')
    actual = {p.relative_to(root).as_posix(): p for p in root.rglob('*')}
    files |= optional_files & set(actual)
    if set(actual) != files | directories | set(links):
        unexpected = set(actual) - files - directories - set(links)
        missing = (files | directories | set(links)) - set(actual)
        raise ValueError('Framework structure differs: unexpected=' + repr(sorted(unexpected)) + ', missing=' + repr(sorted(missing)))
    result = []
    for name, path in sorted(actual.items()):
        if name in links:
            if not path.is_symlink() or os.readlink(path) != links[name] or root not in path.resolve(strict=True).parents:
                raise ValueError('Invalid framework version symlink: ' + name)
            result.append({'path': name, 'type': 'symlink', 'target': links[name],
                           'sha256': hashlib.sha256(os.fsencode(links[name])).hexdigest()})
        elif name in directories:
            if path.is_symlink() or not path.is_dir():
                raise ValueError('Framework directory replaced: ' + name)
            result.append({'path': name, 'type': 'directory'})
        else:
            if path.is_symlink() or not path.is_file():
                raise ValueError('Framework file replaced: ' + name)
            payload = path.read_bytes()
            if b'/Users/' in payload or b'\\/Users\\/' in payload:
                raise ValueError('Machine-private path in framework payload: ' + name)
            result.append({'path': name, 'type': 'file', 'bytes': path.stat().st_size,
                           'sha256': hashlib.sha256(payload).hexdigest()})
    return result
