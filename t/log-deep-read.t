#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More tests => 9 + 1;
use Test::NoWarnings;
use Data::Dumper qw/Dumper/;

use File::Slurp qw/slurp/;
use Log::Deep::Read;

my $deep = Log::Deep::Read->new();
isa_ok( $deep, 'Log::Deep::Read', 'Can create a log object');

# TESTING the parse line method
my @cols = $deep->parse_line( 'date,session,level,message,$DATA={};', { name => 'test' } );
is( scalar @cols, 5, 'Get 5 columns');
is_deeply( \@cols, [ qw/date session level message/, {} ], 'The data structure is as expected' );

@cols = $deep->parse_line( 'date,session,level,message \, test\n,$DATA={};', { name => 'test' } );
is( scalar @cols, 5, 'Get 5 columns');
is_deeply( \@cols, [ qw/date session level/, "message , test\n",  {} ], 'The data structure is as expected' );

# Testing show_line method
ok( $deep->show_line(@cols), 'Ordinarly the line is displayed');
ok( !$deep->show_line(), 'no data the line is not displayed');

# set session colours
is( $deep->session_colour(1), $deep->session_colour(1), 'Two calls to session colour return the same value');
my %colour;
for ( 1..40 ) {
	$colour{$_} = $deep->session_colour($_);
}
is( ( scalar keys %colour ), 40, "40 sessions == 40 colours" );
