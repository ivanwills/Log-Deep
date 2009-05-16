#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More tests => 1 + 1;
use Test::NoWarnings;
use Data::Dumper qw/Dumper/;

use File::Slurp qw/slurp/;
use Log::Deep::Read;

my $deep = Log::Deep::Read->new();
isa_ok( $deep, 'Log::Deep::Read', 'Can create a log object');

