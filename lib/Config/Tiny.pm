package Config::Tiny;

# If you thought Config::Simple was small...

use strict;

# Warning: There is another version line, in t/02.main.t.

our $VERSION = '2.22';

BEGIN {
	require 5.008001;
	$Config::Tiny::errstr  = '';
}

# Create an empty object
sub new { bless {}, shift }

# Create an object from a file
sub read {
	my $class = ref $_[0] ? ref shift : shift;
	my $file  = shift or return $class->_error('No file name provided');

	# Slurp in the file.

	my $encoding = shift;
	$encoding    = $encoding ? "<:$encoding" : '<';
	local $/     = undef;

	open( CFG, $encoding, $file ) or return $class->_error( "Failed to open file '$file' for reading: $!" );
	my $contents = <CFG>;
	close( CFG );

	return $class -> _error("Reading from '$file' returned undef") if (! defined $contents);

	return $class->read_string( $contents );
}

# Create an object from a string
sub read_string {
	my $class = ref $_[0] ? ref shift : shift;
	my $self  = bless {}, $class;
	return undef unless defined $_[0];

	# Parse the file
	my $ns      = '_';
	my $counter = 0;
	foreach ( split /(?:\015{1,2}\012|\015|\012)/, shift ) {
		$counter++;

		# Skip comments and empty lines
		next if /^\s*(?:\#|\;|$)/;

		# Remove inline comments
		s/\s\;\s.+$//g;

		# Handle section headers
		if ( /^\s*\[\s*(.+?)\s*\]\s*$/ ) {
			# Create the sub-hash if it doesn't exist.
			# Without this sections without keys will not
			# appear at all in the completed struct.
			$self->{$ns = $1} ||= {};
			next;
		}

		# Handle properties
		if ( /^\s*([^=]+?)\s*=\s*(.*?)\s*$/ ) {
			$self->{$ns}->{$1} = $2;
			next;
		}

		return $self->_error( "Syntax error at line $counter: '$_'" );
	}

	$self;
}

# Save an object to a file
sub write {
	my $self     = shift;
	my $file     = shift or return $self->_error('No file name provided');
	my $encoding = shift;
	$encoding    = $encoding ? ">:$encoding" : '>';

	# Write it to the file
	my $string = $self->write_string;
	return undef unless defined $string;
	open( CFG, $encoding, $file ) or return $self->_error(
		"Failed to open file '$file' for writing: $!"
		);
	print CFG $string;
	close CFG;

	return 1;
}

# Save an object to a string
sub write_string {
	my $self = shift;

	my $contents = '';
	foreach my $section ( sort { (($b eq '_') <=> ($a eq '_')) || ($a cmp $b) } keys %$self ) {
		# Check for several known-bad situations with the section
		# 1. Leading whitespace
		# 2. Trailing whitespace
		# 3. Newlines in section name
		return $self->_error(
			"Illegal whitespace in section name '$section'"
		) if $section =~ /(?:^\s|\n|\s$)/s;
		my $block = $self->{$section};
		$contents .= "\n" if length $contents;
		$contents .= "[$section]\n" unless $section eq '_';
		foreach my $property ( sort keys %$block ) {
			return $self->_error(
				"Illegal newlines in property '$section.$property'"
			) if $block->{$property} =~ /(?:\012|\015)/s;
			$contents .= "$property=$block->{$property}\n";
		}
	}

	$contents;
}

# Error handling
sub errstr { $Config::Tiny::errstr }
sub _error { $Config::Tiny::errstr = $_[1]; undef }

1;

__END__

=pod

=head1 NAME

Config::Tiny - Read/Write .ini style files with as little code as possible

=head1 SYNOPSIS

	# In your configuration file
	rootproperty=blah

	[section]
	one=twp
	three= four
	Foo =Bar
	empty=

	# In your program
	use Config::Tiny;

	# Create a config
	my $Config = Config::Tiny->new;

	# Open the config
	$Config = Config::Tiny->read( 'file.conf' );
	$Config = Config::Tiny->read( 'file.conf', 'utf8' ); # Neither ':' nor '<:' prefix!
	$Config = Config::Tiny->read( 'file.conf', 'encoding(iso-8859-1)');

	# Reading properties
	my $rootproperty = $Config->{_}->{rootproperty};
	my $one = $Config->{section}->{one};
	my $Foo = $Config->{section}->{Foo};

	# Changing data
	$Config->{newsection} = { this => 'that' }; # Add a section
	$Config->{section}->{Foo} = 'Not Bar!';     # Change a value
	delete $Config->{_};                        # Delete a value or section

	# Save a config
	$Config->write( 'file.conf' );
	$Config->write( 'file.conf', 'utf8' ); # Neither ':' nor '>:' prefix!

	# Shortcuts
	my($rootproperty) = $$Config{_}{rootproperty};

	my($config) = Config::Tiny -> read_string('alpha=bet');
	my($value)  = $$config{_}{alpha}; # $value is 'bet'.

	my($config) = Config::Tiny -> read_string("[init]\nalpha=bet");
	my($value)  = $$config{init}{alpha}; # $value is 'bet'.

=head1 DESCRIPTION

C<Config::Tiny> is a Perl class to read and write .ini style configuration
files with as little code as possible, reducing load time and memory
overhead.

Most of the time it is accepted that Perl applications use a lot
of memory and modules.

The C<*::Tiny> family of modules is specifically intended to provide an ultralight alternative
to the standard modules.

This module is primarily for reading human written files, and anything we write shouldn't need to
have documentation/comments. If you need something with more power move up to L<Config::Simple>,
L<Config::General> or one of the many other C<Config::*> modules.

Lastly, L<Config::Tiny> does B<not> preserve your comments, whitespace, or the order of your config
file.

See L<Config::Tiny::Ordered> (and possibly others) for the preservation of the order of the entries
in the file.

=head1 CONFIGURATION FILE SYNTAX

Files are the same format as for MS Windows C<*.ini> files. For example:

	[section]
	var1=value1
	var2=value2

If a property is outside of a section at the beginning of a file, it will
be assigned to the C<"root section">, available at C<$Config-E<gt>{_}>.

Lines starting with C<'#'> or C<';'> are considered comments and ignored,
as are blank lines.

When writing back to the config file, all comments, custom whitespace,
and the ordering of your config file elements is discarded. If you need
to keep the human elements of a config when writing back, upgrade to
something better, this module is not for you.

=head1 METHODS

=head2 errstr()

Returns a string representing the most recent error, or the empty string.

You can also retrieve the error message from the C<$Config::Tiny::errstr> variable.

=head2 new()

The constructor C<new> creates and returns an empty C<Config::Tiny> object.

=head2 read($filename, [$encoding])

Here, the [] indicate an optional parameter.

The C<read> constructor reads a config file, $filename, and returns a new
C<Config::Tiny> object containing the properties in the file.

$encoding may be used to indicate the encoding of the file, e.g. 'utf8' or 'encoding(iso-8859-1)'.

Do not add a prefix to $encoding, such as '<' or '<:'.

Returns the object on success, or C<undef> on error.

When C<read> fails, C<Config::Tiny> sets an error message internally
you can recover via C<Config::Tiny-E<gt>errstr>. Although in B<some>
cases a failed C<read> will also set the operating system error
variable C<$!>, not all errors do and you should not rely on using
the C<$!> variable.

See t/04.utf8.t and t/04.utf8.txt.

=head2 read_string($string)

The C<read_string> method takes as argument the contents of a config file
as a string and returns the C<Config::Tiny> object for it.

=head2 write($filename, [$encoding])

Here, the [] indicate an optional parameter.

The C<write> method generates the file content for the properties, and
writes it to disk to the filename specified.

$encoding may be used to indicate the encoding of the file, e.g. 'utf8' or 'encoding(iso-8859-1)'.

Do not add a prefix to $encoding, such as '>' or '>:'.

Returns true on success or C<undef> on error.

See t/04.utf8.t and t/04.utf8.txt.

=head2 write_string()

Generates the file content for the object and returns it as a string.

=head1 FAQ

=head2 Why can't I put comments at the ends of lines?

Because a line like:

	key=value # A comment

Sets key to 'value # A comment' :-(.

This conforms to the syntax discussed in L</CONFIGURATION FILE SYNTAX>.

=head2 Why can't I omit the '=' signs?

E.g.:

	[Things]
	my =
	list =
	of =
	things =

Instead of:

	[Things]
	my
	list
	of
	things

Because the use of '=' signs is a type of mandatory documentation. It indicates that that section
contains 4 items, and not 1 odd item split over 4 lines.

=head2 Why do I have to assign the result of a method call to a variable?

This question comes from RT#85386.

Yes, the syntax may seem odd, but you don't have to call both new() and read_string().

Try:

	perl -MData::Dumper -MConfig::Tiny -E 'my $c=Config::Tiny->read_string("one=s"); say Dumper $c'

Or:

	my($config) = Config::Tiny -> read_string('alpha=bet');
	my($value)  = $$config{_}{alpha}; # $value is 'bet'.

Or even, a bit ridiculously:

	my($value) = ${Config::Tiny -> read_string('alpha=bet')}{_}{alpha}; # $value is 'bet'.

=head1 CAVEATS

=head2 Unsupported Section Headers

Some edge cases in section headers are not supported, and additionally may not
be detected when writing the config file.

Specifically, section headers with leading whitespace, trailing whitespace,
or newlines anywhere in the section header, will not be written correctly
to the file and may cause file corruption.

=head2 Setting an option more than once

C<Config::Tiny> will only recognize the first time an option is set in a
config file. Any further attempts to set the same option later in the config
file are ignored.

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Config-Tiny>

For other issues, or commercial enhancement or support, contact the author.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

Maintanence from V 2.15: Ron Savage L<http://savage.net.au/>.

=head1 ACKNOWLEGEMENTS

Thanks to Sherzod Ruzmetov E<lt>sherzodr@cpan.orgE<gt> for
L<Config::Simple>, which inspired this module by being not quite
"simple" enough for me :).

=head1 SEE ALSO

See, amongst many: L<Config::Simple> and L<Config::General>.

See L<Config::Tiny::Ordered> (and possibly others) for the preservation of the order of the entries
in the file.

L<IOD>. Ini On Drugs.

L<IOD::Examples>

L<App::IODUtils>

L<Config::IOD::Reader>

L<Config::Perl::V>. Config data from Perl itself.

L<Config::Onion>

L<Config::IniFiles>

L<Config::INIPlus>

L<Config::Hash>. Allows nested data.

L<Config::MVP>. Author: RJBS. Uses Moose. Extremely complex.

L<Config::TOML>. See next few lines:

L<https://github.com/dlc/toml>

L<https://github.com/alexkalderimis/config-toml.pl>. 1 Star rating.

L<https://github.com/toml-lang/toml>

=head1 COPYRIGHT

Copyright 2002 - 2011 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
