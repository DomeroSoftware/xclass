################################################################################
# iclass.pm - Advanced Thread-Safe IO Operations Class for xclass Ecosystem
#
# This class provides a robust and feature-rich interface for handling IO
# operations within the xclass ecosystem. It offers thread-safe file and stream
# manipulations, supporting various IO types and advanced features.
#
# Key Features:
# - Thread-safe IO operations using xclass synchronization
# - Support for multiple IO types (files, sockets, pipes, TTY, etc.)
# - Advanced file operations: reading, writing, seeking, truncating
# - Compression and encoding support with configurable thresholds
# - File locking mechanisms for concurrent access control
# - Atomic operations for data integrity
# - Temporary file creation and secure file deletion
# - Integration with other xclass reference types
#
# IO Operations:
# - Basic: open, close, read, write, seek, tell, eof, flush
# - Advanced: getline, getlines, printf, say, truncate, clear
# - Utility: binmode, autoflush, lock_io, unlock_io, copy_to
# - Security: create_temp, set_permissions, set_owner, secure_delete
#
# Customization:
# - Configurable buffer size, encoding, compression level
# - Adjustable flush interval for performance tuning
#
# Overloaded Operators:
# - Dereference (*{}), stringification (""), numeric context (0+)
# - Boolean context, negation (!), assignment (=)
# - Equality (==, !=), comparison (cmp, <=>)
#
# Integration with xclass Ecosystem:
# - Inherits core functionality from xclass
# - Implements xclass event system for operation tracking
# - Seamless interaction with other xclass data types
#
# Thread Safety:
# - All methods are designed to be thread-safe
# - Utilizes xclass synchronization mechanisms
#
# Performance Considerations:
# - Optimized for both single-threaded and multi-threaded environments
# - Configurable compression and flush intervals for fine-tuning
#
# Extensibility:
# - Designed to be easily extended with additional IO operations
# - Supports custom event triggers for all operations
#
# Usage Examples:
# - Basic: $io->open('file.txt', 'w')->write("Hello, World!")->close
# - Advanced: $io->set_compression(6)->write($large_data)->flush
# - Atomic: $io->atomic_operation(sub { ... })
#
# Author: OnEhIppY, Domero Software
# Copyright: (C) 2024 OnEhIppY, Domero Software
#
# Dependencies:
# - Perl v5.8.0 or higher
# - IO::Handle
# - Fcntl
# - Encode
# - Compress::Zlib
# - File::Temp
# - Time::HiRes
# - xclass (core functionality and ecosystem integration)
#
# Note: This class is designed to be a comprehensive solution for IO operations
# within the xclass ecosystem. It balances feature richness with performance
# and thread safety considerations. Special care is taken to handle various
# IO types and provide robust error handling and security features.
################################################################################

package iclass;

use strict;
use warnings;
use feature 'say';

use IO::Handle;
use Fcntl qw(:flock SEEK_SET SEEK_CUR SEEK_END);
use POSIX;
use File::Spec;
use Cwd 'abs_path';
use Config;

use Encode qw(encode decode);
use Compress::Zlib;
use File::Temp qw(tempfile tempdir);
use Time::HiRes qw(time gettimeofday usleep sleep);

our $VERSION = '2.0.0';

BEGIN {
    xclass::register('IO', 'iclass');
}

use lclass qw(:io);

# Overload operators for IO-specific operations
use overload
    '*{}' => \&_io_deref_op,
    '""' => \&_stringify_op,
    '0+' => \&_count_op,
    'bool' => \&_bool_op,
    '!' => \&_neg_op,
    '=' => \&_assign_op,
    '==' => \&_eq_op,
    '!=' => \&_ne_op,
    'cmp' => \&_cmp_op,
    '<=>' => \&_spaceship_op,
    fallback => 1;

sub _io_deref_op { shift->get }
sub _stringify_op { shift->to_string }
sub _count_op { shift->fileno }
sub _bool_op { shift->is_open }
sub _neg_op { !shift->is_open }
sub _assign_op { my ($self, $other) = @_; $self->set($other); $self }
# Overloaded operator methods
sub _eq_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        return 0 unless ref($other) && ref($other) eq ref($self);
        return $self->fileno == $other->fileno;
    }, 'eq_op');
}

sub _ne_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        return 1 unless ref($other) && ref($other) eq ref($self);
        return $self->fileno != $other->fileno;
    }, 'ne_op');
}

sub _cmp_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->to_string if ref($other) && ref($other) eq ref($self);
        return $swap ? $other cmp $self->to_string : $self->to_string cmp $other;
    }, 'cmp_op');
}

sub _spaceship_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->fileno if ref($other) && ref($other) eq ref($self);
        return $swap ? $other <=> $self->fileno : $self->fileno <=> $other;
    }, 'spaceship_op');
}

################################################################################
# Constructor method
sub new {
    my ($class, $ref, %options) = @_;
    my $self = bless {
        is => 'io',
        io => $ref,
        io_type => 'UNKNOWN',
        buffer_size => 8192,
        encoding => 'raw',
        compression => 0,
        compression_threshold => 1024,
        compression_level => 6,
        flush_interval => undef,
        last_flush_time => undef,
    }, $class;
    
    return $self->try(sub {
        $self->_init(%options);
        $self->{last_flush_time} = time();
        return $self->_determine_io_type();
    }, 'new', $class, $ref, \%options);
}

################################################################################
# Determine the specific type of IO handle
sub _determine_io_type {
    my ($self) = @_;
    return $self unless defined $self->{io};
    return $self->sync(sub {
        if (-S $self->{io}) {
            $self->{io_type} = 'SOCKET';
        } elsif (-p $self->{io}) {
            $self->{io_type} = 'PIPE';
        } elsif (-t $self->{io}) {
            $self->{io_type} = 'TTY';
        } elsif (-e $self->{io}) {
            if (-f $self->{io}) {
                $self->{io_type} = 'FILE';
            } elsif (-d $self->{io}) {
                $self->{io_type} = 'DIR';
            } elsif (-l $self->{io}) {
                $self->{io_type} = 'LINK';
            }
        } else {
            $self->{io_type} = 'UNKNOWN';
        }
        return $self
    }, '_determine_io_type');
}

# Get the IO type
sub io_type {
    my ($self) = @_;
    return $self->sync(sub {
        return $self->{io_type};
    }, 'io_type');
}

################################################################################
# Set the IO handle
sub set {
    my ($self, $filehandle) = @_;
    return $self->sync(sub {
        $self->{io} = $filehandle;
        return $self->_determine_io_type()
    }, 'set', $filehandle);
}

# Get the IO handle
sub get {
    my ($self) = @_;
    return $self->sync(sub { return $self->{io} }, 'get');
}

################################################################################
# Get file descriptor
sub fileno {
    my ($self) = @_;
    return $self->sync(sub {
        return 0 if !defined $self->{io};
        return CORE::fileno($self->{io});
    }, 'fileno');
}

# Set binary mode
sub binmode {
    my ($self, $layer) = @_;
    $layer //= ':raw :bytes';
    return $self->sync(sub {
        return CORE::binmode($self->{io}, $layer);
    }, 'binmode', $layer);
}

# Get file stat
sub stat {
    my ($self) = @_;
    return $self->sync(sub {
        my @stat = CORE::stat($self->{io});
        $self->throw("Cannot get file mode: $!", 'IO_ERROR') unless @stat;
        return @stat
    }, 'stat');
}

################################################################################
# Set file permissions
sub chmod {
    my ($self, $mode) = @_;
    return $self->sync(sub {
        return CORE::chmod($mode, $self->{io})
    }, 'chmod', $mode);
}

# Get file permissions
sub ismod {
    my ($self) = @_;
    return $self->sync(sub {
        my @stat = $self->stat;
        return $stat[2] & 07777;
    }, 'ismod');
}

################################################################################
# Set file owner
sub chown {
    my ($self, $uid, $gid) = @_;
    return $self->sync(sub {
        my $result = CORE::chown($uid, $gid, $self->{io});
        $self->throw("Failed to set owner: $!", 'IO_ERROR') unless $result;
        return $result;
    }, 'chown', $uid, $gid);
}

# Get file owner
sub isown {
    my ($self) = @_;
    return $self->sync(sub {
        my @stat = $self->stat;
        return ($stat[4], $stat[5]);
    }, 'isown');
}

################################################################################
# Get file size
sub size {
    my ($self) = @_;
    return $self->sync(sub {
        return -s $self->{io};
    }, 'size');
}

################################################################################
# Create a temporary file
sub temporary {
    my ($self,$mode,@args) = @_;
    return $self->sync(sub {
        my ($fh, $filename) = tempfile(@args);
        if (defined $mode) {
            CORE::close($fh);
            $self->open($filename, $mode);
        } else {
            $self->{io} = $fh;
        }
        $self->{filename} = $filename;
        return $filename
    }, 'temporary');
}

################################################################################
# Open a file
sub open {
    my ($self, $filename, $mode) = @_;
    $mode //= '+<';
    #
    # Basic Modes
    #
    #    <   Read-only mode.
    #         Opens an existing file for reading. The file must exist.
    #
    #    >   Write-only mode.
    #         Opens a file for writing, truncating the file to zero length if it
    #         already exists. If the file does not exist, it is created.
    #
    #    >>  Append mode.
    #         Opens a file for writing, appending new data to the end of the file. If the file does not exist, it is created.
    #
    # Read/Write Modes
    #
    #    +<  Read/write mode (without truncation).
    #         Opens an existing file for both reading and writing without truncating it. The file must exist.
    #
    #    +>  Read/write mode (with truncation).
    #         Opens a file for both reading and writing. The file is truncated to zero length if it already exists, or created if it doesn't.
    #
    #    +>> Read/append mode.
    #         Opens a file for both reading and appending. The file must exist, or it will be created. Writes are always appended to the end of the file, but you can still read from any position.
    #
    # Additional Notes (Pipes)
    #
    #    |   Can be used to open a filehandle to or from a command.
    #
    #    |-  Opens a pipe to a command (write to the command).
    #
    #    -|  Opens a pipe from a command (read the output of the command).
    #
    return $self->sync(sub {
        no strict qw(refs);
        CORE::open($self->{io}, $mode, $filename) or $self->throw("Cannot open file $filename: $!", 'IO_ERROR');
        $self->binmode(":$self->{encoding}") if $self->{encoding} ne 'raw';
        return $self->_determine_io_type;
    }, 'open', $filename, $mode);
}

# Open a directory
sub opendir {
    my ($self, $dirname) = @_;
    return $self->sync(sub {
        no strict qw(refs);
        CORE::opendir($self->{io}, $dirname) or $self->throw("Cannot open file $dirname: $!", 'IO_ERROR');
        return $self->_determine_io_type;
    }, 'opendir', $dirname);
}

# Check if file is open
sub is_open {
    my ($self) = @_;
    return $self->sync(sub {
        return defined $self->{io} && defined $self->fileno;
    }, 'is_open');
}

sub filename {
    my ($self) = @_;
    return $self->sync(sub {
        my $filename;
        $self->throw("No Open IO Handle","EMPTY_HANDLER") if !defined $self->{io};
        my $fh = $self->{io};
        my $fd = $self->fileno;
        $self->throw("No IO File descriptor","NO_FILE_DESCRIPTOR")  if !defined $fd;
        # Ensure the filehandle is valid
        $self->throw("Invalid filehandle provided ($fh, $fd)","NO_FILE_HANDLE") unless defined $fh && $fd >= 0;
        my $os = $^O;  # Get the OS name
        if ($os eq 'darwin' || $os eq 'linux') {
            # Linux: Use readlink on /proc/self/fd/
            $filename = CORE::readlink("/proc/self/fd/$fd");
            $self->throw("readlink on /proc/self/fd/$fd failed: $!","FAILED_READLINK") unless defined $filename;
        } elsif ($os eq 'MSWin32') {
            # Windows: Use Win32API::File to get the filename
            eval {
                require Win32API::File;
                $filename = Win32API::File::GetFileName(GetOsFHandle($fh));
            };
            $self->throw("Windows API call failed: $@") if ($@);
        }  else {
            return $self->{filename} if defined $self->{filename};
            $self->throw("Unsupported OS: $os","OS_ERROR");
        }

        # Return the filename if found, otherwise undef
        return defined $filename ? abs_path($filename) : undef;
    });
}
################################################################################
# Rename the file
sub rename {
    my ($self,$newname) = @_;
    return $self->sync(sub {
        if (defined $self->{io} && defined $self->fileno && defined $self->{filename}) {
            if (CORE::rename($self->filename, $newname)) {
                return $self->{filename} = $newname
            }
        }
        return undef
    }, 'rename',$newname);
}

################################################################################
# Close the file/socket
sub close {
    my ($self) = @_;
    $self->flush;
    return $self->sync(sub {
        return 0 unless defined $self->{io};
        $self->throw("Cannot close file: $!", 'IO_ERROR') unless (CORE::close($self->{io}));
        $self->{io} = undef;
        return 1;
    }, 'close');
}

################################################################################
# Close the dir
sub closedir {
    my ($self) = @_;
    return $self->sync(sub {
        $self->flush;
        unless (CORE::closedir($self->{io})) {
            $self->throw("Cannot close file: $!", 'IO_ERROR');
        }
        $self->{io} = undef;
        return 1;
    }, 'closedir');
}

################################################################################
# Clear the file
sub clear {
    my ($self) = @_;
    return $self->sync(sub {
        $self->{io}->flush() or $self->throw("Cannot flush file: $!", 'IO_ERROR');
        CORE::truncate($self->{io}, 0) or $self->throw("Cannot truncate file: $!", 'IO_ERROR');
        CORE::seek($self->{io}, 0, SEEK_SET) or $self->throw("Cannot seek in file: $!", 'IO_ERROR');
        return $self;
    }, 'clear');
}

################################################################################
# Check if the IO handle is ready for reading and optionally execute a callback
sub can_read {
    my ($self, $timeout, $callback, @args) = @_;
    return $self->sync(sub {
        # Default timeout to 0 (non-blocking)
        $timeout = 0 unless defined $timeout;
        my $rin = ''; vec($rin, $self->fileno, 1) = 1;
        if (select($rin, undef, undef, $timeout) > 0) {
            return $callback->($self, @args) if defined $callback && ref($callback) eq 'CODE';
            return 1;
        }
        return 0;
    }, 'can_read', $timeout, $callback, \@args);
}

# Read from the file
sub read {
    my ($self, $buffer, $length, $offset) = @_;
    $offset //= 0;
    return $self->sync(sub {
        my $bytes_read = CORE::read($self->{io}, $$buffer, $length, $offset);
        $self->throw("Read error: $!", 'IO_ERROR') unless (defined $bytes_read);
        # Handle decompression if needed
        $$buffer = Compress::Zlib::uncompress($$buffer) if $self->{compression} && $bytes_read >= $self->{compression_threshold};
        # Handle encoding if needed
        if ($self->{encoding} ne 'raw') {
            eval { $$buffer = decode($self->{encoding}, $$buffer, Encode::FB_CROAK) };
            $self->throw("Decoding error: $@", 'ENCODING_ERROR') if ($@);
        }
        return $bytes_read;
    }, 'read', \$buffer, $length, $offset);
}

sub recv {
    my ($self, $buffer, $length, $flags) = @_;
    $flags //= 0;  # 0 means no flags
    return $self->sync(sub {
        my $bytes_recv = CORE::recv($self->{io}, $$buffer, $length, $flags);
        $self->throw("Read error: $!", 'IO_ERROR') unless (defined $bytes_recv);
        # Handle decompression if needed
        $$buffer = Compress::Zlib::uncompress($$buffer) if $self->{compression} && $bytes_recv >= $self->{compression_threshold};
        # Handle encoding if needed
        if ($self->{encoding} ne 'raw') {
            eval { $$buffer = decode($self->{encoding}, $$buffer, Encode::FB_CROAK) };
            $self->throw("Decoding error: $@", 'ENCODING_ERROR') if ($@);
        }
        return $bytes_recv;
    }, 'recv', \$buffer, $length, $flags);
}

# Read the Directory from the DIRHANDLE
sub readdir {
    my ($self) = @_;
    return $self->sync(sub {
        return CORE::readdir($self->{io});
    }, 'readdir');
}

# Read a line from the file
sub readline {
    my ($self) = @_;
    return $self->sync(sub {
        my $line = CORE::readline($self->{io});
        if ($line) {
            $line = Compress::Zlib::uncompress($line) if $self->{compression} && length($line) >= $self->{compression_threshold};
            if ($self->{encoding} ne 'raw') {
                eval {
                    $line = decode($self->{encoding}, $line, Encode::FB_CROAK);
                };
                if ($@) {
                    $self->throw("Decoding error: $@", 'ENCODING_ERROR');
                }
            }
            return $line;
        }
    }, 'readline');
}

# Read the link from the symlink
sub readlink {
    my ($self) = @_;
    return $self->sync(sub {
        return CORE::readlink($self->{io});
    }, 'readlink');
}

# Read input from the PIPE
sub readpipe {
    my ($self) = @_;
    return $self->sync(sub {
        return CORE::readpipe($self->{io});
    }, 'readpipe');
}

# Read a line from the file
sub getc {
    my ($self) = @_;
    return $self->sync(sub {
        return CORE::getc(*$self->{io});
    }, 'getc');
}

# Get a line from the file
sub getline {
    my ($self) = @_;
    return $self->sync(sub {
        my $line = $self->{io}->getline();
        if ($line) {
            $line = Compress::Zlib::uncompress($line) if $self->{compression} && length($line) >= $self->{compression_threshold};
            if ($self->{encoding} ne 'raw') {
                eval {
                    $line = decode($self->{encoding}, $line, Encode::FB_CROAK);
                };
                if ($@) {
                    $self->throw("Decoding error: $@", 'ENCODING_ERROR');
                }
            }
            return $line;
        }
    }, 'getline');
}

# Get all lines from the file
sub getlines {
    my ($self) = @_;
    return $self->sync(sub {
        my @lines = $self->{io}->getlines();
        if ($self->{compression}) {
            @lines = map { 
                length($_) >= $self->{compression_threshold} ? 
                    Compress::Zlib::uncompress($_) : $_ 
            } @lines;
        }
        if ($self->{encoding} ne 'raw') {
            eval {
                @lines = map { decode($self->{encoding}, $_, Encode::FB_CROAK) } @lines;
            };
            if ($@) {
                $self->throw("Decoding error: $@", 'ENCODING_ERROR');
            }
        }
        return @lines;
    }, 'getlines');
}

################################################################################
# Check if the IO handle is ready for writing and optionally execute a callback
sub can_write {
    my ($self, $timeout, $callback, @args) = @_;
    return $self->sync(sub {
        # Default timeout to 0 (non-blocking)
        $timeout = 0 unless defined $timeout;
        my $win = ''; vec($win, $self->fileno, 1) = 1;
        if (select(undef, $win, undef, $timeout) > 0) {
            return $callback->($self, @args) if defined $callback && ref($callback) eq 'CODE';
            return 1;
        }
        return 0;
    }, 'can_write', $timeout, $callback, \@args);
}

# Write to the file
sub write {
    my ($self, $buffer, $length, $offset) = @_;
    return $self->sync(sub {
        # Handle encoding if needed
        if ($self->{encoding} ne 'raw') {
            eval { $$buffer = encode($self->{encoding}, $$buffer, Encode::FB_CROAK) };
            $self->throw("Encoding error: $@", 'ENCODING_ERROR') if ($@);
        }
        # Handle compression if needed
        $$buffer = Compress::Zlib::compress($$buffer, $self->{compression_level}) if $self->{compression} && length($$buffer) >= $self->{compression_threshold};
        $self->seek($offset) if defined $offset;
        my $bytes_written = CORE::print { $self->{io} } $$buffer;
        $self->throw("Write error: $!", 'IO_ERROR') unless (defined $bytes_written);
        # Flush if necessary
        $self->_check_flush if !$self->{autoflush};
        return $bytes_written;
    }, 'write', $buffer, $length, $offset);
}

sub send {
    my ($self, $buffer, $length, $flags) = @_;
    $flags //= 0;
    return $self->sync(sub {
        # Handle encoding if needed
        if ($self->{encoding} ne 'raw') {
            eval { $$buffer = encode($self->{encoding}, $$buffer, Encode::FB_CROAK) };
            $self->throw("Encoding error: $@", 'ENCODING_ERROR') if ($@);
        }
        # Handle compression if needed
        $$buffer = Compress::Zlib::compress($$buffer, $self->{compression_level}) if $self->{compression} && length($$buffer) >= $self->{compression_threshold};
        my $bytes_send = CORE::send($self->{io}, $$buffer, 0);
        $self->throw("Write error: $!", 'IO_ERROR') unless defined $bytes_send;
        # Flush if necessary
        $self->_check_flush if !$self->{autoflush};
        return $bytes_send;
    }, 'send', $buffer, $length, $flags);
}

# Print to the file
sub print {
    my ($self, @args) = @_;
    return $self->sync(sub {
        my $select = select($self->{io});
        my $result = CORE::print(@args);
        $self->_check_flush if !$self->{autoflush};
        return $result;
    }, 'print', \@args);
}

# Printf to the file
sub printf {
    my ($self, $format, @args) = @_;
    return $self->sync(sub {
        my $select = select($self->{io});
        my $result = CORE::printf($format, @args);
        $self->_check_flush if !$self->{autoflush};
        return $result;
    }, 'printf', $format, \@args);
}

# Say to the file
sub say {
    my ($self, @args) = @_;
    return $self->sync(sub {
        my $select = select($self->{io});
        my $result = CORE::say(@args);
        $self->_check_flush if !$self->{autoflush};
        return $result;
    }, 'say', \@args);
}

# Truncate the file
sub truncate {
    my ($self, $length) = @_;
    return $self->sync(sub {
        return CORE::truncate($self->{io},$length);
    }, 'truncate');
}

################################################################################
# Seek in the file
sub seek {
    my ($self, $position, $whence) = @_;
    $whence //= SEEK_SET;
    return $self->sync(sub {
        return CORE::seek($self->{io},$position, $whence);
    }, 'seek', $position, $whence);
}

# Seek in the directory
sub seekdir {
    my ($self, $position) = @_;
    return $self->sync(sub {
        return CORE::seekdir($self->{io},$position);
    }, 'seekdir', $position);
}

# Get current position in the file
sub tell {
    my ($self) = @_;
    return $self->sync(sub {
        return CORE::tell($self->{io});
    }, 'tell');
}

# Get current position in the directory
sub telldir {
    my ($self) = @_;
    return $self->sync(sub {
        return CORE::telldir($self->{io});
    }, 'telldir');
}

# Check if at end of file
sub eof {
    my ($self) = @_;
    return $self->sync(sub {
        select($self->{io});
        return CORE::eof;
    }, 'eof');
}

################################################################################
# Flush the file
sub flush {
    my ($self) = @_;
    return $self->sync(sub {
        return if !defined $self->{io};
        my $result = $self->{io}->flush();
        $self->{last_flush_time} = time();
        return $result;
    }, 'flush');
}

# Internal methods
sub _check_flush {
    my ($self) = @_;
    return $self->sync(sub {
        $self->flush if (!defined $self->{flush_interval}) || (time() - $self->{last_flush_time} >= $self->{flush_interval});
    }, '_check_flush');
}

# Set autoflush
sub autoflush {
    my ($self, $value) = @_;
    $value //= 1;
    return $self->sync(sub {
        $self->{autoflush} = $value;
        return $self->{io}->autoflush($value);
    }, 'autoflush');
}

sub flush_interval {
    my ($self, $interval) = @_;
    return $self->sync(sub { 
        $self->{flush_interval} = $interval if defined $interval;
        return $self->{flush_interval}
    }, 'flush_interval');
}

################################################################################
# Set and get methods for various properties
sub buffer {
    my ($self, $size) = @_;
    return $self->sync(sub { 
        $self->{buffer_size} = $size if defined $size;
        return $self->{buffer_size}
    }, 'buffer', $size);
}

################################################################################
sub encoding {
    my ($self, $encoding) = @_;
    return $self->sync(sub {
        $self->{encoding} = $encoding if defined $encoding;
        $self->binmode(":$encoding") if defined $encoding && $self->is_open && $encoding ne 'raw';
        return $self->{encoding}
    }, 'encoding', $encoding);
}

################################################################################
sub compression {
    my ($self, $level) = @_;
    return $self->sync(sub {
        $self->{compression} = $level ? 1 : 0 if defined $level;
        return $self->{compression}
    }, 'compression', $level);
}

sub compression_level {
    my ($self, $level) = @_;
    return $self->sync(sub {
        $self->{compression_level} = $level if defined $level && $level > 1;
        return $self->{compression_level}
    }, 'compression_level', $level);
}

################################################################################
# Lock File
sub lock_io {
    my ($self, $operation) = @_;
    $operation //= LOCK_EX;
    return $self->sync(sub {
        return CORE::flock($self->{io}, $operation);
    }, 'lock_io');
}

# Unlock File
sub unlock_io {
    my ($self) = @_;
    return $self->sync(sub {
        return CORE::flock($self->{io}, LOCK_UN);
    }, 'unlock_io');
}

################################################################################
# Copy file contents to another file
sub copy_to {
    my ($self, $destination, $buffer_size) = @_;
    $buffer_size //= 8192;
    return $self->sync(sub {
        my $total_bytes = 0;
        my $buffer;
        my $df = ref($self) eq ref($destination) ? $destination : $self->new->open($destination,">");
        while (my $bytes_read = $self->read(\$buffer, $buffer_size)) {
            $df->write(\$buffer, $bytes_read, $total_bytes) or $self->throw("Write error during copy: $!", 'IO_ERROR');
            $total_bytes += $bytes_read;
        }
        return $total_bytes;
    }, 'copy_to', $destination, $buffer_size);
}

################################################################################
# Get file size
sub unlink {
    my ($self) = @_;
    my $filename = $self->filename;
    return $self->sync(sub {
        $self->close or $self->throw("Close error: $!", 'IO_ERROR');
        return CORE::unlink($filename) if defined $filename && -e $filename;
    }, 'size');
}

################################################################################
# Securely delete file contents
sub secure_delete {
    my ($self) = @_;
    return $self->sync(sub {
        my $size = $self->size;
        $self->seek(0, SEEK_SET) or $self->throw("Seek error: $!", 'IO_ERROR');
        for (1..3) {
            $self->write(\("\0" x $size)) or $self->throw("Write error during secure delete: $!", 'IO_ERROR');
            $self->write(\("\xFF" x $size)) or $self->throw("Write error during secure delete: $!", 'IO_ERROR');
            $self->write(\(join('', map { chr(rand(256)) } 1..$size))) or $self->throw("Write error during secure delete: $!", 'IO_ERROR');
        }
        $self->truncate(0) or $self->throw("Truncate error: $!", 'IO_ERROR');
        $self->unlink or $self->throw("Unlink error: $!", 'IO_ERROR');
        return 1;
    }, 'secure_delete');
}

################################################################################
# Perform an atomic operation
sub atomic_operation {
    my ($self, $code) = @_;
    return $self->sync($code, 'atomic_operation', $code);
}


################################################################################
# IO Socket Accept
use Socket;
sub accept {
    my ($self, $port, $callback) = @_;
    return $self->sync(sub {
        $self->{port} = $port;
        $self->{callback} = $callback;
        $self->{proto} = getprotobyname("tcp");
        socket($self->{io}, PF_INET, SOCK_STREAM, $self->{proto}) || $self->throw("Socket: $!",'SOCKET_OPEN_ERROR');
        setsockopt($self->{io}, SOL_SOCKET, SO_REUSEADDR, pack("l",1)) || $self->throw("setSockOpr: $!","SOCKET_OPTION_ERROR");
        bind($self->{io}, sockaddr_in($self->{port}, INADDR_ANY)) || $self->throw("Bind: $!","SOCKET_BIND_ERROR");
        listen($self->{io}, SOMAXCONN) || $self->throw("Listen: $!","SOCKET_LISTEN_ERROR");
        return $self
    }, 'accept', $port);
}
sub listen {
    my ($self)=@_;
    return $self->try(sub {
        $self->throw("IO Not setup to accept connections","LISTEN_ERROR") if !defined $self->{callback} && ref($self->{callback}) ne 'CODE';
        while (
            !$self->{quit} && 
            (my $paddr = CORE::accept(my $client, $self->{io}))
        ) {
            my ($port, $ip) = sockaddr_in($paddr);
            my $host = gethostbyaddr($ip, AF_INET);
            print STDOUT "Connection from $host [",inet_ntoa($ip), "] at port $port";
            $client = $self->new($client);
            $client->{port} = $port;
            $client->{host} = $host;
            $client->{ip} = $ip;
            $self->{callback}->($self,$client);
        }
        $self->close();
    },'listen');
}
#
# Example use:
#
#   Ic()->accept('8080',sub {
#       my ($server,$client)=@_;
#       Cc(sub {
#           my ($server,$client)=@_;
#           my $out = "Hello there $client->{host}, it's now ".(scalar localtime())."\n";
#           my $len = length($out);
#           my $send = $client->send(\$out,$len);
#           $client->close();
#           if ($send != $len) warn "Not all data send: $send of $len";
#       })->detach($server,$client);
#   })->listen();
#
################################################################################

1;

################################################################################
# EOF iclass.pm (C) 2024 OnEhIppY, Domero Software
################################################################################
