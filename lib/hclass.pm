################################################################################
# hclass.pm - Advanced Thread-Safe Hash Manipulation Class for xclass Ecosystem
#
# This class provides a robust and feature-rich interface for working with
# hash references within the xclass ecosystem. It offers thread-safe operations,
# advanced hash manipulations, and seamless integration with nested data structures.
#
# Key Features:
# - Thread-safe hash operations using xclass synchronization
# - Overloaded operators for intuitive hash manipulation
# - Advanced utility methods for complex hash operations
# - Seamless handling of nested data structures
# - Built-in serialization and deserialization capabilities
# - Integration with xclass for type-specific handling of hash elements
#
# Hash Operations:
# - Basic: get, set, delete, exists, keys, values, clear
# - Advanced: each, map, grep, merge, invert, slice, modify
# - Utility: size, is_empty, serialize, deserialize
#
# Overloaded Operators:
# - Dereference (%{}), stringification (""), numeric context (0+)
# - Boolean context, negation (!), assignment (=)
# - Equality (==, !=), comparison (cmp, <=>)
# - Addition (+), subtraction (-), intersection (&), union (|), symmetric difference (^)
#
# Integration with xclass Ecosystem:
# - Inherits core functionality from xclass
# - Implements xclass event system for operation tracking
# - Utilizes xclass for type-specific handling of hash elements
#
# Thread Safety:
# - All methods are designed to be thread-safe
# - Utilizes xclass synchronization mechanisms
#
# Performance Considerations:
# - Optimized for both single-threaded and multi-threaded environments
# - Efficient handling of nested data structures
#
# Extensibility:
# - Designed to be easily extended with additional methods
# - Supports custom event triggers for all operations
#
# Usage Examples:
# - Basic: $hash->set('key', 'value')->get('key')
# - Advanced: $hash->map(sub { ... })->grep(sub { ... })->merge($other_hash)
# - Operators: $hash1 + $hash2, $hash1 & $hash2, $hash1 ^ $hash2
#
# Author: OnEhIppY, Domero Software
# Copyright: (C) 2024 OnEhIppY, Domero Software
#
# Dependencies:
# - Perl v5.8.0 or higher
# - xclass (core functionality and nested data type handling)
#
# Note: This class is designed to be a comprehensive solution for hash
# manipulation within the xclass ecosystem. It balances feature richness
# with performance and thread safety considerations. Special care is taken
# to handle nested data structures and provide intuitive operator overloading.
################################################################################

package hclass;

use strict;
use warnings;
use Scalar::Util qw(blessed);

our $VERSION = '2.0.0';

BEGIN {
    xclass::register('HASH', 'hclass');
}

use lclass qw(:hash);

################################################################################
# Overload operators for hash-specific operations
use overload
    '""'  => \&_stringify_op,
    '0+'  => \&_numeric_op,
    'bool' => \&_bool_op,
    '!'   => \&_not_op,
    '=='  => \&_eq_op,
    '!='  => \&_ne_op,
    'cmp' => \&_cmp_op,
    '<=>' => \&_spaceship_op,
    '+='   => \&_add_assign_op,
    '-='   => \&_sub_assign_op,
    '&='   => \&_and_assign_op,
    '|='   => \&_or_assign_op,
    '^='   => \&_xor_assign_op,
#    '='   => \&_assign_op,
    fallback => 1;

################################################################################
# Private methods for overloaded operators

sub _stringify_op { $_[0]->to_string }
sub _numeric_op { $_[0]->size }
sub _bool_op { !$_[0]->is_empty }
sub _not_op { $_[0]->is_empty }

sub _assign_op { 
    my ($self, $other) = @_;
    $self->clear->merge($other);
    return $self;
}

sub _eq_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        return 0 unless ref($other) eq ref($self);
        return $self->to_string eq $other->to_string;
    },'eq_op');
}

sub _ne_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        return 1 unless ref($other) eq ref($self);
        return $self->to_string ne $other->to_string;
    },'ne_op');
}

sub _cmp_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->to_string if ref($other) eq ref($self);
        $swap ? $other cmp $self->to_string : $self->to_string cmp $other;
    },'cmp_op');
}

sub _spaceship_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->size if ref($other) eq ref($self);
        $swap ? $other <=> $self->size : $self->size <=> $other;
    },'spaceship_op');
}

sub _add_assign_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        $self->merge($other) if ref($other) eq 'HASH';
        return $self;
    },'add_op');
}

sub _sub_assign_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        if (ref($other) eq 'HASH') {
            $self->grep(sub { my ($k, $v) = @_; !CORE::exists $other->{$k} });
        }
        return $self;
    },'sub_op');
}

sub _and_assign_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        if (ref($other) eq 'HASH') {
            $self->grep(sub { my ($k, $v) = @_; CORE::exists $other->{$k} });
        }
        return $self;
    },'and_op');
}

sub _or_assign_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        $self->merge($other) if ref($other) eq 'HASH';
        return $self;
    },'or_op');
}

sub _xor_assign_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        if (ref($other) eq 'HASH') {
            $self->grep(sub { my ($k, $v) = @_; !CORE::exists $other->{$k} });
            $self->merge({ 
                CORE::map { $_ => $other->{$_} } CORE::grep { !CORE::exists $self->{hash}{$_} } CORE::keys %$other
            });
        }
        return $self;
    },'xor_op');
}

################################################################################
# Constructor method
sub new {
    my ($class, $ref, %options) = @_;

    #print STDOUT "New HASH $ref\n";
    my $self = bless {
        is => 'hash',
        hash => $ref // {},
    }, $class;
    
    $self->try(sub {
        $self->_init(%options);
    }, 'new', $class, $ref, \%options);
    
    #print STDOUT $self->to_string."\n";
    return $self;
}

################################################################################
# Get value(s) from the hash
sub get {
    my ($self, $key) = @_;
    return $self->sync(sub {
        #$self->debug("Key not defined $key") if defined $key && !defined $self->{hash}{$key};
        return defined $key ? $self->{hash}{$key} : $self->{hash};
    },'get',$key);
}

# Get default value if key doesn't exist
sub get_default {
    my ($self, $key, $default) = @_;
    return $self->sync(sub {
        return CORE::exists $self->{hash}{$key} ? $self->get($key) : $default;
    }, 'get_default');
}

# Set value in the hash
sub set {
    my ($self, $key, $value) = @_;
    return $self->sync(sub {
        if (ref($key) eq 'HASH') {
            %{$self->{hash}} = %{$key};
        } else {
            $self->{hash}{$key} = $value;
        }
        return $self;
    },'set',$key,$value);
}

# Delete key from the hash
sub delete {
    my ($self, $key) = @_;
    return $self->sync(sub {
        CORE::delete $self->{hash}{$key};
        return $self;
    },'delete', $key);
}

# Check if key exists in the hash
sub exists {
    my ($self, $key) = @_;
    return $self->sync(sub {
        return CORE::exists $self->{hash}{$key};
    },'exists');
}

################################################################################
# Get all keys from the hash
sub keys {
    my ($self) = @_;
    return $self->sync(sub {
        return CORE::keys %{$self->{hash}};
    },'keys');
}

# Get all values from the hash
sub values {
    my ($self) = @_;
    return $self->sync(sub {
        return CORE::values %{$self->{hash}};
    },'values');
}

# Clear the hash
sub clear {
    my ($self) = @_;
    return $self->sync(sub {
        %{$self->{hash}} = ();
        return $self;
    },'clear');
}

################################################################################
# Iterate over hash key-value pairs
sub each {
    my ($self, $coderef) = @_;
    return $self->sync(sub {
        while (my ($key, $value) = CORE::each %{$self->{hash}}) {
            $coderef->($key, $value);
        }
        return $self;
    },'each');
}

# Map operation on hash key-value pairs
sub map {
    my ($self, $coderef) = @_;
    return $self->sync(sub {
        my %result;
        while (my ($key, $value) = CORE::each %{$self->{hash}}) {
            my ($new_key, $new_value) = $coderef->($key, $value);
            $result{$new_key} = $new_value;
        }
        %{$self->{hash}} = %result;
        return $self;
    },'map',$coderef);
}

# Grep operation on hash key-value pairs
sub grep {
    my ($self, $coderef) = @_;
    return $self->sync(sub {
        my %result;
        my %new_handlers;
        while (my ($key, $value) = CORE::each %{$self->{hash}}) {
            $result{$key} = $value if ($coderef->($key, $value));
        }
        %{$self->{hash}} = %result;
        return $self;
    },'grep',$coderef);
}

################################################################################
# Merge another hash into this one
sub merge {
    my ($self, $other) = @_;
    return $self->sync(sub {
        $other = $other->get if ref($other) eq ref($self);
        while (my ($key, $value) = CORE::each %$other) {
            $self->{hash}{$key}=$value;
        }
        return $self;
    },'merge',$other);
}

# Get the size of the hash
sub size {
    my ($self) = @_;
    return $self->sync(sub {
        return scalar (CORE::keys(%{$self->{hash}}));
    },'size');
}

# Invert the hash (swap keys and values)
sub invert {
    my ($self) = @_;
    return $self->sync(sub {
        my %inverted;
        my %new_handlers;
        while (my ($key, $value) = CORE::each %{$self->{hash}}) {
            $inverted{$value} = $key;
        }
        %{$self->{hash}} = %inverted;
        return $self;
    },'invert');
}

################################################################################
# Get a slice of the hash
sub slice {
    my ($self, @keys) = @_;
    return $self->sync(sub {
        return CORE::map { $_ => $self->{hash}->{$_} } CORE::grep { CORE::exists $self->{hash}{$_} } @keys;
    },'slice');
}

# Modify the hash using a code reference
sub modify {
    my ($self, $coderef) = @_;
    return $self->sync(sub {
        $coderef->($self->{hash});
        return $self;
    },'modify',$coderef);
}

################################################################################
# Additional utility methods

# Flatten a nested hash structure
sub flatten {
    my ($self, $prefix) = @_;
    $prefix //= '';
    return $self->sync(sub {
        my %flattened;
        while (my ($key, $value) = CORE::each %{$self->{hash}}) {
            my $new_key = $prefix ? "${prefix}_$key" : $key;
            if (ref($value) eq 'HASH' or (blessed($value) && $value->isa(__PACKAGE__))) {
                my $sub_hash = ref($value) eq 'HASH' ? __PACKAGE__->new($value) : $value;
                %flattened = (%flattened, %{$sub_hash->flatten($new_key)});
            } else {
                $flattened{$new_key} = $value;
            }
        }
        return \%flattened;
    }, 'flatten');
}

# Unflatten a flattened hash structure
sub unflatten {
    my ($self) = @_;
    return $self->sync(sub {
        my %unflattened;
        while (my ($key, $value) = CORE::each %{$self->{hash}}) {
            my @parts = split /_/, $key;
            my $ref = \%unflattened;
            for my $i (0 .. $#parts - 1) {
                $ref->{$parts[$i]} //= {};
                $ref = $ref->{$parts[$i]};
            }
            $ref->{$parts[-1]} = $value;
        }
        return __PACKAGE__->new(\%unflattened);
    }, 'unflatten');
}

# Perform a deep comparison with another hash
sub deep_compare {
    my ($self, $other) = @_;
    return $self->sync(sub {
        return 0 unless ref($other) eq ref($self);
        my $self_flat = $self->flatten;
        my $other_flat = $other->flatten;
        return 0 unless CORE::keys %$self_flat == CORE::keys %$other_flat;
        for my $key (CORE::keys %$self_flat) {
            return 0 unless CORE::exists $other_flat->{$key};
            return 0 unless $self_flat->{$key} eq $other_flat->{$key};
        }
        return 1;
    }, 'deep_compare');
}

# Apply a function recursively to all values in the hash
sub deep_map {
    my ($self, $func) = @_;
    return $self->sync(sub {
        my %result;
        while (my ($key, $value) = CORE::each %{$self->{hash}}) {
            if (ref($value) eq 'HASH' or (blessed($value) && $value->isa(__PACKAGE__))) {
                $result{$key} = (ref($value) eq 'HASH' ? __PACKAGE__->new($value) : $value)->deep_map($func);
            } else {
                $result{$key} = $func->($value);
            }
        }
        return __PACKAGE__->new(\%result);
    }, 'deep_map');
}

# Get all key-value pairs as an array of arrays
sub pairs {
    my ($self) = @_;
    return $self->sync(sub {
        return CORE::map { [$_, $self->{hash}{$_}] } CORE::keys %{$self->{hash}};
    }, 'pairs');
}

# Update multiple keys at once
sub update {
    my ($self, $updates) = @_;
    return $self->sync(sub {
        while (my ($key, $value) = CORE::each %$updates) {
            $self->set($key, $value);
        }
        return $self;
    }, 'update');
}

# Remove multiple keys at once
sub remove {
    my ($self, @keys) = @_;
    return $self->sync(sub {
        for my $key (@keys) {
            $self->delete($key);
        }
        return $self;
    }, 'remove');
}

# Check if the hash has all specified keys
sub has_keys {
    my ($self, @keys) = @_;
    return $self->sync(sub {
        for my $key (@keys) {
            return 0 unless CORE::exists $self->{hash}->{$key};
        }
        return 1;
    }, 'has_keys');
}

1;

################################################################################
# EOF hclass.pm (C) 2024 OnEhIppY, Domero Software
################################################################################
