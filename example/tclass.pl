#!/usr/bin/env perl

use strict;
use warnings;
use xclass;
use Time::HiRes qw(time);

print "tclass Example - Simple and Complex Use Cases\n\n";

# Simple Use Case: Counter Thread
print "Simple Use Case: Counter Thread\n";

my $counter_thread = Tc('Example', 'SimpleCounter',
    scalar => 0,
    code => sub {
        my ($self) = @_;
        while (!$self->should_stop) {
            $self->SCALAR->inc(1);
            $self->sleep(0.1);
        }
    }
);

$counter_thread->start;
sleep(2);
$counter_thread->stop;
print "Final count: ", $counter_thread->SCALAR->get, "\n\n";

# Complex Use Case: Multi-threaded Data Processing Pipeline
print "Complex Use Case: Multi-threaded Data Processing Pipeline\n";

# Shared data structures
my $input_queue = Ac([])->share_it;
my $processing_queue = Ac([])->share_it;
my $result_hash = Hc({})->share_it;

# Producer thread
my $producer = Tc('Example', 'Producer',
    input_queue => $input_queue,
    code => sub {
        my ($self) = @_;
        for my $i (1..20) {
            $self->get('input_queue')->push($i);
            $self->sleep(0.1);
        }
    }
);

# Worker threads
my @workers = map {
    Tc('Example', "Worker$_",
        input_queue => $input_queue,
        processing_queue => $processing_queue,
        code => sub {
            my ($self) = @_;
            while (!$self->should_stop) {
                if (my $item = $self->get('input_queue')->shift) {
                    my $processed = $item * 2;  # Simple processing: double the input
                    $self->get('processing_queue')->push([$item, $processed]);
                } else {
                    $self->sleep(0.1);
                }
            }
        }
    )
} 1..3;

# Consumer thread
my $consumer = Tc('Example', 'Consumer',
    processing_queue => $processing_queue,
    result_hash => $result_hash,
    code => sub {
        my ($self) = @_;
        while (!$self->should_stop) {
            if (my $item = $self->get('processing_queue')->shift) {
                my ($original, $processed) = @$item;
                $self->get('result_hash')->set($original, $processed);
            } else {
                $self->sleep(0.1);
            }
        }
    }
);

# Start all threads
$producer->start;
$_->start for @workers;
$consumer->start;

# Wait for processing to complete
while ($result_hash->size < 20) {
    sleep 0.1;
}

# Stop all threads
$producer->stop;
$_->stop for @workers;
$consumer->stop;

# Print results
print "Processing results:\n";
$result_hash->each(sub {
    my ($key, $value) = @_;
    print "Input: $key, Output: $value\n";
});

print "\nAll threads completed successfully.\n";
