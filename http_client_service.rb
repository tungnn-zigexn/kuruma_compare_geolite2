require 'net/http'
require 'uri'
require 'fileutils'
require_relative 'shared_utils'

class HttpClientService
  MAX_REDIRECTS = 5
  USER_AGENT = 'Ruby/MaxMind-Downloader'.freeze
  OPEN_TIMEOUT = 30
  READ_TIMEOUT = 300

  def initialize(logger:)
    @logger = logger
  end

  def download_with_redirects(download_url, output_path, account_id = nil, license_key = nil)
    uri = URI(download_url)
    redirect_count = 0

    while redirect_count <= MAX_REDIRECTS
      begin
        result = nil
        execute_request(uri, redirect_count.zero?, account_id, license_key) do |response|
          case response.code.to_i
          when 200
            result = save_file_streamed(response, output_path)
          when 301, 302, 303, 307, 308
            location = response['location']
            if location
              uri = URI.join(uri, location)
              redirect_count += 1
              result = :redirect
            else
              result = error('Redirect without location header')
            end
          else
            result = error("HTTP #{response.code}: #{response.message}")
          end
        end

        return result unless result == :redirect
      rescue StandardError => e
        return error("Request failed: #{e.message}")
      end
    end

    error("Too many redirects (#{redirect_count})")
  end

  private

  def execute_request(uri, use_auth, account_id, license_key, &block)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Get.new(uri.request_uri)
    request['User-Agent'] = USER_AGENT
    request.basic_auth(account_id, license_key) if use_auth && account_id.to_s != '' && license_key.to_s != ''

    http.request(request, &block)
  end

  def save_file_streamed(response, output_path)
    SharedUtils.ensure_directory_exists!(output_path)
    temp_path = "#{output_path}.tmp"

    begin
      File.open(temp_path, 'wb') do |file|
        response.read_body do |chunk|
          file.write(chunk)
        end
      end

      if File.exist?(temp_path) && File.size(temp_path).positive?
        File.rename(temp_path, output_path)
        { success: true }
      else
        FileUtils.rm_f(temp_path)
        error('Downloaded file is empty or missing')
      end
    rescue StandardError => e
      FileUtils.rm_f(temp_path) if File.exist?(temp_path)
      error("File save failed: #{e.message}")
    end
  end

  def error(message)
    { success: false, error: message }
  end
end
