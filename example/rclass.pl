#!/usr/bin/env perl

use strict;
use warnings;
use xclass;

print "rclass Example - Simple and Complex Use Cases\n\n";

# Simple Use Case: Basic Reference Manipulation
print "Simple Use Case: Basic Reference Manipulation\n";

my $scalar = 42;
my $simple_ref = Rc(\$scalar);

print "Original value: ", ${$simple_ref->get}, "\n";

$simple_ref->apply(sub { ${$_[0]->get} *= 2 });
print "After doubling: ", ${$simple_ref->get}, "\n";

$simple_ref->set([1, 2, 3]);
print "Changed to array: ", join(", ", @{$simple_ref->get}), "\n";

print "Reference type: ", $simple_ref->get_type, "\n\n";

# Complex Use Case: Multi-type Reference Handling and Thread-safe Operations
print "Complex Use Case: Multi-type Reference Handling and Thread-safe Operations\n";

# Create different types of references
my $array_ref = Rc([1, 2, 3, 4, 5]);
my $hash_ref = Rc({a => 1, b => 2, c => 3});
my $code_ref = Rc(sub { my $x = shift; return $x * $x });

# Perform operations on references
$array_ref->apply(sub { @{$_[0]->get} = map { $_ * 2 } @{$_[0]->get} });
print "Doubled array: ", join(", ", @{$array_ref->get}), "\n";

$hash_ref->apply(sub { $_{$_} += 10 for keys %$_ });
print "Hash with added values: ", join(", ", map { "$_: ".%{$hash_ref->get}{$_} } sort keys %{$hash_ref->get}), "\n";

my $result = $code_ref->deref->(5);
print "Code reference result: ", $result, "\n";

# Thread-safe operations
use threads;

my $shared_ref = Rc(shared_clone({count => 0}));

my @threads = map {
    threads->create(sub {
        for (1..1000) {
            $shared_ref->apply(sub { $_->{count}++ });
        }
    });
} 1..5;

$_->join for @threads;

print "Final count after thread operations: ", $shared_ref->deref->{count}, "\n";

# Demonstrate reference type changes
my $dynamic_ref = Rc(\42);
print "\nDynamic reference type changes:\n";
print "Initial type: ", $dynamic_ref->get_type, "\n";

$dynamic_ref->set([1, 2, 3]);
print "Changed to array, type: ", $dynamic_ref->get_type, "\n";

$dynamic_ref->set({x => 1, y => 2});
print "Changed to hash, type: ", $dynamic_ref->get_type, "\n";

# Demonstrate cloning and comparison
my $original = Rc([1, 2, 3]);
my $clone = $original->clone;
print "\nCloning and comparison:\n";
print "Original: ", join(", ", @{$original->get}), "\n";
print "Clone: ", join(", ", @{$clone->get}), "\n";
print "Are equal? ", $original->equals($clone) ? "Yes" : "No", "\n";

# Demonstrate size and clear operations
print "\nSize and clear operations:\n";
print "Size of array reference: ", $array_ref->size, "\n";
$array_ref->clear;
print "Size after clearing: ", $array_ref->size, "\n";

print "\nAll operations completed successfully.\n";
