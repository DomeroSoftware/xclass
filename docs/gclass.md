# gclass - Advanced GLOB Reference Manipulation Class for xclass Ecosystem

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

The gclass module provides a robust and feature-rich interface for working with
GLOB references within the xclass ecosystem. It offers thread-safe operations
on global variables, including scalars, arrays, hashes, code references, and
IO handles, with seamless integration into the xclass framework.

Key features include:

- Thread-safe GLOB reference operations using lclass synchronization
- Overloaded operators for intuitive GLOB manipulation
- Comprehensive handling of all GLOB components (SCALAR, ARRAY, HASH, CODE, IO)
- Support for shared GLOBs across threads
- Integration with xclass for type-specific handling of GLOB components
- Advanced operations: cloning, merging, comparison

### Integration with xclass Ecosystem

gclass inherits core functionality from lclass and can be instantiated directly
or through xclass factory methods. It implements the xclass event system for
operation tracking and utilizes xclass for type-specific handling of GLOB components.

### Thread Safety

All methods in gclass are designed to be thread-safe, with support for shared GLOBs across threads.

### Performance Considerations

gclass is optimized for both single-threaded and multi-threaded environments,
with efficient handling of GLOB components.

### Extensibility

The class is designed to be easily extended with additional methods and
supports custom event triggers for all operations.

### Handling of Circular References

gclass, managing GLOB references, incorporates the xclass ecosystem's circular reference handling capabilities.

- GLOB references can safely contain or be contained within other xclass objects without causing reference loops.
- Circular references involving any combination of scalar, array, hash, or code references within the GLOB are automatically managed.
- The garbage collection process correctly cleans up gclass objects involved in circular references.
- Complex data structures involving GLOBs and other xclass objects can be created without manual circular reference management.

## Synopsis

```perl
use strict;
use warnings;
use gclass;

# Create a new gclass object
my $glob = gclass->new(space => 'main', name => 'my_glob');

# Set GLOB components
$glob->SCALAR(42)
     ->ARRAY([1, 2, 3])
     ->HASH({a => 1, b => 2});

# Access GLOB components
my $scalar_value = $glob->SCALAR->get;
my $array_ref = $glob->ARRAY;
my $hash_ref = $glob->HASH;

# Clone and merge GLOBs
my $clone = $glob->clone('my_clone');
$glob->merge($other_glob);

# Compare GLOBs
if ($glob->equals($other_glob)) {
    print "GLOBs are equal\n";
}
```

## Examples

### Using Overloaded Operators

#### Scalar Dereference

```perl
my $glob = gclass->new(space => 'main', name => 'my_glob');
$glob->SCALAR(42);

# Using overloaded scalar dereference
print ${$glob};  # Prints 42

# Standard class way
print $glob->SCALAR->get;  # Prints 42
```

#### Array Dereference

```perl
$glob->ARRAY([1, 2, 3]);

# Using overloaded array dereference
push @{$glob}, 4;  # Adds 4 to the array
print join(', ', @{$glob});  # Prints 1, 2, 3, 4

# Standard class way
$glob->ARRAY->push(5);
print $glob->ARRAY->join(', ');  # Prints 1, 2, 3, 4, 5
```

#### Hash Dereference

```perl
$glob->HASH({a => 1, b => 2});

# Using overloaded hash dereference
${$glob}{c} = 3;
print ${$glob}{a};  # Prints 1

# Standard class way
$glob->HASH->set('d', 4);
print $glob->HASH->get('b');  # Prints 2
```

#### Code Dereference

```perl
$glob->CODE(sub { print "Hello, World!\n" });

# Using overloaded code dereference
&{$glob}();  # Prints "Hello, World!"

# Standard class way
$glob->CODE->call();  # Prints "Hello, World!"
```

#### IO Dereference

```perl
$glob->IO(\*STDOUT);

# Using overloaded IO dereference
print {*{$glob}} "Test\n";  # Prints "Test" to STDOUT

# Standard class way
$glob->IO->print("Test\n");  # Prints "Test" to STDOUT
```

#### Stringification

```perl
$glob->SCALAR("Test String");

# Using overloaded stringification
print "$glob";  # Prints "Test String"

# Standard class way
print $glob->to_string;  # Prints "Test String"
```

#### Numeric Context

```perl
$glob->SCALAR(42);

# Using overloaded numeric context
print $glob + 8;  # Prints 50

# Standard class way
print $glob->SCALAR->get + 8;  # Prints 50
```

#### Boolean Context

```perl
# Using overloaded boolean context
if ($glob) {
    print "GLOB exists\n";
}

# Standard class way
if ($glob->exists) {
    print "GLOB exists\n";
}
```

#### Assignment

```perl
my $new_glob = gclass->new(space => 'main', name => 'new_glob');
$new_glob = $glob;  # Assigns $glob to $new_glob
```

### xclass Integration

#### Using xclass Factory Method

```perl
use xclass;

my $glob = Gc('main', 'my_glob');
$glob->SCALAR(42);
```

#### Converting Perl GLOB to gclass

```perl
my $perl_glob = \*STDOUT;
my $gclass_glob = Xc($perl_glob);
```

#### Using xclass Type-Specific Methods

```perl
$glob->ARRAY(Ac([1, 2, 3]));
$glob->HASH(Hc({a => 1, b => 2}));
```

### lclass Utilization

#### Thread-Safe Operations

```perl
use threads;
use threads::shared;

my $shared_glob = gclass->new(space => 'main', name => 'shared_glob', is_shared => 1);
$shared_glob->SCALAR(0);

my @threads = map {
    threads->create(sub {
        for (1..1000) {
            $shared_glob->SCALAR->atomic_add(1);
        }
    });
} 1..10;

$_->join for @threads;
print ${$shared_glob->SCALAR};  # Should print 10000
```

#### Error Handling

```perl
eval {
    $glob->throw("An error occurred", 'CUSTOM_ERROR');
};
if ($@) {
    print "Caught error: $@\n";
}
```

#### Event Triggering

```perl
$glob->on('change', sub {
    my ($self, $event) = @_;
    print "GLOB changed: $event->{component}\n";
});

$glob->SCALAR(100);  # Triggers 'change' event
```

## Methods

### Constructor

#### new($space, $name, %options)

Creates a new gclass object.

```perl
my $glob = gclass->new(space => 'main', name => 'my_glob');
```

### Core Methods

#### set($glob_ref)

Sets the GLOB reference.

```perl
$glob->set(\*main::STDOUT);
```

#### get()

Gets the GLOB reference.

```perl
my $glob_ref = $glob->get();
```

#### exists()

Checks if the GLOB exists.

```perl
if ($glob->exists()) {
    print "GLOB exists\n";
}
```

### GLOB Component Methods

#### SCALAR($value)

Gets or sets the SCALAR component of the GLOB.

```perl
$glob->SCALAR(42);
my $scalar_value = $glob->SCALAR->get;
```

#### ARRAY($value)

Gets or sets the ARRAY component of the GLOB.

```perl
$glob->ARRAY([1, 2, 3]);
my $array_ref = $glob->ARRAY;
```

#### HASH($value)

Gets or sets the HASH component of the GLOB.

```perl
$glob->HASH({a => 1, b => 2});
my $hash_ref = $glob->HASH;
```

#### CODE($value)

Gets or sets the CODE component of the GLOB.

```perl
$glob->CODE(sub { print "Hello, World!\n" });
my $code_ref = $glob->CODE;
```

#### IO($value)

Gets or sets the IO component of the GLOB.

```perl
$glob->IO(\*STDOUT);
my $io_ref = $glob->IO;
```

### Advanced Methods

#### clone($clone_name)

Creates a clone of the GLOB.

```perl
my $clone = $glob->clone('my_clone');
```

#### merge($other_glob)

Merges another gclass object into this one.

```perl
$glob->merge($other_glob);
```

#### equals($other_glob)

Compares this GLOB with another for equality.

```perl
if ($glob->equals($other_glob)) {
    print "GLOBs are equal\n";
}
```

#### compare($other_glob)

Compares this GLOB with another, returning -1, 0, or 1.

```perl
my $result = $glob->compare($other_glob);
```

#### hash_code()

Returns a hash code for the GLOB.

```perl
my $hash = $glob->hash_code();
```

## Overloaded Operators

gclass overloads the following operators for intuitive GLOB manipulation:

- Scalar dereference (${})
- Array dereference (@{})
- Hash dereference (%{})
- Code dereference (&{})
- GLOB dereference (*{})
- Stringification ("")
- Numeric context (0+)
- Boolean context
- Assignment (=)

## Error Handling

gclass uses the error handling mechanisms provided by lclass. Errors can be thrown using the `throw` method and caught using eval blocks or try-catch constructs.

## Limitations and Caveats

- Care should be taken when manipulating GLOBs that are used elsewhere in the program.
- Shared GLOBs may have performance implications in highly concurrent scenarios.
- Not all GLOB operations may be available or behave the same way across different Perl versions.

## Configuration

gclass inherits its configuration options from lclass. Specific options for gclass include:

- space: The package namespace for the GLOB (default: 'main').
- name: The name of the GLOB within the specified namespace.
- is_shared: Whether the GLOB should be shared across threads (default: false).

## Performance Considerations

- Shared GLOBs: Using shared GLOBs may introduce some performance overhead due to locking mechanisms.
- GLOB Component Access: Direct component access (e.g., SCALAR, ARRAY) is optimized for performance.
- Cloning and Merging: These operations may be expensive for large GLOBs.
- Thread Safety: The thread-safe design may introduce some overhead in single-threaded scenarios.

## Thread Safety

gclass is designed to be thread-safe. All public methods use lclass synchronization mechanisms to ensure safe concurrent access and modification of GLOB references. The 'is_shared' option allows for GLOBs to be safely shared across threads.

## Compatibility

gclass requires Perl version 5.10 or higher due to its use of advanced language features and for optimal performance.

## Dependencies

This module requires the following Perl modules:

- v5.10 or higher
- threads
- threads::shared
- Scalar::Util
- Time::HiRes
- lclass
- xclass

## Version

Version 2.0.0

This documentation refers to gclass version 2.0.0.

## See Also

- [`xclass`](xclass.md): eXtended Class - Core of the xclass ecosystem
- [`lclass`](lclass.md): Lock Class - Thread-safe operations, synchronization and Utilities
- [`sclass`](sclass.md): Scalar Class - Advanced scalar value manipulation
- [`aclass`](aclass.md): Array Class - Enhanced array handling and operations
- [`hclass`](hclass.md): Hash Class - Advanced hash manipulation and features
- [`iclass`](iclass.md): IO Class - Input/Output operations and file handling
- [`cclass`](cclass.md): Code Class - Subroutine and code reference management
- [`rclass`](rclass.md): Reference Class - Generic reference type handling
- [`tclass`](tclass.md): Thread Class - Advanced thread control and management

## See Also

xclass, lclass, hclass, aclass, sclass, cclass, iclass, rclass, tclass

## Author

OnEhIppY, Domero Software <domerosoftware@gmail.com>

## Copyright and License

Copyright (C) 2024 OnEhIppY, Domero Software

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
