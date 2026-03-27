require 'json'
require 'open-uri'
require 'digest'
require 'fileutils'
require 'net/http'

CONFIG_FILE = 'upstream_sources.json'

unless File.exist?(CONFIG_FILE)
  puts "No configuration file (#{CONFIG_FILE}) found. Skipping update check."
  exit 0
end

sources = JSON.parse(File.read(CONFIG_FILE))
any_updates = false

# Helper to detect Repo URLs and find the actual download link
def resolve_download_url(source_url)
  # Regex: Matches "https://github.com/User/Repo" (root only, no /blob/, /raw/, etc.)
  if source_url =~ %r{^https?://github\.com/([^/]+)/([^/]+)(?:\.git)?/?$}
    owner, repo = $1, $2
    puts "\n   -> Detected GitHub Repository: #{owner}/#{repo}"
    
    api_url = "https://api.github.com/repos/#{owner}/#{repo}/releases/latest"
    uri = URI(api_url)
    
    req = Net::HTTP::Get.new(uri)
    req['User-Agent'] = 'FontBuildScript/1.0'
    
    # Use GITHUB_TOKEN if present (helps avoid rate limits in CI)
    if ENV['GITHUB_TOKEN']
      req['Authorization'] = "token #{ENV['GITHUB_TOKEN']}"
    end

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    if res.is_a?(Net::HTTPSuccess)
      data = JSON.parse(res.body)
      
      # Find the first asset that looks like a font file
      asset = data['assets'].find { |a| a['name'] =~ /\.(ttf|otf|ttc)$/i }
      
      if asset
        puts "   -> Resolved to Latest Release Asset: #{asset['name']}"
        return asset['browser_download_url']
      else
        puts "   !! Warning: No .ttf/.otf/.ttc asset found in latest release. Trying raw repo..."
      end
    else
      puts "   !! Warning: Could not check releases (HTTP #{res.code}). Using raw URL."
    end
  end
  
  # Return original URL if it wasn't a repo or if lookup failed
  return source_url
end

sources.each do |local_path, url|
  print "Checking #{local_path} ... "
  
  # 1. Resolve the URL (Handle GitHub Releases vs Direct Links)
  final_url = resolve_download_url(url)

  # Ensure the destination directory exists
  FileUtils.mkdir_p(File.dirname(local_path))

  begin
    # 2. Download the remote file into memory
    # URI.open handles the redirects from GitHub automatically
    remote_data = URI.open(final_url).read
    remote_hash = Digest::SHA256.hexdigest(remote_data)

    if File.exist?(local_path)
      local_data = File.read(local_path)
      local_hash = Digest::SHA256.hexdigest(local_data)
    else
      local_hash = nil
    end

    if local_hash != remote_hash
      puts "UPDATE FOUND"
      puts "   - Local SHA:  #{local_hash || 'Not found'}"
      puts "   - Remote SHA: #{remote_hash}"
      
      File.open(local_path, 'wb') { |f| f.write(remote_data) }
      any_updates = true
    else
      puts "Up to date."
    end
    
  rescue StandardError => e
    puts "ERROR"
    puts "   Failed to fetch #{final_url}: #{e.message}"
    exit 1 
  end
end