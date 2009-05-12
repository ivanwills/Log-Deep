#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More tests => 11 + 1;
use Test::NoWarnings;
use Data::Dumper qw/Dumper/;

use Log::Deep;

my $deep = Log::Deep->new();
isa_ok( $deep, 'Log::Deep', 'Can create a log object');

ok( -f $deep->file, 'Check that the file is created/exists' );

# truncate the file and reset the writing at the start
truncate $deep->{handle}, 0;
seek $deep->{handle}, 0, 0;

my $current_length = 0;
my $found_length = log_length($deep);

is( $found_length, $current_length, 'Check that we realy do have a zero length file');

$current_length = $found_length + 1;
$deep->session(0);
$found_length = log_length($deep);

is( $found_length, $current_length, 'Checking that session writes one log line');

SKIP: {
	skip "Need to work out how to fatal testing working with out exiting", 1;

	warn Dumper my $exit = \*Log::Deep::exit;
	*Log::Deep::exit = sub {};
	$current_length = $found_length + 1;
	$deep->fatal('test');
	*Log::Deep::exit = $exit;
	$found_length = log_length($deep);

	is( $found_length, $current_length, 'Checking that fatal writes one log line');
}

$current_length = $found_length + 1;
$deep->error('test');
$found_length = log_length($deep);

is( $found_length, $current_length, 'Checking that error writes one log line');

$current_length = $found_length + 1;
$deep->warning('test');
$found_length = log_length($deep);

is( $found_length, $current_length, 'Checking that warning writes one log line');

$current_length = $found_length + 0;
$deep->debug('test');
$found_length = log_length($deep);

is( $found_length, $current_length, 'Checking that debug writes one log line');

$current_length = $found_length + 0;
$deep->message('test');
$found_length = log_length($deep);

is( $found_length, $current_length, 'Checking that message writes one log line');

$current_length = $found_length + 0;
$deep->note('test');
$found_length = log_length($deep);

is( $found_length, $current_length, 'Checking that note writes one log line');

$current_length = $found_length + 1;
$deep->security('test');
$found_length = log_length($deep);

is( $found_length, $current_length, 'Checking that security writes one log line');


sub log_length {
	my ($deep) = @_;

	my $file   = $deep->file;
	my $length = `wc -l $file`;
	chomp $length;

	$length =~ s{^(\d+).*$}{$1}xms;

	return $length;
}
