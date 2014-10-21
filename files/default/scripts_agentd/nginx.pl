#!/usr/bin/perl
# Boris HUISGEN <bhuisgen@hbis.fr>
# Kevin Maziere <kevin@kbrwadventure.com> 

use LWP::UserAgent;

my $URL = "http://172.16.0.211:22222/nginx_status";

#
# DO NOT MODIFY AFTER THIS LINE
#

my $ua = LWP::UserAgent->new(timeout => 15);
my $response = $ua->request(HTTP::Request->new('GET', $URL));

my $active =  -1;
my $reading = -1;
my $writing = -1;
my $waiting = -1;
my $requests = -1;
my $accept = -1;
my $handle = -1;
foreach (split(/\n/, $response->content)) {
  $active = $1 if (/^Active connections:\s+(\d+)/);
  if (/^Reading:\s+(\d+).*Writing:\s+(\d+).*Waiting:\s+(\d+)/) {
    $reading = $1;
    $writing = $2;
    $waiting = $3;
  }

  $accept = $1 if (/^\s+(\d+)\s+(\d+)\s+(\d+)/);
  $handle = $2 if (/^\s+(\d+)\s+(\d+)\s+(\d+)/);
  $requests = $3 if (/^\s+(\d+)\s+(\d+)\s+(\d+)/);
}

print "Active: $active\tRequests: $requests\tReading: $reading\tWriting: $writing\tWaiting: $waiting\tAccept: $accept\tHandle: $handle\n";

