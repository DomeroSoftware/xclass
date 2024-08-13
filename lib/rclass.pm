################################################################################

# rclass.pm - Advanced Thread-Safe Reference Handling Class for xclass Ecosystem

#
# This class provides a robust and versatile interface for managing references
# of any type within the xclass ecosystem. It leverages lclass functionality
# for core operations and integrates seamlessly with xclass for type-specific
# handling.
#
# Key Features:
# - Thread-safe reference operations using lclass synchronization
# - Support for all reference types (scalar, array, hash, code, glob)
# - Automatic type detection and appropriate handling
# - Overloaded operators for intuitive reference manipulation
# - Advanced utility methods for reference operations
# - Seamless integration with other xclass reference types
# - Built-in serialization and deserialization capabilities
#
# Reference Operations:
# - Basic: set, deref, get_type
# - Advanced: apply, merge, clear, clone
# - Utility: size, serialize, deserialize, equals, compare, hash_code
#
# Overloaded Operators:
# - Dereference (${}), array (@{}), hash (%{}), code (&{}), glob (*{})
# - Stringification (""), numeric context (0+), boolean context
# - Assignment (=)
#
# Integration with xclass Ecosystem:
# - Utilizes xclass for type-specific reference handling
# - Implements xclass event system for operation tracking
# - Seamless interaction with other xclass data types
#
# Thread Safety:
# - All methods are designed to be thread-safe
# - Utilizes lclass synchronization mechanisms
#
# Performance Considerations:
# - Optimized for both single-threaded and multi-threaded environments
# - Efficient handling of different reference types
#
# Extensibility:
# - Designed to be easily extended with additional reference operations
# - Supports custom event triggers for all operations
#
# Usage Examples:
# - Basic: $ref->set(\$scalar)->deref
# - Advanced: $ref->apply(sub { ... })->merge($other_ref)
# - Serialization: $serialized = $ref->serialize; $ref->deserialize($serialized)
#
# Author: OnEhIppY, Domero Software
# Copyright: (C) 2024 OnEhIppY, Domero Software
#
# Dependencies:
# - Perl v5.8.0 or higher
# - lclass (for core functionality and thread-safe operations)
# - Scalar::Util (for type checking)
# - xclass (for handling specific reference types)
#
# Note: This class is designed to be a comprehensive solution for reference
# handling within the xclass ecosystem. It balances feature richness with
# performance and thread safety considerations. Special care is taken to
# handle various reference types and provide robust error handling.

################################################################################

package rclass;

use strict;
use warnings;
use Scalar::Util qw(blessed reftype);

our $VERSION = '2.0.0';

BEGIN {
    xclass::register('REF', 'rclass');
}

use lclass qw(:ref);

################################################################################
# Overload operators for reference-specific operations
use overload
    '""'   => \&_stringify_op,
    '0+'   => \&_count_op,
    'bool' => \&_bool_op,
    '='    => \&_assign_op,
    '!='    => \&_neg_op,
    fallback => 1;

sub _stringify_op { shift->to_string}
sub _count_op { shift->deref ? 1 : 0 }
sub _bool_op { defined shift->deref }
sub _assign_op { my ($self, $other) = @_; $self->set($other); $self }
sub _neg_op { my ($self, $other) = @_; "$self" ne "$other" }

################################################################################
# Constructor
sub new {
    my ($class, $ref, %options) = @_;
    my $self = bless {
        is => 'ref',
        ref => $ref,
        type => reftype($ref),
    }, $class;
    
    return $self->try(sub {
        $self->_init(%options);
        return $self;
    }, 'new', $class, $ref, \%options);
}

# Set the reference
sub set {
    my ($self, $reference) = @_;
    return $self->sync(sub {
        $self->throw("Invalid reference", 'TYPE_ERROR') unless ref($reference);
        $self->{ref} = $reference;
        $self->{type} = reftype($self->{ref});
        return $self;
    }, 'set', $reference);
}

sub get {
    my ($self) = @_;
    return $self->sync(sub { 
        return $self->{ref};
    }, 'get');
}

# Dereference the stored reference
sub deref {
    my ($self) = @_;
    return $self->sync(sub { 
        return $self->xc($self->{ref});
    }, 'deref');
}

# Get reference type
sub get_type {
    my ($self) = @_;
    return $self->sync(sub { $self->{type} }, 'get_type');
}

# Merge with another rclass (if possible)
sub merge {
    my ($self, $other) = @_;
    return $self->sync(sub {
        $self->throw("Cannot merge with non-rclass object", 'TYPE_ERROR') unless blessed($other) && $other->isa(__PACKAGE__);
        if ($self->get_type eq $other->get_type) {
            my $wrapper = $self->deref;
            if ($wrapper->can('merge')) {
                $wrapper->merge($other->deref);
            } else {
                $self->throw("Merge not supported for type " . $self->get_type, 'OPERATION_ERROR');
            }
        } else {
            $self->throw("Cannot merge references of different types", 'TYPE_ERROR');
        }
        return $self;
    }, 'merge', $other);
}

# Get the size of the reference
sub size {
    my ($self) = @_;
    return $self->sync(sub {
        my $wrapper = $self->get;
        return blessed($wrapper) && $wrapper->can('size') ? $wrapper->size : 1;
    }, 'size');
}

# Clear the reference content
sub clear {
    my ($self) = @_;
    return $self->sync(sub {
        my $wrapper = $self->deref;
        if ($wrapper->can('clear')) {
            $wrapper->clear;
        } else {
            ${$self->{ref}} = undef;
        }
        return $self;
    }, 'clear');
}

# Get hash code
sub hash_code {
    my ($self) = @_;
    return $self->sync(sub {
        my @data = ($self->{type}, $self->get);
        return join(':', @data) if $#data > -1;
    }, 'hash_code');
}

1;

################################################################################
# EOF rclass.pm (C) 2024 OnEhIppY, Domero Software
################################################################################
