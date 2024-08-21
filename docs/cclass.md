# NAME

cclass - Advanced Code Reference Manipulation Class for xclass Ecosystem

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

The cclass module provides a robust and feature-rich interface for working with
code references within the xclass ecosystem. It offers thread-safe operations,
advanced function manipulation, and seamless integration with other xclass components.

Key features include:

- Thread-safe code reference operations using lclass synchronization
- Overloaded operators for intuitive code reference manipulation
- Advanced function manipulation: memoization, currying, composition
- Execution control: throttling, debouncing, retrying with backoff
- Performance analysis: timing and profiling
- Thread management: creation, detaching, and joining
- Integration with xclass for result wrapping and type handling

## Integration with xclass Ecosystem

cclass inherits core functionality from lclass and can be instantiated directly
or through xclass factory methods. It implements the xclass event system for
operation tracking and uses xclass for result wrapping and type handling.

## Thread Safety

All methods in cclass are designed to be thread-safe, utilizing lclass synchronization mechanisms.

## Performance Considerations

cclass is optimized for both single-threaded and multi-threaded environments.
It uses efficient handling of function composition and chaining.

## Extensibility

The class is designed to be easily extended with additional methods and
supports custom event triggers for all operations.

## Handling of Circular References

cclass, while primarily dealing with code references, is also equipped to handle circular references as part of the xclass ecosystem.

- Code references wrapped by cclass can safely reference other xclass objects, including other cclass objects.
- Any circular references created through closures or shared data structures are automatically managed.
- The garbage collector correctly handles cclass objects involved in circular references.
- Users can create complex callback structures or event systems without worrying about circular reference management.

# SYNOPSIS

```perl
use strict;
use warnings;
use cclass;

# Create a new cclass object
my $func = cclass->new(sub { $_[0] + $_[1] });

# Basic usage
my $result = $func->call(2, 3);  # Returns 5

# Advanced usage
$func->memoize()->throttle(5)->retry(3, 1);
$result = $func->call(2, 3);  # Returns 5, memoized and throttled

# Function composition
my $composed = $func->compose(sub { $_[0] * 2 }, sub { $_[0] + 1 });
$result = $composed->call(2, 3);  # Returns 11 ((2+3)*2 + 1)

# Threading
my $thread = $func->create_thread(2, 3);
$thread->join;
```

# EXAMPLES

## Memoization and Throttling

```perl
my $expensive_func = cclass->new(sub {
    my ($x, $y) = @_;
    sleep(1);  # Simulate expensive computation
    return $x * $y;
});

$expensive_func->memoize()->throttle(2);

for my $i (1..5) {
    my $result = $expensive_func->call(2, 3);
    print "Result: $result\n";
}
```

This example demonstrates memoization and throttling of an expensive function.

## Retry with Exponential Backoff

```perl
my $unreliable_func = cclass->new(sub {
    die "Random failure" if rand() < 0.7;
    return "Success";
});

$unreliable_func->retry_with_backoff(5, 1, 10);

eval {
    my $result = $unreliable_func->call();
    print "Result: $result\n";
};
if ($@) {
    print "Function failed after multiple retries: $@\n";
}
```

This example shows how to use retry with exponential backoff for an unreliable function.

## Profiling and Timing

```perl
my $func_to_profile = cclass->new(sub {
    my $sum = 0;
    for (1..1000) {
        $sum += $_;
    }
    return $sum;
});

my $profile_result = $func_to_profile->profile(1000);
print "Average execution time: $profile_result->{average_time} seconds\n";

my $timed_result = $func_to_profile->time();
print "Single execution time: $timed_result->{time} seconds\n";
print "Result: $timed_result->{result}\n";
```

## Function Call Overloading

There are multiple ways to call a cclass object:

```perl
my $add = cclass->new(sub { $_[0] + $_[1] });

# Standard method call
print $add->call(2, 3), "\n";  # Outputs: 5

# Using overloaded function call
print $add->(2, 3), "\n";      # Outputs: 5

# Using &{} dereferencing
print &{$add}(2, 3), "\n";     # Outputs: 5
```

## Stringification

The stringification overload in cclass provides a meaningful representation of the wrapped code reference:

```perl
my $add = cclass->new(sub { $_[0] + $_[1] });
print "$add\n";
# Outputs something like:
# cclass(CODE(0x55f5e0c5f550))
# sub { $_[0] + $_[1] }

my $complex_func = cclass->new(sub {
    my ($x, $y) = @_;
    if ($x > $y) {
        return $x - $y;
    } else {
        return $y - $x;
    }
});

print "$complex_func\n";    # Outputs something like:

# cclass(CODE(0x55f5e0c5f668))
# sub {
#     my($x, $y) = @_;
#     if ($x > $y) {
#         return $x - $y;
#     }
#     else {
#         return $y - $x;
#     }
# }
```

This stringification provides both the memory address of the code reference and a decompiled representation of the function, which can be useful for debugging and introspection.

## Numification

In numeric contexts, a cclass object is treated as a number:

```perl
my $func = cclass->new(sub { 42 });
print 0 + $func, "\n";  # Outputs: 1 (true, because the function is defined)
```

## Boolean Context

cclass objects can be used in boolean contexts:

```perl
my $func = cclass->new(sub { 1 });
if ($func) {
    print "Function is defined\n";
}
```

## Negation

The negation operator is overloaded:

```perl
my $func = cclass->new(sub { 0 });
if (!$func) {
    print "This won't be printed because the function is defined\n";
}
```

## Equality Comparison

cclass objects can be compared for equality:

```perl
my $func1 = cclass->new(sub { 1 });
my $func2 = cclass->new(sub { 1 });
my $func3 = $func1->clone();

print "func1 == func2: ", ($func1 == $func2 ? "true" : "false"), "\n";  # Likely false
print "func1 == func3: ", ($func1 == $func3 ? "true" : "false"), "\n";  # True

print "func1 != func2: ", ($func1 != $func2 ? "true" : "false"), "\n";  # Likely true
```

## Comparison

cclass objects can be compared using string comparison operators:

```perl
my $func1 = cclass->new(sub { "a" });
my $func2 = cclass->new(sub { "b" });

print "func1 cmp func2: ", ($func1 cmp $func2), "\n";  # Outputs: -1, 0, or 1
print "func1 <=> func2: ", ($func1 <=> $func2), "\n";  # Outputs: -1, 0, or 1
```

## Composition

Functions can be composed using the . operator:

```perl
my $add_one = cclass->new(sub { $_[0] + 1 });
my $double = cclass->new(sub { $_[0] * 2 });

my $composed = $add_one . $double;
print $composed->(3), "\n";  # Outputs: 8 ((3+1)*2)
```

## Memoization

Demonstrate memoization with cache size and expiration:

```perl
my $fibonacci = cclass->new(sub {
    my ($n) = @_;
    return $n if $n < 2;
    return $fibonacci->($n-1) + $fibonacci->($n-2);
});

$fibonacci->memoize(100, 3600);  # Cache up to 100 results for 1 hour
print $fibonacci->(30), "\n";  # First call is slow
print $fibonacci->(30), "\n";  # Second call is fast due to memoization
```

## Throttling

Demonstrate throttling to limit call frequency:

```perl
my $api_call = cclass->new(sub {
    print "API called at " . localtime() . "\n";
    return "API result";
});

$api_call->throttle(2);  # Limit to one call every 2 seconds

for (1..5) {
    $api_call->();
}
```

## Retry with Backoff

Show retry functionality with exponential backoff:

```perl
my $unreliable_func = cclass->new(sub {
    die "Random failure" if rand() < 0.7;
    return "Success";
});

$unreliable_func->retry_with_backoff(5, 1, 10);

eval {
    my $result = $unreliable_func->();
    print "Result: $result\n";
};
if ($@) {
    print "Function failed after multiple retries: $@\n";
}
```

## Profiling

Profile a function's performance:

```perl
my $func_to_profile = cclass->new(sub {
    my $sum = 0;
    $sum += $_ for 1..1000;
    return $sum;
});

my $profile = $func_to_profile->profile(100);
print "Average time: $profile->{average_time} seconds\n";
```

## Threading

Demonstrate thread creation and management:

```perl
my $threaded_func = cclass->new(sub {
    my ($id) = @_;
    return "Thread $id completed";
});

my $thread = $threaded_func->create_thread(1);
my $result = $thread->join;
print $result, "\n";
```

These examples showcase the various ways to use cclass objects, leveraging both the overloaded operators and the standard class methods to manipulate and execute code references in a flexible and powerful manner.

# METHODS

## Constructor

### new($coderef, %options)

Creates a new cclass object.

## Core Methods

### call(@args)

Calls the wrapped code reference with the given arguments.

### set($coderef)

Sets a new code reference for the object.

### get()

Returns the wrapped code reference.

## Function Manipulation

### memoize($max_cache_size, $expiration)

Memoizes the function results.

### curry(@curry_args)

Curries the function with the given arguments.

### compose(@coderefs)

Composes the function with other functions.

## Execution Control

### throttle($limit)

Throttles function calls to a specified time limit.

### debounce($delay)

Debounces function calls.

### retry($max_attempts, $delay)

Retries the function on failure.

### retry_with_backoff($max_attempts, $initial_delay, $max_delay)

Retries the function with exponential backoff.

### timeout($seconds)

Sets a timeout for function execution.

## Performance Analysis

### time(@args)

Times the execution of the function.

### profile($iterations, @args)

Profiles the function over multiple iterations.

## Threading

### create_thread(@args)

Creates a new thread with the function.

### detach(@args)

Detaches a thread with the function.

### join($timeout, @args)

Joins a thread with the function.

## Utility Methods

### apply($func)

Applies a function to the result of the wrapped function.

### chain(@funcs)

Chains multiple functions.

### partial(@args)

Partially applies arguments to the function.

### flip()

Flips the order of arguments.

### limit_args($n)

Limits the number of arguments passed to the function.

### delay($seconds)

Delays the execution of the function.

### wrap_result(@result)

Wraps the result using xclass.

### call_and_wrap(@args)

Calls the function and wraps the result.

### defined()

Checks if the code reference is defined.

# OVERLOADED OPERATORS

cclass overloads the following operators:

- Function call (&{})

    Allows you to call the wrapped code reference directly:
    $code->(@args)  # equivalent to $code->call(@args)
    &{$code}(@args) # also equivalent to $code->call(@args)

- Stringification ("")
- Numification (0+)
- Boolean context
- Negation (!)
- Equality (==, !=)
- Comparison (cmp, <=>)
- Composition (.)

# ERROR HANDLING

cclass uses the error handling mechanisms provided by xclass. The following error types may be thrown:

- TYPE_ERROR
- RUNTIME_ERROR
- TIMEOUT_ERROR

# LIMITATIONS AND CAVEATS

- Memoization may consume significant memory for functions with many unique inputs.
- Thread safety relies on proper use of synchronization mechanisms.
- Some advanced features may have a performance impact, especially in tight loops.
- Closures and references to lexical variables may not behave as expected when used with threading methods.

# CONFIGURATION

cclass inherits its configuration options from lclass. Refer to the lclass documentation for configuration options.

# PERFORMANCE CONSIDERATIONS

- Memoization: Can significantly improve performance for expensive functions with repetitive inputs, but may consume memory.
- Throttling and Debouncing: Useful for rate-limiting but can introduce delays.
- Composition and Chaining: Efficient for combining multiple operations but may add slight overhead.
- Threading: Can improve performance for concurrent operations but introduces thread management overhead.

# THREAD SAFETY

cclass is designed to be thread-safe when used correctly. All public methods use lclass synchronization mechanisms to ensure safe concurrent access and modification of the wrapped code reference.

# COMPATIBILITY

cclass requires Perl version 5.10 or higher due to its use of advanced language features and for optimal performance.

# DEPENDENCIES

This module requires the following Perl modules:

- v5.10 or higher
- threads
- threads::shared
- JSON::PP
- lclass (for utility methods and thread-safe operations)
- xclass (for handling specific reference types)

# VERSION

Version 2.0.0

This documentation refers to cclass version 2.0.0.

# SEE ALSO

xclass, lclass

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
- [`aclass`](aclass.md): Array Class - Enhanced array handling and operations
- [`hclass`](hclass.md): Hash Class - Advanced hash manipulation and features
- [`iclass`](iclass.md): IO Class - Input/Output operations and file handling
- [`gclass`](gclass.md): GLOB Class - Advanced GLOB reference manipulation
- [`rclass`](rclass.md): Reference Class - Generic reference type handling
- [`tclass`](tclass.md): Thread Class - Advanced thread control and management


For more information, please refer to the full documentation by running `perldoc cclass` after installation.
