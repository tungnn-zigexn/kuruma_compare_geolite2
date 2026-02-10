require 'zlib'
require 'fileutils'
require 'minitar'

class TarExtractorService
  TAR_FILE_REGEX = %r{\A[\w\-/.]+\.tar\.gz\z}

  def initialize(logger:)
    @logger = logger
  end

  def extract_mmdb_to_file(tar_file_path, extract_dir, output_path)
    unless tar_file_path.to_s.match?(TAR_FILE_REGEX)
      return { success: false, error: 'Invalid tar file path' }
    end

    FileUtils.mkdir_p(extract_dir)
    Zlib::GzipReader.open(tar_file_path) do |gzip_stream|
      Minitar.unpack(gzip_stream, extract_dir)
    end

    mmdb_path = Dir.glob(File.join(extract_dir, '**', '*.mmdb')).first
    unless mmdb_path && File.file?(mmdb_path)
      return { success: false, error: 'No .mmdb file found in archive' }
    end

    @logger.info("Found .mmdb file: #{mmdb_path}. Copying to #{output_path}")
    FileUtils.mkdir_p(File.dirname(output_path))
    FileUtils.cp(mmdb_path, output_path)
    { success: true }
  rescue Zlib::GzipFile::Error => e
    @logger.error("Extraction failed due to corrupted gzip file: #{e.message}")
    { success: false, error: "Extraction failed: Corrupted tar.gz file - #{e.message}" }
  rescue StandardError => e
    @logger.error("Extraction failed: #{e.message}")
    { success: false, error: "Extraction failed: #{e.message}" }
  end
end
