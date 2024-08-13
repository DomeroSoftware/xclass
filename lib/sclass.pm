################################################################################
# sclass.pm - Advanced Scalar Manipulation Class for xclass Ecosystem
#
# This class provides a robust and feature-rich interface for working with
# scalar values within the xclass ecosystem. It offers thread-safe operations,
# extensive utility methods, and seamless integration with other xclass components.
#
# Key Features:
# - Thread-safe scalar operations using lclass synchronization
# - Overloaded operators for intuitive scalar manipulation
# - Extensive set of utility methods for string and numeric operations
# - JSON serialization (storage) and deserialization (export)
# - Regular expression operations (match, substitute)
# - String manipulation (trim, pad, case conversion)
# - Numeric operations (increment, decrement, arithmetic)
# - Bitwise operations
# - Atomic operations (fetch_add, fetch_store, test_set)
# - Encryption and hashing methods (base64, MD5, SHA256, simple XOR cipher)
# - Cloning and comparison methods
#
# Integration with xclass Ecosystem:
# - Inherits core functionality from lclass
# - Can be instantiated directly or through xclass factory methods
# - Supports conversion to and from other xclass types (aclass, hclass, etc.)
# - Implements xclass event system for operation tracking
#
# Thread Safety:
# - All methods are designed to be thread-safe when used with shared scalars
# - Utilizes lclass synchronization mechanisms
#
# Performance Considerations:
# - Optimized for both single-threaded and multi-threaded environments
# - Lazy loading of heavy dependencies (e.g., cryptographic libraries)
#
# Extensibility:
# - Designed to be easily extended with additional methods
# - Supports custom event triggers for all operations
#
# Usage Examples:
# - Basic scalar operations: $scalar->set("value")->uc()->reverse()
# - Numeric operations: $scalar->set(5)->inc(3)->mul(2)
# - Advanced operations: $scalar->encrypt($key)->encode_base64()->md5()
#
# Author: OnEhIppY, Domero Software
# Copyright: (C) 2024 OnEhIppY, Domero Software
#
# Dependencies:
# - Perl v5.8.0 or higher
# - lclass (for core functionality and thread safety)
# - xclass (for ecosystem integration)
# - Scalar::Util (for type checking)
# - JSON::XS (for JSON storage)
# - MIME::Base64 (for base64 encoding/decoding, loaded on demand)
# - Digest::MD5 and Digest::SHA (for hashing, loaded on demand)
#
# Note: This class is designed to be a comprehensive solution for scalar
# manipulation within the xclass ecosystem. It balances feature richness
# with performance and thread safety considerations.
################################################################################

package sclass;

use strict;
use warnings;
use Scalar::Util qw(looks_like_number blessed);
use JSON::XS;
use MIME::Base64;
use Digest::MD5;
use Digest::SHA;

our $VERSION = '2.0.0';

BEGIN {
    xclass::register('SCALAR', 'sclass');
}

use lclass qw(:scalar);

# Overload operators for scalar-specific operations
use overload
    '""'    => \&_quote_op,
    '0+'    => \&_count_op,
    'bool'  => \&_bool_op,
    '!'     => \&_not_op,
    '='     => \&_assign_op,
    '=='    => \&_eq_op,
    '!='    => \&_ne_op,
    'cmp'   => \&_cmp_op,
    '<=>'   => \&_spaceship_op,
    '+'     => \&_add_op,
    '-'     => \&_sub_op,
    '*'     => \&_mul_op,
    '/'     => \&_div_op,
    '%'     => \&_mod_op,
    '**'    => \&_exp_op,
    '<<'    => \&_lshift_op,
    '>>'    => \&_rshift_op,
    '&'     => \&_and_op,
    '|'     => \&_or_op,
    '^'     => \&_xor_op,
    '~'     => \&_bitwise_not,
    'x'     => \&_repeat_op,
    '.='    => \&_concat_assign_op,
    '+='    => \&_inc_assign_op,
    '-='    => \&_dec_assign_op,
    '*='    => \&_mul_assign_op,
    '/='    => \&_div_assign_op,
    '%='    => \&_mod_assign_op,
    '**='   => \&_exp_assign_op,
    '++'    => \&_inc_op,
    '--'    => \&_dec_op,
    fallback => 1;

################################################################################

# Private methods for overloaded operators

sub _not_op { my ($s)=shift->get; return !$s }
sub _assign_op { my ($self, $other) = @_; $self->set($other); $self }
sub _bool_op { my ($s)=shift->get; return !!$s }
sub _count_op { my ($s)=shift->get; return 0 + $s }
sub _quote_op { my ($s)=shift->get; return $s }
sub _eq_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->get == $other;
    },'eq_op',$other,$swap);
}
sub _ne_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->get != $other;
    },'ne_op',$other,$swap);
}
sub _cmp_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $swap ? $other cmp $self->get : $self->get cmp $other;
    },'cmp_op',$other,$swap);
}
sub _spaceship_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $swap ? $other <=> $self->get : $self->get <=> $other;
    },'spaceship_op',$other,$swap);
}
sub _add_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($self->get + $other);
    },'add_op',$other,$swap);
}
sub _sub_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($swap ? $other - $self->get : $self->get - $other);
    },'sub_op',$other,$swap);
}

sub _mul_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($self->get * $other);
    },'mul_op',$other,$swap);
}

sub _div_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($swap ? $other / $self->get : $self->get / $other);
    },'div_op',$other,$swap);
}

sub _mod_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($swap ? $other % $self->get : $self->get % $other);
    },'mod_op',$other,$swap);
}

sub _exp_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($swap ? $other ** $self->get : $self->get ** $other);
    },'pow_op',$other,$swap);
}

sub _lshift_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($swap ? $other << $self->get : $self->get << $other);
    },'lshift_op',$other,$swap);
}

sub _rshift_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($swap ? $other >> $self->get : $self->get >> $other);
    },'rshift_op',$other,$swap);
}

sub _and_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($self->get & $other);
    },'and_op',$other,$swap);
}

sub _or_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($self->get | $other);
    },'or_op',$other,$swap);
}

sub _xor_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($self->get ^ $other);
    },'xor_op',$other,$swap);
}

sub _repeat_op {
    my ($self,$other,$swap)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($swap ? $other x $self->get : $self->get x $other);
    },'repeat_op',$other,$swap);
}

sub _bitwise_not { 
    my $self = shift; 
    my $result = $self->clone; 
    my $value = $self->get; 
    my $bitmask = (1 << $self->bit_length) - 1; # Perform bitwise NOT and ensure it is interpreted as a signed integer
    return $result->set((~$value & $bitmask) - ($bitmask + 1));
}

sub _concat_assign_op { my ($self, $other) = @_; $self->concat($other); $self }
sub _inc_assign_op { my ($self, $other) = @_; $self->inc($other); $self }
sub _dec_assign_op { my ($self, $other) = @_; $self->dec($other); $self }
sub _mul_assign_op { my ($self, $other) = @_; $self->mul($other); $self }
sub _div_assign_op { my ($self, $other) = @_; $self->div($other); $self }
sub _mod_assign_op { my ($self, $other) = @_; $self->set($self->get % $other); $self }
sub _exp_assign_op { my ($self, $other) = @_; $self->set($self->get ** $other); $self }
sub _inc_op { my $self = shift; $self->inc; $self }
sub _dec_op { my $self = shift; $self->dec; $self }

################################################################################

sub bit_length {
    my ($self) = @_;
    my $value = $self->get;
    $value = abs($value);
    return 0 if $value == 0;  # Special case for zero
    my $bit_length = int(log($value) / log(2)) + 1;
    return $bit_length;
}

################################################################################

# Constructor method
sub new {
    my ($class, $ref, %options) = @_;
    #print STDOUT "Create Scalar\n";
    my $self = bless {
        is => 'scalar',
        scalar => ref($ref) ? $ref : \$ref,
    }, $class;
    #print STDOUT "Init Scalar $ref\n";
    return $self->try(sub {
        $self->_init(%options);
        return $self;
    },'new', $class, $ref, \%options);
}

################################################################################

# Get the value of the scalar
sub get {
    my ($self)=@_;
    return $self->sync(sub {
        return ${$self->{scalar}};
    },'get');
}

    # Set the value of the scalar
sub set {
    my ($self,$ref)=@_;
    $self->sync(sub {
        $self->{scalar} = (ref($ref) ? $ref : \$ref) if defined $ref;
    },'set',$ref);
    return $self;
}

################################################################################

# Perform chomp operation on the scalar
sub chomp {
    my ($self)=@_;
    $self->sync(sub {
        chomp ${$self->{scalar}};
    },'chomp');
    return $self;
}

# Perform chop operation on the scalar
sub chop {
    my ($self)=@_;
    $self->sync(sub {
        chop ${$self->{scalar}};
    },'chop');
    return $self;
}

# Perform substr operation on the scalar
sub substr {
    my ($self,@args)=@_;
    my $val = $self->sync(sub {
        return &CORE::substr(${$self->{scalar}}, @args);
    },'substr',\@args);
    return $val;
}

# Reverse the scalar value
sub reverse {
    my ($self)=@_;
    $self->sync(sub {
        ${$self->{scalar}} =  reverse(${$self->{scalar}});
    },'reverse');
    return $self;
}

# Convert scalar to uppercase
sub uc {
    my ($self)=@_;
    $self->sync(sub {
        ${$self->{scalar}} = uc ${$self->{scalar}};
    },'uc');
    return $self;
}

# Convert scalar to lowercase
sub lc {
    my ($self)=@_;
    $self->sync(sub {
        ${$self->{scalar}} = lc ${$self->{scalar}};
    },'lc');
    return $self;
}

# Split the scalar value
sub split {
    my ($self,$delimiter)=@_;
    return $self->sync(sub {
        return split /$delimiter/, ${$self->{scalar}};
    },'split',$delimiter);
}

################################################################################

# Concatenate a string to the scalar
sub concat {
    my ($self,$string)=@_;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} .= $string;
        }else{
           ${$self->{scalar}} .= $string;
       }
    },'concat',$string);
    return $self;
}

# Increment the scalar value
sub inc {
    my ($self,$value)=@_; $value //= 1;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} += $value;
        }else{
            ${$self->{scalar}} += $value;
        }
    },'inc',$value);
    return $self;
}

# Decrement the scalar value
sub dec {
    my ($self,$value)=@_;$value //= 1;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} -= $value;
        }else{
            ${$self->{scalar}} -= $value;
        }
    },'dec',$value);
    return $self;
}

# Multiply the scalar value
sub mul {
    my ($self,$value)=@_;$value //= 1;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} *= $value;
        }else{
            ${$self->{scalar}} *= $value;
        }
    },'mul',$value);
    return $self;
}

# Divide the scalar value
sub div {
    my ($self,$value)=@_;
    $self->throw("Division by zero", 'DIVISION_BY_ZERO') if !$value;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} /= $value;
        }else{
            ${$self->{scalar}} /= $value;
        }
    },'div',$value);
    return $self;
}

# Absolute scalar value
sub abs {
    my ($self)=@_;
    return $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            return $self->clone->set(abs(${${$self->{scalar}}}));
        }else{
            return $self->clone->set(abs(${$self->{scalar}}));
        }
    },'abs');
}

# Modules
sub mod {
    my ($self,$other)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($self->get % $other);
    },'mod',$other);
}

# Power
sub exp {
    my ($self,$other)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        return $self->clone->set($self->get ** $other);
    },'pow',$other);
}

# Negate
sub neg {
    my ($self)=@_;
    return $self->sync(sub {
        return $self->clone->set(-$self->get);
    },'neg');
}

################################################################################

# Modify the scalar value using a code block
sub modify {
    my ($self,$code)=@_;
    $self->sync(sub {
        local $_ = ${$self->{scalar}};
        $code->();
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} = $_;
        }else{
            ${$self->{scalar}} = $_;
        }
    },'modify',$code);
    return $self;
}

# Get the type of the scalar
sub type {
    my ($self)=@_;
    return $self->sync(sub {
        return ref \${$self->{scalar}};
    },'type');
}

# Append a string to the scalar (alias for concat)
sub append {
    my ($self,$string)=@_;
    return $self->concat($string);
}

# Prepend a string to the scalar
sub prepend {
    my ($self,$string)=@_;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} = $string . ${${$self->{scalar}}};
        }else{
            ${$self->{scalar}} = $string . ${$self->{scalar}};
        }
    },'prepend');
    return $self;
}

# Check if the scalar value is numeric
sub is_numeric {
    my ($self)=@_;
    return $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            return looks_like_number(${${$self->{scalar}}});
        }else{
            return looks_like_number(${$self->{scalar}});
        }
    },'is_numeric');
}

# Convert the scalar value to a number
sub to_number {
    my ($self)=@_;
    return $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            return 0 + ${${$self->{scalar}}};
        }else{
            return 0 + ${$self->{scalar}};
        }
    },'to_number');
}

# Get the length of the scalar value
sub len() {
    my ($self)=@_;
    return $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            return length(${${$self->{scalar}}});
        }else{
            return length(${$self->{scalar}});
        }
    },'length');
}

################################################################################

# Additional utility methods

# Load an object into a JSON scalar
sub to_json {
    my ($self,$obj)=@_;
    $self->sync(sub {
        ${$self->{scalar}} = JSON::XS->new->utf8->convert_blessed->allow_nonref->encode($obj);
        $self->{is_json} = 1;
    },'to_json',$obj);
    return $self;
}

# Convert the JSON scalar to an object
sub from_json {
    my ($self)=@_;
    return $self->sync(sub {
        return $self->{is_json} ? JSON::XS->new->utf8->convert_blessed->allow_nonref->decode(${$self->{scalar}}) : ${$self->{scalar}};
    },'from_json');
}

# Perform a regular expression match on the scalar
sub match {
    my ($self,$regex)=@_;
    return $self->sync(sub {
        my @matches;
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            @matches = ${${$self->{scalar}}} =~ /$regex/;
        }else{
            @matches = ${$self->{scalar}} =~ /$regex/;
        }
        return @matches;
    },'match',$regex);
}

# Perform a regular expression substitution on the scalar
sub subs {
    my ($self,$regex, $replacement, $global)=@_; $global //=0;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            if ($global) {
                ${${$self->{scalar}}} =~ s/$regex/$replacement/g;
            } else {
                ${${$self->{scalar}}} =~ s/$regex/$replacement/;
            }
        }else{
            if ($global) {
                ${$self->{scalar}} =~ s/$regex/$replacement/g;
            } else {
                ${$self->{scalar}} =~ s/$regex/$replacement/;
            }
        }
    },'substitute', $regex, $replacement, $global);
    return $self;
}

# Trim whitespace from the beginning and end of the scalar
sub trim() {
    my ($self)=@_;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} =~ s/^\s+|\s+$//g;
        }else{
            ${$self->{scalar}} =~ s/^\s+|\s+$//g;
        }
    },'trim');
    return $self;
}

# Pad the scalar with a specified character
sub pad {
    my ($self,$length,$pad_char,$pad_left)=@_;
    $pad_char //= ' ';
    $pad_left //= 1;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            my $padding = $pad_char x ($length - CORE::length(${${$self->{scalar}}}));
            if ($pad_left) {
                ${${$self->{scalar}}} = $padding . ${${$self->{scalar}}};
            } else {
                ${${$self->{scalar}}} .= $padding;
            }
        }else{
            my $padding = $pad_char x ($length - CORE::length(${$self->{scalar}}));
            if ($pad_left) {
                ${$self->{scalar}} = $padding . ${$self->{scalar}};
            } else {
                ${$self->{scalar}} .= $padding;
            }
        }
    },'pad', $length, $pad_char, $pad_left);
    return $self;
}

# Merge with another sclass (in this case, just set the value)
sub merge {
    my ($self,$other,$swap)=@_;
    $self->sync(sub {
        $self->throw("Cannot merge with non-sclass object", 'TYPE_ERROR') unless blessed($other) && $other->isa(__PACKAGE__);
        ${$self->{scalar}} = $other->get;
    },'merge',$other);
    return $self;
}

# Clear the scalar value (set to undef)
sub clear {
    my ($self)=@_;
    $self->sync(sub {
        ${$self->{scalar}} = "";
    },'clear');
    return $self;
}

# Fetch and add atomically
sub fetch_add {
    my ($self,$value)=@_;
    return $self->sync(sub {
        my $old_value = ${$self->{scalar}};
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} += $value;
        }else{
            ${$self->{scalar}} += $value;
        }
        return $old_value;
    },'fetch_add',$value);
}

# Fetch and store atomically
sub fetch_store {
    my ($self,$value)=@_;
    return $self->sync(sub {
        my $old_value = ${$self->{scalar}};
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} = $value;
        }else{
            ${$self->{scalar}} = $value;
        }
        return $old_value;
    },'fetch_store',$value);
}

# Test and set atomically
sub test_set {
    my ($self,$value)=@_;
    return $self->sync(sub {
        if (!defined ${$self->{scalar}}) {
            if (ref(${$self->{scalar}}) eq 'SCALAR') {
                ${${$self->{scalar}}} = $value;
            }else{
                ${$self->{scalar}} = $value;
            }
            return 1;
        }
        return 0;
    },'test_set',$value);
}

# Check if the scalar contains a specific substring
sub contains {
    my ($self,$string)=@_;
    return $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            return index(${${$self->{scalar}}}, $string) != -1;
        }else{
            return index(${$self->{scalar}}, $string) != -1;
        }
    },'contains',$string);
}

# Replace all occurrences of a substring
sub replace_all {
    my ($self,$search,$replace)=@_;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} =~ s/\Q$search\E/$replace/g;
        }else{
            ${$self->{scalar}} =~ s/\Q$search\E/$replace/g;
        }
    },'replace_all',$search,$replace);
    return $self;
}

# Convert to boolean value
sub to_bool {
    my ($self)=@_;
    return $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            return !!${${$self->{scalar}}};
        }else{
            return !!${$self->{scalar}};
        }
    },'to_bool');
}

# Perform a case-insensitive comparison
sub eq_ignore_case {
    my ($self,$other)=@_;
    return $self->sync(sub {
        $other = $other->get if blessed($other) && $other->can('get');
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            return &CORE::lc(${${$self->{scalar}}}) eq &CORE::lc($other);
        }else{
            return &CORE::lc(${$self->{scalar}}) eq &CORE::lc($other);
        }
    },'eq_ignore_case',$other);
}

# Convert to title case
sub title_case {
    my ($self)=@_;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} =~ s/(\w+)/\u\L$1/g;
        }else{
            ${$self->{scalar}} =~ s/(\w+)/\u\L$1/g;
        }
    },'title_case');
    return $self;
}

# Count occurrences of a substring
sub count_occurrences {
    my ($self, $string) = @_;
    return $self->sync(sub {
        return 0 if $string eq '';
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            return scalar(() = ${${$self->{scalar}}} =~ /\Q$string\E/g);
        }else{
            return scalar(() = ${$self->{scalar}} =~ /\Q$string\E/g);
        }
    }, 'count_occurrences', $string);
}

# Truncate the scalar to a specified length
sub truncate {
    my ($self,$length,$ellipsis)=@_; $ellipsis //= '...';
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            if (&CORE::length(${${$self->{scalar}}}) > $length) {
                ${${$self->{scalar}}} = &CORE::substr(${${$self->{scalar}}}, 0, $length - &CORE::length($ellipsis)) . $ellipsis;
                $self->trigger('truncate');
            }
        }else{
            if (&CORE::length(${$self->{scalar}}) > $length) {
                ${$self->{scalar}} = &CORE::substr(${$self->{scalar}}, 0, $length - &CORE::length($ellipsis)) . $ellipsis;
                $self->trigger('truncate');
            }
        }
    },'truncate',$length, $ellipsis);
    return $self;
}

# Convert to camel case
sub to_camel_case {
    my ($self) = @_;
    $self->sync(sub {
        my $value;
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            $value = ${${$self->{scalar}}};
        }else{
            $value = ${$self->{scalar}};
        }
        $value =~ s/(?:^|_)(.)/\U$1/g; # Capitalize first letter after underscore or start
        $value =~ s/\s+//g;             # Remove spaces
        $value = lcfirst($value);      # Ensure first letter is lowercase
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} = $value;
        }else{
            ${$self->{scalar}} = $value;
        }
    }, 'to_camel_case');
    return $self;
}

# Convert to snake case
sub to_snake_case {
    my ($self) = @_;
    $self->sync(sub {
        my $value;
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            $value = ${${$self->{scalar}}}
        }else{
            $value = ${$self->{scalar}}
        }
        $value =~ s/([A-Z])/_\l$1/g;  # Insert underscores before capital letters
        $value =~ s/^_//;             # Remove leading underscore
        $value =~ s/\s+/_/g;          # Replace spaces with underscores
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} = $value
        }else{
            ${$self->{scalar}} = $value;
        }
    }, 'to_snake_case');
    return $self;
}

 # Validate the scalar against a regular expression
sub valid {
    my ($self,$regex)=@_;
    return $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            return ${${$self->{scalar}}} =~ /$regex/;
        }else{
            return ${$self->{scalar}} =~ /$regex/;
        }
    },'valid',$regex);
}

    # Encode the scalar to base64
sub enc_base64 {
    my ($self)=@_;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} = MIME::Base64::encode_base64(${${$self->{scalar}}});
        }else{
            ${$self->{scalar}} = MIME::Base64::encode_base64(${$self->{scalar}});
        }
        $self->trigger('encode_base64');
    },'encode_base64');
    return $self;
}

# Decode the scalar from base64
sub dec_base64 {
    my ($self)=@_;
    $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            ${${$self->{scalar}}} = MIME::Base64::decode_base64(${${$self->{scalar}}});
        }else{
            ${$self->{scalar}} = MIME::Base64::decode_base64(${$self->{scalar}});
        }
        $self->trigger('decode_base64');
    },'decode_base64');
    return $self;
}

# Encrypt the scalar using a simple XOR cipher (for demonstration purposes only)
sub encrypt {
    my ($self,$key)=@_;
    $self->sync(sub {
        $self->throw("Invalid key given for `encrypt`","INVALID_INPUT") if length($key) == 0;
        my $encrypted = '';
        my $key_length = &CORE::length($key);
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            for my $i (0..&CORE::length(${${$self->{scalar}}})-1) {
                $encrypted .= chr(ord(&CORE::substr(${${$self->{scalar}}}, $i, 1)) ^ ord(&CORE::substr($key, $i % $key_length, 1)));
            }
            ${${$self->{scalar}}} = $encrypted;
        }else{
            for my $i (0..&CORE::length(${$self->{scalar}})-1) {
                $encrypted .= chr(ord(&CORE::substr(${$self->{scalar}}, $i, 1)) ^ ord(&CORE::substr($key, $i % $key_length, 1)));
            }
            ${$self->{scalar}} = $encrypted;
        }
    },'encrypt',$key);
    return $self;
}

# Decrypt the scalar using a simple XOR cipher (for demonstration purposes only)
sub decrypt {
    my ($self,$key)=@_;
    return $self->encrypt($key);  # XOR encryption is symmetric
}

# Calculate MD5 hash of the scalar
sub md5 {
    my ($self)=@_;
    return $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            return Digest::MD5::md5_hex(${${$self->{scalar}}});
        }else{
            return Digest::MD5::md5_hex(${$self->{scalar}});
        }
    },'md5');
}

# Calculate SHA256 hash of the scalar
sub sha256 {
    my ($self)=@_;
    return $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            return Digest::SHA::sha256_hex(${${$self->{scalar}}});
        }else{
            return Digest::SHA::sha256_hex(${$self->{scalar}});
        }
    },'sha256');
}

    # Calculate SHA512 hash of the scalar
sub sha512 {
    my ($self)=@_;
    return $self->sync(sub {
        if (ref(${$self->{scalar}}) eq 'SCALAR') {
            return Digest::SHA::sha512_hex(${${$self->{scalar}}});
        }else{
            return Digest::SHA::sha512_hex(${$self->{scalar}});
        }
    },'sha512');
}

1;

################################################################################
# EOF sclass.pm (C) 2024 OnEhIppY, Domero Software
################################################################################
