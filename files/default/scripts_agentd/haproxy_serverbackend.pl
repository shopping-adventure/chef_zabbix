#!/usr/bin/perl

$first = 1;

print "{\n";
print "\t\"data\":[\n\n";

for (`cat /etc/haproxy/haproxy.cfg|grep -v default|grep backend|awk {'print \$2'}`)
{
	($backendname) = m/(\S+)/;

	for (`cat /etc/haproxy/haproxy.cfg|grep $backendname | grep server| awk {'print \$2'}`)
	{
		($servername) = m/(\S+)/;
		print "\t,\n" if not $first;
		$first = 0;

		print "\t{\n";
		print "\t\t\"{#HAPBACKENDSERVER}\" : \"$servername\"\n";
		print "\t}\n";
	}
}
print "\n\t]\n";
print "}\n";

