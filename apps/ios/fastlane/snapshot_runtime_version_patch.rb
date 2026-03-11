require "json"
require "open3"

module FastlaneCore
  class DeviceManager
    class << self
      unless method_defined?(:simulators_without_runtime_version_fix)
        alias_method :simulators_without_runtime_version_fix, :simulators
      end

      def simulators(requested_os_type = "")
        devices = simulators_without_runtime_version_fix(requested_os_type)
        runtime_name_to_version = runtime_name_to_version_map

        devices.each do |device|
          next if device.os_type.to_s.empty? || device.os_version.to_s.empty?

          runtime_name = "#{device.os_type} #{device.os_version}"
          actual_version = runtime_name_to_version[runtime_name]
          next if actual_version.to_s.empty?

          device.os_version = actual_version
          device.ios_version = actual_version if device.respond_to?(:ios_version=)
        end

        devices
      end

      private

      def runtime_name_to_version_map
        @runtime_name_to_version_map ||= begin
          output, status = Open3.capture2("xcrun simctl list -j runtimes")
          if status.success?
            json = JSON.parse(output)
            runtimes = json.fetch("runtimes", [])
            runtimes.each_with_object({}) do |runtime, map|
              name = runtime["name"]
              version = runtime["version"]
              next if name.to_s.empty? || version.to_s.empty?
              map[name] = version
            end
          else
            {}
          end
        rescue StandardError
          {}
        end
      end
    end
  end
end
