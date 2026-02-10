require 'fileutils'
require 'google/cloud/storage'
require_relative 'shared_utils'

class GcsBaselineDownloader
  def initialize(bucket:, object:, project_id: nil, logger:)
    @bucket_name = bucket
    @object_name = object
    @project_id = project_id
    @logger = logger
  end

  def download_to(output_path)
    SharedUtils.ensure_directory_exists!(output_path)
    @logger.info("Downloading baseline file from GCS: gs://#{@bucket_name}/#{@object_name} -> #{output_path}")
    storage = Google::Cloud::Storage.new(project_id: @project_id)
    bucket = storage.bucket @bucket_name
    file = bucket.file @object_name
    file.download output_path
    unless SharedUtils.file_valid?(output_path)
      @logger.error('Invalid baseline file or size too small')
      return false
    end
    @logger.info('GCS baseline download completed.')
    true
  rescue StandardError => e
    @logger.error("Failed to download baseline file from GCS: #{e.message}")
    false
  end
end
