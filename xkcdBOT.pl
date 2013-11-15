#!/usr/bin/perl
#Copyright (C) 2013 by dgbrt.
#
#This library is free software; you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation; either version 3 of the License, or
#(at your option) any later version.
#
#This library is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.


use strict;
use warnings;
use POSIX qw(strftime);
use HTML::Entities;
use MediaWiki::Bot;

my $bot;
my $comic_page;
my $comic_num;
my $comic_name;
my $picture_name;
my $picture_uri;
my $comic_titletext;
my $raw;
my %atts;
my $text;
my $date;
my $day;
my @all_comics_old_list;
my $all_comics_line;


binmode STDOUT, ':utf8';

if ($#ARGV != 1)
{
    print "usage: xkcd username password\n";
    exit;
}

my $user = $ARGV[0];
my $pass = $ARGV[1];


# If the comic was processed, do nothing.
$date = strftime "%Y-%m-%d", localtime;
if (-e "/opt/xkcd/$date.txt")
{
    exit(0);
}


# Get the latest comic and extract the important content
$comic_page = `curl -s http://xkcd.com/`;

($comic_num) = $comic_page =~ /Permanent link to this comic: http:\/\/xkcd.com\/(\d+)/;
($comic_name) = $comic_page =~ /<div id="ctitle">(.*)<\/div>/;
($picture_uri) = $comic_page =~ /Image URL \(for hotlinking\/embedding\): (.*)/;

while( $comic_page =~ /<img\s+([^>]+)>/g )
{
    $raw = $1;
    while( $raw =~ /([^ =]+)\s*=\s*("([^"]+)"|[^\s]+\s*)/g )
    {
	$atts{ $1 } = $3;
    }
    if( $atts{ "src" } eq $picture_uri )
    {
	$comic_titletext = $atts{ "title" };
    }
}

$comic_titletext = decode_entities($comic_titletext);


($picture_name) = $picture_uri =~ /http:\/\/imgs.xkcd.com\/comics\/(.*)/;


# Download the new picture
`curl -s $picture_uri -o /opt/xkcd/$picture_name`;


# Create the file to stop the polling if upload is already done
$date = strftime "%Y-%m-%d", localtime;
open(COMICPAGE, ">/opt/xkcd/$date.txt");
print COMICPAGE "$date\n";
close(COMICPAGE);


# Create the local page file
$day = strftime "%e", localtime;
$date = strftime "%B $day, %Y", localtime;
open(COMICPAGE, ">/opt/xkcd/$comic_num.txt");
print COMICPAGE "{{comic\n";
print COMICPAGE "| number    = $comic_num\n";
print COMICPAGE "| date      = $date\n";
print COMICPAGE "| title     = $comic_name\n";
print COMICPAGE "| image     = $picture_name\n";
print COMICPAGE "| titletext = $comic_titletext\n";
print COMICPAGE "}}\n";
print COMICPAGE "\n";
print COMICPAGE "==Explanation==\n";
print COMICPAGE "{{incomplete}}\n";
print COMICPAGE "\n";
print COMICPAGE "==Transcript==\n";
print COMICPAGE "{{incomplete transcript}}\n";
print COMICPAGE "\n";
print COMICPAGE "{{comic discussion}}\n";
print COMICPAGE "<!-- Include any categories below this line. -->\n";
close(COMICPAGE);

# Log file
$date = strftime "%Y-%m-%d-%H:%M:%S", localtime;
open(COMICLOG, ">>/opt/xkcd/000_comic_log.txt");
print COMICLOG "$date:";
print COMICLOG " $comic_num -";
print COMICLOG " $comic_name -";
print COMICLOG " $picture_name\n";
close(COMICLOG);


# Login to the wiki
$bot = MediaWiki::Bot->new
({
    assert      => 'bot',
    host        => 'explainxkcd.com',
    ##host        => 'localhost',
    path        => '/wiki/api.php',
    debug       => 1, # Turn debugging on, to see what the bot is doing
    login_data  => { username => $user, password => $pass },
})
|| die "Login failed";


# Upload the picture
$bot->upload
({
    file    => "/opt/xkcd/$picture_name",
    title   => "$picture_name"
})
|| die "Picture upload failed";


# Comic name
$text = "#REDIRECT [[$comic_num: $comic_name]]\n";
$bot->edit
({
    page    => $comic_name,
    text    => $text,
    summary => "Created by dgbrtBOT",
})
|| die "Comic name failed";

# Comic number
$text = "#REDIRECT [[$comic_num: $comic_name]]\n";
$bot->edit
({
    page    => $comic_num,
    text    => $text,
    summary => "Created by dgbrtBOT",
})
|| die "Comic number failed";

# Comic page
$day = strftime "%e", localtime;
$day =~ s/^\s+//;
$date = strftime "%B $day, %Y", localtime;
$text = <<END;
{{comic
| number    = $comic_num
| date      = $date
| title     = $comic_name
| image     = $picture_name
| titletext = $comic_titletext
}}

==Explanation==
{{incomplete}}

==Transcript==
{{incomplete transcript}}

{{comic discussion}}
<!-- Include any categories below this line. -->
END

$bot->edit
({
    page    => "$comic_num: $comic_name",
    text    => $text,
    summary => "Created by dgbrtBOT",
})
|| die "Comic page failed";

# Template LATESTCOMIC
$text = "$comic_num\n";
$bot->edit
({
    page    => "Template:LATESTCOMIC",
    text    => $text,
    summary => "Created by dgbrtBOT",
})
|| die "LATESTCOMIC failed";


# List of all comics
$text = $bot->get_text('List of all comics');
@all_comics_old_list = split("\\n", $text);

$text = "";
$date = strftime "%Y-%m-%d", localtime;

my $count = 0;
foreach $all_comics_line (@all_comics_old_list)
{
    $count += 1;
    if ($count == 13)
    {
        $text .= "{{comicsrow|$comic_num|$date|$comic_name}}";
        $text .= "$all_comics_line\n";
    }
    else
    {
        $text .= "$all_comics_line\n";
    }
}

$bot->edit
({
    page    => 'List of all comics',
    text    => $text,
    summary => 'Created by dgbrtBOT',
})
|| die "List of all comics";

