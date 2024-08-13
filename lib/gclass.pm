################################################################################

# gclass.pm - Advanced GLOB Reference Manipulation Class for xclass Ecosystem

#
# This class provides a robust and feature-rich interface for working with
# GLOB references within the xclass ecosystem. It offers thread-safe operations
# on global variables, including scalars, arrays, hashes, code references, and
# IO handles, with seamless integration into the xclass framework.
#
# Key Features:
# - Thread-safe GLOB reference operations using lclass synchronization
# - Overloaded operators for intuitive GLOB manipulation
# - Comprehensive handling of all GLOB components (SCALAR, ARRAY, HASH, CODE, IO)
# - Support for shared GLOBs across threads
# - Integration with xclass for type-specific handling of GLOB components
# - Serialization and deserialization capabilities (excluding CODE and IO)
# - Advanced operations: cloning, merging, comparison
#
# GLOB Operations:
# - Basic: set, get, exists
# - Component-specific: SCALAR, ARRAY, HASH, CODE, IO (get/set operations)
# - Advanced: clone, merge
# - Utility: to_string, serialize, deserialize
# - Comparison: equals, compare
#
# Integration with xclass Ecosystem:
# - Inherits core functionality from lclass
# - Implements xclass event system for operation tracking
# - Utilizes xclass for type-specific handling of GLOB components
#
# Thread Safety:
# - All methods are designed to be thread-safe
# - Support for shared GLOBs across threads
#
# Performance Considerations:
# - Optimized for both single-threaded and multi-threaded environments
# - Efficient handling of GLOB components
#
# Extensibility:
# - Designed to be easily extended with additional methods
# - Supports custom event triggers for all operations
#
# Usage Examples:
# - Basic: $glob->SCALAR(42)->ARRAY([1,2,3])->HASH({a => 1, b => 2})
# - Advanced: $glob->clone()->merge($other_glob)
# - Comparison: $glob1->equals($glob2)
#
# Author: OnEhIppY, Domero Software
# Copyright: (C) 2024 OnEhIppY, Domero Software
#
# Dependencies:
# - Perl v5.8.0 or higher
# - lclass (for utility methods and thread-safe operations)
# - threads::shared (for thread-safe shared variables)
# - Scalar::Util (for type checking)
# - xclass (for handling specific types and ecosystem integration)
#
# Note: This class is designed to be a comprehensive solution for GLOB reference
# manipulation within the xclass ecosystem. It balances feature richness
# with performance and thread safety considerations. Special care should be
# taken when working with CODE and IO components, as they have limitations
# in terms of serialization and cross-thread operations.

################################################################################

package gclass;

use strict;
use warnings;

use threads::shared;
use Scalar::Util qw(blessed reftype);

our $VERSION = '2.0.0';

BEGIN {
    xclass::register('GLOB', 'gclass');
}

use lclass qw(:glob);

################################################################################
# Overload operators for GLOB-specific operations
use overload
    '""'   => \&_stringify_op,
    '0+'   => \&_count_op,
    'bool' => \&_bool_op,
    '='    => \&_assign_op,
    fallback => 1;

################################################################################
sub _stringify_op { my $self = shift; $self->to_string }
sub _count_op { my $self = shift; $self->{scalar} ? $self->SCALAR->get : 0 }
sub _bool_op { my ($self) = @_; $self->exists }
sub _assign_op { my ($self, $other) = @_; $self->set($other); $self }

################################################################################
# Glob Class Constructor
sub new {
    my ($class, $space, $name, %options) = @_;
    my $self = bless {
        is => 'glob',
        space => $space // 'main',
        name => $name,
    }, $class;
    return $self->try(sub {
        $self->_initialize(%options);
        $self->_init(%options);
        return $self;
    }, 'new', $space, $name, \%options);
}

sub namespace {
    my ($self)=@_;
    return "$self->{space}".($self->{name} ? "::$self->{name}":"");
}

sub glob {
    my ($self)=@_;
    return *{$self->namespace};
}

# Initialize the GLOB
sub _initialize {
    my ($self,%options) = @_;
    $self->sync(sub {
        if ($self->namespace) {
            no strict 'refs';
            $self->{glob} = \*{$self->namespace};
            $self->{glob} = &share($self->{glob}) if $self->is_shared;
            for my $type ('CODE','IO','SCALAR','ARRAY','HASH') {
                #print STDOUT "Creating $type\n";
                $self->$type($options{$type}) if (defined $options{$type});
            }
        }
    }, 'initialize');
}

# Link Namespace to the GLOB Class
sub link_it {
    my ($self)=@_;
    return $self->sync(sub {
        $self->SCALAR(\$self);
        return $self
    },'link_it');
}
#
#    use gclass;
#
# Create and configure the gclass object
#    gclass->new(
#        'Space', 'Name',
#        ARRAY => [],
#        HASH => {count=>0},
#        CODE => sub {
#            $Space::Name->ARRAY->push($Space::Name->HASH->get('count'));
#            $Space::Name->HASH->set('count',$Space::Name->HASH->get('count')+1);
#        })
#        ->link_it    # Links the GLOB to the namespace
#        ->share_it;  # Shares the GLOB and its contents across threads
#
#    # Example thread operations
#    my @threads = map {
#        threads->create(sub {
#            # Example method call on the shared GLOB
#            $Space::Name->CODE->();  # Glob Code Calls
#        })
#    } 0..5;
#
#    # Wait for all threads to complete
#    $_->join for @threads;
#
################################################################################
# Set the GLOB
sub set {
    my ($self, $glob_ref) = @_;
    return $self->sync(sub {
        $self->throw("Invalid GLOB reference", 'TYPE_ERROR') unless ref($glob_ref) eq 'GLOB';
        $self->{glob} = $self->is_shared ? &share($glob_ref) : $glob_ref;
        $self->{scalar} = xclass::Sc(\*{$self->{glob}}{SCALAR}) if defined *{$self->{glob}}{SCALAR};
        $self->{array} = xclass::Ac(\*{$self->{glob}}{ARRAY}) if defined *{$self->{glob}}{ARRAY};
        $self->{hash} = xclass::Hc(\*{$self->{glob}}{HASH}) if defined *{$self->{glob}}{HASH};
        $self->{code} = xclass::Cc(\*{$self->{glob}}{CODE}) if defined *{$self->{glob}}{CODE};
        $self->{io} = xclass::Ic(\*{$self->{glob}}{IO}) if defined *{$self->{glob}}{IO};
        return $self;
    }, 'set', $glob_ref);
}

# Get the GLOB
sub get {
    my ($self,$type) = @_;
    return $self->sync(sub { 
        return $self->{$type}->get if defined $type;
        return $self->{glob}
    }, 'get', $type);
}

# Check if the GLOB exists
sub exists {
    my ($self,$type) = @_;
    return $self->sync(sub { 
        return defined $self->{$type} if defined $type;
        return defined $self->{glob}
    }, 'exists', $type);
}

################################################################################
# Get/Set SCALAR
sub SCALAR {
    my ($self, $value) = @_;
    return $self->sync(sub {
        if (defined $value) {
            $self->throw("Can not set None Scalar context","NO_SCALAR_CONTEXT") unless !ref($value) || ref($value) eq 'SCALAR' || ref($value) eq 'REF';
            no strict 'refs';
            #print STDOUT "Defined $value\n";
            ${*{$self->{glob}}} = $value;
            #print STDOUT "Defined Glob Scalar\n";
            $self->{scalar} = xclass::Sc(\${*{$self->{glob}}}) if (!defined $self->{scalar});
            #print STDOUT "Created Scalar Class\n";
            $self->{scalar}{is_shared} = 0;
            $self->{scalar}->share_it if $self->is_shared;
        }
        $self->throw("Scalar context does not exist in this GLOB","NO_GLOB_SCALAR") if !defined $self->{scalar};
        #print STDOUT "Return sclass\n";
        return $self->{scalar};
    }, 'SCALAR', $value);
}

# Get/Set ARRAY
sub ARRAY {
    my ($self, $value) = @_;
    return $self->sync(sub {
        if (defined $value) {
            $self->throw("Can not set None Array context with `".ref($value)."`","NO_ARRAY_CONTEXT") unless ref($value) eq 'ARRAY';
            no strict 'refs';
            #print STDOUT "REF(".ref($value)."):[".join(',', @$value)."]\n";
            @{*{$self->{glob}}} = @$value;
            $self->{array} = xclass::Ac(\@{*{$self->{glob}}}) if (!defined $self->{array});
            $self->{array}{is_shared} = 0;
            $self->{array}->share_it if $self->is_shared;
        }
        $self->throw("Array context does not exist in this GLOB","NO_GLOB_ARRAY") if !defined $self->{array};
        return $self->{array};
    }, 'ARRAY', $value);
}

# Get/Set HASH
sub HASH {
    my ($self, $value) = @_;
    return $self->sync(sub {
        if (defined $value) {
            $self->throw("Can not set None Hash context","NO_HASH_CONTEXT") unless ref($value) eq 'HASH';
            no strict 'refs';
            #print STDOUT "REF(".ref($value)."):[".join(',', %$value)."]\n";
            %{*{$self->{glob}}} = %$value if defined $value;
            $self->{hash} = xclass::Hc(\%{*{$self->{glob}}}) if (!defined $self->{hash});
            $self->{hash}{is_shared} = 0;
            $self->{hash}->share_it if $self->is_shared;
            #print STDOUT "Class(".ref($self->{hash}).")\n";
        }
        $self->throw("Hash context does not exist in this GLOB","NO_GLOB_HASH") if !defined $self->{hash};
        return $self->{hash};
    }, 'HASH', $value);
}

# Get/Set CODE
sub CODE {
    my ($self, $value) = @_;
    return $self->sync(sub {
        if (defined $value) {
            $self->throw("Can not set None Code context","NO_CODE_CONTEXT") unless ref($value) eq 'CODE';
            no strict 'refs';
            *{$self->{glob}} = $value if defined $value;
            $self->{code} = xclass::Cc(\&{*{$self->{glob}}}) if (!defined $self->{code});
            $self->{code}{is_shared} = 0;
            $self->{code}->share_it if $self->is_shared;
        }
        $self->throw("Code context does not exist in this GLOB","NO_GLOB_CODE") if !defined $self->{code};
        return $self->{code};
    }, 'CODE', $value);
}

# Get/Set IO
sub IO {
    my ($self, $value) = @_;
    return $self->sync(sub {
        if (defined $value) {
            my $io_type = ref($value) || 'UNKNOWN';
            $self->throw("Unknown IO type: $io_type", "UNKNOWN_IO_TYPE") if $io_type eq 'UNKNOWN';
            no strict 'refs';
            if ($io_type eq 'GLOB') {
                *{*{$self->{glob}}} = *{$value};
            }
            elsif ($value->isa('IO::Handle') || 
                   $value->isa('IO::File') || 
                   $value->isa('IO::Dir') || 
                   $value->isa('IO::Socket') || 
                   $value->isa('IO::Pipe') || 
                   $value->isa('IO::Select') || 
                   $value->isa('IO::String') || 
                   $value->isa('IO::Scalar')
            ) {
                *{*{$self->{glob}}} = $value;
            }
            else {
                $self->throw("Unsupported IO type: $io_type", "UNSUPPORTED_IO_TYPE");
            }
            $self->{io} = xclass::Ic(\*{*{$self->{glob}}}) if (!defined $self->{io});
            $self->{io}{is_shared} = 0;
            $self->{io}->share_it if $self->is_shared;
        }
        $self->throw("Input/Output context does not exist in this GLOB","NO_GLOB_IO") if !defined $self->{io};
        return $self->{io};
    }, 'IO', $value);
}

################################################################################
# Get GLOB Hash Code
sub hash_code {
    my ($self) = @_;
    return $self->sync(sub {
        return join(':', 
            $self->{space}, $self->{name}, 
            *{$self->{glob}}{SCALAR}, *{$self->{glob}}{ARRAY}, *{$self->{glob}}{HASH}
        );
    }, 'hash_code');
}

################################################################################
# Merge with another gclass
sub merge {
    my ($self, $other) = @_;
    return $self->sync(sub {
        $self->throw("Cannot merge with non-gclass object", 'TYPE_ERROR') unless blessed($other) && $other->isa(__PACKAGE__);
        $self->SCALAR->set($other->SCALAR->get) if $other->exists('scalar');
        $self->ARRAY->push(@{$other->ARRAY->get}) if $other->exists('array');
        $self->HASH->merge($other->HASH->get) if $other->exists('hash');
        $self->CODE->set($other->CODE->get) if $other->exists('code');
        $self->IO->set($other->IO->get) if $other->exists('io');
        return $self;
    }, 'merge', $other);
}

1;

################################################################################
# EOF gclass.pm (C) 2024 OnEhIppY, Domero Software
################################################################################
