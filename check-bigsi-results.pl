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
my $false_negatives = 0;
my $false_positives_count = 0;

my $answer;
my ($a_query,$a_qkmer,$a_akmer,$a_score,$a_doc);
sub next_answer_line() {
    do {
        $answer = <A>;
        if (!defined $answer) {
            $a_query = "";
            $a_doc = "";
            return;
        }
        if ($answer =~ /^"query","num_kmers"/) {
            # header line
            $answer = "";
        }
    } while ($answer !~ /^"/);
    # "AGCT",9970,9970,100.0,"SRR1544569.bloom"
    die($answer) unless
        $answer =~ /^"([^"]+)",([0-9]+),([0-9]+),([0-9.]+),"([^"]+)\.bloom"\r\n$/;
    ($a_query,$a_qkmer,$a_akmer,$a_score,$a_doc) = ($1,$2,$3,$4,$5);
    #print "$a_query -> $a_doc\n";
}
next_answer_line();

while (my $info = <Q>) {
    chomp($info);

    my $query = <Q>;
    chomp($query);

    print "Q: $info\n";
    if ($info =~ /^>negative[0-9]+/) {
        ++$negatives;

        # count results
        my $results = 0;
        while ($a_query eq $query) {
            ++$results;
            next_answer_line();
        }

        print "neg: results: $results\n";

        $false_positives++ if $results != 0;
        $false_positives_count += $results;
    }
    elsif ($info =~ /^>doc:[^:]*:[^:]*:[^:]*:(.+)$/) {
        ++$positives;

        my $target = $1;

        # count results
        my $results = 0;
        while ($a_query eq $query) {
            ++$results;
            #print "$a_doc - $target\n";
            if ($a_doc eq $target) {
                print "Target $target matched\n";
                $target = "";
            }
            next_answer_line();
        }

        if ($target) {
            print "Target $target NOT MATCHED!\n";
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

die("has false negatives") if $false_negatives != 0;

exit(0);
