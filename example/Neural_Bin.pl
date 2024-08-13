# Neural_Bin.pl

use strict;
use warnings;

sub worker_function {
    my ($self) = @_;
    my $nn = ${Neural::Network};  # Access the main neural network object
    my $epochs = $nn->HASH->get('epochs');
    my $learning_rate = $nn->HASH->get('learning_rate');
    my $training_data = $nn->HASH->get('training_data');
    my $num_threads = $nn->HASH->get('num_threads');

    for my $epoch (1 .. $epochs / $num_threads) {
        $training_data->each(sub {
            my ($data) = @_;
            my ($func, $input, $target) = @$data;
            my $output = $nn->forward_pass($func, $input);
            $nn->backward_pass($func, $input, $output, $target, $learning_rate);
        });

        if ($epoch % 250 == 0) {
            my $error = $nn->calculate_error();
            print "Worker " . $self->name . ", Epoch $epoch, Error: $error\n";
        }
    }
}

sub forward_pass {
    my ($nn, $func, $input) = @_;
    my $activation = [@$input, function_to_number($func)];
    $nn->ARRAY->each(sub {
        my ($weight) = @_;
        $activation = [map {
            my $sum = 0;
            $sum += $activation->[$_] * $weight->[$_][$_] for 0..$#$activation;
            1 / (1 + exp(-$sum))
        } 0..$#{$weight->[0]}];
    });
    return $activation->[0];
}

sub backward_pass {
    my ($nn, $func, $input, $output, $target, $learning_rate) = @_;
    
    my @layer_outputs = ([@$input, function_to_number($func)]);
    my @layer_inputs = ();
    
    # Forward pass to store layer outputs and inputs
    $nn->ARRAY->each(sub {
        my ($weight) = @_;
        my $layer_input = [@{$layer_outputs[-1]}, 1];  # Add bias
        push @layer_inputs, $layer_input;
        
        my $layer_output = [map {
            my $sum = 0;
            $sum += $layer_input->[$_] * $weight->[$_][$_] for 0..$#$layer_input;
            1 / (1 + exp(-$sum))
        } 0..$#{$weight->[0]}];
        
        push @layer_outputs, $layer_output;
    });
    
    # Calculate output layer error
    my $output_error = [map { $layer_outputs[-1][$_] - $target->[$_] } 0..$#{$layer_outputs[-1]}];
    
    # Backpropagate the error
    my @deltas = ($output_error);
    $nn->ARRAY->reverse->each_with_index(sub {
        my ($weight, $l) = @_;
        my $prev_layer_output = $layer_outputs[$#{$layer_outputs} - $l - 1];
        my $layer_input = $layer_inputs[$#{$layer_inputs} - $l];
        
        # Calculate delta for this layer
        my $delta = [map {
            $deltas[0][$_] * $layer_outputs[-$l-1][$_] * (1 - $layer_outputs[-$l-1][$_])
        } 0..$#{$layer_outputs[-$l-1]}];
        
        # Update weights
        for my $i (0..$#$layer_input) {
            for my $j (0..$#$delta) {
                $weight->[$i][$j] -= $learning_rate * $delta->[$j] * $layer_input->[$i];
            }
        }
        
        # Calculate delta for previous layer (excluding bias)
        if ($l < $nn->ARRAY->size - 1) {
            my $prev_delta = [map {
                my $sum = 0;
                $sum += $delta->[$_] * $weight->[$_][$_] for 0..$#$delta;
                $sum * $prev_layer_output->[$_] * (1 - $prev_layer_output->[$_])
            } 0..$#{$prev_layer_output}-1];
            unshift @deltas, $prev_delta;
        }
    });
}

sub calculate_error {
    my ($self) = @_;
    my $error = 0;
    
    my $training_data = $self->HASH->get('training_data');
    
    $training_data->each(sub {
        my ($data) = @_;
        my ($func, $input, $target) = @$data;
        my $output = $self->forward_pass($func, $input);
        $error += ($output - $target->[0]) ** 2;
    });
    
    return $error / (2 * $training_data->size);  # Mean Squared Error
}

sub function_to_number {
    my ($func) = @_;
    my %func_map = ('XOR' => 0, 'AND' => 1, 'NXOR' => 2, 'NAND' => 3);
    if (exists $func_map{$func}) {
        return $func_map{$func} / 3;  # Normalize to [0, 1]
    } else {
        die "Unknown function: $func";
    }
}

1;