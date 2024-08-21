# iclass - Advanced Thread-Safe IO Operations Class for xclass Ecosystem

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

The iclass module provides a robust and feature-rich interface for handling IO
operations within the xclass ecosystem. It offers thread-safe file and stream
manipulations, supporting various IO types and advanced features.

Key features include:

- Thread-safe IO operations using xclass synchronization
- Support for multiple IO types (files, sockets, pipes, TTY, etc.)
- Advanced file operations: reading, writing, seeking, truncating
- Compression and encoding support with configurable thresholds
- File locking mechanisms for concurrent access control
- Atomic operations for data integrity
- Temporary file creation and secure file deletion
- Integration with other xclass reference types

### Integration with xclass Ecosystem

iclass inherits core functionality from xclass and can be instantiated directly
or through xclass factory methods. It implements the xclass event system for
operation tracking and seamlessly interacts with other xclass data types.

### Thread Safety

All methods in iclass are designed to be thread-safe, utilizing xclass synchronization mechanisms.

### Performance Considerations

iclass is optimized for both single-threaded and multi-threaded environments.
It uses configurable compression and flush intervals for fine-tuning performance.

### Extensibility

The class is designed to be easily extended with additional IO operations and
supports custom event triggers for all operations.

## Synopsis

```perl
use strict;
use warnings;
use xclass;

# Create a new iclass object
my $io = Ic();

# Open a file for writing
$io->open('example.txt', '>');

# Write to the file
$io->write("Hello, World!");

# Close the file
$io->close();

# Open a file for reading
$io->open('example.txt', '<');

# Read from the file
my $content;
$io->read(\$content, 1024);

# Close the file
$io->close();
```

## Examples

### Using Compression

```perl
my $io = Ic();
$io->open('large_file.txt', '>');
$io->compression(1);
$io->compression_level(6);
$io->write("Large amount of data...");
$io->close();
```

### Atomic Operations

```perl
my $io = Ic();
$io->open('important_data.txt', '+<');
$io->atomic_operation(sub {
    my $data = $io->getline();
    $data =~ s/old/new/;
    $io->seek(0, 0);
    $io->write($data);
});
$io->close();
```

### Secure File Deletion

```perl
my $io = Ic();
$io->open('sensitive_data.txt', '+<');
# ... perform operations ...
$io->secure_delete();
```

### Socket Operations

```perl
my $server = Ic();
$server->accept(8080, sub {
    my ($server, $client) = @_;
    my $message = "Hello, client!";
    $client->send(\$message, length($message));
    $client->close();
});
$server->listen();
```

## Methods

### Constructor

#### new($ref, %options)

Creates a new iclass object.

```perl
my $io = iclass->new();
```

### Core Methods

#### open($filename, $mode)

Opens a file with the specified mode.

```perl
$io->open('file.txt', '>');
```

#### close()

Closes the currently open file.

```perl
$io->close();
```

#### read($buffer, $length, $offset)

Reads data from the file into the buffer.

```perl
my $buffer;
$io->read(\$buffer, 1024);
```

#### write($buffer, $length, $offset)

Writes data from the buffer to the file.

```perl
$io->write("Hello, World!");
```

#### seek($position, $whence)

Seeks to a position in the file.

```perl
$io->seek(0, 0);  # Seek to the beginning
```

#### tell()

Returns the current position in the file.

```perl
my $position = $io->tell();
```

#### eof()

Checks if the end of file has been reached.

```perl
if ($io->eof()) {
    print "End of file reached\n";
}
```

#### flush()

Flushes the file buffer.

```perl
$io->flush();
```

#### fileno()

Returns the file descriptor for the IO handle.

```perl
my $fd = $io->fileno();
```

#### binmode($layer)

Sets the binary mode for the file handle.

```perl
$io->binmode(":raw");
```

#### is_open()

Checks if the IO handle is open.

```perl
if ($io->is_open()) {
    print "IO handle is open\n";
}
```

### Advanced Methods

#### getline()

Reads a line from the file.

```perl
my $line = $io->getline();
```

#### getlines()

Reads all lines from the file.

```perl
my @lines = $io->getlines();
```

#### printf($format, @args)

Prints formatted output to the file.

```perl
$io->printf("Name: %s, Age: %d", $name, $age);
```

#### say(@args)

Prints the arguments to the file, adding a newline.

```perl
$io->say("Hello, World!");
```

#### truncate($length)

Truncates the file to the specified length.

```perl
$io->truncate(100);
```

#### clear()

Clears the contents of the file.

```perl
$io->clear();
```

#### lock_io($operation)

Locks the file for exclusive access.

```perl
$io->lock_io(LOCK_EX);
```

#### unlock_io()

Unlocks the file.

```perl
$io->unlock_io();
```

#### copy_to($destination, $buffer_size)

Copies the contents of the file to another file.

```perl
$io->copy_to($other_io, 8192);
```

#### temporary($mode, @args)

Creates a temporary file.

```perl
my $temp_filename = $io->temporary();
```

#### secure_delete()

Securely deletes the file contents.

```perl
$io->secure_delete();
```

#### atomic_operation($code)

Performs an atomic operation on the file.

```perl
$io->atomic_operation(sub {
    # Atomic operations here
});
```

#### io_type()

Returns the type of the IO handle.

```perl
my $type = $io->io_type();
```

#### autoflush($value)

Sets or gets the autoflush setting for the IO handle.

```perl
$io->autoflush(1);
```

#### chmod($mode)

Sets the file permissions.

```perl
$io->chmod(0644);
```

#### ismod()

Gets the file permissions.

```perl
my $perms = $io->ismod();
```

#### chown($uid, $gid)

Sets the file owner.

```perl
$io->chown(1000, 1000);
```

#### isown()

Gets the file owner (UID and GID).

```perl
my ($uid, $gid) = $io->isown();
```

### Configuration Methods

#### buffer($size)

Sets or gets the buffer size for IO operations.

```perl
$io->buffer(16384);
```

#### encoding($encoding)

Sets or gets the encoding for text operations.

```perl
$io->encoding('utf8');
```

#### compression($level)

Sets or gets the compression setting for IO operations.

```perl
$io->compression(1);
```

#### compression_level($level)

Sets or gets the compression level.

```perl
$io->compression_level(9);
```

#### flush_interval($interval)

Sets or gets the automatic flush interval.

```perl
$io->flush_interval(5);  # Flush every 5 seconds
```

### Socket Methods

#### accept($port, $callback)

Sets up a socket to accept connections on the specified port.

```perl
$io->accept(8080, sub {
    my ($server, $client) = @_;
    # Handle client connection
});
```

#### listen()

Starts listening for incoming connections on the socket.

```perl
$io->listen();
```

## Overloaded Operators

iclass overloads the following operators:

- Dereference (*{})
- Stringification ("")
- Numeric context (0+)
- Boolean context
- Negation (!)
- Assignment (=)
- Equality (==, !=)
- Comparison (cmp, <=>)

## Error Handling

iclass uses the error handling mechanisms provided by xclass. Errors can be caught and handled using eval blocks or try-catch constructs.

## Limitations and Caveats

- Large file operations may consume significant memory, especially with compression enabled.
- Some advanced features may not be available on all platforms.
- Secure deletion may not be effective on all types of storage media.
- Thread safety relies on proper use of synchronization mechanisms.

## Configuration

iclass inherits its configuration options from xclass. Specific options for iclass include:

- buffer_size: Size of the buffer for IO operations (default: 8192 bytes).
- encoding: Default encoding for text operations (default: 'raw').
- compression: Whether compression is enabled (default: 0).
- compression_level: Level of compression for IO operations (default: 6).
- compression_threshold: Minimum size for compression to be applied (default: 1024 bytes).
- flush_interval: Interval for automatic flushing (default: undef, no automatic flushing).

## Performance Considerations

- Buffer Size: Larger buffer sizes can improve performance for bulk operations but increase memory usage.
- Compression: Enables smaller file sizes but adds CPU overhead. Useful for large files or network transfers.
- Encoding: UTF-8 encoding may add overhead for non-ASCII text. Consider using 'raw' for binary data.
- Flush Interval: Frequent flushing ensures data integrity but may impact performance.

## Thread Safety

iclass is designed to be thread-safe when used correctly. All public methods use xclass synchronization mechanisms to ensure safe concurrent access and modification of IO handles.

## Compatibility

iclass requires Perl version 5.10 or higher due to its use of advanced language features and for optimal performance. It has been developed and tested primarily on Unix-like systems (Linux, macOS) and Windows.

## Dependencies

This module requires the following Perl modules:

- v5.10 or higher
- IO::Handle
- Fcntl
- POSIX
- File::Spec
- Cwd
- Config
- Encode
- Compress::Zlib
- File::Temp
- Time::HiRes
- Socket
- xclass (for handling specific reference types and core functionality)

## Version

Version 2.0.0

This documentation refers to iclass version 2.0.0.

## See Also

- [`xclass`](xclass.md): eXtended Class - Core of the xclass ecosystem
- [`lclass`](lclass.md): Lock Class - Thread-safe operations, synchronization and Utilities
- [`sclass`](sclass.md): Scalar Class - Advanced scalar value manipulation
- [`aclass`](aclass.md): Array Class - Enhanced array handling and operations
- [`hclass`](hclass.md): Hash Class - Advanced hash manipulation and features
- [`cclass`](cclass.md): Code Class - Subroutine and code reference management
- [`gclass`](gclass.md): GLOB Class - Advanced GLOB reference manipulation
- [`rclass`](rclass.md): Reference Class - Generic reference type handling
- [`tclass`](tclass.md): Thread Class - Advanced thread control and management

## Author

OnEhIppY, Domero Software <domerosoftware@gmail.com>

## Copyright and License

Copyright (C) 2024 OnEhIppY, Domero Software

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
