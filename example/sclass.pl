#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(../lib);
use JSON::XS;
use threads;
use Benchmark;

# Load the necessary modules
use xclass 'Sc';
use sclass;

# Test counter
my $test_counter = 0;

sub run_test {
    my ($description, $code) = @_;
    eval {
        $code->();
        print "Test " . ++$test_counter . " passed: $description\n";
    } or do {
        print "Test " . ++$test_counter . " failed: $description\n";
        print "Error: $@\n";
    };
}

# Demonstrating basic usage of sclass module
run_test("Basic sclass usage", sub {
    my $scalar = sclass->new(\(my $s = "example"));
    print "Scalar: ", ref($scalar), "\n";
    print "Value: ", $scalar->get, "\n";
});

run_test("Using Sc() to create sclass object", sub {
    my $scalar = Sc(\(my $s = "xclass example"));
    print "Scalar: ", ref($scalar), "\n";
    print "Value: ", $scalar->get, "\n";
});

# Demonstrating various methods provided by sclass
run_test("Chomp method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!\n"));
    print "Chomp: ", $scalar->chomp->get, "\n";
});

run_test("Chop method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "Chop: ", $scalar->chop->get, "\n";
});

run_test("Uppercase method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "Uppercase: ", $scalar->uc->get, "\n";
});

run_test("Lowercase method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "Lowercase: ", $scalar->lc->get, "\n";
});

run_test("Reverse method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "Reverse: ", $scalar->reverse->get, "\n";
});

run_test("Trim method", sub {
    my $scalar = Sc(\(my $s = "  trim me  "));
    print "Trim: ", $scalar->trim->get, "\n";
});

run_test("Pad method", sub {
    my $scalar = Sc(\(my $s = "pad"));
    print "Pad: ", $scalar->pad(5)->get, "\n";
});

run_test("Substring method", sub {
    my $scalar = Sc(\(my $s = "sub string"));
    print "Substring: ", $scalar->substr(4, 3), "\n";
});

run_test("Increment method", sub {
    my $scalar = Sc(\(my $s = 5));
    print "Increment: ", $scalar->inc->get, "\n";
});

run_test("Decrement method", sub {
    my $scalar = Sc(\(my $s = 5));
    print "Decrement: ", $scalar->dec->get, "\n";
});

run_test("Increment by 3 method", sub {
    my $scalar = Sc(\(my $s = 5));
    print "Increment by 3: ", $scalar->inc(3)->get, "\n";
});

run_test("Decrement by 2 method", sub {
    my $scalar = Sc(\(my $s = 5));
    print "Decrement by 2: ", $scalar->dec(2)->get, "\n";
});

run_test("Multiply by 2 method", sub {
    my $scalar = Sc(\(my $s = 5));
    print "Multiply by 2: ", $scalar->mul(2)->get, "\n";
});

run_test("Divide by 3 method", sub {
    my $scalar = Sc(\(my $s = 6));
    print "Divide by 3: ", $scalar->div(3)->get, "\n";
});

run_test("Is numeric method", sub {
    my $scalar = Sc(\(my $s = "123"));
    print "Is numeric: ", ($scalar->is_numeric ? "Yes" : "No"), "\n";
});

run_test("To number method", sub {
    my $scalar = Sc(\(my $s = "123"));
    print "To number: ", $scalar->to_number, "\n";
});

run_test("Is empty method", sub {
    my $scalar = Sc(\(my $s = ""));
    print "Is empty: ", ($scalar->is_empty ? "Yes" : "No"), "\n";
});

run_test("Length method", sub {
    my $scalar = Sc(\(my $s = "Hello"));
    print "Length: ", $scalar->len, "\n";
});

run_test("Split method", sub {
    my $scalar = Sc(\(my $s = "a,b,c"));
    print "Split: ", join(", ", $scalar->split(',')), "\n";
});

run_test("Left shift method", sub {
    my $scalar = Sc(\(my $s = 5));  # 101 in binary
    print "Left shift: ", $scalar->_lshift_op(1)->get, "\n";
});

run_test("Right shift method", sub {
    my $scalar = Sc(\(my $s = 5));
    print "Right shift: ", $scalar->_rshift_op(1)->get, "\n";
});

run_test("Bitwise AND method", sub {
    my $scalar = Sc(\(my $s = 5));
    print "Bitwise AND: ", $scalar->_and_op(3)->get, "\n";
});

run_test("Bitwise OR method", sub {
    my $scalar = Sc(\(my $s = 5));
    print "Bitwise OR: ", $scalar->_or_op(3)->get, "\n";
});

run_test("Bitwise XOR method", sub {
    my $scalar = Sc(\(my $s = 5));
    print "Bitwise XOR: ", $scalar->_xor_op(3)->get, "\n";
});

run_test("Handling large increment", sub {
    my $scalar = Sc(\(my $s = 999_999_999));
    print "Increment large number: ", $scalar->inc(1)->get, "\n";
});

run_test("Handling large string", sub {
    my $scalar = Sc(\(my $s = "a" x 1_000_000));
    print "Large string length: ", $scalar->len, "\n";
});

run_test("To JSON method", sub {
    my $scalar = Sc(\(my $s = ""));
    print "To JSON: ", $scalar->to_json({ key => "value" }), "\n";
});

run_test("From JSON method", sub {
    my $scalar = Sc(\(my $s = '{"key":"value"}'));
    my $decoded = $scalar->from_json;
    print "From JSON: ", ref($decoded) eq 'HASH' ? "Yes" : "No", "\n";
});

run_test("Match method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "Match: ", $scalar->match(qr/World/) ? "Yes" : "No", "\n";
});

run_test("Substitute method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "Substitute: ", $scalar->substitute(qr/World/, "Universe")->get, "\n";
});

run_test("Encrypt/Decrypt method", sub {
    my $scalar = Sc(\(my $s1 = "Sensitive Data"));
    my $key = "secret";
    my $encrypted = $scalar->encrypt($key)->get;
    print "Encrypted: ", $encrypted, "\n";
    my $decrypted = $scalar->decrypt($key)->get;
    print "Decrypted: ", $decrypted, "\n";
});

run_test("MD5 method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "MD5: ", $scalar->md5, "\n";
});

run_test("SHA256 method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "SHA256: ", $scalar->sha256, "\n";
});

run_test("SHA512 method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "SHA512: ", $scalar->sha512, "\n";
});

run_test("Base64 encode method", sub {
    my $scalar = Sc(\(my $s = "Encode me"));
    print "Base64 encode: ", $scalar->enc_base64, "\n";
});

run_test("Base64 decode method", sub {
    my $scalar = Sc(\(my $s = "RW5jb2RlIG1l"));
    print "Base64 decode: ", $scalar->dec_base64->get, "\n";
});

run_test("Fetch add method", sub {
    my $scalar = Sc(\(my $s = 5));
    print "Fetch add: ", $scalar->fetch_add(2), "\n";
});

run_test("Fetch store method", sub {
    my $scalar = Sc(\(my $s = 5));
    print "Fetch store: ", $scalar->fetch_store(10), "\n";
});

run_test("Clone method", sub {
    my $scalar = Sc(\(my $s = "clone me"));
    my $clone = $scalar->clone;
    print "Clone: ", $clone->get, "\n";
});

run_test("Contains method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "Contains 'World': ", $scalar->contains("World") ? "Yes" : "No", "\n";
});

run_test("Replace all method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "Replace all: ", $scalar->replace_all("World", "Universe")->get, "\n";
});

run_test("To boolean method", sub {
    my $scalar = Sc(\(my $s = "true"));
    print "To boolean: ", $scalar->to_bool ? "Yes" : "No", "\n";
});

run_test("Equals ignore case method", sub {
    my $scalar = Sc(\(my $s = "Hello"));
    print "Equals ignore case 'hello': ", $scalar->eq_ignore_case("hello") ? "Yes" : "No", "\n";
});

run_test("Count occurrences method", sub {
    my $scalar = Sc(\(my $s = "Hello, World! Hello!"));
    print "Count occurrences of 'Hello': ", $scalar->count_occurrences("Hello"), "\n";
});

run_test("Truncate method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "Truncate to 5: ", $scalar->truncate(5)->get, "\n";
});

run_test("To camel case method", sub {
    my $scalar = Sc(\(my $s = "hello world"));
    print "To camel case: ", $scalar->to_camel_case->get, "\n";
});

run_test("To snake case method", sub {
    my $scalar = Sc(\(my $s = "HelloWorld"));
    print "To snake case: ", $scalar->to_snake_case->get, "\n";
});

run_test("Title case method", sub {
    my $scalar = Sc(\(my $s = "hello world"));
    print "Title case: ", $scalar->title_case->get, "\n";
});

run_test("Valid method", sub {
    my $scalar = Sc(\(my $s = "Hello, World!"));
    print "Valid: ", $scalar->valid(qr/World/) ? "Yes" : "No", "\n";
});

run_test("Concat method", sub {
    my $scalar = Sc(\(my $s = "Hello"));
    print "Concat: ", $scalar->concat(", World!")->get, "\n";
});

run_test("Apply method", sub {
    my $scalar = Sc(\(my $s = "Hello"));
    print "Apply: ", $scalar->apply(sub { uc $_[0] })->get, "\n";
});

run_test("Append method", sub {
    my $scalar = Sc(\(my $s = "Hello"));
    print "Append: ", $scalar->append("!")->get, "\n";
});

run_test("Prepend method", sub {
    my $scalar = Sc(\(my $s = "World"));
    print "Prepend: ", $scalar->prepend("Hello, ")->get, "\n";
});

run_test("Modify method", sub {
    my $scalar = Sc(\(my $s = "Hello"));
    $scalar->modify(sub { $_[0] .= ", World!" });
    print "Modify: ", $scalar->get, "\n";
});

run_test("Merge method", sub {
    my $scalar1 = Sc(\(my $s1 = "Hello"));
    my $scalar2 = Sc(\(my $s2 = "World"));
    print "Merge: ", $scalar1->merge($scalar2)->get, "\n";
});

run_test("Clear method", sub {
    my $scalar = Sc(\(my $s = "Hello"));
    print "Clear: ", $scalar->clear->get, "\n";
});

run_test("Get undefined method", sub {
    my $scalar = Sc(\(my $s = undef));
    print "Get undefined: ", defined $scalar->get ? "Defined" : "Undefined", "\n";
});

run_test("Is empty with undefined method", sub {
    my $scalar = Sc(\(my $s = undef));
    print "Is empty with undefined: ", $scalar->is_empty ? "Yes" : "No", "\n";
});

run_test("Type method", sub {
    my $scalar = Sc(\(my $s1 = "string"));
    print "Type: ", $scalar->type, "\n";
    $scalar->set(\(my $s2 = 123));
    print "Type: ", $scalar->type, "\n";
});

# Threading String tests
run_test("Threading tests for strings", sub {
    sub thread_function {
        my $scalar = Sc(\(my $s = "Thread Example"));

        # Perform various string operations
        $scalar->concat(" - Updated");
        $scalar->trim;              # Remove leading and trailing whitespace
        $scalar->uc;                # Convert to uppercase
        $scalar->lc;                # Convert to lowercase
        my $length = $scalar->len;  # Get the length of the string

        # Simulate some work with the scalar
        sleep(1); # Just to make the threads actually work for some time

        return ($scalar->get, $length);
    }

    my @threads;
    for (1..5) {
        push @threads, threads->create(\&thread_function);
    }

    foreach my $thread (@threads) {
        my ($result, $length) = $thread->join();
        print "Thread result: $result, Length: $length\n";
    }
});

# Threading Number tests
run_test("Threading tests for numbers", sub {

    my $scalar = Sc(\(my $n :shared = 10));

    sub threads_function {
        my $s = shift;
        # Perform various numeric operations
        $s->inc;           # Increment the value
        $s->inc(5);        # Add 5 to the value
        $s->dec(2);        # Subtract 2 from the value
        $s->mul(3);        # Multiply the value by 3
        $s->div(2);        # Divide the value by 2

        # Simulate some work with the scalar
        sleep(1); # Just to make the threads actually work for some time

        return $s->get;
    }

    my @threads;
    for (1..5) {
        push @threads, threads->create(\&threads_function,$scalar);
    }

    foreach my $thread (@threads) {
        my $result = $thread->join();
        print "Thread result: ($n) $result\n";
    }
});

# Benchmark tests
run_test("Benchmark tests", sub {
    my $number = Sc(\(my $s = 10));
    my $string = Sc(\(my $s2 = "Benchmark Example"));

    my $results = timethese(100000, {
        'increment' => sub { $number->inc },
        'decrement' => sub { $number->dec },
        'addition' => sub { $number->inc(5) },
        'subtraction' => sub { $number->dec(5) },
        'multiplication' => sub { $number->mul(2) },
        'division' => sub { $number->div(2) },
        'bitwise_and' => sub { $number->_and_op(1) },
        'bitwise_or' => sub { $number->_or_op(1) },
        'bitwise_xor' => sub { $number->_xor_op(1) },
        'negate' => sub { $number->neg },
        'absolute' => sub { $number->abs },
        'not_op' => sub { $number->_not_op },
        'modulus' => sub { $number->mod(3) },
        'exponentiation' => sub { $number->exp(2) },
        'concatenation' => sub { $string->concat(" test") },
        'string_length' => sub { $string->len },
        'string_reverse' => sub { $string->reverse },
        'to_uppercase' => sub { $string->uc },
        'to_lowercase' => sub { $string->lc },
        'substring' => sub { $string->substr(0, 5) },
        'trim' => sub { $string->trim },
        'match' => sub { $string->match(qr/Example/) },
        'substitute' => sub { $string->substitute(qr/Example/, "Test") },
        'clone' => sub { $string->clone },
        'apply' => sub { $string->apply(sub { $_[0] .= "!" }) },
        'append' => sub { $string->append(" end") },
        'prepend' => sub { $string->prepend("start ") },
        'modify' => sub { $string->modify(sub { $_[0] .= " modified" }) },
        'merge' => sub { $string->merge(Sc(\(my $s2 = " Merge"))) },
        'clear' => sub { $string->clear },
        'get' => sub { $string->get },
        'set' => sub { $string->set("New Value") },
        'is_empty' => sub { $string->is_empty },
        'to_number' => sub { $number->to_number },
        'to_boolean' => sub { $string->to_bool },
        'valid' => sub { $string->valid(qr/Ben/) },
        'to_json' => sub { $string->to_json({key=>'value'}) },
        'from_json' => sub { $string->from_json },
        'contains' => sub { $string->contains("Example") },
        'replace_all' => sub { $string->replace_all("Example", "Test") },
        'eq_ignore_case' => sub { $string->eq_ignore_case("benchmark example") },
#        'count_occurrences' => sub { $string->count_occurrences("e") },
        'truncate' => sub { $string->truncate(5) },
        'to_camel_case' => sub { $string->to_camel_case },
        'to_snake_case' => sub { $string->to_snake_case },
        'title_case' => sub { $string->title_case },
        'type' => sub { $string->type },
        'md5' => sub { $string->md5 },
        'sha256' => sub { $string->sha256 },
        'sha512' => sub { $string->sha512 },
        'enc_base64' => sub { $string->enc_base64 },
        'dec_base64' => sub { $string->dec_base64 },
        'fetch_add' => sub { $number->fetch_add(2) },
        'fetch_store' => sub { $string->fetch_store("Stored Value") },
        'encrypt' => sub { $string->encrypt("secret") },
        'decrypt' => sub { $string->decrypt("secret") },
    });

});

print "Total tests run: $test_counter\n";
