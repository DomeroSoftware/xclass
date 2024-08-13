#!/usr/bin/env perl

use v5.38;
use strict;
use warnings;
use threads;
use Thread::Queue;
use lib '../lib';
use hclass;

# Create a shared hash
my %shared_hash :shared;
my $hclass_obj = hclass->new(\%shared_hash);

# Create a queue for thread synchronization
my $queue = Thread::Queue->new();

# Function to perform operations on the shared hash
sub perform_operations {
    my $thread_id = threads->tid();
    
    # Set some key-value pairs
    $hclass_obj->set("key_$thread_id", $thread_id);
    $hclass_obj->set("double_$thread_id", $thread_id * 2);
    say "Thread $thread_id: Set key-value pairs. Hash: " . $hclass_obj;
    
    # Use overloaded operators
    my $result = $hclass_obj + { "new_key_$thread_id" => "value_$thread_id" };
    say "Thread $thread_id: Added new key-value pair (using overloaded +). Result: $result";
    
    # Demonstrate other methods
    say "Thread $thread_id: Keys: " . join(', ', $hclass_obj->keys());
    say "Thread $thread_id: Values: " . join(', ', $hclass_obj->values());
    
    # Demonstrate atomic modifications
    $hclass_obj->modify(sub {
        my $hash_ref = shift;
        $hash_ref->{"atomic_$thread_id"} = "atomic_value_$thread_id";
    });
    say "Thread $thread_id: After atomic modification: " . $hclass_obj;
    
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

# Final hash
say "Final hash: " . $hclass_obj;

# Demonstrate more operations
say "Size of hash: " . $hclass_obj->size();
say "Is empty? " . ($hclass_obj->is_empty() ? "Yes" : "No");

# Demonstrate map and grep
$hclass_obj->map(sub { my ($k, $v) = @_; ($k, ref($v) eq 'SCALAR' ? $$v * 2 : $v) });
say "After doubling all numeric values: " . $hclass_obj;

my $filtered = $hclass_obj->clone->grep(sub { my ($k, $v) = @_; $k =~ /^double_/ });
say "After keeping only 'double_' keys: " . $filtered;

# Demonstrate merge
my $another_hclass = hclass->new({ new_key1 => 100, new_key2 => 200 });
$hclass_obj->merge($another_hclass);
say "After merging with another hash: " . $hclass_obj;

# Demonstrate invert
my $inverted = $hclass_obj->clone->invert();
say "After inverting: " . $inverted;

# Demonstrate overloaded operators
my $intersection = $hclass_obj & $another_hclass;
say "Intersection with {new_key1 => 100, new_key2 => 200}: $intersection";

my $difference = $hclass_obj - $another_hclass;
say "Difference with {new_key1 => 100, new_key2 => 200}: $difference";

my $symmetric_difference = $hclass_obj ^ $another_hclass;
say "Symmetric difference with {new_key1 => 100, new_key2 => 200}: $symmetric_difference";

# Demonstrate each
say "Iterating through the hash:";
$hclass_obj->each(sub { my ($k, $v) = @_; say "  $k => $v"; });

# Demonstrate clone
my $clone = $hclass_obj->clone();
$clone->set("clone_key", "clone_value");
say "Original after modifying clone: " . $hclass_obj;
say "Clone: " . $clone;

# Demonstrate clear
$hclass_obj->clear();
say "After clearing: " . $hclass_obj;
say "Is empty now? " . ($hclass_obj->is_empty() ? "Yes" : "No");

# Demonstrate serialization and deserialization
my $serialized = $hclass_obj->serialize();
say "Serialized hash: $serialized";
my $deserialized = hclass->new({})->deserialize($serialized);
say "Deserialized hash: $deserialized";
