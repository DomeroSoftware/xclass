################################################################################
# aclass.pm - Advanced Array Manipulation Class for xclass Ecosystem
#
# This class provides a robust and feature-rich interface for working with
# array references within the xclass ecosystem. It offers thread-safe operations,
# extensive utility methods, and seamless integration with other xclass components.
#
# Key Features:
# - Thread-safe array operations using lclass synchronization mechanisms
# - Consistent error handling using lclass throw and warn methods
# - Integration with xclass event system through trigger method
# - Overloaded operators for intuitive array manipulation
# - Extensive set of utility methods for array operations
# - Element-wise type handling using xclass
# - Support for functional programming paradigms (map, grep, reduce)
# - Advanced operations like slicing, atomic updates, and compare-and-swap
# - Serialization and deserialization capabilities
#
# Array Operations:
# - Basic: push, pop, shift, unshift, splice, join, clear
# - Functional: map, grep, reduce, foreach, first, last
# - Sorting and Ordering: sort, reverse, unique
# - Mathematical: sum, min, max
# - Slicing and Accessing: get, set, slice
# - Atomic: compare_and_swap, atomic_update
# - Iteration: iterator
#
# Integration with xclass Ecosystem:
# - Inherits core functionality from lclass
# - Can be instantiated directly or through xclass factory methods
# - Supports conversion to and from other xclass types
# - Implements xclass event system for operation tracking
#
# Thread Safety:
# All public methods in this class are designed to be thread-safe when used
# with shared arrays. The class utilizes lclass synchronization mechanisms
# to ensure safe concurrent access and modification of the underlying array.
#
# lclass Integration:
# This class heavily relies on lclass functionality for error handling,
# synchronization, and event triggering. It uses the following lclass methods:
# - sync: For thread-safe operations
# - throw: For standardized error handling
# - warn: For non-fatal warnings
# - trigger: For event system integration
# - try: For consistent error handling and operation wrapping
#
# Performance Considerations:
# - Optimized for both single-threaded and multi-threaded environments
# - Efficient handling of large arrays
#
# Extensibility:
# - Designed to be easily extended with additional methods
# - Supports custom event triggers for all operations
#
# Usage Examples:
#   my $array = aclass->new([1, 2, 3]);
#   $array->push(4, 5)->sort->reverse;
#   my $sum = $array->sum;
#   $array->map(sub { $_ * 2 })->grep(sub { $_ > 5 });
#
# Author: OnEhIppY, Domero Software
# Copyright: (C) 2024 OnEhIppY, Domero Software
#
# Dependencies:
# - Perl v5.8.0 or higher
# - lclass (for core functionality and thread safety)
# - xclass (for ecosystem integration and element-wise type handling)
# - Scalar::Util (for type checking)
# - List::Util (for array operations)
#
# Note: This class is designed to be a comprehensive solution for array
# manipulation within the xclass ecosystem. It balances feature richness
# with performance and thread safety considerations.
################################################################################

package aclass;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number blessed reftype);
use List::Util;

our $VERSION = '2.0.0';

BEGIN {
    xclass::register('ARRAY', 'aclass');
}

use lclass qw(:array);

################################################################################
# Error codes
use constant {
    ACLASS_INDEX_ERROR       => 'ACLASS_INDEX_ERROR',
    ACLASS_TYPE_ERROR        => 'ACLASS_TYPE_ERROR',
    ACLASS_EMPTY_ARRAY_ERROR => 'ACLASS_EMPTY_ARRAY_ERROR',
    ACLASS_INVALID_ARGUMENT  => 'ACLASS_INVALID_ARGUMENT',
    ACLASS_SLICE_ERROR       => 'ACLASS_SLICE_ERROR',
};

################################################################################
# Overload operators
use overload
    '@{}' => \&_array_deref_op,
    '""' => \&_stringify_op,
    '0+' => \&_count_op,
    'bool' => \&_bool_op,
    '!' => \&_neg_op,
    'x' => \&_repeat_op,
    '=' => \&_assign_op,
    '==' => \&_eq_op,
    '!=' => \&_ne_op,
    'cmp' => \&_cmp_op,
    '<=>' => \&_spaceship_op,
    '+=' => \&_add_op,
    '-=' => \&_sub_op,
    '*=' => \&_mul_op,
    '&=' => \&_bitwise_and_op,
    '|=' => \&_bitwise_or_op,
    '^=' => \&_bitwise_xor_op,
    '~' => \&_bitwise_not,
    '.=' => \&_concat_assign_op,
    '<<' => \&_lshift_op,
    '>>' => \&_rshift_op,
    fallback => 1;


################################################################################
# Overloaded operator methods
sub _array_deref_op { my $self = shift; $self->get }
sub _stringify_op { my $self = shift; $self->join(',') }
sub _count_op { my $self = shift; return 0 + $self->len }
sub _bool_op { my $self = shift; $self->len > 0 }
sub _neg_op { my $self = shift; $self->len == 0 }

sub _repeat_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        return $self->ac([(@{$self->get}) x $other])
    }, 'repeat_op');
}

sub _assign_op { 
    my ($self, $other) = @_; 
    $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
    $self->clear->push(@$other); 
    return $self
}

sub _eq_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        return $self->join(',') eq (ref($other) eq 'ARRAY' ? join(',', @$other) : $other);
    }, 'eq_op');
}

sub _ne_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        return $self->join(',') ne (ref($other) eq 'ARRAY' ? join(',', @$other) : $other);
    },'ne_op');
}

sub _cmp_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        return $swap ? 
            (ref($other) eq 'ARRAY' ? join(',', @$other) : $other) cmp $self->join(',') :
            $self->join(',') cmp (ref($other) eq 'ARRAY' ? join(',', @$other) : $other);
    },'cmp_op');
}

sub _spaceship_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        return $swap ? 
            (ref($other) eq 'ARRAY' ? scalar(@$other) : $other) <=> $self->len :
            $self->len <=> (ref($other) eq 'ARRAY' ? scalar(@$other) : $other);
    },'spaceship_op');
}

sub _add_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        $self->push(@$other) if ref($other) eq 'ARRAY';
        return $self;
    },'add_op');
}

sub _sub_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        if (ref($other) eq 'ARRAY') {
            my %remove = CORE::map { defined($_) ? ($_ => 1) : () } @$other;
            $self->grep(sub { defined ($_[0]) && !$remove{$_[0]} });
        }
        return $self;
    },'sub_op');
}

sub _mul_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        if (looks_like_number($other)) {
            $self->set($_, $self->get($_) * $other) for (0..$#{$self});
        }
        return $self;
    },'mul_op');
}

sub _bitwise_and_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        if (ref($other) eq 'ARRAY') {
            my %keep = CORE::map { $_ => 1 } @$other;
            $self->grep(sub { $keep{$_[0]} });
        }
        return $self
    },'_bitwise_and_op');
}

sub _bitwise_or_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        $self->push(@$other)->unique if ref($other) eq 'ARRAY';
        return $self
    },'_bitwise_or_op');
}

sub _bitwise_xor_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
        if (ref($other) eq 'ARRAY') {
            my %count;
            $count{$_}++ for (@$self, @$other);
            $self->grep(sub { $count{$_[0]} == 1 });
        }
        return $self
    }, '_bitwise_xor_op');
}

sub _bitwise_not { shift->clone->reverse }

sub _concat_assign_op { 
    my ($self, $other) = @_; 
    $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
    $self->push(@$other); 
    $self 
}
sub _lshift_op {
    my ($self, $other) = @_;
    $other = $other->get if blessed($other) && $other->isa(__PACKAGE__);
    return $self->push($other)
}
sub _rshift_op { 
    my $self = shift; 
    return $self->pop 
}

################################################################################
# Constructor
sub new {
    my ($class, $ref, %options) = @_;
    my $self = bless {
        is => 'array',
        array => $ref,
    }, $class;

    $self->try(sub {
        $self->_init(%options);
    }, 'new', $class, $ref, \%options);

    return $self;
}

################################################################################
# Private methods
sub _validate_coderef {
    my ($self, $coderef) = @_;
    $self->throw("Invalid code reference", ACLASS_INVALID_ARGUMENT) unless ref($coderef) eq 'CODE';
    return ref($coderef) eq 'CODE'
}

sub _check_empty {
    my ($self) = @_;
    $self->throw("Cannot perform operation on an empty array", ACLASS_EMPTY_ARRAY_ERROR) if @{$self->{array}} == 0;
}

################################################################################
# Public methods
sub get {
    my ($self, $index) = @_;
    return $self->sync(sub {
        $self->throw("Can't get undefined index $index", ACLASS_INDEX_ERROR) if defined $index && !defined $self->{array}[$index];
        return $self->{array}[$index] if defined $index;
        return $self->{array};
    },'get');
}

sub set {
    my ($self, $index, $value) = @_;
    return $self->sync(sub {
        if (ref($index) eq 'ARRAY' && !defined $value) {
            $self->{array} = $index;
        }
        elsif (defined $value) {
            $self->throw("Index must be an integer", ACLASS_TYPE_ERROR) 
                unless !ref($index) && looks_like_number($index) && $index == int($index);
            $self->{array}[$index] = $value;
        } else {
            $self->throw("Invalid array or index and value input", ACLASS_TYPE_ERROR);
        }
        return $self;
    },'set');
}

sub push {
    my ($self, @values) = @_;
    return $self->sync(sub {
        CORE::push @{$self->{array}}, @values;
        return $self;
    },'push');
}

sub pop {
    my ($self) = @_;
    return $self->sync(sub {
        $self->throw("Cannot pop from an empty array", ACLASS_EMPTY_ARRAY_ERROR) if @{$self->{array}} == 0;
        my $index = $#{$self->{array}};
        my $value = CORE::pop @{$self->{array}};
        return $value;
    },'pop');
}

sub shift {
    my ($self) = @_;
    return $self->sync(sub {
        $self->throw("Cannot shift from an empty array", ACLASS_EMPTY_ARRAY_ERROR) if @{$self->{array}} == 0;
        return CORE::shift @{$self->{array}};
    },'shift');
}

sub unshift {
    my ($self, @values) = @_;
    return $self->sync(sub {
        CORE::unshift @{$self->{array}}, @values;
        return $self;
    },'unshift');
}

sub len {
    my ($self) = @_;
    return $self->sync(sub { 
        return scalar @{$self->{array}}
    },'len');
}

sub sort {
    my ($self, $body) = @_;
    return $self->sync(sub {
        @{$self->{array}} = defined $body ? CORE::sort { $body->($a,$b) } @{$self->{array}} : CORE::sort @{$self->{array}};
        return $self;
    },'sort');
}

sub reverse {
    my ($self) = @_;
    return $self->sync(sub {
        @{$self->{array}} = CORE::reverse @{$self->{array}};
        return $self;
    },'reverse');
}

sub splice {
    my ($self, $offset, $length, @list) = @_;
    return $self->sync(sub {
        $self->throw("Invalid offset", ACLASS_INDEX_ERROR) if $offset < 0 or $offset+$length > scalar @{$self->{array}};
        return CORE::splice @{$self->{array}}, $offset, $length, @list;
    },'splice');
}

sub join {
    my ($self, $delimiter) = @_;
    return $self->sync(sub { 
        return CORE::join($delimiter,@{$self->{array}})
    },'join');
}

sub clear {
    my ($self) = @_;
    return $self->sync(sub {
        @{$self->{array}} = ();
        return $self;
    },'clear');
}

sub map {
    my ($self, $coderef) = @_;
    return $self->sync(sub {
        return if !$self->_validate_coderef($coderef);
        @{$self->{array}} = CORE::map { $coderef->($self->{array}[$_]) } 0..$#{$self->{array}};
        return $self;
    },'map');
}

sub grep {
    my ($self, $coderef) = @_;
    return $self->sync(sub {
        return if !$self->_validate_coderef($coderef);
        my @grepped;
        for my $index (0..$#{$self->{array}}) {
            CORE::push @grepped, $self->{array}[$index] if ($coderef->($self->{array}[$index]));
        }
        @{$self->{array}} = @grepped;
        return $self;
    },'grep');
}

sub reduce {
    my ($self, $coderef) = @_;
    return $self->sync(sub {
        return if !$self->_validate_coderef($coderef);
        $self->throw("Cannot reduce an empty array", ACLASS_EMPTY_ARRAY_ERROR) if @{$self->{array}} == 0;
        return List::Util::reduce { $coderef->($a,$b) } @{$self->{array}};
    },'reduce');
}

sub slice {
    my ($self, $start, $end) = @_;
    return $self->sync(sub {
        $self->throw("Invalid slice range", ACLASS_SLICE_ERROR) if $start < 0 or $end >= @{$self->{array}} or $start > $end;
        return $self->xc([CORE::map { $self->{array}[$_] } $start..$end]);
    },'slice');
}

sub each {
    my ($self, $coderef) = @_;
    return $self->sync(sub {
        $self->_validate_coderef($coderef);
        for my $index (0..$#{$self->{array}}) {
            $coderef->($self->{array}->[$index]);
        }
        return $self;
    }, 'each');
}

sub first {
    my ($self, $coderef) = @_;
    return $self->sync(sub {
        $self->_validate_coderef($coderef);
        for my $index (0..$#{$self->{array}}) {
            return $self->{array}->[$index] if $coderef->($self->{array}->[$index]);
        }
        return undef;
    },'first');
}

sub last {
    my ($self, $coderef) = @_;
    return $self->sync(sub {
        $self->_validate_coderef($coderef);
        my $last;
        for my $index (CORE::reverse 0..$#{$self->{array}}) {
            if ($coderef->($self->{array}->[$index])) {
                $last = $self->{array}->[$index];
                last;
            }
        }
        return $last;
    },'last');
}

sub sum {
    my ($self) = @_;
    return $self->sync(sub {
        $self->_check_empty;
        return List::Util::sum CORE::map { $self->{array}->[$_] } 0..$#{$self->{array}};
    },'sum');
}

sub min {
    my ($self) = @_;
    return $self->sync(sub {
        $self->_check_empty;
        return List::Util::min CORE::map { $self->{array}->[$_] } 0..$#{$self->{array}};
    },'min');
}

sub max {
    my ($self) = @_;
    return $self->sync(sub {
        $self->_check_empty;
        return List::Util::max CORE::map { $self->{array}->[$_] } 0..$#{$self->{array}};
    },'max');
}

sub unique {
    my ($self) = @_;
    return $self->sync(sub {
        my @unique = List::Util::uniq CORE::map { $self->{array}->[$_] } 0..$#{$self->{array}};
        @{$self->{array}} = @unique;
        return $self;
    },'unique');
}

sub compare_and_swap {
    my ($self, $index, $old_value, $new_value) = @_;
    return $self->sync(sub {
        $self->throw("Index out of bounds", ACLASS_INDEX_ERROR) if $index < 0 or $index >= @{$self->{array}};
        if ($self->{array}->[$index] eq $old_value) {
            $self->{array}->[$index] = $new_value;
            return 1;
        }
        return 0;
    },'compare_and_swap');
}

sub atomic_update {
    my ($self, $index, $coderef) = @_;
    return $self->sync(sub {
        $self->throw("Index out of bounds", ACLASS_INDEX_ERROR) if $index < 0 or $index >= @{$self->{array}};
        $self->_validate_coderef($coderef);
        $self->{array}->[$index] = $coderef->($self->{array}->[$index]);
        return $self;
    },'atomic_update');
}

sub iterator {
    my ($self) = @_;
    return $self->sync(sub {
        my $index = 0;
        my $array = $self->{array};
        return sub {
            return undef if $index >= @$array;
            return $array->[$index++]
        };
    },'iterator');
}

1;

################################################################################
# EOF aclass.pm (C) 2024 OnEhIppY, Domero Software
################################################################################
