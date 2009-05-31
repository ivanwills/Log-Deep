package Log::Deep::File;

# Created on: 2009-05-30 22:58:50
# Create by:  Ivan Wills
# $Id$
# $Revision$, $HeadURL$, $Date$
# $Revision$, $Source$, $Date$

use strict;
use warnings;
use version;
use Carp;
use Scalar::Util;
use List::Util;
#use List::MoreUtils;
use CGI;
use Data::Dumper qw/Dumper/;
use English qw/ -no_match_vars /;
use base qw/Exporter/;
use overload '""' => \&name;

our $VERSION     = version->new('0.0.1');
our @EXPORT_OK   = qw//;
our %EXPORT_TAGS = ();

sub new {
	my $caller = shift;
	my $class  = ref $caller ? ref $caller : $caller;
	my ($name) = @_;
	my $self   = { name => $name };

	bless $self, $class;

	open $self->{handle}, '<', $name or warn "Could not open $name: $OS_ERROR\n" and return;

	return $self;
}

sub line {
	my ($self) = @_;

	my $fh   = $self->{handle};
	my $line = <$fh>;

	if ($line) {
		while ( $line !~ /\n$/xms ) {
			# guarentee that we have a full log line, ie if we read a line before it has been completely written
			$line .= <$fh>;
		}
	}

	$self->{count}++;

	return $line;
}

sub name { $_[0]->{name} }

sub reset {
	my ($self) = @_;

	# reset the file handle so that it can be read again;
	seek $self->{handle}, 0, 1;

	$self->{count} = 0;

	return;
}

1;

__END__

=head1 NAME

Log::Deep::File - <One-line description of module's purpose>

=head1 VERSION

This documentation refers to Log::Deep::File version 0.1.


=head1 SYNOPSIS

   use Log::Deep::File;

   # Brief but working code example(s) here showing the most common usage(s)
   # This section will be as far as many users bother reading, so make it as
   # educational and exemplary as possible.


=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=cut

=head3 C<new ( $search, )>

Param: C<$search> - type (detail) - description

Return: Log::Deep::File -

Description:

=head3 C<line ( $search, )>

Param: C<$search> - type (detail) - description

Return: Log::Deep::File -

Description:

=head3 C<name ( $search, )>

Param: C<$search> - type (detail) - description

Return: Log::Deep::File -

Description:

=head3 C<reset ( $search, )>

Param: C<$search> - type (detail) - description

Return: Log::Deep::File -

Description:

=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate (even
the ones that will "never happen"), with a full explanation of each problem,
one or more likely causes, and any suggested remedies.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the module, including
the names and locations of any configuration files, and the meaning of any
environment variables or properties that can be set. These descriptions must
also include details of any configuration language used.

=head1 DEPENDENCIES

A list of all of the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules
are part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.

=head1 INCOMPATIBILITIES

A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for system
or program resources, or due to internal limitations of Perl (for example, many
modules that use source code filters are mutually incompatible).

=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of
whether they are likely to be fixed in an upcoming release.

Also, a list of restrictions on the features the module does provide: data types
that cannot be handled, performance issues and the circumstances in which they
may arise, practical limitations on the size of data sets, special cases that
are not (yet) handled, etc.

The initial template usually just has:

There are no known bugs in this module.

Please report problems to Ivan Wills (ivan.wills@gmail.com).

Patches are welcome.

=head1 AUTHOR

Ivan Wills - (ivan.wills@gmail.com)
<Author name(s)>  (<contact address>)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009 Ivan Wills (14 Mullion Close, Hornsby Heights, NSW Australia 2077).
All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.  This program is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
