require('json')
require('pathname')

require_relative('node')
require_relative('pod_helpers')
require_relative('xcode')

def app_config(project_root)
  manifest = app_manifest(project_root)
  return [nil, nil, nil] if manifest.nil?

  [manifest['name'], manifest['displayName'], manifest['version'], manifest['singleApp']]
end

def apply_config_plugins(project_root, target_platform)
  begin
    resolve_module('@expo/config-plugins')
  rescue StandardError
    # Skip if `@expo/config-plugins` cannot be found
    return
  end

  apply_config_plugins = File.join(__dir__, 'scripts', 'apply-config-plugins.mjs')
  result = system("node \"#{apply_config_plugins}\" \"#{project_root}\" --#{target_platform}")
  raise 'Failed to apply config plugins' unless result
end

def autolink_script_path(project_root, target_platform, react_native_version)
  start_dir = if react_native_version >= v(0, 76, 0)
                project_root
              else
                react_native_path(project_root, target_platform)
              end
  package_path = resolve_module('@react-native-community/cli-platform-ios', start_dir)
  File.join(package_path, 'native_modules')
end

def react_native_path(project_root, target_platform)
  @react_native_path ||= {}

  unless @react_native_path.key?(target_platform)
    react_native_path = platform_config('reactNativePath', project_root, target_platform)
    if react_native_path.is_a? String
      @react_native_path[target_platform] = Pathname.new(resolve_module(react_native_path))
    else
      manifest = JSON.parse(File.read(File.join(__dir__, '..', '..', 'package.json')))
      react_native = manifest['defaultPlatformPackages'][target_platform.to_s]
      raise "Unsupported target platform: #{target_platform}" if react_native.nil?

      @react_native_path[target_platform] = Pathname.new(resolve_module(react_native))
    end
  end

  @react_native_path[target_platform]
end

def target_product_type(target)
  target.product_type if target.respond_to?(:product_type)
end

def react_native_pods(version)
  if version.zero? || version >= v(0, 71, 0)
    'use_react_native-0.71'
  elsif version >= v(0, 70, 0)
    'use_react_native-0.70'
  else
    raise "Unsupported React Native version: #{version}"
  end
end

def validate_resources(resources, app_dir)
  excluded = []
  not_found = []
  resources.each do |r|
    if r.start_with?('..')
      excluded << r
    elsif !File.exist?(File.join(app_dir, r))
      not_found << r
    end
  end

  unless excluded.empty?
    items = excluded.join("\n  ")
    Pod::UI.warn("CocoaPods does not allow resources outside the project root:\n  #{items}")
  end

  unless not_found.empty?
    items = not_found.join("\n  ")
    Pod::UI.warn(
      "CocoaPods will not include resources it cannot find:\n  #{items}\n\n" \
      'The app will still build and run if they are served by the dev ' \
      'server. To include missing resources, make sure they exist, then run ' \
      '`pod install` again to update the workspace.'
    )
  end

  resources
end

def resources_pod(project_root, target_platform, platforms)
  app_manifest = find_file('app.json', project_root)
  return if app_manifest.nil?

  app_dir = File.dirname(app_manifest)
  resources = resolve_resources(app_manifest(project_root), target_platform)
  return if resources.nil? || resources.empty?

  spec = {
    'name' => 'TemplateProject-Resources',
    'version' => '1.0.0-dev',
    'summary' => 'Resources for TemplateProject',
    'homepage' => 'https://github.com/microsoft/react-native-test-app',
    'license' => 'Unlicense',
    'authors' => '@microsoft/react-native-test-app',
    'source' => { 'git' => 'https://github.com/microsoft/react-native-test-app.git' },
    'platforms' => {
      'osx' => platforms[:macos],
    },
    'resources' => validate_resources(resources, app_dir),
  }

  podspec_path = File.join(app_dir, 'TemplateProject-Resources.podspec.json')
  File.open(podspec_path, 'w') do |f|
    # Under certain conditions, the file doesn't get written to disk before it
    # is read by CocoaPods.
    f.write(spec.to_json)
    f.fsync
    ObjectSpace.define_finalizer(self, Remover.new(f))
  end

  Pathname.new(app_dir).relative_path_from(project_root).to_s
end

def __use_react_native!(project_root, target_platform, options)
  react_native = react_native_path(project_root, target_platform)
  version = package_version(react_native.to_s).segments
  version = v(version[0], version[1], version[2])

  require_relative(react_native_pods(version))

  include_react_native!(**options,
                        app_path: find_file('package.json', project_root).parent.to_s,
                        path: react_native.relative_path_from(project_root).to_s,
                        rta_project_root: project_root,
                        version: version)
end

def make_project!(xcodeproj, project_root, target_platform, options)
  xcodeproj_src = File.join(project_root, '.generate', 'assets', 'project.pbxproj')
  destination = project_path(project_root, target_platform)
  xcodeproj_dst = File.join(destination, xcodeproj)

  name, display_name, version, single_app = app_config(project_root)

  # Copy Xcode project files
  FileUtils.mkdir_p(destination)
  FileUtils.cp(xcodeproj_src, xcodeproj_dst)
  FileUtils.cp(File.join(project_root, '.generate', 'assets', 'Info.plist'), File.join(destination, name, 'Info.plist'))
  FileUtils.cp_r(File.join(project_root, '.generate', 'assets', 'Assets.xcassets'), File.join(destination, name))
  FileUtils.cp_r(File.join(project_root, '.generate', 'assets', 'Base.lproj'), File.join(destination, name,))
  FileUtils.cp_r(File.join(project_root, '.generate', 'assets', 'Localizations'), File.join(destination, name))
  
  # FileUtils.cp(File.join(project_root, '.generate', 'assets', 'TemplateProject-DevSupport.podspec'), File.join(destination, 'TemplateProject-DevSupport.podspec'))
  FileUtils.cp(File.join(project_root, '.generate', 'assets', 'App.entitlements'), File.join(destination, 'App.entitlements'))

  # TemplateProject.xcscheme is already there
  # unless name.nil?
  #   xcschemes_path = File.join(xcodeproj_dst, 'xcshareddata', 'xcschemes')
  #   FileUtils.cp(File.join(xcschemes_path, 'TemplateProject.xcscheme'),
  #                File.join(xcschemes_path, "#{name}.xcscheme"))
  # end

  # Link source files
  # %w[TemplateProject TemplateProjectTests TemplateProjectUITests].each do |file|
  #   FileUtils.ln_sf(project_path(file, target_platform), destination)
  # end

  # Shared code lives in `ios/TemplateProject/`
  # if target_platform != :ios
  #   source = File.expand_path('TemplateProject', __dir__)
  #   shared_path = File.join(destination, 'Shared')
  #   FileUtils.ln_sf(source, shared_path) unless File.exist?(shared_path)
  # end

  # Note the location of Node so we can use it later in script phases
  node_bin = find_node
  File.write(File.join(project_root, '.xcode.env'), "export NODE_BINARY='#{node_bin}'\n")
  File.write(File.join(destination, '.env'), "export PATH='#{`dirname '#{node_bin}'`.strip!}':$PATH\n")

  react_native = react_native_path(project_root, target_platform)
  rn_version = package_version(react_native.to_s).segments
  rn_version = v(rn_version[0], rn_version[1], rn_version[2])
  version_macro = "REACT_NATIVE_VERSION=#{rn_version}"

  build_settings = {}
  tests_build_settings = {}
  uitests_build_settings = {}

  code_sign_entitlements = platform_config('codeSignEntitlements', project_root, target_platform)
  if code_sign_entitlements.is_a? String
    package_root = File.dirname(find_file('app.json', project_root))
    entitlements = Pathname.new(File.join(package_root, name, code_sign_entitlements))
    build_settings[CODE_SIGN_ENTITLEMENTS] = entitlements.relative_path_from(destination).to_s
  end

  code_sign_identity = platform_config('codeSignIdentity', project_root, target_platform)
  build_settings[CODE_SIGN_IDENTITY] = code_sign_identity if code_sign_identity.is_a? String

  development_team = platform_config('developmentTeam', project_root, target_platform)
  if development_team.is_a? String
    build_settings[DEVELOPMENT_TEAM] = development_team
    tests_build_settings[DEVELOPMENT_TEAM] = development_team
    uitests_build_settings[DEVELOPMENT_TEAM] = development_team
  end

  product_bundle_identifier = platform_config('bundleIdentifier', project_root, target_platform)
  if product_bundle_identifier.is_a? String
    build_settings[PRODUCT_BUNDLE_IDENTIFIER] = product_bundle_identifier
    tests_build_settings[PRODUCT_BUNDLE_IDENTIFIER] = "#{product_bundle_identifier}Tests"
    uitests_build_settings[PRODUCT_BUNDLE_IDENTIFIER] = "#{product_bundle_identifier}UITests"
  end

  override_build_settings!(build_settings, options[:build_setting_overrides])

  build_settings[PRODUCT_DISPLAY_NAME] = display_name
  build_settings[PRODUCT_VERSION] = version || '1.0'

  build_number = platform_config('buildNumber', project_root, target_platform)
  build_settings[PRODUCT_BUILD_NUMBER] = build_number || '1'

  use_new_arch = new_architecture_enabled?(options, rn_version)
  use_bridgeless = bridgeless_enabled?(options, rn_version)
  app_project = Xcodeproj::Project.open(xcodeproj_dst)
  app_project.native_targets.each do |target|
    case target.name
    when 'TemplateProject'
      # In Xcode 15, `unary_function` and `binary_function` are no longer
      # provided in C++17 and newer Standard modes. See Xcode release notes:
      # https://developer.apple.com/documentation/xcode-release-notes/xcode-15-release-notes#Deprecations
      # Upstream issue: https://github.com/facebook/react-native/issues/37748
      enable_cxx17_removed_unary_binary_function =
        (rn_version >= v(0, 72, 0) && rn_version < v(0, 72, 5)) ||
        (rn_version >= v(0, 71, 0) && rn_version < v(0, 71, 4)) ||
        (rn_version.positive? && rn_version < v(0, 70, 14))
      target.build_configurations.each do |config|
        config.build_settings[GCC_PREPROCESSOR_DEFINITIONS] ||= ['$(inherited)']
        config.build_settings[GCC_PREPROCESSOR_DEFINITIONS] << version_macro
        if enable_cxx17_removed_unary_binary_function
          config.build_settings[GCC_PREPROCESSOR_DEFINITIONS] <<
            '_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION=1'
        end
        if use_new_arch
          config.build_settings[GCC_PREPROCESSOR_DEFINITIONS] << 'FOLLY_NO_CONFIG=1'
          config.build_settings[GCC_PREPROCESSOR_DEFINITIONS] << 'RCT_NEW_ARCH_ENABLED=1'
          config.build_settings[GCC_PREPROCESSOR_DEFINITIONS] << 'USE_FABRIC=1'
          if use_bridgeless
            config.build_settings[GCC_PREPROCESSOR_DEFINITIONS] << 'USE_BRIDGELESS=1'
          end
        end

        build_settings.each do |setting, value|
          config.build_settings[setting] = value
        end

        config.build_settings[OTHER_SWIFT_FLAGS] ||= ['$(inherited)']
        config.build_settings[OTHER_SWIFT_FLAGS] << '-DUSE_FABRIC' if use_new_arch
        config.build_settings[OTHER_SWIFT_FLAGS] << '-DUSE_BRIDGELESS' if use_bridgeless
        if single_app.is_a? String
          config.build_settings[OTHER_SWIFT_FLAGS] << '-DENABLE_SINGLE_APP_MODE'
        end

        config.build_settings[USER_HEADER_SEARCH_PATHS] ||= ['$(inherited)']
        config.build_settings[USER_HEADER_SEARCH_PATHS] << File.join(destination, name)
      end
    when 'TemplateProjectTests'
      target.build_configurations.each do |config|
        tests_build_settings.each do |setting, value|
          config.build_settings[setting] = value
        end
      end
    when 'TemplateProjectUITests'
      target.build_configurations.each do |config|
        uitests_build_settings.each do |setting, value|
          config.build_settings[setting] = value
        end
      end
    end
  end
  app_project.save

  config = app_project.build_configurations[0]
  {
    :xcodeproj_path => xcodeproj_dst,
    :platforms => {
      :macos => config.resolve_build_setting(MACOSX_DEPLOYMENT_TARGET),
    },
    :react_native_version => rn_version,
    :use_new_arch => use_new_arch,
    :code_sign_identity => code_sign_identity || '',
    :development_team => development_team || '',
  }
end

def init!(options, &block)
  assert_version(Pod::VERSION)
  target_platform = :macos

  xcodeproj = 'TemplateProject.xcodeproj'
  project_root = Pod::Config.instance.installation_root
  project_target = make_project!(xcodeproj, project_root, target_platform, options)
  xcodeproj_dst, platforms = project_target.values_at(:xcodeproj_path, :platforms)

  if project_target[:use_new_arch] || project_target[:react_native_version] >= v(0, 73, 0)
    install! 'cocoapods', :deterministic_uuids => false
  end

  # As of 0.75, we should use `use_native_modules!` from `react-native` instead
  if project_target[:react_native_version] < v(0, 75, 0)
    require_relative(autolink_script_path(project_root,
                                          target_platform,
                                          project_target[:react_native_version]))
  end

  begin
    platform :osx, platforms[:macos]
  rescue StandardError
    # Allow platform deployment target to be overridden
  end

  project xcodeproj_dst

  react_native_post_install = nil

  target 'TemplateProject' do
    react_native_post_install = __use_react_native!(project_root, target_platform, options)

    pod 'ReactNativeHost', :path => resolve_module_relative('@rnx-kit/react-native-host')

    pod 'TemplateProject-DevSupport', :path => File.join(project_root, '.generate', 'assets', 'TemplateProject-DevSupport.podspec')
    
    if (resources_pod_path = resources_pod(project_root, target_platform, platforms))
      pod 'TemplateProject-Resources', :path => resources_pod_path
    end

    yield TemplateProjectTargets.new(self) if block_given?

    use_native_modules!
  end

  post_install do |installer|
    react_native_post_install&.call(installer)
    options[:post_install]&.call(installer)

    test_dependencies = {}
    %w[TemplateProjectTests TemplateProjectUITests].each do |target|
      definition = target_definitions[target]
      next if definition.nil?

      definition.non_inherited_dependencies.each do |dependency|
        test_dependencies[dependency.name] = dependency
      end
    end

    installer.pods_project.targets.each do |target|
      case target.name
      when /\AReact/, 'RCT-Folly', 'SocketRocket', 'Yoga', 'fmt', 'glog', 'libevent'
        target.build_configurations.each do |config|
          # TODO: Drop `_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION` when
          #       we no longer support 0.72
          config.build_settings[GCC_PREPROCESSOR_DEFINITIONS] ||= ['$(inherited)']
          config.build_settings[GCC_PREPROCESSOR_DEFINITIONS] <<
            '_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION=1'
          config.build_settings[WARNING_CFLAGS] ||= []
          config.build_settings[WARNING_CFLAGS] << '-w'
        end
      when 'RNReanimated'
        # Reanimated tries to automatically install itself by swizzling a method
        # in `RCTAppDelegate`. We don't use it since it doesn't exist on older
        # versions of React Native. Redirect users to the config plugin instead.
        # See https://github.com/microsoft/react-native-test-app/issues/1195 and
        # https://github.com/software-mansion/react-native-reanimated/commit/a8206f383e51251e144cb9fd5293e15d06896df0.
        target.build_configurations.each do |config|
          config.build_settings[GCC_PREPROCESSOR_DEFINITIONS] ||= ['$(inherited)']
          config.build_settings[GCC_PREPROCESSOR_DEFINITIONS] << 'DONT_AUTOINSTALL_REANIMATED'
        end
      else
        # Ensure `ENABLE_TESTING_SEARCH_PATHS` is always set otherwise Xcode may
        # fail to properly import XCTest
        unless test_dependencies.assoc(target.name).nil?
          target.build_configurations.each do |config|
            setting = config.resolve_build_setting(ENABLE_TESTING_SEARCH_PATHS)
            config.build_settings[ENABLE_TESTING_SEARCH_PATHS] = 'YES' if setting.nil?
          end
        end
      end

      next unless target_product_type(target) == 'com.apple.product-type.bundle'

      # Code signing of resource bundles was enabled in Xcode 14. Not sure if
      # this is intentional, or if there's a bug in CocoaPods, but Xcode will
      # fail to build when targeting devices. Until this is resolved, we'll just
      # just have to make sure it's consistent with what's set in `app.json`.
      # See also https://github.com/CocoaPods/CocoaPods/issues/11402.
      target.build_configurations.each do |config|
        config.build_settings[CODE_SIGN_IDENTITY] ||= project_target[:code_sign_identity]
        config.build_settings[DEVELOPMENT_TEAM] ||= project_target[:development_team]
      end
    end

    apply_config_plugins(project_root, target_platform)

    Pod::UI.notice(
      "`#{xcodeproj}` was sourced from `react-native-test-app`. " \
      'All modifications will be overwritten next time you run `pod install`.'
    )
  end
end

class TemplateProjectTargets
  def initialize(podfile)
    @podfile = podfile
  end

  def app
    yield if block_given?
  end

  def tests
    @podfile.target 'TemplateProjectTests' do
      @podfile.inherit! :complete
      yield if block_given?
    end
  end

  def ui_tests
    @podfile.target 'TemplateProjectUITests' do
      @podfile.inherit! :complete
      yield if block_given?
    end
  end
end

class Remover
  def initialize(tmpfile)
    @pid = Process.pid
    @tmpfile = tmpfile
  end

  def call(*_args)
    return if @pid != Process.pid

    @tmpfile.close
    FileUtils.rm_rf(@tmpfile.path)
  end
end