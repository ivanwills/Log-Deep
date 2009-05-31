#!perl

use Test::More tests => 4 + 1;
use Test::NoWarnings;

BEGIN {
	use_ok( 'Log::Deep'       );
	use_ok( 'Log::Deep::Read' );
	use_ok( 'Log::Deep::Line' );
	use_ok( 'Log::Deep::File' );
}

diag( "Testing Log::Deep $Log::Deep::VERSION, Perl $], $^X" );
