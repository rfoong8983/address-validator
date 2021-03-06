# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsStreetMultipleValidator do
  let(:api_request) { create :api_request }

  subject { described_class.new(api_request) }

  describe '#build_credentials' do
    let(:err) { 'Could not find auth ID or auth token' }

    context 'when auth id is missing' do
      it 'logs a message and raises an error' do
        stub_const('ENV', {'smarty_streets_auth_id' => nil})
        expect(Rails.logger).to receive(:error)
        expect { subject.build_credentials }.to raise_error(err)
      end
    end

    context 'when auth key is missing' do
      it 'logs a message and raises an error' do
        stub_const('ENV', {'smarty_streets_auth_token' => nil})
        expect(Rails.logger).to receive(:error)
        expect { subject.build_credentials }.to raise_error(err)
      end
    end

    it 'returns a credentials object' do
      stub_const('ENV', {'smarty_streets_auth_id' => 'foo',
                         'smarty_streets_auth_token' => 'bar'})

      expect(subject.build_credentials).to be_a(SmartyStreets::StaticCredentials)
    end
  end

  describe '#valid_address?' do
    context 'when address is fully populated' do
      let(:valid_address) { { address_line_one: 'foo', city: 'foo', state: 'BA', zip_code: '91210' } }

      it 'returns true' do
        expect(subject.valid_address?(valid_address)).to eql(true)
      end
    end

    context 'when address_line_one is missing' do
      let(:empty_address_line_one) { { address_line_one: '', city: 'foo', state: 'BA', zip_code: '91210' } }
      let(:nil_address_line_one) { { city: 'foo', state: 'BA', zip_code: '91210' } }

      it 'returns false' do
        expect(subject.valid_address?(empty_address_line_one)).to eql(false)
        expect(subject.valid_address?(nil_address_line_one)).to eql(false)
      end
    end

    context 'when city is missing' do
      let(:empty_city) { { address_line_one: 'foo', city: '', state: 'BA', zip_code: '91210' } }
      let(:nil_city) { { address_line_one: 'foo', state: 'BA', zip_code: '91210' } }

      it 'returns false' do
        expect(subject.valid_address?(empty_city)).to eql(false)
        expect(subject.valid_address?(nil_city)).to eql(false)
      end
    end

    context 'when state is missing' do
      let(:empty_state) { { address_line_one: 'foo', city: 'foo', state: '', zip_code: '91210' } }
      let(:nil_state) { { address_line_one: 'foo', city: 'foo', zip_code: '91210' } }

      it 'returns false' do
        expect(subject.valid_address?(empty_state)).to eql(false)
        expect(subject.valid_address?(nil_state)).to eql(false)
      end
    end

    context 'when zip is missing' do
      let(:empty_zip) { { address_line_one: 'foo', city: 'foo', state: 'BA', zip_code: '' } }
      let(:nil_zip) { { address_line_one: 'foo', city: 'foo', state: 'BA' } }

      it 'returns false' do
        expect(subject.valid_address?(empty_zip)).to eql(false)
        expect(subject.valid_address?(nil_zip)).to eql(false)
      end
    end
  end

  describe '#validate_addresses' do
    let(:addresses) do
      [
        { },
        { address_line_one: 'foo1', city: 'foo', state: 'BA', zip_code: '91210' },
        { },
        { address_line_one: 'foo3', city: 'foo', state: 'BA', zip_code: '91210' },
        { address_line_one: 'foo4', city: 'foo', state: 'BA', zip_code: '91210' }
      ]
    end
    let(:expected_result) do
      {
        valid: [addresses[1], addresses[3], addresses[4]],
        invalid: [addresses[0], addresses[2]]
      }
    end

    it 'returns separates valid from invalid addresses' do
      expect(subject.validate_addresses(addresses)).to eql(expected_result)
    end
  end

  describe '#build_batch' do
    let(:valid_addresses) do
      [
        { address_line_one: 'foo', city: 'foo', state: 'BA', zip_code: '91210' },
        { address_line_one: 'foo1', city: 'foo', state: 'BA', zip_code: '91210' },
        { address_line_one: 'foo2', city: 'foo', state: 'BA', zip_code: '91210' },
        { address_line_one: 'foo3', city: 'foo', state: 'BA', zip_code: '91210' },
        { address_line_one: 'foo4', city: 'foo', state: 'BA', zip_code: '91210' }
      ]
    end

    it 'should call #add_to_batch for each address' do
      expect(subject).to receive(:add_to_batch).exactly(5).times.and_call_original
      subject.build_batch(valid_addresses)
    end
  end

  describe '#add_to_batch' do
    let(:batch) { SmartyStreets::Batch.new }
    let(:batch_item_number) { 0 }
    let(:address) { { address_line_one: 'foo', city: 'foo', state: 'BA', zip_code: '91210' } }

    it 'adds an address to the batch' do
      subject.add_to_batch(batch, batch_item_number, address)
      expect(batch[batch_item_number].street).to eql(address[:address_line_one])
      expect(batch[batch_item_number].city).to eql(address[:city])
      expect(batch[batch_item_number].state).to eql(address[:state])
      expect(batch[batch_item_number].zipcode).to eql(address[:zip_code])
      expect(batch[batch_item_number].match).to eql('strict')
    end
  end

  describe '#transform_results' do
    let(:populated_result) do
      [
        OpenStruct.new(metadata: OpenStruct.new(latitude: 30.0, longitude: 30.0),
                       analysis: OpenStruct.new(dpv_match_code: 'Y'))
      ]
    end
    let(:requested_addresses) do
      [
        OpenStruct.new(street: '225 Judah Street',
                       city: 'San Francisco',
                       state: 'CA',
                       zipcode: '94122',
                       result: populated_result),
        OpenStruct.new(street: 'foo3',
                       city: 'foo',
                       state: 'BA',
                       zipcode: '91210',
                       result: [])
      ]
    end
    let(:batch) { SmartyStreets::Batch.new }
    let(:invalid_addresses) { [{ }] }
    let(:invalid_address_info) { 'Address was missing a required field' }
    let(:expected_result) do
      [
        { valid: false, additional_info: invalid_address_info },
        { 
          address_line_one: '225 Judah Street',
          city: 'San Francisco',
          state: 'CA',
          zip_code: '94122',
          latitude: 30.0,
          longitude: 30.0,
          valid: true,
          additional_info: 'Confirmed; entire address is present in the USPS data.'
        },
        { 
          address_line_one: 'foo3',
          city: 'foo',
          state: 'BA',
          zip_code: '91210',
          valid: false,
          additional_info: 'API returned no result for this address'
        }
      ]
    end

    before do
      batch.instance_variable_set(:@all_lookups, requested_addresses)
    end

    it 'adds a "valid" key and "additional" info key for all addresses and latitude/longitude for requested addresses' do
      expect(subject.transform_result(batch, requested_addresses, invalid_addresses)).to eql(expected_result)
    end
  end

  describe '#get_cache_key_for' do
    let(:all_lookups) do
      [
        OpenStruct.new(street: '225 Judah Street',
                       city: 'San Francisco',
                       state: 'CA',
                       zipcode: '94122'),
        OpenStruct.new(street: 'foo3',
                       city: 'foo',
                       state: 'BA',
                       zipcode: '91210')
      ]
    end
    let(:expectd_cache_key) { '225 judah street, san francisco, ca, 94122|foo3, foo, ba, 91210' }

    it 'joins address parts separated by ", ", joins the addresses separated by "|", and lowercases string' do
      expect(subject.get_cache_key_for(all_lookups)).to eql(expectd_cache_key)
    end
  end
end