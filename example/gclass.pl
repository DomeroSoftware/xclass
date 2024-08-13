#!/usr/bin/env perl

use v5.38;
use warnings;
use experimental 'class';
use threads;
use Thread::Queue;
use IO::File;
use Time::HiRes qw(time);
use Data::Dumper;

# Include the directory containing gclass.pm in @INC
use lib '../lib';
use gclass;

# Create a shared glob
my $shared_glob = gclass->new(
    space => 'MyNamespace',
    name => 'shared_glob',
    init => {
        SCALAR => \"Initial scalar value",
        ARRAY => [1, 2, 3],
        HASH => { key1 => 'value1', key2 => 'value2' },
        CODE => sub { "Hello from code!" },
        IO => IO::File->new_tmpfile,
    }
);

# Create a queue for thread synchronization
my $queue = Thread::Queue->new();

# Function to perform operations using the shared glob
sub perform_operations {
    my $thread_id = threads->tid();
    
    # Modify SCALAR
    $shared_glob->SCALAR("Modified by thread $thread_id");
    
    # Append to ARRAY
    $shared_glob->ARRAY->push("Thread $thread_id");
    
    # Add to HASH
    $shared_glob->HASH->set("thread_$thread_id" => "Was here");
    
    # Call CODE
    my $code_result = $shared_glob->CODE->call();
    say "Thread $thread_id CODE result: $code_result";
    
    # Write to IO
    $shared_glob->IO->print("Thread $thread_id was here\n");
    
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

# Show the final state of the glob
say "\nFinal state of the shared glob:";
say $shared_glob->show();

# Demonstrate more operations
say "\nDemonstrating more operations:";

# Access SCALAR
say "SCALAR value: " . $shared_glob->SCALAR->get();

# Access ARRAY
say "ARRAY contents: " . join(", ", $shared_glob->ARRAY->get());

# Access HASH
say "HASH contents:";
for my $key ($shared_glob->HASH->keys()) {
    say "  $key => " . $shared_glob->HASH->get($key);
}

# Call CODE
say "CODE result: " . $shared_glob->CODE->call();

# Read from IO
$shared_glob->IO->seek(0, 0);
say "IO contents:";
while (my $line = $shared_glob->IO->getline()) {
    print $line;
}

# Demonstrate overloaded operators
say "\nDemonstrating overloaded operators:";
say "Glob as string: $shared_glob";
say "Glob as number: " . (0 + $shared_glob);
say "Is glob truthy? " . ($shared_glob ? "Yes" : "No");

# Reinitialize the glob
say "\nReinitializing the glob:";
$shared_glob->reinitialize({
    SCALAR => \"New scalar value",
    ARRAY => [4, 5, 6],
    HASH => { new_key => 'new_value' },
    CODE => sub { "New code result" },
    IO => IO::File->new_tmpfile,
});
say $shared_glob->show();

# Check if types are defined
say "\nChecking if types are defined:";
for my $type (qw(SCALAR ARRAY HASH CODE IO)) {
    say "$type is " . ($shared_glob->is_defined($type) ? "defined" : "not defined");
}

# Set and get individual types
say "\nSetting and getting individual types:";
$shared_glob->set(SCALAR => "Newly set scalar");
say "New SCALAR value: " . $shared_glob->get('SCALAR');

$shared_glob->set(ARRAY => 7, 8, 9);
say "New ARRAY contents: " . join(", ", @{$shared_glob->get('ARRAY')});

$shared_glob->set(HASH => new_key1 => 'new_value1', new_key2 => 'new_value2');
say "New HASH contents:";
for my $key (keys %{$shared_glob->get('HASH')}) {
    say "  $key => " . $shared_glob->get('HASH')->{$key};
}

# New examples demonstrating added features
say "\nDemonstrating new features:";

# Serialization and deserialization
say "\nSerializing and deserializing:";
my $serialized = $shared_glob->serialize('json');
my $new_glob = gclass->new(space => 'NewSpace', name => 'new_glob');
$new_glob->deserialize($serialized, 'json');
say "Deserialized glob:";
say $new_glob->show();

# Type constraints
say "\nDemonstrating type constraints:";
$shared_glob->set_type_constraint('SCALAR', Type::Tiny->new(constraint => sub { $_[0] =~ /^\d+$/ }));
eval { $shared_glob->SCALAR(42) };
say "Setting SCALAR to 42: " . ($@ ? "Failed" : "Succeeded");
eval { $shared_glob->SCALAR("Not a number") };
say "Setting SCALAR to 'Not a number': " . ($@ ? "Failed (as expected)" : "Succeeded (unexpected)");

# Atomic operations
say "\nDemonstrating atomic operations:";
$shared_glob->SCALAR(0);
for (1..10) {
    $shared_glob->atomic_operation(sub {
        my $self = shift;
        $self->SCALAR($self->SCALAR->get + 1);
    });
}
say "After 10 atomic increments, SCALAR is: " . $shared_glob->SCALAR->get();

# Event system
say "\nDemonstrating event system:";
$shared_glob->on('set', sub {
    my ($self, $type) = @_;
    say "Event: The $type was set.";
});
$shared_glob->set(SCALAR => 100);

# Iterator
say "\nDemonstrating iterator:";
$shared_glob->ARRAY(1..5);
my $iterator = $shared_glob->create_iterator('ARRAY');
say "Array contents using iterator:";
while (my $value = $iterator->()) {
    print "$value ";
}
say "";

# Profiling
say "\nDemonstrating profiling:";
$shared_glob->profile(sub {
    $shared_glob->ARRAY->push(6);
    $shared_glob->HASH->set(new_key => 'profiled_value');
});
my $profiling_data = $shared_glob->get_profiling_data();
say "Profiling data: ", Dumper($profiling_data);

# Cloning and merging
say "\nDemonstrating cloning and merging:";
my $clone = $shared_glob->clone();
$clone->SCALAR("Cloned value");
say "Original SCALAR: ", $shared_glob->SCALAR->get();
say "Cloned SCALAR: ", $clone->SCALAR->get();
$shared_glob->merge($clone);
say "After merge, SCALAR: ", $shared_glob->SCALAR->get();

# Watching for changes
say "\nDemonstrating watching for changes:";
my $watch_callback = sub {
    my ($self, $event, @args) = @_;
    say "Watch event: $event";
};
$shared_glob->watch($watch_callback);
$shared_glob->SCALAR("Watched change");
$shared_glob->unwatch($watch_callback);

# Size calculation
say "\nDemonstrating size calculation:";
my $size = $shared_glob->size();
say "Size of shared_glob: $size bytes";

# Optimization flags
say "\nDemonstrating optimization flags:";
$shared_glob->set_optimization_flags(use_cache => 1);
say "Optimization flags set. Cache will be used for subsequent operations.";
my $cached_value = $shared_glob->get('SCALAR');
say "Cached SCALAR value: ", $cached_value;
$shared_glob->clear_cache();
say "Cache cleared.";

# Weak references
say "\nDemonstrating weak references:";
{
    my $object = { data => 'some data' };
    $shared_glob->add_weak_reference('my_object', $object);
    my $retrieved_object = $shared_glob->get_weak_reference('my_object');
    say "Weak reference retrieved: ", $retrieved_object ? "Yes" : "No";
}
my $retrieved_object = $shared_glob->get_weak_reference('my_object');
say "Weak reference after object destruction: ", $retrieved_object ? "Still exists (unexpected)" : "Gone (as expected)";

say "\nAll operations completed.";
