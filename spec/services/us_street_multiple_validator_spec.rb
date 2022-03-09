# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsStreetMultipleValidator do
  subject { described_class.new }

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

  describe '#run' do
    it 'runs' do
      subject.run([])
    end
  end
end