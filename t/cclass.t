#!/usr/bin/env perl

use lib qw(../lib);

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Warn;
use Time::HiRes qw(time sleep);
use threads;
use threads::shared;

my @xclass_methods = qw(new get set);
my @code_methods = qw(
    _stringify_op _count_op _bool_op _eq_op _ne_op _cmp_op _spaceship_op 
    call benchmark wrap curry compose time profile bind create_thread detach join
    apply_code modify chain partial flip limit_args delay retry_with_backoff timeout hash_code
);
my @lclass_methods = qw(
    _ref _shared share_it _init is_defined is_empty 
    sync lock unlock apply on trigger throw debug try 
    compare equals to_string serialize deserialize clone 
    xc sc ac hc cc ic gc rc tc
);
my @code_class = (@xclass_methods, @code_methods, @lclass_methods);

# Load the necessary modules
use_ok('xclass','Xc','Cc');

# Test xclass integration
subtest 'xclass integration' => sub {
    my $code = Cc(sub { $_[0] + $_[1] });
    isa_ok($code, 'cclass', 'xclass creates cclass object for CODE type');
    can_ok($code, @code_class);
    is($code->(2, 3), 5, 'cclass object works as expected when created via xclass');
};

# Test basic cclass functionality
subtest 'Basic cclass functionality' => sub {
    my $add = cclass->new(sub { $_[0] + $_[1] });
    isa_ok($add, 'cclass', 'Cc creates cclass object');
    is($add->call(2, 3), 5, 'call method works');
    is($add->(2, 3), 5, 'overloaded function call works');
    
    $add->set(sub { $_[0] * $_[1] });
    is($add->(2, 3), 6, 'set method changes the code reference');
    
    my $code_ref = $add->get();
    is(ref($code_ref), 'CODE', 'get method returns a code reference');
};

# Test overloaded operators
subtest 'Overloaded operators' => sub {
    my $func = Cc(sub { $_[0] + 1 });
    
    # Stringification
    #like("sub $func", qr/^sub \{.+\}$/s, 'Stringification works');
    
    # Numification
    is(0 + $func, 1, 'Numification returns true for defined function');
    
    # Boolean context
    ok($func, 'Boolean context returns true for defined function');
    
    # Equality
    my $func2 = $func->clone();
    ok($func == $func2, 'Equality comparison works');
    ok($func != Cc(sub { 2 }), 'Inequality comparison works');
    
    # Comparison
    my $func_a = Cc(sub { 'a' });
    my $func_b = Cc(sub { 'b' });
    is($func_a cmp $func_b, -1, 'String comparison works');
    is($func_a <=> $func_b, -1, 'Numeric comparison works');
    
    # Composition
    $func->compose(sub { $_[0] * 2 });
    is($func->(3), 8, 'Function composition works');
};

# Test advanced function manipulation
subtest 'Advanced function manipulation' => sub {
    my $expensive_func = Cc(sub {
        my ($x, $y) = @_;
        sleep(0.1);  # Simulate expensive computation
        return $x * $y;
    });
    
    # Currying
    my $add_five = Cc(sub { $_[0] + $_[1] })->curry(5);
    is($add_five->(3), 8, 'Currying works');
    
    # Composition
    my $composed = $expensive_func->compose(sub { $_[0] + 1 }, sub { $_[0] * 2 });
    is($composed->(2, 3), 13, 'Composition works');
};

# Test execution control
subtest 'Execution control' => sub {
    my $thrown = 0; local $SIG{__DIE__} = sub { $thrown++ };
    my $warned = 0; local $SIG{__WARN__} = sub { $warned++ };
    # Timeout
    my $timeout_func = Cc(sub { sleep(2); return "Done" })->timeout(1);
    eval {$timeout_func->() };
    is($thrown,1,'Timeout throws exception');
};

# Test performance analysis
subtest 'Performance analysis' => sub {
    my $func = Cc(sub { sleep(0.1); return $_[0] * 2 });
    
    my $timed = $func->time(5);
    ok($timed->{time} >= 0.1, 'Time measurement works');
    is($timed->{result}, 10, 'Timed function returns correct result');
    
    my $profile = $func->profile(10, 5);
    ok($func->{profiling}{average} >= 0.1, 'Profiling measures average time');
    ok($func->{profiling}{duration} >= 1, 'Profiling measures total time');
};

# Test threading
subtest 'Threading' => sub {
    my $threaded_func = Cc(sub {
        my ($id) = @_; 
        return "Thread $id completed"; 
    });
    
    $threaded_func->detach(1);
    pass('detach does not throw an exception');
    
    my @result = $threaded_func->join(2);
    is($result[0], "Thread 2 completed", 'join returns thread result');
    
};

# Test utility methods
subtest 'Utility methods' => sub {
    my $func = Cc(sub { $_[0] + 1 });
    my $applied = $func->apply_code(sub { $_[0] * 2 });
    is($applied->(2), 6, 'apply works');
    
    $func = Cc(sub { $_[0] + 1 });
    my $chained = $func->chain(sub { $_[0] * 2 }, sub { $_[0] + 3 });
    is($chained->(2), 9, 'chain works');
    
    my $partial = Cc(sub { $_[0] + $_[1] + $_[2] })->partial(1, 2);
    is($partial->(3), 6, 'partial application works');
    
    my $flipped = Cc(sub { $_[0] / $_[1] })->flip();
    is($flipped->(2, 10), 5, 'flip works');
    
    my $limited = Cc(sub { $_[0] + $_[1] + ($_[2] // 0) })->limit_args(2);
    is($limited->(1, 2, 3), 3, 'limit_args works');
    
    my $delayed = Cc(sub { Time::HiRes::sleep(0.1); return Time::HiRes::gettimeofday() })->delay(0.1);
    my $start_time = Time::HiRes::gettimeofday();
    my $end_time = [$delayed->()]; $end_time = join('.',@{$end_time});
    my $run_time = $end_time - $start_time;
    ok($run_time >= 0.1, "delay works STM: $start_time - ETM: $end_time - RTM: $run_time");
};

# Test error handling
subtest 'Error handling' => sub {
    my $thrown = 0; local $SIG{__DIE__} = sub { $thrown++ };
    my $warned = 0; local $SIG{__WARN__} = sub { $warned++ };
    eval { Cc("not a coderef") }; is($thrown, 1, 'new throws on invalid input');
    eval { Cc(sub { die "error" })->call() }; is($thrown, 3, 'call propagates exceptions');
    eval { Cc(sub { 1 })->retry(0, 1) }; is($thrown, 4, 'retry validates input');

#    my $warned = 0;
#    local $SIG{__WARN__} = sub { $warned++ };
#    $arr->debug("Test warning");
#    is($warned, 1, 'warn method works');

};

# Test lclass inherited functionality
subtest 'lclass inherited functionality' => sub {
    my $func = Cc(sub { $_[0] + 1 });
    
    # Test event system
    my $event_fired = 0;
    $func->on('before_call', sub { $event_fired++ });
    $func->(1);
    is($event_fired, 1, 'Event system works');
};

# Test thread safety
subtest 'Thread safety' => sub {
    my $shared_value : shared = shared_clone(0);
    my $func = Cc(sub { lock($shared_value); $shared_value++ });
    my @threads = map { $func->create_thread() } 1..10;
    $_->join for @threads;
    is($shared_value, 10, 'Thread-safe execution');
};

# Test integration with xclass type system
subtest 'xclass type system integration' => sub {
    my $func = Cc(sub { return [$_[0], $_[1]] });
    my $result = $func->wrap(1, 2);
    isa_ok($result, 'aclass', 'wrap returns xclass type : '.ref($result));
    is_deeply($result->get, [1, 2], 'wrap preserves result');
};

# lclass integration
subtest 'Clone method' => sub {
    my $original = Cc(sub { $_[0] * 2 });
    my $cloned = $original->clone();
    is($cloned->(5), 10, 'Cloned function behaves the same as original');
    $original->set(sub { $_[0] * 3 });
    is($cloned->(5), 10, 'Modifying original does not affect clone');
};

subtest 'Modify method' => sub {
    my $func = Cc(sub { $_[0] + 1 });
    $func->modify(sub {
        my $original = shift;
        return sub { $original->(@_) * 2 };
    });
    
    is($func->(5), 12, 'Modified function combines original and new behavior');
};

subtest 'Bind method' => sub {
    my $obj = { value => 5 };
    my $method = Cc(sub {
        my ($self, $x) = @_;
        return $self->{value} + $x;
    })->bind($obj);
    
    is($method->(3), 8, 'Bound method has correct context');
};

done_testing();
