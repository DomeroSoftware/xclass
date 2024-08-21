# NAME

xclass - Core Management and Factory Class for the xclass Ecosystem

# TABLE OF CONTENTS

- [DESCRIPTION](#description)
- [SYNOPSIS](#synopsis)
- [EXAMPLES](#examples)
- [METHODS](#methods)
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

The xclass module serves as the central hub, manager, and factory for the
entire xclass ecosystem. It provides a unified interface for creating,
managing, and interacting with various specialized classes that handle
different data types in Perl.

Key features and responsibilities of xclass include:

- Class Registration and Management
- Instance Creation and Factory Methods
- Lazy Loading and Performance Optimization
- Configuration Management
- Debugging and Logging
- Thread Safety
- Error Handling
- Extensibility
- Interoperability

## Handling of Circular References

xclass provides built-in support for handling circular references across its ecosystem. When creating or manipulating objects, xclass automatically detects and manages circular references to prevent memory leaks and infinite recursion. This is achieved through a combination of weak references and internal bookkeeping.

Key points:
- Circular references are automatically detected during object creation and manipulation.
- Weak references are used where appropriate to break circular reference chains.
- The garbage collector is able to properly clean up objects involved in circular references.
- Users generally don't need to manually manage circular references when using xclass objects.

# SYNOPSIS

'''perl
use xclass;

# Create instances of specialized classes
my $scalar = Sc("Hello, World!");
my $array = Ac([1, 2, 3]);
my $hash = Hc({ key => 'value' });

# Use automatic type conversion
my $converted = Xc($some_data);

# Configure the ecosystem
xclass::configure(lazy_loading => 0, cache_instances => 1);

# Set debug level
xclass::set_debug_level(2);
'''

# EXAMPLES

## Basic Usage

'''perl
use xclass;

# Create a scalar object
my $scalar = Sc("Hello, xclass!");
print $scalar->get, "\n";  # Outputs: Hello, xclass!

# Create an array object
my $array = Ac([1, 2, 3]);
$array->push(4);
print $array->join(", "), "\n";  # Outputs: 1, 2, 3, 4

# Create a hash object
my $hash = Hc({ name => "Alice", age => 30 });
$hash->set("city", "New York");
print $hash->get("name"), " lives in ", $hash->get("city"), "\n";
# Outputs: Alice lives in New York
'''

## Automatic Type Conversion

'''perl
use xclass;

sub process_data {
    my $data = shift;
    my $xdata = Xc($data);  # Automatically converts to appropriate xclass object

    if ($xdata->isa('sclass')) {
        print "Processing scalar: ", $xdata->get, "\n";
    } elsif ($xdata->isa('aclass')) {
        print "Processing array: ", $xdata->join(", "), "\n";
    } elsif ($xdata->isa('hclass')) {
        print "Processing hash: ", join(", ", $xdata->keys), "\n";
    }
}

process_data("Hello");  # Outputs: Processing scalar: Hello
process_data([1, 2, 3]);  # Outputs: Processing array: 1, 2, 3
process_data({ a => 1, b => 2 });  # Outputs: Processing hash: a, b
'''

## Thread-Safe Operations

'''perl
use xclass;
use threads;

my $shared_array = Ac([]);

my @threads = map {
    threads->create(sub {
        for (1..10) {
            $shared_array->push($_);
            sleep rand();
        }
    });
} 1..5;

$_->join for @threads;

print "Final array: ", $shared_array->join(", "), "\n";
# Outputs a thread-safe, combined result of all threads
'''

## Using Code References

'''perl
use xclass;

my $code = Cc(sub { my $x = shift; return $x * 2 });

print $code->call(5), "\n";  # Outputs: 10

$code->modify(sub { my $original = shift; sub { $original->(@_) + 1 } });
print $code->call(5), "\n";  # Outputs: 11
'''

## IO Operations

'''perl
use xclass;

my $file = Ic("example.txt");
$file->write("Hello, xclass!");
my $content = $file->read;
print $content, "\n";  # Outputs: Hello, xclass!
'''

## GLOB Handling

'''perl
use xclass;

my $glob = Gc(\*STDOUT);
$glob->print("This goes to STDOUT\n");
'''

## General Reference Manipulation

'''perl
use xclass;

my $ref = Rc(\[1, 2, 3]);
print $ref->deref->[1], "\n";  # Outputs: 2
'''

## Thread Management

'''perl
use xclass;

my $thread = Tc->new('MyApp', 'WorkerThread',
    code => sub {
        my ($self) = @_;
        while (!$self->should_stop) {
            print "Working...\n";
            $self->sleep(1);
        }
    }
);

$thread->start;
sleep 5;
$thread->stop;
'''

# METHODS

## Class Registration and Management

### register($type, $class)

Registers a new class in the xclass ecosystem.

'''perl
xclass::register('CUSTOM', 'MyCustomClass');
'''

### registered($type)

Checks if a type is registered.

'''perl
if (xclass::registered('SCALAR')) {
    print "SCALAR type is registered\n";
}
'''

### class($type)

Returns the class name for a given type.

'''perl
my $class_name = xclass::class('ARRAY');
'''

## Instance Creation

### create($type, @args)

Creates an instance of the specified type.

'''perl
my $array = xclass::create('ARRAY', [1, 2, 3]);
'''

### Sc(@args), Ac(@args), Hc(@args), Cc(@args), Ic(@args), Gc(@args), Rc(@args), Tc(@args)

Shorthand methods for creating instances of specific types.

'''perl
my $scalar = Sc("Hello");
my $array = Ac([1, 2, 3]);
my $hash = Hc({ key => 'value' });
'''

### Xc($element, @args)

Automatically converts an element to the appropriate xclass type.

'''perl
my $xobject = Xc($some_data);
'''

## Configuration and Debugging

### configure(%options)

Configures the xclass ecosystem.

'''perl
xclass::configure(lazy_loading => 0, cache_instances => 1);
'''

### set_debug_level($level)

Sets the debug level for the ecosystem.

'''perl
xclass::set_debug_level(2);
'''

### debug_log($message, $level, $category)

Logs a debug message.

'''perl
xclass::debug_log("Processing data", 2, 'DATA');
'''

# ERROR HANDLING

xclass uses a centralized error handling mechanism. Errors are thrown as exceptions and can be caught using eval or try-catch constructs.

'''perl
eval {
    my $array = Ac("not an array");
};
if ($@) {
    print "Error: $@\n";
}
'''

# LIMITATIONS AND CAVEATS

- Performance overhead for type checking and conversion in Xc()
- Potential memory usage increase when caching instances
- Lazy loading may cause slight delays on first use of a class

# CONFIGURATION

Configuration options can be set using the configure() method:

- lazy_loading: Enable/disable lazy loading of classes (default: 1)
- cache_instances: Enable/disable instance caching (default: 0)

'''perl
xclass::configure(lazy_loading => 0, cache_instances => 1);
'''

# PERFORMANCE CONSIDERATIONS

- Use lazy_loading => 1 for faster startup times
- Use cache_instances => 1 for faster repeated instance creation at the cost of memory
- Be mindful of debug_log usage in production environments

# THREAD SAFETY

xclass is designed to be thread-safe. It uses semaphores for critical sections and ensures that all operations on shared data are properly synchronized.

# COMPATIBILITY

xclass requires Perl version 5.10 or higher. It is designed to work on both Unix-like systems and Windows.

# DEPENDENCIES

## CPAN Dependencies

- v5.10 or higher
- threads
- threads::shared
- Thread::Semaphore
- Exporter
- Scalar::Util
- List::Util
- Time::HiRes
- IO::Handle
- Fcntl
- Encode
- Compress::Zlib
- File::Temp
- Socket
- Storable
- Data::MessagePack
- JSON::XS
- YAML::XS
- Storable
- B::Deparse
- Devel::Size;
- Devel::Cycle;
- Benchmark
- Perl::Critic;
- Log::Log4perl
- Try::Tiny
- Test::MemoryGrowth
- Test::More
- Test::Exception
- Test::Warn

## xclass Ecosystem Dependencies

- lclass (Locking, Synchronization, and Utility)

Core utility class providing foundational methods for debugging, locking, and other general utilities. Automatically imported by all other *class modules.

- sclass (SCALAR)

Implements comprehensive, thread-safe operations for scalar reference manipulation.

- aclass (ARRAY)

Provides thread-safe, feature-rich operations for array reference manipulation.

- hclass (HASH)

Offers robust, thread-safe methods for hash reference operations.

- cclass (CODE)

Manages and manipulates code references in a thread-safe manner.

- iclass (IO)

Handles input/output operations in a thread-safe way, encapsulating both file system and network operations.

- gclass (GLOB)

Implements thread-safe operations for GLOB references.

- rclass (REF)

Provides a unified interface for manipulating general references.

- tclass (THREAD)

Offers comprehensive, thread-safe management for individual threads.

## Internal Dependency Structure

- xclass
Depends on: All other *class modules
Role: Core management and factory class

- lclass
Depends on: None (base utility class)
Role: Provides core utilities to all other classes

- sclass, aclass, hclass, cclass, iclass, gclass, rclass
Depend on: lclass, xclass
Role: Type-specific reference handling

- tclass
Depends on: lclass, xclass, gclass
Role: Thread management and control

## Optional Extended Ecosystem Components

- pclass (Thread Pool Management)
Depends on: tclass, xclass, lclass
Role: Implements an efficient thread pool management system

- dclass (Database Interface)
Depends on: xclass, lclass, potentially sclass, aclass, hclass
Role: Provides a thread-safe database interface

Note: The xclass ecosystem is designed with lazy loading, meaning that while all these dependencies exist, they are only loaded when needed, improving startup time and memory usage for applications that don't use all components.

# VERSION

Version 2.0.0

# SEE ALSO

- [`lclass`](lclass.md): Lock Class - Thread-safe operations, synchronization and Utilities
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

Copyright (C) 2024 OnEhIppY, Domero Software

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
