#!/usr/bin/perl -w

use strict;
use warnings;

my $qfile = shift(@ARGV);
my $afile = shift(@ARGV);

open(Q, "$qfile") or die("First argument: queries.fa");
open(A, "$afile") or die("Second argument: results.txt");

my $positives = 0;
my $negatives = 0;
my $false_positives = 0;
my $false_positives_count = 0;
my $false_negatives = 0;

while (my $info = <Q>) {
    chomp($info);

    my $query = <Q>;
    chomp($query);

    print "Q: $info\n";
    if ($info =~ /^>negative[0-9]*/) {
        ++$negatives;

        my $answer = <A>;
        chomp($answer);
        my @a = split('\t', $answer);

        die($answer) unless $a[0] =~ /^transcript# ([0-9]+)$/;
        shift(@a);

        my $results = 0;
        foreach my $a (@a) {
            ++$results if $a;
        }

        $false_positives_count += $results;
        if ($results != 0) {
            print "  false positive\n";
            $false_positives++;
        }
    }
    elsif ($info =~ /^>doc:([^:]*):[^:]*:[^:]*:(.+)$/) {
        ++$positives;

        my $answer = <A>;
        chomp($answer);
        my @a = split('\t', $answer);

        my $target = $1;

        die($answer) unless $a[0] =~ /^transcript# ([0-9]+)$/;
        shift(@a);

        if ($a[$target]) {
            print "  target $target matched\n";
            $target = "";
        }
        else {
            print "  target $target NOT MATCHED!\n";
            $false_negatives++;
        }
    }
}

print "positives: $positives\n";
print "negatives: $negatives\n";
print "false_positives: $false_positives\n";
print "false_positives_count: $false_positives_count\n";
print "false_negatives: $false_negatives\n";

my $RESULT = $ENV{RESULT} || "";
print "RESULT $RESULT positives=$positives negatives=$negatives false_positives=$false_positives false_positives_count=$false_positives_count false_negatives=$false_negatives\n";

print("has false negatives\n") if $false_negatives != 0;

exit(0);
