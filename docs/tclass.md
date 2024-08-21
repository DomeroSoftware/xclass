# NAME

tclass - Advanced Thread Control and Management Class for xclass Ecosystem

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

The tclass module provides a robust and feature-rich interface for creating, managing,
and controlling threads with integrated shared data handling through xclass-wrapped
GLOB references. It offers a comprehensive set of thread management capabilities, including:

- Thread lifecycle management (creation, starting, stopping, detaching, joining)
- Shared data handling through GLOB references with type-specific access
- Extended class support for complex thread-specific data structures
- Customizable error and kill signal handling
- Thread-safe operations and synchronization
- High-resolution timing functions for precise thread control
- Comprehensive status tracking and reporting
- Support for both detached and joinable threads
- Graceful termination and cleanup mechanisms

Key features include:

- Seamless integration with xclass ecosystem
- Thread-safe operations using lclass synchronization
- Flexible shared data management with support for various data types
- Event-driven architecture with customizable triggers
- Advanced error handling and reporting
- Support for extended classes and custom data structures
- High-resolution sleep and yield functions for fine-grained thread control
- Comprehensive string representation and comparison methods

This tclass is designed to provide a powerful yet easy-to-use interface for
complex multi-threaded applications within the xclass framework, ensuring
thread safety, proper resource management, and extensibility.

## Handling of Circular References

tclass, designed for thread management, incorporates robust circular reference handling as part of the xclass ecosystem.

- Thread objects can safely reference other xclass objects, including other thread objects, without causing memory leaks.
- Circular references in shared data structures across threads are automatically detected and managed.
- The garbage collection process correctly handles tclass objects and their associated data involved in circular references.
- Users can create complex multi-threaded applications with interconnected data structures without manual intervention for circular reference management.

# SYNOPSIS

```perl
use strict;
use warnings;
use tclass;

# Create a new thread
my $thread = tclass->new('MyApp', 'WorkerThread',
    scalar => 0,
    array => [],
    hash => {},
    code => sub {
        my ($self, @args) = @_;
        while (!$self->should_stop) {
            # Thread work here
            $self->sleep(0.1);
        }
    },
    on_kill => sub {
        my $self = shift;
        # Cleanup code
    },
    on_error => sub {
        my ($self, $error) = @_;
        # Error handling code
    }
);

# Start the thread
$thread->start(@args);

# Interact with shared data
$thread->SCALAR->set(42);
my $value = $thread->SCALAR->get;

# Stop the thread
$thread->stop;
```

# EXAMPLES

## Basic Thread Creation and Management

```perl
use xclass;

my $thread = Tc('MyApp', 'WorkerThread',
    scalar => 0,
    array => [],
    hash => { status => 'idle' },
    code => sub {
        my ($self) = @_;
        while (!$self->should_stop) {
            my $status = $self->HASH->get('status');
            if ($status eq 'work') {
                $self->SCALAR->inc(1);
                $self->HASH->set('status', 'idle');
            }
            $self->sleep(0.1);
        }
    },
    on_error => sub {
        my ($self, $error) = @_;
        $self->HASH->set('error', $error);
    }
);

$thread->start;
$thread->HASH->set('status', 'work');
sleep(1);
print "Work done: ", $thread->SCALAR->get, "\n";
$thread->stop;
```

## Using Extended Classes

```perl
package MyCounter;
use Moo;
has count => (is => 'rw', default => 0);
sub increment { shift->count(shift->count + 1) }

package main;
use xclass;

my $thread = Tc('MyApp', 'CounterThread',
    counter => MyCounter->new,
    code => sub {
        my ($self) = @_;
        while (!$self->should_stop) {
            $self->ext('counter')->increment;
            $self->sleep(1);
        }
    }
);

$thread->start;
sleep(5);
$thread->stop;
print "Final count: ", $thread->ext('counter')->count, "\n";
```

## Thread Synchronization and Shared Data Manipulation

```perl
my $thread = Tc('MyApp', 'SyncThread',
    array => [],
    hash => { sum => 0 },
    code => sub {
        my ($self) = @_;
        while (!$self->should_stop) {
            $self->ARRAY->push(int(rand(100)));
            my $sum = $self->ARRAY->reduce(sub { $a + $b });
            $self->HASH->set('sum', $sum);
            $self->sleep(0.5);
        }
    }
);

$thread->start;
sleep(5);
$thread->stop;
print "Final sum: ", $thread->HASH->get('sum'), "\n";
print "Array: ", $thread->ARRAY->join(', '), "\n";
```

## Error Handling and Logging

```perl
my $thread = Tc('MyApp', 'ErrorThread',
    hash => { log => [] },
    code => sub {
        my ($self) = @_;
        $self->HASH->get('log')->push("Thread started");
        eval { die "Simulated error" };
        if ($@) {
            $self->HASH->get('log')->push("Error: $@");
            $self->throw($@);
        }
    },
    on_error => sub {
        my ($self, $error) = @_;
        $self->HASH->get('log')->push("Error handled: $error");
    }
);

$thread->start;
$thread->join;
print "Log:\n", $thread->HASH->get('log')->join("\n"), "\n";
```

## Using lclass Options

tclass inherits lclass functionality, which is initialized in the constructor. The lclass options are passed directly in the constructor arguments, not in a separate 'lclass' hash:

```perl
my $thread = Tc('MyApp', 'OptionsThread',
    scalar => 0,
    code => sub {
        my ($self) = @_;
        while (!$self->should_stop) {
            $self->SCALAR->inc(1);
            $self->sleep(1);
        }
    },
    debug => 1,
    trace => 1,
    log_file => '/tmp/thread_log.txt',
    on_error => sub {
        my ($self, $error, $method, @args) = @_;
        warn "Error in method $method: $error";
    }
);

$thread->start;
sleep(5);
$thread->stop;
```

## Detached Threads

```perl
my $detached_thread = Tc('MyApp', 'DetachedThread',
    scalar => 0,
    code => sub {
        my ($self) = @_;
        for (1..5) {
            $self->SCALAR->inc(1);
            $self->sleep(1);
        }
    },
    auto_detach => 1
);

$detached_thread->start;
print "Thread detached: ", $detached_thread->detached ? "Yes" : "No", "\n";
```

## Thread Pool Implementation

```perl
sub create_worker {
    my ($id, $task_queue, $results) = @_;
    return Tc("MyApp", "Worker$id",
        task_queue => $task_queue,
        results => $results,
        code => sub {
            my ($self) = @_;
            while (!$self->should_stop) {
                if (my $task = $self->get('task_queue')->shift) {
                    my $result = $task * 2;  # Simple task: double the input
                    $self->get('results')->set($task, $result);
                } else {
                    $self->sleep(0.1);
                }
            }
        }
    );
}

my $task_queue = Ac([]);
my $results = Hc({});

my @workers = map { create_worker($_, $task_queue, $results) } 1..5;

$_->start for @workers;

$task_queue->push($_) for 1..10;

while ($task_queue->size > 0 || $results->size < 10) {
    sleep 0.1;
}

$_->stop for @workers;

print "Results: ", join(", ", map { $results->get($_) } sort { $a <=> $b } $results->keys), "\n";

$_->join for @workers;
```

## xclass Overloading

Overloading in tclass is handled through the xclass ecosystem. Here are examples of how to use overloading with tclass:

### Numeric Overloading

```perl
use xclass;

my $thread = Tc('MyApp', 'NumericThread',
    scalar => 10
);

print $thread + 5, "\n";  # 15
print $thread * 2, "\n";  # 20
```

### String Overloading

```perl
my $thread = Tc('MyApp', 'StringThread',
    scalar => "Hello"
);

print "$thread, World!\n";  # Hello, World!
print $thread . " Perl!\n";  # Hello Perl!
```

### Comparison Overloading

```perl
my $thread = Tc('MyApp', 'CompareThread',
    scalar => 50
);

print "Greater\n" if $thread > 30;
print "Equal\n" if $thread == 50;
```

### Boolean Overloading

```perl
my $thread = Tc('MyApp', 'BoolThread',
    scalar => 1
);

print "True\n" if $thread;
$thread->SCALAR->set(0);
print "False\n" unless $thread;
```

## lclass Utilization

tclass inherits functionality from lclass. Here are examples of how to use lclass features with tclass:

### Custom Error Handling

```perl
my $thread = Tc('MyApp', 'ErrorThread',
    on_error => sub {
        my ($self, $error, $method, @args) = @_;
        warn "Error in method $method: $error";
    },
    CODE => sub {
        my ($self) = @_;
        $self->throw("Custom error");
    }
);

$thread->start;
$thread->join;
```

### Method Wrapping

```perl
my $thread = Tc('MyApp', 'WrapThread',
    CODE => sub {
        my ($self) = @_;
        print "Thread running\n";
    }
)->on('before_start',sub {
    my ($self, @args) = @_;
    print "Before starting thread\n";
})->on('after_stop',sub {
    my ($self, @args) = @_;
    print "After stopping thread\n";
})->on('error_call',sub {
    my ($self, @args) = @_;
    print "Thread Error ",join("\n",@args),"\n";
});

$thread->start;
$thread->stop;
```

# METHODS

## Constructor

### new($space, $name, %options)

Creates a new tclass object.

```perl
my $thread = tclass->new('MyApp', 'WorkerThread', %options);
```

## Thread Control Methods

### start(@args)

Starts the thread with optional arguments.

```perl
$thread->start(@args);
```

### stop($timeout)

Stops the thread, optionally with a timeout.

```perl
$thread->stop(5);  # Stop with 5-second timeout
```

### detach()

Detaches the thread.

```perl
$thread->detach;
```

### join($timeout)

Waits for the thread to finish, optionally with a timeout.

```perl
$thread->join(10);  # Wait for up to 10 seconds
```

## Status and Information Methods

### status()

Returns the current status of the thread.

```perl
my $status = $thread->status;
```

### tid()

Returns the thread ID.

```perl
my $tid = $thread->tid;
```

### running()

Checks if the thread is running.

```perl
if ($thread->running) { ... }
```

### detached()

Checks if the thread is detached.

```perl
if ($thread->detached) { ... }
```

## Shared Data Methods

### get($key)

Gets a reference to shared data.

```perl
my $scalar_ref = $thread->get('SCALAR');
```

### set($key, $value)

Sets a reference to shared data.

```perl
$thread->set('ARRAY', [1, 2, 3]);
```

## GLOB Accessor Methods

### SCALAR()

Returns the SCALAR component of the shared GLOB.

```perl
my $scalar = $thread->SCALAR;
```

### ARRAY()

Returns the ARRAY component of the shared GLOB.

```perl
my $array = $thread->ARRAY;
```

### HASH()

Returns the HASH component of the shared GLOB.

```perl
my $hash = $thread->HASH;
```

### CODE()

Returns the CODE component of the shared GLOB.

```perl
my $code = $thread->CODE;
```

### IO()

Returns the IO component of the shared GLOB.

```perl
my $io = $thread->IO;
```

## Extended Class Methods

### ext($key, $value?)

Gets or sets an extended class.

```perl
my $counter = $thread->ext('counter');
$thread->ext('counter', MyCounter->new);
```

## Thread Control Methods (for use within thread code)

### should_stop()

Checks if the thread should stop.

```perl
while (!$self->should_stop) { ... }
```

### yield()

Yields control to other threads.

```perl
$self->yield;
```

### sleep($seconds)

Sleeps for the specified number of seconds (high-resolution).

```perl
$self->sleep(0.1);
```

### usleep($nanoseconds)

Sleeps for the specified number of nanoseconds.

```perl
$self->usleep(100_000);  # Sleep for 100 microseconds
```

## Comparison Methods

### equals($other)

Compares with another tclass object for equality.

```perl
if ($thread1->equals($thread2)) { ... }
```

### compare($other)

Compares with another tclass object.

```perl
my $result = $thread1->compare($thread2);
```

### hash_code()

Returns a hash code for the tclass object.

```perl
my $hash = $thread->hash_code;
```

# ERROR HANDLING

tclass uses the error handling mechanisms provided by xclass and lclass. Errors can be caught and handled using eval blocks or try-catch constructs. Additionally, custom error handling can be implemented using the 'on_error' handler:

```perl
my $thread = tclass->new('MyApp', 'ErrorThread',
    CODE => sub { die "An error occurred" },
    on_error => sub {
        my ($self, $error, $method, @args) = @_;
        warn "Thread error in method $method: $error";
    }
);
```

The throw() method can be used to raise custom errors:

```perl
$self->throw("Custom error message");
```

# LIMITATIONS AND CAVEATS

- Detached threads cannot be joined or stopped externally.
- Care should be taken when sharing complex data structures between threads.
- The 'CODE' and 'IO' components of shared GLOBs have limitations in terms of sharing and serialization.
- High-resolution timing functions may have system-dependent precision.
- Extended classes should be designed with thread safety in mind.

# CONFIGURATION

tclass configuration is primarily done through the constructor options. Key configuration options include:

- space: The namespace for the thread (required)
- name: The name of the thread (required)
- scalar, array, hash, code, io: Initial values for shared GLOB components
- on_kill: Custom handler for thread termination
- on_error: Custom handler for thread errors
- auto_detach: Automatically detach the thread upon starting
- lclass: Additional lclass options for debugging, tracing, and method wrapping

# PERFORMANCE CONSIDERATIONS

- Frequent access to shared data may impact performance due to synchronization overhead.
- Using high-resolution sleep functions excessively may increase CPU usage.
- Large shared data structures may increase memory usage and affect performance.
- Detached threads may have slightly better performance but are harder to manage.

# THREAD SAFETY

tclass is designed to be thread-safe. All public methods use lclass synchronization mechanisms to ensure safe concurrent access and modification of shared data.

# COMPATIBILITY

tclass requires Perl version 5.10 or higher due to its use of advanced language features and for optimal performance. It has been developed and tested primarily on Unix-like systems (Linux, macOS) and Windows.

# DEPENDENCIES

This module requires the following Perl modules:

- v5.10 or higher
- threads
- threads::shared
- Scalar::Util (for type checking)
- Time::HiRes (for high-resolution time functions)
- lclass (for utility methods and thread-safe operations)
- xclass (for handling specific reference types)
- gclass (for GLOB-based reference handling and manipulation)

# VERSION

Version 2.0.0

This documentation refers to tclass version 2.0.0.

# SEE ALSO

- [`xclass`](xclass.md): eXtended Class - Core of the xclass ecosystem
- [`lclass`](lclass.md): Lock Class - Thread-safe operations, synchronization and Utilities
- [`sclass`](sclass.md): Scalar Class - Advanced scalar value manipulation
- [`aclass`](aclass.md): Array Class - Enhanced array handling and operations
- [`hclass`](hclass.md): Hash Class - Advanced hash manipulation and features
- [`iclass`](iclass.md): IO Class - Input/Output operations and file handling
- [`cclass`](cclass.md): Code Class - Subroutine and code reference management
- [`gclass`](gclass.md): GLOB Class - Advanced GLOB reference manipulation
- [`rclass`](rclass.md): Reference Class - Generic reference type handling


# AUTHOR

OnEhIppY, Domero Software <domerosoftware@gmail.com>

# COPYRIGHT AND LICENSE

Copyright (C) 2024 OnEhIppY, Domero Software

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
