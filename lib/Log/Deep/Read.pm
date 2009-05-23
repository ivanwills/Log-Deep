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

our $VERSION     = version->new('0.1.0');
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
	my $once = 1;
	my %files = map {$_ => { name => $_ }} map { sort glob $_ } @files;

	# record the current number of files watched
	$self->{file_count} = keys %files;

	# loop for ever if we are following the log file other wise we loop
	# only one time.
	while ( $self->{follow} || $once == 1 ) {
		# increment $once to keep track of the itteration number
		$once++;

		# itterate over each file found/specified
		for my $file (keys %files) {
			# process the file for any (new) log lines
			if ( !$self->read_file($files{$file}) ) {
				# delete the file if there was nothing to read
				delete $files{$file};
			}
		}

		# exit the loop if there was no data to be read
		last if !%files;

		# turn off tracking last lines/sessions
		$self->{number} = 0;
		$self->{'session-number'} = 0;

		# every 1,000 itterations check if there are any new files matching
		# any passed globs in, allows not having to re-run every time a new
		# log file is created.
		if ( $once % 1_000 ) {
			for my $file ( map { sort glob $_ } @files ) {
				# check that the file still exists
				next if !-e $file;

				# add the new file only if it doesn't already exist
				$files{$file} ||= { name => $file };
			}

			# record the current number of files watched
			$self->{file_count} = keys %files;
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
	my @lines;
	my %sessions;

	# check that we got an actual file
	return if !$file->{name} || !-f $file->{name};

	# check if we have a cached file handle for this file
	if (!$file->{handle}) {
		# open up the file
		open $file->{handle}, '<', $file->{name} or warn "Could not open $file->{name}: $!\n" and return;
	}

	my $fh = $file->{handle};

	# read the rest of the lines in the file
	LINE:
	while (my $line = <$fh>) {
		while ( $line !~ /\n$/xms ) {
			# guarentee that we have a full log line, ie if we read a line before it has been completely written
			$line .= <$fh>;
		}

		# parse the line
		my @line = $self->parse_line( $line, $file );

		# skip displaying the line if it should be filtered out
		next LINE if !$self->show_line(@line);

		# get the display text for the line
		my $line_text = eval { $self->display_line(@line) };

		# check that there were no errors
		if ($EVAL_ERROR) {
			# print the errors
			warn $EVAL_ERROR;

			# go on to the next line
			next LINE;
		}

		# check if we are displaying lines/sessions from the end of the file
		if ($self->{number}) {
			# add the line to end of the lines
			push @lines, $line_text;
		}
		elsif ( $self->{'session-number'} ) {
			# get the session id
			my $session = $line[1];

			# add the session to the list of session if we have not already come accross it
			push @lines, $session if !$sessions{$session};

			# add the line to the session's lines
			$sessions{$session} ||= '';
			$sessions{$session}  .= $line_text;
		}
		else {
			# print any file change info
			$self->changed_file($file);

			# print out the log line
			print $line_text;
		}
	}

	# check if we have any stored lines to print
	if (@lines) {
		# print any file change info
		$self->changed_file($file);

		# check which format we are using
		if ($self->{number}) {
			my $first_line = @lines - $self->{number} <= 0 ? 0 : @lines - $self->{number};
			print @lines[ $first_line .. (@lines - 1) ];
		}
		elsif ( $self->{'session-number'} ) {
			# work out what to do
			my $first_line = @lines - $self->{'session-number'} <= 0 ? 0 : @lines - $self->{'session-number'};
			for my $i ( $first_line .. (@lines - 1) ) {
				print $sessions{$lines[$i]};
			}
		}
	}

	# reset the file handle so that it can be read again;
	seek $file->{handle}, 0, 1;

	return $file->{handle};
}

sub changed_file {
	my ( $self, $file ) = @_;

	# check if we have printed some lines from this file before
	if ( !$self->{last_print_file} || $self->{last_print_file} ne $file ) {
		if ( $self->{file_count} > 1 ) {
			# print out the change in file (same format as tail)
			print "\n==> $file->{name} <==\n";
		}

		# set this file as the last printed file
		$self->{last_print_file} = $file;
	}

	return;
}

sub parse_line {
	my ($self, $line, $file) = @_;

	# split the line into 5 parts
	# TODO this might cause some problems if the message happens to have a \, in it
	my @log = split /(?<!\\),/, $line, 5;

	if ( @log != 5 && $self->{verbose} ) {
		# get the file name and line number
		my $name    = $file->{name};
		my $line_no = $file->{handle}->input_line_number;

		# print out the warnings about the bad line
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
		eval $log[-1];  ## no critic
	}
	else {
		warn "There appears to be a problem with the data";
		$DATA = {};
	}

	return (@log[0..3], $DATA);
}

sub show_line {
	my ($self, $time, $session, $level, $message, $data) = @_;

	# TODO add real filtering body here
	return 0 if !$time || !$session || !$data;

	return 1;
}

sub display_line {
	my ($self, $time, $session, $level, $message, $data) = @_;
	my $out = '';

	my $last = $self->{last_line_time} || 0;
	my $now  = time;

	# check if we are putting line breaks when there is a large time between followed file output
	if ( $self->{breaks} && $now > $last + $self->{short_break} ) {
		my $lines = $now > $last + $self->{long_break} ? $self->{long_lines} : $self->{short_lines};
		$out .= "\n" x $lines;
	}
	$self->{last_line_time} = $now;

	# construct the log line determining colours to use etc
	$level = $self->{mono} ? $level : colored $level, $LEVEL_COLOURS->{$level};
	$out .= $self->{mono} ? $self->session_colour($session) : color $self->session_colour($session);
	$out .= "[$time]";

	if ( !$self->{verbose} ) {
		# add the session id if the user cares
		$out .= " $session";
	}
	if ( !$self->{mono} ) {
		# reset the colour if we are not in mono
		$out .= color 'reset';
	}

	# finish constructing the log line
	$out .= " $level - $message\n";
	$out .= $self->display_data($data);

	return $out;
}

sub display_data {
	my ($self, $data) = @_;
	my $display = $self->{display};
	my $out     = '';

	# check for any fields that should be displayed
	FIELD:
	for my $field ( sort keys %{ $display } ) {
		if ( ref $display->{$field} eq 'ARRAY' || $display->{$field} ne 1 ) {
			# print the specified sub keys of $field

			if ( !ref $display->{$field} ) {
				# convert the display field into an array so that we can print it's sub fields
				$display->{$field} = [ split /,/, $display->{$field} ];
			}

			# out put each named sub field of $field
			for my $sub_field ( @{ $display->{$field} } ) {
				$out .= $self->{dump}->Names( $field . '_' . $sub_field )->Data( $data->{$field}{$sub_field} )->Out();
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
			$out .= "\$$field = $data->{$field}";

			# safely guarentee that there is a new line at the end of this line
			chomp $out;
			$out .= "\n";
		}
		else {
			# out put the field normally
			$out .= $self->{dump}->Names($field)->Data($data->{$field})->Out();
		}
	}

	return $out;
}

sub session_colour {
	my ($self, $session_id) = @_;

	die "No session id supplied!" if !$session_id;

	# return the cached session colour if we have one
	return $self->{sessions}{$session_id}{colour} if $self->{sessions}{$session_id};

	# set the next colour, cycle through backgrounds for each foreground
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

	# check that the colour is not an excluded colour or that background and
	# foreground colours are not the same.
	if (
		$excludes{ $colours[$self->{foreground}] . $colours[$self->{background}] }
		|| $self->{foreground} == $self->{background}
	) {
		# we cannot use this colour so get the next colour in the sequence
		return $self->session_colour($session_id);
	}

	my $colour = "$colours[$self->{foreground}] on_$colours[$self->{background}]";

	# remove old sessions
	# TODO need to get this code working
	if ( 0 && keys %{ $self->{sessions} } > $self->{sessions_max} ) {
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

	# return the colour
	return $colour;
}


1;

__END__

=head1 NAME

Log::Deep::Read - Read and prettily display log files generated by Log::Deep

=head1 VERSION

This documentation refers to Log::Deep::Read version 0.1.0.

=head1 SYNOPSIS

   use Log::Deep::Read;

   # Brief but working code example(s) here showing the most common usage(s)
   # This section will be as far as many users bother reading, so make it as
   # educational and exemplary as possible.

=head1 DESCRIPTION

Provides the functionality to read and analyse log files written by Log::Deep

=head1 SUBROUTINES/METHODS

=head3 C<new ( %args )>

Arg: C<mono> - bool - Display out put in mono ie don't use colour

Arg: C<follow> - bool - Follow the log files for any new additions

Arg: C<number> - int - The number of lines to display from the end of the log file

Arg: C<session-number> - int - The number of sessions to display from the end of the file

Arg: C<display> - hash ref - keys are the keys of the log's data to display
if a true value (or hide if false). The values can also be a comma separated
list (or an array reference) to turn on displaying of sub keys of the field
(requires the filed to be a hash)

Arg: C<filter> - hash ref - specifies the keys to filter (not yet implemented)

Arg: C<verbose> - bool - Turn on showing more verbose log messages.

Arg: C<short_break> - bool - Turn on showing a short break when some time has
passed between displaying log lines (when follow is true)

Arg: C<short_lines> - int - the number lines to print out when a short time
threshold has been exceeded.

Arg: C<long_break> - bool - Turn on showing a short break when a longer time has
passed between displaying log lines (when follow is true)

Arg: C<long_lines> - int - the number lines to print out when a longer time
threshold has been exceeded.

Arg: C<sessions_max> - int - The maximum number of sessions to keep before
starting to remove older sessions

Return: Log::Deep::Read - A new Log::Deep::Read object

Description: Sets up a Log::Deep::Read object to play with.

=head3 C<read_files ( @files )>

Param: C<@files> - List of strings - A list of files to be read

Description: Reads and parses all the log files specified

=head3 C<read_file ( $file, $fh )>

Param: C<$file> - string - The name of the file to read

Param: C<$fh> - File Handle - A (possibly) previously open file handle to
$file.

Return: File Handle - The opened file handle

Description: Reads through the lines of $file

=head3 C<changed_file ( $file )>

Param: C<$file> - hash ref - The file currently being examined

Description: Prints a message to the user that the current log file has
changed to a new file. The format is the same as for the tail command.

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
