#!/usr/bin/perl

use strict;
use warnings;
use LWP 6.08;
use Image::Info qw(image_type);
use Flickr::API;
use Data::Dumper qw(Dumper);
use Flickr::API::Request;


my $argument = shift();
my $browser = LWP::UserAgent->new;
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
if (not $response->{success}) {
	die "Something gone wrong";
}


open(FILE,"> user_ID")
	or die "Problem $!";
print(FILE Dumper $response->{tree});
close(FILE);


my $user_id;
my $buf_line;

open(FILE,"< user_ID")
	or die "I have some problems $! \n";

my @strings = <FILE>;
foreach my $line (@strings) {
	$buf_line = $line;
	if($buf_line =~ s/^[ ]*'id' => '//) {
		$buf_line =~ s/'$//;
		$user_id = $buf_line;
		last;
	}
}

close(FILE);

chomp($user_id);
print("User ID : $user_id \n");

my $user_name = $argument;
$user_name =~ s/http.+photos\///;
$user_name =~ s/\/.*//;
mkdir $user_name;
chdir $user_name;

my $images_request = Flickr::API::Request->new({
			method => 'flickr.people.getPublicPhotos', 
			args => { 
				api_key => $flickr_api_key,
				user_id => $user_id,
				per_page => 500
			}
		});

my $images_response = $api->execute_request($images_request);

if(not $images_response->{success}) { 
	die "One more problem here $images_response->{error_code}";
}

open(IMAGE_LIST, "> image_list")
	or die "And one more here $!";
print(IMAGE_LIST Dumper $images_response->{tree});
close(IMAGE_LIST);

open(IMAGE_LIST, "< image_list") 
	or die "And here $!";
@strings = <IMAGE_LIST>;
close(IMAGE_LIST);

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
	
		


