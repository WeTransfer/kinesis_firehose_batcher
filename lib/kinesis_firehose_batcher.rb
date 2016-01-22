class KinesisFirehoseBatcher
  VERSION = '0.0.1'
  
  MAX_BYTES_PER_BATCH = 4 * 1024 * 1024
  MAX_RECORDS_PER_BATCH = 500
  MAX_BYTES_PER_RECORD = 1000 * 1024
  
  # Gets raised when Firehose still refuses to accept records
  # even once the tries have been exhausted
  class RetriesExahusted < StandardError
  end
  
  # Gets raised when a record string is too large to be sent via Firehose.
  # If you encounter this, you need to use a side-channel to send data to
  # the Firehose destination outside of the Firehose flow. For example,
  # if you have a stream dumping data to S3 you might have to just grab the
  # record and upload it separately.
  class RecordTooLarge < StandardError
    
    # @param [String] the record that was too large
    attr_reader :record
    
    def initialize(failed_record_string, *args_for_super)
      @record = failed_record_string
      super(*args_for_super)
    end
  end
  
  def initialize(client:, delivery_stream_name:, max_retries: 100)
    @buffer = []
    @client, @delivery_stream_name, @max_retries = client, delivery_stream_name, max_retries
  end
  
  # Add a record (string) to the batch
  #
  # @param str[String] The record to add
  def <<(str)
    raise RecordTooLarge.new(str) if str.bytesize >= MAX_BYTES_PER_RECORD
    @buffer << str
  end
  
  # Send the accumulated records in the buffer, and empty the buffer afterwards.
  #
  # @return [void]
  def send!
    return if @buffer.empty?
    recursive_send(@buffer)
    @buffer.clear
  end
  
  # Tells how many records are in the buffer, ready to send
  #
  # @return [Fixnum] the number of records outstanding
  def buffered
    @buffer.length
  end
  
  private
  
  # Accepts an array of Strings (records) and sends them via the client
  # supplied to the constructor
  #
  # Kept in a separate method because normal Kinesis (not Firehose) has
  # a different way of packing records and a different method signature
  #
  # @param record_strings[Array<String>] the array of records to send
  # @return [Aws::Firehose::Types::PutRecordBatchOutput]
  def send_via_client(record_strings)
    record_hashes = record_strings.map do | str |
      {data: str}
    end
    @client.put_record_batch(records: record_hashes, delivery_stream_name: @delivery_stream_name)
  end
  
  def recursive_send(array_of_record_strings)
    if array_of_record_strings.empty?
      return 
    elsif overflow?(array_of_record_strings)
      # Split the array into parts and try again.
      array_of_record_strings.each_slice(array_of_record_strings.length / 2) do | slice |
        recursive_send(slice)
      end
    else
      send_with_retries(array_of_record_strings)
      array_of_record_strings.clear
    end
  end
  
  def overflow?(array_of_record_strings)
    # Each PutRecordBatch request supports up to 500 array_of_record_strings.
    # Each record in the request can be as large as 1,000 KB (before 64-bit encoding),
    # up to a limit of 4 MB for the entire request.
    return true if array_of_record_strings.length >= MAX_RECORDS_PER_BATCH
    return true if packet_size(array_of_record_strings) >= MAX_BYTES_PER_BATCH
  end
  
  def send_with_retries(record_hashes)
    result = send_via_client(record_hashes)
    
    return if result.failed_put_count.zero?
    
    tries = 0
    
    while result.failed_put_count.nonzero?
      tries += 1
      if tries >= @max_retries
        msg = "%d records still failed to send after %d tries" % [result.failed_put_count, tries]
        raise RetriesExahusted.new(msg)
      end
       
      # Replace all the records that did manage to send with nils
      result.request_responses.each_with_index do | record_response, record_i |
        record_hashes[record_i] = nil if record_response.record_id
      end
      
      # Squash out all the nils (records that were sent during the previous try
      record_hashes.compact!
      
      #... and try to send again
      result = send_via_client(record_hashes)
    end
  end
  
  def packet_size(array_of_strings)
    array_of_strings.inject(0) {|bytesize, record_str| bytesize + record_str.bytesize }
  end
end
