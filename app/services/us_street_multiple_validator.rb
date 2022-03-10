# frozen_string_literal: true

class UsStreetMultipleValidator
  include SmartyStreets::USStreet::MatchType

  def initialize(api_request)
    @api_request = api_request
  end

  def build_credentials
    log_info 'Creating static credentials'

    if auth_id.nil? || auth_token.nil?
      err = 'Could not find auth ID or auth token'
      log_error err
      raise err
    end

    credentials = SmartyStreets::StaticCredentials.new(auth_id, auth_token)

    log_info 'Static credentials created'

    credentials
  end

  def valid_address?(address)
    address[:address_line_one].present? && \
      address[:city].present? && \
      address[:state].present? && \
      address[:zip_code].present?
  end

  def validate_addresses(addresses)
    valid_addresses = []
    invalid_addresses = []

    addresses.each do |address|
      valid_addresses << address if valid_address?(address)
      invalid_addresses << address if !valid_address?(address)
    end

    {
      valid: valid_addresses,
      invalid: invalid_addresses
    }
  end

  def add_to_batch(batch, batch_item_number, address)
    log_info "Adding address #{batch_item_number} to batch"
    # Documentation for input fields can be found at:
    # https://smartystreets.com/docs/cloud/us-street-api
    batch.add(SmartyStreets::USStreet::Lookup.new)
    batch[batch_item_number].street = address[:address_line_one]
    batch[batch_item_number].city = address[:city]
    batch[batch_item_number].state = address[:state]
    batch[batch_item_number].zipcode = address[:zip_code]
    batch[batch_item_number].match = STRICT

    log_info "Finished adding address #{batch_item_number} to batch"

    batch
  end

  def build_batch(addresses)
    batch = SmartyStreets::Batch.new

    addresses.each_with_index do |address, index|
      add_to_batch(batch, index, address)
    end

    batch
  end

  def transform_result(batch, invalid_addresses)
    results = []
    # Process addresses received in request with missing fields, not sent to API
    invalid_addresses.each do |address|
      results.push(address.merge(valid: false, additional_info: 'Address was missing a required field'))
    end

    batch.each do |lookup|
      address = { address_line_one: lookup.street,
                 city: lookup.city,
                 state: lookup.state,
                 zip_code: lookup.zipcode }

      result = lookup.result.first
      if result.present?
        # Process address requested in API with match
        metadata = result&.metadata
        analysis = result&.analysis
        dpv_match_code = analysis&.dpv_match_code
        latitude = metadata&.latitude
        longitude = metadata&.longitude

        if dpv_match_code.blank? || latitude.blank? || longitude.blank?
          log_warn "Match code, latitude, or longitude missing from api request: #{api_request.reference_uuid}"
        end

        address = address.merge(latitude: latitude,
                                longitude: longitude,
                                valid: dpv_match_code == 'Y' ? true : false,
                                additional_info: get_match_info(dpv_match_code))
      else
        # Process address requested in API with no result
        address = address.merge(valid: false, additional_info: 'API returned no result for this address')
      end

      results.push(address)
    end

    results
  end

  def run(addresses)
    credentials = build_credentials

    # The appropriate license values to be used for your subscriptions
    # can be found on the Subscriptions page of the account dashboard.
    # https://www.smartystreets.com/docs/cloud/licensing
    client = SmartyStreets::ClientBuilder.new(credentials).with_licenses(licences)
                                                          .build_us_street_api_client

    validated = validate_addresses(addresses)
    valid_addresses = validated[:valid]
    invalid_addresses = validated[:invalid]

    batch = build_batch(valid_addresses)

    begin
      log_info 'Sending batch address validation request'

      @api_request.start!

      client.send_batch(batch)

      @api_request.complete!

      log_info 'Successfully sent batch address validation request'
    rescue SmartyStreets::SmartyError => err
      log_error err
      @api_request.fail!
      raise err
    end

    transform_result(batch, invalid_addresses)
  end

  def get_match_info(dpv_match_code)
    info = {
      'Y' => 'Confirmed; entire address is present in the USPS data.',
      'N' => 'Not confirmed; address is not present in the USPS data.',
      'S' => 'Confirmed by ignoring secondary info; the main address is present in the USPS data, but the submitted secondary information (apartment, suite, etc.) was not recognized.',
      'D' => 'Confirmed but missing secondary info; the main address is present in the USPS data, but it is missing secondary information (apartment, suite, etc.).'
    }

    additional_info = info[dpv_match_code]

    if !additional_info
      "No match info for dpv_match_code: #{dpv_match_code}"
    else
      additional_info
    end
  end

  def get_cache_key_for(all_lookups)
    key = ''

    all_lookups.each_with_index do |lookup, index|
      address_str = [lookup.street.to_s, lookup.city.to_s, lookup.state.to_s, lookup.zipcode.to_s].join(', ')
      address_str += '|' if index != all_lookups.length - 1
      key += address_str.downcase
    end

    key
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

  def log_info(message)
    Rails.logger.info "#{self.class} - #{message}"
  end

  def log_warn(message)
    Rails.logger.warn "#{self.class} - #{message}"
  end

  def log_error(message)
    Rails.logger.error "#{self.class} - #{message}"
  end
end