require 'fileutils'

module SharedUtils
  MIN_VALID_SIZE = 1024 * 1024

  def self.file_valid?(path)
    return false unless File.exist?(path)
    return false if File.zero?(path)

    File.size(path) >= MIN_VALID_SIZE
  end

  def self.ensure_directory_exists!(file_path)
    dir = File.dirname(file_path)
    FileUtils.mkdir_p(dir) if dir != '.' && !Dir.exist?(dir)
  end
end
