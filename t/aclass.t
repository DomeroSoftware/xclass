#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use Test::More;
use threads;
use Thread::Queue;

my @xclass_methods = qw(new get set);
my @array_methods = qw(
    _array_deref_op _stringify_op _count_op _bool_op _neg_op _repeat_op _assign_op
    _eq_op _ne_op _cmp_op _spaceship_op _add_op _sub_op _mul_op 
    _bitwise_and_op _bitwise_or_op _bitwise_xor_op _bitwise_not
    _concat_assign_op _lshift_op _rshift_op
    push pop shift unshift len sort reverse splice join clear map grep reduce slice each
    first last sum min max unique compare_and_swap atomic_update iterator
);
my @lclass_methods = qw(
    _ref _shared share_it _init is_defined is_empty 
    sync lock unlock apply on trigger throw debug try 
    compare equals to_string serialize deserialize clone 
    xc sc ac hc cc ic gc rc tc
);
my @array_class = (@xclass_methods, @array_methods, @lclass_methods);

# Load the modules
use_ok('xclass', 'Xc', 'Ac');

# Test basic aclass functionality
{
    my $arr = Ac([1, 2, 3]);
    isa_ok($arr, 'aclass', 'Ac creates an aclass object');
    can_ok($arr, @array_class);
    is_deeply($arr->get, [1, 2, 3], 'get returns the correct array');
    
    $arr->push(4, 5);
    is_deeply($arr->get, [1, 2, 3, 4, 5], 'push adds elements correctly');
    
    is($arr->pop, 5, 'pop removes and returns the last element');
    is_deeply($arr->get, [1, 2, 3, 4], 'array is updated after pop');
    
    is($arr->shift, 1, 'shift removes and returns the first element');
    is_deeply($arr->get, [2, 3, 4], 'array is updated after shift');
    
    $arr->unshift(0, 1);
    is_deeply($arr->get, [0, 1, 2, 3, 4], 'unshift adds elements at the beginning');
    
    is($arr->len, 5, 'len returns the correct length');
    
    $arr->sort(sub { $_[1] <=> $_[0] });
    is_deeply($arr->get, [4, 3, 2, 1, 0], 'sort works correctly');
    
    $arr->reverse;
    is_deeply($arr->get, [0, 1, 2, 3, 4], 'reverse works correctly');
    
    my @spliced = $arr->splice(1, 2, 'a', 'b');
    is_deeply(\@spliced, [1, 2], 'splice returns removed elements');
    is_deeply($arr->get, [0, 'a', 'b', 3, 4], 'array is updated after splice');
    
    is($arr->join('-'), '0-a-b-3-4', 'join works correctly');
    
    $arr->clear;
    is_deeply($arr->get, [], 'clear empties the array');
}

# Test thread-safe operations
{
    my $arr = Ac([1, 2, 3, 4, 5]);
    my $queue = Thread::Queue->new();

    my @threads = map {
        threads->create(sub {
            for (1..100) {
                $arr->push($_);
                $arr->pop;
                $arr->shift;
                $arr->unshift($_);
            }
            $queue->enqueue($arr->len);
        });
    } 1..5;

    $_->join for @threads;

    my @lengths = map { $queue->dequeue } 1..5;
    is_deeply(\@lengths, [5, 5, 5, 5, 5], 'Array length remains consistent across threads');
}

# Test xclass top-level functionality
{
    my $arr = Xc([1, 2, 3]);
    isa_ok($arr, 'aclass', 'Xc creates an aclass object for arrays');
    
    my $arr2 = Ac([4, 5, 6]);
    isa_ok($arr2, 'aclass', 'Ac creates an aclass object');
    
    is_deeply($arr->get, [1, 2, 3], 'Xc initializes array correctly');
    is_deeply($arr2->get, [4, 5, 6], 'Ac initializes array correctly');
}

# Test underlying lclass functionality
{
    my $arr = Ac([1, 2, 3]);
    
    my $thrown = 0;
    local $SIG{__DIE__} = sub { $thrown++ };
    eval { $arr->throw("Test error") };
    is($thrown, 1, 'throw method works');
    
    my $warned = 0;
    local $SIG{__WARN__} = sub { $warned++ };
    $arr->debug("Test warning");
    is($warned, 1, 'warn method works');
    
    my $triggered = 0;
    $arr->on('push', sub { $triggered++ });
    $arr->push(4);
    is($triggered, 1, 'event system works');
}

# Test overloaded operators
{
    my $arr = Ac([1, 2, 3]);
    my @array = @{$arr};
    is_deeply(\@array, [1, 2, 3], 'Array dereference works');
    
    is($arr->_count_op, 3, 'Numeric conversion works');
    is("$arr", "1,2,3", 'String conversion works');
    ok($arr, 'Boolean conversion works for non-empty array');
    ok(!Ac([]), 'Boolean conversion works for empty array');
    
    $arr += [4, 5];
    is_deeply($arr->get, [1, 2, 3, 4, 5], 'Addition operator works');
    
    $arr -= [2];
    is_deeply($arr->get, [1, 3, 4, 5], 'Subtraction operator works');
    
    $arr *= 2;
    is_deeply($arr->get, [2, 6, 8, 10], 'Multiplication operator works');
    
    $arr &= [1, 2, 4];
    is_deeply($arr->get, [2], 'Bitwise AND operator works');
    
    $arr |= [3, 4];
    is_deeply($arr->get, [2, 3, 4], 'Bitwise OR operator works');
    
    $arr ^= [1, 2, 3];
    is_deeply($arr->get, [4], 'Bitwise XOR operator works');
    
    $arr += [5,6];
    my $arr2 = ~$arr;
    is_deeply($arr2->get, [6, 5, 4], 'Bitwise NOT operator works');
    
    $arr2 = $arr x 2;
    is_deeply($arr2->get, [4, 5, 6, 4, 5, 6], 'Repetition operator works');
}

# Test all public methods
{
    my $arr = Ac([1, 2, 3, 4, 5]);
    
    $arr->map(sub { $_[0] * 2 });
    is_deeply($arr->get, [2, 4, 6, 8, 10], 'map works correctly');
    
    $arr->grep(sub { $_[0] > 5 });
    is_deeply($arr->get, [6, 8, 10], 'grep works correctly');
    
    is($arr->reduce(sub { $_[0] + $_[1] }), 24, 'reduce works correctly');
    
    is_deeply($arr->slice(0, 1)->get, [6, 8], 'slice works correctly');
    
    my $sum = 0;
    $arr->each(sub { $sum += $_[0] });
    is($sum, 24, 'each works correctly');
    
    is($arr->first(sub { $_[0] > 7 }), 8, 'first works correctly');
    is($arr->last(sub { $_[0] < 10 }), 8, 'last works correctly');
    
    is($arr->sum, 24, 'sum works correctly');
    is($arr->min, 6, 'min works correctly');
    is($arr->max, 10, 'max works correctly');
    
    $arr->set([1, 2, 2, 3, 3, 3]);
    $arr->unique;
    is_deeply($arr->get, [1, 2, 3], 'unique works correctly');
    
    ok($arr->compare_and_swap(0, 1, 10), 'compare_and_swap works when values match');
    ok(!$arr->compare_and_swap(1, 1, 20), 'compare_and_swap fails when values don\'t match');
    
    $arr->atomic_update(0, sub { $_[0] * 2 });
    is($arr->get(0), 20, 'atomic_update works correctly');
    
    my $iterator = $arr->iterator;
    my @iterated;
    while (my $value = $iterator->()) {
        push @iterated, $value;
    }
    is_deeply(\@iterated, [20, 2, 3], 'iterator works correctly');
}

# Additional edge cases and error handling
{
    my $arr = Ac([]);
    
    my $thrown = 0;
    local $SIG{__DIE__} = sub { $thrown++ };

    eval { $arr->pop };
    is($thrown, 1, 'pop on empty array throws error');

    eval { $arr->shift };
    is($thrown, 2, 'shift on empty array throws error');
    
    eval { $arr->get(0) };
    is($thrown, 3, 'get with invalid index throws error');
    
    eval { $arr->set("null", 1) };
    is($thrown, 4, 'set with invalid index throws error');
    
    eval { $arr->splice(1, 1) };
    is($thrown, 5, 'splice with invalid offset throws error');
    
    eval { $arr->map("not a coderef") };
    is($thrown, 6, 'map with invalid coderef throws error');
}

done_testing();
