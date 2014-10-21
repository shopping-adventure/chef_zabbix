#!/usr/bin/perl

$first = 1;

print "{\n";
print "\t\"data\":[\n\n";

#for (`ls /srv/sa_riak/shared/data/merge_index`)
for (`du -sh /srv/sa_riak/shared/data/merge_index/*|grep -v "4.0K"| sed 's/\t/\\//g'| sed 's/\\// /g'|rev`)
{
  ($dirname) = m/(\S+)/;

  print "\t,\n" if not $first;
  $first = 0;

  print "\t{\n";
  print "\t\t\"{#RIAKPART}\":\"".reverse($dirname)."\"\n";
  print "\t}\n";
}

print "\n\t]\n";
print "}\n";
