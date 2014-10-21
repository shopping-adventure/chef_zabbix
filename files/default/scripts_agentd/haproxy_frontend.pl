#!/usr/bin/perl

$first = 1;

print "{\n";
print "\t\"data\":[\n\n";

for (`cat /etc/haproxy/haproxy.cfg|grep -v default|grep frontend|awk {'print \$2'}`)
{
    ($dirname) = m/(\S+)/;

    print "\t,\n" if not $first;
    $first = 0;

    print "\t{\n";
    print "\t\t\"{#HAFRONTEND}\":\"$dirname\"\n";
    print "\t}\n";
}

print "\n\t]\n";
print "}\n";

