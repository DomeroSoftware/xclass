#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;

use xclass;
use threads;
use threads::shared;
use Time::HiRes qw(sleep);

# Initialize shared data
my $counter :shared = 0;
my @items :shared;
my $status :shared = 'running';

# Wrap shared data in xclass objects
my $shared_counter = Sc(\$counter);
my $shared_items = Ac(\@items);
my $shared_status = Sc(\$status);

sub run_app {
    my $threads = Ac([]);

    # Create worker threads
    for my $i (1..3) {
        my $thread = Tc('MyApp', "Worker$i",
            SCALAR => 0,
            ARRAY => [],
            HASH => { worker_id => $i },
            CODE => sub {
                my ($self) = @_;
                while (!$self->should_stop && $shared_status->get eq 'running') {
                    if (my $item = $shared_items->shift) {
                        # Process item
                        my $processed = uc($item);
                        $shared_counter->inc(1);
                        $self->SCALAR->inc(1);
                        say "Thread ", $self->tid, " processed: $processed (global count: ", $shared_counter->get, 
                            ", local count: ", $self->SCALAR->get, ")";
                    }
                    $self->sleep(0.5);
                }
                $self->status('finished');
            },
            on_error => sub {
                my ($self, $error) = @_;
                warn "Error in thread ", $self->tid, ": $error";
            },
            on_kill => sub {
                my ($self) = @_;
                say "Thread ", $self->tid, " is being killed";
            }
        );
        $threads->push($thread->start);
        
        # Optionally detach some threads to demonstrate different scenarios
        $thread->detach if $i % 2 == 0;
    }

    my $input = Ic(\*STDIN);

    # Main application loop
    while ($shared_status->get eq 'running') {
        $input->can_read(0.1, sub {
            my ($input) = @_;
            my $line = $input->readline;
            chomp $line;
            if ($line eq 'quit') {
                $shared_status->set('stopping');
            } else {
                $shared_items->push($line);
            }
        });
    }

    # Stop all threads (this will handle both detached and non-detached threads)
    $_->stop for @{$threads->get};

    say "Application finished. Final counter: ", $shared_counter->get;
    say "Processed items: ", $shared_items->join(', ');
}

# Run the application
run_app();

__END__

=head1 NAME

xclass_example.pl - Comprehensive demonstration of the xclass ecosystem with tclass

=head1 DESCRIPTION

This script demonstrates the advanced usage of various xclass components:

=over 4

=item * threads and threads::shared for creating shared variables

=item * Sc (sclass) for thread-safe scalar operations on shared scalars

=item * Ac (aclass) for thread-safe array operations on shared arrays

=item * Tc (tclass) for advanced thread management, demonstrating:
    - Direct incorporation of worker code
    - Proper use of should_stop for graceful termination
    - Handling of both detached and non-detached threads
    - Use of on_error and on_kill callbacks

=item * Ic (iclass) for non-blocking I/O operations

=back

=head1 USAGE

Run the script and enter text at the prompt. Enter 'quit' to exit.

=cut
