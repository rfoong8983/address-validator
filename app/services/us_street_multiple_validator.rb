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

  def transform_result(requested_addresses, invalid_addresses)
    results = []
    invalid_addresses.each do |address|
      results.push(address.merge(valid: false, additional_info: 'Address was missing a required field'))
    end

    requested_addresses.each do |address|
      components = address['components']
      metadata = address['metadata']
      analysis = address['analysis']
      dpv_match_code = analysis['dpv_match_code']

      result = { address_line_one: address['delivery_line_1'],
                 city: components['city_name'],
                 state: components['state_abbreviation'],
                 zip_code: components['zipcode'],
                 latitude: metadata['latitude'],
                 longitude: metadata['longitude'],
                 valid: dpv_match_code == 'Y' ? true : false,
                 additional_info: get_match_info(dpv_match_code) }

      results.push(result)
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
      result = client.send_batch(batch)
      @api_request.complete!

      log_info 'Successfully sent batch address validation request'
    rescue SmartyStreets::SmartyError => err
      log_error err
      @api_request.fail!
      raise err
    end

    transform_result(result, invalid_addresses)
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

  def log_warning(message)
    Rails.logger.warn "#{self.class} - #{message}"
  end

  def log_error(message)
    Rails.logger.error "#{self.class} - #{message}"
  end

  def get_match_info(dpv_match_code)
    info = {
      'Y' => 'Confirmed; entire address is present in the USPS data.',
      'N' => 'Not confirmed; address is not present in the USPS data.',
      'S' => 'Confirmed by ignoring secondary info; the main address is present in the USPS data, but the submitted secondary information (apartment, suite, etc.) was not recognized.',
      'D' => 'Confirmed but missing secondary info; the main address is present in the USPS data, but it is missing secondary information (apartment, suite, etc.).'
    }

    info[dpv_match_code]
  end
end