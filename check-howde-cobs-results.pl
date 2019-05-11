#!/usr/bin/perl -w

use strict;
use warnings;

my $afile = shift(@ARGV);

open(A, "$afile") or die("First argument: results.txt");

my $positives = 0;
my $negatives = 0;
my $false_positives = 0;
my $false_positives_count = 0;
my $false_negatives = 0;

while (my $info = <A>) {
    chomp($info);

    if ($info =~ /^\*negative[0-9]*\s+([0-9]+)$/) {
        ++$negatives;

        my $results = $1;
        $false_positives++ if $results != 0;
        $false_positives_count += $results;

        for(my $r = 0; $r < $results; ++$r) {
            my $match = <A>;
        }
    }
    elsif ($info =~ /^\*doc:[^:]*:[^:]*:[^:]*:([^ ]+)\s+([0-9]+)$/) {
        ++$positives;

        my $target = $1;
        my $results = $2;

        for(my $r = 0; $r < $results; ++$r) {
            my $match = <A>;
            chomp($match);
            $match =~ s/\t[0-9]+$//;
            if ($match eq $target) {
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
        print "A: $info\n";
    }
}

print "positives: $positives\n";
print "negatives: $negatives\n";
print "false_positives: $false_positives\n";
print "false_positives_count: $false_positives_count\n";
print "false_negatives: $false_negatives\n";

my $RESULT = $ENV{RESULT} || "";
print "RESULT $RESULT positives=$positives negatives=$negatives false_positives=$false_positives false_positives_count=$false_positives_count false_negatives=$false_negatives\n";

die("has false negatives") if $false_negatives != 0;

exit(0);
