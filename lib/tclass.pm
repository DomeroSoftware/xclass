################################################################################

# tclass.pm - Advanced Thread Control and Management Class for xclass Ecosystem

#
# This class provides a robust and feature-rich interface for creating, managing,
# and controlling threads with integrated shared data handling through xclass-
# wrapped GLOB references. It offers a comprehensive set of thread management
# capabilities, including:
#
# - Thread lifecycle management (creation, starting, stopping, detaching, joining)
# - Shared data handling through GLOB references with type-specific access
# - Extended class support for complex thread-specific data structures
# - Customizable error and kill signal handling
# - Thread-safe operations and synchronization
# - High-resolution timing functions for precise thread control
# - Comprehensive status tracking and reporting
# - Support for both detached and joinable threads
# - Graceful termination and cleanup mechanisms
#
# Key Features:
# - Seamless integration with xclass ecosystem
# - Thread-safe operations using lclass synchronization
# - Flexible shared data management with support for various data types
# - Event-driven architecture with customizable triggers
# - Advanced error handling and reporting
# - Support for extended classes and custom data structures
# - High-resolution sleep and yield functions for fine-grained thread control
# - Comprehensive string representation and comparison methods
#
# This class is designed to provide a powerful yet easy-to-use interface for
# complex multi-threaded applications within the xclass framework, ensuring
# thread safety, proper resource management, and extensibility.
#
# Author: OnEhIppY, Domero Software
# Copyright: (C) 2024 OnEhIppY, Domero Software
#
# Dependencies:
# - Perl v5.8.0 or higher
# - threads
# - threads::shared
# - lclass (for utility methods and thread-safe operations)
# - xclass (for handling specific reference types)
# - Scalar::Util (for type checking)
# - Time::HiRes (for high-resolution time)

################################################################################

package tclass;

use strict;
use warnings;
use threads;
use threads::shared;
use Scalar::Util qw(blessed reftype);
use Time::HiRes;

our $VERSION = '2.0.0';

BEGIN {
    xclass::register('THREAD', 'tclass');
}

use lclass qw(:thread);

################################################################################

use overload
    '""'    => \&_stringify_op,
    '0+'    => \&_numify_op,
    'bool'  => \&_bool_op,
    '=='    => \&_eq_op,
    '!='    => \&_ne_op,
    '<=>'   => \&_spaceship_op,
    'cmp'   => \&_cmp_op,
    '+'     => \&_add_op,
    '-'     => \&_sub_op,
    fallback => 1;

sub _stringify_op { shift->to_string }
sub _numify_op { my $self = shift; return $self->tid // 0; }
sub _bool_op { my $self = shift; return $self->running; }

sub _array_deref_op {
    my $self = shift;
    return [$self->status, $self->tid, $self->{name}, $self->{space}];
}

sub _eq_op {
    my ($self, $other, $swap) = @_;
    return $self->tid == $other->tid if blessed($other) && $other->isa(__PACKAGE__);
    return 0;
}

sub _ne_op {
    my ($self, $other, $swap) = @_;
    return !$self->_eq($other);
}

sub _spaceship_op {
    my ($self, $other, $swap) = @_;
    return ($swap ? $other->tid <=> $self->tid : $self->tid <=> $other->tid)
        if blessed($other) && $other->isa(__PACKAGE__);
    return -1;
}

sub _cmp_op {
    my ($self, $other, $swap) = @_;
    my $self_str = "$self";
    my $other_str = blessed($other) && $other->isa(__PACKAGE__) ? "$other" : $other;
    return $swap ? $other_str cmp $self_str : $self_str cmp $other_str;
}

sub _add_op {
    my ($self, $other, $swap) = @_;
    if (blessed($other) && $other->isa(__PACKAGE__)) {
        # Combine shared data of two threads
        return $self->HASH->merge($other->HASH);
    } elsif (!ref $other) {
        # Add a value to all numeric elements in shared data
        return $self->HASH->map(sub {
            my ($k, $v) = @_;
            return ($k, (looks_like_number($v) ? $v + $other : $v));
        });
    }
    return $self;
}

sub _sub_op {
    my ($self, $other, $swap) = @_;
    if (!$swap && !ref $other) {
        # Subtract a value from all numeric elements in shared data
        return $self->HASH->map(sub {
            my ($k, $v) = @_;
            return ($k, (looks_like_number($v) ? $v - $other : $v));
        });
    }
    return $self;
}

################################################################################
# Constructor
sub new {
    my ($class, $space, $name, %options) = @_;
    no strict 'refs';
    die "Thread already exists: ${space}::${name}" if defined *{"${space}::${name}"}{CODE};
    die "Thread space (and name) must be provided" unless $space;
    my $status :shared = 'initialized';
    my $detached :shared = 0;
    my $self = bless {
        space => $space,
        name => $name // '',
        is => 'glob',
        glob => gclass->new($space,$name,%options)->share_it,
        thread => undef,
        status => \$status,
        extended => {},
        on_kill => $options{on_kill} // undef,
        on_error => $options{on_error} // undef,
        detached => \$detached,
        %options
    }, $class;

    return $self->try(sub {
        $self->_init(%options);
        return $self;
    }, 'new', $class, $space, $name, \%options);
}

# Link Thread to the NameSpace
sub link_it {
    my ($self)=@_;
    $self->{glob}->SCALAR(\$self);
    return $self
}

# Check if a thread with given space and name already exists
sub exists {
    my ($class, $space, $name) = @_;
    no strict 'refs';
    return defined *{"${space}::${name}"}{CODE};
}

# Start the thread
sub start {
    my ($self, @args) = @_;
    return $self->sync(sub {
        $self->throw("Thread already running") if ${$self->{status}} eq 'running';
        $self->throw("No code reference provided for thread") unless $self->{glob}->CODE && $self->{glob}->CODE->is_defined;
        $self->{thread} = threads->create(sub {
            ${$self->{status}} = 'running';
            eval { $self->{glob}->CODE->call($self, @args) };
            if ($@) {
                ${$self->{status}} = 'error';
                $self->_handle_error($@);
            } else {
                ${$self->{status}} = 'finished';
            }
            # Clean up detached thread
            $self->_cleanup() if (${$self->{detached}});
        });
        # Detach immediately if requested
        #print STDOUT "Hash:". $self->{glob}->HASH->to_string."\n" if *{$self->{glob}{glob}}{HASH};
        $self->detach() if *{$self->{glob}{glob}}{HASH} && *{$self->{glob}{glob}}{HASH}{auto_detach};
        return $self;
    }, 'start', \@args);
}

# Detach the thread
sub detach {
    my ($self) = @_;
    return $self->sync(sub {
        #print STDOUT "Detaching\n";
        $self->throw("Thread not started") unless $self->{thread};
        $self->throw("Thread already detached") if ${$self->{detached}};
        $self->{thread}->detach();
        ${$self->{detached}} = 1;
        return $self;
    }, 'detach');
}

# Check if thread is detached
sub detached {
    my ($self,$new) = @_;
    return $self->sync(sub {
        ${$self->{detached}} = $new if defined $new;
        return ${$self->{detached}};
    }, 'detached');
}

# Stop the thread
sub stop {
    my ($self, $timeout) = @_;
    return $self->sync(sub {
        return if ${$self->{status}} eq 'finished' || ${$self->{status}} eq 'error';
        #$self->throw("Cannot stop detached thread","DETACHED_THREAD_ERROR") if ${$self->{detached}};
        ${$self->{status}} = 'stopping';
        #print STDOUT "Stop: ".${$self->{status}}."\n";
        $self->_handle_kill();
        unless (${$self->{detached}}) {
            $self->{thread}->join();
            ${$self->{status}} = 'finished';
        };
        return $self;
    }, 'stop');
}

# Graceful stop check (to be used in thread code)
sub should_stop {
    my ($self) = @_;
    return $self->sync(sub {
        return ${$self->{status}} eq 'stopping';
    }, 'should_stop');
}

# Get thread status
sub status {
    my ($self,$new) = @_;
    return $self->sync(sub {
        ${$self->{status}} = $new if defined $new;
        return ${$self->{status}};
    }, 'status');
}

# Get thread ID
sub tid {
    my ($self) = @_;
    return $self->sync(sub {
        return $self->{thread} ? $self->{thread}->tid : 0;
    }, 'tid');
}

# Check if thread is running
sub running {
    my ($self) = @_;
    return $self->sync(sub {
        #print STDOUT "Status: ${$self->{status}}\n";
        return ${$self->{status}} eq 'running';
    }, 'running');
}

# Wait for thread to finish
sub join {
    my ($self, $timeout) = @_;
    return $self->sync(sub {
        return unless $self->{thread};
        $self->throw("Cannot join detached thread","THREAD_DETACHED") if ${$self->{detached}};
        if (defined $timeout) {
            $self->{thread}->join($timeout) or $self->throw("Thread did not finish within timeout","THREAD_JOIN_TIMEOUT");
        } else {
            $self->{thread}->join();
        }
        $self->status('finished');
        return $self;
    }, 'join', $timeout);
}

# Glob accessories
sub SCALAR { my ($self,@args) = @_; return $self->{glob}->SCALAR(@args) }
sub ARRAY { my ($self,@args) = @_; return $self->{glob}->ARRAY(@args) }
sub HASH { my ($self,@args) = @_; return $self->{glob}->HASH(@args) }
sub CODE { my ($self,@args) = @_; return $self->{glob}->CODE(@args) }
sub IO { my ($self,@args) = @_; return $self->{glob}->IO(@args) }

# Get a reference to shared data
sub get {
    my ($self, $key) = @_;
    return $self->sync(sub {
        if ($key eq 'SCALAR') { return $self->{glob}->SCALAR }
        elsif ($key eq 'ARRAY') { return $self->{glob}->ARRAY }
        elsif ($key eq 'HASH') { return $self->{glob}->HASH }
        elsif ($key eq 'CODE') { return $self->{glob}->CODE }
        elsif ($key eq 'IO') { return $self->{glob}->IO }
        else { return $self->{glob}->HASH->get($key) }
    }, 'get', $key);
}

# Set a reference to shared data
sub set {
    my ($self, $key, $value) = @_;
    return $self->sync(sub {
        if ($key eq 'SCALAR') { $self->{glob}->SCALAR($value) }
        elsif ($key eq 'ARRAY') { $self->{glob}->ARRAY($value) }
        elsif ($key eq 'HASH') { $self->{glob}->HASH($value) }
        elsif ($key eq 'CODE') { $self->{glob}->CODE($value) }
        elsif ($key eq 'IO') { $self->{glob}->IO($value) }
        else { $self->{glob}->HASH->set($key, $value) }
        return $self;
    }, 'set', $key, $value);
}

# Get an extended class
sub ext {
    my ($self, $key, $value) = @_;
    return $self->sync(sub {
        $self->{extended}{$key} = $value if defined $value;
        return $self->{extended}{$key};
    }, 'ext', $key, $value);
}

# Handle kill signal
sub _handle_kill {
    my ($self) = @_;
    return $self->sync(sub {
        if ($self->{on_kill} && ref($self->{on_kill}) eq 'CODE') {
            eval { $self->{on_kill}->($self) };
            warn "Error in on_kill handler: $@" if $@;
        }
    }, '_handle_kill');
}

# Handle error
sub _handle_error {
    my ($self, $error) = @_;
    return $self->sync(sub {
        if ($self->{on_error} && ref($self->{on_error}) eq 'CODE') {
            eval { $self->{on_error}->($self, $error) };
            warn "Error in on_error handler: $@" if $@;
        }
    }, '_handle_error', $error);
}

# Yield control (to be used in thread code)
sub yield {
    my ($self) = @_;
    return $self->sync(sub {
        threads->yield();
    }, 'yield');
}

# Sleep for a specified time (to be used in thread code)
sub sleep {
    my ($self, $seconds) = @_;
    Time::HiRes::sleep($seconds);
}

# CPU Sleep for a specified time (to be used in thread code)
sub usleep {
    my ($self, $nanoseconds) = @_;
    Time::HiRes::usleep($nanoseconds);
}

# Cleanup
sub _cleanup {
    my ($self) = @_;
    # Perform any necessary cleanup for detached threads
    # This method is called automatically when a detached thread finishes
    $self->trigger('cleanup');
}

# Get Thread Namespace
sub namespace { return shift->{glob}->namespace }

# Get hash code
sub hash_code {
    my ($self) = @_;
    return $self->sync(sub {
        return CORE::join(
            ':',
            $self->{space}, $self->{name},
            ${$self->{status}}, ${$self->{detached}},
            $self->{glob}->{scalar} ? $self->{glob}->SCALAR->md5 : 'NOSCALAR',
            $self->{glob}->{array} ? $self->{glob}->ARRAY->join(':') : 'NOARRAY',
            $self->{glob}->{hash} ? $self->{glob}->HASH->keys : 'NOHASH',
            $self->{glob}->{io} ? $self->{glob}->IO->fileno : 'NOIO',
            $self->{glob}->{code} ? length($self->{glob}->CODE->to_string) : 'NOCODE'
        );
        # Note: CODE and IO are not included in the hash code
    }, 'hash_code');
}

1;

################################################################################
# EOF tclass.pm (C) 2024 OnEhIppY, Domero Software
################################################################################
