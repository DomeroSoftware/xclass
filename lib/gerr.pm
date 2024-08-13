#!/usr/bin/perl

#############################################################################
#                                                                           #
#   Eureka Error System v1.1.4                                              #
#   (C) 2020 Domero, Groningen, NL                                          #
#   ALL RIGHTS RESERVED                                                     #
#                                                                           #
#############################################################################

package gerr;

=head1 NAME

gerr - Eureka Error System v1.1.4

=head1 SYNOPSIS

    use gerr; # Standard usage
    use gerr qw(:control); # Use to override warn and die

    my $error_message = error("error message");
    warn "This is a warning."; # Calls custom Warn function if :control is used
    die "This is a fatal error."; # Calls custom Die function if :control is used

=head1 DESCRIPTION

The `gerr` module is designed to enhance error and debugging management in Perl scripts by providing custom error messages, stack traces, and handlers for warnings and fatal errors. It offers a consistent approach to handle errors and warnings, making debugging more manageable and informative.

The module includes functionalities to format error messages, capture and format stack traces, and replace default Perl warning and die functions with custom implementations when needed. This allows developers to gain deeper insights into issues within their scripts, including those that involve other modules and packages.

=head1 VERSION

Version 1.1.4

=head1 USAGE

To use the `gerr` module, include it in your Perl script with one of the following methods:

=head2 Standard Usage

    use gerr;

    # Generate a formatted error message
    my $error_message = error("Something went wrong", "type=Error", "trace=3", "return=1");

    # Output the error message
    warn "This is a warning message.";
    die "This is a fatal error message.";

In this case, the `error` function will return a formatted error message but will not print or exit unless explicitly configured. `warn` and `die` will be handled by Perl's default warning and die handlers.

=head2 Using :control to Override warn and die

    use gerr qw(:control);

    # Generate a warning
    warn "This is a warning message.";

    # Generate a fatal error
    die "This is a fatal error message.";

When using the `:control` tag, the `warn` and `die` functions are overridden with custom implementations that format messages using the `error` function. This enables a consistent approach to error handling across your script, providing additional context such as stack traces for better debugging.

=head1 FUNCTIONS

=cut

################################################################################

package gerr;

use strict;
use warnings; no warnings qw(uninitialized);
use Exporter;

our $VERSION = '1.1.4';
our @ISA = qw(Exporter);
our @EXPORT = qw(error Warn Die);
our @EXPORT_OK = qw(trace);

=head1 FUNCTIONS

=cut

################################################################################

=head2 error

    error(@messages)

The `error` function generates a formatted error message.

=head3 Arguments:

=over 4

=item * return=<value>: Set return boolean (default: 0, which will also exit the program)

=item * type=<value>: Set error type (default: "FATAL ERROR")

=item * size=<value>: Set size of formatted message (default: 78)

=item * trace=<value>: Set trace depth (default: 2)

=item * All other parts are considered as part of the error message itself.

=back

Returns the formatted error message as a string.

=cut

use utf8; # Enable UTF-8 support

sub error {
    my @msg = @_;
    my $return = 0;
    my $type = "FATAL ERROR";
    my $size = 80 - 2;
    my $trace = 2;
    my @lines;

    while (scalar(@msg)) {
        if (!defined $msg[0]) { 
            shift(@msg);
        }
        elsif ($msg[0] =~ /^return=(.+)$/s) { 
            $return = $1; 
            shift(@msg);
        }
        elsif ($msg[0] =~ /^type=(.+)$/s) { 
            $type = $1; 
            shift(@msg);
        }
        elsif ($msg[0] =~ /^size=(.+)$/s) { 
            $size = $1; 
            shift(@msg);
        }
        elsif ($msg[0] =~ /^trace=(.+)$/s) { 
            $trace = $1; 
            shift(@msg);
        }
        else { 
            push @lines, split(/\n/, shift(@msg)); 
        }
    }

    $type = " $type ";
    my $tsize = length("$type");
    push @lines, "";

    my $ls = ($size >> 1) - ($tsize >> 1);
    my $rs = $size - ($size >> 1) - ($tsize >> 1) - 1;
    my $tit = " " . ("#" x $ls) . $type . ("#" x $rs) . "\n";
    my $str = "\n\n";

    foreach my $line (@lines) {
        while (length($line) > 0) {
            $str .= " # ";
            if (length($line) > $size) {
                $str .= substr($line, 0, $size - 6) . "..." . " #\n";
                $line = "..." . substr($line, $size - 6);
            } else {
                $str .= $line . (($size - length($line) - 3) > 0 ? (" " x ($size - length($line) - 3)) : '') . " #\n";
                $line = "";
            }
        }
    }

    $str .= trace($trace); # Include stack trace if enabled

     # Only exit if not in an eval block
    if (!$return && !$^S) {
        $| = 1; # Autoflush STDERR
        binmode STDERR, ":encoding(UTF-8)"; # Set UTF-8 encoding for STDERR
        print STDERR $str;
        exit 1;
    }

    return $str;
}

################################################################################

=head2 trace

    trace($depth)

The `trace` function generates a stack trace with the given depth.

=head3 Arguments:

=over 4

=item * $depth: Depth of the stack trace (default: 1)

=back

Returns the formatted stack trace as a string.

=cut

sub trace {
    my $depth = $_[0] || 1;
    my @out = ();

    while ($depth > 0 && $depth < 20) {
        my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller($depth);
        
        if (!$package) { 
            $depth = 0; 
        } else { 
            push @out, [$line, "$package($filename)", "Calling $subroutine($hasargs) ", ($subroutine eq '(eval)' && $evaltext ? "[$evaltext]" : "")]; 
            $depth++;
        }
    }

    @out = reverse @out;

    if (@out) {
        for my $i (0 .. $#out) {
            my $dept = "# " . (" " x $i) . ($i > 0 ? "`[" : "-[");
            my ($ln, $pk, $cl, $ev) = @{$out[$i]};
            my $ll = (60 - length($dept . $cl));
            my $rr = (6 - length($ln));
            $out[$i] = "$dept $cl" . (" " x ($ll > 0 ? $ll : 0)) . " at line: " . (" " x ($rr > 0 ? $rr : 0)) . "$ln : $pk" . ($ev ? "\n$ev" : "");
        }
    }

    return join("\n", @out) . "\n";
}

################################################################################

=head2 Warn

    Warn($message)

The `Warn` function provides a custom implementation for warnings. It formats the message and invokes the warning signal handler if defined.

=head3 Arguments:

=over 4

=item * $message: The warning message

=back

=cut

sub Warn {
    my ($message) = @_;
    my $file = (caller)[1];
    my $line = (caller)[2];
    my $formatted_message = error("$message at $file line $line.", "return=1", "type=Warning", "trace=3");
    if ($SIG{__WARN__}) {
        $SIG{__WARN__}->($formatted_message);
    } else {
        binmode STDERR, ":encoding(UTF-8)"; # Set UTF-8 encoding for STDERR
        print STDERR $formatted_message;
    }
}

################################################################################

=head2 Die

    Die($message)

The `Die` function provides a custom implementation for fatal errors. It formats the message and invokes the die signal handler if defined, and exits the program if not in an eval block.

=head3 Arguments:

=over 4

=item * $message: The fatal error message

=back

=cut

sub Die {
    my ($message) = @_;
    my $file = (caller)[1];
    my $line = (caller)[2];
    my $formatted_message = error("$message at $file line $line.", "return=1", "type=Fatal", "trace=3");
    if ($SIG{__DIE__}) {
        $SIG{__DIE__}->($formatted_message);
    } else {
        binmode STDERR, ":encoding(UTF-8)"; # Set UTF-8 encoding for STDERR
        print STDERR $formatted_message;
    }
    exit 1 unless $^S; # Only exit if not in an eval block
}

################################################################################

=head1 CUSTOM ERROR HANDLING

=head2 Warn

The `Warn` function formats the warning message, includes the call location, and either invokes a custom warning handler if defined or prints the message to STDERR. This is useful when you want consistent formatting for warnings across your entire application, even when other modules are in use.

=head2 Die

The `Die` function formats the fatal error message, includes the call location, and either invokes a custom die handler if defined or prints the message to STDERR and exits the program if not in an eval block. By replacing `CORE::GLOBAL::die`, you ensure that all fatal errors, even those triggered by other modules or packages, are handled consistently.

=head1 EXPORT

By default, only the `error` function is exported. If you want to use custom warning and die handlers, use the `:control` tag.

=head1 ADVANCED USAGE

The `:control` tag enables overriding Perl's built-in `warn` and `die` functions with `Warn` and `Die` methods from `gerr`. This capability is particularly useful for debugging large applications or systems where you want to ensure that all warnings and errors, regardless of their origin, are handled consistently.

By leveraging `:control`, you can:

=over 4

=item * Ensure that all warnings and errors are formatted uniformly across your application, including messages from other modules or packages.

=item * Capture and log detailed stack traces for better debugging and problem analysis.

=item * Maintain consistent error handling behavior across different components of your application, providing a unified debugging experience.

=back

Using the `:control` tag effectively allows you to centralize and standardize error and warning management, making it easier to diagnose and address issues across complex Perl applications.

=cut

sub import {
    my ($class, @args) = @_;

    # Handle import arguments
    if (grep { $_ eq ':control' } @args) {
        # Override global warn and die
        no strict 'refs'; # Allow modifying symbolic references
        *CORE::GLOBAL::warn = \&Warn;
        *CORE::GLOBAL::die = \&Die;
    }

    # Export default functions
    $class->export_to_level(1, $class, @EXPORT);

    # Conditionally export functions based on import arguments
    if (grep { $_ eq ':control' } @args) {
        $class->export_to_level(1, $class, @EXPORT_OK);
    }
}

1;

################################################################################

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2020 Domero, Groningen, NL. All rights reserved.

=cut

################################################################################
# EOF gerr.pm (C) 2020 Domero
