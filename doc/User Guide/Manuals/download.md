# NAME

seqmule-download downloads reference genomes, index files, capture region definitions and other databases.

# SYNOPSIS

        seqmule download <options>

# DESCRIPTION

This command downloads specific database files used in analysis, including but not limited to, reference genomes, index for reference, dbSNP database, 1000G indel database, capture region definitions from various manufacturers.

# OPTIONS

        --down,-d               comma-delimited list of databases and BED files by capture kit manufacturer. See details.
        --downdir <dir>         custom download folder. NOT recommended if you want to use default databases.
        -v,--verbose            verbose output. Default: disabled
        -h,--help                       help
        --noclean                       do not clean temporary files
        --debug                 debug mode

# EXAMPLES

        #download all hg19 databases/BEDs to default location (under installation directory)
        seqmule download -down hg19all 

        #same as above, but saved at custom location
        seqmule download -down hg19all -downdir /home/user/database 

# DETAILS

- **--down**

    The following list gives possible options and their corresponding databases. You can use 'hg19all','hg18all','all' to download all databases corresponding to a specific genome build or all databases. Default location for databases is 'installation\_directory/database/'. 
