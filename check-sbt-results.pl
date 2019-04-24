#!/usr/bin/perl -w

use strict;
use warnings;

my $qfile = shift(@ARGV);
my $afile = shift(@ARGV);

open(Q, "$qfile") or die("First argument: queries.fa");
open(A, "$afile") or die("Second argument: results.txt");

my $false_positives = 0;
my $false_positives_count = 0;
my $false_negatives = 0;

while (my $info = <Q>) {
    chomp($info);

    my $query = <Q>;
    chomp($query);

    print "Q: $info\n";
    if ($info =~ /^>negative[0-9]*/) {
        my $answer = <A>;
        chomp($answer);

        die($answer) unless $answer =~ /^\*$query ([0-9]+)$/;
        my $results = $1;

        $false_positives_count += $results;
        if ($results != 0) {
            print "  false positive\n";
            $false_positives++;
        }

        for(my $r = 0; $r < $results; ++$r) {
            my $match = <A>;
        }
    }
    elsif ($info =~ /^>doc:[^:]*:[^:]*:[^:]*:(.+)$/) {
        my $answer = <A>;
        chomp($answer);

        my $target = $1;

        if ($answer =~ /^\*$query ([0-9]+)$/) {
            my $results = $1;
            for(my $r = 0; $r < $results; ++$r) {
                my $match = <A>;
                die unless $match =~ /^ss?bt\/([^.]+)(\.sim)?\.bf\.bv\.rrr$/;
                if ($1 eq $target) {
                    print "  target $target matched\n";
                    $target = "";
                }
            }

            if ($target) {
                print "  target $target NOT MATCHED!\n";
                $false_negatives++;
            }
        }
        else {
            die($answer);
        }
    }
}

print "false_positives: $false_positives\n";
print "false_positives_count: $false_positives_count\n";
print "false_negatives: $false_negatives\n";

die("has false negatives") if $false_negatives != 0;

exit(0);
