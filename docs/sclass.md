# NAME

sclass - Advanced Scalar Manipulation Class for xclass Ecosystem

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
- [SEE ALSO](#see-also)
- [AUTHOR](#author)
- [COPYRIGHT AND LICENSE](#copyright-and-license)

# DESCRIPTION

The sclass module provides a robust and feature-rich interface for working with
scalar references within the xclass ecosystem. It offers thread-safe operations,
extensive utility methods, and seamless integration with other xclass components.

Key features include:

- Thread-safe scalar operations using lclass synchronization
- Overloaded operators for intuitive scalar manipulation
- Extensive set of utility methods for string and numeric operations
- JSON serialization and deserialization
- Regular expression operations (match, substitute)
- String manipulation (trim, pad, case conversion)
- Numeric operations (increment, decrement, arithmetic)
- Bitwise operations
- Atomic operations (fetch_add, fetch_store, test_set)
- Encryption and hashing methods (base64, MD5, SHA256, SHA512, simple XOR cipher)
- Cloning and comparison methods

## Integration with xclass Ecosystem

sclass inherits core functionality from lclass and can be instantiated directly
or through xclass factory methods. It is registered with the xclass ecosystem
for seamless integration.

## Thread Safety

All methods are designed to be thread-safe when used with shared scalars,
utilizing lclass synchronization mechanisms.

## Performance Considerations

sclass is optimized for both single-threaded and multi-threaded environments
and uses lazy loading of heavy dependencies (e.g., cryptographic libraries).

## Extensibility

The class is designed to be easily extended with additional methods.

## Handling of Circular References

sclass, as part of the xclass ecosystem, inherits the circular reference handling capabilities of xclass. When scalar values are wrapped in sclass objects, any circular references involving these objects are automatically managed.

- Circular references involving sclass objects are safely handled without causing memory leaks.
- Users can create complex data structures involving sclass objects without worrying about circular reference issues.
- The internal implementation ensures that the Perl garbage collector can properly clean up sclass objects involved in circular references.

# SYNOPSIS

```perl
use strict;
use warnings;
use sclass;

# Create a new sclass object
my $scalar = sclass->new(\(my $s = "Hello, World!"));

# Perform operations
$scalar->set("New Value");
$scalar->uc();
$scalar->reverse();
print $scalar->get();  # Prints: EULAV WEN

# Numeric operations
my $num = sclass->new(\(my $n = 5));
$num->inc(3)->mul(2);
print $num->get();  # Prints: 16

# Advanced operations
my $data = sclass->new(\(my $d = "secret"));
$data->encrypt("key")->encode_base64();
print $data->md5();

# Overloaded operators
my $a = sclass->new(\(my $x = 10));
my $b = sclass->new(\(my $y = 5));
my $c = $a + $b;
print "$c";  # Prints: 15
```

# EXAMPLES

## Basic Usage

```perl
use strict;
use warnings;
use xclass;

# Create a new sclass object
my $scalar = Sc(\(my $s = "Hello, World!"));

# Get and set values
print "$scalar";  # Prints: Hello, World!
$scalar->set("New Value");
print "$scalar";  # Prints: New Value

# String manipulations
$scalar->uc();
print $scalar->get();  # Prints: NEW VALUE
$scalar->reverse();
print $scalar->get();  # Prints: EULAV WEN
```

## Numeric Operations

```perl
my $num = Sc(\(my $n = 5));
$num->inc(3)->mul(2); # $num +=3; $num *= 2;
print $num->get();  # Prints: 16

$num->div(4); # $num /= 4;
print $num->get();  # Prints: 4
```

## Regular Expression Operations

```perl
my $text = Sc(\(my $t = "The quick brown fox"));
$text->substitute(qr/quick/, "lazy");
print $text->get();  # Prints: The lazy brown fox

if ($text->match(qr/lazy/)) {
    print "Match found!";
}
```

## Encryption and Hashing

```perl
my $data = Sc(\(my $d = "secret"));
$data->encrypt("key");
print $data->get();  # Prints: encrypted data

$data->decrypt("key");
print $data->get();  # Prints: secret

print $data->md5();  # Prints: MD5 hash of "secret"
```

## Base64 Encoding/Decoding

```perl
my $base64 = Sc(\(my $b = "Hello, World!"));
$base64->encode_base64();
print $base64->get();  # Prints: SGVsbG8sIFdvcmxkIQ==

$base64->decode_base64();
print $base64->get();  # Prints: Hello, World!
```

## JSON Serialization

```perl
my $json = Sc(\(my $j = { key => "value" }));
$json->to_json();
print $json->get();  # Prints: {"key":"value"}

$json->from_json('{"new_key":"new_value"}');
print $json->get();  # Prints: {"new_key":"new_value"}
```

## Atomic Operations

```perl
my $atomic = Sc(\(my $a = 10));
my $old_value = $atomic->fetch_add(5);
print "Old: $old_value, New: ", $atomic->get();  # Prints: Old: 10, New: 15

$atomic->test_set(20);
print $atomic->get();  # Prints: 20
```

## Using Overloaded Operators

```perl
my $a = Sc(\(my $x = 10));
my $b = Sc(\(my $y = 5));

my $c = $a + $b;
print "$c";  # Prints: 15

$a *= 2;
print $a->get();  # Prints: 20

if ($a > $b) {
    print "a is greater than b";
}
```

## Error Handling

```perl
my $div = Sc(\(my $d = 10));
$div->try(sub {
    $div->div(0); # $div /= 0;
}, 'division_operation');

if ($div->catch('division_operation')) {
    print "Division by zero caught!";
}
```

## Thread-Safe Operations

```perl
use threads;
use threads::shared;

my $shared = sclass->new(\(my $s :shared = 0));

my @threads = map {
    threads->create(sub {
        for (1..1000) {
            $shared->inc(); # $shared ++;
        }
    });
} 1..5;

$_->join for @threads;

print "$shared";  # Prints: 5000
```

These examples demonstrate the key features and usage patterns of the sclass module, including basic operations, numeric manipulations, regular expressions, encryption, hashing, atomic operations, overloaded operators, error handling, and thread-safe operations.

# METHODS

## Constructor

### new($ref, %options)

Creates a new sclass object.

```perl
my $scalar = sclass->new(\(my $value = "Hello"));
```

## Core Methods

### get()

Retrieves the value of the scalar.

### set($ref)

Sets the value of the scalar.

### modify($code)

Modifies the scalar value using a code block.

## String Operations

### chomp()

Removes the trailing newline from the scalar.

### chop()

Removes the last character from the scalar.

### uc()

Converts the scalar to uppercase.

### lc()

Converts the scalar to lowercase.

### reverse()

Reverses the scalar value.

### trim()

Trims whitespace from the beginning and end of the scalar.

### pad($length, $pad_char = ' ', $pad_left = 1)

Pads the scalar with a specified character.

### sstr(@args)

Returns a substring of the scalar.

## Numeric Operations

### inc($value = 1)

Increments the scalar value.

### dec($value = 1)

Decrements the scalar value.

### mul($value)

Multiplies the scalar value.

### div($value)

Divides the scalar value.

## Type Checking and Conversion

### is_numeric()

Checks if the scalar value is numeric.

### to_number()

Converts the scalar value to a number.

### is_empty()

Checks if the scalar value is empty.

### len()

Returns the length of the scalar value.

## Serialization

### to_json()

Converts the scalar to a JSON string.

### from_json($json_string)

Loads a JSON string into the scalar.

## Regular Expression Operations

### match($regex)

Performs a regular expression match on the scalar.

### substitute($regex, $replacement, $global = 0)

Performs a regular expression substitution on the scalar.

## Advanced Operations

### encrypt($key)

Encrypts the scalar using a simple XOR cipher.

### decrypt($key)

Decrypts the scalar using a simple XOR cipher.

### md5()

Calculates the MD5 hash of the scalar.

### sha256()

Calculates the SHA256 hash of the scalar.

### sha512()

Calculates the SHA512 hash of the scalar.

### encode_base64()

Encodes the scalar to base64.

### decode_base64()

Decodes the scalar from base64.

## Atomic Operations

### fetch_add($value)

Atomically fetches and adds to the scalar.

### fetch_store($new_value)

Atomically fetches and stores a new value.

### test_set($new_value)

Atomically tests and sets a new value.

## Utility Methods

### clone()

Creates a deep copy of the sclass object.

### contains($substring)

Checks if the scalar contains a specific substring.

### replace_all($search, $replace)

Replaces all occurrences of a substring.

### to_bool()

Converts the scalar to a boolean value.

### eq_ignore_case($other)

Performs a case-insensitive comparison.

### count_occurrences($substring)

Counts occurrences of a substring.

### truncate($length, $ellipsis = '...')

Truncates the scalar to a specified length.

# OVERLOADED OPERATORS

sclass overloads the following operators for intuitive scalar manipulation:

- Stringification ("")
- Numification (0+)
- Boolean context
- Negation (!)
- Assignment (=)
- Equality (==, !=)
- Comparison (cmp, <=>)
- Arithmetic (+, -, *, /, %, **)
- Bitwise (<<, >>, &, |, ^, ~)
- String operations (.=, x)
- In-place arithmetic (+=, -=, *=, /=, %=, **=)
- Increment and decrement (++, --)

# ERROR HANDLING

sclass uses the error handling mechanisms provided by lclass. Exceptions are thrown using the `throw` method inherited from lclass. Errors can be caught using the `try` method:

```perl
$scalar->try(sub {
    $scalar->div(0);
}, 'division_operation');
```

For more details on error handling, refer to the lclass documentation.

# LIMITATIONS AND CAVEATS

- The encryption method provided is a simple XOR cipher and should not be used for secure encryption in production environments.
- Performance may be impacted in heavily multi-threaded environments due to locking mechanisms.
- Some operations may create temporary objects, which could impact memory usage in large-scale applications.

# CONFIGURATION

sclass inherits its configuration options from lclass. Refer to the lclass documentation for details on available configuration options.

# PERFORMANCE CONSIDERATIONS

- Lazy Loading: Heavy dependencies are loaded on demand.
- Overloaded Operators: May introduce slight performance overhead compared to direct method calls.
- Thread Safety: Introduces some overhead in multi-threaded environments due to locking mechanisms.
- Memory Usage: Each sclass object maintains its own scalar reference.

# THREAD SAFETY

sclass is designed to be thread-safe, leveraging the synchronization mechanisms provided by lclass. All methods, including overloaded operators, are implemented using lclass's synchronization primitives.

To use an sclass object across multiple threads, you need to explicitly share it:

```perl
my $scalar = sclass->new(\(my $value = "Shared Value"))->share();
```

# COMPATIBILITY

sclass requires Perl version 5.10 or higher. It has been developed and tested primarily on Unix-like systems (Linux, macOS) and Windows.

# SEE ALSO

- [`xclass`](xclass.md): eXtended Class - Core of the xclass ecosystem
- [`lclass`](lclass.md): Lock Class - Thread-safe operations, synchronization and Utilities
- [`aclass`](aclass.md): Array Class - Enhanced array handling and operations
- [`hclass`](hclass.md): Hash Class - Advanced hash manipulation and features
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
