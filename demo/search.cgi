#!/usr/bin/perl -w
#
# Simple CGI interface to module Circa::Search
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.
#
# $Date: 2000/09/28 15:49:10 $
# $Log: search.cgi,v $
# Revision 1.4  2000/09/28 15:49:10  Administrateur
# Ajout de la recherche dans une categorie seulement Search/demo/search.cgi
# Rajout des undef dans l'appel de search
#
# Revision 1.3  2000/09/25 21:48:02  Administrateur
# Utilisation de fill_template pour la substitution
#
# Revision 1.2  2000/09/22 22:07:25  Administrateur
# Ajout de la navigation par categorie
#
# Revision 1.1.1.1  2000/09/09 17:08:58  Administrateur
# Release initiale
#

use diagnostics;
use strict;
use CGI qw/:standard :html3 :netscape escape unescape/;
use CGI::Carp qw/fatalsToBrowser/;
use Circa::Search;

my $user = "alian";	# User utilisé
my $pass = "spee/do00"; # mot de passe
my $db 	 = "circa";	# nom de la base de données

my $masque = "/home/Administrateur/public_html/Circa/Search/demo/circa.htm";

my $search = new Circa::Search;
print header;
# Connection à MySQL
if (!$search->connect_mysql($user,$pass,$db,"localhost")) 
	{die "Erreur à la connection MySQL:$DBI::errstr\n";}

if ((param('word'))&&(param('id'))) 
	{	
	# Interrogation du moteur et tri du resultat par facteur
	my $mots=param('word');
	my $first = param('first') ||0;
	my ($resultat,$links,$indice) = $search->search(
		undef,$mots,$first,
		param('id')|undef,
		param('langue')|undef,
		param('url')|undef,
		param('create')|undef,
		param('update')|undef,
		param('categorie')|undef
		);
	if ($indice==0) {$resultat="<p>Aucun document trouvé.</p>";}
	if ($indice!=0) {$indice="$indice page(s) trouvée(s)";} else {$indice=' ';}
	# Liste des variables à substituer dans le template
	my %vars = ('resultat' 		=> $resultat,
	    	    'titre'		=> $search->get_name_site(param('id')),
	    	    'listeLiensSuivPrec'=> $links,
	    	    'words'		=> param('word'),
	    	    'id'		=> param('id'),
	    	    'categorie'		=> param('categorie'),
	    	    'listeLangue'	=> $search->get_liste_langue,
	    	    'nb'		=> $indice);
	# Affichage du resultat
	print $search->fill_template($masque,\%vars),end_html;
	}
elsif ((param('categorie'))&&(param('id'))) 
	{
	my ($cates,$titre) = $search->categories_in_categorie(param('categorie'),param('id'));
	my $sites = $search->sites_in_categorie(param('categorie'),param('id'));
	# Substitution dans le template
	my %vars = ('resultat' 		=> h2('Catégories').$cates.h2('Sites').$sites,
	    	    'titre'		=> "la rubrique $titre",
	    	    'words'		=> ' ',
	    	    'categorie'		=> param('categorie'),
	    	    'id'		=> param('id'),
	    	    'listeLangue'	=> $search->get_liste_langue,
	    	    'nb'		=> 0);	    	   
	# Affichage du resultat
	print $search->fill_template($masque,\%vars),end_html;
	}
else {print $search->start_classic_html,$search->advanced_form(param('id')),end_html;}
$search->close_connect;