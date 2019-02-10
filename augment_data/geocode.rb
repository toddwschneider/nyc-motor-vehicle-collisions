require 'bundler/setup'
Bundler.require

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: 'localhost',
  database: 'nyc-motor-vehicle-collisions'
)

class Geocoding < ActiveRecord::Base
  API_BASE_URL = 'https://maps.googleapis.com/maps/api/geocode/json'
  API_KEY = Hash[*ARGV]['--google-api-key']
  NYC_BOUNDS = '40.4,-74.3|41.0,-73.65'

  def geocode!
    raise 'no api key' if API_KEY.blank?

    begin
      request = RestClient.get(API_BASE_URL, params: {
        address: address_for_geocode,
        bounds: NYC_BOUNDS,
        key: API_KEY
      })
    rescue RestClient::BadRequest
      puts "Bad request for #{id}"
      return
    end

    json = JSON.parse(request.body)
    result = json.dig('results', 0)

    if result && (result['types'] & acceptable_google_types).present?
      self.latitude = result.dig('geometry', 'location', 'lat')
      self.longitude = result.dig('geometry', 'location', 'lng')
    end

    self.full_response = json

    save!
  end
end

class IntersectionGeocoding < Geocoding
  scope :for_geocoding, -> { where(full_response: nil) }

  def address_for_geocode
    raise "#{id} missing on_street_name" if on_street_name.blank?
    raise "#{id} missing cross_street_name" if cross_street_name.blank?

    [
      "#{on_street_name} and #{cross_street_name}",
      reported_borough,
      'nyc'
    ].compact.join(', ').downcase
  end

  def acceptable_google_types
    %w(intersection)
  end
end

class StreetAddressGeocoding < Geocoding
  scope :for_geocoding, -> {
    where("
      full_response IS NULL
      AND off_street_name NOT LIKE '%parking lot%'
      AND off_street_name NOT LIKE '%p/l%'
      AND off_street_name NOT LIKE '%pl of%'
      AND off_street_name NOT LIKE '%muni lot%'
      AND off_street_name NOT LIKE '%driveway%'
      AND NOT (
        off_street_name ~* '^\\d+ east drive' AND reported_borough IS NULL
      )
      AND off_street_name ~* '\\d'
    ")
  }

  def address_for_geocode
    raise "#{id} missing off_street_name" if off_street_name.blank?

    [
      off_street_name.squish,
      reported_borough,
      'nyc'
    ].compact.join(', ').downcase
  end

  def acceptable_google_types
    %w(street_address premise)
  end
end

def run
  if Geocoding::API_KEY.blank?
    puts [
      'You have to specify a Google Maps Geocoding API key',
      'Usage:',
      '  ruby geocode.rb --google-api-key YOUR_API_KEY_HERE'
    ].join("\n\n")

    return
  end

  [IntersectionGeocoding, StreetAddressGeocoding].each do |klass|
    scope = klass.for_geocoding
    puts "#{Time.now}: going to geocode #{scope.count} #{klass.name} addresses"

    scope.find_each.with_index do |g, i|
      puts "#{Time.now}: done #{i} addresses" if i > 0 && i % 50 == 0
      g.geocode!
    end

    puts "#{Time.now}: finished #{klass.name}"
  end
end

run
