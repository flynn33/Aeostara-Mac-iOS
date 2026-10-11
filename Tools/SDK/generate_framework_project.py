# Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.
"""Generate genuine dynamic framework targets referencing original native sources."""
import argparse
import hashlib
import pathlib
import plistlib
import xml.etree.ElementTree as ET


def ident(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()


def quote(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', required=True, choices=('macos', 'ios'))
    parser.add_argument('--source', required=True, type=pathlib.Path)
    parser.add_argument('--output', required=True, type=pathlib.Path)
    args = parser.parse_args()
    prefix = 'AeostaraMac' if args.platform == 'macos' else 'Aeostara'
    modules = [prefix + 'Domain', prefix + 'Services']
    records = []

    def add(key, isa, **fields):
        uid = ident(key)
        rendered = ' '.join(f'{k} = {v};' for k, v in fields.items())
        records.append(f'\t\t{uid} = {{ isa = {isa}; {rendered} }};')
        return uid

    def array(values):
        return '(' + ', '.join(values) + (',' if values else '') + ')'

    def settings(values):
        return '{ ' + ' '.join(f'{k} = {quote(v)};' for k, v in values.items()) + ' }'

    product_refs = {}
    source_groups = []
    for module in modules:
        source = args.source / 'Sources' / module
        files = sorted(source.glob('*.swift'))
        if not files:
            raise SystemExit(f'Missing native source membership: {module}')
        build_files = []
        refs = []
        for file in files:
            key = f'{module}/{file.name}'
            ref = add('file:' + key, 'PBXFileReference', lastKnownFileType='sourcecode.swift',
                      path=quote('../Sources/' + key), sourceTree='SOURCE_ROOT')
            refs.append(ref)
            build_files.append(add('source:' + key, 'PBXBuildFile', fileRef=ref))
        source_groups.append(add('group:' + module, 'PBXGroup', name=quote(module), children=array(refs), sourceTree=quote('<group>')))
        product_refs[module] = add('product:' + module, 'PBXFileReference', explicitFileType='wrapper.framework',
                                   includeInIndex='0', path=quote(module + '.framework'), sourceTree='BUILT_PRODUCTS_DIR')
        add('sources:' + module, 'PBXSourcesBuildPhase', buildActionMask='2147483647', files=array(build_files), runOnlyForDeploymentPostprocessing='0')
        add('headers:' + module, 'PBXHeadersBuildPhase', buildActionMask='2147483647', files='()', runOnlyForDeploymentPostprocessing='0')

    target_ids = []
    for module in modules:
        framework_files = []
        dependencies = []
        if module.endswith('Services'):
            domain = modules[0]
            framework_files.append(add('link:' + module, 'PBXBuildFile', fileRef=product_refs[domain]))
            proxy = add('proxy:' + module, 'PBXContainerItemProxy', containerPortal=ident('project'), proxyType='1',
                        remoteGlobalIDString=ident('target:' + domain), remoteInfo=quote(domain))
            dependencies.append(add('dependency:' + module, 'PBXTargetDependency', target=ident('target:' + domain), targetProxy=proxy))
        framework_phase = add('frameworks:' + module, 'PBXFrameworksBuildPhase', buildActionMask='2147483647', files=array(framework_files), runOnlyForDeploymentPostprocessing='0')
        configs = []
        for config in ('Debug', 'Release'):
            values = {
                'PRODUCT_NAME': module, 'PRODUCT_MODULE_NAME': module,
                'PRODUCT_BUNDLE_IDENTIFIER': 'com.aeostara.sdk.' + module,
                'DEFINES_MODULE': 'YES', 'SKIP_INSTALL': 'NO',
                'BUILD_LIBRARY_FOR_DISTRIBUTION': 'YES',
                'GENERATE_INFOPLIST_FILE': 'NO',
                'INFOPLIST_FILE': '$(SRCROOT)/FrameworkInfo.plist',
                'CURRENT_PROJECT_VERSION': '1', 'MARKETING_VERSION': '0.1.0',
                'AEOSTARA_SDK_VERSION': '0.1.0-rc.1',
                'SWIFT_VERSION': '5.0', 'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if config == 'Debug' else '-O',
                'SWIFT_COMPILATION_MODE': 'singlefile' if config == 'Debug' else 'wholemodule',
                'ENABLE_TESTABILITY': 'YES' if config == 'Debug' else 'NO',
                'ONLY_ACTIVE_ARCH': 'NO', 'MACH_O_TYPE': 'mh_dylib',
                'CODE_SIGN_STYLE': 'Manual', 'CODE_SIGNING_ALLOWED': 'NO',
                'DEBUG_INFORMATION_FORMAT': 'dwarf-with-dsym',
                'DYLIB_INSTALL_NAME_BASE': '@rpath',
                'INSTALL_PATH': '$(LOCAL_LIBRARY_DIR)/Frameworks',
                'SWIFT_SERIALIZE_DEBUGGING_OPTIONS': 'NO',
                'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @loader_path/Frameworks @rpath',
                'CLANG_ENABLE_MODULES': 'YES',
            }
            if args.platform == 'macos':
                values.update(SDKROOT='macosx', SUPPORTED_PLATFORMS='macosx', MACOSX_DEPLOYMENT_TARGET='13.0')
            else:
                values.update(SDKROOT='iphoneos', SUPPORTED_PLATFORMS='iphoneos iphonesimulator',
                              IPHONEOS_DEPLOYMENT_TARGET='16.0', TARGETED_DEVICE_FAMILY='1,2', SUPPORTS_MACCATALYST='NO')
            configs.append(add('config:' + module + ':' + config, 'XCBuildConfiguration', buildSettings=settings(values), name=quote(config)))
        config_list = add('config-list:' + module, 'XCConfigurationList', buildConfigurations=array(configs), defaultConfigurationIsVisible='0', defaultConfigurationName='Release')
        target_ids.append(add('target:' + module, 'PBXNativeTarget', buildConfigurationList=config_list,
                              buildPhases=array([ident('headers:' + module), ident('sources:' + module), framework_phase]),
                              buildRules='()', dependencies=array(dependencies), name=quote(module),
                              productName=quote(module), productReference=product_refs[module],
                              productType=quote('com.apple.product-type.framework')))
    products = add('group:Products', 'PBXGroup', children=array(list(product_refs.values())), name='Products', sourceTree=quote('<group>'))
    main_group = add('group:root', 'PBXGroup', children=array(source_groups + [products]), sourceTree=quote('<group>'))
    project_configs = [add('config:project:' + config, 'XCBuildConfiguration', buildSettings='{}', name=quote(config)) for config in ('Debug', 'Release')]
    project_config_list = add('config-list:project', 'XCConfigurationList', buildConfigurations=array(project_configs), defaultConfigurationIsVisible='0', defaultConfigurationName='Release')
    project = add('project', 'PBXProject', attributes='{ LastUpgradeCheck = 2700; }', buildConfigurationList=project_config_list,
                  compatibilityVersion=quote('Xcode 14.0'), developmentRegion='en', hasScannedForEncodings='0',
                  knownRegions='(en, Base,)', mainGroup=main_group, productRefGroup=products,
                  projectDirPath=quote(''), projectRoot=quote(''), targets=array(target_ids))
    output = args.output / 'AeostaraSDK.xcodeproj'
    schemes = output / 'xcshareddata' / 'xcschemes'
    schemes.mkdir(parents=True, exist_ok=True)
    (args.output / 'FrameworkInfo.plist').write_bytes(plistlib.dumps({
        'CFBundleDevelopmentRegion': '$(DEVELOPMENT_LANGUAGE)',
        'CFBundleExecutable': '$(EXECUTABLE_NAME)',
        'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)',
        'CFBundleInfoDictionaryVersion': '6.0',
        'CFBundleName': '$(PRODUCT_NAME)',
        'CFBundlePackageType': 'FMWK',
        'CFBundleShortVersionString': '$(MARKETING_VERSION)',
        'CFBundleVersion': '$(CURRENT_PROJECT_VERSION)',
        'AeostaraSDKVersion': '$(AEOSTARA_SDK_VERSION)',
        'AeostaraSourceCommit': '$(AEOSTARA_SOURCE_COMMIT)',
        'AeostaraToolchain': '$(AEOSTARA_TOOLCHAIN)',
    }))
    (output / 'project.pbxproj').write_text('// !$*UTF8*$!\n{\n archiveVersion = 1; classes = {}; objectVersion = 56;\n objects = {\n' + '\n'.join(records) + f'\n }}; rootObject = {project};\n}}\n')
    for module in modules:
        scheme = ET.Element('Scheme', LastUpgradeVersion='2700', version='1.7')
        action = ET.SubElement(scheme, 'BuildAction', parallelizeBuildables='YES', buildImplicitDependencies='YES')
        entries = ET.SubElement(action, 'BuildActionEntries')
        entry = ET.SubElement(entries, 'BuildActionEntry', buildForTesting='YES', buildForRunning='YES', buildForProfiling='YES', buildForArchiving='YES', buildForAnalyzing='YES')
        ET.SubElement(entry, 'BuildableReference', BuildableIdentifier='primary', BlueprintIdentifier=ident('target:' + module),
                      BuildableName=module + '.framework', BlueprintName=module, ReferencedContainer='container:AeostaraSDK.xcodeproj')
        ET.SubElement(scheme, 'TestAction', buildConfiguration='Debug', selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB', selectedLauncherIdentifier='Xcode.DebuggerFoundation.Launcher.LLDB', shouldUseLaunchSchemeArgsEnv='YES')
        ET.SubElement(scheme, 'LaunchAction', buildConfiguration='Debug', selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB', selectedLauncherIdentifier='Xcode.DebuggerFoundation.Launcher.LLDB', launchStyle='0', useCustomWorkingDirectory='NO', ignoresPersistentStateOnLaunch='NO', debugDocumentVersioning='YES', allowLocationSimulation='YES')
        ET.SubElement(scheme, 'ProfileAction', buildConfiguration='Release', shouldUseLaunchSchemeArgsEnv='YES', savedToolIdentifier='', useCustomWorkingDirectory='NO', debugDocumentVersioning='YES')
        ET.SubElement(scheme, 'AnalyzeAction', buildConfiguration='Debug')
        ET.SubElement(scheme, 'ArchiveAction', buildConfiguration='Release', revealArchiveInOrganizer='YES')
        ET.indent(scheme)
        ET.ElementTree(scheme).write(schemes / (module + '.xcscheme'), encoding='UTF-8', xml_declaration=True)
    print(output)


if __name__ == '__main__':
    main()
