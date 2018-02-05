require 'rest-client'
require 'scraperwiki'
require 'json'
require 'net/http'

def archived_search_url(timestring)
  "https://web.archive.org/web/#{timestring}/https://tenders.nsw.gov.au/?event=public.api.contract.search"
end

def web_archive(url)
  archive_request_response = RestClient.get("https://web.archive.org/save/#{url}")
  archive_request_response.headers[:link].split(", ")[2][/\<.*\>/].gsub(/<|>/, "")
end

timemap = JSON.parse(
  Net::HTTP.get(
    URI("https://web.archive.org/web/timemap/json/http://tenders.nsw.gov.au/?event=public.api.contract.search")
  )
)
archive_times = timemap[1..-1].map { |t| t[1] }

# FOR EACH IN THE TIMEMAP
archive_times.each do |archive_timestamp|
  return if (ScraperWiki.select("archive_timestamp from data where archive_timestamp='#{archive_timestamp}'").empty? rescue false)
  puts "Getting archived search data from #{archived_search_url(archive_timestamp)}"
  archived_search_data = JSON.parse(
    Net::HTTP.get(URI(archived_search_url(archive_timestamp)))
  )

  archived_search_data["releases"].each do |release|
    release["awards"].each do |award|
      url = "https://tenders.nsw.gov.au/?event=public.api.contract.view&CNUUID=#{award["CNUUID"]}"

      puts "Getting contract data from #{url}"

      record = {
        scraped_at: Date.today.to_s,
        web_archive_url: web_archive(url),
        CNUUID: award["CNUUID"],
        ocid: release["ocid"],
        data_blob: Net::HTTP.get(URI(url)),
        archive_timestamp: archive_timestamp
      }

      puts "Saving contract data from #{url}"
      ScraperWiki.save_sqlite([:CNUUID, :archive_timestamp], record)

      sleep 3
    end
  end
end
