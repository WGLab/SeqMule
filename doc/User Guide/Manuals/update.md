# NAME

seqmule-update updates the program and related 3rd party program to latest compatible versions

# SYNOPSIS

        seqmule update [options]

# DESCRIPTION

This command updates SeqMule to latest released version or development version. The 3rd party programs will also be updated accordingly.

# OPTIONS

        --git                   update from GitHub
        --tmpdir <DIR>          temporary folder for storing copy of downloaded stuff. Default is $TMPDIR or /tmp
        -h,--help               help

# EXAMPLES

        #update SeqMule to the latest version hosted on SeqMule website
        seqmule update

        #update SeqMule to the latest version on GitHub
        seqmule update --git

# OPTIONS

- **--git**

    update SeqMule to the latest version available on GitHub. Use this version when you got bugs using the version hosted on SeqMule website or want to try out pre-release new features.
