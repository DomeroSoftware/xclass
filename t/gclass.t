#!/usr/bin/perl
use strict;
use warnings;

use lib qw(../lib);
use Test::More;
use Test::Exception;
use threads;
use threads::shared;
use Time::HiRes qw(usleep);

my @xclass_methods = qw(new get set);
my @glob_methods = qw(
    _stringify_op _count_op _bool_op _assign_op namespace glob link_it hash_code exists
    SCALAR ARRAY HASH CODE IO merge
);
my @lclass_methods = qw(
    _ref _shared share_it _init is_defined is_empty 
    sync lock unlock apply on trigger throw debug try 
    compare equals to_string serialize deserialize clone 
    xc sc ac hc cc ic gc rc tc
);
my @glob_class = (@xclass_methods, @glob_methods, @lclass_methods);

# Load the necessary modules
use_ok('xclass');

# Test xclass integration
{
    my $glob = Xc(\*main);
    isa_ok($glob, 'gclass', 'Xc creates a gclass object: '.ref($glob));
    can_ok($glob, @glob_class);

    my $glob2 = Gc('main', 'test_glob');
    isa_ok($glob2, 'gclass', 'Gc creates a gclass object');

    is($glob2->{space}, 'main', 'Gc sets correct space');
    is($glob2->{name}, 'test_glob', 'Gc sets correct name');
}

# Test constructor and basic methods
{
    my $glob = gclass->new('test', 'glob');
    isa_ok($glob, 'gclass', 'Constructor creates a gclass object');
    can_ok($glob, @glob_class);

    ok($glob->exists, 'GLOB exists after creation');
    is($glob->{space}, 'test', 'Constructor sets correct space');
    is($glob->{name}, 'glob', 'Constructor sets correct name');

    my $glob_ref = $glob->get;
    is(ref($glob_ref), 'GLOB', 'get returns a GLOB reference');

    my $new_glob = \*STDOUT;
    $glob->set($new_glob);
    is($glob->get, $new_glob, 'set changes the GLOB reference');
}

# Test GLOB component methods
{
    my $glob = gclass->new('main', 'component_test');

    # SCALAR
    $glob->SCALAR(42);
    is($glob->SCALAR->get, 42, 'SCALAR get/set works');

    # ARRAY
    $glob->ARRAY([1, 2, 3]);
    is_deeply($glob->ARRAY->get, [1, 2, 3], 'ARRAY get/set works');

    # HASH
    $glob->HASH({a => 1, b => 2});
    is_deeply($glob->HASH->get, {a => 1, b => 2}, 'HASH get/set works');

    # CODE
    my $code = sub { return "Hello" };
    $glob->CODE($code);
    is($glob->CODE->call, "Hello", 'CODE get/set works');

    # IO
    $glob->IO(\*STDOUT);
    is(*{$glob->IO->get}, *STDOUT, 'IO get/set works');
}

# Test overloaded operators
{
    my $glob = gclass->new('overload', 'test');

    # Scalar dereference
    $glob->SCALAR(42);
    is($overload::test, 42, 'Scalar dereference works: ');

    # Array dereference
    $glob->ARRAY([1, 2, 3]);
    is_deeply([@overload::test], [1, 2, 3], 'Array dereference works');

    # Hash dereference
    $glob->HASH({a => 1, b => 2});
    is_deeply({%overload::test}, {a => 1, b => 2}, 'Hash dereference works');

    # Code dereference
    $glob->CODE(sub { return "Hello" });
    is(&overload::test(), "Hello", 'Code dereference works');

    # IO dereference
    $glob->IO(\*STDOUT);
    is(*{$glob->IO->get}, *STDOUT, 'IO dereference works');

    # Stringification
    $glob->SCALAR("Test String");
#    is("$glob", "GLOB overload::test
#  SCALAR: 42
#  ARRAY: [1, 2, 3]
#  HASH: {a => 1, b => 2}
#  CODE: {
#    use warnings;
#    use strict;
#    (return 'Hello');
#}
#  IO: IO handle (type: PIPE, fileno: 1)
#", 'Stringification works');

    # Numeric context
    $glob->SCALAR(42);
    is(0 + $glob, 42, 'Numeric context works');

    # Boolean context
    ok($glob, 'Boolean context works');

    # Assignment
    my $new_glob = gclass->new('main', 'new_glob');
    $new_glob = $glob;
    is($new_glob->SCALAR->get, 42, 'Assignment works');
}

# Test advanced methods
{
    my $glob1 = gclass->new('main', 'glob1',
        SCALAR => 42,
        ARRAY => [1, 2, 3],
        HASH => {a => 1, b => 2}
    );

    my $clone = $glob1->clone('glob1_clone');
    isa_ok($clone, 'gclass', 'clone creates a new gclass object');
    is($clone->SCALAR->get, 42, 'clone copies SCALAR');
    is_deeply($clone->ARRAY->get, [1, 2, 3], 'clone copies ARRAY');
    is_deeply($clone->HASH->get, {a => 1, b => 2}, 'clone copies HASH');

    my $glob2 = gclass->new('main', 'glob2',
        SCALAR => 100,
        ARRAY => [4, 5, 6],
        HASH => {c => 3, d => 4}
    );

    $glob1->merge($glob2);
    is($glob1->SCALAR->get, 100, 'merge updates SCALAR');
    is_deeply($glob1->ARRAY->get, [1, 2, 3, 4, 5, 6], 'merge updates ARRAY');
    is_deeply($glob1->HASH->get, {a => 1, b => 2, c => 3, d => 4}, 'merge updates HASH');

    ok($glob1->equals($glob1), "equals returns true for same object");
    ok(!$glob1->equals($glob2), "equals returns false for different objects");

    is($glob2->compare($glob1), 1, 'compare works correctly');

    my $hash_code = $glob1->hash_code;
    ok($hash_code, 'hash_code returns a value');
    isnt($glob1->hash_code, $glob2->hash_code, 'hash_code differs for different objects');
}

# Test error handling
{
    my $thrown = 0;
    my @thrown_error = "";
    local $SIG{__DIE__} = sub { $thrown++; @thrown_error = @_; };
    
    my $warned = 0;
    my @warned_error = "";
    local $SIG{__WARN__} = sub { $warned++; @warned_error = @_; };

    my $glob = gclass->new('main', 'error_test');

    eval { $glob->throw("Test error", 'TEST_ERROR') };
    ok($thrown_error[0] =~ /Test error/gs, 'throw message works');
    ok($thrown == 1, 'throw count works');
    eval { $glob->set("Not a GLOB") };
    is($thrown, 4, 'Wrong Glob Reference throw works');
#    is($warned, 1, 'warn method works');
}

# Test event system
{
    my $glob = gclass->new('main', 'event_test');
    my $event_triggered = 0;

    $glob->on('after_SCALAR', sub {
        my ($self, $code, $args) = @_;
        $event_triggered = $args->[0]
    });

    $glob->SCALAR(42);
    is($event_triggered, 42, 'Event system triggers on change');
}

# Test lclass inherited functionality
{
    my $glob = gclass->new('main', 'lclass_test');

    # Test sync method
    $glob->sync(sub {
        $glob->SCALAR(42);
    });
    is($glob->SCALAR->get, 42, 'sync method works');

    # Test try method
    my $result = $glob->try(sub {
        return $glob->SCALAR->get * 2;
    }, 'test_try');
    is($result, 84, 'try method works');

    # Test debug method
    {
        my $debugged = 0;
        local $gclass::DEBUG = 1;
        local $SIG{__WARN__} = sub { $debugged++ };
        $glob->debug("Test debug");
        is($debugged, 1, 'debug method works');
    }
}

# Test xclass type conversion
{
    my $glob = gclass->new('main', 'conversion_test');
    $glob->SCALAR(42);
    $glob->ARRAY([1, 2, 3]);
    $glob->HASH({a => 1, b => 2});
    $glob->CODE(sub {return 1});
    $glob->IO(\*STDOUT);

    my $scalar = $glob->SCALAR;
    isa_ok($scalar, 'sclass', 'SCALAR returns sclass object');

    my $array = $glob->ARRAY;
    isa_ok($array, 'aclass', 'ARRAY returns aclass object');

    my $hash = $glob->HASH;
    isa_ok($hash, 'hclass', 'HASH returns hclass object');

    my $code = $glob->CODE;
    isa_ok($code, 'cclass', 'CODE returns cclass object');

    my $io = $glob->IO;
    isa_ok($io, 'iclass', 'IO returns iclass object');
}

# Test destructor
{
    my $glob = gclass->new('main', 'destructor_test');
    $glob->SCALAR(42);
    $glob->ARRAY([1, 2, 3]);
    $glob->HASH({a => 1, b => 2});

    undef $glob;

    ok(!defined $glob, 'Object properly destroyed');
}

# Test thread safety
{
    my $done:shared = 0;
    my $shared_glob = gclass->new(
        'Shared', 'Glob',
        SCALAR => 0,
        ARRAY => [],
    )->share_it;

    for (1..10) {
        threads->create(sub {
            for (1..10) {
                usleep(100*(rand()*10));
                $shared_glob->ARRAY->push(threads->tid.':'.(${*Shared::Glob}++));
            }
            $done++
        })->detach;
    };

    while ($done != 10) {
        usleep(1000);
    }

    my $cnt:shared = 0;
    my @arr:shared = ();

    for (1..10) {
        threads->create(sub {
            for (1..10) {
                usleep(100*(rand()*10));
                push @arr, threads->tid.':'.($cnt++);
            }
            $done++
        })->detach;
    };

    while ($done != 20) {
        usleep(1000);
    }

    is(${*Shared::Glob}, 100, 'Thread-safe operations work correctly');
    is($cnt, 100, 'Thread-safe operations work correctly');
}

done_testing();
