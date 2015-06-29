# NAME

SeqMule an automatic pipeline for next-generation sequencing data analysis

# SYNOPSIS

seqmule update \[options\]

For details about each option, please use 'seqmule update -h':

Options:

      --git                     update from GitHub
      --tmpdir <DIR>            temporary folder for storing copy of downloaded stuff. Default is $TMPDIR
      or /tmp
      -h,--help                 help

Examples:

      #update SeqMule to the latest version hosted on SeqMule website
      seqmule update

      #update SeqMule to the latest version on GitHub
      seqmule update --git

# OPTIONS

- **--git**

    update SeqMule to the latest version available on GitHub. Use this version when you got bugs using the version hosted on SeqMule website or want to try out pre-release new features.

# DESCRIPTION

SeqMule automatizes analysis of next-generation sequencing data by simplifying program installation, downloading of various databases, generation of analysis script, and customization of your pipeline.
