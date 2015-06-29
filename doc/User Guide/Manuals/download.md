# NAME

SeqMule an automatic pipeline for next-generation sequencing data analysis

# SYNOPSIS

seqmule download <options>

For details about each option, please use 'seqmule download -h':

Options:

      --down,-d                 comma-delimited list of databases and BED files by capture kit manufacturer. See details.
      --downdir <dir>           custom download folder. NOT recommended if you want to use default databases.
      -v,--verbose              verbose output. Default: disabled
      -h,--help                 help
      --noclean                 do not clean temporary files
      --debug                   debug mode

# EXAMPLE

      #download all hg19 databases/BEDs to default location (under installation directory)
      seqmule download -down hg19all 

      #same as above, but saved at custom location
      seqmule download -down hg19all -downdir /home/user/database 

# OPTIONS

- **--down**

    The following list gives possible options and their corresponding databases. You can use 'hg19all','hg18all','all' to download all databases corresponding to a specific genome build or all databases. Default location for databases is 'installation\_directory/database/'. 

# DESCRIPTION

SeqMule automatizes analysis of next-generation sequencing data by simplifying program installation, downloading of various databases, generation of analysis script, and customization of your pipeline.
