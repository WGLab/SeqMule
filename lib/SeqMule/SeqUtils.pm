package SeqMule::SeqUtils;

use strict;
use warnings;
use Carp;

#allowed filetypes
my %FILETYPE = (BAM=>1,FASTQ=>1,VCF=>1);
sub new
{
    my ($class,%arg)=@_;

    $arg{'filetype'} =~ /FASTQ|BAM|VCF/ or croak ("filetype: FASTQ|BAM|VCF\n");

    return bless {
	'file'		=>$arg{'file'} || croak ("No file path\n"),
	'filetype'	=>$arg{'filetype'} || croak ("No file type\n"),
	'sample'	=>$arg{'sample'}	|| croak ("No sample\n"), 
	'parent'	=>$arg{'parent'}, #allow no parent for FASTQ
	'istumor'	=>$arg{'istumor'}	|| croak ("No istumor flag\n"),
	'ancestor'	=>$arg{'ancestor'}	|| 
	croak ("No ancestor\n"), #if no ancestor exists, set to itself
	'rgid'		=>$arg{'rgid'} || croak("No RG ID\n"), 
	'lb'		=>$arg{'lb'} || croak("No Library\n"),
	'pl'    	=>$arg{'pl'} || croak ("No Platform\n"),
    }, $class;
}

sub pl
{
    #get or set pl obj
    my $self = shift;
    my $pl = shift;
    if(defined $pl)
    {
	$self->{pl} = $pl;
    } else
    {
	return $self->{pl};
    }
}
sub lb
{
    #get or set lb obj
    my $self = shift;
    my $lb = shift;
    if(defined $lb)
    {
	$self->{lb} = $lb;
    } else
    {
	return $self->{lb};
    }
}
sub rgid
{
    #get or set rgid obj
    my $self = shift;
    my $rgid = shift;
    if(defined $rgid)
    {
	$self->{rgid} = $rgid;
    } else
    {
	return $self->{rgid};
    }
}
sub ancestor
{
    #get or set ancestor obj
    my $self = shift;
    my $ancestor = shift;
    if(defined $ancestor)
    {
	$self->{ancestor} = $ancestor;
    } else
    {
	return $self->{ancestor};
    }
}
sub istumor
{
    #get or set tumor flag
    my $self = shift;
    my $istumor = shift;
    if(defined $istumor)
    {
	$self->{istumor} = $istumor;
    } else
    {
	return $self->{istumor};
    }
}
sub parent
{
    #get or set parent (where current obj comes from)
    my $self = shift;
    my $parent = shift;
    if(defined $parent)
    {
	$self->{parent} = $parent;
    } else
    {
	return $self->{parent};
    }
}
sub sample
{
    #get or set sample
    my $self = shift;
    my $sample = shift;
    if(defined $sample)
    {
	$self->{sample} = $sample;
    } else
    {
	return $self->{sample};
    }
}
sub filetype
{
    #get or set file path
    my $self = shift;
    my $type = shift;
    if(defined $type)
    {
	if($FILETYPE{$type})
	{
	    $self->{filetype} = $type;
	} else
	{
	    croak("$type is not allowed, use ",keys %FILETYPE," \n");
	}
    } else
    {
	return $self->{filetype};
    }
}
sub file
{
    #get or set file path
    my $self=shift;
    my $file = shift;
    if(defined $file)
    {
	$self->{file} = $file;
    } else
    {
	return $self->{file};
    }
}
1;

=head1 Control

Control: package for managing jobs, reporting errors, and returning results

=head1 SYNOPSIS

use SeqMule::SeqUtils;

my $obj = SeqMule::SeqUtils->new( {	
	'file'		=>'/home/user/data/1.bam',
	'filetype'	=>'BAM',
	'sample'	=>'mysample',
	'parent'	=>$obj_for_fastq,
	'istumor'	=>0,
	'ancestor'	=>$obj_for_fastq,
	'rgid'		=>'READGROUP',
	'lb'		=>'LIBRARY',
	'pl'    	=>'PLATFORM',
});

$obj->file(); #we obtain file path


=head1 AUTHOR

Yunfei Guo

=head1 COPYRIGHT

GPLv3

=cut
