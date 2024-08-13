#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(../lib);
use Test::More;

# Load the xclass module
use_ok('xclass') or BAIL_OUT("Cannot load xclass module");

# Test xclass core functionality
subtest 'xclass Core Functionality' => sub {

    # Test version
    ok(defined $xclass::VERSION, 'xclass version is defined');
    
    # Test registration
    Sc();
    ok(xclass::registered('SCALAR'), 'SCALAR type is registered');
    Ac();
    ok(xclass::registered('ARRAY'), 'ARRAY type is registered');
    Hc();
    ok(xclass::registered('HASH'), 'HASH type is registered');
    Cc();
    ok(xclass::registered('CODE'), 'CODE type is registered');
    Ic();
    ok(xclass::registered('IO'), 'IO type is registered');
    Gc();
    ok(xclass::registered('GLOB'), 'GLOB type is registered');
    Rc();
    ok(xclass::registered('REF'), 'REF type is registered');
    Tc('Space','Name');
    ok(xclass::registered('THREAD'), 'THREAD type is registered');

    # Test class retrieval
    is(xclass::class('SCALAR'), 'sclass', 'SCALAR class is sclass');
    is(xclass::class('ARRAY'), 'aclass', 'ARRAY class is aclass');
    is(xclass::class('HASH'), 'hclass', 'HASH class is hclass');
    is(xclass::class('CODE'), 'cclass', 'CODE class is cclass');
    is(xclass::class('IO'), 'iclass', 'IO class is iclass');
    is(xclass::class('GLOB'), 'gclass', 'GLOB class is gclass');
    is(xclass::class('REF'), 'rclass', 'REF class is rclass');
    is(xclass::class('THREAD',"Space","Name"), 'tclass', 'THREAD class is tclass');

    # Test instance creation
    my $scalar = Sc("test");
    isa_ok($scalar, 'sclass', 'Sc creates sclass instance');

    my $array = Ac([1, 2, 3]);
    isa_ok($array, 'aclass', 'Ac creates aclass instance');

    my $hash = Hc({a => 1, b => 2});
    isa_ok($hash, 'hclass', 'Hc creates hclass instance');

    my $code = Cc(sub { 1 });
    isa_ok($code, 'cclass', 'Cc creates cclass instance');

    my $io = Ic(\*STDOUT);
    isa_ok($io, 'iclass', 'Ic creates iclass instance');

    my $glob = Gc(\*STDOUT);
    isa_ok($glob, 'gclass', 'Gc creates gclass instance');

    my $ref = Rc(\$scalar);
    isa_ok($ref, 'rclass', 'Rc creates rclass instance');

    # Test Xc conversion
    my $xc_scalar = Xc("test");
    isa_ok($xc_scalar, 'sclass', 'Xc converts scalar to sclass');

    my $xc_array = Xc([1, 2, 3]);
    isa_ok($xc_array, 'aclass', 'Xc converts array to aclass');

    my $xc_hash = Xc({a => 1, b => 2});
    isa_ok($xc_hash, 'hclass', 'Xc converts hash to hclass');

};


done_testing();
