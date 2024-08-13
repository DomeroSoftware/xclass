#!/usr/bin/env perl

use strict;
use warnings;
use threads;
use Thread::Queue;

# Include the directory containing aclass.pm in @INC
use lib '../lib';
use aclass;

# Create a shared array
my @shared_array :shared;
my $aclass_obj = aclass->new(\@shared_array);

# Create a queue for thread synchronization
my $queue = Thread::Queue->new();

# Function to perform operations on the shared array
sub perform_operations {
    my $thread_id = threads->tid();
    
    # Push elements
    $aclass_obj->push($thread_id, $thread_id * 2, $thread_id * 3);
    say "Thread $thread_id: Pushed elements. Array: " . $aclass_obj;
    
    # Sort the array
    $aclass_obj->sort;
    say "Thread $thread_id: Sorted array: " . $aclass_obj;
    
    # Use overloaded operators
    my $result = $aclass_obj + [100, 200];
    say "Thread $thread_id: Added [100, 200] (using overloaded +). Result: $result";
    
    $aclass_obj *= 2;
    say "Thread $thread_id: Multiplied by 2 (using overloaded *=). Result: " . $aclass_obj;
    
    # Demonstrate other methods
    say "Thread $thread_id: Sum of elements: " . $aclass_obj->sum();
    say "Thread $thread_id: Maximum element: " . $aclass_obj->max();
    
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

# Final array
say "Final array: " . $aclass_obj;

# Demonstrate more operations
say "Length of array: " . $aclass_obj->len();
say "First element: " . $aclass_obj->get(0);
say "Last element: " . $aclass_obj->get(-1);

# Demonstrate map and grep
$aclass_obj->map(sub { $_ * 2 });
say "After doubling all elements: " . $aclass_obj;

$aclass_obj->grep(sub { $_ % 4 == 0 });
say "After keeping only multiples of 4: " . $aclass_obj;

# Demonstrate reduce
my $product = $aclass_obj->reduce(sub { $a * $b });
say "Product of all elements: $product";

# Demonstrate slice
my @slice = $aclass_obj->slice(1, 3);
say "Slice (index 1 to 3): " . join(', ', @slice);

# Demonstrate unique
$aclass_obj->push(4, 8, 12, 4, 8);
say "Before unique: " . $aclass_obj;
$aclass_obj->unique();
say "After unique: " . $aclass_obj;

# Demonstrate first and last
my $first_over_10 = $aclass_obj->first(sub { $_ > 10 });
say "First element over 10: $first_over_10";

my $last_even = $aclass_obj->last(sub { $_ % 2 == 0 });
say "Last even element: $last_even";

# Demonstrate overloaded operators
my $another_aclass = aclass->new([1, 2, 3]);
my $union = $aclass_obj | $another_aclass;
say "Union with [1, 2, 3]: $union";

my $intersection = $aclass_obj & $another_aclass;
say "Intersection with [1, 2, 3]: $intersection";

my $difference = $aclass_obj - $another_aclass;
say "Difference with [1, 2, 3]: $difference";

# Demonstrate reverse
$aclass_obj->reverse();
say "Reversed array: " . $aclass_obj;
