#!/usr/bin/perl -w
#
# Simple perl exmple to interface with module Circa::Search
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.
#
# $Date: 2000/09/16 11:26:09 $
# $Log: search.pl,v $
# Revision 1.1.1.1  2000/09/16 11:26:09  Administrateur
#
#
# Revision 1.1.1.1  2000/09/09 17:08:58  Administrateur
# Release initiale
#

use diagnostics;
use strict;
use Circa::Search;
use Getopt::Long;

my $user = "alian";	# User utilisé
my $pass = "spee/do00"; # mot de passe
my $db 	 = "circa";	# nom de la base de données
my $search = new Circa::Search;

if (@ARGV==0) 
	{
print "Usage: search.pl +word='list of word' [+id=id_site] [+url=url_restric] 
                [+langue=] [+create=] [+update=]\n
+word=w   : Search words w
+id=i     : Restrict to site with responsable with id i
+url=u    : Restrict to site with url beginning with u
+langue=l : Restrict to langue l
+create=c : Only url added after this date c (YYYY/MM/DD)
+update=u : Only url updated after this date u (YYYY/MM/DD)
         ";	
	exit;
	}	  	

my ($id,$url,$langue,$update,$create,$word);
GetOptions ( 	"word=s"   => \$word,
		"id=s"     => \$id,
	  	"url=s"	   => \$url,
	  	"langue=s" => \$langue,
	  	"update=s" => \$update,
	  	"create=s" => \$create);
if (!$id) {$id=1;}

# Connection à MySQL
if (!$search->connect_mysql($user,$pass,$db,"localhost")) 
	{die "Erreur à la connection MySQL:$DBI::errstr\n";}

if (($word) && ($id)) 
	{
	my $ref_hash = $search->search($word,0,$id,$langue,$url,$create,$update);
	my @key = reverse sort { $$ref_hash{$a}[2] <=> $$ref_hash{$b}[2] } keys %$ref_hash;
	my $indice=0;

	# Selection des url correspondant à la page demandée
	foreach my $url (@key)
 		{
 		my ($titre,$description,$facteur,$langue,$last_update)=@{$$ref_hash{$url}};
 		print "$facteur:$url: $titre\n";
		}	
	}
$search->close_connect;