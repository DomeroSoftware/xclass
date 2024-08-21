# NAME

aclass - Advanced Array Manipulation Class for xclass Ecosystem

# TABLE OF CONTENTS

- [DESCRIPTION](#description)
- [SYNOPSIS](#synopsis)
- [EXAMPLES](#examples)
- [METHODS](#methods)
- [OVERLOADED OPERATORS](#overloaded-operators)
- [ERROR HANDLING](#error-handling)
- [LIMITATIONS AND CAVEATS](#limitations-and-caveats)
- [CONFIGURATION](#configuration)
- [PERFORMANCE CONSIDERATIONS](#performance-considerations)
- [THREAD SAFETY](#thread-safety)
- [COMPATIBILITY](#compatibility)
- [DEPENDENCIES](#dependencies)
- [VERSION](#version)
- [SEE ALSO](#see-also)
- [AUTHOR](#author)
- [COPYRIGHT AND LICENSE](#copyright-and-license)

# DESCRIPTION

The aclass module provides a robust and feature-rich interface for working with
array references within the xclass ecosystem. It offers thread-safe operations,
extensive utility methods, and seamless integration with other xclass components.

Key features include:

- Thread-safe array operations using lclass synchronization
- Overloaded operators for intuitive array manipulation
- Extensive set of utility methods for array operations
- Element-wise type handling using xclass
- Support for functional programming paradigms (map, grep, reduce)
- Advanced operations like slicing, atomic updates, and compare-and-swap
- Iterators for efficient traversal
- Integration with xclass event system for operation tracking

## Integration with xclass Ecosystem

aclass inherits core functionality from lclass and can be instantiated directly
or through xclass factory methods. It implements the xclass event system for
operation tracking and uses xclass for element-wise type handling.

## Thread Safety

All methods in aclass are designed to be thread-safe when used with shared arrays,
utilizing lclass synchronization mechanisms.

## Performance Considerations

aclass is optimized for both single-threaded and multi-threaded environments.
It uses lazy initialization of element handlers and efficient locking strategies.

## Extensibility

The class is designed to be easily extended with additional methods and
supports custom event triggers for all operations.

## Handling of Circular References

aclass provides robust handling of circular references within array structures. As part of the xclass ecosystem, it leverages the built-in circular reference management capabilities.

- Arrays can contain references to other aclass objects or to objects of other xclass types without causing issues.
- Circular references within nested array structures are automatically detected and managed.
- The garbage collection process correctly handles aclass objects involved in circular references, preventing memory leaks.
- Users can freely create complex, self-referential data structures using aclass without manual intervention.

# SYNOPSIS

```perl
use strict;
use warnings;
use aclass;

# Create a new aclass object
my $array = aclass->new([1, 2, 3, 4, 5]);

# Basic operations
$array->push(6)->unshift(0);
print $array->join(', ');  # Prints: 0, 1, 2, 3, 4, 5, 6

# Functional operations
$array->map(sub { $_ * 2 })->grep(sub { $_ > 5 });
print $array->join(', ');  # Prints: 6, 8, 10, 12

# Advanced operations
my $sum = $array->reduce(sub { $a + $b });
print "Sum: $sum";  # Prints: Sum: 36

# Overloaded operators
my $a = aclass->new([1, 2, 3]);
my $b = aclass->new([4, 5, 6]);
my $c = $a + $b;
print $c->join(', ');  # Prints: 1, 2, 3, 4, 5, 6

# Atomic operations
$array->compare_and_swap(0, 6, 7);
$array->atomic_update(1, sub { $_ * 3 });

# Iteration
my $iter = $array->iterator();
while (my $elem = $iter->()) {
    print "$elem ";
}
```

# EXAMPLES

## Data Processing Pipeline

```perl
use aclass;
use List::Util qw(sum);

my $readings = aclass->new([23.1, 22.8, 24.3, 23.9, 22.5, 24.1]);

my $result = $readings
    ->map(sub { $_ * 1.8 + 32 })  # Convert Celsius to Fahrenheit
    ->grep(sub { $_ > 75 })       # Filter readings above 75°F
    ->map(sub { sprintf "%.1f°F", $_ });  # Format for display

print "High temperature readings: " . $result->join(", ") . "\n";

my $avg = $readings->reduce(sub { $a + $b }) / $readings->len;
printf "Average temperature: %.1f°C\n", $avg;
```

## Custom Sorting and Filtering

```perl
use aclass;

my $people = aclass->new([
    { name => "Alice", age => 30 },
    { name => "Bob", age => 25 },
    { name => "Charlie", age => 35 },
    { name => "David", age => 28 },
]);

# Sort people by age
$people->sort(sub { $a->{age} <=> $b->{age} });

# Filter people over 30
my $over_30 = $people->grep(sub { $_->{age} > 30 });

# Map to just names
my $names = $people->map(sub { $_->{name} });

print "All names: " . $names->join(", ") . "\n";
print "People over 30: " . $over_30->map(sub { $_->{name} })->join(", ") . "\n";
```

## Dynamic Array Manipulation

```perl
use aclass;

my $dynamic_array = aclass->new([1, 2, 3, 4, 5]);

# Remove even numbers and double odd numbers
$dynamic_array->foreach(sub {
    if ($_ % 2 == 0) {
        $dynamic_array->splice($dynamic_array->first(sub { $_ == $_ }), 1);
    } else {
        $dynamic_array->set($dynamic_array->first(sub { $_ == $_ }), $_ * 2);
    }
});

print "Modified array: " . $dynamic_array->join(", ") . "\n";
```

# METHODS

## Constructor

### new($ref?, %options)

Creates a new aclass object.

```perl
my $array = aclass->new([1, 2, 3]);
```

## Core Methods

### get($index?)

Retrieves element(s) from the array.

```perl
my $elem = $array->get(0);
my @all = $array->get();
```

### set($index, $value)

Sets an element in the array.

```perl
$array->set(0, 10);
```

### push(@values)

Pushes elements to the end of the array.

```perl
$array->push(4, 5, 6);
```

### pop()

Pops an element from the end of the array.

```perl
my $last = $array->pop();
```

### shift()

Shifts an element from the beginning of the array.

```perl
my $first = $array->shift();
```

### unshift(@values)

Unshifts elements to the beginning of the array.

```perl
$array->unshift(-1, 0);
```

### len()

Returns the length of the array.

```perl
my $length = $array->len();
```

### sort($body?)

Sorts the array.

```perl
$array->sort(sub { $a <=> $b });
```

### reverse()

Reverses the array.

```perl
$array->reverse();
```

### splice($offset, $length?, @list)

Splices the array.

```perl
my @removed = $array->splice(1, 2, 'a', 'b');
```

### join($delimiter)

Joins array elements into a string.

```perl
my $str = $array->join(', ');
```

### clear()

Clears the array.

```perl
$array->clear();
```

## Functional Methods

### map($coderef)

Applies a function to each element.

```perl
$array->map(sub { $_ * 2 });
```

### grep($coderef)

Filters elements based on a condition.

```perl
$array->grep(sub { $_ > 5 });
```

### reduce($coderef)

Reduces the array to a single value.

```perl
my $sum = $array->reduce(sub { $a + $b });
```

### foreach($coderef)

Iterates over array elements.

```perl
$array->foreach(sub { print "$_ " });
```

### first($coderef)

Finds the first element matching a condition.

```perl
my $first_even = $array->first(sub { $_ % 2 == 0 });
```

### last($coderef)

Finds the last element matching a condition.

```perl
my $last_odd = $array->last(sub { $_ % 2 != 0 });
```

## Mathematical Methods

### sum()

Calculates the sum of array elements.

```perl
my $sum = $array->sum();
```

### min()

Finds the minimum value in the array.

```perl
my $min = $array->min();
```

### max()

Finds the maximum value in the array.

```perl
my $max = $array->max();
```

## Advanced Methods

### unique()

Removes duplicate elements from the array.

```perl
$array->unique();
```

### slice($start, $end)

Gets a slice of the array.

```perl
my $slice = $array->slice(1, 3);
```

### compare_and_swap($index, $old_value, $new_value)

Performs a compare-and-swap operation.

```perl
my $success = $array->compare_and_swap(0, 1, 10);
```

### atomic_update($index, $coderef)

Performs an atomic update on an element.

```perl
$array->atomic_update(0, sub { $_ * 2 });
```

### iterator()

Creates an iterator for the array.

```perl
my $iter = $array->iterator();
while (my $elem = $iter->()) {
    print "$elem ";
}
```

# OVERLOADED OPERATORS

aclass overloads the following operators for intuitive array manipulation:

- Dereferencing (@{}, ${}, %{})
- Stringification ("")
- Numification (0+)
- Boolean context
- Negation (!)
- Assignment (=)
- Equality (==, !=)
- Comparison (cmp, <=>)
- Arithmetic (+, -)
- Multiplication (*)
- Bitwise (&, |, ^, ~)
- String operations (x)
- Append (.=)
- Left shift (<<)
- Right shift (>>)

Examples of overloaded operator usage:

```perl
my $a = aclass->new([1, 2, 3]);
my $b = aclass->new([4, 5, 6]);

# Addition
my $c = $a + $b;  # [1, 2, 3, 4, 5, 6]

# Multiplication
my $d = $a * 2;   # [1, 2, 3, 1, 2, 3]

# Stringification
print "$a";       # "1,2,3"

# Boolean context
if ($a) {
    print "Array is not empty";
}
```

# ERROR HANDLING

aclass uses the error handling mechanisms provided by lclass. The following error codes may be thrown:

- ACLASS_INDEX_ERROR: Thrown when an invalid index is accessed.
- ACLASS_TYPE_ERROR: Thrown when there's a type mismatch in element-wise operations.
- ACLASS_EMPTY_ARRAY_ERROR: Thrown when attempting operations on an empty array.
- ACLASS_INVALID_ARGUMENT: Thrown when invalid arguments are passed to methods.
- ACLASS_SLICE_ERROR: Thrown when an invalid slice range is specified.

Errors can be caught and handled using eval blocks or try-catch constructs if you're using a module like Try::Tiny.

# LIMITATIONS AND CAVEATS

[This section will be filled with known limitations or caveats of using aclass as they are discovered during development and usage.]

# CONFIGURATION

aclass inherits its configuration options from lclass. Refer to the lclass documentation for configuration options.

# PERFORMANCE CONSIDERATIONS

- Lazy Initialization: Element handlers are initialized on-demand to minimize overhead.
- Efficient Locking: Fine-grained locking is used to maximize concurrency in multi-threaded environments.
- Overloaded Operators: While convenient, overloaded operators may introduce slight performance overhead compared to direct method calls.
- Large Arrays: Performance may degrade with very large arrays due to the overhead of maintaining element handlers.

# THREAD SAFETY

aclass is designed to be thread-safe when used with shared arrays. All public methods use lclass synchronization mechanisms to ensure safe concurrent access and modification of the underlying array.

# COMPATIBILITY

aclass requires Perl version 5.10 or higher due to its use of advanced language features and for optimal performance. It has been developed and tested primarily on Unix-like systems (Linux, macOS) and Windows.

# DEPENDENCIES

This module requires the following Perl modules:

- v5.10 or higher
- Scalar::Util
- List::Util
- lclass (for utility methods and thread-safe operations)
- xclass (for handling specific reference types)

# VERSION

Version 2.0.0

This documentation refers to aclass version 2.0.0.

# AUTHOR

OnEhIppY, Domero Software <domerosoftware@gmail.com>

# COPYRIGHT AND LICENSE

Copyright (C) 2024 OnEhIppY, Domero Software

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# See Also

- [`xclass`](xclass.md): eXtended Class - Core of the xclass ecosystem
- [`lclass`](lclass.md): Lock Class - Thread-safe operations, synchronization and Utilities
- [`sclass`](sclass.md): Scalar Class - Advanced scalar value manipulation
- [`hclass`](hclass.md): Hash Class - Advanced hash manipulation and features
- [`iclass`](iclass.md): IO Class - Input/Output operations and file handling
- [`cclass`](cclass.md): Code Class - Subroutine and code reference management
- [`gclass`](gclass.md): GLOB Class - Advanced GLOB reference manipulation
- [`rclass`](rclass.md): Reference Class - Generic reference type handling
- [`tclass`](tclass.md): Thread Class - Advanced thread control and management

