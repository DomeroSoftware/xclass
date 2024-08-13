#!/usr/bin/env perl

use v5.38;
use strict;
use warnings;
use threads;
use Thread::Queue;

use lib '../lib';
use cclass;

# Create a shared code reference
my $shared_code = cclass->new(sub {
    my ($x, $y) = @_;
    return $x + $y;
});

# Create a queue for thread synchronization
my $queue = Thread::Queue->new();

# Function to perform operations using the shared code reference
sub perform_operations {
    my $thread_id = threads->tid();
    
    # Call the shared code
    my $result = $shared_code->call(10, 20);
    say "Thread $thread_id: Result of 10 + 20 = $result";
    
    # Use overloaded operators
    my $new_code = $shared_code . sub { $_[0] * 2 };
    $result = $new_code->call(10, 20);
    say "Thread $thread_id: Result of (10 + 20) * 2 = $result";
    
    # Demonstrate memoization
    $shared_code->memoize(100, 60);  # Cache size 100, expire after 60 seconds
    my $time_info = $shared_code->time(30, 40);
    say "Thread $thread_id: Result of 30 + 40 = $time_info->{result}, Time taken: $time_info->{time} seconds";
    
    # Call again to demonstrate memoization effect
    $time_info = $shared_code->time(30, 40);
    say "Thread $thread_id: Memoized result of 30 + 40 = $time_info->{result}, Time taken: $time_info->{time} seconds";
    
    $queue->enqueue(1);  # Signal that the thread is done
}

# Create multiple threads
my @threads = map {
    threads->create(\&perform_operations);
} 1..3;

# Wait for all threads to finish
$queue->dequeue() for 1..3;

# Join all threads
$_->join for @threads;

# Demonstrate more operations
say "\nDemonstrating more operations:";

# Modify
$shared_code->modify(sub {
    my $original = shift;
    return sub { $original->(@_) * 2 };
});
say "Modified result: " . $shared_code->call(5, 7);

# Curry
my $curried = $shared_code->clone()->curry(100);
say "Curried result: " . $curried->call(50);

# Throttle
my $throttled = $shared_code->clone()->throttle(1);  # 1 second throttle
say "Throttled result 1: " . $throttled->call(6, 7);
say "Throttled result 2: " . $throttled->call(8, 9);  # This will wait for 1 second

# Debounce
my $debounced = $shared_code->clone()->debounce(1);  # 1 second debounce
$debounced->call(10, 11);
$debounced->call(12, 13);
sleep 2;  # Wait for debounce to complete

# Retry
my $retry = cclass->new(sub {
    state $attempts = 0;
    $attempts++;
    die "Simulated failure" if $attempts < 3;
    return "Success after $attempts attempts";
})->retry(5, 0.5);
say "Retry result: " . $retry->call();

# Profile
my $profile_result = $shared_code->profile(10000, 1, 2);
say "Profile result: Iterations: $profile_result->{iterations}, " .
    "Total time: $profile_result->{total_time} seconds, " .
    "Average time: $profile_result->{average_time} seconds";

# Lightweight mode
$shared_code->set_lightweight_mode(1);
say "Lightweight mode: " . ($shared_code->get_lightweight_mode() ? "Enabled" : "Disabled");

say "\nAll operations completed.";
