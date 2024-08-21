#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(../lib);
use Test::More;
use Test::Exception;
use Test::Warn;
use JSON::XS;

my @xclass_methods = qw(new get set);
my @scalar_methods = qw(
    _not_op _assign_op _bool_op _count_op _quote_op _eq_op _ne_op _cmp_op _spaceship_op
    _add_op _sub_op _mul_op _div_op _mod_op _exp_op _lshift_op _rshift_op
    _and_op _or_op _xor_op _repeat_op _bitwise_not
    _concat_assign_op _inc_assign_op _dec_assign_op
    _mul_assign_op _div_assign_op _mod_assign_op _exp_assign_op
    _inc_op _dec_op bit_length
    chomp chop substr reverse uc lc split concat inc dec mul div mod exp neg
    modify type append prepend is_numeric to_number len to_json from_json
    match subs trim pad merge clear fetch_add fetch_store test_set
    contains replace_all to_bool eq_ignore_case title_case count_occurrences
    truncate to_camel_case to_snake_case valid enc_base64 dec_base64 encrypt decrypt
    md5 sha256 sha512
);
my @lclass_methods = qw(
    _ref _shared share_it _init is_defined is_empty 
    sync lock unlock apply on trigger throw debug try 
    compare equals to_string serialize deserialize clone 
    xc sc ac hc cc ic gc rc tc
);

my @scalar_class = (@xclass_methods, @scalar_methods, @lclass_methods);

# Load the necessary modules
use_ok('xclass', 'Sc');

# Test xclass method for creating classes
{
    my $scalar = Sc(\(my $s = "xclass test"));
    print STDOUT "Scalar($scalar) `",ref($scalar),"`,`",$scalar->get,"`\n";
    isa_ok($scalar, 'sclass', 'Sc() creates sclass object');
    can_ok($scalar, @scalar_class);
    is("$scalar", "xclass test", 'Sc() initializes with correct value');
}

# Test base class construction
{
    my $scalar = sclass->new(\(my $s = "test"));
    print STDOUT "Scalar($scalar) `",ref($scalar),"`,`",$scalar->get,"`\n";
    isa_ok($scalar, 'sclass', 'sclass->new creates sclass object ');
    can_ok($scalar, @scalar_class);
    is("$scalar", "test", 'sclass object stringifies correctly');
}

# Test class-specific methods
{
    my $scalar = Sc(\(my $s = "Hello, World!\n"));
    
    # String operations
    is($scalar->chomp->get, "Hello, World!", 'chomp() works');
    is($scalar->chop->get, "Hello, World", 'chop() works');
    is($scalar->uc->get, "HELLO, WORLD", 'uc() works');
    is($scalar->lc->get, "hello, world", 'lc() works');
    is($scalar->reverse->get, "dlrow ,olleh", 'reverse() works');
    
    $scalar->set("  trim me  ");
    is($scalar->trim->get, "trim me", 'trim() works');
    
    $scalar->set("pad");
    is($scalar->pad(5)->get, "  pad", 'pad() works');
    
    $scalar->set("sub string");
    is($scalar->substr(4, 3), "str", 'substr() works');
    
    # Numeric operations
    $scalar->set(5);
    is($scalar->inc->get, 6, 'inc() works');
    is($scalar->dec->get, 5, 'dec() works');
    is($scalar->inc(3)->get, 8, 'inc(value) works');
    is($scalar->dec(2)->get, 6, 'dec(value) works');
    is($scalar->mul(2)->get, 12, 'mul() works');
    is($scalar->div(3)->get, 4, 'div() works');
    
    # Type checking and conversion
    $scalar->set("123");
    ok($scalar->is_numeric, 'is_numeric() works');
    is($scalar->to_number, 123, 'to_number() works');
    
    $scalar->set("");
    ok($scalar->is_empty, 'is_empty() works');
    
    $scalar->set("Hello");
    is($scalar->len, 5, 'length() works');

    # Test for the split() method:
    is_deeply([$scalar->set("a,b,c")->split(',')], ['a', 'b', 'c'], 'split() works correctly');

    # Assuming $scalar is a blessed object with necessary methods
    $scalar->set(5);  # 101 in binary

    is($scalar->_lshift_op(1)->get, 10, 'Left shift works');

    # Reset the value for the next test
    $scalar->set(5);

    is($scalar->_rshift_op(1)->get, 2, 'Right shift works');

    $scalar->set(5);

    # Bitwise AND
    is($scalar->_and_op(3)->get, 1, 'Bitwise AND works');

    # Bitwise OR
    is($scalar->_or_op(2)->get, 7, 'Bitwise OR works');

    # Reset value before XOR
    $scalar->set(5);

    # Bitwise XOR
    is($scalar->_xor_op(3)->get, 6, 'Bitwise XOR works');

    # Test for handling of large numbers:
    $scalar->set(1_000_000_000_000_000);
    is($scalar->inc->get, 1_000_000_000_000_001, 'Large number handling works');

    # Test for handling of very large strings:
    $scalar->set('a' x 1_000_000);
    is($scalar->len, 1_000_000, 'Can handle very large strings');

    # JSON serialization
    my $obj1 = {key => "value"};
    $scalar->to_json($obj1);
    is($scalar->get, JSON::XS->new->utf8->encode($obj1), 'to_json() works');
    is_deeply($scalar->from_json, $obj1, 'from_json() works');
    
    # More comprehensive tests for JSON handling:
    $scalar->set('{"key": "value"}');
    my $obj2 = $scalar->from_json();
    is_deeply($obj2, {key => "value"}, 'from_json() works with JSON string');
    $scalar->to_json({nested => {array => [1, 2, 3]}});
    like($scalar->get, qr/\{.*"nested".*:.*\{.*"array".*:.*\[.*1.*,.*2.*,.*3.*\].*\}.*\}/, 'to_json() handles nested structures');

    # Test for error handling with invalid JSON:
    throws_ok(
        sub {$scalar->set('{"invalid": json}')->from_json},
        qr//s,
        'from_json() throws error on invalid JSON'
    );

    # Regular expression operations
    $scalar->set("The quick brown fox");
    is_deeply([$scalar->match(qr/quick (\w+)/)], ['brown'], 'match() works');
    
    $scalar->subs(qr/quick/, "slow");
    is($scalar->get, "The slow brown fox", 'substitute() works');
    
    # Encryption and hashing
    $scalar->set("secret");
    my $encrypted = $scalar->encrypt("key")->get;
    isnt($encrypted, "secret", 'encrypt() changes the value');
    is($scalar->decrypt("key")->get, "secret", 'decrypt() restores the original value');
    # Test for error handling in encrypt() and decrypt() methods:
    throws_ok(
        sub { $scalar->encrypt("") },
        qr//s,
        'encrypt() throws error with empty key'
    );

    like($scalar->md5, qr/^[a-f0-9]{32}$/, 'md5() works');
    like($scalar->sha256, qr/^[a-f0-9]{64}$/, 'sha256() works');
    like($scalar->sha512, qr/^[a-f0-9]{128}$/, 'sha512() works');
    
    like($scalar->enc_base64->get, qr/^[A-Za-z0-9+\/]+={0,2}$/, 'encode_base64() works');
    is($scalar->dec_base64->get, "secret", 'decode_base64() works');
    
    # Atomic operations
    $scalar->set(10);
    is($scalar->fetch_add(5), 10, 'fetch_add() returns old value');
    is($scalar->get, 15, 'fetch_add() updates value');
    
    is($scalar->fetch_store(20), 15, 'fetch_store() returns old value');
    is($scalar->get, 20, 'fetch_store() updates value');
    
    $scalar = Sc(undef);
    ok($scalar->test_set(30), 'test_set() returns true for undefined value');
    is($scalar->get, 30, 'test_set() sets value when undefined');
    
    # Utility methods
    $scalar->set("Hello");
    my $clone = $scalar->clone;
    isnt($clone->_ref, $scalar->_ref, 'clone() creates new object');
    is($clone, $scalar, 'clone() preserves value');
    
    $scalar->set("Hello, World!");
    ok($scalar->contains("World"), 'contains() works');
    
    $scalar->replace_all("o", "0");
    is($scalar->get, "Hell0, W0rld!", 'replace_all() works');
    
    $scalar->set(1);
    ok($scalar->to_bool, 'to_bool() works');
    
    $scalar->set("hello");
    ok($scalar->eq_ignore_case("HELLO"), 'eq_ignore_case() works');
    
    $scalar->set("hello hello hello");
    is($scalar->count_occurrences("hello"), 3, 'count_occurrences() works');
    
    $scalar->set("This is a long string");
    $scalar->truncate(10);
    is($scalar->get, "This is...", 'truncate() works');
    
    $scalar->set("hello_world");
    $scalar->to_camel_case;
    is($scalar->get, "helloWorld", 'to_camel_case() works');
    $scalar->set("hello_world_example");
    $scalar->to_camel_case();
    is($scalar->get, "helloWorldExample", 'to_camel_case() works with multiple underscores');
    
    $scalar->set("helloWorld");
    $scalar->to_snake_case;
    is($scalar->get, "hello_world", 'to_snake_case() works');
    $scalar->set("helloWorldExample");
    $scalar->to_snake_case();
    is($scalar->get, "hello_world_example", 'to_snake_case() works with multiple capital letters');
    
    $scalar->set("hello world");
    $scalar->title_case();
    is($scalar->get, "Hello World", 'title_case() works');

    $scalar->set("valid123");
    ok($scalar->valid(qr/^[a-z]+\d+$/), 'valid() works with valid input');
    $scalar->set(";invalid!");
    ok(!$scalar->valid(qr/^[a-z]+\d+$/), 'valid() works with invalid input');
    
    # Test for the concat() method:
    $scalar->set("Hello");
    $scalar->concat(" World");
    is($scalar->get, "Hello World", 'concat() works correctly');

    # apply() method
    $scalar->set("hello");
    $scalar->apply(sub { uc $_[0] });
    is($scalar->get, "HELLO", 'apply() works');
    # Test for the apply() method with more complex scenarios:
    $scalar->set("hello");
    $scalar->apply(sub { uc($_[0]) . "!" });
    is($scalar->get, "HELLO!", 'apply() works with more complex transformation');

    # Additional methods
    $scalar->set("Hello");
    $scalar->append(" World");
    is($scalar->get, "Hello World", 'append() works');

    $scalar->prepend("Say: ");
    is($scalar->get, "Say: Hello World", 'prepend() works');

    $scalar->modify(sub { $_ = reverse });
    is($scalar->get, "dlroW olleH :yaS", 'modify() works');

    # Test for the merge() method:
    my $scalar1 = Sc(\(my $s1 = "Hello"));
    my $scalar2 = Sc(\(my $s2 = " World"));
    $scalar1->merge($scalar2);
    is($scalar1->get, " World", 'merge() works');

    # Test for the clear() method:
    $scalar->set("Not empty");
    $scalar->clear();
    ok($scalar->is_empty, 'clear() works');

    # Test for handling of undefined values:
    $scalar->set(undef);
    is($scalar->get, '', 'get() returns undef for undefined value');
    ok($scalar->is_empty, 'is_empty() returns true for undefined value');

    # Test for the type() method:
    $scalar->set(\1);
    is($scalar->type, "SCALAR", 'type() returns SCALAR for numbers');
    $scalar->set("string");
    is($scalar->type, "SCALAR", 'type() returns SCALAR for strings');
}

# Test overloaded operators
{
    my $a = Sc(\(my $x = 10));
    my $b = Sc(\(my $y = 5));

    is($a + $b, 15, 'Addition operator works');
    is($a - $b, 5, 'Subtraction operator works');
    is($a * $b, 50, 'Multiplication operator works');
    is($a / $b, 2, 'Division operator works');
    is($a % $b, 0, 'Modulo operator works');
    is($a ** $b, 100000, 'Exponentiation operator works');

    ok($a > $b, 'Greater than operator works');
    ok($a >= $b, 'Greater than or equal operator works');
    ok($b < $a, 'Less than operator works');
    ok($b <= $a, 'Less than or equal operator works');
    ok($a == $a, 'Equality operator works');
    ok($a != $b, 'Inequality operator works');

    $a->set(7);
    $b->set(3);
    is($a & $b, 3, 'Bitwise AND operator works');
    is($a | $b, 7, 'Bitwise OR operator works');
    is($a ^ $b, 4, 'Bitwise XOR operator works');
    is(~$a, -8, 'Bitwise NOT operator works');
    is($a << 1, 14, 'Left shift operator works');
    is($a >> 1, 3, 'Right shift operator works');

    $a->set("Hello");
    is($a x 3, "HelloHelloHello", 'String repeat operator works');
    $a .= " World";
    is($a, "Hello World", 'String concatenation operator works');

    $a->set(5);
    $a += 3;
    is($a, 8, '+= operator works');
    $a -= 2;
    is($a, 6, '-= operator works');
    $a *= 2;
    is($a, 12, '*= operator works');
    $a /= 3;
    is($a, 4, '/= operator works');
    $a %= 3;
    is($a, 1, '%= operator works');
    $a **= 3;
    is($a, 1, '**= operator works');

    $a->set(5);
    is(++$a, 6, 'Pre-increment operator works');
    is($a++, 7, 'Post-increment operator works');
    is($a, 7, 'Post-increment effect works');
    is(--$a, 6, 'Pre-decrement operator works');
    is($a--, 5, 'Post-decrement operator works');
    is($a, 5, 'Post-decrement effect works');
}

# Test lclass inherited functionality
{
    my $scalar = Sc(\(my $s = "test"));
    lives_ok(sub { $scalar->share_it }, 'share_it() method inherited from lclass');
    lives_ok(sub { $scalar->lock }, 'lock() method inherited from lclass');
    lives_ok(sub { $scalar->unlock }, 'unlock() method inherited from lclass');
    lives_ok(sub { eval{$scalar->debug("Test warning")} },'debug() method inherited from lclass');
    
    # Test event system
    $scalar->{caught} = 0;
    $scalar->on('trigger_test', sub { 
        my ($self,@args)=@_; $self->{caught}=$args[0];
    });
    eval { $scalar->try(sub { $scalar->trigger('trigger_test',1) },'test') };
    ok($scalar->{caught}, 'Trigger was caught by the registered handler');
}

# Test thread safety
SKIP: {
    eval { 
        require threads; threads->import; 
        require threads::shared; threads::shared->import; 
        1
    } or skip "threads not available", 3;
    
    # Test different ways to define shared variables
    my $s1 :shared = 0; my $shared1 = Sc(\$s1);
    my $shared2 = Sc(\(my $s2 :shared = 0));
    my $s3 = 0; my $shared3 = Sc(\$s3)->share_it;

   # Test shared1 independently
    {
        my @threads = map { threads->create(sub { for (1..1000) { $shared1->inc } }) } 1..5;
        $_->join for @threads;
        is($shared1->get, 5000, 'Thread-safe operations work correctly for shared scalar '.$shared1);
    }

    # Test shared2 independently
    {
        my @threads = map { threads->create(sub { for (1..1000) { $shared2->inc } }) } 1..5;
        $_->join for @threads;
        is($shared2->get, 5000, 'Thread-safe operations work correctly for shared scalar '.$shared2);
    }

    # Test shared3 independently
    {
        my @threads = map { threads->create(sub { for (1..1000) { $shared3->inc } }) } 1..5;
        $_->join for @threads;
        is($shared3->get, 5000, 'Thread-safe operations work correctly for shared scalar '.$shared3);
    }
    is($s1, 5000, 'Thread-safe operations work correctly for ' . ($shared1->{is_lightweight} ? 'unshared' : 'shared') . ' referenced scalar '.$s1);
    is($s2, 5000, 'Thread-safe operations work correctly for ' . ($shared2->{is_lightweight} ? 'unshared' : 'shared') . ' referenced scalar '.$s2);
    is($s3, 5000, 'Thread-safe operations work correctly for ' . ($shared3->{is_lightweight} ? 'unshared' : 'shared') . ' referenced scalar '.$s3);

    # Define and initialize shared variables
    $s1 = 0;
    $s2 = 0;
    $s3 = 0;

    # Shared counter to track completed threads
    my $counter :shared = 0;
    my $total_threads = 15; # Total number of threads

    # Function to create threads
    sub test_shared {
        my ($shared, $label) = @_;

        for (1..5) {
            threads->create(sub {
                for (1..1000) { $shared->inc }
                {
                    lock($counter);
                    $counter++;
                }
            })->detach;
        }
    }

    # Start tests with threads
    test_shared($shared1, 'shared1');
    test_shared($shared2, 'shared2');
    test_shared($shared3, 'shared3');

    # Wait for all threads to finish
    while (1) {
        sleep(1); # Adjust sleep as necessary
        {
            lock($counter);
        }
        last if $counter >= $total_threads; # Total increments expected
    }

    # Check results after all threads are done
    is($s1, 5000, 'Thread-safe operations work correctly for ' . ($shared1->{is_lightweight} ? 'unshared' : 'shared') . ' scalar '.$s1);
    is($s2, 5000, 'Thread-safe operations work correctly for ' . ($shared2->{is_lightweight} ? 'unshared' : 'shared') . ' scalar '.$s2);
    is($s3, 5000, 'Thread-safe operations work correctly for ' . ($shared3->{is_lightweight} ? 'unshared' : 'shared') . ' scalar '.$s3);
}

# Test error handling
{
    my $thrown = 0; local $SIG{__DIE__} = sub { $thrown++ };
    my $warned = 0; local $SIG{__WARN__} = sub { $warned++ };

    my $scalar = Sc(\(my $s = 10));
    my $error_caught = 0;
    $scalar->on('error_div', sub { $error_caught = 1 });
    eval { $scalar->try(sub { $scalar->div(0) }); };
    ok($thrown, "Division by zero error caught correctly: $error_caught : $thrown");
}

# Test performance impact of synchronization
SKIP: {
    eval { require Benchmark; 1 } or skip "Benchmark module not available", 1;

    my $shared_scalar = Sc(\(my $ss :shared = 0));
    my $unshared_scalar = Sc(\(my $us = 0));

    my $result = Benchmark::timethese(100000, {
        'shared' => sub { $shared_scalar->inc },
        'unshared' => sub { $unshared_scalar->inc },
    });

    my $shared_time = $result->{shared}->[1];
    my $unshared_time = $result->{unshared}->[1];

    ok($shared_time > $unshared_time, 'Shared operations have performance impact');
    diag("Shared time: $shared_time, Unshared time: $unshared_time");

    my $large_string = 'a' x 1_000_000;
    my $scalar = Sc(\(my $s = $large_string));

    my $results = Benchmark::timethese(1000, {
        'large_string_operation' => sub { $scalar->uc },
    });

    ok(1, 'Large string operation completed without error');
    diag("Time for large string operation: " . $results->{large_string_operation}->[1]);
}

#Test for memory usage (this is more of a benchmark than a test):
SKIP: {
    my $scalar = Sc(\(my $s = ""));
    eval { require Devel::Size; 1 } or skip "Devel::Size not available", 1;
    my $size_before = Devel::Size::total_size($scalar);
    $scalar->set('a' x 1_000_000);
    my $size_after = Devel::Size::total_size($scalar);
    ok($size_after > $size_before, 'Memory usage increases with large data');
}

# Test for memory leaks:4
SKIP: {
    eval { require Test::MemoryGrowth; 1 } or skip "Test::MemoryGrowth not available", 1;

    Test::MemoryGrowth::no_growth(sub {
        my $scalar = Sc(\(my $s = "test"));
        $scalar->set("new value");
        $scalar->uc();
        $scalar->reverse();
    }, 'No memory growth for basic operations');
}

done_testing();
