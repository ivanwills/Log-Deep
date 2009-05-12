package Log::Deep::Read;

# Created on: 2008-11-11 19:37:26
# Create by:  ivan
# $Id$
# $Revision$, $HeadURL$, $Date$
# $Revision$, $Source$, $Date$

use strict;
use warnings;
use version;
use Carp;
use Scalar::Util;
use List::Util;
use Data::Dump::Streamer;
use English qw/ -no_match_vars /;
use Readonly;
use Term::ANSIColor;
use Time::HiRes qw/sleep/;
use base qw/Exporter/;

our $VERSION     = version->new('0.0.6');
our @EXPORT_OK   = qw//;
our %EXPORT_TAGS = ();

Readonly my $LEVEL_COLOURS => {
		note     => '',
		message  => '',
		debug    => '',
		warning  => 'yellow',
		error    => 'red',
		fatal    => 'bold red',
		security => '',
	};

Readonly my @colours => qw/
	black
	red
	green
	yellow
	blue
	magenta
	cyan
	white
/;
Readonly my %excludes => map { $_ => 1 } qw/cyangreen greencyan bluemagenta magentablue cyanblue bluecyan greenblue bluegreen/;

sub new {
	my $caller = shift;
	my $class  = ref $caller ? ref $caller : $caller;
	my %param  = @_;
	my $self   = \%param;

	bless $self, $class;

	$self->{short_break}  ||= 2;
	$self->{short_lines}  ||= 2;
	$self->{long_break}   ||= 5;
	$self->{long_lines}   ||= 5;
	$self->{foreground}   ||= 0;
	$self->{background}   ||= 0;
	$self->{sessions_max} ||= 100;

	$self->{dump} = Data::Dump::Streamer->new()->Indent(4);

	return $self;
}

sub read_files {
	my ($self, @files) = @_;
	my %files = map {$_ => { name => $_ }} map { glob $_ } @files;
	my $once = 1;

	while ( $self->{follow} || $once == 1 ) {
		$once++;
		for my $file (keys %files) {
			# process the file for any (new) log lines
			$self->read_file($files{$file});
		}

		# every 1,000 itterations check if there are any new files matching
		# any passed globs in, allows not having to re-run every time a new
		# log file is created.
		if ( $once % 1_000 ) {
			for my $file ( map { glob $_ } @files ) {
				# add the new file only if it doesn't already exist
				$files{$file} ||= { name => $file };
			}
		}
		else {
			# sleep every time we have cycled through all the files to
			# reduce CPU load.
			sleep 0.1;
		}
	}

	return;
}

sub read_file {
	my ($self, $file) = @_;

	if (!$file->{handle}) {
		# TODO implement seeking to end and going back correct number of lines ...
		open $file->{handle}, '<', $file->{name} or warn "Could not open $file->{name}: $!\n" and next;
	}
	my $fh = $file->{handle};

	# read the rest of the lines in the file
	while (my $line = <$fh>) {
		my @line = $self->parse_line($line);

		next if !$self->show_line(@line);

		$self->display_line(@line);
	}

	# reset the file handle so that it can be read again;
	seek $file->{handle}, 0, 1;

	return $file->{handle};
}

sub parse_line {
	my ($self, $line) = @_;

	my @log = split /,/, $line, 5;

	for my $col (@log) {
		$col =~ s/(?<!\\)\\n/\n/g;
		$col =~ s/\\\\/\\/g;
	}

	# re-process the data so we can display what is needed.
	my $DATA;
	eval $log[-1];  ## no critic

	return (@log[0..3], $DATA);
}

sub show_line {
	my ($self, $time, $session, $level, $message, $data) = @_;

	# TODO add real filtering body here

	return 1;
}

sub display_line {
	my ($self, $time, $session, $level, $message, $data) = @_;

	my $last = $self->{last_line_time};
	my $now  = time;
	if ( $self->{breaks} && $now > $last + $self->{short_break} ) {
		my $lines = $now > $last + $self->{long_break} ? $self->{long_lines} : $self->{short_lines};
		print "\n" x $lines;
	}
	$self->{last_line_time} = $now;

	$level = colored $level, $LEVEL_COLOURS->{$level};
	print color $self->session_colour($session);
	print "[$time]";
	print " $session" if $self->{verbose};
	print color 'reset';
	print " $level - $message\n";

	if ($self->{display}) {
		$self->display_data($data);
	}

	return;
}

sub display_data {
	my ($self, $data) = @_;
	my $display = $self->{display};

	FIELD:
	for my $field ( sort keys %{ $display } ) {
		if ( ref $display->{$field} eq 'ARRAY' ) {
			for my $sub_field ( @{ $display->{$field} } ) {
				warn $sub_field;
				print $self->{dump}->Names( $field . '_' . $sub_field )->Data( $data->{$field}{$sub_field} )->Out();
			}
		}
		elsif ( $display->{$field} eq 0 ) {
			next FIELD;
		}
		elsif ( $display->{$field} ne 1 ) {
			$display->{$field} = [ split /,/, $display->{$field} ];
			for my $sub_field ( @{ $display->{$field} } ) {
				warn $sub_field;
				print $self->{dump}->Names( $field . '_' . $sub_field )->Data( $data->{$field}{$sub_field} )->Out();
			}
		}
		elsif ( $field eq 'data' && !defined $data->{data} ) {
			# don't print anything
		}
		else {
			print $self->{dump}->Names($field)->Data($data->{$field})->Out();
		}
	}

	return;
}

sub session_colour {
	my ($self, $session_id) = @_;

	die "No session id supplied!" if !$session_id;

	return $self->{sessions}{$session_id}{colour} if $self->{sessions}{$session_id};

	if ( $self->{background} + 1 < @colours ) {
		$self->{background}++;
	}
	elsif ( $self->{foreground} + 1 < @colours ) {
		$self->{background} = 0;
		$self->{foreground}++;
	}
	else {
		$self->{background} = 0;
		$self->{foreground} = 0;
	}

	if ( $excludes{ $colours[$self->{foreground}] . $colours[$self->{background}] } || $self->{foreground} == $self->{background} ) {
		return $self->session_colour($session_id);
	}

	my $colour = "$colours[$self->{foreground}] on_$colours[$self->{background}]";

	# remove old sessions
	if ( keys %{ $self->{sessions} } > $self->{sessions_max} ) {
		# get max session with the current colour
		my $time = 0;
		for my $session ( keys %{ $self->{sessions} } ) {
			$time = $self->{session}{$session}{time} if $time < $self->{session}{$session}{time} && $self->{session}{$session}{colour} eq $colour;
		}

		# now remove sessions older than $time
		for my $session ( keys %{ $self->{sessions} } ) {
			delete $self->{session}{$session} if $self->{session}{$session}{time} <= $time;
		}
	}

	# cache the session info
	$self->{sessions}{$session_id}{time}   = time;
	$self->{sessions}{$session_id}{colour} = $colour;

	return $colour;
}


1;

__END__

=head1 NAME

Log::Deep::Read - Read and prettily display log files generated by Log::Deep

=head1 VERSION

This documentation refers to Log::Deep::Read version 0.0.6.

=head1 SYNOPSIS

   use Log::Deep::Read;

   # Brief but working code example(s) here showing the most common usage(s)
   # This section will be as far as many users bother reading, so make it as
   # educational and exemplary as possible.

=head1 DESCRIPTION

Provides the functionality to read and analyse log files written by Log::Deep

=head1 SUBROUTINES/METHODS

=head3 C<new ()>

Return: Log::Deep::Read - A new Log::Deep::Read object

Description:

=head3 C<read_files ( @files )>

Param: C<@files> - List of strings - A list of files to be read

Description: Reads and parses all the log files specified

=head3 C<read_file ( $file, $fh )>

Param: C<$file> - string - The name of the file to read

Param: C<$fh> - File Handle - A (possibly) previously open file handle to
$file.

Return: File Handle - The opened file handle

Description: Reads through the lines of $file

=head3 C<parse_line ( $line )>

Param: C<$line> - string - Line from a Log::Deep log file

Return: Array - The elements of the log line

Description: Parses the log line and returns the data that the is stored on
the log line.

=head3 C<show_line ( $time, $session, $level, $message, $data )>

Params: The data for the current log line

Description: Determines if a line should be shown or not (checks the line against the filter)

=head3 C<display_line ( $time, $session, $level, $message, $data )>

Params: The data for the current log line

Description: Actually prints out the line, colouring the out put as necessary.

=head3 C<display_data ( $data )>

Param: C<$data> - hash ref - The data to be displayed

Description: Displays the log lines data based on the display rules set up
when the object was created.

=head3 C<session_colour ( $session_id )>

Params: The session id that is to be coloured

Description: Colours session based on their ID's

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Ivan Wills (ivan.wills@gmail.com).

Patches are welcome.

=head1 AUTHOR

Ivan Wills - (ivan.wills@gmail.com)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009 Ivan Wills (14 Mullion Close, Hornsby Heights, NSW 2077).
All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.  This program is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
