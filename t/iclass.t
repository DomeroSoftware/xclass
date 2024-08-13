#!/usr/bin/perl
use strict;
use warnings;

use lib qw(../lib);
use Test::More;
use Test::Exception;
use File::Temp qw/ tempfile tempdir /;
use Fcntl qw(:flock SEEK_SET SEEK_CUR SEEK_END);
use Encode qw(encode decode);
use Compress::Zlib;

my @xclass_methods = qw(new get set);
my @io_methods = qw(
    _io_deref_op _stringify_op _count_op _bool_op _neg_op _assign_op _eq_op _ne_op _cmp_op _spaceship_op
    io_type fileno binmode stat chmod ismod chown isown size open opendir is_open filename rename
    close closedir clear can_read read recv readdir readline readlink readpipe getc getline getlines
    can_write write send print printf say truncate seek seekdir tell telldir eof flush _check_flush
    autoflush flush_interval buffer encoding compression compression_level lock_io unlock_io
    copy_to unlink secure_delete atomic_operation accept listen
);
my @lclass_methods = qw(
    _ref _shared share_it _init is_defined is_empty 
    sync lock unlock apply on trigger throw debug try 
    compare equals to_string serialize deserialize clone 
    xc sc ac hc cc ic gc rc tc
);
my @io_class = (@xclass_methods, @io_methods, @lclass_methods);

# Load the necessary modules
use_ok('xclass');

# Test xclass integration
my $out = Ic(\*STDOUT);
isa_ok($out, 'iclass', 'Ic creates an STDOUT iclass object: '.$out->io_type);

# Test all iclass methods
can_ok($out, @io_class);

# Test constructor
my $err = iclass->new(\*STDERR);
isa_ok($err, 'iclass', 'Constructor creates an STDERR iclass object: '.$err->io_type);
can_ok($err, @io_class);

# Test file operations
my ($fh, $filename) = tempfile();
my $io = Ic($fh);
can_ok($io, @io_class);
ok($io->is_open, 'File is open');
is($io->io_type, 'FILE', 'IO type is FILE');
ok($io->write(\"Hello, World!"), 'Write to file');
ok($io->flush, 'Flush to file');
is($io->tell, 13, 'Tell returns correct position');
ok($io->close, 'Close file');
ok($io->open($filename, '<'), 'Open file for reading');
my $content;
my $bytesread = $io->read(\$content, 13);
is($bytesread, 13, 'Read from file: ');
is($content, "Hello, World!", 'Read content is correct');
ok($io->eof, 'End of file reached');
ok($io->close, 'Close file');

# Test seeking
ok($io->open($filename, '+<'), 'Open file for reading and writing');
ok($io->seek(7), 'Seek to position');
is($io->tell, 7, 'Tell returns correct position after seek');
ok($io->write(\"Perl!!"), 'Write at seeked position');
ok($io->seek(0), 'Seek to beginning');
is($io->tell, 0, 'Tell returns correct position after seek');
$bytesread = $io->read(\$content, 13);
is($bytesread, 13, 'Read from file: ');
is($content, "Hello, Perl!!", 'Content after seek and write is correct');
ok($io->close, 'Close file');

# Test truncate
ok($io->open($filename, '>'), 'Open file for truncate test');
ok($io->truncate(5), 'Truncate file');
ok($io->seek(0, SEEK_END), 'Seek to end');
is($io->tell, 5, 'File size after truncate is correct');
ok($io->close, 'Close file');

# Test binmode
ok($io->open($filename, '>'), 'Open file for binmode test');
ok($io->binmode(':utf8'), 'Set UTF-8 binmode');
ok($io->write(\"こんにちは"), 'Write UTF-8 content');
ok($io->close, 'Close file');

ok($io->open($filename, '<'), 'Open file for UTF-8 read test');
ok($io->binmode(':utf8'), 'Set UTF-8 binmode for reading');
$bytesread = $io->read(\$content, 15);
is($bytesread, 15, 'Read from file');
is($content, "こんにちは", 'Read UTF-8 content correctly');
ok($io->close, 'Close file');

# Test getline and getlines
ok($io->open($filename, '>'), 'Open file for getline test');
$io->write(\"Line 1\nLine 2\nLine 3\n");
ok($io->close, 'Close file');

ok($io->open($filename, '<'), 'Open file for getline read test');
is($io->getline, "Line 1\n", 'getline returns correct line');
my @lines = $io->getlines;
is_deeply(\@lines, ["Line 2\n", "Line 3\n"], 'getlines returns correct lines');
ok($io->close, 'Close file');

# Test printf and say
ok($io->open($filename, '>'), 'Open file for printf test');
ok($io->printf("Number: %d, String: %s", 42, "test"), 'printf to file');
ok($io->say("This is a new line"), 'say to file');
ok($io->close, 'Close file');

ok($io->open($filename, '<'), 'Open file for printf read test');
$io->read(\$content, 100);
like($content, qr/Number: 42, String: test/, 'printf content is correct');
like($content, qr/This is a new line/, 'say content is correct');
ok($io->close, 'Close file');

# Test clear
ok($io->open($filename, '+<'), 'Open file for clear test');
ok($io->clear, 'Clear file');
is($io->tell, 0, 'File position is at beginning after clear');
$bytesread = $io->read(\$content, 100);
is($content, '', 'File is empty after clear');
ok($io->close, 'Close file');

# Test locking
ok($io->open($filename, '>'), 'Open file for locking test');
ok($io->lock_io(LOCK_EX), 'Exclusive lock acquired');
ok($io->unlock_io, 'Lock released');
ok($io->close, 'Close file');

# Test copy_to
ok($io->open($filename, '>'), 'Open source file for copy test');
$io->write(\"Copy test content");
ok($io->close, 'Close source file');

my $dest_io = Ic();
my $dest_filename = $dest_io->temporary;
ok(-e $dest_filename, 'Destination file created');
ok($dest_io->is_open, 'Opened destination file for copy test: '.$dest_filename);
ok($io->open($filename, '<'), 'Open source file for reading');
ok($io->copy_to($dest_io), 'Copy content to destination file');
ok($io->close, 'Close source file');
ok($dest_io->close, 'Close destination file');
ok($dest_io->open($dest_filename, '<'), 'Open copied file for verification');
$dest_io->read(\$content, 100);
is($content, "Copy test content", 'Copied content is correct');
ok($dest_io->close, 'Close copied file');

# Test create_temp
my $temp_filename = $io->temporary;
ok(-e $temp_filename, 'Temporary file created');
ok($io->is_open, 'Temporary file is open');
ok($io->close, 'Close temporary file');

# Test secure_delete
ok($io->open($filename, '>'), 'Open file for secure delete test');
$io->write(\"Sensitive data");
ok($io->close, 'Close file');
ok($io->open($filename, '>'), 'Reopen file for secure delete');
ok($io->secure_delete, 'Secure delete performed');
ok(!-e $filename, 'File no longer exists after secure delete');

# Test atomic_operation
($fh, $filename) = tempfile();
ok($io->open($filename, '>'), 'Open file for atomic operation test');
$io->atomic_operation(sub {
    return $io->write(\"Atomic write");
});
ok($io->close, 'Close file after atomic operation');
ok($io->open($filename, '<'), 'Reopen file to check atomic operation');
$io->read(\$content, 100);
is($content, "Atomic write", 'Atomic operation content is correct');
ok($io->close, 'Close file');

# Test permissions and ownership
SKIP: {
    skip "Permissions tests require root privileges", 4 if $> != 0;
    
    ok($io->open($filename, '>'), 'Open file for permissions test'.$io->ismod);
    ok($io->chmod(0644), 'Set file permissions');
    is($io->ismod, 0644, 'Get file permissions');
    ok($io->chown(1000, 1000), 'Set file owner');
    my ($uid, $gid) = $io->isown;
    is($uid, 1000, 'Owner UID is correct');
    is($gid, 1000, 'Owner GID is correct');
    ok($io->unlink, 'Unlink file');
}

($fh, $filename) = tempfile();
ok($io->open($filename,">"), 'Open file for configuration methods');
# Test configuration methods
is($io->buffer, 8192, 'Default buffer size is correct');
ok($io->buffer(16384), 'Set new buffer size');
is($io->buffer, 16384, 'New buffer size is correct');

is($io->encoding, 'raw', 'Default encoding is correct');
ok($io->encoding('utf8'), 'Set new encoding');
is($io->encoding, 'utf8', 'New encoding is correct');

is($io->compression, 0, 'Default compression is off');
ok($io->compression(1), 'Enable compression');
is($io->compression, 1, 'Compression is enabled');

is($io->compression_level, 6, 'Default compression level is correct');
ok($io->compression_level(9), 'Set new compression level');
is($io->compression_level, 9, 'New compression level is correct');

is($io->flush_interval, undef, 'Default flush interval is undefined');
ok($io->flush_interval(5), 'Set new flush interval');
is($io->flush_interval, 5, 'New flush interval is correct');
ok($io->close, 'Close file');

# Test overloaded operators
ok($io->open("$filename\.new",">"), 'Open file for overloaded operator tests');
my $overload = "Overload test";
$io->write(\$overload);
ok($io->close, 'Close file');

# Test dereference overload
ok($io->open($filename, '<'), 'Open file for dereference test');
my $fh_deref = *{$io};
isa_ok($io, 'iclass', 'Dereferenced filehandle: '. $fh_deref);

# Test stringification overload
like("$io", qr/IO handle \(type\: FILE\, fileno\: 3\)/s, 'Stringification includes class name');

# Test numeric context overload
my $fileno = 0 + $io;
ok($fileno > 0, "Numeric context returns positive number (likely fileno: $fileno == ".$io->fileno.")");

ok($io->close, 'Close file');
# Test boolean context overload
ok($io->open($filename, '<'), 'Open file for boolean test');
ok($io, 'Boolean context is true when file is open');
ok($io->close, 'Close file');
ok(!$io, 'Boolean context is false when file is closed');

# Test comparison overloads
my $io2 = Ic()->open($filename, '>');
ok($io != $io2, 'Inequality operator works');
$io2->close;

# Test lclass functionality
lives_ok { $io->sync(sub { $io->open($filename, '<') }) } 'sync method from lclass works';
lives_ok { $io->try(sub { $io->read(\my $content, 10) }, 'read_test') } 'try method from lclass works';
ok($io->close, 'Close file');

# Clean up
unlink $filename;
unlink $dest_filename;
unlink $temp_filename;

done_testing();
