# rclass - Advanced Thread-Safe Reference Handling Class for xclass Ecosystem

## Table of Contents

- [Description](#description)
- [Synopsis](#synopsis)
- [Examples](#examples)
- [Methods](#methods)
- [Overloaded Operators](#overloaded-operators)
- [Error Handling](#error-handling)
- [Limitations and Caveats](#limitations-and-caveats)
- [Configuration](#configuration)
- [Performance Considerations](#performance-considerations)
- [Thread Safety](#thread-safety)
- [Compatibility](#compatibility)
- [Dependencies](#dependencies)
- [Version](#version)
- [See Also](#see-also)
- [Author](#author)
- [Copyright and License](#copyright-and-license)

## Description

The rclass module provides a robust and versatile interface for managing references
of any type within the xclass ecosystem. It leverages lclass functionality
for core operations and integrates seamlessly with xclass for type-specific
handling.

Key features include:

- Thread-safe reference operations using lclass synchronization
- Support for all reference types (scalar, array, hash, code, glob)
- Automatic type detection and appropriate handling
- Overloaded operators for intuitive reference manipulation
- Advanced utility methods for reference operations
- Seamless integration with other xclass reference types
- Built-in serialization and deserialization capabilities

### Integration with xclass Ecosystem

rclass utilizes xclass for type-specific reference handling and implements the xclass
event system for operation tracking. It seamlessly interacts with other xclass data types.

### Thread Safety

All methods in rclass are designed to be thread-safe, utilizing lclass synchronization mechanisms.

### Performance Considerations

rclass is optimized for both single-threaded and multi-threaded environments,
with efficient handling of different reference types.

### Extensibility

The rclass is designed to be easily extended with additional reference operations
and supports custom event triggers for all operations.

## Synopsis

```perl
use strict;
use warnings;
use rclass;

# Create a new rclass object
my $ref = rclass->new(\$scalar);

# Set a new reference
$ref->set(\@array);

# Dereference
my $value = $ref->deref;

# Apply a function to the reference content
$ref->apply(sub { $_[0] * 2 });

# Merge with another rclass object
$ref->merge($other_ref);

# Clone the reference
my $clone = $ref->clone;

# Compare references
if ($ref->equals($other_ref)) {
    print "References are equal\n";
}
```

## Examples

### Basic Usage and Overloaded Operators

```perl
use xclass;

# Create a new rclass object
my $scalar_ref = Rc(\10);
print $$scalar_ref;  # Prints 10

my $array_ref = Rc([1, 2, 3]);
push @$array_ref, 4;  # Adds 4 to the array
print $array_ref->deref->[3];  # Prints 4

my $hash_ref = Rc({a => 1, b => 2});
print $hash_ref->deref->{a};  # Prints 1
```

### Reference Type Detection and Manipulation

```perl
my $dynamic_ref = Rc(\42);
print $dynamic_ref->get_type, "\n";  # Outputs: SCALAR

$dynamic_ref->set([1, 2, 3]);
print $dynamic_ref->get_type, "\n";  # Outputs: ARRAY
```

### Applying Functions to References

```perl
my $ref = Rc({a => 1, b => 2});
$ref->apply(sub { 
    my $hash = shift;
    $hash->{c} = $hash->{a} + $hash->{b};
    return $hash;
});
print $ref->deref->{c};  # Prints 3
```

### Merging References

```perl
my $ref1 = Rc({a => 1, b => 2});
my $ref2 = Rc({c => 3, d => 4});
$ref1->merge($ref2);
print $ref1->deref->{c};  # Prints 3
```

### Cloning and Comparison

```perl
my $original = Rc([1, 2, 3]);
my $clone = $original->clone;
print $original->equals($clone) ? "Equal" : "Not equal";  # Prints "Equal"
```

### Size and Clearing

```perl
my $array_ref = Rc([1, 2, 3, 4, 5]);
print $array_ref->size, "\n";  # Prints 5
$array_ref->clear;
print $array_ref->size, "\n";  # Prints 0
```

### Hash Code Generation

```perl
my $ref1 = Rc({a => 1, b => 2});
my $ref2 = Rc({a => 1, b => 2});
print $ref1->hash_code eq $ref2->hash_code ? "Same hash" : "Different hash";
```

### Thread-Safe Operations

```perl
use threads;

my $shared_ref = Rc(shared_clone({count => 0}));

my @threads = map {
    threads->create(sub {
        for (1..1000) {
            $shared_ref->apply(sub { $_->{count}++ });
        }
    });
} 1..10;

$_->join for @threads;
print $shared_ref->deref->{count}, "\n";  # Should print 10000
```

### Integration with xclass Ecosystem

```perl
my $array_ref = Rc([1, 2, 3, 4, 5]);
my $aclass_array = $array_ref->deref;  # Converts to aclass
my $filtered = $aclass_array->filter(sub { $_ % 2 == 0 });
print $filtered->join(", "), "\n";  # Prints 2, 4
```

These examples showcase the core functionality of rclass within the xclass ecosystem, demonstrating its capabilities in reference manipulation, type handling, thread-safe operations, and integration with other xclass components.

## Methods

### Constructor

#### new($ref, %options)

Creates a new rclass object.

```perl
my $ref = rclass->new(\$scalar);
```

### Core Methods

#### set($reference)

Sets the reference.

```perl
$ref->set(\@array);
```

#### deref()

Dereferences the stored reference.

```perl
my $value = $ref->deref;
```

#### get_type()

Gets the type of the reference.

```perl
my $type = $ref->get_type;
```

### Advanced Methods

#### apply($func)

Applies a function to the reference content.

```perl
$ref->apply(sub { $_[0] * 2 });
```

#### merge($other)

Merges with another rclass object.

```perl
$ref->merge($other_ref);
```

#### size()

Gets the size of the reference.

```perl
my $size = $ref->size;
```

#### clear()

Clears the reference content.

```perl
$ref->clear;
```

#### clone()

Creates a clone of the reference.

```perl
my $clone = $ref->clone;
```

#### equals($other)

Compares with another rclass object for equality.

```perl
if ($ref->equals($other_ref)) {
    print "References are equal\n";
}
```

#### compare($other)

Compares with another rclass object.

```perl
my $result = $ref->compare($other_ref);
```

#### hash_code()

Gets the hash code of the reference.

```perl
my $hash = $ref->hash_code;
```

## Overloaded Operators

rclass overloads the following operators for intuitive reference manipulation:

- Scalar dereference (${})
- Array dereference (@{})
- Hash dereference (%{})
- Code dereference (&{})
- Glob dereference (*{})
- Stringification ("")
- Numeric context (0+)
- Boolean context
- Assignment (=)

## Error Handling

rclass uses the error handling mechanisms provided by xclass. The following error types may be thrown:

- TYPE_ERROR: Thrown when an invalid type is provided to a method.
- OPERATION_ERROR: Thrown when an operation fails or is not supported for the current reference type.

Errors can be caught and handled using eval blocks or try-catch constructs if you're using a module like Try::Tiny.

## Limitations and Caveats

- Some operations may not be supported for all reference types.
- Care should be taken when manipulating references to shared data structures in multi-threaded environments.
- Serialization and deserialization of code references and globs may have limitations.
- Performance may be impacted when dealing with very large data structures.

## Configuration

rclass inherits its configuration options from xclass. There are no specific configuration options for rclass.

## Performance Considerations

- Reference Type: Different reference types may have varying performance characteristics for certain operations.
- Thread Safety: The thread-safe design may introduce some overhead in single-threaded scenarios.
- Large Data Structures: Operations on very large data structures may impact performance.
- Cloning: Deep cloning of complex data structures can be resource-intensive.

## Thread Safety

rclass is designed to be thread-safe. All public methods use lclass synchronization mechanisms to ensure safe concurrent access and modification of references.

## Compatibility

rclass requires Perl version 5.10 or higher due to its use of advanced language features and for optimal performance. It has been developed and tested primarily on Unix-like systems (Linux, macOS) and Windows.

## Dependencies

This module requires the following Perl modules:

- v5.10 or higher
- Scalar::Util (for type checking)
- lclass (for utility methods and thread-safe operations)
- xclass (for handling specific reference types)

## Version

Version 2.0.0

This documentation refers to rclass version 2.0.0.

## See Also

- [`xclass`](xclass.md): eXtended Class - Core of the xclass ecosystem
- [`lclass`](lclass.md): Lock Class - Thread-safe operations, synchronization and Utilities
- [`sclass`](sclass.md): Scalar Class - Advanced scalar value manipulation
- [`aclass`](aclass.md): Array Class - Enhanced array handling and operations
- [`hclass`](hclass.md): Hash Class - Advanced hash manipulation and features
- [`iclass`](iclass.md): IO Class - Input/Output operations and file handling
- [`cclass`](cclass.md): Code Class - Subroutine and code reference management
- [`gclass`](gclass.md): GLOB Class - Advanced GLOB reference manipulation
- [`tclass`](tclass.md): Thread Class - Advanced thread control and management

## Author

OnEhIppY, Domero Software <domerosoftware@gmail.com>

## Copyright and License

Copyright (C) 2024 OnEhIppY, Domero Software

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
