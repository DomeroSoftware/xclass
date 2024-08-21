# NAME

lclass - Locking, Synchronization, and Utility Base Class for the xclass Ecosystem

# SYNOPSIS

```perl
use xclass;

my $scalar_obj = Sc("Hello, World!");
$scalar_obj->share_it;
$scalar_obj->lock;
$scalar_obj->set("New value");
$scalar_obj->unlock;

my $serialized = $scalar_obj->serialize;
my $deserialized = Sc()->deserialize($serialized);

# Using with other xclass types
my $array_obj = Ac([1, 2, 3]);
my $hash_obj = Hc({key => 'value'});

# Applying functions
$array_obj->apply(sub { $_[0] * 2 });

# Event handling
$hash_obj->on('after_set', sub { print "Hash changed\n" });
```

# DESCRIPTION

The `lclass` module serves as the foundational base class for the xclass ecosystem, providing essential methods for locking, synchronization, and utility functions. It is designed to be inherited by other specialized classes within the xclass framework, ensuring consistent functionality across the ecosystem.

# METHODS

## Core Methods

- **_ref**

  Internal method to get the reference of the stored data.

- **_shared**

  Check if the stored reference is shared.

- **share_it**

  Make the object shared for thread-safe operations.

- **_init(%options)**

  Initialize the object with given options.

## Locking Mechanisms

- **lock**

  Acquire a lock on the object.

- **unlock**

  Release the lock on the object.

- **sync($code, $operation_name, @args)**

  Execute code in a synchronized manner.

## Data Manipulation

- **apply($func)**

  Apply a function to the object's data.

## Stringification

- **to_string**

  Convert the object to a string representation.

## Serialization

- **serialize($format)**

  Serialize the object to a specified format (default: JSON).

- **deserialize($serialized_data, $format)**

  Deserialize data into the object.

## Memory Management

- **memory_usage**

  Get the memory usage of the object.

- **check_circular_refs**

  Check for circular references in the object.

## Error Handling

- **throw($message, $code)**

  Throw an exception with a message and error code.

- **debug($message)**

  Log a debug message.

- **try($code, $operation_name, @args)**

  Execute code in a try-catch block.

## Comparison

- **compare($other, $swap)**

  Compare the object with another object.

- **equals($other, $swap)**

  Check if the object is equal to another object.

## Event Handling

- **on($event, $callback)**

  Register a callback for an event.

- **trigger($event, @args)**

  Trigger an event with optional arguments.

## Utility Methods

- **is_defined**

  Check if the object's reference is defined.

- **is_empty**

  Check if the object's data is empty.

- **clone($clone_name)**

  Create a clone of the object.

## Configuration and Meta-information

- **version**

  Get the version of lclass.

- **check_compatibility($required_version)**

  Check if the current version is compatible with a required version.

- **configure(%options)**

  Configure lclass options.

## Plugin System

- **register_plugin($name, $plugin)**

  Register a plugin for lclass.

- **use_plugin($name, @args)**

  Use a registered plugin.

# EXPORT

The following functions can be exported:

- :all - Exports all functions
- :config - Exports configuration-related functions
- :scalar, :array, :hash, :code, :io, :glob, :ref, :thread - Exports type-specific functions
- :meta - Exports meta-information functions
- :advanced - Exports advanced features

# CONFIGURATION

Configuration options can be set using the `configure` function or by modifying the `%CONFIG` hash directly:

    lclass::configure(debug_level => 2, use_cache => 1);

Available options include:

- debug_level
- use_cache
- cache_strategy
- cache_size
- serialization_format
- max_recursion_depth
- enable_profiling
- enable_async
- security_level
- encryption_key

# SEE ALSO

- [`xclass`](xclass.md): eXtended Class - Core of the xclass ecosystem
- [`sclass`](sclass.md): Scalar Class - Advanced scalar value manipulation
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

Copyright (C) 2024 by OnEhIppY, Domero Software

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.1 or,
at your option, any later version of Perl 5 you may have available.
