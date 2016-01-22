require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'securerandom'
describe KinesisFirehoseBatcher do
  it "batches the records for sending" do
    client = double('Aws::Firehose::Client')
    
    s = described_class.new(client: client, delivery_stream_name: 'some-stream')
    
    2000.times { s << "Some message\n" }
    1000.times { s << "Another message\n" }
    
    expect(s.buffered).to eq(3000)
    
    s << "Closing message"
    
    message_sends = []
    expect(client).to receive(:put_record_batch).exactly(9).times {|*args|
      message_sends << args
      double(:failed_put_count => 0)
    }
    
    s.send!
    
    expect(message_sends).not_to be_empty
    message_sends.each do | one_put_batch_call |
      args = one_put_batch_call[0]
      expect(args[:delivery_stream_name]).to eq('some-stream')
      
      records = args[:records]
      expect(records).not_to be_empty
      expect(records.length).to be < KinesisFirehoseBatcher::MAX_RECORDS_PER_BATCH
  
      record_strings = records.map{|e| e.fetch(:data) }
      entire_message = record_strings.join
      
      expect(entire_message.bytesize).to be < KinesisFirehoseBatcher::MAX_BYTES_PER_BATCH 
    end
    
    total_records = message_sends.map{|e| e[0][:records]}.flatten
    expect(total_records.length).to eq(3001)
  end
  
  it 'attempts to resend the records that failed' do
    client = double('Aws::Firehose::Client')
    s = described_class.new(client: client, delivery_stream_name: 'some-stream')
    
    expect(s).to receive(:send_via_client).once.with(['Hello 1', 'Hello 2', 'Hello 3']) {
      fake_record_responses = [
        double(record_id: SecureRandom.hex(2)),
        double(record_id: nil),
        double(record_id: SecureRandom.hex(2)),
      ]
      double('Firehose response', :request_responses => fake_record_responses, :failed_put_count => 1)
    }
    
    expect(s).to receive(:send_via_client).once.with(['Hello 2']) {
      fake_record_responses = [
        double(record_id: SecureRandom.hex(2)),
      ]
      double('Firehose response', :request_responses => fake_record_responses, :failed_put_count => 0)
    }
    
    (1..3).each { |i| s << "Hello #{i}" }
    s.send!
  end
  
  it 'sends via the given client' do
    client = double('Aws::Firehose::Client')
    s = described_class.new(client: client, delivery_stream_name: 'some-stream')
    expect(client).to receive(:put_record_batch).with({
      delivery_stream_name: 'some-stream',
      records: [{data: 'Hello 1'}, {data: 'Hello 2'}, {data: 'Hello 3'}]
    }).and_return(double(failed_put_count: 0))
    
    (1..3).each { |i| s << "Hello #{i}" }
    
    s.send!
  end
  
  it 'gives up after the set number of retries' do
    client = double('Aws::Firehose::Client')
    s = described_class.new(client: double(), delivery_stream_name: 'some-stream', max_retries: 123)
    
    tries_used = 0
    allow(s).to receive(:send_via_client) { |record_strings|
      tries_used += 1
      # Always fail one record of the batch
      sent_record_response = double(record_id: SecureRandom.hex(2))
      failed_record_response = double(record_id: nil)
      
      record_responses = [sent_record_response] * (record_strings.length - 1)
      record_responses << failed_record_response
      record_responses.shuffle!
      
      double('Firehose response', :request_responses => record_responses, :failed_put_count => 1)
    }
    7000.times { s << "Hello and goodbye - just a record here\n" }
    expect {
      s.send!
    }.to raise_error(KinesisFirehoseBatcher::RetriesExahusted)
    expect(tries_used).to eq(123)
  end
  
  it 'explicitly fails when a record is too large' do
    s = described_class.new(client: double(), delivery_stream_name: 'some-stream')
    expect {
      s << Random.new.bytes(1024 * 1024 * 3)
    }.to raise_error {|e|
      expect(e).to be_kind_of(KinesisFirehoseBatcher::RecordTooLarge)
      expect(e.record).to be_kind_of(String)
    }
  end
end
