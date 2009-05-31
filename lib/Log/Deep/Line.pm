package Log::Deep::Line;

# Created on: 2009-05-30 21:19:07
# Create by:  Ivan Wills
# $Id$
# $Revision$, $HeadURL$, $Date$
# $Revision$, $Source$, $Date$

use strict;
use warnings;
use version;
use Carp;
use Readonly;
use Data::Dumper qw/Dumper/;
use English qw/ -no_match_vars /;
use base qw/Exporter/;
use Term::ANSIColor;

our $VERSION     = version->new('0.0.1');
our @EXPORT_OK   = qw//;
our %EXPORT_TAGS = ();

Readonly my $LEVEL_COLOURS => {
		info     => '',
		message  => '',
		debug    => '',
		warn  => 'yellow',
		error    => 'red',
		fatal    => 'bold red',
		security => '',
	};

sub new {
	my $caller = shift;
	my $class  = ref $caller ? ref $caller : $caller;
	my ($self, $line, $file) = @_;

	if (ref $self ne 'HASH') {
		$file = $line;
		$line = $self;
		$self = {};
	}

	bless $self, $class;

	$self->parse($line, $file) if $line && $file;

	return $self;
}

sub parse {
	my ($self, $line, $file) = @_;

	# split the line into 5 parts
	# TODO this might cause some problems if the message happens to have a \, in it
	my @log = split /(?<!\\),/, $line, 5;

	if ( @log != 5 && $self->{verbose} ) {
		# get the file name and line number
		my $name    = $file->{name};
		my $line_no = $file->{handle}->input_line_number;

		# output the warnings about the bad line
		warn "The log $name line ($line_no) did not contain 4 columns! Got ". (scalar @log) . " columns\n";
		warn $line if $self->{verbose} > 1;
	}

	# un-quote the individual columns
	for my $col (@log) {
		$col =~ s/ \\ \\ /\\/gxms;
		$col =~ s/ (?<!\\) \\n /\n/gxms;
		$col =~ s/ (?<!\\) \\, /,/gxms;
	}

	# re-process the data so we can display what is needed.
	my $DATA;
	if ( $log[-1] =~ /;$/xms ) {
		local $SIG{__WARN__} = sub {};
		eval $log[-1];  ## no critic
	}
	else {
		warn 'There appears to be a problem with the data on line ' . $file->{handle}->input_line_number . "\n";
		$DATA = {};
	}

	$self->{date}    = $log[0];
	$self->{session} = $log[1];
	$self->{level}   = $log[2];
	$self->{message} = $log[3];
	$self->{DATA}    = $DATA;

	$self->{file}     = $file;
	$self->{position} = $file->{handle} ? tell $file->{handle} : 0;

	return $self;
}

sub id { $_[0]->{session} };

sub colour {
	my ($self, $colour) = @_;

	if ($colour) {
		my ($foreground, $background) = $colour =~ /^ ( \w+ ) \s+ on_ ( \w+ ) $/xms;
		$self->{fg} = $foreground;
		$self->{bg} = $background;
	}

	return "$self->{fg} on_$self->{bg}";
}

sub show {
	my ($self) = @_;

	# TODO add real filtering body here
	return 0 if !$self->{date} || !$self->{session};

	return 1;
}

sub text {
	my ($self) = @_;
	my $out = '';

#	my $last = $self->{last_line_time} || 0;
#	my $now  = time;
#
#	# check if we are putting line breaks when there is a large time between followed file output
#	if ( $self->{breaks} && $now > $last + $self->{short_break} ) {
#		my $lines = $now > $last + $self->{long_break} ? $self->{long_lines} : $self->{short_lines};
#		$out .= "\n" x $lines;
#	}
#	$self->{last_line_time} = $now;

	# construct the log line determining colours to use etc
	my $level = $self->{mono} ? $self->{level} : colored $self->{level}, $LEVEL_COLOURS->{$self->{level}};
	$out .= $self->{mono} ? '' : color $self->colour();
	$out .= "[$self->{date}]";

	if ( !$self->{verbose} ) {
		# add the session id if the user cares
		$out .= " $self->{session}";
	}
	if ( !$self->{mono} ) {
		# reset the colour if we are not in mono
		$out .= color 'reset';
	}

	# finish constructing the log line
	$out .= " $level - $self->{message}\n";

	return $out;
}

sub data {
	my ($self) = @_;
	my $display = $self->{display};
	my @fields;
	my @out;
	my $data = $self->{data};

	# check for any fields that should be displayed
	FIELD:
	for my $field ( sort keys %{ $display } ) {
		if ( ref $display->{$field} eq 'ARRAY' || $display->{$field} ne 1 ) {
			# select the specified sub keys of $field

			if ( !ref $display->{$field} ) {
				# convert the display field into an array so that we can select it's sub fields
				$display->{$field} = [ split /,/, $display->{$field} ];
			}

			# out put each named sub field of $field
			for my $sub_field ( @{ $display->{$field} } ) {
				push @out, $self->{dump}->Names( $field . '_' . $sub_field )->Data( $data->{$field}{$sub_field} )->Out();
			}
		}
		elsif (
			$display->{$field} eq 0        # field explicitly set to false
			|| !defined $display->{$field} # or explicitly undefined
			|| (
				$field eq 'data'           # the field is data
				&& !%{ $data->{data} }     # and there is not data
			)
		) {
			# skip this field
			next FIELD;
		}
		elsif ( !ref $data->{$field} ) {
			# out put scalar values with out the DDS formatting
			my $out .= "\$$field = $data->{$field}";

			# safely guarentee that there is a new line at the end of this line
			chomp $out;
			$out .= "\n";
			push @out, $out;
		}
		else {
			# out put the field normally
			push @out, $self->{dump}->Names($field)->Data($data->{$field})->Out();
		}
	}

	return @out;
}

1;

__END__

=head1 NAME

Log::Deep::Line - Encapsulates one line from a log file

=head1 VERSION

This documentation refers to Log::Deep::Line version 0.1.

=head1 SYNOPSIS

   use Log::Deep::Line;

   # Brief but working code example(s) here showing the most common usage(s)
   # This section will be as far as many users bother reading, so make it as
   # educational and exemplary as possible.


=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=cut

=head3 C<new ( $search, )>

Param: C<$search> - type (detail) - description

Return: Log::Deep::Line -

Description:

=head3 C<parse ( $search, )>

Param: C<$search> - type (detail) - description

Return: Log::Deep::Line -

Description:

=head3 C<id ( $search, )>

Param: C<$search> - type (detail) - description

Return: Log::Deep::Line -

Description:

=head3 C<colour ( $search, )>

Param: C<$search> - type (detail) - description

Return: Log::Deep::Line -

Description:

=head3 C<show ( $search, )>

Param: C<$search> - type (detail) - description

Return: Log::Deep::Line -

Description:

=head3 C<text ( $search, )>

Param: C<$search> - type (detail) - description

Return: Log::Deep::Line -

Description:

=head3 C<data ( $search, )>

Param: C<$search> - type (detail) - description

Return: Log::Deep::Line -

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
