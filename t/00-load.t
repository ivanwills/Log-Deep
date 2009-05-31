#!perl

use Test::More tests => 3 + 1;
use Test::NoWarnings;

BEGIN {
	use_ok( 'Log::Deep'       );
	use_ok( 'Log::Deep::Read' );
	use_ok( 'Log::Deep::Line' );
}

diag( "Testing Log::Deep $Log::Deep::VERSION, Perl $], $^X" );
