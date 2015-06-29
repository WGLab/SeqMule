# NAME

SeqMule an automatic pipeline for next-generation sequencing data analysis

# SYNOPSIS

seqmule run <script\_file> \[options\]

For details about each option, please use 'seqmule run -h':

Options:

      -n <INT>                  run from step INT
      --sge <TEXT>              run each command via Sun Grid Engine. A template with XCPUX keyword is expected.
      -h,--help                 help

      EXAMPLE

      #continue run from last executed step
      seqmule run your_analysis.script
      
      #run from a certain step
      seqmule run -n 10 your_analysis.script

      #run via Sun Grid Engine (a job scheduling system)
      seqmule run -sge "qsub -V -cwd -pe smp XCPUX" your_analysis.script

# OPTIONS

- **--sge**

    To run commands via Sun Grid Engine, SGE must be installed first. -e, -o will be added automatically. "-S /bin/bash" is added automatically. Do NOT specify -e,-o or -S in the qsub template.

# DESCRIPTION

SeqMule automatizes analysis of next-generation sequencing data by simplifying program installation, downloading of various databases, generation of analysis script, and customization of your pipeline.
