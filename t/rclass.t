#!/usr/bin/perl
use strict;
use warnings;

use lib qw(../lib);
use Test::More;
use Test::Exception;
use Test::Warn;
use threads;
use threads::shared;
use Time::HiRes qw(sleep usleep);

my @xclass_methods = qw(new get set);
my @ref_methods = qw(
    _stringify_op _count_op _bool_op _assign_op _neg_op deref get_type merge size clear hash_code
);
my @lclass_methods = qw(
    _ref _shared share_it _init is_defined is_empty 
    sync lock unlock apply on trigger throw debug try 
    compare equals to_string serialize deserialize clone 
    xc sc ac hc cc ic gc rc tc
);
my @ref_class = (@xclass_methods, @ref_methods, @lclass_methods);

# Load the necessary modules
use_ok('xclass');

# Test xclass integration
{
    my $ref = Rc(\42);
    isa_ok($ref, 'rclass', 'Rc() creates rclass object');
    can_ok($ref, @ref_class);
    is(${$ref->get}, 42, 'Rc() correctly initializes scalar reference');

    my $array_ref = Rc([1, 2, 3]);
    is_deeply($array_ref->get, [1, 2, 3], 'Rc() correctly initializes array reference');

    my $hash_ref = Rc({a => 1, b => 2});
    is_deeply($hash_ref->get, {a => 1, b => 2}, 'Rc() correctly initializes hash reference');
}

# Test constructor and basic methods
{
    my $ref = rclass->new(\42);
    isa_ok($ref, 'rclass', 'new() creates rclass object');
    is($ref->get_type, 'SCALAR', 'get_type() returns correct type for scalar');
    is(${$ref->get}, 42, 'get ${deref} returns correct value for scalar');

    $ref->set([1, 2, 3]);
    is($ref->get_type, 'ARRAY', 'get_type() returns correct type after set()');
    is_deeply($ref->get, [1, 2, 3], 'deref() returns correct value after set()');
}

# Test overloaded operators
{
    my $scalar_ref = Rc(\42);
    is(${$scalar_ref->get}, 42, 'Scalar dereference works');
    is($scalar_ref + 0, 1, 'Numeric context works');
    ok($scalar_ref, 'Boolean context works');
    like("$scalar_ref", qr/^SCALAR\(.*\)$/, 'Stringification works: '. "$scalar_ref");

    my $array_ref = Rc([1, 2, 3]);
    is_deeply($array_ref->get, [1, 2, 3], 'Array dereference works');

    my $hash_ref = Rc({a => 1, b => 2});
    is_deeply($hash_ref->get, {a => 1, b => 2}, 'Hash dereference works');

    my $code_ref = Rc(sub { 42 });
    is(&{$code_ref->get}, 42, 'Code dereference works');

    open my $fh, '>', \my $output;
    my $glob_ref = Rc(\*$fh);
    print {*{$glob_ref->get}{IO}} "test";
    is($output, "test", 'Glob dereference works');
}

# Test advanced methods
{
    my $ref = Rc({a => 1, b => 2});
    $ref->apply(sub { $_[0]->{c} = $_[0]->{a} + $_[0]->{b}; $_[0] });
    is($ref->get->{c}, 3, 'apply() works correctly');

    my $other_ref = Rc({d => 4});
    $ref->merge($other_ref);
    is($ref->get->{d}, 4, 'merge() works correctly');

    is($ref->size, 1, 'size() returns correct value');

    $ref->clear;
    is_deeply($ref->get, {}, 'clear() works correctly');

    my $clone = $ref->clone;
    ok($clone != $ref, 'clone() creates a new object: '.join(',',$clone,$ref));
    is_deeply($clone->get, $ref->get, 'clone() creates an identical copy');

    ok($ref->equals($clone->get), 'equals() returns true for identical references');
    is($ref->compare($clone->get), 0, 'compare() returns 0 for identical references: '.join(', ',"$ref","$clone"));

    my $hash_code = $ref->hash_code;
    like($hash_code, qr/^HASH/s, 'hash_code() returns a non-empty string');
}

# Test error handling
{
    my $thrown = 0;
    local $SIG{__DIE__} = sub { $thrown++ };
    
    my $ref = Rc(\42);
    eval { $ref->merge("not a reference") };
    is($thrown, 3, 'merge() throws error for invalid input');
    eval { $ref->set("not a reference") };
    is($thrown, 4, 'set() throws error for invalid input');
}

# Test thread safety
{
    my $shared_ref = Rc(shared_clone({count => 0}))->share_it;
    my @threads = map {
        threads->create(sub {
            for (1..100) {
                $shared_ref->apply(sub { $_[0]->{count}++; $_[0] });
            }
        });
    } 1..10;
    $_->join for @threads;
    is($shared_ref->get->{count}, 1000, 'Thread-safe operations work correctly');
}

# Test lclass inherited functionality
{

    my $thrown = 0; local $SIG{__DIE__} = sub { $thrown++ };
    my $warned = 0; local $SIG{__WARN__} = sub { $warned++ };

    my $ref = Rc(\42);
    
    # Test event system
    my $event_fired = 0;
    $ref->on('after_set', sub { $event_fired++ });
    $ref->set(\43);
    is($event_fired, 1, 'Event system works');

    # Test logging
    eval { $ref->debug("Test warning") };
    is($warned, 1, 'warn() method works');

    # Test try-catch mechanism
    eval { $ref->try(sub { die "Test error" }, 'test') };
    is($thrown, 2, 'try() method catches errors');

    # Test atomic operations
    my $num = 0;
    $ref->set(\$num);
    $ref->apply(sub { ${$_[0]} += 1 });
    is(${$ref->get}, 1, 'apply() method works');

    # Test locking
    $ref->lock;
    $ref->unlock;
    pass('lock() and unlock() methods do not crash');

    # Test wait and signal
    my $signaled :shared = 0;
    threads->create(sub {
        $ref->lock;
        sleep(0.1);
        $signaled = 1;
        $ref->unlock;
    })->detach;
    sleep 0.2;
    $ref->lock;
    $ref->unlock;
    sleep 0.1;
    ok($signaled, 'wait() and signal() methods work');
}

# Test xclass type conversion
{
    my $array_ref = Rc([1, 2, 3]);
    my $aclass = $array_ref->deref;
    isa_ok($aclass, 'aclass', 'deref() returns aclass for array references');
    is($aclass->join(','), '1,2,3', 'aclass methods work on dereferenced array');

    my $hash_ref = Rc({a => 1, b => 2});
    my $hclass = $hash_ref->deref;
    isa_ok($hclass, 'hclass', 'deref() returns hclass for hash references');
    is($hclass->get('a'), 1, 'hclass methods work on dereferenced hash');
}

# Test circular reference handling
{
    my $ref1 = Rc({});
    my $ref2 = Rc({});
    $ref1->deref->{other} = $ref2;
    $ref2->deref->{other} = $ref1;
    lives_ok { $ref1 = undef; $ref2 = undef; } 'Circular references do not cause memory leaks';
}

# Test performance with large data structures
{
    my $large_array = [(1..10000)];
    my $ref = Rc($large_array);
    my $start_time = time();
    $ref->apply(sub { $_ });
    my $end_time = time();
    ok($end_time - $start_time < 1, 'Performance is acceptable for large data structures');
}

# Test all supported reference types
{
    # Scalar
    my $scalar_ref = Rc(\42);
    is($scalar_ref->get_type, 'SCALAR', 'Scalar reference type is correct');
    is(${$scalar_ref->get}, 42, 'Scalar reference value is correct');

    # Array
    my $array_ref = Rc([1, 2, 3]);
    is($array_ref->get_type, 'ARRAY', 'Array reference type is correct');
    is_deeply($array_ref->deref->get, [1, 2, 3], 'Array reference value is correct');

    # Hash
    my $hash_ref = Rc({a => 1, b => 2});
    is($hash_ref->get_type, 'HASH', 'Hash reference type is correct');
    is_deeply($hash_ref->deref->get, {a => 1, b => 2}, 'Hash reference value is correct');

    # Code
    my $code_ref = Rc(sub { 42 });
    is($code_ref->get_type, 'CODE', 'Code reference type is correct');
    is($code_ref->deref->(), 42, 'Code reference executes correctly');

    # Glob
    open my $fh, '>', \my $output;
    my $glob_ref = Rc(\*$fh);
    is($glob_ref->get_type, 'GLOB', 'Glob reference type is correct');
    print {$glob_ref->deref} "test";
    is($output, "test", 'Glob reference works correctly');
}

# Test error handling for unsupported operations
{
    my $scalar_ref = Rc(\42);
    throws_ok { $scalar_ref->push(1) } qr/Can't locate object method "push"/, 'Unsupported method throws error';
}

# Test thread-local and shared references
{
    my $count = 42; my $clone = 0;
    my $local_ref = Rc(\$count);
    my $shared_ref = Rc(shared_clone(\$clone));

    threads->create(sub {
        $shared_ref->apply(sub { ${$_[0]} += 1; $_[0] });
    })->join;

    is(${$local_ref->get}, 42, 'Thread-local reference is unaffected by other threads');
    is(${$shared_ref->get}, 1, 'Shared reference is modified across threads');
}

# Test deep cloning
{
    my $original = Rc({
        a => [1, 2, {b => 3}],
        c => {d => [4, 5]}
    });
    my $clone = $original->clone;

    $original->deref->get->{a}[2]{b} = 99;
    $original->deref->get->{c}{d}[0] = 88;

    is($clone->deref->get->{a}[2]{b}, 3, 'Deep clone: nested hash is independent');
    is($clone->deref->get->{c}{d}[0], 4, 'Deep clone: nested array is independent');
}

done_testing();
