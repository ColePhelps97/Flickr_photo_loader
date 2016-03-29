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


my $user_name = $response->{hash}{user}{username};
mkdir $user_name;
chdir $user_name;

my $user_id = $response->{hash}{user}{id};

print "User ID : $user_id \n";


my $total_pages = 1;
for(my $current_page = 1; $current_page <= $total_pages; $current_page++) {
	my $images_request = Flickr::API::Request->new({
		method => 'flickr.people.getPublicPhotos', 
		args => { 
			api_key => $flickr_api_key,
			user_id => $user_id,
			per_page => 500,
			page => $current_page
		}
	});
	
	my $images_response = $api->execute_request($images_request);
	die "getPublicPhotos request failed" unless $images_response->{success};

	$total_pages = $images_response->{hash}{photos}{pages};
	
	for(my $image_number = 0;
			$image_number < (int($images_response->{hash}{photos}{total} - $current_page*$images_response->{hash}{photos}{perpage} /
			$images_response->{hash}{photos}{perpage}) != 0 ? 
			$images_response->{hash}{photos}{perpage} : 
			$images_response->{hash}{photos}{total} % $images_response->{hash}{photos}{perpage}); 
			$image_number++) {


		my $url = sprintf("http://farm%s.static.flickr.com/%s/%s_%s.jpg", 
			$images_response->{hash}{photos}{photo}[$image_number]{farm},
			$images_response->{hash}{photos}{photo}[$image_number]{server},
			$images_response->{hash}{photos}{photo}[$image_number]{id},
			$images_response->{hash}{photos}{photo}[$image_number]{secret});
		
		my $number = $image_number+$images_response->{hash}{photos}{perpage}*($current_page-1);
		print("[$number] <-> $url");
		my $image_source = $browser->get($url);

		open(IMAGE, "> image.jpg")
			or die "image.jpg problems $!";
		print(IMAGE $image_source->content);
		close(IMAGE);

		my $image_type = image_type("image.jpg");
		if($image_type->{file_type} eq 'PNG') {
			print(" : File not found \n");
		} else {
			print(" : OK \n");
			open(IMAGE, "> $images_response->{hash}{photos}{photo}[$image_number]{title}.jpg") 
				or die "I can't open $image_number image $!";
			print(IMAGE $image_source->content);
			close(IMAGE);
		} 
	}
}

