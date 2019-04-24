#!/usr/bin/perl -w

use strict;
use warnings;

my $qfile = shift(@ARGV);
my $afile = shift(@ARGV);

open(Q, "$qfile") or die("First argument: queries.fa");
open(A, "$afile") or die("Second argument: results.txt");

my $false_positives = 0;
my $false_negatives = 0;

my $answer = <A>;
chomp($answer);

while (my $info = <Q>) {
    chomp($info);

    my $query = <Q>;
    chomp($query);

    print "Q: $info\n";
    if ($info =~ /^>negative[0-9]+/) {
        die($answer) unless $answer =~ /^seq[0-9]+\s([0-9]+)$/;

        # count results
        my $results = 0;
        do {
            $answer = <A>;
            chomp($answer);
            ++$results;
        } while ($answer =~ /^squeakr/);
        --$results;

        $false_positives++ if $results != 0;
    }
    elsif ($info =~ /^>doc:[^:]*:[^:]*:[^:]*:(.+)$/) {
        my $target = $1;

        die($answer) unless $answer =~ /^seq[0-9]+\s([0-9]+)$/;

        my $results = 0;
        while(1) {
            $answer = <A>;
            chomp($answer);

            last unless $answer =~ /^squeakr\/([^.]+)\.squeakr\s+([0-9]+)$/;

            if ($1 eq $target) {
                print "Target $target matched\n";
                $target = "";
            }
        }

        if ($target) {
            print "Target $target NOT MATCHED!\n";
            $false_negatives++;
        }
    }
}

print "false_positives: $false_positives\n";
print "false_negatives: $false_negatives\n";

die("has false negatives") if $false_negatives != 0;
