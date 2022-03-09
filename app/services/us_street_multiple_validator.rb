# frozen_string_literal: true

class UsStreetMultipleValidator
  include SmartyStreets::USStreet::MatchType

  def build_credentials
    Rails.logger.info "#{self.class} - Creating static credentials"

    if auth_id.nil? || auth_token.nil?
      err = 'Could not find auth ID or auth token'
      Rails.logger.error err
      raise 'Could not find auth ID or auth token'
    end

    credentials = SmartyStreets::StaticCredentials.new(auth_id, auth_token)

    Rails.logger.info "#{self.class} - Static credentials created"

    credentials
  end

  def run(addresses)
    credentials = build_credentials

    # The appropriate license values to be used for your subscriptions
    # can be found on the Subscriptions page of the account dashboard.
    # https://www.smartystreets.com/docs/cloud/licensing
    client = SmartyStreets::ClientBuilder.new(credentials).with_licenses(licences)
                                                          .build_us_street_api_client

    batch = SmartyStreets::Batch.new

    # Documentation for input fields can be found at:
    # https://smartystreets.com/docs/cloud/us-street-api

    batch.add(SmartyStreets::USStreet::Lookup.new)
    batch[0].input_id = '8675309'  # Optional ID from your system
    batch[0].addressee = 'John Doe'
    batch[0].street = '1600 amphitheatre parkway'
    batch[0].street2 = 'second star to the right'
    batch[0].secondary = 'APT 2'
    batch[0].urbanization = ''  # Only applies to Puerto Rico addresses
    batch[0].lastline = 'Mountain view, California'
    batch[0].zipcode = '21229'
    batch[0].candidates = 3
    batch[0].match = INVALID # "invalid" is the most permissive match,
                                      # this will always return at least one result even if the address is invalid.
                                      # Refer to the documentation for additional Match Strategy options.

    batch.add(SmartyStreets::USStreet::Lookup.new('1 Rosedale, Baltimore, Maryland')) # Freeform addresses work too.
    batch[1].candidates = 10 # Allows up to ten possible matches to be returned (default is 1).

    batch.add(SmartyStreets::USStreet::Lookup.new('123 Bogus Street, Pretend Lake, Oklahoma'))

    batch.add(SmartyStreets::USStreet::Lookup.new)
    batch[3].street = '1 Infinite Loop'
    batch[3].zipcode = '95014' # You can just input the street and ZIP if you want.

    begin
      client.send_batch(batch)
    rescue SmartyStreets::SmartyError => err
      Rails.logger.error err
      return
    end

    batch.each_with_index do |lookup, i|
      candidates = lookup.result

      if candidates.empty?
        puts "Address #{i} is invalid.\n\n"
        next
      end

      puts "Address #{i} is valid. (There is at least one candidate)"

      candidates.each do |candidate|
        components = candidate.components
        metadata = candidate.metadata

        puts "\nCandidate #{candidate.candidate_index} : "
        puts "Input ID: #{candidate.input_id}"
        puts "Delivery line 1: #{candidate.delivery_line_1}"
        puts "Last line:       #{candidate.last_line}"
        puts "ZIP Code:        #{components.zipcode}-#{components.plus4_code}"
        puts "County:          #{metadata.county_name}"
        puts "Latitude:        #{metadata.latitude}"
        puts "Longitude:       #{metadata.longitude}"
        puts
      end
    end
  end

  private

  def auth_id
    ENV['smarty_streets_auth_id']
  end

  def auth_token
    ENV['smarty_streets_auth_token']
  end

  def licences
    [ENV['smarty_streets_licences']]
  end
end