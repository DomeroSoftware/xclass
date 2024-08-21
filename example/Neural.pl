
use lib qw(../lib .);
use strict;
use warnings;
use xclass;
use threads;
use threads::shared;
use Storable qw(store retrieve);

$| = 1;

sub initialize_weights {
    my $nn = ${${*Neural::Network}};  # Access the main neural network object
    my @layers = @{$nn->HASH->get('training')->{layers}};
    my @weights;

    for my $i (0 .. $#layers - 1) {
        my @layer;
        for my $j (0 .. $layers[$i+1] - 1) {
            my @neuron = map { rand() * 2 - 1 } 0 .. $layers[$i] + 1;  # +1 for bias
            push @layer, \@neuron;
        }
        push @weights, \@layer;
    }

    $nn->ARRAY->set(\@weights);
    #print STDOUT $nn->ARRAY->serialize."\n";
}

sub load_weights {
    my $nn = ${${*Neural::Network}};  # Access the main neural network object
    my $base_file = $nn->HASH->get->{base_file};
    my $filename = "./${base_file}.dat";
    open my $fh, '<', $filename or die "Could not open file '$filename' $!";
    my $json = do { local $/; <$fh> };
    close $fh;
    $nn->ARRAY->deserialize($json)->share_it;
    print "Loaded weights from $filename.\n";
}

sub save_weights {
    my $nn = ${${*Neural::Network}};  # Access the main neural network object
    my $base_file = $nn->HASH->get->{base_file};
    my $filename = "./${base_file}.dat";
    open my $fh, '>', $filename or die "Could not open file '$filename' $!";
    print $fh $nn->ARRAY->serialize;
    close $fh;
    print "Saved weights to $filename.\n";
}

sub network_function {
    my $nn = ${${*Neural::Network}};  # Access the main neural network object
    
    #print STDOUT $nn->HASH->serialize."\n";

    my $base_file = $nn->HASH->get->{base_file};

    my $training_code = "./${base_file}.pl";
    require $training_code;

    # Initialize or load weights
    my $weights_file = "./${base_file}.dat";
    if (-e $weights_file && !$nn->HASH->get('random_init')) {
        load_weights();
    } else {
        initialize_weights();
    }

    print "Initialized weights:\n";
    $nn->ARRAY->each_with_index(sub {
        my ($layer_weights, $layer_index) = @_;
        print STDOUT "Layer $layer_index weights:\n";
        for my $neuron_index (0 .. $#$layer_weights) {
            print STDOUT "  Neuron $neuron_index: " . join(", ", @{$layer_weights->[$neuron_index]}) . "\n";
        }
    });

    # Create and run worker threads
    my $num_threads = $nn->HASH->get('num_threads') // 4;
    my @workers = map { Tc('Neural', "Worker$_", CODE => \&worker_function) } 1..$num_threads;

    $_->start for @workers;
    $_->join for @workers;

    # Save weights after training
    save_weights();

    # Test the trained network
    my $training = $nn->HASH->get('training');
    for (my $i=0; $i <= $#{$training->{data}}; $i++) {
        my ($func, $input, $expected) = @{$training->{data}->[$i]};
        my $output = forward_pass($func, $input);
        printf "Function: %s, Input: [%s], Expected: %.3f, Output: %.3f\n",
               $func, join(', ', @$input), $expected->[0], $output;
    };
}

our @weights :shared = ();

my $nn = Tc('Neural', 'Network', CODE => \&network_function)->link_it;
$nn->HASH({
    epochs => 20000,
    last_epoch => 0,
    learning_rate => 0.01683,
    num_threads => 8,
    base_file => 'Neural_Bin',
    training => require 'Neural_Bin.Training',
})->share_it;
$nn->ARRAY([])->share_it;

$nn->start->join for (0..9);

=pod

=head1 NAME

Neural Network Training with xclass - Demonstrating Concurrent Programming Power

=head1 DESCRIPTION

This script implements a multi-threaded neural network training system using the xclass ecosystem for Perl. It serves as a comprehensive example of how xclass simplifies and enhances concurrent programming.

=head1 XCLASS ECOSYSTEM ADVANTAGES

=over 4

=item * Thread-Safe Data Structures

Utilizes C<Hc>, C<Ac>, and C<Sc> for thread-safe hash, array, and scalar operations without explicit locking.

=item * Simplified Thread Management

C<Tc> (Thread Class) abstracts thread creation, start, and join operations, streamlining concurrent code structure.

=item * Shared Memory

The C<share_it> method facilitates safe data sharing across threads, crucial for neural network weights and training data.

=item * Concurrent Processing

Multiple worker threads train the neural network in parallel, demonstrating xclass's capability for distributing computational load.

=item * Thread-Safe Operations

Methods like C<each>, C<each_with_index>, C<push>, C<set>, and C<get> are inherently thread-safe, reducing synchronization complexity.

=item * Flexible Inter-Thread Communication

Shared data structures enable seamless communication between main and worker threads.

=item * Scalability

Easily adjustable number of worker threads allows the program to scale with available hardware.

=item * Clean Code Organization

xclass enables clear separation between thread management and core neural network logic.

=item * Implicit Error Handling

xclass provides mechanisms for exception propagation across threads (not explicitly shown in this example).

=item * Performance Optimization

Leverages multiple threads for potentially faster neural network training compared to single-threaded implementations.

=item * Consistent State Management

C<HASH>, C<ARRAY>, and C<SCALAR> accessors offer a uniform interface for cross-thread state management.

=item * Thread-Safe Persistence

Demonstrates thread-safe saving and loading of network weights.

=item * Implementation Flexibility

Easily switches between random initialization and pre-trained weight loading.

=item * Concurrency Abstraction

Allows developers to focus on algorithmic logic rather than low-level concurrency details.

=item * Resource Efficiency

Implied thread pooling leads to more efficient system resource utilization.

=item * Easy Synchronization

Simple C<join> operations ensure training completion before testing.

=item * Modular Design

Facilitates easy feature additions or neural network modifications without altering the concurrency model.

=item * Code Readability

Maintains readability despite concurrent complexity, thanks to xclass abstractions.

=item * Extensibility

Structure supports easy integration of more complex neural architectures or training algorithms.

=item * Cross-Function Data Sharing

Demonstrates complex data sharing across functions and threads using shared SCALAR references.

=back

This example illustrates how xclass simplifies implementing complex, concurrent applications like neural network training. It abstracts traditional concurrent programming challenges, allowing developers to focus on core application logic while benefiting from parallel processing capabilities.

=cut

################################################################################
# EOF Neural.pl (C) 2024, OnEhIppY, Domero Software <domerosoftware@gmail.com>