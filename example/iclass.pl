#!/usr/bin/env perl

use v5.36;
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use iclass;
use threads;
use Thread::Queue;
use Fcntl qw(:flock);

# Basic usage
my $io = iclass->new();
$io->open("test.txt", "w");
$io->print("Hello, world!\n");
$io->close;

# Reading from a file
$io->open("test.txt", "r");
my $content = $io->getline();
say "Read from file: $content";
$io->close;

# Using compression
my $compressed_io = iclass->new(undef, compression => 1);
$compressed_io->open("compressed.dat", "w");
$compressed_io->print("This is compressed data " x 1000);
$compressed_io->close;

say "Compressed file size: ", -s "compressed.dat";

# Thread-safe operations
my $shared_io = iclass->new(\*STDOUT);
my $queue = Thread::Queue->new();

sub worker {
    while (my $message = $queue->dequeue()) {
        $shared_io->say("Thread ", threads->tid(), ": $message");
    }
}

my @threads = map { threads->create(\&worker) } 1..5;

for my $i (1..20) {
    $queue->enqueue("Message $i");
}

$queue->end();
$_->join() for @threads;

# Atomic operations
$io->open("atomic.txt", "w");
$io->atomic_operation(sub {
    $io->print("This operation ");
    $io->print("is atomic");
});
$io->close;

# Using different encodings
my $utf16_io = iclass->new(undef, encoding => 'UTF-16LE');
$utf16_io->open("utf16.txt", "w");
$utf16_io->print("こんにちは、世界！");
$utf16_io->close;

# File locking example
my $locked_io = iclass->new();
$locked_io->open("locked.txt", "w");
if ($locked_io->lock(LOCK_EX | LOCK_NB)) {
    $locked_io->print("This file is locked");
    $locked_io->unlock();
} else {
    say "Could not acquire lock";
}
$locked_io->close;

# Secure deletion
my $secure_io = iclass->new();
$secure_io->open("sensitive.txt", "w");
$secure_io->print("This is sensitive data");
$secure_io->close;
$secure_io->secure_delete();

# Error handling
my $error_io = iclass->new();
if (!$error_io->open("non_existent.txt", "r")) {
    say "Error: ", $error_io->get_last_error();
}

# Copying file contents
my $source = iclass->new();
my $destination = iclass->new();
$source->open("source.txt", "w");
$source->print("Source content");
$source->close;

$source->open("source.txt", "r");
$destination->open("destination.txt", "w");
my $copied = $source->copy_to($destination);
say "Copied $copied bytes";
$source->close;
$destination->close;

# Using temporary files
my $temp_io = iclass->new();
my $temp_filename = $temp_io->create_temp();
$temp_io->print("Temporary data");
$temp_io->close;
say "Temporary file created: $temp_filename";
unlink $temp_filename;

# Setting and getting file permissions
my $perm_io = iclass->new();
$perm_io->open("permissions.txt", "w");
$perm_io->set_permissions(0644);
my $perms = $perm_io->get_permissions();
say sprintf("File permissions: %04o", $perms);
$perm_io->close;

# Using overloaded operators
my $overload_io = iclass->new(\*STDOUT);
say "File descriptor: $overload_io";  # Uses overloaded stringification
say "Is open: ", $overload_io ? "Yes" : "No";  # Uses overloaded boolean context

# Original examples from the file
my $fh = iclass->new(\*STDOUT);
$fh->print("Hello, world!\n");

my $file_io = iclass->new();
$file_io->open("output.txt", "w");
$file_io->say("Writing to a file");
$file_io->close;

# Thread-safe operations (expanded version)
my $shared_file_io = iclass->new();
$shared_file_io->open("shared_output.txt", "w");

my @thread_pool;
for my $i (1..5) {
    push @thread_pool, threads->create(sub {
        for my $j (1..10) {
            $shared_file_io->say("Thread $i: Message $j");
        }
    });
}

$_->join for @thread_pool;
$shared_file_io->close;

say "Thread-safe writing completed. Check shared_output.txt for results.";

# EOF iclass.pl
