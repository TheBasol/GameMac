#!/usr/bin/env python3
import os
import uuid

def generate_uuid():
    # Xcode uses 24-character uppercase hexadecimal UUIDs
    return uuid.uuid4().hex[:24].upper()

def main():
    print("Generating Xcode project for GameMac with folder groups...")
    
    project_dir = os.path.dirname(os.path.abspath(__file__))
    xcodeproj_path = os.path.join(project_dir, "GameMac.xcodeproj")
    os.makedirs(xcodeproj_path, exist_ok=True)
    
    # Static UUIDs to make the project deterministic and correct
    proj_uuid = "24F4B8922C0C300000D00001"
    main_group_uuid = "24F4B8932C0C300000D00001"
    target_uuid = "24F4B8942C0C300000D00001"
    sources_phase_uuid = "24F4B8952C0C300000D00001"
    frameworks_phase_uuid = "24F4B8962C0C300000D00001"
    resources_phase_uuid = "24F4B8972C0C300000D00001"
    debug_config_list_uuid = "24F4B8982C0C300000D00001"
    release_config_list_uuid = "24F4B8992C0C300000D00001"
    
    # Collect Swift files in GameMac
    swift_files = []
    gamemac_dir = os.path.join(project_dir, "GameMac")
    for root, dirs, files in os.walk(gamemac_dir):
        # Exclude hidden directories
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for file in files:
            if file.endswith(".swift"):
                rel_path = os.path.relpath(os.path.join(root, file), project_dir)
                swift_files.append(rel_path)
    
    print(f"Found {len(swift_files)} Swift files in the GameMac folder.")
    
    # Collect layout JSON resources
    layout_files = []
    layouts_dir = os.path.join(project_dir, "GameMac", "Resources", "Layouts")
    if os.path.isdir(layouts_dir):
        for file in sorted(os.listdir(layouts_dir)):
            if file.endswith(".json"):
                rel_path = os.path.relpath(os.path.join(layouts_dir, file), project_dir)
                layout_files.append(rel_path)
    
    print(f"Found {len(layout_files)} layout JSON files.")
    
    # UUID mapping for comments in PBXGroups
    uuid_to_name = {
        "24F4B89E2C0C300000D00001": "GameMac.app",
        "24F4B89F2C0C300000D00001": "Frameworks",
        "24F4B89B2C0C300000D00001": "AppKit.framework",
        "24F4B89C2C0C300000D00001": "IOKit.framework",
        "24F4B89D2C0C300000D00001": "CoreGraphics.framework"
    }
    
    file_references = []
    build_files = []
    sources_children = []
    resources_children = []
    
    # Tree representation of Groups
    # Key: tuple of directory components, e.g. ("GameMac", "App")
    # Value: { "uuid": "...", "name": "App", "children_uuids": [...] }
    groups = {
        (): {
            "uuid": main_group_uuid,
            "name": None,
            "children_uuids": [
                "24F4B89E2C0C300000D00001", # GameMac.app
                "24F4B89F2C0C300000D00001"  # Frameworks
            ]
        }
    }
    
    def add_file_to_groups(file_path, file_uuid, filename):
        parts = file_path.split("/")
        # Build groups recursively
        for i in range(1, len(parts)):
            parent_path = tuple(parts[:i-1])
            current_path = tuple(parts[:i])
            if current_path not in groups:
                group_uuid = generate_uuid()
                name = parts[i-1]
                groups[current_path] = {
                    "uuid": group_uuid,
                    "name": name,
                    "children_uuids": []
                }
                uuid_to_name[group_uuid] = name
                # Add current group to parent's children list
                groups[parent_path]["children_uuids"].append(group_uuid)
        # Add file uuid to its parent group
        file_dir_path = tuple(parts[:-1])
        groups[file_dir_path]["children_uuids"].append(file_uuid)
        uuid_to_name[file_uuid] = filename

    # Process Swift files
    for file in sorted(swift_files):
        file_uuid = generate_uuid()
        build_uuid = generate_uuid()
        filename = os.path.basename(file)
        
        file_references.append(f'\t\t{file_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{file}"; sourceTree = "<group>"; }};')
        build_files.append(f'\t\t{build_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {filename} */; }};')
        sources_children.append(f'\t\t\t\t{build_uuid} /* {filename} in Sources */,')
        
        add_file_to_groups(file, file_uuid, filename)
        
    # Process layout files
    for file in sorted(layout_files):
        file_uuid = generate_uuid()
        build_uuid = generate_uuid()
        filename = os.path.basename(file)
        
        file_references.append(f'\t\t{file_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = text.json; path = "{file}"; sourceTree = "<group>"; }};')
        build_files.append(f'\t\t{build_uuid} /* {filename} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {filename} */; }};')
        resources_children.append(f'\t\t\t\t{build_uuid} /* {filename} in Resources */,')
        
        add_file_to_groups(file, file_uuid, filename)
        
    # Process Entitlements
    entitlements_file = "GameMac/Entitlements/GameMac.entitlements"
    entitlements_uuid = "24F4B8A02C0C300000D00001"
    file_references.append(f'\t\t{entitlements_uuid} /* GameMac.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = "{entitlements_file}"; sourceTree = "<group>"; }};')
    add_file_to_groups(entitlements_file, entitlements_uuid, "GameMac.entitlements")
    
    # Process Info.plist
    infoplist_file = "GameMac/Resources/Info.plist"
    infoplist_uuid = "24F4B8A12C0C300000D00001"
    file_references.append(f'\t\t{infoplist_uuid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "{infoplist_file}"; sourceTree = "<group>"; }};')
    add_file_to_groups(infoplist_file, infoplist_uuid, "Info.plist")
    
    # Generate PBXGroup Section
    group_blocks = []
    
    # Root group is special (no name attribute, and links main elements)
    root_group_info = groups[()]
    root_children = []
    for c_uuid in root_group_info["children_uuids"]:
        c_name = uuid_to_name.get(c_uuid, "")
        comment = f" /* {c_name} */" if c_name else ""
        root_children.append(f'\t\t\t\t{c_uuid}{comment},')
    
    root_group_str = f"""\t\t{main_group_uuid} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{"\n".join(root_children)}
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};"""
    group_blocks.append(root_group_str)
    
    # Frameworks group
    frameworks_group_str = """\t\t24F4B89F2C0C300000D00001 /* Frameworks */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t24F4B89B2C0C300000D00001 /* AppKit.framework */,
\t\t\t\t24F4B89C2C0C300000D00001 /* IOKit.framework */,
\t\t\t\t24F4B89D2C0C300000D00001 /* CoreGraphics.framework */,
\t\t\t);
\t\t\tname = Frameworks;
\t\t\tsourceTree = "<group>";
\t\t};"""
    group_blocks.append(frameworks_group_str)
    
    # Add all generated subdirectory groups
    for path in sorted(groups.keys(), key=len):
        if path == ():
            continue
        g_info = groups[path]
        g_uuid = g_info["uuid"]
        g_name = g_info["name"]
        
        c_lines = []
        for c_uuid in g_info["children_uuids"]:
            c_name = uuid_to_name.get(c_uuid, "")
            comment = f" /* {c_name} */" if c_name else ""
            c_lines.append(f'\t\t\t\t{c_uuid}{comment},')
            
        group_str = f"""\t\t{g_uuid} /* {g_name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{"\n".join(c_lines)}
\t\t\t);
\t\t\tname = "{g_name}";
\t\t\tsourceTree = "<group>";
\t\t}};"""
        group_blocks.append(group_str)
        
    # Strings to merge in pbxproj template
    build_files_str = "\n".join(build_files)
    file_references_str = "\n".join(file_references)
    pbxgroups_content = "\n".join(group_blocks)
    sources_children_str = "\n".join(sources_children)
    resources_children_str = "\n".join(resources_children)
    
    # Generate content of pbxproj
    pbxproj_content = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{build_files_str}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_references_str}
		24F4B89B2C0C300000D00001 /* AppKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = AppKit.framework; path = System/Library/Frameworks/AppKit.framework; sourceTree = SDKROOT; }};
		24F4B89C2C0C300000D00001 /* IOKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = IOKit.framework; path = System/Library/Frameworks/IOKit.framework; sourceTree = SDKROOT; }};
		24F4B89D2C0C300000D00001 /* CoreGraphics.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = CoreGraphics.framework; path = System/Library/Frameworks/CoreGraphics.framework; sourceTree = SDKROOT; }};
		24F4B89E2C0C300000D00001 /* GameMac.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = GameMac.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase_uuid} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{pbxgroups_content}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target_uuid} /* GameMac */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {debug_config_list_uuid} /* Build configuration list for PBXNativeTarget "GameMac" */;
			buildPhases = (
				{sources_phase_uuid} /* Sources */,
				{frameworks_phase_uuid} /* Frameworks */,
				{resources_phase_uuid} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = GameMac;
			productName = GameMac;
			productReference = 24F4B89E2C0C300000D00001 /* GameMac.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{proj_uuid} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1420;
				LastUpgradeCheck = 1420;
				TargetAttributes = {{
					{target_uuid} = {{
						CreatedOnToolsVersion = 14.2;
						LastSwiftMigration = 1420;
					}};
				}};
			}};
			buildConfigurationList = {release_config_list_uuid} /* Build configuration list for PBXProject "GameMac" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {main_group_uuid};
			productRefGroup = {main_group_uuid};
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target_uuid} /* GameMac */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_phase_uuid} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{resources_children_str}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase_uuid} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{sources_children_str}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		24F4B8A22C0C300000D00001 /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_MIN_MAX_LIMITS = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_PREP_TO_NONDIRECT_SEL = YES;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = Debug;
		}};
		24F4B8A32C0C300000D00001 /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_MIN_MAX_LIMITS = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_PREP_TO_NONDIRECT_SEL = YES;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				COPY_PHASE_STRIP = YES;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			}};
			name = Release;
		}};
		24F4B8A42C0C300000D00001 /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "GameMac/Entitlements/GameMac.entitlements";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_HARDENED_RUNTIME = NO;
				INFOPLIST_FILE = "GameMac/Resources/Info.plist";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.gamemac.GameMac;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "macosx";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.7;
			}};
			name = Debug;
		}};
		24F4B8A52C0C300000D00001 /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "GameMac/Entitlements/GameMac.entitlements";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_HARDENED_RUNTIME = NO;
				INFOPLIST_FILE = "GameMac/Resources/Info.plist";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.gamemac.GameMac;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "macosx";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.7;
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{debug_config_list_uuid} /* Build configuration list for PBXNativeTarget "GameMac" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				24F4B8A42C0C300000D00001 /* Debug */,
				24F4B8A52C0C300000D00001 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{release_config_list_uuid} /* Build configuration list for PBXProject "GameMac" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				24F4B8A22C0C300000D00001 /* Debug */,
				24F4B8A32C0C300000D00001 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {proj_uuid} /* Project object */;
}}
"""
    
    pbxproj_path = os.path.join(xcodeproj_path, "project.pbxproj")
    with open(pbxproj_path, "w", encoding="utf-8") as f:
        f.write(pbxproj_content)
    
    print(f"Xcode project generated successfully at {xcodeproj_path}!")
    print("You can open it by running: open GameMac.xcodeproj")

if __name__ == "__main__":
    main()
