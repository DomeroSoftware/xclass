# NAME

hclass - Advanced Thread-Safe Hash Manipulation Class for xclass Ecosystem

# TABLE OF CONTENTS

- [DESCRIPTION](#description)
- [SYNOPSIS](#synopsis)
- [EXAMPLES](#examples)
- [METHODS](#methods)
- [OVERLOADED OPERATORS](#overloaded-operators)
- [ERROR HANDLING](#error-handling)
- [LIMITATIONS AND CAVEATS](#limitations-and-caveats)
- [PERFORMANCE CONSIDERATIONS](#performance-considerations)
- [THREAD SAFETY](#thread-safety)
- [COMPATIBILITY](#compatibility)
- [DEPENDENCIES](#dependencies)
- [VERSION](#version)
- [SEE ALSO](#see-also)
- [AUTHOR](#author)
- [COPYRIGHT AND LICENSE](#copyright-and-license)

# DESCRIPTION

The hclass module provides a robust and feature-rich interface for working with
hash references within the xclass ecosystem. It offers thread-safe operations,
advanced hash manipulations, and seamless integration with nested data structures.

Key features include:

- Thread-safe hash operations using xclass synchronization
- Overloaded operators for intuitive hash manipulation
- Advanced utility methods for complex hash operations
- Seamless handling of nested data structures
- Integration with xclass for type-specific handling of hash elements

## Integration with xclass Ecosystem

hclass inherits core functionality from xclass and can be instantiated directly
or through xclass factory methods. It implements the xclass event system for
operation tracking and uses xclass for element-wise type handling.

## Thread Safety

All methods in hclass are designed to be thread-safe, utilizing xclass synchronization
mechanisms through the sync method.

## Performance Considerations

hclass is optimized for both single-threaded and multi-threaded environments.
It uses efficient handling of nested data structures and lazy initialization of element handlers.

## Extensibility

The class is designed to be easily extended with additional methods and
supports custom event triggers for all operations through the xclass event system.

## Handling of Circular References

hclass, like other components of the xclass ecosystem, includes sophisticated handling of circular references within hash structures.

- Hash values can reference other hclass objects or any other xclass objects, including self-references.
- Circular references in nested hash structures are automatically detected and managed.
- The system ensures proper garbage collection of hclass objects involved in circular references.
- Complex data structures with circular references can be created and manipulated without user intervention for reference management.

# SYNOPSIS

```perl
use strict;
use warnings;

use hclass;

# Create a new hclass object
my $hash = hclass->new({ a => 1, b => 2, c => 3 });

# Basic operations
$hash->set('d', 4)->delete('a');
print $hash->get('b');  # Prints: 2

# Advanced operations
$hash->map(sub { my ($k, $v) = @_; ($k, $v * 2) });
print $hash->to_string;  # Prints something like: {b => 4, c => 6, d => 8}

# Merging hashes
my $other = hclass->new({ e => 5, f => 6 });
$hash->merge($other);

# Using overloaded operators
my $combined = $hash + { g => 7 };
my $intersection = $hash & $other;

# Iteration
$hash->each(sub { my ($k, $v) = @_; print "$k: $v\n" });
```

# EXAMPLES

## Basic Usage

```perl
my $hash = hclass->new({ foo => 1, bar => 2 });
$hash->set('baz', 3);
print $hash->get('foo');  # Prints: 1
$hash->delete('bar');
print $hash->to_string;  # Prints: {foo => 1, baz => 3}
```

## Overloaded Operators

### Dereference (%{})

```perl
my $hash = hclass->new({ a => 1, b => 2 });
my %perl_hash = %{$hash};
print $perl_hash{a};  # Prints: 1
```

### Stringification ("")

```perl
my $hash = hclass->new({ x => 10, y => 20 });
print "$hash";  # Prints: {x => 10, y => 20}
```

### Numeric Context (0+)

```perl
my $hash = hclass->new({ a => 1, b => 2, c => 3 });
print 0 + $hash;  # Prints: 3 (size of the hash)
```

### Boolean Context and Negation (!)

```perl
my $hash = hclass->new({ a => 1 });
print "Not empty" if $hash;  # Prints: Not empty
print "Empty" if !$hash->new;  # Prints: Empty
```

### Assignment (=)

```perl
my $hash1 = hclass->new({ a => 1 });
my $hash2 = $hash1;
$hash2->set('b', 2);
print $hash1->to_string;  # Prints: {a => 1, b => 2}
```

### Equality (==, !=)

```perl
my $hash1 = hclass->new({ a => 1, b => 2 });
my $hash2 = hclass->new({ a => 1, b => 2 });
my $hash3 = hclass->new({ a => 1, c => 3 });
print "Equal" if $hash1 == $hash2;  # Prints: Equal
print "Not equal" if $hash1 != $hash3;  # Prints: Not equal
```

### Comparison (cmp, <=>)

```perl
my $hash1 = hclass->new({ a => 1 });
my $hash2 = hclass->new({ b => 2 });
print $hash1 cmp $hash2;  # Prints: -1
print $hash1 <=> $hash2;  # Prints: -1 (based on size)
```

### Addition (+)

```perl
my $hash1 = hclass->new({ a => 1, b => 2 });
my $hash2 = hclass->new({ b => 3, c => 4 });
my $result = $hash1 + $hash2;
print $result->to_string;  # Prints: {a => 1, b => 3, c => 4}
```

### Subtraction (-)

```perl
my $hash1 = hclass->new({ a => 1, b => 2, c => 3 });
my $hash2 = hclass->new({ b => 2, c => 3 });
my $result = $hash1 - $hash2;
print $result->to_string;  # Prints: {a => 1}
```

### Intersection (&)

```perl
my $hash1 = hclass->new({ a => 1, b => 2, c => 3 });
my $hash2 = hclass->new({ b => 2, c => 3, d => 4 });
my $result = $hash1 & $hash2;
print $result->to_string;  # Prints: {b => 2, c => 3}
```

### Union (|)

```perl
my $hash1 = hclass->new({ a => 1, b => 2 });
my $hash2 = hclass->new({ b => 3, c => 4 });
my $result = $hash1 | $hash2;
print $result->to_string;  # Prints: {a => 1, b => 3, c => 4}
```

### Symmetric Difference (^)

```perl
my $hash1 = hclass->new({ a => 1, b => 2, c => 3 });
my $hash2 = hclass->new({ b => 2, c => 4, d => 5 });
my $result = $hash1 ^ $hash2;
print $result->to_string;  # Prints: {a => 1, c => 3, d => 5}
```

## xclass Integration

### Using xclass Factory Method

```perl
use xclass;
my $hash = Hc({ a => 1, b => 2 });  # Creates an hclass object
```

### Nested Structures with xclass

```perl
my $complex = Hc({
    array => Ac([1, 2, 3]),
    hash => Hc({ x => 10, y => 20 }),
    scalar => Sc(42)
});
print $complex->get('array')->get(1);  # Prints: 2
print $complex->get('hash')->get('x');  # Prints: 10
print $complex->get('scalar')->get;  # Prints: 42
```

## lclass Utilization

### Using lclass Methods

```perl
my $hash1 = hclass->new({ a => 1, b => 2 });
$hash1->try(sub {
    $hash1->set('c', 3);
    die "Error" if $hash1->size > 3;
}, 'set_operation');


my $hash2 = hclass->new({ a => 1, b => 2 })->share;
$hash2->sync(sub {
    $hash2->set('c', 3);
    die "Error" if $hash2->size > 3;
}, 'set_shared_operation');
```

### Event Handling

```perl
$hash->on('set', sub {
    my ($self, $key, $value) = @_;
    print "Set $key to $value\n";
});
$hash->set('d', 4);  # Triggers the event
```

# METHODS

## Constructor

### new($ref?, %options)

Creates a new hclass object.

```perl
my $hash = hclass->new({ key => 'value' });
```

## Core Methods

### get($key?)

Retrieves value(s) from the hash.

```perl
my $value = $hash->get('key');
my %all = $hash->get();
```

### set($key, $value)

Sets a value in the hash.

```perl
$hash->set('key', 'new_value');
```

### delete($key)

Deletes a key-value pair from the hash.

```perl
$hash->delete('key');
```

### exists($key)

Checks if a key exists in the hash.

```perl
if ($hash->exists('key')) { ... }
```

### keys()

Returns all keys of the hash.

```perl
my @keys = $hash->keys();
```

### values()

Returns all values of the hash.

```perl
my @values = $hash->values();
```

### clear()

Clears the hash.

```perl
$hash->clear();
```

## Advanced Methods

### each($coderef)

Iterates over the hash.

```perl
$hash->each(sub { my ($k, $v) = @_; print "$k: $v\n" });
```

### map($coderef)

Applies a function to each key-value pair.

```perl
$hash->map(sub { my ($k, $v) = @_; ($k, $v * 2) });
```

### grep($coderef)

Filters the hash based on a condition.

```perl
$hash->grep(sub { my ($k, $v) = @_; $v > 10 });
```

### merge($other_hash)

Merges another hash into this one.

```perl
$hash->merge({ new_key => 'new_value' });
```

### size()

Returns the number of key-value pairs in the hash.

```perl
my $size = $hash->size();
```

### is_empty()

Checks if the hash is empty.

```perl
if ($hash->is_empty()) { ... }
```

### invert()

Inverts the hash (swaps keys and values).

```perl
$hash->invert();
```

### slice(@keys)

Gets a slice of the hash.

```perl
my %slice = $hash->slice('key1', 'key2');
```

### modify($coderef)

Modifies the hash using a code reference.

```perl
$hash->modify(sub { my $h = shift; $h->{new_key} = 'new_value' });
```

### to_string()

Converts the hash to a string representation.

```perl
print $hash->to_string();
```

# OVERLOADED OPERATORS

hclass overloads the following operators for intuitive hash manipulation:

- Dereferencing (%{})
- Stringification ("")
- Numification (0+)
- Boolean context
- Negation (!)
- Assignment (=)
- Equality (==, !=)
- Comparison (cmp, <=>)
- Addition (+)
- Subtraction (-)
- Intersection (&)
- Union (|)
- Symmetric Difference (^)

See the EXAMPLES section for usage of these overloaded operators.

# ERROR HANDLING

hclass uses the error handling mechanisms provided by xclass. Errors are thrown using the throw method inherited from xclass. These can be caught and handled using eval blocks or try-catch constructs if you're using a module like Try::Tiny.

# LIMITATIONS AND CAVEATS

- Operations on very large hashes may impact performance due to the overhead of maintaining element handlers.
- The overloaded operators create new hclass instances, which may impact performance in tight loops.
- Concurrent modifications to the same hash from multiple threads should be carefully managed to avoid race conditions.

# PERFORMANCE CONSIDERATIONS

- Lazy Initialization: Element handlers are initialized on-demand to minimize overhead.
- Efficient Locking: The sync method is used to ensure thread-safe operations while maximizing concurrency.
- Overloaded Operators: While convenient, overloaded operators may introduce slight performance overhead compared to direct method calls.

# THREAD SAFETY

hclass is designed to be thread-safe. All public methods use the sync method provided by xclass to ensure safe concurrent access and modification of the underlying hash.

# COMPATIBILITY

hclass requires Perl version 5.10 or higher due to its use of advanced language features and for optimal performance.

# DEPENDENCIES

This module requires the following Perl modules:

- v5.10 or higher
- JSON::PP
- lclass (for utility methods and thread-safe operations)
- xclass (for handling specific reference types)

# VERSION

Version 2.0.0

This documentation refers to hclass version 2.0.0.

# SEE ALSO

- [`xclass`](xclass.md): eXtended Class - Core of the xclass ecosystem
- [`lclass`](lclass.md): Lock Class - Thread-safe operations, synchronization and Utilities
- [`sclass`](sclass.md): Scalar Class - Advanced scalar value manipulation
- [`aclass`](aclass.md): Array Class - Enhanced array handling and operations
- [`iclass`](iclass.md): IO Class - Input/Output operations and file handling
- [`cclass`](cclass.md): Code Class - Subroutine and code reference management
- [`gclass`](gclass.md): GLOB Class - Advanced GLOB reference manipulation
- [`rclass`](rclass.md): Reference Class - Generic reference type handling
- [`tclass`](tclass.md): Thread Class - Advanced thread control and management


# AUTHOR

OnEhIppY, Domero Software <domerosoftware@gmail.com>

# COPYRIGHT AND LICENSE

Copyright (C) 2024 OnEhIppY, Domero Software

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
