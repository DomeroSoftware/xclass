#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(../lib);
use Test::More;
use Test::Exception;
use Test::Warn;
use JSON::PP;

my @xclass_methods = qw(new get set);
my @hash_methods = qw(
    _stringify_op _numeric_op _bool_op _not_op _assign_op _eq_op _ne_op _cmp_op _spaceship_op
    _sub_assign_op _and_assign_op _or_assign_op _xor_assign_op get_default 
    delete exists keys values clear each map grep  merge size invert slice modify flatten unflatten
    deep_compare deep_map pairs update remove has_keys
);
my @lclass_methods = qw(
    _ref _shared share_it _init is_defined is_empty 
    sync lock unlock apply on trigger throw debug try 
    compare equals to_string serialize deserialize clone 
    xc sc ac hc cc ic gc rc tc
);
my @hash_class = (@xclass_methods, @hash_methods, @lclass_methods);

# Load the modules
use_ok('xclass','Xc','Sc','Ac','Hc');

# Test xclass integration
subtest 'xclass integration' => sub {
    my $h = Hc({ a => 1, b => 2 });
    isa_ok($h, 'hclass', 'Hc factory method creates hclass object');
    can_ok($h, @hash_class);
    is($h->get('a'), 1, 'Hc object has correct value');

    my $complex = Hc({
        array => Ac([1, 2, 3]),
        hash => Hc({ x => 10, y => 20 }),
        scalar => Sc(42)
    });
    is($complex->get('array')->get(1), 2, 'Nested Ac access works');
    is($complex->get('hash')->get('x'), 10, 'Nested Hc access works');
    is($complex->get('scalar')->get, 42, 'Nested Sc access works');
};

# Test basic hclass methods
subtest 'Basic hclass methods' => sub {
    my $h = Hc({ a => 1, b => 2 });
    is($h->get('a'), 1, 'get method works');
    $h->set('c', 3);
    is($h->get('c'), 3, 'set method works');
    ok($h->exists('b'), 'exists method works');
    $h->delete('b');
    ok(!$h->exists('b'), 'delete method works');
    is_deeply([sort $h->keys], ['a', 'c'], 'keys method works');
    is_deeply([sort $h->values], [1, 3], 'values method works');
    $h->clear;
    ok($h->is_empty, 'clear and is_empty methods work');
};

# Test advanced hclass methods
subtest 'Advanced hclass methods' => sub {
    my $h = Hc({ a => 1, b => 2, c => 3 });
    $h->each(sub { my ($k, $v) = @_; $h->set($k,$v+1); });
    is($h->get('a'), 2, 'each method works');
    
    $h->map(sub { my ($k, $v) = @_; ($k, $v * 2) });
    is($h->get('b'), 6, 'map method works');
    
    $h->grep(sub { my ($k, $v) = @_; $v > 5 });
    ok(!$h->exists('a'), 'grep method works');
    
    $h->merge({ d => 8 });
    is($h->get('d'), 8, 'merge method works');
    
    $h = Hc({ a => 1, b => 2, c => 3 });
    is($h->size, 3, 'size method works');
    
    my %slice = $h->slice('b', 'c');
    is_deeply(\%slice, { 'b' => 2, 'c' => 3 }, 'slice method works');
    
    $h->modify(sub { my $hash = shift; $hash->{new} = 'value' });
    is($h->get('new'), 'value', 'modify method works');
};

# Test overloaded operators
subtest 'Overloaded operators' => sub {
    my $h0 = Hc({});
    my $h1 = Hc({ a => 1, b => 2 });
    my $h2 = Hc({ b => 3, c => 4 });
    
    my %deref = %{$h1->get};
    is_deeply(\%deref, { a => 1, b => 2 }, 'Dereference operator works');
    
    like("$h1", qr/\{.*\}/, 'Stringification works');
    
    is(0 + $h1, 2, 'Numification works');
    
    ok($h1, 'Boolean context works');
    ok(!$h0, 'Negation works');
    
    my $h3 = $h1;
    $h3->set('d', 5);
    is($h1->get('d'), 5, 'Assignment works');
    
    ok($h1 == $h1, 'Equality works');
    ok($h1 != $h2, 'Inequality works');
    
    cmp_ok($h1, 'cmp', $h2, 'String comparison works');
    cmp_ok($h1, '<=>', $h2, 'Numeric comparison works');
    
    $h1 += $h2;
    is_deeply($h1->get, {a => 1, b => 3, c => 4, d => 5}, 'Addition works');
    
    $h1 -= $h2;
    is_deeply($h1->get, { a => 1, d => 5 }, 'Subtraction works');
    
    $h2->set('d',5);
    $h1 &= $h2;
    is_deeply($h1->get, { d => 5 }, 'Intersection works');
    
    $h1 |= $h2;
    is_deeply($h1->get, {b => 3, c => 4, d => 5}, 'Union works');
    
    $h1->set('a',1);
    $h1->set('b',2);
    $h1->delete('d');
    $h1 ^= $h2;
    is_deeply($h1->get, {a => 1, b => 3, c => 4, d => 5}, 'Symmetric difference works');
};

# Test lclass functionality
subtest 'lclass functionality' => sub {
    my $h = Hc({ a => 1, b => 2 })->share_it;
    #$lclass::CONFIG{debug_level}=1;
    lives_ok { $h->sync(sub { 
        print STDOUT "SYNC\n";
        $h->set('c', 3) 
    },'test_sync') } 'sync method works';

    print STDOUT "H: $h\n";
    
    my $called = 0;
    $h->on('set', sub { $called++ });
    $h->set('d', 4);
    is($called, 1, 'Event system works');
    
    my $thrown = 0;
    local $SIG{__DIE__} = sub { $thrown++ };
    eval { $h->throw("Test error") };
    is($thrown, 1, 'throw method works');
    
    my $warned = 0;
    local $SIG{__WARN__} = sub { $warned++ };
    $h->debug("Test warning");
    is($warned, 1, 'warn method works');

    my $result;
    lives_ok {
        $result = $h->try(sub {
            $h->set('e', 5);
            die "Test die" if $h->size > 5;
            return 'success';
        }, 'test_operation');
    } 'try method works';
    is($result, 'success', 'try method returns correct value');
};

# Test thread safety
SKIP: {
    eval { require threads; 1 } or skip "threads not available", 1;
    
    subtest 'Thread safety' => sub {
        my $h = Hc({})->share_it;
        $h->set('count',0);
        
        my @threads = map {
            threads->create(sub {
                my ($hash)=@_;
                for (1..1000) {
                    $hash->lock();
                    my $count = $hash->get('count') || 0;
                    $hash->set('count', 1 + $count);
                    $hash->unlock();
                }
            },$h)
        } 1..10;
        
        $_->join for @threads;
        
        is($h->get('count'), 10000, 'Thread-safe operations work correctly');
    };
}

# Test error handling
subtest 'Error handling' => sub {
    my $thrown = 0; local $SIG{__DIE__} = sub { $thrown++ };
    my $warned = 0; local $SIG{__WARN__} = sub { $warned++ };
    my $h = Hc({});

    $h->get('non_existent');
    is($warned, 0, 'get throws error for non-existent key');

    $h->set();
    is($warned, 1, 'set throws error for missing arguments');

    $h->delete();
    is($warned, 2, 'delete throws error for missing key');
};

# Test serialization and deserialization
subtest 'Serialization and deserialization' => sub {
    my $h = Hc({ a => 1, b => { c => 2 } });
    my $json = $h->serialize('json');
    my $deserialized = Hc({})->deserialize($json,'json');
    is_deeply($deserialized->get, $h->get, 'Serialization and deserialization work correctly');
};

# Test integration with other xclass types
subtest 'Integration with other xclass types' => sub {
    my $h = Hc({
        array => Ac([1, 2, 3]),
        hash => Hc({ x => 10, y => 20 }),
        scalar => Sc(42)
    });
    
    isa_ok($h->get('array'), 'aclass', 'Array value is aclass');
    isa_ok($h->get('hash'), 'hclass', 'Hash value is hclass');
    isa_ok($h->get('scalar'), 'sclass', 'Scalar value is sclass');
    
    is($h->get('array')->get(1), 2, 'Can access nested aclass');
    is($h->get('hash')->get('x'), 10, 'Can access nested hclass');
    is($h->get('scalar')->get, 42, 'Can access nested sclass');
};

# Test performance
subtest 'Performance' => sub {
    my $h = Hc({});
    my $start_time = time;
    for my $i (1..10000) {
        $h->set("key$i", $i);
    }
    my $end_time = time;
    ok($end_time - $start_time < 5, 'Setting 10000 keys takes less than 5 seconds');
    
    $start_time = time;
    my $sum = 0;
    $h->each(sub { my ($k, $v) = @_; $sum += $v });
    $end_time = time;
    ok($end_time - $start_time < 1, 'Iterating over 10000 keys takes less than 1 second');
};

done_testing();
