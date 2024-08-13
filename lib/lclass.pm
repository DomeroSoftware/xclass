#!/usr/bin/env perl

################################################################################
# lclass.pm - Advanced Thread-Safe Base Utility Class for xclass Ecosystem
#
# This class serves as the foundation for the entire xclass ecosystem, providing
# core functionality, utilities, and advanced features for building robust,
# thread-safe, and feature-rich specialized classes.
#
# Key Features:
# - Thread-safe operations with advanced locking mechanisms
# - Comprehensive error handling and exception system
# - Flexible serialization and deserialization (JSON, YAML, Storable, MessagePack)
# - Memory management and optimization utilities
# - Asynchronous operations support (Future, Promise)
# - Advanced event system for inter-object communication
# - Profiling and benchmarking capabilities
# - Caching system with configurable strategies
# - Plugin system for extensibility
# - Security features including input sanitization and data encryption
# - Comprehensive type constraints and validation
#
# Core Functionalities:
# - Reference handling and type-specific operations
# - Shared data management for multi-threaded environments
# - Cloning and deep copying of complex data structures
# - Weak reference management
# - Configurable logging and debugging facilities
#
# Performance Features:
# - Memory usage tracking and circular reference detection
# - Code profiling and benchmarking tools
# - Configurable caching system
#
# Security Features:
# - Input sanitization
# - Data encryption and decryption
# - Type constraints and validation
#
# Extensibility:
# - Plugin system for adding custom functionality
# - Event system for inter-object communication
# - Customizable serialization formats
#
# Integration with xclass Ecosystem:
# - Base class for all specialized xclass types (sclass, aclass, hclass, etc.)
# - Provides core utilities used throughout the ecosystem
# - Ensures consistency in thread-safety and error handling across all classes
#
# Usage:
# - Import specific functionalities using tags (e.g., use lclass qw(:core :performance))
# - Inherit from lclass for custom classes within the xclass ecosystem
# - Use as a standalone utility class for advanced Perl programming
#
# Version: 2.0.0
# Author: OnEhIppY, Domero Software
# Copyright: (C) 2024 OnEhIppY, Domero Software <domerosoftware@gmail.com>
#
# Dependencies:
# - Perl v5.8.0 or higher
# - Various CPAN modules (threads, JSON::XS, YAML::XS, Storable, etc.)
#
# Note: This class is designed to be a comprehensive solution for building
# robust, thread-safe, and high-performance Perl applications. It combines
# best practices in OOP, thread-safety, performance optimization, and security.
################################################################################

package lclass;

use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Semaphore;

use Storable qw(freeze thaw dclone);
use JSON::XS;
use YAML::XS;
use Data::MessagePack;

use B::Deparse;
use Scalar::Util qw(weaken isweak refaddr blessed);
use Time::HiRes qw(time sleep usleep);
use Log::Log4perl;
use Devel::Size qw(total_size);
use Devel::Cycle;

use gerr qw(:control);

our $VERSION = '2.0.0';

# Configuration
our %CONFIG = (
    debug_level => 0,
    use_cache => 1,
    cache_strategy => 'LRU',
    cache_size => 1000,
    serialization_format => 'json',
    max_recursion_depth => 10,
    enable_profiling => 0,
    enable_async => 1,
    security_level => 'normal',
    encryption_key => 'default_key_change_me',
);

# Initialize logging
Log::Log4perl->init(\<<'EOT');
    log4perl.rootLogger=WARN, Screen
    log4perl.appender.Screen=Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.layout=PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern=%d %p %m %n
EOT
our $logger = Log::Log4perl->get_logger();

# Plugin system
our %PLUGINS;

################################################################################
# Error Handling
################################################################################

sub throw {
    my ($self, $message, $code) = @_;
    $message //= 'fatal error';
    $code //= 'FATAL_ERROR';
    $logger->error("Exception: $message (Code: $code)");
    die "Exception [$code]: $message";
}

sub debug {
    my ($self, $message) = @_;
    $logger->error("Warning: $message");
    warn "Warning: $message";
}

sub try {
    my ($self, $code, $operation_name, @args) = @_;
    $operation_name //= 'try';
    my @result;
    eval {
        $self->trigger("before_$operation_name", \@args);
        @result = $code->(@args);
        $self->trigger("after_$operation_name", \@args, \@result);
    };
    if ($@) {
        my $error = $@;
        $self->trigger("error_$operation_name", $error, \@args);
        $self->throw("Error in $operation_name: $error", "${operation_name}_ERROR");
    }
    return wantarray ? @result : $result[0];
}

################################################################################
# Core Methods (from original implementation)
################################################################################

# Internal method to get the reference of the stored data
sub _ref { 
    my ($self) = @_;
    #$self->trigger('_ref');
#    $self->throw("Reference not initialized", 'REF_ERROR') unless defined $self->{$self->{is}};
    return $self->{is} && $self->{$self->{is}} ? $self->{$self->{is}} : undef;
}

# Check if the stored reference is shared
sub _shared {
    my ($self, $depth) = @_;
    $depth //= 0;
#    $self->trigger('before_shared', $depth);
    return 0 if $depth > 10;  # Prevent excessive recursion

    my $ref = $self->_ref;
    return 0 unless $ref;

    if ($self->{is} eq 'scalar') {
        return is_shared($ref);
    } elsif ($self->{is} eq 'array') {
        return is_shared($ref);
    } elsif ($self->{is} eq 'hash') {
        return is_shared($ref);
    } elsif ($self->{is} eq 'code') {
        return $self->{is_shared}; # is_shared($ref);
    } elsif ($self->{is} eq 'io') {
        return ref($ref) eq 'GLOB' ? 1 : is_shared($ref); # $self->{is_shared}; #
    } elsif ($self->{is} eq 'ref') {
        return is_shared($ref);
    } elsif ($self->{is} eq 'glob') {
        return $self->{is_shared}; # is_shared($ref);
    } else {
        $self->throw("Unknown type: $self->{is}", 'TYPE_ERROR');
    }

    #$self->trigger('after_shared');
}

sub share_it {
    my ($self) = @_;
    $self->trigger('before_share_it');
    return $self if ($self->_shared);

    $self->{sharing} //= 0; $self->{sharing}++;
    if ($self->{sharing} == 1) { # only share the first loop
        if ($self->{is} eq 'scalar')    { share(${$self->{scalar}}); $self->{scalar} = shared_clone($self->{scalar}); $self->{is_shared}=1; }
        elsif ($self->{is} eq 'array')  { share(@{$self->{array}}); $self->{array} = shared_clone($self->{array}); $self->{is_shared}=1; }
        elsif ($self->{is} eq 'hash')   { share(%{$self->{hash}}); $self->{hash} = shared_clone($self->{hash}); $self->{is_shared}=1; }
        elsif ($self->{is} eq 'code')   { $self->{code} = $self->{code}; $self->{is_shared}=1; }
        elsif ($self->{is} eq 'io')     { 
            $self->{io} = ref($self->{io}) eq 'GLOB' ? $self->{io} : shared_clone($self->{io}); 
            $self->{is_shared}=1;
        }
        elsif ($self->{is} eq 'ref')    { $self->{ref} = shared_clone($self->{ref}); $self->{is_shared}=1; }
        elsif ($self->{is} eq 'glob')   { 
            #$self->{glob} = shared_clone(\*{$self->{glob}});
            $self->{scalar}->share_it if defined $self->{scalar};
            $self->{array}->share_it if defined $self->{array};
            $self->{hash}->share_it if defined $self->{hash};
            $self->{code}->share_it if defined $self->{code};
            $self->{io}->share_it if defined $self->{io};
        }
        else { $self->throw("Cannot make $self->{is} shared", 'SHARE_ERROR') }

        $self->{is_shared}=1;

        $self->_init();

        $self->trigger('after_share_it');
    }else{
        print STDOUT "Blocked Sharing $self->{sharing}\n";
    }
    delete $self->{sharing};
    return $self;
}

# Initialize the object
sub _init {
    my ($self, %options) = @_;
    $self->trigger('before_init',\%options);
    $lclass::CONFIG{debug_level} = $options{debug} // $lclass::CONFIG{debug_level};
    
    if ($self->_shared || $self->{is} eq 'code' || $self->{is} eq 'io' || $self->{is} eq 'glob') {
        # Initialize shared resources
        $self->{lock_semaphore}     = Thread::Semaphore->new(1);
        $self->{lock_mutex}         = Thread::Semaphore->new(1);
        $self->{lock_owner}         = &share({});
        $self->{is_lightweight}     = 0;
    } else {
        # Unshare and clean up
        delete $self->{lock_semaphore} if defined $self->{lock_semaphore};
        delete $self->{lock_mutex} if defined $self->{lock_mutex};
        delete $self->{lock_owner} if defined $self->{lock_owner};
        $self->{is_lightweight}     = 1;
    }
    # Convert shared variables to unshared
    $self->{event_callbacks}    = {};
    $self->{profiling_data}     = {};
    $self->{type_constraints}   = {};
    $self->{cache}              = {};
    $self->{cache_order}        = [];

    $self->throw("Failed to initialize lock_semaphore", 'INIT_ERROR') if !$self->{is_lightweight} && !defined $self->{lock_semaphore};
    $self->throw("Failed to initialize lock_mutex", 'INIT_ERROR') if !$self->{is_lightweight} && !defined $self->{lock_mutex};
    $self->throw("Failed to initialize event_callbacks", 'INIT_ERROR') unless defined $self->{event_callbacks};
    $self->throw("Failed to initialize profiling_data", 'INIT_ERROR') unless defined $self->{profiling_data};
    $self->throw("Failed to initialize type_constraints", 'INIT_ERROR') unless defined $self->{type_constraints};
    $self->throw("Failed to initialize cache", 'INIT_ERROR') unless defined $self->{cache};
    $self->trigger('after_init',\%options);
}

################################################################################
# Locking Mechanisms
################################################################################

sub lock {
    my ($self) = @_;
    my $tid = threads->tid;
    return if $self->{is_lightweight} || !defined $self->{lock_semaphore};
    $self->debug("[Before_Lock]") if $lclass::CONFIG{debug_level};

    $self->{lock_semaphore}->down unless $self->{lock_owner}{$tid};
    $self->debug("\e[92m === Thread $tid attempting to aquire lock (owners: `".join('`, `',@{[keys %{$self->{lock_owner}}]})."`) === \e[39m") if $lclass::CONFIG{debug_level};
    
    if (!$self->{lock_owner}{$tid}) {
        $self->{lock_owner}{$tid}=1;
        $self->debug("\e[92m +++ Thread $tid acquired lock (count: $self->{lock_owner}{$tid}) +++ \e[39m") if $lclass::CONFIG{debug_level};
    } else {
        $self->{lock_owner}{$tid}++;
        $self->debug("\e[92m +++ Thread $tid re-acquired lock (count: $self->{lock_owner}{$tid}) +++ \e[39m") if $lclass::CONFIG{debug_level};
    }
}

sub unlock {
    my ($self) = @_;
    return if $self->{is_lightweight} || !defined $self->{lock_semaphore};

    my $tid = threads->tid;
    $self->debug("\e[94m === Lock Thread $tid Mutex === \e[39m") if $lclass::CONFIG{debug_level};
    $self->{lock_mutex}->down;
    $self->debug("\e[93m --- Thread $tid attempting to unlock (owners: `".join('`, `',@{[keys %{$self->{lock_owner}}]})."`) --- \e[39m") if $lclass::CONFIG{debug_level};

    if (defined $self->{lock_owner} && defined $self->{lock_owner}{$tid} && $self->{lock_owner}{$tid} > 0) {
        $self->{lock_owner}{$tid}--;
        if (!$self->{lock_owner}{$tid}) {
            delete $self->{lock_owner}{$tid};
            $self->{lock_semaphore}->up;
            $self->debug("\e[92m ||| Thread $tid released lock ||| \e[39m") if $lclass::CONFIG{debug_level};
        } else {
            $self->debug("\e[92m --- Thread $tid decremented lock (count: $self->{lock_owner}{$tid}) --- \e[39m") if $lclass::CONFIG{debug_level};
        }
    } elsif (scalar(keys %{$self->{lock_owner}}) == 0) {
        $self->debug("\e[93m ### Thread $tid already released lock ### \e[39m") if $lclass::CONFIG{debug_level};
        $self->{lock_owner}{$tid}=0;
        $self->{lock_semaphore}->up;
    } else {
        $self->debug("\e[93m *** Thread $tid attempted to unlock a lock it doesn't own:".join(', ',@{[keys %{$self->{lock_owner}}]})." *** \e[39m") if $lclass::CONFIG{debug_level};
        $self->throw("Thread $tid attempted to unlock a lock not owned by the current thread:".join(', ',@{[keys %{$self->{lock_owner}}]}), 'LOCK_ERROR');
    }
    $self->{lock_mutex}->up;
    $self->debug("\e[96m === unLock Thread $tid Mutex === \e[39m") if $lclass::CONFIG{debug_level};

}

sub sync {
    my ($self, $code, $operation_name, @args) = @_;
    $operation_name //= 'sync_operation';

    my $tid = threads->tid;
    my @result;
    my $error;
    my $isshared = $self->_shared;

    $self->lock if $isshared;

    $self->debug("[Locked]") if $lclass::CONFIG{debug_level};
    eval {
        $self->debug("[Before]") if $lclass::CONFIG{debug_level};
        $self->trigger('before_'.$operation_name, $code, \@args);
        $self->debug("[Call]") if $lclass::CONFIG{debug_level};
        @result = $code->(@args);
        $self->debug("[After]") if $lclass::CONFIG{debug_level};
        $self->trigger('after_'.$operation_name, $code, \@args, \@result);
        1;
    } or do {
        $error = $@;
    };

    $self->unlock if $isshared;
    $self->debug("[UnLocked]") if $lclass::CONFIG{debug_level};

    if ($error) {
        $self->trigger('error_'.$operation_name, $code, \@args, $error);
        $self->throw("Execution error in code $operation_name: $error", 'SYNC_ERROR');
    }

    $self->trigger($operation_name, $code, \@args, \@result);

    return wantarray ? @result : $result[0];
}

################################################################################
# Apply Function
################################################################################

sub apply {
    my ($self, $func) = @_;
    $self->sync(sub {
        my $ref = $self->_ref;
        my $is = $self->{is};
        if ($is eq 'scalar')        { $$ref = $func->($$ref) }
        elsif ($is eq 'array')      { @$ref = map { $func->($_) } @$ref }
        elsif ($is eq 'hash')       { %$ref = map { $_ => $func->($ref->{$_}) } keys %$ref }
            # For code references, we can't modify the code itself,
            # but we can wrap it with the applied function
        elsif ($is eq 'code')       { $ref = sub { $func->($ref->(@_)) } }
            # For glob references, we pass the entire glob to the function
        elsif ($is eq 'glob')       { $ref = $func->($ref) }
        elsif ($is eq 'ref')        { $ref = $func->($ref) }
        else { $self->throw("Unsupported reference type: $is", 'TYPE_ERROR') }
    }, 'apply', $func);
    return $self;
}

################################################################################
# Stringification
################################################################################

# Convert *class object to string representation
sub to_string {
    my $self = shift;
    
    return $self->sync(sub {
        $self->trigger('stringify');
        my $is = $self->{is};
        my $ref = $self->_ref;
        $self->throw("Cannot stringify $is undefined reference", 'STRING_ERROR') unless defined $ref;
        
        if ($is eq 'scalar') { return defined $$ref ? $$ref : '' }
        elsif ($is eq 'array') { return '[' . join(', ', @$ref) . ']' }
        elsif ($is eq 'hash') { return '{' . join(', ', map { "$_ => " . ($ref->{$_} // 'undef') } sort keys %$ref) . '}' }
        elsif ($is eq 'code') { return 'sub '.B::Deparse->new("-p", "-sC")->coderef2text($ref) }
        elsif ($is eq 'io') { return defined $self->{io} ? "IO handle (type: $self->{io_type}, fileno: " . $self->fileno . ")" : "Closed IO handle" }
        elsif ($is eq 'glob') {
            if ($self->{thread}) {
                # Special handling for tclass
                return sprintf("Thread(%s::%s, Status: %s, TID: %s, Detached: %s)\nThread-GLOB: %s.\n",
                    $self->{space},
                    $self->{name},
                    $self->{status},
                    $self->get_tid // 'N/A',
                    ($self->{detached} ? 'Yes' : 'No'),
                    $self->{glob}->to_string
                );
            } else {
                my $namespace = $self->{space} . ($self->{name} ? "::".$self->{name}:"");
                return  "GLOB $namespace\n".
                        ($self->{scalar} ? "  SCALAR: ".$self->SCALAR->get."\n" : "").
                        ($self->{array} ? "  ARRAY: ".$self->ARRAY->to_string."\n" : "").
                        ($self->{hash} ? "  HASH: " . $self->HASH->to_string."\n" : "").
                        ($self->{code} ? "  CODE: " . $self->CODE->to_string."\n" : "").
                        ($self->{io} ? "  IO: " . $self->IO->to_string."\n" : "");
            }
        }
        elsif ($is eq 'ref') {
            # For rclass, we'll use the type of the referenced object
            my $reftype = $self->{type} // 'undef';
            return "$ref";
        }
        else {
            return "$is(undef)";
        }
    });
}

################################################################################
# Enhanced Serialization
################################################################################

sub serialize {
    my ($self, $format) = @_;
    
    $format //= $lclass::CONFIG{serialization_format};
    
    return $self->try(sub {
        my $is = $self->{is};
        my $data = $self->_ref;
        
        my $serialized_data = {
            is => $is,
            data => undef,
        };
        
        if ($is eq 'scalar') { $serialized_data->{data} = $$data }
        elsif ($is eq 'array') { $serialized_data->{data} = [@$data] }
        elsif ($is eq 'hash') { $serialized_data->{data} = {%$data} }
        elsif ($is eq 'code') { $serialized_data->{data} = B::Deparse->new("-p", "-sC")->coderef2text($data) }
        elsif ($is eq 'io') {
            # For IO, we'll store the filename or descriptor
            $serialized_data->{data} = { 
                io_type => $self->io_type, 
                name => $self->filename,
                fileno => $self->fileno,
                io => "$self->{io}"
            };
        }
        elsif ($is eq 'ref') { 
            $serialized_data->{data} = "$data";
            #    ref($data) eq 'SCALAR' ? $$data :
            #    ref($data) eq 'ARRAY' ? @$data :
            #    ref($data) eq 'HASH' ? %$data :
            #    ref($data) eq 'IO' ? xclass::Ic($data)->to_string :
            #    ref($data) eq 'CODE' ? xclass::Cc($data)->to_string :
            #    ref($data) eq 'GLOB' ? xclass::Gc($data)->to_string :
            #    $$data 
        }
        elsif ($is eq 'glob') {
            return $self->{glob}->serialize if ($self->{thread});
            $serialized_data->{data} = {
                space => $self->{space},
                name => $self->{name},
            };
            $serialized_data->{data}{scalar} = $self->SCALAR->get if defined $self->{scalar};
            $serialized_data->{data}{array} = $self->ARRAY->get if defined $self->{array};
            $serialized_data->{data}{hash} = $self->HASH->get if defined $self->{hash};
            if (defined $self->{code} && (my $code = $self->CODE->get)) {
                my $deparser = B::Deparse->new("-p", "-sC");
                $serialized_data->{data}{code} = $deparser->coderef2text($code);
            }
            if (defined $self->{io} && (my $io = $self->IO->get)) {
                if (my $filename = $io->filename) {
                    $serialized_data->{data}{io} = { type => 'file', name => $filename };
                } elsif (my $fileno = $io->fileno) {
                    $serialized_data->{data}{io} = { type => 'fileno', number => $fileno };
                }
            }
        }
        else {
            $self->throw("Unknown type for serialization: $is", 'SERIALIZE_ERROR');
        }
        
        if ($format eq 'json') {
            return JSON::XS->new->utf8->pretty->allow_nonref->allow_blessed->convert_blessed->encode($serialized_data);
        }
        elsif ($format eq 'storable') {
            return freeze($serialized_data);
        }
        elsif ($format eq 'yaml') {
            return YAML::XS::Dump($serialized_data);
        }
        elsif ($format eq 'msgpack') {
            return Data::MessagePack->new->utf8->allow_blessed->convert_blessed->pack($serialized_data);
        }
        else {
            $self->throw("Unsupported serialization format: $format", 'SERIALIZE_ERROR');
        }
    }, 'serialize', $format);
}

sub deserialize {
    my ($self, $serialized_data, $format) = @_;
    
    $self->throw("Cannot deserialize empty data", 'DESERIALIZE_ERROR') unless defined $serialized_data && length $serialized_data;
    $format //= $lclass::CONFIG{serialization_format};
    
    return $self->try(sub {
        my $deserialized_data;
        
        if ($format eq 'json') {
            $deserialized_data = JSON::XS->new->utf8->allow_nonref->allow_blessed->convert_blessed->decode($serialized_data);
        }
        elsif ($format eq 'storable') {
            $deserialized_data = thaw($serialized_data);
        }
        elsif ($format eq 'yaml') {
            $deserialized_data = YAML::XS::Load($serialized_data);
        }
        elsif ($format eq 'msgpack') {
            $deserialized_data = Data::MessagePack->new->utf8->allow_blessed->convert_blessed->unpack($serialized_data);
        }
        else {
            $self->throw("Unsupported deserialization format: $format", 'DESERIALIZE_ERROR');
        }
        
        my $is = $deserialized_data->{is};
        my $data = $deserialized_data->{data};
        
        $self->throw("Deserialized data type doesn't match object type", 'DESERIALIZE_ERROR')
            unless $is eq $self->{is};
        
        if ($is eq 'scalar') { $self->set(\$data) }
        elsif ($is eq 'array') { $self->set($data) }
        elsif ($is eq 'hash') { $self->set($data) }
        elsif ($is eq 'code') {
            my $coderef = eval "sub $data";
            $self->throw("Failed to evaluate code: $@", 'DESERIALIZE_ERROR') if $@;
            $self->set($coderef);
        }
        elsif ($is eq 'io') {
            print STDOUT $deserialized_data."\n";
            if (defined $data->{type} && $data->{type} eq 'PIPE') {
                $self->set(*{$data->{io}});
            }
            elsif(defined $data->{type} && $data->{type} eq 'FILE') {
                open my $fh, '<', $data->{name} or $self->throw("Cannot open file: $!", 'DESERIALIZE_ERROR');
                $self->set($fh);
            }
            elsif (defined $data->{fileno}) {
                open my $fh, '<&=', $data->{fileno} or $self->throw("Cannot open file descriptor: $!", 'DESERIALIZE_ERROR');
                $self->set($fh);
            }
            else {
                $self->throw("Unknown IO type for deserialization", 'DESERIALIZE_ERROR');
            }
        }
        elsif ($is eq 'ref') {
            $self->set($data);
        }
        elsif ($is eq 'glob') {
            $self->{space} = $data->{space};
            $self->{name} = $data->{name};
            $self->_initialize();
            $self->SCALAR($data->{scalar}) if $data->{scalar};
            $self->ARRAY($data->{array}) if $data->{array};
            $self->HASH($data->{hash}) if $data->{hash};
            if ($data->{code}) {
                my $coderef = eval "sub $data->{code}";
                $self->throw("Failed to evaluate code: $@", 'DESERIALIZE_ERROR') if $@;
                $self->CODE($coderef);
            }
            if ($data->{io}) {
                if ($data->{io}{type} eq 'file') {
                    open my $fh, '<', $data->{io}{name} or $self->throw("Cannot open file: $!", 'DESERIALIZE_ERROR');
                    $self->IO($fh);
                } elsif ($data->{io}{type} eq 'fileno') {
                    open my $fh, '<&=', $data->{io}{number} or $self->throw("Cannot open file descriptor: $!", 'DESERIALIZE_ERROR');
                    $self->IO($fh);
                }
            }
        }
        else {
            $self->throw("Unknown type for deserialization: $is", 'DESERIALIZE_ERROR');
        }
        
        return $self;
    }, 'deserialize', $serialized_data, $format);
}

################################################################################
# Memory Management
################################################################################

sub memory_usage {
    my ($self) = @_;
    $self->trigger('memory_usage');
    return total_size($self);
}

sub check_circular_refs {
    my ($self) = @_;
    $self->trigger('circular_ref_check');
    my @cycles;
    Devel::Cycle::find_cycle($self, sub { push @cycles, [@_] });
    return \@cycles;
}

################################################################################
# Versioning
################################################################################

sub version {
    return $VERSION;
}

sub check_compatibility {
    my ($required_version) = @_;
    return version->parse($VERSION) >= version->parse($required_version);
}

################################################################################
# Extensibility
################################################################################

sub register_plugin {
    my ($self, $name, $plugin) = @_;
    $self->trigger('plugin_registration', $name);
    $self->throw("Invalid plugin name", 'PLUGIN_ERROR') unless defined $name && length $name;

    $PLUGINS{$name} = $plugin;
}

sub use_plugin {
    my ($self, $name, @args) = @_;
    $self->trigger('plugin_usage', $name);
    $self->throw("Invalid plugin name", 'PLUGIN_ERROR') unless defined $name && length $name;
    $self->throw("Plugin $name not found", 'PLUGIN_ERROR') unless exists $PLUGINS{$name};
    return $PLUGINS{$name}->new($self, @args);
}

################################################################################
# Configuration
################################################################################

sub configure {
    my (%options) = @_;
    @CONFIG{keys %options} = values %options;
}

################################################################################
# Additional Utility Methods
################################################################################

sub is_defined {
    my ($self) = @_;
    $self->trigger('definition_check');
    return defined $self->_ref;
}

sub is_empty {
    my ($self) = @_;
    my $is = $self->{is};
    $self->trigger('emptiness_check');
    if ($is eq 'scalar') { return !defined ${$self->_ref} || ${$self->_ref} eq ''; }
    elsif ($is eq 'array')  { return @{$self->_ref} == 0; }
    elsif ($is eq 'hash')   { return scalar (keys %{$self->_ref}) == 0; }
    elsif ($is eq 'code')   { return ref($self->_ref) eq 'CODE' ? 0 : 1; }  # Code references are never considered empty
    elsif ($is eq 'io')     { 
        return ref($self->_ref) eq 'GLOB'
            && defined *{$self->_ref} 
            && defined *{$self->_ref}{IO} ? 0 : 1; 
    }  # IO handles are never considered empty
    elsif ($is eq 'ref')    { return !defined $self->_ref || !defined ${$self->_ref}; }
    elsif ($is eq 'glob')   { return ref($self->_ref) eq 'GLOB' ? 0 : 1; }  # Globs are never considered empty
    else { $self->throw("Unknown type: $self->{is}", 'TYPE_ERROR'); }
}

sub clone {
    my ($self,$clone) = @_;
    $self->throw("Cannot clone undefined reference", 'CLONE_ERROR') unless defined $self->_ref;
    return $self->sync(sub {
        return xclass::Cc($self->{code}) if ($self->{is} eq 'code');
        if ($self->{is} eq 'glob') {
            return $self->{glob}->clone if $self->{thread};
            my $clone_name = defined $clone ? $clone : "$self->{name}_clone";
            my $clone_obj = gclass->new(
                space => $self->{space},
                name => $clone_name,
            );
            $clone_obj->SCALAR($self->SCALAR->get) if defined $self->{scalar};
            $clone_obj->ARRAY($self->ARRAY->get) if defined $self->{array};
            $clone_obj->HASH($self->HASH->get) if defined $self->{hash};
            $clone_obj->CODE($self->CODE->get) if defined $self->{code};
            $clone_obj->IO($self->IO->get) if defined $self->{io};
            return $self->is_shared ? $clone_obj->share_it : $clone_obj;
        }
        elsif ($self->{is} eq 'ref') {
            my $type = ref($self->{ref});
            #print STDOUT "Clone $type\n";
            return ref($self)->new(dclone(\@{$self->{ref}})) if $type eq 'ARRAY';
            return ref($self)->new(dclone(\%{$self->{ref}})) if $type eq 'HASH';
            return ref($self)->new(dclone(\&{$self->{ref}})) if $type eq 'CODE';
#            return ref($self)->new(\*{$self->{ref}}) if $type eq 'GLOB';
            return ref($self)->new(dclone(\${$self->{ref}}));
        }
        return ref($self)->new(dclone($self->_ref));
    }, 'clone', $clone);
}

################################################################################
# Event Handling utils
################################################################################

# User Callbacks
sub on {
    my ($self, $event, $callback) = @_;
    $self->throw("Callback must be a code reference") unless ref $callback eq 'CODE';
    $self->sync(sub {
        $self->{event_callbacks}{$event} = [] unless exists $self->{event_callbacks}{$event};
        push @{$self->{event_callbacks}{$event}}, $callback;
    }, 'on');
    
    return $self;
}

# Class Triggers
sub trigger {
    my ($self, $event, @args) = @_;
    for my $callback (@{$self->{event_callbacks}{$event} || []}) {
        $callback->($self, @args);
    }
    return $self;
}

################################################################################
# Compare
################################################################################
sub compare {
    my ($self, $other, $swap) = @_;
    
    my $is = $self->{is};
    my $ref = $self->_ref;

    if ($is eq 'scalar') {
        return $swap ? ${$other->_ref} cmp ${$ref} : ${$ref} cmp ${$other->_ref};
    }
    elsif ($is eq 'array' && ref($other->_ref) eq 'ARRAY') {
        my $result = @{$ref} <=> @{$other->_ref};
        return $result if $result != 0;
        for my $i (0 .. $#{$ref}) {
            $result = $ref->[$i] cmp $other->_ref->[$i];
            return $result if $result != 0;
        }
        return 0;
    }
    elsif ($is eq 'hash') {
        my $result = keys(%{$ref}) <=> keys(%{$other->_ref});
        return $result if $result != 0;
        for my $key (sort keys %{$ref}) {
            return 1 unless exists $other->_ref->{$key};
            $result = $ref->{$key} cmp $other->_ref->{$key};
            return $result if $result != 0;
        }
        return 0;
    }
    elsif ($is eq 'code') {
        return $swap ? "$other" cmp $self->to_string : $self->to_string cmp "$other";
    }
    elsif ($is eq 'io') {
        return $swap ? $other->fileno <=> $self->fileno : $self->fileno <=> $other->fileno;
    }
    elsif ($is eq 'glob') {
        return $swap ? "$other" cmp $self->to_string : $self->to_string cmp "$other";
    }
    elsif ($is eq 'ref') {
        #print STDOUT "REF(".ref($ref)."); OTHER(".ref($other).")\n";
        if (ref($ref) eq ref($other)) {
            return $swap ? xclass::Sc(\${$other})->compare(xclass::Sc(\${$ref})) : xclass::Sc(\${$ref})->compare(xclass::Sc(\${$other})) if (ref($ref) eq 'SCALAR');
            return $swap ? xclass::Ac(\@{$other})->compare(xclass::Ac(\@{$ref})) : xclass::Ac(\@{$ref})->compare(xclass::Ac(\@{$other})) if (ref($ref) eq 'ARRAY');
            return $swap ? xclass::Hc(\%{$other})->compare(xclass::Hc(\%{$ref})) : xclass::Hc(\%{$ref})->compare(xclass::Hc(\%{$other})) if (ref($ref) eq 'HASH');
            return $swap ? xclass::Cc(\&{$other})->compare(xclass::Cc(\&{$ref})) : xclass::Cc(\&{$ref})->compare(xclass::Cc(\&{$other})) if (ref($ref) eq 'CODE');
            return $swap ? xclass::Ic(\*{$other})->compare(xclass::Ic(\*{$ref})) : xclass::Ic(\*{$ref})->compare(xclass::Ic(\*{$other})) if (ref($ref) eq 'GLOB');
        }
        return $swap ? ref($other) cmp ref($ref) : ref($ref) cmp ref($other);
    }
    elsif ($is eq 'thread') {
        return $swap ? $other->tid <=> $self->tid : $self->tid <=> $other->tid;
    }
    else {
        return $swap ? $other->to_string cmp $self->to_string : $self->to_string cmp $other->to_string;
    }
}

sub equals {
    my ($self, $other, $swap) = @_;
    return $self->compare($other, $swap) == 0 ? 1 : 0;
}

################################################################################
# Exported DESTROY Destructor using DESTRUCT for local class cleanup
################################################################################

#sub DESTROY {
#    my ($self) = @_;
#
#    $self->trigger('DESTROY');
#
#    # Call the class-specific DESTRUCT function if it exists
#    $self->DESTRUCT() if $self->can('DESTRUCT');
#
#    # Perform general cleanup
#    # Clear any resources while considering if they are shared
#    foreach my $key (keys %$self) {
#        next if ref($self->{$key}) && ref($self->{$key}) =~ /^(SCALAR|ARRAY|HASH)$/;  # Skip clearing shared references
#        if (ref($self->{$key}) eq 'ARRAY')      { @{$self->{$key}} = () }
#        elsif (ref($self->{$key}) eq 'HASH')    { %{$self->{$key}} = () }
#        elsif (ref($self->{$key}) eq 'SCALAR')  { ${$self->{$key}} = "" }
#        undef $self->{$key}
#    }
#
#    # Clear cache
#    clear_cache($self);
#
#    $self->unlock() if $self->_shared;
#
#    # Log destruction if debug is enabled
#    $logger->debug("Destroying " . ref($self) . " object") if $lclass::CONFIG{debug_level} > 0;
#}



################################################################################
# Xclass

sub xc { my $self=shift; return xclass::Xc(@_) }
sub sc { my $self=shift; return xclass::Sc(@_) }
sub ac { my $self=shift; return xclass::Ac(@_) }
sub hc { my $self=shift; return xclass::Hc(@_) }
sub cc { my $self=shift; return xclass::Cc(@_) }
sub ic { my $self=shift; return xclass::Ic(@_) }
sub gc { my $self=shift; return xclass::Gc(@_) }
sub rc { my $self=shift; return xclass::Rc(@_) }
sub tc { my $self=shift; return xclass::Tc(@_) }

################################################################################
# Package Exports & Class Imports
################################################################################

use Exporter;

our @EXPORT_OK = qw(
    %CONFIG
    _ref _shared share_it _init
    is_defined is_empty
    to_string serialize deserialize clone
    on trigger
    lock unlock sync apply 
    memory_usage
    throw debug try compare equals
    xc sc ac hc cc ic gc rc tc
    check_circular_refs
    convert_to
    version
    check_compatibility 
    register_plugin use_plugin
    configure
);

my @lclass_exports = qw(
    %CONFIG
    _ref _shared share_it _init
    is_defined is_empty
    to_string serialize deserialize clone
    on trigger
    lock unlock sync apply
    memory_usage
    throw debug try compare equals
    xc sc ac hc cc ic gc rc tc
);

our %EXPORT_TAGS = (

    config => [qw(%CONFIG)],
    scalar => [@lclass_exports],    # Scalar-specific methods
    array => [@lclass_exports],     # Array-specific methods
    hash => [@lclass_exports],      # Hash-specific methods
    code => [@lclass_exports],      # Code-specific methods
    io => [@lclass_exports],        # IO-specific methods
    glob => [@lclass_exports],      # Glob-specific methods
    ref => [@lclass_exports],       # Reference-specific methods
    thread => [@lclass_exports],    # Thread-specific methods

    # Configuration and meta-information methods
    meta => [qw(
        version
        check_compatibility
        configure
    )],

    # Advanced features
    advanced => [qw(
        check_circular_refs
        register_plugin use_plugin
    )],

    # All exportable functions
    all => \@EXPORT_OK,
);

# Import method to export functions to the calling package
sub import {
    my ($class, @args) = @_;
    my $target = caller;
    no strict 'refs';
    
    my @methods_to_export;
    
    for my $arg (@args) {
        if ($arg =~ /^:(.+)/) {
            my $tag = $1;
            if (exists $EXPORT_TAGS{$tag}) {
                push @methods_to_export, @{$EXPORT_TAGS{$tag}};
            } else {
                die "Unknown tag :$tag in import";
            }
        } else {
            push @methods_to_export, $arg;
        }
    }
    
    # If no methods specified, export all
    @methods_to_export = @EXPORT_OK if !@methods_to_export;

    my %seen;
    for my $method (grep { !$seen{$_}++ } @methods_to_export) {
        if (grep { $_ eq $method } @EXPORT_OK) {
            *{"${target}::$method"} = \&$method;
        } else {
            die "Method $method is not exportable from lclass";
        }
    }
}

1;

################################################################################
# EOF lclass.pm (C) 2024 OnEhIppY, Domero Software <domerosoftware@gmail.com>