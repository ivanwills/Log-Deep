
use strict;
use warnings;
use Test::More tests => 5 + 1;
use Test::NoWarnings;

use Log::Deep;

my $deep = Log::Deep->new;

my $level = $deep->level;
is_deeply( $level, { fatal=>1, error=>1, warning=>1, debug=>0, message=>0, note=>0 }, "Check that the default setup is as expected" );

$level = $deep->level('debug');
is_deeply( $level, { fatal=>1, error=>1, warning=>1, debug=>1, message=>0, note=>0 }, "turn on debug and higher" );

$level = $deep->level(1);
is_deeply( $level, { fatal=>1, error=>1, warning=>1, debug=>1, message=>1, note=>0 }, "turn on message and higher" );

$deep->level( -set => 'note' );
$level = $deep->level;
is_deeply( $level, { fatal=>1, error=>1, warning=>1, debug=>1, message=>1, note=>1 }, "trun on just note" );

$deep->level( -unset => 'message' );
$level = $deep->level;
is_deeply( $level, { fatal=>1, error=>1, warning=>1, debug=>1, message=>0, note=>1 }, "trun off just message" );

