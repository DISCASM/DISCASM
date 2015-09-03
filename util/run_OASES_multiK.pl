#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::Bin/../PerlLib");
use Pipeliner;

use Getopt::Long qw(:config posix_default no_ignore_case bundling pass_through);


my $usage = <<__EOUSAGE__;

#################################################################################
#
#  --left_fq <string>    left fastq filename
#  --right_fq <string>   right fastq filename
#
#  --kmers|K <string>      comma-delimited list of kmers to use, ie. "19,23,27,31"
#  --mergeK|M <int>        kmer to perform multi-K assembly merging with.
#
#  --min_length|L <int>    minimum contig length to report.
#
#  --out_dir|O <string>    path to output directory
#
#  optional:
#
#  --no_clean              do not remove the intermediate assembly directories.
#
#################################################################################

__EOUSAGE__

    ;

my $help_flag;
my $left_fq;
my $right_fq;
my $kmers;
my $min_length;
my $output_dir;
my $mergeK;
my $no_clean_flag = 0;

&GetOptions ( 'h' => \$help_flag,
              'left_fq=s' => \$left_fq,
              'right_fq=s' => \$right_fq,
              'kmers|K=s' => \$kmers,
              'mergeK|M=i' => \$mergeK,
              'min_length|L=s' => \$min_length,
              'out_dir|O=s' => \$output_dir,
              'no_clean' => \$no_clean_flag,
    );


if ($help_flag) {
    die $usage;
}

unless ($left_fq && $right_fq && $kmers && $mergeK && $min_length && $output_dir) {
    die $usage;
}

my @kmer_vals = split(/,/, $kmers);
foreach my $k (@kmer_vals) {
    $k =~ s/\s//g;
    unless ($k =~ /^\d+$/) {
        die "Error, kmer value ($k) isn't recognized as a number.  --kmers set to $kmers";
    }
}




main: {
    
    $left_fq = &Pipeliner::ensure_full_path($left_fq);
    $right_fq = &Pipeliner::ensure_full_path($right_fq);
    $output_dir = &Pipeliner::ensure_full_path($output_dir);
    
    unless (-d $output_dir) {
        mkdir $output_dir or die "Error, cannot mkdir $output_dir";
    }
    chdir $output_dir or die "Error, cannot cd to $output_dir";
    
    my $pipeliner = new Pipeliner(-verbose => 1);

    if ($left_fq =~ /\.gz$/) {
        $left_fq = "<(zcat $left_fq)";
    }

    if ($right_fq =~ /\.gz$/) {
        $right_fq = "<(zcat $right_fq)";
    }
    

    my @kmer_assemblies;
    my @dirs_to_cleanup;
    my @checkpoints_to_cleanup;
    
    foreach my $kmer (@kmer_vals) {
        
        my $cmd = "bash -c \"velveth oasesK_$kmer $kmer -fastq -separate $left_fq $right_fq\"";
        $pipeliner->add_commands(new Command($cmd, "oasesK_${kmer}.prep.ok"));
        push (@checkpoints_to_cleanup, "oasesK_${kmer}.prep.ok");

        $cmd = "velvetg oasesK_$kmer -read_trkg yes";
        $pipeliner->add_commands(new Command($cmd, "velvetg.$kmer.ok"));
        push (@checkpoints_to_cleanup, "velvetg.$kmer.ok");

        $cmd = "oases oasesK_$kmer";
        $pipeliner->add_commands(new Command($cmd, "oasesK_$kmer.ok"));
        push (@checkpoints_to_cleanup, "oasesK_$kmer.ok");

        push (@kmer_assemblies, "oasesK_$kmer/transcripts.fa");
        
        push (@dirs_to_cleanup, "oasesK_$kmer");
    }
    
    ## merge the kmer assemblies:
    my $cmd = "velveth mergedAsm $mergeK -long " . join(" ", @kmer_assemblies);
    $pipeliner->add_commands(new Command($cmd, "mergedAsm.velveth.ok"));
    push (@checkpoints_to_cleanup, "mergedAsm.velveth.ok");

    $cmd = "velvetg mergedAsm -read_trkg yes -conserveLong yes";
    $pipeliner->add_commands(new Command($cmd, "mergedAsm.velvetg.ok"));
    push (@checkpoints_to_cleanup, "mergedAsm.velvetg.ok");

    $cmd = "oases mergedAsm -merge yes -min_trans_lgth $min_length";
    $pipeliner->add_commands(new Command($cmd, "mergedAsm.oases.ok"));
    push (@checkpoints_to_cleanup, "mergedAsm.oases.ok");
    
    
    push (@dirs_to_cleanup, "mergedAsm");

    $pipeliner->run();

    ###########
    ## cleanup
    rename("mergedAsm/transcripts.fa", "oases.transcripts.fa");
    
    # purge the directories 
    unless ($no_clean_flag) {
        foreach my $dir (@dirs_to_cleanup) {
            `rm -rf ./$dir`;
        }
        foreach my $chkpt (@checkpoints_to_cleanup) {
            unlink($chkpt);
        }
    }
    
    exit(0);
}


    
