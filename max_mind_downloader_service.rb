require 'uri'
require 'fileutils'
require_relative 'shared_utils'

class MaxMindDownloaderService
  MAXMIND_DOWNLOAD_URL = 'https://download.maxmind.com/app/geoip_download'
  EDITION_ID = 'GeoLite2-Country'

  def initialize(license_key:, account_id: nil, logger:)
    @license_key = license_key
    @account_id = account_id
    @logger = logger
  end

  def download_and_extract(tar_path, extract_dir, output_mmdb_path)
    if @license_key.to_s.empty?
      return { success: false, error: 'MAXMIND_LICENSE_KEY is not configured.' }
    end

    download_url = build_download_url
    @logger.info("Downloading latest file from MaxMind: #{download_url.to_s.gsub(@license_key, '***')}")

    http = HttpClientService.new(logger: @logger)
    result = http.download_with_redirects(
      download_url.to_s,
      tar_path,
      @account_id.to_s.empty? ? nil : @account_id,
      @license_key
    )
    unless result[:success]
      return { success: false, error: result[:error] }
    end

    @logger.info('MaxMind tar.gz download completed.')

    extractor = TarExtractorService.new(logger: @logger)
    extract_result = extractor.extract_mmdb_to_file(tar_path, extract_dir, output_mmdb_path)
    unless extract_result[:success]
      return { success: false, error: extract_result[:error] }
    end

    unless SharedUtils.file_valid?(output_mmdb_path)
      return { success: false, error: 'Extracted .mmdb file is invalid or too small' }
    end

    { success: true, file_path: output_mmdb_path }
  rescue StandardError => e
    @logger.error("MaxMind download failed: #{e.message}")
    { success: false, error: "MaxMind download error: #{e.message}" }
  end

  private

  def build_download_url
    params = {
      'edition_id' => EDITION_ID,
      'license_key' => @license_key,
      'suffix' => 'tar.gz'
    }
    params['account_id'] = @account_id if @account_id.to_s != ''
    query = URI.encode_www_form(params)
    URI("#{MAXMIND_DOWNLOAD_URL}?#{query}")
  end
end
