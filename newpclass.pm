################################################################################
# pclass.pm - Advanced Thread Pool Management Class for xclass Ecosystem
#
# This class provides a robust and feature-rich interface for managing a pool
# of threads within a given namespace, utilizing tclass for individual thread
# control. It offers comprehensive thread pool capabilities, including:
#
# - Dynamic thread creation and management within a namespace
# - Task queue management and distribution
# - Pool size control and optimization
# - Thread lifecycle management (creation, assignment, termination)
# - Integrated error handling and reporting
# - Performance monitoring and statistics
#
# Key Features:
# - Seamless integration with xclass ecosystem, particularly tclass
# - Thread-safe operations using lclass synchronization
# - Namespace-based pool organization
# - Dynamic task distribution and load balancing
# - Configurable pool size and growth policies
# - Comprehensive error handling and reporting
# - Performance metrics and pool health monitoring
#
# Author: OnEhIppY, Domero Software
# Copyright: (C) 2024 OnEhIppY, Domero Software
#
# Dependencies:
# - v5.38 or higher
# - xclass (core package)
# - lclass (for utility methods and thread-safe operations)
# - tclass (for individual thread management)
# - Scalar::Util (for type checking)
################################################################################

use v5.38;
use strict;
use warnings;

use xclass;
use Scalar::Util qw(blessed);

BEGIN {
    xclass::register('POOL', 'pclass');
}

class pclass v2.0.0 {
    use lclass qw(:pool);

    # Fields
    field $is = 'pool';
    field $namespace :param;
    field $min_threads :param = 1;
    field $max_threads :param = 10;
    field $threads = {};
    field $task_queue = [];
    field $is_running :shared = 0;

    # Constructor
    method new($class: $namespace, %options) {
        my $self = bless {
            namespace => $namespace,
            %options
        }, $class;

        return $self->try(sub {
            $self->throw("Namespace must be provided") unless $namespace;
            $self->_init(%options);
            $self->_initialize_pool();
            return $self;
        }, 'new', $class, $namespace, \%options);
    }

    # Initialize the thread pool
    method _initialize_pool() {
        for my $i (1..$min_threads) {
            $self->_create_thread("${namespace}::thread_$i");
        }
    }

    # Create a new thread
    method _create_thread($name) {
        return $self->sync(sub {
            my $thread = tclass->new($namespace, $name, 
                scalar => shared_clone({}),
                array => shared_clone([]),
                hash => shared_clone({}),
                code => sub {
                    my ($self) = @_;
                    while (!$self->should_stop()) {
                        if (my $task = $self->get_shared('ARRAY')->shift) {
                            eval { $task->() };
                            if ($@) {
                                $self->get_shared('HASH')->{last_error} = $@;
                            }
                        } else {
                            $self->sleep(0.1);
                        }
                    }
                }
            );
            $threads->{$name} = $thread;
            $thread->start();
            return $thread;
        }, '_create_thread', $name);
    }

    # Add a task to the pool
    method add_task($task) {
        return $self->sync(sub {
            push @$task_queue, $task;
            $self->_distribute_tasks();
            return $self;
        }, 'add_task', $task);
    }

    # Distribute tasks to available threads
    method _distribute_tasks() {
        return $self->sync(sub {
            while (my $task = shift @$task_queue) {
                my $assigned = 0;
                for my $thread (values %$threads) {
                    if ($thread->get_shared('ARRAY')->is_empty) {
                        $thread->get_shared('ARRAY')->push($task);
                        $assigned = 1;
                        last;
                    }
                }
                if (!$assigned && scalar(keys %$threads) < $max_threads) {
                    my $new_thread_name = "${namespace}::thread_" . (scalar(keys %$threads) + 1);
                    my $new_thread = $self->_create_thread($new_thread_name);
                    $new_thread->get_shared('ARRAY')->push($task);
                }
                last if !$assigned;
            }
        }, '_distribute_tasks');
    }

    # Start the thread pool
    method start() {
        return $self->sync(sub {
            return if $is_running;
            $is_running = 1;
            $_->start() for values %$threads;
            return $self;
        }, 'start');
    }

    # Stop the thread pool
    method stop() {
        return $self->sync(sub {
            return unless $is_running;
            $is_running = 0;
            $_->stop() for values %$threads;
            return $self;
        }, 'stop');
    }

    # Get the number of active threads
    method active_thread_count() {
        return $self->sync(sub {
            return scalar(grep { $_->is_running() } values %$threads);
        }, 'active_thread_count');
    }

    # Get the current task queue size
    method task_queue_size() {
        return $self->sync(sub {
            return scalar(@$task_queue);
        }, 'task_queue_size');
    }

    # Get pool statistics
    method get_stats() {
        return $self->sync(sub {
            return {
                active_threads => $self->active_thread_count(),
                total_threads => scalar(keys %$threads),
                queued_tasks => $self->task_queue_size(),
                is_running => $is_running,
            };
        }, 'get_stats');
    }

    # Cleanup and terminate all threads
    method cleanup() {
        return $self->sync(sub {
            $self->stop();
            %$threads = ();
            @$task_queue = ();
            return $self;
        }, 'cleanup');
    }

    # Destructor
    method DESTRUCT() {
        return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
        $self->try(sub {
            $self->cleanup();
            $self->warning("Destroying pclass object for namespace $namespace");
        }, 'DESTRUCT');
    }
}

1;

################################################################################
# EOF pclass.pm (C) 2024 OnEhIppY, Domero Software
################################################################################
