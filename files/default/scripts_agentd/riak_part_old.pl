#!/usr/bin/perl

$first = 1;

print "{\n";
print "\t\"data\":[\n\n";

#for (`ls /srv/sa_riak/shared/data/merge_index`)
for (`du -sh /srv/sa_riak/shared/data/merge_index/*|grep -v "4.0K"|awk -F"/" '{print $7}'`)
{
    ($dirname) = m/(\S+)/;

    print "\t,\n" if not $first;
    $first = 0;

    print "\t{\n";
    print "\t\t\"{#RIAKPART}\":\"$dirname\"\n";
    print "\t}\n";
}

print "\n\t]\n";
print "}\n";
