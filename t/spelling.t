
use strict;
use warnings;
use Test::More;

eval { require Test::Spelling; Test::Spelling->import() };

plan skip_all => "Test::Spelling required for testing POD coverage" if $@;

add_stopwords(qw/CPAN AnnoCPAN RT NSW Hornsby Param Params Arg Plugins plugins pm url CGI analyse colouring Colours coloured ID's/);
all_pod_files_spelling_ok();
