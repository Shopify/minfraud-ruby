require 'spec_helper'
require 'webmock/rspec'

describe Minfraud::MinfraudClient do
  subject(:minfraud_client) { Minfraud::MinfraudClient.new }
  subject(:minfraud_client_east) { Minfraud::MinfraudClient.new(host_choice: 'us_east') }
  let(:transaction) {
    Minfraud::Transaction.new do |t|
      t.ip = '127.0.0.1'
      t.txn_id = 'Order-1-1'
      t.license_key = 'test_license'
    end
  }
  let(:success_response) { double(Minfraud::Response, body: '') }

  describe 'Minfraud::MinfraudClient.new' do
    it 'creates a new Faraday Connection' do
      expect(minfraud_client.instance_variable_get(:@http_client)).to be_instance_of(Faraday::Connection)
    end
  end

  describe 'Minfraud::MinfraudClient.FIELD_MAP' do
    it 'matches Minfraud::Transaction.ATTRIBUTES' do
      expect(Minfraud::MinfraudClient.const_get(:FIELD_MAP).keys)
        .to match_array(Minfraud::Transaction.const_get(:ATTRIBUTES))
    end
  end

  describe 'Minfraud::MinfraudClient#send_transaction' do
    it 'sends appropriately encoded transaction data to minFraud service' do
      allow(Minfraud::Response).to receive(:new).and_return(success_response)
      stub_request(:get, request_url)
        .with(query: hash_including({})) # ignores query parameters
        .to_return(status: 200, body: '')

      transaction = Minfraud::Transaction.new do |t|
        t.ip = '1'
        t.city = '2'
        t.state = '3'
        t.postal = '4'
        t.country = '5'
        t.txn_id = '6'
        t.license_key = '7'
      end

      minfraud_client.send_transaction(transaction: transaction)

      expect(a_request(:get, request_url).with(
        query: hash_including({
          'i': '1',
          'city': '2',
          'region': '3',
          'postal': '4',
          'country': '5',
          'txnID': '6',
          'license_key': '7',
        })
      )).to have_been_made
    end

    it 'sends request using a persisted connection' do
      allow(Minfraud::Response).to receive(:new).and_return(success_response)
      stub_request(:get, request_url)
        .with(query: hash_including({})) # ignores query parameters
        .to_return(status: 200, body: '')

      minfraud_client.send_transaction(transaction: transaction)

      expect(a_request(:get, request_url).with(
        headers: { 'Connection' => 'keep-alive' },
        query: hash_including({}) # ignores query parameters
      )).to have_been_made
    end

    it 'sends request to the right service host' do
      allow(Minfraud::Response).to receive(:new).and_return(success_response)
      stub_request(:get, request_url_east)
        .with(query: hash_including({})) # ignores query parameters
        .to_return(status: 200, body: '')

      minfraud_client_east.send_transaction(transaction: transaction)

      expect(a_request(:get, request_url_east).with(
        query: hash_including({}) # ignores query parameters
      )).to have_been_made
    end

    it 'raises a ConnectionException if there is an HTTP error' do
      allow(Minfraud::Response).to receive(:new).and_return(success_response)
      stub_request(:get, request_url)
        .with(query: hash_including({})) # ignores query parameters
        .to_raise(Errno::ECONNREFUSED)

      expect {
        minfraud_client.send_transaction(transaction: transaction)
      }.to raise_error(Minfraud::ConnectionException)
    end

    it 'creates Response object out of raw response' do
      expect(minfraud_client.instance_variable_get(:@http_client)).to receive(:get)
      expect(Minfraud::Response).to receive(:new).and_return(success_response)
      minfraud_client.send_transaction(transaction: transaction)
    end

    it 'creates passes a block to modify the Response' do
      expect(minfraud_client.instance_variable_get(:@http_client)).to receive(:get)
      expect_any_instance_of(Minfraud::Response).to receive(:decode_body).and_return({})
      response = minfraud_client.send_transaction(transaction: transaction) do |resp|
        resp[:absurd] = 'not_absurd'
      end
      expect(response.absurd).to eq('not_absurd')
      expect(response.something_else).to be_nil
    end
  end

  def request_url
    'https://minfraud.maxmind.com/app/ccv2r'
  end

  def request_url_east
    'https://minfraud.maxmind.com/app/ccv2r'
  end

end
