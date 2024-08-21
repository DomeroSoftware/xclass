#!/usr/bin/env perl

################################################################################
# xclass.pm - Core Management and Factory Class for the xclass Ecosystem
#
# The xclass module serves as the central hub, manager, and factory for the
# entire xclass ecosystem. It provides a unified interface for creating,
# managing, and interacting with various specialized classes that handle
# different data types in Perl.
#
# xclass Ecosystem Overview:
# - xclass (Core Package): Directive: Serve as the top-level user interface for the xclass ecosystem, providing access to all other classes and managing type registration and integration.
# - lclass (Locking, Synchronization, and Utility): Directive: Provide foundational methods for debugging, locking, and other general utilities. Serve as an automatic import for all other *class modules, ensuring consistent base functionality across the ecosystem.
# - sclass (Scalar Reference Manipulation): Directive: Implement comprehensive, thread-safe operations for scalar reference manipulation, offering extensive utility methods specific to scalar data.
# - aclass (Array Reference Manipulation): Directive: Provide thread-safe, feature-rich operations for array reference manipulation, supporting complex data structures and efficient array handling.
# - hclass (Hash Reference Manipulation): Directive: Offer robust, thread-safe methods for hash reference operations, providing advanced key-value pair management within the xclass framework.
# - cclass (Code Reference Manipulation): Directive: Manage and manipulate code references in a thread-safe manner, offering utilities for dynamic code execution and modification.
# - iclass (IO Reference Manipulation): Directive: Handle input/output operations in a thread-safe way, encapsulating both file system (fclass) and network (nclass) operations for comprehensive IO management.
# - rclass (General Reference Manipulation): Directive: Provide a unified interface for manipulating general references, ensuring type-specific handling and thread-safety for reference operations not covered by other specialized classes.
# - gclass (GLOB Reference Manipulation): Directive: Implement thread-safe operations for GLOB references, offering type-specific access methods and integration with other xclass components.
# - tclass (Thread Control): Directive: Offer comprehensive, thread-safe management for individual threads, utilizing gclass for named thread references and integrating with xclass locking mechanisms.
#
# Key Features and Responsibilities of xclass:
# 1. Class Registration and Management:
#    - Maintains a registry of all specialized classes in the ecosystem
#    - Provides methods to register, query, and retrieve class information
#
# 2. Instance Creation and Factory Methods:
#    - Offers a unified create() method for instantiating any specialized class
#    - Provides shorthand methods (Sc, Ac, Hc, etc.) for quick instance creation
#    - Implements the Xc() method for automatic type detection and conversion
#
# 3. Lazy Loading and Performance Optimization:
#    - Supports lazy loading of specialized classes to improve startup time
#    - Implements an optional instance caching mechanism for performance
#
# 4. Configuration Management:
#    - Centralizes configuration options for the entire ecosystem
#    - Allows runtime configuration changes through the configure() method
#
# 5. Debugging and Logging:
#    - Provides centralized debugging utilities for the ecosystem
#    - Offers configurable debug levels and category-based logging
#
# 6. Thread Safety:
#    - Implements thread-safe operations using semaphores
#    - Ensures proper synchronization for shared resources
#
# 7. Error Handling:
#    - Provides a unified error handling mechanism for the ecosystem
#
# 8. Extensibility:
#    - Allows easy integration of new specialized classes into the ecosystem
#    - Supports dynamic loading and registration of classes
#
# 9. Interoperability:
#    - Facilitates seamless conversion between different data types
#    - Ensures consistent interface across all specialized classes
#
# Usage:
# - Import xclass to gain access to the entire ecosystem:
#   use xclass;
# - Create instances of specialized classes:
#   my $scalar = Sc("Hello, World!");
#   my $array = Ac([1, 2, 3]);
# - Use automatic type conversion:
#   my $converted = Xc($some_data);
# - Configure the ecosystem:
#   xclass::configure(lazy_loading => 0, cache_instances => 1);
#
# Integration with lclass:
# - xclass utilizes lclass for core functionality shared across all classes
# - Ensures consistent thread-safety, error handling, and utility methods
#
# Version: 2.0.0
# Author: OnEhIppY, Domero Software
# Copyright: (C) 2024 OnEhIppY, Domero Software
#
# Dependencies:
# - Perl v5.8.0 or higher
#
# Note: This module is the cornerstone of the xclass ecosystem, providing
# a unified and extensible framework for advanced data type handling in Perl.
# It combines ease of use with powerful features, making it suitable for
# both simple scripts and complex, multi-threaded applications.
################################################################################

package xclass;

use strict;
use warnings;
use threads;
use threads::shared;
use Thread::Semaphore;

################################################################################

our $VERSION = '2.0.0';  # Ecosystem version

sub version {
    return $VERSION;
}

################################################################################
# Configuration
################################################################################

our %CONFIG = (
    lazy_loading => 1,
    cache_instances => 0,
);

sub configure {
    my (%options) = @_;
    @CONFIG{keys %options} = values %options;
}

################################################################################
# Debugging utilities
################################################################################

our $DEBUG_LEVEL = 0;

sub set_debug_level {
    my ($level) = @_;
    $DEBUG_LEVEL = $level;
}

sub debug_log {
    my ($message, $level, $category) = @_;
    $level //= 1;
    $category //= 'GENERAL';
    print STDERR "DEBUG [$category]: $message\n" if $DEBUG_LEVEL >= $level;
}

################################################################################
# Class registration and management
################################################################################

our $SEMAPHORE = Thread::Semaphore->new();
our %XCLASS_REGISTRY;

sub register {
    my ($type, $class) = @_;
    $SEMAPHORE->down();
    eval {
        $XCLASS_REGISTRY{$type} = {
            class => $class, 
        };
        debug_log("Registered $type: $class (v$VERSION)", 2, 'REGISTRY');
    };
    $SEMAPHORE->up();
    die "RegistrationError: $@" if $@;
}

sub registered {
    my ($type) = @_;
    return exists $XCLASS_REGISTRY{$type};
}

sub class {
    my ($type) = @_;
    my $info = $XCLASS_REGISTRY{$type} or die "UnknownTypeError: $type";
    return $info->{class};
}

sub loaded {
    my ($class) = @_;
    no strict 'refs';
    return ${"${class}::VERSION"} || ${"${class}::ISA"} || ${"${class}::"}{new};
}

################################################################################
# Instance creation and caching
################################################################################

my $lockOwner :shared = undef;
my $lockCount :shared = 0;

sub create {
    my ($type, @args) = @_;
    #print STDOUT "Create $type\n";
    $SEMAPHORE->down() unless defined $lockOwner && $lockOwner eq threads->tid;
    $lockOwner = threads->tid;
    $lockCount ++;
    #print STDOUT "Locked $type\n";
    my $object = eval {
        my $info = $XCLASS_REGISTRY{$type} or die "UnknownTypeError: $type";
        my $class = $info->{class};
        my $instance = $class->new(@args);
        $lockCount--;
        $SEMAPHORE->up() if $lockCount == 0;
        $lockOwner = undef if $lockCount == 0;
        return $instance;
    };
    if ($@) {
        $lockCount--;
        $SEMAPHORE->up() if $lockCount == 0;
        $lockOwner = undef if $lockCount == 0;
        die "InstanceCreationError: $@";
    }

    return $object
}

################################################################################
# Type conversion and utility functions
################################################################################

sub Xc {
    my ($element, @args) = @_;
    
    return $element if ref($element) =~ /^(sclass|aclass|hclass|cclass|iclass|gclass|rclass|tclass)$/;
    
    my $elements = ref($element) ? $element : \$element;
    
    my $TYPE = ref($elements);
    
    if ($TYPE eq 'GLOB') {
        $TYPE = 'IO' if defined(*{$elements}{IO});
    }
    
    if (registered($TYPE)) {
        my $class = eval { return create($TYPE, $elements, @args) };
        die "ConversionError: Failed to create $TYPE object: $@" if $@;
        return $class;
    } else {
        return $elements;
    }
}

################################################################################
# Class loading
################################################################################

require sclass;
require aclass;
require hclass;
require cclass;
require iclass;
require gclass;
require rclass;
require tclass;

################################################################################
# Shorthand methods for creating instances
sub Sc { return create('SCALAR', @_) }
sub Ac { return create('ARRAY', @_) }
sub Hc { return create('HASH', @_) }
sub Cc { return create('CODE', @_) }
sub Ic { return create('IO', @_) }
sub Gc { return create('GLOB', @_) }
sub Rc { return create('REF', @_) }
sub Tc { return create('THREAD', @_) }

################################################################################
# xclass Ecosystem Exports
use Exporter 'import';
our @EXPORT = qw(Sc Ac Hc Cc Ic Gc Rc Tc Xc);

1;

################################################################################
# EOF xclass.pm (C) 2024 OnEhIppY, Domero Software
################################################################################
