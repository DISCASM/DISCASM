#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::Bin/../PerlLib");
use Pipeliner;

my $usage = "usage: $0 left.fq right.fq output_directory\n\n";

my $left_fq = $ARGV[0] or die $usage;
my $right_fq = $ARGV[1] or die $usage;
my $output_dir = $ARGV[2] or die $usage;



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
    
    my $cmd = "bash -c \"shuffleSequences_fastq.pl $left_fq $right_fq shuffled.fq\" ";
    $pipeliner->add_commands( new Command($cmd, "shuffled.fq.ok"));

    $cmd = "velveth ./DS_oases_out 25 -fastq -shortPaired shuffled.fq";
    $pipeliner->add_commands( new Command($cmd, "velveth.ok"));

    $cmd = "velvetg ./DS_oases_out -ins_length 300 -read_trkg yes";
    $pipeliner->add_commands( new Command($cmd, "velvetg.ok"));

    $cmd = "oases ./DS_oases_out -ins_length 300 -min_trans_lgth 100";
    $pipeliner->add_commands( new Command($cmd, "oases.ok"));
    

    $pipeliner->run();

    ## cleanup
    rename("DS_oases_out/transcripts.fa", "oases.transcripts.fa");
    unlink("shuffled.fq");
    `rm -rf ./DS_oases_out/`;
    

    
    exit(0);
}


    
