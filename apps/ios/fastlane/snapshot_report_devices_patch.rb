module Snapshot
  class ReportsGenerator
    unless method_defined?(:available_devices_without_dynamic_names)
      alias_method :available_devices_without_dynamic_names, :available_devices
    end

    def available_devices
      base = available_devices_without_dynamic_names
      dynamic = dynamic_device_name_mappings
      base.merge(dynamic)
    end

    private

    def dynamic_device_name_mappings
      output_dir = Snapshot.config[:output_directory]
      return {} if output_dir.to_s.empty?

      names = Dir[File.join(output_dir, "*", "*.png")]
        .map { |path| File.basename(path, ".png") }
        .map { |name| name.split("-", 2).first }
        .map(&:strip)
        .reject(&:empty?)
        .uniq
        .sort_by { |name| -name.length }

      names.each_with_object({}) do |name, mappings|
        mappings[name] = name
      end
    end
  end
end
