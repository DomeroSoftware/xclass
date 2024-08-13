use lib qw(../lib);
use strict;
use warnings;
use Test::More;
use Test::Exception;
use threads;
use threads::shared;

# Load the necessary modules

my @xclass_imports = qw(sclass aclass hclass cclass iclass gclass rclass tclass);
my @xclass_exports = qw(Sc Ac Hc Cc Ic Gc Rc Tc);
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
my @array_methods = qw(
    _array_deref_op _stringify_op _count_op _bool_op _neg_op _repeat_op _assign_op
    _eq_op _ne_op _cmp_op _spaceship_op _add_op _sub_op _mul_op 
    _bitwise_and_op _bitwise_or_op _bitwise_xor_op _bitwise_not
    _concat_assign_op _lshift_op _rshift_op
    push pop shift unshift len sort reverse splice join clear map grep reduce slice each
    first last sum min max unique compare_and_swap atomic_update iterator
);
my @hash_methods = qw(
    _stringify_op _numeric_op _bool_op _not_op _assign_op _eq_op _ne_op _cmp_op _spaceship_op
    _sub_assign_op _and_assign_op _or_assign_op _xor_assign_op get_default 
    delete exists keys values clear each map grep  merge size invert slice modify flatten unflatten
    deep_compare deep_map pairs update remove has_keys
);
my @code_methods = qw(
    _stringify_op _count_op _bool_op _eq_op _ne_op _cmp_op _spaceship_op 
    call benchmark wrap curry compose time profile bind create_thread detach join
    apply_code modify chain partial flip limit_args delay retry_with_backoff timeout hash_code
);
my @io_methods = qw(
    _io_deref_op _stringify_op _count_op _bool_op _neg_op _assign_op _eq_op _ne_op _cmp_op _spaceship_op
    io_type fileno binmode stat chmod ismod chown isown size open opendir is_open filename rename
    close closedir clear can_read read recv readdir readline readlink readpipe getc getline getlines
    can_write write send print printf say truncate seek seekdir tell telldir eof flush _check_flush
    autoflush flush_interval buffer encoding compression compression_level lock_io unlock_io
    copy_to unlink secure_delete atomic_operation accept listen
);
my @glob_methods = qw(
    _stringify_op _count_op _bool_op _assign_op namespace glob link_it hash_code exists
    SCALAR ARRAY HASH CODE IO merge
);
my @ref_methods = qw(
    _stringify_op _count_op _bool_op _assign_op _neg_op deref get_type merge size clear hash_code
);
my @thread_methods = qw(
    _stringify_op _numify_op _bool_op _eq_op _ne_op _spaceship_op _cmp_op _add_op _sub_op
    exists start detach stop status tid running join SCALAR ARRAY HASH CODE IO ext
    _handle_kill _handle_error should_stop yield sleep usleep _cleanup hash_code
);

my @lclass_methods = qw(
    _ref _shared share_it _init is_defined is_empty 
    sync lock unlock apply on trigger throw debug try 
    compare equals to_string serialize deserialize clone 
    xc sc ac hc cc ic gc rc tc
);

my @scalar_class = (@xclass_methods, @scalar_methods, @lclass_methods);
my @array_class = (@xclass_methods, @array_methods, @lclass_methods);
my @hash_class = (@xclass_methods, @hash_methods, @lclass_methods);
my @code_class = (@xclass_methods, @code_methods, @lclass_methods);
my @io_class = (@xclass_methods, @io_methods, @lclass_methods);
my @glob_class = (@xclass_methods, @glob_methods, @lclass_methods);
my @ref_class = (@xclass_methods, @ref_methods, @lclass_methods);
my @thread_class = (@xclass_methods, @thread_methods, @lclass_methods);

use_ok('xclass', @xclass_exports);

# Test basic class creation
subtest 'Basic SCALAR class creation' => sub {
    # Scalar Reference Class
    my $s = Sc(\(my $scalar = 10));
    isa_ok($s, 'sclass', 'Sc creates sclass object');
    can_ok($s, @scalar_class);
    $s = Sc(\(my $shared_scalar :shared = 10));
    isa_ok($s, 'sclass', 'Sc creates sclass object');
    can_ok($s, @scalar_class);
    ok($s->_shared, 'Sc creates Shared sclass object');
};
subtest 'Basic ARRAY class creation' => sub {
    # Array Reference Class
    my $a = Ac(\(my @array = (1, 2, 3)));
    isa_ok($a, 'aclass', 'Ac creates aclass object');
    can_ok($a, @array_class);
    $a = Ac(\(my @shared_array :shared = (1, 2, 3)));
    isa_ok($a, 'aclass', 'Ac creates aclass object');
    can_ok($a, @array_class);
    ok($a->_shared, 'Ac creates Shared aclass object');
};
subtest 'Basic HASH class creation' => sub {
    # Hash Reference Class
    my %hash = (a => 1);
    my %shared_hash :shared = (b => 2);
    my $h = Hc(\%hash);
    isa_ok($h, 'hclass', 'Hc creates hclass object');
    can_ok($h, @hash_class);
    $h = Hc(\%shared_hash);
    isa_ok($h, 'hclass', 'Hc creates hclass object');
    can_ok($h, @hash_class);
    ok($h->_shared, 'Hc creates Shared hclass object');
};
subtest 'Basic CODE class creation' => sub {
    # Code Reference Class
    my $c = Cc(sub { print "Hello" });
    isa_ok($c, 'cclass', 'Cc creates cclass object');
    can_ok($c, @code_class);
    $c = Cc(sub { print "Hello" })->share_it;
    isa_ok($c, 'cclass', 'Cc creates cclass object');
    can_ok($c, @code_class);
    ok($c->_shared, 'Cc creates Shared cclass object');
};
subtest 'Basic IO class creation' => sub {
    # IO Reference Class
    my $i = Ic(\*STDOUT);
    isa_ok($i, 'iclass', 'Ic creates iclass object');
    can_ok($i, @io_class);
    $i = Ic(\*STDOUT)->share_it;
    isa_ok($i, 'iclass', 'Ic creates iclass object');
    can_ok($i, @io_class);
    ok($i->_shared, 'Ic creates Shared iclass object');
};
subtest 'Basic GLOB class creation' => sub {
    # Glob Reference Class
    my $g = Gc('Space','Name');
    isa_ok($g, 'gclass', 'Gc creates gclass object');
    can_ok($g, @glob_class);
    $g = Gc('SharedSpace','Name')->share_it;
    isa_ok($g, 'gclass', 'Gc creates gclass object');
    can_ok($g, @glob_class);
    ok($g->_shared, 'Gc creates Shared iclass object');
};
subtest 'Basic REF class creation' => sub {
    # Reference Class
    my $r = Rc(\(my $ref = 10));
    isa_ok($r, 'rclass', 'Rc creates rclass object');
    can_ok($r, @ref_class);
    $r = Rc(\(my $shared_ref :shared = 10));
    isa_ok($r, 'rclass', 'Rc creates rclass object');
    can_ok($r, @ref_class);
    ok($r->_shared, 'Rc creates Shared rclass object');
};
subtest 'Basic THREAD class creation' => sub {
    # Thread Control Class
    my $ts = Tc(
        'Thread','Space',
        CODE => sub {
            # Thread code
        }
    );
    isa_ok($ts, 'tclass', 'Tc creates tclass object');
    can_ok($ts, @thread_class);
    my $tl = Tc(
        'Thread','Link',
        CODE => sub {
            # Thread code
        }
    )->link_it;
    isa_ok($tl, 'tclass', 'Tc creates tclass object');
    can_ok($tl, @thread_class);
    isa_ok(${${*Thread::Link}}, 'tclass', 'Tc creates Glob Namespace tclass object: '.ref(${${*Thread::Link}}) );
};

# Test thread creation and management
subtest 'Thread creation and management' => sub {
    my $count :shared = 0;
    my @array :shared = ();
    my %hash :shared = ();
    my $thread = Tc('TestSpace', 'TestThread',
        SCALAR => \$count,
        ARRAY => \@array,
        HASH => \%hash,
        CODE => sub {
            my ($self) = @_;
            ${$self->SCALAR->get}++ for 1..50;
            push @{$self->ARRAY->get}, 'done';
        }
    );

    isa_ok($thread, 'tclass', 'Tc creates tclass object');

    $thread->start->join;

    is(${$thread->SCALAR->get}, 50, 'Scalar value correctly updated');
    is(${${*TestSpace::TestThread}}, 50, 'Glob Scalar value correctly updated');
    is_deeply($thread->ARRAY->get, ['done'], 'Array correctly updated');
    is_deeply([@{*TestSpace::TestThread}], ['done'], 'Glob Array correctly updated');
};

# Test lclass functionality across all types
subtest 'lclass functionality' => sub {
    my $thrown = 0; local $SIG{__DIE__} = sub { $thrown++ };
    my $debug = 0; local $SIG{__WARN__} = sub { $debug++ };

    my $s = Sc( \(my $scalar = 0) )->share_it;
    my $a = Ac( \(my @array = ()) )->share_it;
    my $h = Hc( \(my %hash = ()) )->share_it;
    my $c = Cc( sub {} )->share_it;
    my $i = Ic( \*STDOUT )->share_it;
    my $g = Gc( "STDOUT" )->share_it;
    my $r = Rc( \(my $ref = 0) )->share_it;

    ok($s->_shared, "sclass object can be shared");
    ok($a->_shared, "aclass object can be shared");
    ok($h->_shared, "hclass object can be shared");
    ok($c->_shared, "cclass object can be shared");
    ok($i->_shared, "iclass object can be shared");
    ok($g->_shared, "gclass object can be shared");
    ok($r->_shared, "rclass object can be shared");

};

# Test _ref and _shared methods
subtest '_ref and _shared methods' => sub {
    my $scalar :shared = 42;
    my @array :shared = (1,2,3);
    my %hash :shared = (a=>1,b=>2,c=>3);
    my $code = sub { print "CODE\n" };
    my $io = \*STDOUT;

    my $s = Sc(\$scalar);
    my $a = Ac(\@array);
    my $h = Hc(\%hash);
    my $c = Cc($code);
    my $i = Ic($io);
    my $g = Gc('Glob','SpaceRef');
    my $r = Rc(\$scalar);
    my $t = Tc('Thread','SpaceRef');

    is($s->_ref, \$scalar, '_ref returns correct SCALAR reference');
    is($a->_ref, \@array, '_ref returns correct ARRAY reference');
    is($h->_ref, \%hash, '_ref returns correct HASH reference');
    is($c->_ref, $code, '_ref returns correct CODE reference');
    is($i->_ref, $io, '_ref returns correct IO reference');
    is(*{$g->_ref}, *{*Glob::SpaceRef}, '_ref returns correct GLOB reference');
    is($r->_ref, \$scalar, '_ref returns correct GLOB reference');
    is(*{$t->{glob}{glob}}, *{*Thread::SpaceRef}, '_ref returns correct Thread GLOB reference');

    ok($s->_shared, '_shared correctly identifies shared SCALAR data');
    ok($a->_shared, '_shared correctly identifies shared ARRAY data');
    ok($h->_shared, '_shared correctly identifies shared HASH data');
    #ok($c->_shared, '_shared correctly identifies shared CODE data');
    ok($i->_shared, '_shared correctly identifies shared IO data');
    #ok($g->_shared, '_shared correctly identifies shared GLOB data');
    ok($r->_shared, '_shared correctly identifies shared REF data');
    #ok($t->_shared, '_shared correctly identifies shared Thread GLOB data');
};

subtest 'object method tests' => sub {
    my $scalar = 42;
    my @array = (1,2,3);
    my %hash = (a=>1,b=>2,c=>3);
    my $code = sub { print "CODE\n" };
    my $io = \*STDOUT;
    my $ref = \$scalar;

    my $s = Sc(\$scalar)->share_it;
    my $a = Ac(\@array)->share_it;
    my $h = Hc(\%hash)->share_it;
    my $c = Cc($code)->share_it;
    my $i = Ic($io)->share_it;
    my $g = Gc('Glob','Space2',ARRAY=>[1,2,3])->share_it;
    my $r = Rc(\$ref)->share_it;
    my $t = Tc('Thread','Space2',HASH=>{a=>1,b=>2,c=>3})->share_it;

# Test share_it method
    ok($s->_shared, 'share_it correctly shares SCALAR data');
    ok($a->_shared, 'share_it correctly shares ARRAY data');
    ok($h->_shared, 'share_it correctly shares HASH data');
    #ok($c->_shared, 'share_it correctly shares CODE data');
    ok($i->_shared, 'share_it correctly shares IO data');
    #ok($g->_shared, 'share_it correctly shares GLOB data');
    #ok($r->_shared, 'share_it correctly shares REF data');
    #ok($t->_shared, 'share_it correctly shares Thread GLOB data');

# Test is_defined method
    ok($s->is_defined, 'SCALAR Class is defined');
    ok($a->is_defined, 'ARRAY Class is defined');
    ok($h->is_defined, 'HASH Class is defined');
    ok($c->is_defined, 'CODE Class is defined');
    ok($i->is_defined, 'IO Class is defined');
    ok($g->is_defined, 'GLOB Class is defined');
    ok($r->is_defined, 'REF Class is defined');
    ok($t->is_defined, 'Thread GLOB Class is defined');

# Test is_empty method
    ok(!$s->is_empty, 'SCALAR Class is not empty');
    #ok(!$a->is_empty, 'ARRAY Class is not empty');
    #ok(!$h->is_empty, 'HASH Class is not empty');
    ok(!$c->is_empty, 'CODE Class is not empty');
    ok(!$i->is_empty, 'IO Class is not empty');
    #ok(!$g->is_empty, 'GLOB Class is not empty');
    ok(!$r->is_empty, 'REF Class is not empty');
    #ok(!$t->is_empty, 'Thread GLOB Class is not empty');

    ok(Sc(\'')->is_empty, 'Empty scalar is considered empty');
    ok(Ac([])->is_empty, 'Empty array is considered empty');
    ok(Hc({})->is_empty, 'Empty hash is considered empty');
    ok(Cc()->is_empty, 'Empty code is considered empty');
    ok(Ic()->is_empty, 'Empty io is considered empty');
    #ok(Gc()->is_empty, 'Empty glob is considered empty');
    ok(Rc()->is_empty, 'Empty reference is considered empty');
    #ok(Tc()->is_empty, 'Empty thread glob is considered empty');

};

subtest 'stringify method tests' => sub {
    my $scalar = 42;
    my @array = (1,2,3);
    my %hash = (a=>1,b=>2,c=>3);
    my $code = sub { print "CODE\n" };
    my $io = \*STDOUT;
    my $ref = \$scalar;

    my $s = Sc(\$scalar);
    my $a = Ac(\@array);
    my $h = Hc(\%hash);
    my $c = Cc($code);
    my $i = Ic($io);
    my $g = Gc('Glob','Space3',ARRAY=>[1,2,3]);
    my $r = Rc(\$ref);
    my $t = Tc('Thread','Space3',HASH=>{a=>1,b=>2,c=>3});

# Test to_string method
    is($s->to_string, '42', 'to_string returns correct SCALAR value');
    is($a->to_string, '[1, 2, 3]', 'to_string returns correct ARRAY value');
    is($h->to_string, '{a => 1, b => 2, c => 3}', 'to_string returns correct HASH value');
    is($c->to_string, 'sub {
    use warnings;
    use strict;
    print("CODE\n");
}', 'to_string returns correct CODE value');
    is($i->to_string, 'IO handle (type: PIPE, fileno: 1)', 'to_string returns correct IO value'); #  : "Closed IO handle"
    is($g->to_string, 'GLOB Glob::Space3
  ARRAY: [1, 2, 3]
', 'to_string returns correct GLOB value');
    is($t->to_string, 'GLOB Thread::Space3
', 'to_string returns correct Thread GLOB value');

# Test serialize and deserialize methods
    my $ds = Sc()->deserialize($s->serialize);
    is_deeply($ds->get, $s->get, 'SCALAR Class Serialization and deserialization work correctly');
    my $da = Ac()->deserialize($a->serialize);
    is_deeply($da->get, $a->get, 'ARRAY Class Serialization and deserialization work correctly');
    my $dh = Hc()->deserialize($h->serialize);
    is_deeply($dh->get, $h->get, 'HASH Class Serialization and deserialization work correctly');
    #my $dc = Cc()->deserialize($c->serialize);
    #is($dc->to_string, $c->to_string, 'CODE Class Serialization and deserialization work correctly');
    #my $di = Ic()->deserialize($i->serialize);
    #is($di->to_string, $i->to_string, 'IO Class Serialization and deserialization work correctly');
    #my $dg = Gc('New','Glob',ARRAY=>[])->deserialize($g->serialize);
    #is($dg->to_string, $g->to_string, 'GLOB Class Serialization and deserialization work correctly');
    #my $dr = Rc()->deserialize($r->serialize);
    #is($dr->to_string, $r->to_string, 'REF Class Serialization and deserialization work correctly');
    #my $dt = Tc('New','Space',SCALAR=>"",HASH=>{})->deserialize($t->serialize);
    #is($dt->to_string, $t->to_string, 'Thread GLOB Class Serialization and deserialization work correctly');

# Test clone method
    my $cs = $s->clone;
    my $ca = $a->clone;
    my $ch = $h->clone;
    my $cc = $c->clone;
    #my $ci = $i->clone;
    my $cg = $g->clone;
    my $cr = $r->clone;
    my $ct = $t->clone;

    is($cs->get, $s->get, 'SCALAR Clone creates a copy with the same data');
    #is($ca->get, $a->get, 'ARRAY Clone creates a copy with the same data');
    #is($ch->get, $h->get, 'HASH Clone creates a copy with the same data');
    is($cc->get, $c->get, 'CODE Clone creates a copy with the same data');
    #is($ci->get, $i->get, 'IO Clone creates a copy with the same data');
    #is($cg->get, $g->get, 'GLOB Clone creates a copy with the same data');

    #isnt($cs, $s, 'SCALAR Clone is a different object');
    #isnt($ca, $a, 'ARRAY Clone is a different object');
    #isnt($ch, $h, 'HASH Clone is a different object');
    #isnt($cc, $c, 'CODE Clone is a different object');
    #isnt($ci, $i, 'IO Clone is a different object');
    isnt($cg, $g, 'GLOB Clone is a different object');


};

# Test error handling methods
subtest 'Test error handling methods' => sub {
    my $scalar = 42;
    my @array = (1,2,3);
    my %hash = (a=>1,b=>2,c=>3);
    my $code = sub { print "CODE\n" };
    my $io = \*STDOUT;
    my $ref = \$scalar;

    my $s = Sc(\$scalar)->share_it;
    my $a = Ac(\@array)->share_it;
    my $h = Hc(\%hash)->share_it;
    my $c = Cc($code)->share_it;
    my $i = Ic($io)->share_it;
    my $g = Gc('Glob2','Space',ARRAY=>[1,2,3])->share_it;
    my $r = Rc(\$ref)->share_it;
    my $t = Tc('Thread2','Space',HASH=>{a=>1,b=>2,c=>3})->share_it;

    my $thrown = 0; local $SIG{__DIE__} = sub { $thrown++ };
    my $warned = 0; local $SIG{__WARN__} = sub { $warned++ };

    eval { $s->throw("Test error") }; is($thrown, 1, 'SCALAR Class throw method works');
    eval { $s->debug("Test Warning") }; is($warned, 1, 'SCALAR Class debug method works');
    eval { $a->throw("Test error") }; is($thrown, 2, 'ARRAY Class throw method works');
    eval { $a->debug("Test Warning") }; is($warned, 2, 'ARRAY Class debug method works');
    eval { $h->throw("Test error") }; is($thrown, 3, 'HASH Class throw method works');
    eval { $h->debug("Test error") }; is($warned, 3, 'HASH Class debug method works');
    eval { $c->throw("Test error") }; is($thrown, 4, 'CODE Class throw method works');
    eval { $c->debug("Test error") }; is($warned, 4, 'CODE Class debug method works');
    eval { $i->throw("Test error") }; is($thrown, 5, 'IO Class throw method works');
    eval { $i->debug("Test error") }; is($warned, 5, 'IO Class debug method works');
    eval { $g->throw("Test error") }; is($thrown, 6, 'GLOB Class throw method works');
    eval { $g->debug("Test error") }; is($warned, 6, 'GLOB Class debug method works');
    eval { $r->throw("Test error") }; is($thrown, 7, 'REF Class throw method works');
    eval { $r->debug("Test error") }; is($warned, 7, 'REF Class debug method works');
    eval { $t->throw("Test error") }; is($thrown, 8, 'Thread Class throw method works');
    eval { $t->debug("Test error") }; is($warned, 8, 'Thread Class debug method works');

    lives_ok { $s->try(sub { 1 }) } 'SCALAR Class try method works for successful execution';
    eval { $s->try(sub { die 'Test error' }) }; is($thrown, 10, 'SCALAR Class try method works for failures');
    lives_ok { $a->try(sub { 1 }) } 'ARRAY Class try method works for successful execution';
    eval { $a->try(sub { die 'Test error' }) }; is($thrown, 12, 'ARRAY Class try method works for failures');
    lives_ok { $h->try(sub { 1 }) } 'HASH Class try method works for successful execution';
    eval { $h->try(sub { die 'Test error' }) }; is($thrown, 14, 'HASH Class try method works for failures');
    lives_ok { $c->try(sub { 1 }) } 'CODE Class try method works for successful execution';
    eval { $c->try(sub { die 'Test error' }) }; is($thrown, 16, 'CODE Class try method works for failures');
    lives_ok { $i->try(sub { 1 }) } 'IO Class try method works for successful execution';
    eval { $i->try(sub { die 'Test error' }) }; is($thrown, 18, 'IO Class try method works for failures');
    lives_ok { $g->try(sub { 1 }) } 'GLOB Class try method works for successful execution';
    eval { $g->try(sub { die 'Test error' }) }; is($thrown, 20, 'GLOB Class try method works for failures');
    lives_ok { $r->try(sub { 1 }) } 'REF Class try method works for successful execution';
    eval { $r->try(sub { die 'Test error' }) }; is($thrown, 22, 'REF Class try method works for failures');
    lives_ok { $t->try(sub { 1 }) } 'Thread Class try method works for successful execution';
    eval { $t->try(sub { die 'Test error' }) }; is($thrown, 24, 'Thread Class try method works for failures');

# Test event system (on and trigger methods)
    my $triggered = 0;
    $s->on('test_event', sub { $triggered++ }); $s->trigger('test_event');
    is($triggered, 1, 'SCALAR Event system works correctly');
    $a->on('test_event', sub { $triggered++ }); $a->trigger('test_event');
    is($triggered, 2, 'ARRAY Event system works correctly');
    $h->on('test_event', sub { $triggered++ }); $h->trigger('test_event');
    is($triggered, 3, 'HASH Event system works correctly');
    $c->on('test_event', sub { $triggered++ }); $c->trigger('test_event');
    is($triggered, 4, 'CODE Event system works correctly');
    $i->on('test_event', sub { $triggered++ }); $i->trigger('test_event');
    is($triggered, 5, 'IO Event system works correctly');
    $g->on('test_event', sub { $triggered++ }); $g->trigger('test_event');
    is($triggered, 6, 'GLOB Event system works correctly');
    $r->on('test_event', sub { $triggered++ }); $r->trigger('test_event');
    is($triggered, 7, 'REF Event system works correctly');
    $t->on('test_event', sub { $triggered++ }); $t->trigger('test_event');
    is($triggered, 8, 'Thread Glob Event system works correctly');

# Test lock and unlock methods
    $s->lock; $s->inc; $s->unlock;
    is($s->get, 43, 'SCALAR Class Lock and unlock work correctly');
    $a->lock; $a->push(4); $a->unlock;
    is_deeply($a->get, [4], 'ARRAY Class Lock and unlock work correctly');
    $h->lock; $h->set(d=>4); $h->unlock;
    is_deeply($h->get, {d=>4}, 'HASH Class Lock and unlock work correctly');
    $c->lock; $c->call(); $c->unlock;
    is($c->get, $c->{code}, 'CODE Class Lock and unlock work correctly');
    $i->lock; $i->io_type(); $i->unlock;
    is($i->io_type, 'PIPE', 'IO Class Lock and unlock work correctly');
    $g->lock; $g->ARRAY->push(4); $g->unlock;
    is_deeply($g->ARRAY->get, [4], 'GLOB Class Lock and unlock work correctly');
    $r->lock; ${${$r->get}}++; $r->unlock;
    is(${${$r->get}}, 44, 'REF Class Lock and unlock work correctly');
    $t->lock; $t->HASH->set(d=>4); $t->unlock;
    is_deeply($t->HASH->get, {d=>4}, 'Thread GLOB Class Lock and unlock work correctly');

# Test sync method
    $s->sync(sub { $s->inc });
    is($s->get, 45, 'SCALAR Class sync method works correctly');
    $a->sync(sub { $a->pop });
    is_deeply($a->get, [],'ARRAY Class sync method works correctly');
    $h->sync(sub { $h->delete('d') });
    is_deeply($h->get, {},'HASH Class sync method works correctly');
    $c->sync(sub { $c->hash_code });
    is($c->hash_code, $c->hash_code,'CODE Class sync method works correctly');
    $i->sync(sub { $i->fileno });
    is($i->fileno, $i->fileno,'IO Class sync method works correctly');
    $g->sync(sub { $g->namespace });
    is($g->namespace, 'Glob2::Space','GLOB Class sync method works correctly');
    $r->sync(sub { $r->get });
    is(${$r->get}, $ref,'REF Class sync method works correctly');
    $t->sync(sub { $t->namespace });
    is($t->namespace, 'Thread2::Space','Thread GLOB Class sync method works correctly');


};

subtest 'Other methods' => sub {
    my $scalar = 42;
    my @array = (1,2,3);
    my %hash = (a=>1,b=>2,c=>3);
    my $code = sub { print "CODE\n" };
    my $io = \*STDOUT;
    my $ref = \$scalar;

    my $s = Sc(\$scalar)->share_it;
    my $a = Ac(\@array)->share_it;
    my $h = Hc(\%hash)->share_it;
    my $c = Cc($code)->share_it;
    my $i = Ic($io)->share_it;
    my $g = Gc('Glob4','Space1',ARRAY=>[1,2,3])->share_it;
    my $r = Rc(\$ref)->share_it;
    my $t = Tc('Thread4','Space1',HASH=>{a=>1,b=>2,c=>3})->share_it;

# Test apply method
    $s->apply(sub { $_[0] * 2 });
    is($s->get, 84, 'apply method works correctly');

# Test memory_usage method
    ok($s->memory_usage > 0, 'memory_usage returns a positive value');

# Test comparison methods
#    my ($s1,$s2) = (Sc(\(my $scalar1 = 'a')), Sc(\(my $scalar2 = 'b')));
#    is($s1->compare($s2), -1, 'SCALAR Class compare method works correctly');
#    ok(!$s1->equals($s2), 'SCALAR Class equals method works correctly');
#
#    my ($a1,$a2) = (
#        Ac(\(my @array1 = ('a'))), 
#        Ac(\(my @array2 = ('b')))
#    );
#    is($a1->compare($a2), -1, 'ARRAY Class compare method works correctly');
#    ok(!$a1->equals($a2), 'ARRAY Class equals method works correctly');
#
#    my ($h1,$h2) = (
#        Hc(\(my %hash1 = ('a'=>1))), 
#        Hc(\(my %hash2 = ('b'=>2)))
#    );
#    is($h1->compare($h2), -1, 'HASH Class compare method works correctly');
#    ok(!$h1->equals($h2), 'HASH Class equals method works correctly');
#
#    my ($c1,$c2) = (
#        Cc(sub {return 1}), 
#        Cc(sub {return 2})
#    );
#    is($c1->compare($c2), -1, 'CODE Class compare method works correctly');
#    ok(!$c1->equals($c2), 'CODE Class equals method works correctly');
#
#    my ($i1,$i2) = (Ic(\*STDOUT), Ic(\*STDERR));
#    is($i1->compare($i2), -1, 'IO Class compare method works correctly');
#    ok(!$i1->equals($i2), 'IO Class equals method works correctly');
#
#    my ($g1,$g2) = (Gc('Glob1','Space'), Gc('Glob2','Space'));
#    is($g1->compare($g2), -1, 'GLOB Class compare method works correctly');
#    ok(!$g1->equals($g2), 'GLOB Class equals method works correctly');
#
#    my ($r1,$r2) = (Rc(\(my $ref1 = 'a')), Rc(\(my $ref2 = 'b')));
#    is($r1->compare($r2), -1, 'REF Class compare method works correctly');
#    ok(!$r1->equals($r2), 'REF Class equals method works correctly');
#
#    my ($t1,$t2) = (Gc('Thread1','Space'), Tc('Thread2','Space'));
#    is($t1->compare($t2), -1, 'Thread GLOB Class compare method works correctly');
#    ok(!$t1->equals($t2), 'Thread GLOB Class equals method works correctly');

};

done_testing();
