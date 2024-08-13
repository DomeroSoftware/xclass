#!/usr/bin/perl
use strict;
use warnings;

use lib qw(../lib);
use Test::More;
use Time::HiRes qw(time sleep usleep);
use threads;
use threads::shared;

my @xclass_methods = qw(new get set);
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
my @thread_class = (@xclass_methods, @thread_methods, @lclass_methods);

# Load the necessary modules
use_ok('xclass');

# Test xclass integration
{
    my $thread = Tc('TestSpace', 'TestThread');
    isa_ok($thread, 'tclass', 'Tc function creates tclass object');
    can_ok($thread, @thread_class);
}

# Test basic thread creation and management
{
    my $count :shared = 0;
    my $thread = Tc('TestSpace', 'BasicThread',
        SCALAR => \$count,
        ARRAY => [],
        HASH => {},
        CODE => sub {
            print STDOUT "Running Thread: ".threads->tid."\n";
            my ($self) = @_;
            ${${*TestSpace::BasicThread}}++ for 1..50;
            push @{*TestSpace::BasicThread}, 'done';
        }
    );

    $thread->start;
    $thread->stop;
    ok(!$thread->running, 'Thread not running after stop');
    
    is(${${*TestSpace::BasicThread}}, 50, 'Scalar value correctly updated');
    is_deeply([@{*TestSpace::BasicThread}], ['done'], 'Array correctly updated');
}

# Test shared data access and manipulation
{
    my $thread = Tc('TestSpace', 'SharedDataThread',
        SCALAR => 10,
        ARRAY => [],
        HASH => {},
        CODE => sub {
            my ($self) = @_;
            $self->SCALAR->inc(5);
            $self->ARRAY->push(4);
            $self->HASH->set('c'=>3);
        }
    );
    $thread->ARRAY([1, 2, 3]);
    $thread->HASH({ a => 1, b => 2 });
    $thread->start->join;
    
    is($thread->SCALAR->get, 15, 'Shared scalar correctly updated');
    is_deeply($thread->ARRAY->get, [1, 2, 3, 4], 'Shared array correctly updated');
    is_deeply($thread->HASH->get, { a => 1, b => 2, c => 3 }, 'Shared hash correctly updated');
}

# Test thread control methods
{
    my $thread = Tc('TestSpace', 'ControlThread',
        SCALAR => 0, 
        #HASH=>{},
        CODE => sub {
            my ($self) = @_;
            print STDOUT "Start: ".$self->status."\n";
            while (!$self->should_stop) {
                print STDOUT "Loop: ".$self->status."\n";
                $self->SCALAR->inc(1);
                $self->sleep(0.1);
            }
            print STDOUT "Stoped: ".$self->status('finished')."\n";
        }
    );

    $thread->start;
    sleep(0.5);
    $thread->stop;
    
    ok($thread->SCALAR->get > 0, 'Thread executed before stopping');
    ok(!$thread->running, 'Thread stopped successfully');
}

# Test detached threads
{
    my $thread = Tc('TestSpace', 'DetachedThread',
        SCALAR => 0,
        CODE => sub {
            my ($self) = @_;
            $self->SCALAR->inc(1) for 1..5;
        },
    );
    $thread->HASH({auto_detach => 1});
    $thread->start;
    ok($thread->detached, 'Thread is detached');
    
    # Wait a bit for the thread to finish
    sleep(1);
    print "Status: ".$thread->status.",".$thread->detached."\n";
    
    # We can't join a detached thread, so we just check if it's not running
    ok(!$thread->running, 'Detached thread finished running');
}

# Test namespace operators
{
    my $thread = Tc('TestSpace', 'OverloadThread');
    $thread->SCALAR(10);
    $thread->ARRAY([1, 2, 3]);
    $thread->HASH({ a => 1 });
    
    is(${*TestSpace::OverloadThread} + 5, 15, 'Numeric addition overload works');
    is("${*TestSpace::OverloadThread}", "10", 'String overload works');
    ok(!$thread, 'Boolean overload works');
    is_deeply([@{*TestSpace::OverloadThread}], [1, 2, 3], 'Array dereference overload works');
    is_deeply({%{*TestSpace::OverloadThread}}, { a => 1 }, 'Hash dereference overload works');
}

# Test high-resolution timing
{
    my $start_time = time;
    my $thread = Tc('TestSpace', 'TimingThread',
        CODE => sub {
            my ($self) = @_;
            $self->sleep(0.1);
            $self->usleep(100_000);  # 100 milliseconds
        }
    );
    
    $thread->start;
    $thread->join;
    my $elapsed_time = time - $start_time;
    
    ok($elapsed_time >= 0.2 && $elapsed_time < 0.3, 'High-resolution sleep functions work correctly');
}

# Test comparison methods
{
    my $thread1 = Tc('TestSpace', 'CompareThread1', SCALAR => 10);
    my $thread2 = Tc('TestSpace', 'CompareThread2', SCALAR => 10);
    my $thread3 = Tc('TestSpace', 'CompareThread3', SCALAR => 20);
    
    ok($thread1->equals($thread1), 'Equals method works for equal threads');
    ok(!$thread1->equals($thread2), 'Equals method works for unequal threads');
    
    is($thread1->compare($thread1), 0, 'Compare method works for equal threads');
    ok($thread1->compare($thread2) < 0, 'Compare method works for unequal threads');
    
    isnt($thread1->hash_code, $thread3->hash_code, 'Hash code differs for different threads');
}

# Test thread synchronization
{
    my $shared_counter :shared = 0;
    my @threads = map {
        Tc("TestSpace", "SyncThread$_",
            CODE => sub {
                my ($self) = @_;
                for (1..100) {
                    {
                        lock($shared_counter);
                        $shared_counter++;
                    }
                    $self->yield;
                }
            }
        )
    } 1..5;
    
    $_->start for @threads;
    $_->join for @threads;
    
    is($shared_counter, 500, 'Thread synchronization works correctly');
}

# Test circular reference handling
{
    my $thread1 = Tc('TestSpace', 'CircularThread1');
    my $thread2 = Tc('TestSpace', 'CircularThread2');
    
    $thread1->HASH({'other'=> $thread2});
    $thread2->HASH({'other'=> $thread1});
    
    ok(1, 'Circular references between threads do not cause immediate issues');
    
    undef $thread1;
    undef $thread2;
    
    ok(1, 'Threads with circular references can be destroyed');
}

# Test method wrapping
{
    my $wrap_log = '';
    my $thread = Tc('TestSpace', 'WrapThread',
        SCALAR => \(my $scalar :shared = 0),
        CODE => sub {
            my ($self) = @_;
            $self->SCALAR->inc(1);
        }
    )->on('before_start', sub {
        $wrap_log .= 'before_start;';
    })->on('after_stop', sub {
        $wrap_log .= 'after_stop;';
    });
    
    $thread->start;
    $thread->stop;
    
    is($wrap_log, 'before_start;after_stop;', 'Method wrapping works correctly');
}

# Test thread pool implementation
{
    my $task_queue = Ac([])->share_it;
    my $results = Hc({})->share_it;
    
    sub create_worker {
        my ($id) = @_;
        my $worker = Tc("TestSpace", "Worker$id",
            CODE => sub {
                my ($self) = @_;
                while (!$self->should_stop) {
                    if (
                        (defined $self->HASH->get('task_queue')) &&
                        ($self->HASH->get('task_queue')->len > 0) && 
                        (my $task = $self->HASH->get('task_queue')->shift)
                    ) {
                        my $result = $task * 2;
                        $self->HASH->get('results')->set($task => $result);
                    } else {
                        $self->sleep(0.1);
                    }
                }
            }
        );
        $worker->HASH({
            task_queue => $task_queue,
            results => $results,
        });
        return $worker
    }
    
    my @workers = map { create_worker($_) } 1..3;
    $_->start->detach for @workers;
    
    $task_queue->push($_) for 1..10;
    
    while ($task_queue->len > 0 || scalar @{[$results->keys]} < 10) {
        print STDOUT "Queue: ".$task_queue->len." Done: ".join(', ',@{[$results->keys]})."\n";
        sleep 0.1;
    }
    
    is($results->size, 10, 'Thread pool processed all tasks');
    is_deeply(
        [sort { $a <=> $b } map { $results->get($_) } $results->keys],
        [2, 4, 6, 8, 10, 12, 14, 16, 18, 20],
        'Thread pool produced correct results'
    );
}

done_testing();
