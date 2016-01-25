# kinesis_firehose_batcher

[![Build Status](https://travis-ci.org/WeTransfer/kinesis_firehose_batcher.svg?branch=master)](https://travis-ci.org/WeTransfer/kinesis_firehose_batcher)

Send record strings to AWS Kinesis Firehose in sensible batches (straddling the limits for the batch
size, maximum number of records and maximum record length).

    client = Aws::Firehose::Client.new(region: "us-east-1")
    batcher = KinesisFirehoseBatcher.new(client: client, delivery_stream_name: 'my-stream')
    9000.times { batcher <<  JSON.dump(some_record) }
    batcher.send!

## Contributing to kinesis_firehose_batcher
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2016 WeTransfer. See LICENSE.txt for further details.

