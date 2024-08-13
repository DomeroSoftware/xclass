################################################################################

# cclass.pm - Advanced Code Reference Manipulation Class for xclass Ecosystem

#
# This class provides a robust and feature-rich interface for working with
# code references within the xclass ecosystem. It offers thread-safe operations,
# advanced function manipulation, and seamless integration with other xclass components.
#
# Key Features:
# - Thread-safe code reference operations using lclass synchronization
# - Overloaded operators for intuitive code reference manipulation
# - Advanced function manipulation: memoization, currying, composition
# - Execution control: throttling, debouncing, retrying with backoff
# - Performance analysis: timing and profiling
# - Thread management: creation, detaching, and joining
# - Integration with xclass for result wrapping and type handling
#
# Code Reference Operations:
# - Basic: set, get, call
# - Functional: modify, curry, compose, apply, chain, partial, flip
# - Performance: memoize, throttle, debounce
# - Execution Control: retry, retry_with_backoff, timeout
# - Analysis: time, profile
# - Threading: create_thread, detach, join
#
# Integration with xclass Ecosystem:
# - Inherits core functionality from lclass
# - Implements xclass event system for operation tracking
# - Supports result wrapping using xclass type system
#
# Thread Safety:
# - All methods are designed to be thread-safe
# - Utilizes lclass synchronization mechanisms
#
# Performance Considerations:
# - Optimized for both single-threaded and multi-threaded environments
# - Efficient handling of function composition and chaining
#
# Extensibility:
# - Designed to be easily extended with additional methods
# - Supports custom event triggers for all operations
#
# Usage Examples:
# - Basic: $code->call(1, 2, 3)
# - Advanced: $code->memoize()->throttle(5)->retry(3, 1)
# - Composition: $code->compose($func1, $func2)->curry(1, 2)->call(3)
#
# Author: OnEhIppY, Domero Software
# Copyright: (C) 2024 OnEhIppY, Domero Software
#
# Dependencies:
# - Perl v5.8.0 or higher
# - threads::shared (for thread-safe shared variables)
# - xclass (for handling specific data types and ecosystem integration)
#
# Note: This class is designed to be a comprehensive solution for code reference
# manipulation within the xclass ecosystem. It balances feature richness
# with performance and thread safety considerations.

################################################################################

package cclass;

use strict;
use warnings;
use threads;
use threads::shared;
use Scalar::Util qw(blessed);
use Time::HiRes qw(sleep);
use Digest::xxHash;
use Benchmark qw(:all);

our $VERSION = '2.0.0';

BEGIN {
    xclass::register('CODE', 'cclass');
}

use lclass qw(:code);

################################################################################
# Overload operators for code-specific operations

use overload
    '&{}' => \&_code_op,
    '""' => \&_stringify_op,
    '0+' => \&_count_op,
    'bool' => \&_bool_op,
    '==' => \&_eq_op,
    '!=' => \&_ne_op,
    'cmp' => \&_cmp_op,
    '<=>' => \&_spaceship_op,
    #'.' => \&_compose_op,
    fallback => 1;

################################################################################
# Private methods for overloaded operators

sub _code_op { my $self = shift; sub { $self->call(@_) } }

sub _stringify_op { my $self = shift; $self->to_string }

sub _count_op { my $self = shift; $self->is_defined ? 1 : 0 }

sub _bool_op { my $self = shift; $self->is_defined }

sub _eq_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        return 0 unless blessed($other) && $other->isa(__PACKAGE__);
        return $self->get == $other->get;
    },'eq_op');
}

sub _ne_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        return !$self->_eq_op($other, $swap);
    },'ne_op');
}

sub _cmp_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        my $self_str = $self->to_string;
        my $other_str = blessed($other) && $other->can('to_string') ? $other->to_string : "$other";
        return $self_str cmp $other_str;
    },'cmp_op');
}

sub _spaceship_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        my $self_str = $self->to_string;
        my $other_str = blessed($other) && $other->can('to_string') ? $other->to_string : "$other";
        return $self_str cmp $other_str;
    },'spaceship_op');
}

sub _compose_op {
    my ($self, $other, $swap) = @_;
    return $self->sync(sub {
        $self->throw("Cannot compose with non-CODE object", 'TYPE_ERROR')
            unless ref($other) eq 'CODE';
        return $self->compose($other);
    },'compose_op');
}

################################################################################
# Constructor method

sub new {
    my ($class, $ref, %options) = @_;
    my $self = bless {
        is => 'code',
        code => $ref,
        memoized_cache => shared_clone({}),
        memoized_cache_keys => shared_clone([]),
        last_call => shared_clone(0),
    }, $class;
    $self->throw("Invalid Code Reference","TYPE_ERROR") if defined $self->{code} && ref($self->{code}) ne 'CODE';
    $self->try(sub {
        $self->_init(%options);
    }, 'new', $class, $ref, \%options);
    
    return $self;
}

################################################################################
# Basic operations

sub set {
    my ($self, $ref) = @_;
    return $self->sync(sub {
        unless (ref($ref) eq 'CODE') {
            $self->trigger('set_error', { error => "Invalid code reference" });
            $self->throw("Invalid code reference", 'TYPE_ERROR');
        }
        $self->{code} = $ref;
        return $self;
    },'set',$ref);
}

sub get {
    my ($self) = @_;
    return $self->sync(sub { return $self->{code} },'get');
}

sub call {
    my ($self, @args) = @_;
    return $self->try(sub {
        $self->throw("Undefined code reference", 'TYPE_ERROR') unless defined $self->{code};
        my @result = $self->{code}->(@args);
        return wantarray ? @result : $result[0]
    },'call',\@args);
}


################################################################################
# Performance Metrics
################################################################################

sub benchmark {
    my ($self, $count) = @_;
    return timethis($count // 1000, $self->{code});
}

################################################################################
# Advanced operations

sub wrap {
    my ($self, @args) = @_;
    my $result = $self->call(@args);
    return xclass::Xc($result);
}

sub curry {
    my ($self, @curry_args) = @_;
    return $self->sync(sub {
        my $original = $self->{code};
        $self->{code} = sub { return $original->(@curry_args, @_) };
        return $self;
    },'curry',\@curry_args);
}

sub compose {
    my ($self, @coderefs) = @_;
    return $self->sync(sub {
        foreach my $coderef (@coderefs) {
            unless (ref($coderef) eq 'CODE') {
                $self->trigger('compose_error', { error => "Invalid code reference in composition" });
                $self->throw("Invalid code reference in composition", 'TYPE_ERROR');
            }
        }
        my $original = $self->{code};
        $self->{code} = sub {
            my $result = $original->(@_);
            for my $coderef (reverse @coderefs) {
                $result = $coderef->($result);
            }
            return $result;
        };
        return $self;
    },'compose',\@coderefs);
}

sub time {
    my ($self, @args) = @_;
    return $self->sync(sub {
        my $start = Time::HiRes::time;
        my $result = eval { $self->call(@args) };
        my $end = Time::HiRes::time;
        if ($@) {
            $self->trigger('time_error', { error => $@, args => \@args });
            $self->throw($@, 'RUNTIME_ERROR');
        }
        my $timing = {
            result => $result,
            time => $end - $start
        };
        $self->trigger('time', $timing);
        return $timing;
    },'time',\@args);
}

sub profile {
    my ($self, $iterations, @args) = @_;
    my $operation = $self->{code};
    $self->throw("Invalid operation for profiling", 'PROFILE_ERROR') unless ref $operation eq 'CODE';

    return $self->sync(sub {
        my $result;
        my $start = Time::HiRes::time();
        for (1..$iterations) {
            $result = $operation->(@args);
        }
        my $end = Time::HiRes::time();
        
        $self->{profiling} = {
            duration => $end - $start,
            average => ($end - $start) / $iterations,
        };

        return $result;
    })
}

sub bind {
    my ($self, $context) = @_;
    return $self->sync(sub {
        my $original = $self->{code};
        $self->{code} = sub { $original->($context, @_) };
        return $self;
    },'bind',\$context);
}

sub create_thread {
    my ($self, @args) = @_;
    return $self->sync(sub {
        unless (defined $self->{code}) {
            $self->trigger('create_thread_error', { error => "Undefined code reference" });
            $self->throw("Undefined code reference", 'TYPE_ERROR');
        }
        my $thread;
        eval {
            $thread = threads->create(sub {
                my @result;
                eval { @result = $self->{code}->(@args) };
                if ($@) {
                    $self->trigger('thread_execution_error', { error => $@, args => \@args });
                    $self->throw($@, 'RUNTIME_ERROR');
                }
                return wantarray ? @result : $result[0]
            })
        };
        if ($@) {
            $self->trigger('create_thread_error', { error => $@ });
            $self->throw("Thread creation failed: $@", 'RUNTIME_ERROR');
        }
        $self->trigger('create_thread', { thread => $thread, args => \@args });
        return $thread;
    },'create_thread',\@args);
}

sub detach {
    my ($self, @args) = @_;
    my $thread = $self->create_thread(@args);
    my $detached = $thread->detach;
    $self->trigger('detach', { thread => $thread, detached => $detached, args => \@args });
    return $detached;
}

sub join {
    my ($self, @args) = @_;
    return $self->create_thread(@args)->join()
}

sub apply_code {
    my ($self, $func) = @_;
    return $self->sync(sub {
        unless (ref($func) eq 'CODE') {
            $self->trigger('apply_error', { error => "Invalid function argument" });
            $self->throw("Invalid function argument", 'TYPE_ERROR');
        }
        my $original = $self->{code};
        $self->{code} = sub {
            my @result = eval { return $original->(@_) };
            if ($@) {
                $self->trigger('apply_error', { error => $@, args => \@_ });
                $self->throw($@, 'RUNTIME_ERROR');
            }
            my @applied_result = eval { return $func->(@result) };
            if ($@) {
                $self->trigger('apply_error', { error => $@, result => \@result });
                $self->throw($@, 'RUNTIME_ERROR');
            }
            $self->trigger('apply', { original_result => \@result, applied_result => \@applied_result });
            return wantarray ? @applied_result : $applied_result[0];
        };
        return $self;
    },'apply',$func);
}

sub modify {
    my ($self, $func) = @_;
    return $self->sync(sub {
        unless (ref($func) eq 'CODE') {
            $self->trigger('apply_error', { error => "Invalid function argument" });
            $self->throw("Invalid function argument", 'TYPE_ERROR');
        }
        $self->{code} = $func->($self->{code});
        return $self;
    },'modify',$func);
}

sub chain {
    my ($self, @funcs) = @_;
    return $self->sync(sub {
        foreach my $func (@funcs) {
            unless (ref($func) eq 'CODE') {
                $self->trigger('chain_error', { error => "Invalid function in chain" });
                $self->throw("Invalid function in chain", 'TYPE_ERROR');
            }
        }
        my $original = $self->{code};
        $self->{code} = sub {
            my $result = eval { $original->(@_) };
            if ($@) {
                $self->trigger('chain_error', { error => $@, args => \@_ });
                $self->throw($@, 'RUNTIME_ERROR');
            }
            for my $func (@funcs) {
                $result = eval { $func->($result) };
                if ($@) {
                    $self->trigger('chain_error', { error => $@, result => $result });
                    $self->throw($@, 'RUNTIME_ERROR');
                }
            }
            $self->trigger('chain', { result => $result, chain_length => scalar(@funcs) });
            return $result;
        };
        return $self;
    },'chain',\@funcs);
}

sub partial {
    my ($self, @args) = @_;
    return $self->sync(sub {
        my $original = $self->{code};
        $self->{code} = sub {
            return $original->(@args, @_);
        };
        $self->trigger('partial', { partial_args => \@args });
        return $self;
    },'partial',\@args);
}

sub flip {
    my ($self) = @_;
    return $self->sync(sub {
        my $original = $self->{code};
        $self->{code} = sub {
            my @flipped_args = reverse @_;
            $self->trigger('flip', { original_args => \@_, flipped_args => \@flipped_args });
            return $original->(@flipped_args);
        };
        return $self;
    },'flip');
}

sub limit_args {
    my ($self, $n) = @_;
    return $self->sync(sub {
        unless ($n > 0) {
            $self->trigger('limit_args_error', { error => "Invalid argument count" });
            $self->throw("Invalid argument count", 'TYPE_ERROR');
        }
        my $original = $self->{code};
        $self->{code} = sub {
            my @limited_args = (@_)[0..($n-1)];
            $self->trigger('limit_args', { original_count => scalar(@_), limited_count => scalar(@limited_args) });
            return $original->(@limited_args);
        };
        return $self;
    },'limit_args',$n);
}

sub delay {
    my ($self, $seconds) = @_;
    return $self->sync(sub {
        unless ($seconds >= 0) {
            $self->trigger('delay_error', { error => "Invalid delay time" });
            $self->throw("Invalid delay time", 'TYPE_ERROR');
        }
        my $original = $self->{code};
        $self->{code} = sub {
            $self->trigger('delay_start', { delay => $seconds });
            sleep($seconds);
            my @result = $original->(@_);
            $self->trigger('delay_end', { delay => $seconds, result => \@result });
            return wantarray ? @result : $result[0];
        };
        return $self;
    },'delay',$seconds);
}

sub retry_with_backoff {
    my ($self, $max_attempts, $initial_delay, $max_delay) = @_;
    return $self->sync(sub {
        unless ($max_attempts > 0 && $initial_delay > 0 && $max_delay >= $initial_delay) {
            $self->trigger('retry_with_backoff_error', { error => "Invalid parameters", max_attempts => $max_attempts, initial_delay => $initial_delay, max_delay => $max_delay });
            $self->throw("Invalid parameters for retry_with_backoff", 'TYPE_ERROR');
        }
        my $original = $self->{code};
        $self->{code} = sub {
            my $attempts = 0;
            my $delay = $initial_delay;
            while ($attempts < $max_attempts) {
                my @result = eval { $original->(@_) };
                unless ($@) {
                    $self->trigger('retry_with_backoff_success', { attempts => $attempts + 1 });
                    return wantarray ? @result : $result[0];
                }
                sleep($delay);
                $delay = $delay * 2 < $max_delay ? $delay * 2 : $max_delay;
                $attempts++;
            }
            $self->trigger('retry_with_backoff_failure', { attempts => $max_attempts, error => $@ });
            $self->throw("Function failed after $max_attempts attempts with exponential backoff: $@", 'RUNTIME_ERROR');
        };
        $self->trigger('retry_with_backoff', { max_attempts => $max_attempts, initial_delay => $initial_delay, max_delay => $max_delay });
        return $self;
    },'retry_with_backoff',[$max_attempts, $initial_delay, $max_delay]);
}

sub timeout {
    my ($self, $seconds) = @_;
    return $self->sync(sub {
        $self->throw("Invalid timeout value", 'TYPE_ERROR') unless $seconds > 0;
        $self->trigger('timeout_start', { seconds => $seconds });
        my $original = $self->{code};
        $self->{code} = sub {
            my $result;
            eval {
                local $SIG{ALRM} = sub { die "Timeout\n" };
                alarm($seconds);
                $result = $original->(@_);
                alarm(0);
            };
            if ($@ eq "Timeout\n") {
                $self->trigger('timeout');
                $self->throw("Function execution timed out after $seconds seconds", 'TIMEOUT_ERROR');
            }
            $self->throw($@, 'RUNTIME_ERROR') if $@;
            $self->trigger('timeout_end', { result => $result });
            return $result;
        };
        return $self;
    },'timeout',$seconds);
}

sub hash_code {
    my ($self) = @_;
    return $self->sync(sub {
        return defined $self->{code} ? int($self->{code}) : 0;
    },'hash_code');
}

1;

################################################################################
# EOF cclass.pm (C) 2024 OnEhIppY, Domero Software
################################################################################
