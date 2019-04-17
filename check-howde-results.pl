#!/usr/bin/perl -w

use strict;
use warnings;

my $afile = shift(@ARGV);

open(A, "$afile") or die("First argument: results.txt");

my $false_positives = 0;
my $false_negatives = 0;

while (my $info = <A>) {
    chomp($info);

    print "A: $info\n";
    if ($info =~ /^\*negative ([0-9]+)$/) {
        my $results = $1;
        $false_positives++ if $results != 0;

        for(my $r = 0; $r < $results; ++$r) {
            my $match = <A>;
        }
    }
    elsif ($info =~ /^*doc:[^:]*:[^:]*:[^:]*:([^ ]+) ([0-9]+)$/) {
        my $target = $1;
        my $results = $2;

        for(my $r = 0; $r < $results; ++$r) {
            my $match = <A>;
            chomp($match);
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
}

print "false_positives: $false_positives\n";
print "false_negatives: $false_negatives\n";

die("has false negatives") if $false_negatives != 0;
