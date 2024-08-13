#!/usr/bin/env perl

use v5.38;
use strict;
use warnings;
use threads;
use Thread::Queue;

# Include the directory containing lclass.pm in @INC
use lib '../lib';
use lclass;

# Create a shared resource
my $shared_counter :shared = 0;

# Create an object that uses lclass
package MySharedObject {
    use lclass;

    sub new {
        my $class = shift;
        return bless {
            lock_semaphore => Thread::Semaphore->new(1),
            global_lock_owner => undef,
            global_lock_count => 0,
            thread_local_lock_count => {},
            thread_local_lock_id => {},
        }, $class;
    }

    sub increment_counter {
        my $self = shift;
        $self->locked(sub {
            $shared_counter++;
            print "Thread ", threads->tid(), " incremented counter to $shared_counter\n";
            sleep(rand(2));  # Simulate some work
        });
    }
}

my $shared_object = MySharedObject->new();

# Create a queue for thread synchronization
my $queue = Thread::Queue->new();

# Create multiple threads
my @threads = map {
    threads->create(sub {
        for (1..5) {
            $shared_object->increment_counter();
        }
        $queue->enqueue(1);  # Signal that the thread is done
    });
} 1..3;

# Wait for all threads to finish
$queue->dequeue() for 1..3;

# Join all threads
$_->join for @threads;

print "Final counter value: $shared_counter\n";
