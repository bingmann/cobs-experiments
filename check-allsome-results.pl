#!/usr/bin/perl -w

use strict;
use warnings;

my $qfile = shift(@ARGV);
my $afile = shift(@ARGV);

open(Q, "$qfile") or die("First argument: queries.fa");
open(A, "$afile") or die("Second argument: results.txt");

my $false_positives = 0;
my $false_negatives = 0;

while (my $info = <Q>) {
    chomp($info);

    my $query = <Q>;
    chomp($query);

    print "Q: $info\n";
    if ($info eq ">negative") {
        my $answer = <A>;
        chomp($answer);

        die unless $answer =~ /^\*$query ([0-9]+)$/;
        my $results = $1;

        $false_positives++ if $results != 0;

        $answer = <A>;
        chomp($answer);
        die unless $answer =~ /^#/;

        for(my $r = 0; $r < $results; ++$r) {
            my $match = <A>;
        }
    }
    elsif ($info =~ /^>doc:[^:]*:[^:]*:[^:]*:(.+)$/) {
        my $answer = <A>;
        chomp($answer);

        my $target = $1;

        if ($answer =~ /^\*$query (\d+)$/) {
            my $results = $1;

            $answer = <A>;
            chomp($answer);
            die unless $answer =~ /^#/;

            for(my $r = 0; $r < $results; ++$r) {
                my $match = <A>;
                die unless $match =~ /^allsome\/([^.]+)\.bf\.bv\.rrr$/;
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
        else {
            die($answer);
        }
    }
    else {
        die($info);
    }
}

print "false_positives: $false_positives\n";
print "false_negatives: $false_negatives\n";

die("has false negatives") if $false_negatives != 0;
