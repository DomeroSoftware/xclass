use strict;
use warnings;
use List::Util qw(sum);
use threads;
use threads::shared;

my $last_epoch :shared = 0;

sub worker_function {
    my ($self) = @_;
    my $nn = ${${*Neural::Network}};
    
    print STDOUT "Worker Neural::Network : `".$self->namespace."`                              \n";
    
    my $epochs = $nn->HASH->get('epochs');
    my $learning_rate = $nn->HASH->get('learning_rate');
    my $training_data = $nn->HASH->get('training')->{data};
    my $num_threads = $nn->HASH->get('num_threads');
    my $last_error = undef;
    my $last_progress = 0;

    {
        my $total_error = 0; my $i=0;
        for my $data (@$training_data) {
            my ($func, $input, $target) = @$data;
            my $output = forward_pass($func, $input);
            $total_error += ($output - $target->[0]) ** 2;
            backward_pass($func, $input, $target);
            $i++;
        }
        my $error = $total_error / (2 * scalar(@$training_data));
        lock($last_epoch);
        $last_epoch = $error;
        $last_error = $error;
        print STDOUT $self->namespace." Epoch 0, Error: $error, Learning-Rate: $learning_rate                 \n";
    }

    my ($total_error,$error,$i);
    for my $epoch (1 .. $epochs / $num_threads) {
        $total_error = 0; $i=0;
        for my $data (@$training_data) {
            my ($func, $input, $target) = @$data;
            my $output = forward_pass($func, $input);
            $total_error += ($output - $target->[0]) ** 2;
            backward_pass($func, $input, $target);
            print STDOUT $self->namespace." Training ($epoch:$i), Function: `$func`, input [".join(', ',@$input)."] Target [".join(', ',@$target)."]                             \r" if $epoch % 1 == 0 && $i % 3 == 0;
            $i++;
        }
        
        $error = $total_error / (2 * scalar(@$training_data));
        if ($epoch % 10 == 0) {
            lock($last_epoch);
            my $progress = (defined $last_error ? $last_error - $error : 0);
            my $new_progress = $progress - $last_progress;
            $last_progress = $progress;
            $last_error = $error;
            if ($last_epoch < $epoch) {
                $last_epoch = $epoch;
                print STDOUT $self->namespace." Epoch $epoch, Error: $error, Learning-Rate: $learning_rate, Progress: $progress, Diff: $new_progress                 \n";
            }
        }
        #$learning_rate *= 0.72 if ($epoch % 100 == 0);
        $self->yield;
    }
}

sub forward_pass {
    my ($func, $inputs) = @_;
    my $nn = ${${*Neural::Network}};
    
    my @activations = (@$inputs, function_to_number($func), 1);
    
    $nn->ARRAY->each_with_index(sub {
        my ($layer, $index) = @_;
        my @new_activations;
        for my $neuron (@$layer) {
            my $sum = $neuron->[0];  # Bias
            for my $i (0 .. $#activations) {
                $sum += $neuron->[$i+1] * $activations[$i];
            }
            push @new_activations, 1 / (1 + exp(-$sum));
        }
        @activations = @new_activations;
    });
    
    return $activations[0];
}

sub backward_pass {
    my ($func, $inputs, $target) = @_;
    my $nn = ${${*Neural::Network}};
    
    # Forward pass
    my @layer_activations = ([@$inputs, function_to_number($func), 1]);
    $nn->ARRAY->each_with_index(sub {
        my ($weights, $index) = @_;
        my @new_activations;
        for my $neuron (@{$weights}) {
            my $sum = $neuron->[0];  # Bias
            for my $i (0 .. $#{$layer_activations[-1]}) {
                $sum += $neuron->[$i+1] * $layer_activations[-1][$i];
            }
            push @new_activations, 1 / (1 + exp(-$sum));
        }
        push @layer_activations, \@new_activations;
    });
    
    # Backward pass
    my @deltas;
    $nn->ARRAY->each_reverse_index(sub {
        my ($weights, $i) = @_;
        my @layer_deltas;
        if ($i == $#{$nn->ARRAY->get()}) {
            # Output layer
            my $output = $layer_activations[-1][0];
            push @layer_deltas, $output * (1 - $output) * ($target->[0] - $output);
        } else {
            # Hidden layers
            for my $j (0 .. $#{$layer_activations[$i+1]}) {
                my $error = 0;
                for my $k (0 .. $#{$nn->ARRAY->get($i+1)}) {
                    $error += $deltas[0][$k] * $nn->ARRAY->get($i+1)->[$k][$j+1];
                }
                my $output = $layer_activations[$i+1][$j];
                push @layer_deltas, $output * (1 - $output) * $error;
            }
        }
        unshift @deltas, \@layer_deltas;
    });
    
    # Update weights
    $nn->ARRAY->each_with_index(sub {
        my ($weights, $i) = @_;
        for my $j (0 .. $#{$weights}) {
            $weights->[$j][0] += $nn->HASH->get('learning_rate') * $deltas[$i][$j];  # Update bias
            for my $k (0 .. $#{$layer_activations[$i]}) {
                $weights->[$j][$k+1] += $nn->HASH->get('learning_rate') * $deltas[$i][$j] * $layer_activations[$i][$k];
            }
        }
    });
    
    return $layer_activations[-1][0];
}

sub activate {
    my ($x, $is_output) = @_;
    return $is_output ? 1 / (1 + exp(-$x)) : ($x > 0 ? $x : 0);  # ReLU for hidden, sigmoid for output
}

sub activate_derivative {
    my ($x, $is_output) = @_;
    return $is_output ? $x * (1 - $x) : ($x > 0 ? 1 : 0);  # Derivative of ReLU for hidden, sigmoid for output
}

sub function_to_number {
    my $nn = ${${*Neural::Network}};
    my $training = $nn->HASH->get('training');
    #print STDOUT "Training data: $training\n";
    my ($func) = @_;
    return exists $training->{map}{$func} ?
        $training->{map}{$func} / (1+$#{[keys %{$training->{map}}]}) :
        die "Unknown function: $func";
}

1;
