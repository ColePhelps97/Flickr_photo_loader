#!/usr/bin/perl

use strict;
use warnings;
use LWP 6.08;
use Image::Info qw(image_type);
use Flickr::API;
use Data::Dumper qw(Dumper);
use Flickr::API::Request;


my $argument = shift // '';
my $browser = LWP::UserAgent->new();
my $source = $browser->get($argument);
my $image_number = 1;
my $flickr_api_key = '8f4efdbbbf309931c9a58372edbbf732';
my $flickr_api_secret = 'ef5a8d2bc078e920';


my $api = new Flickr::API({
		key => $flickr_api_key, 
		secret => $flickr_api_secret
	});

my $request = Flickr::API::Request->new({
		method => 'flickr.urls.lookupUser', 
		args => { 
			api_key => $flickr_api_key, 
			url => $argument
		}
	});

my $response = $api->execute_request($request);
die "Request failed" unless $response->{success};

$argument =~ m{http.+photos/([^/]+)/.*};
my $user_name = $1 // '';
mkdir $user_name;
chdir $user_name;


open my $FILE, "+>", "user_ID" or die "Problem $!";
print $FILE Dumper $response->{tree};
seek $FILE, 0, 0;

while (<$FILE>) {
	last if $_ =~ m{^\s*'id'\s*=>\s*'([^']*)'};
}
my $user_id = $1 // -1;

close $FILE;

chomp $user_id;
print "User ID : $user_id \n";

my $images_request = Flickr::API::Request->new({
			method => 'flickr.people.getPublicPhotos', 
			args => { 
				api_key => $flickr_api_key,
				user_id => $user_id,
				per_page => 500
			}
		});

my $images_response = $api->execute_request($images_request);
die "getPublicPhotos request failed" unless $images_response->{success};

open my $IMAGE_LIST, "+>", "image_list") or die "image_list $!";
print $IMAGE_LIST Dumper $images_response->{tree};
seek $IMAGE_LIST, 0, 0;

@strings = <$IMAGE_LIST>;
close $IMAGE_LIST;
/* unreadable below */

my $image_source_response;
my $farm;
my $server;
my $photoID;
my $secret;

my $farm_ready = 0;
my $server_ready = 0;
my $photoID_ready = 0;
my $secret_ready = 0;
my $is_attr = 0;


foreach my $line (@strings) {
	$buf_line = $line;
	if($buf_line =~ /'attributes'/) {
		$is_attr = 1;
	}
		
	if($is_attr == 1){
		if($buf_line =~ s/^.*'server' => '// && $server_ready == 0) {
			if($buf_line =~ s/',$//) {
				$server = $buf_line;
				chomp($server);
				$server_ready = 1;
			}
		}
		if($buf_line =~ s/^.*'secret' => '// && $secret_ready == 0) {
			if($buf_line =~ s/',$//) {
				$secret = $buf_line;
				chomp($secret);
				$secret_ready = 1;
			}
		}
		if($buf_line =~ s/^.*'farm' => '// && $farm_ready == 0) {
			if($buf_line =~ s/',$//) {
				$farm= $buf_line;
				chomp($farm);
				$farm_ready = 1;
			}
		}
		if($buf_line =~ s/^.*'id' => '// && $photoID_ready == 0) {
			if($buf_line =~ s/',$//) {
				$photoID= $buf_line;
				chomp($photoID);
				$photoID_ready = 1;
				
			}
		}
		
	}	
	if($is_attr == 1 && $server_ready == 1 && $farm_ready == 1 && $photoID_ready == 1 && $secret_ready == 1) {
			my $url = sprintf("http://farm%s.static.flickr.com/%s/%s_%s.jpg", $farm, $server, $photoID, $secret);
			print($url);
			$image_source_response = $browser->get($url);

			open(IMAGE, "> image.jpg")
				or die "image.jpg problems $!";
			print(IMAGE $image_source_response->content);
			close(IMAGE);

			my $image_type = image_type("image.jpg");
			if($image_type->{file_type} eq 'PNG') {
				print(" : File not found \n");
			} else {
				print(" : OK \n");
				open(IMAGE, "> image_$image_number.jpg") 
					or die "I can't open $image_number image $!";
				print(IMAGE $image_source_response->content);
				close(IMAGE);

				$image_number++;
			} 
			
			$is_attr = 0;
			$server_ready = 0;
			$secret_ready = 0;
			$farm_ready = 0;
			$photoID_ready = 0;
	}		
}
	
		


