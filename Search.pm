package Circa::Search;

# module Circa::Search : provide function to perform search on Circa
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: Search.pm,v $
# Revision 1.4  2000/09/28 15:56:32  Administrateur
# - Update SQL search method
# - Add + and - to syntax of word search
# - Add search in one categorie only
#
# Revision 1.3  2000/09/25 21:39:44  Administrateur
# - Update possibilities to browse several site on a same database
# - Update navigation by category
# - Use new MCD
#

use DBI;
use DBI::DBD;
use strict;
use CGI qw/:standard :html3 :netscape escape unescape/;
use CGI::Carp qw/fatalsToBrowser/;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
$VERSION = ('$Revision: 1.4 $ ' =~ /(\d+\.\d+)/)[0];

# -------------------
# Template par defaut
my $templateS='"<p>$indiceG - <a href=\"$url\">$titre</a> $description<br> 
		<font class=\"small\"><b>Url:</b> $url <b>Facteur:</b> $facteur
		<b>Last update:</b> $last_update </font></p>\n"';
my $templateC='"<p>$nom_complet<br></p>\n"';
# -------------------

=head1 NAME

Circa::Search - provide functions to perform search on Circa, a www search
engine running with Mysql

=head1 SYNOPSIS

 use Circa::Search;
 my $search = new Circa::Search;
 
 # Connection à MySQL
 if (!$search->connect_mysql("aliansql","pass","my_database","localhost")) 
	{die "Erreur à la connection MySQL:$DBI::errstr\n";}

 # Affichage d'un formulaire minimum
 print 	header,
 	$search->start_classic_html,
 	$search->default_form;
 
 # Interrogation du moteur
 # Sites trouves, liens pages suivantes, nb pages trouvees
 my ($resultat,$links,$indice) = $search->search('informatique internet',0,1);


=head1 DESCRIPTION

This is Circa::Search, a module who provide functions to 
perform search on Circa, a www search engine running with 
Mysql. Circa is for your Web site, or for a list of sites. 
It indexes like Altavista does. It can read, add and 
parse all url's found in a page. It add url and word 
to MySQL for use it at search.

Remarques sur la recherche:

 - Accents are removed on search and when indexed
 - Search are cas unsensitive (mmmh what my english ? ;-)

=head1 VERSION

$Revision: 1.4 $

=cut

sub new {
        my $class = shift;
        my $self = {};
        bless $self, $class;     
	$self->{SCRIPT_NAME} = $ENV{'SCRIPT_NAME'} || 'search.cgi';
	$self->{DBH} = undef;
	$self->{PREFIX_TABLE} = 'circa_';
        $self->{SERVER_PORT}  ="3306"; 	# Port de mysql par default
	$self->{SIZE_MAX}     = 1000000;  # Size max of file read
        return $self;
    }

=head2 port_mysql

Get or set the MySQL port

=cut

sub port_mysql
	{
	my $self = shift;
	if (@_) {$self->{SERVER_PORT}=shift;}
	return $self->{SERVER_PORT};
	}

=head2 prefix_table

Get or set the prefix for table name for use Circa with more than one
time on a same database

=cut

sub prefix_table
	{
	my $self = shift;
	if (@_) {$self->{PREFIX_TABLE}=shift;}
	return $self->{PREFIX_TABLE};		
	}

=head1 Méthodes publiques

=head2 connect_mysql($user,$password,$db)

Connecte l'application à MySQL. Retourne 1 si succes, 0 sinon

 $user     : Utilisateur MySQL
 $password : Mot de passe MySQL
 $db       : Database MySQL
 $server   : Adr IP du serveur MySQL

=cut

sub connect_mysql
	{
	my ($this,$user,$password,$db,$server)=@_;
	my $driver = "DBI:mysql:database=$db;host=$server;port=".$this->port_mysql;
	$this->{DBH} = DBI->connect($driver,$user,$password,{ PrintError => 0 }) || return 0;
	return 1;
	}

sub close_connect {$_[0]->{DBH}->disconnect;}

=head2 search($template,$mot,$first,$id,$langue,$url,$create,$update,$catego)

Fonction permettant d'effectuer une recherche par mot dans Circa

Paramètres :

 $template : Masque HTML pour le resultat de chaque lien. Si undef, le masque par defaut
 (defini en haut de ce module) sera utilise. La liste des variables définies au 
 moment du eval sont : $indiceG,$titre,$description,$url,$facteur,$last_update,$langue
             
  Exemple de masque :
             
  '"<p>$indiceG - <a href=\"$url\">$titre</a> $description<br> 
   <font class=\"small\"><b>Url:</b> $url <b>Facteur:</b> $facteur
   <b>Last update:</b> $last_update </font></p>\n"'
             
 $mot    : Séquence des mots recherchés tel que tapé par l'utilisateur
 first   : Indice du premier site affiché dans le résultat
 $id     : Id du site dans lequel effectué la recherche
 $langue : Restriction par langue (facultatif)
 $Url    : Restriction par url : les url trouvées commenceront par $Url (facultatif)
 $create : Restriction par date inscription. Format YYYY-MM-JJ HH:MM:SS (facultatif)
 $update : Restriction par date de mise à jour des pages. Format YYYY-MM-JJ HH:MM:SS (facultatif)
 $catego : Restriction par categorie (facultatif)
 
Retourne ($resultat,$links,$indice)

 $resultat : Buffer HTML contenant la liste des sites trouves formaté en fonction
             de $template et des mots present dans $mots
 $links    : Liens vers les pages suivantes / precedentes
 $indice   : Nombre de sites trouves

=cut

sub search
	{
	my ($this,$template,$mots,$first,$idc,$langue,$Url,$create,$update,$categorie)=@_;
	$this->{DBH}->do("insert into $idc".$this->prefix_table.$idc."stats(requete) values('$mots')");
	if (!$template) {$template=$templateS;}
	my ($indice,$id,$i,$tab,$nbPage,$links,$resultat,@ind_and,@ind_not,@mots_tmp) = (0,0,$idc);
	$mots=~s/'/ /g;
	my @mots = split(/\s/,$mots);
	if (@mots==0) {$mots[0]=$mots;}
	foreach (@mots) 
		{		
		if    ($_ eq '+') {push(@ind_and,$i);} # Reperage de la position des mots 'and'
		elsif ($_ eq '-') {push(@ind_not,$i);} # Reperage de la position des mots 'not'
		else {push(@mots_tmp,$_);}
		$i++;
		}
	# Recherche SQL
	$tab=$this->search_word($tab,join("','",@mots_tmp),$idc,$langue,$Url,$create,$update,$categorie);
	# On supprime tout ceux qui ne repondent pas aux criteres and si present
	foreach my $ind (@ind_and) {foreach my $url (keys %$tab) {delete $$tab{$url} if (!appartient($mots[$ind],@{$$tab{$url}[5]}));}}
	# On supprime tout ceux qui ne repondent pas aux criteres not si present
	foreach my $ind (@ind_not) {foreach my $url (keys %$tab) {delete $$tab{$url} if (appartient($mots[$ind],@{$$tab{$url}[5]}));}}
	# Tri par facteur
	my @key = reverse sort { $$tab{$a}[2] <=> $$tab{$b}[2] } keys %$tab;
	# Selection des url correspondant à la page demandée
	my $nbResultPerPage= param('nbResultPerPage') || 10; 
	my $lasto = $first + $nbResultPerPage;
	foreach my $url (@key)
 		{
 		my ($titre,$description,$facteur,$langue,$last_update)=@{$$tab{$url}};
 		my $indiceG=$indice+1;
 		if (($indice>=$first)&&($indice<$lasto)) {$resultat.= eval $template;}
 		# Constitution des liens suivants / precedents
		if (!($indice%$nbResultPerPage)) 
			{
			$nbPage++;
			if ($indice==$first) {$links.="$nbPage- ";}
			else {$links.='<a href="'.$this->get_link($indice).'">'.$nbPage.'</a>- '."\n";}
			} 			
		$indice++;
		}	
	if (@key==0) {$resultat="<p>Aucun document trouvé.</p>";}
	return ($resultat,$links,$indice);
	}

=head2 search_word($tab,$word,$idc,$langue,$Url,$create,$update,$categorie)

 $tab    : Reference du hash où mettre le resultat
 $word   : Mot recherché
 $id     : Id du site dans lequel effectué la recherche
 $langue : Restriction par langue (facultatif)
 $Url    : Restriction par url
 $create : Restriction par date inscription
 $update : Restriction par date de mise à jour des pages
 $catego : Restriction par categorie

Retourne la reference du hash avec le resultat de la recherche sur le mot $word
Le hash est constitué comme tel:

      $tab{$url}[0] : titre
      $tab{$url}[1] : description
      $tab{$url}[2] : facteur
      $tab{$url}[3] : langue
      $tab{$url}[4] : date de dernière modification
   @{$$tab{$url}[5]}: liste des mots trouves pour cet url

=cut

sub search_word
	{
	my ($self,$tab,$word,$idc,$langue,$Url,$create,$update,$categorie)=@_;
	# Restriction diverses
	if ($langue) {$langue=" and langue='$langue' ";} else {$langue= ' ';}
	if (($Url)&&($Url ne 'http://')) {$Url=" and url like '$Url%' ";} 	 else {$Url=' ';}
	if ($create) {$create="and unix_timestamp('$create')< unix_timestamp(last_check) ";}  else {$create=' ';}
	if ($update) {$update="and unix_timestamp('$update')< unix_timestamp(last_update) ";} else {$update=' ';}	
	if ($categorie) 
		{
		my @l=$self->get_liste_categorie_fils($categorie,$idc);
		$categorie="and l.categorie in (".join(',',@l).')';
		} 
	else {$categorie=' ';}	

	my $requete = "
		select 	facteur,url,titre,description,langue,last_update,mot 
		from 	".$self->{PREFIX_TABLE}.$idc."links l,".$self->{PREFIX_TABLE}.$idc."relation r 
		where 	r.id_site=l.id 
		and 	r.mot in ('$word')
		$langue $Url $create $update $categorie
		order 	by facteur desc";
		
	my $sth = $self->{DBH}->prepare($requete);
	#print "requete:$requete\n";
	$sth->execute() || print "Erreur $requete:$DBI::errstr\n";		
	while (my ($facteur,$url,$titre,$description,$langue,$last_update,$mot)=$sth->fetchrow_array)
		{
		$$tab{$url}[0]=$titre;
		$$tab{$url}[1]=$description;	
		$$tab{$url}[2]+=$facteur;
		$$tab{$url}[3]=$langue;
		$$tab{$url}[4]=$last_update;
		push(@{$$tab{$url}[5]},$mot);
		}
	return $tab;		
	}

=head2 categories_in_categorie($id,$idr,$template)

Fonction retournant la liste des categories de la categorie $id dans le site $idr

 $id       : Id de la categorie de depart. Si undef, 1 est utilisé (Considéré comme le "Home")
 $idr	   : Id du responsable
 $template : Masque HTML pour le resultat de chaque lien. Si undef, le masque par defaut
             (defini en haut de ce module) sera utlise

Retourne ($resultat,$nom_categorie) :

 $resultat : Buffer contenant la liste des sites formatées en ft de $template
 $nom_categorie : Nom court de la categorie

=cut

sub categories_in_categorie
	{
	my $self=shift;
	my ($id,$idr,$template)=@_;
	if (!$idr) {$idr=1;} 
	if (!$id) {$id=1;}	
	if (!$template) {$template=$templateC;}
	my ($buf,%tab);
	my $sth = $self->{DBH}->prepare("select id,nom,parent from ".$self->{PREFIX_TABLE}.$idr."categorie");
	#print "requete:$requete\n";
	$sth->execute() || print "Erreur $DBI::errstr\n";		
	while (my ($id,$nom,$parent)=$sth->fetchrow_array)
		{
		$tab{$id}[0]=$nom;
		$tab{$id}[1]=$parent;
		}
	foreach my $key (keys %tab)
		{
		my $nom_complet;
		my ($nom,$parent)=($tab{$key}[0],$tab{$key}[1]);
		if ($tab{$key}[1]!=0) {$nom_complet=$self->getParent($key,$idr,%tab);}
		my $links = $self->get_link_categorie($key,$idr);
		if ($parent==$id) {$buf.= eval $template;}
		}
	if (!$buf) {$buf="<p>Plus de catégorie</p>";}
	return ($buf,$tab{$id}[0]);
	}

=head2 sites_in_categorie($id,$idr,$template)

Fonction retournant la liste des pages de la categorie $id dans le site $idr

 $id       : Id de la categorie de depart. Si undef, 1 est utilisé (Considéré comme le "Home")
 $idr	   : Id du responsable 
 $template : Masque HTML pour le resultat de chaque lien. Si undef, le masque par defaut
             (defini en haut de ce module) sera utlise

Retourne le buffer contenant la liste des sites formatées en ft de $template

=cut

sub sites_in_categorie
	{
	my $self=shift;
	my ($id,$idr,$template)=@_;
	if (!$idr) {$idr=1;}
	if (!$id) {$id=1;}	
	if (!$template) {$template=$templateS;}
	my ($buf);
	my $requete = "
	select 	url,titre,description,langue,last_update 
	from 	".$self->{PREFIX_TABLE}.$idr."links 
	where 	categorie=$id";		
	my $sth = $self->{DBH}->prepare($requete);
	$sth->execute() || print "Erreur $requete:$DBI::errstr\n";		
	my ($facteur,$indiceG)=(100,1);
	while (my ($url,$titre,$description,$langue,$last_update)=$sth->fetchrow_array)	{$buf.= eval $template; $indiceG++;}
	if (!$buf) {$buf="<p>Pas de pages dans cette catégorie</p>";}
	return $buf;
	}

=head2 getParent($id,$idr,%tab)

Rend la chaine correspondante à la catégorie $id avec ses rubriques parentes

=cut

sub getParent
	{
	my ($this,$id,$idr,%tab)=@_;	
	my $parent;
	if (($tab{$id}[1]!=0)&&($tab{$id}[0])) {$parent = $this->getParent($tab{$id}[1],$idr,%tab);}	
	if (!$tab{$id}[0]) {$tab{$id}[0]='Home';}
	$parent.="&gt;<a href=\"".$this->get_link_categorie($id,$idr)."\">$tab{$id}[0]</a>";
	return $parent;
	}

=head2 get_link($no_page)

Retourne l'URL correspondant à la page no $no_page dans la recherche en cours

=cut

sub get_link 
	{
	my $self = shift;
	my $buf = $self->{SCRIPT_NAME}."?word=".escape(param('word'))."&id=".param('id')."&first=".$_[0];
	if (param('nbResultPerPage')) {$buf.="&nbResultPerPage=".param('nbResultPerPage');}
	return $buf;
	}

=head2 get_link_categorie($no_categorie,$id)

Retourne l'URL correspondant à la categorie no $no_categorie

=cut

sub get_link_categorie {return $_[0]->{SCRIPT_NAME}."?categorie=$_[1]&id=$_[2]";}

=head2 start_classic_html

Affiche le debut de document (<head></head>)

=cut

sub start_classic_html
	{
	return start_html(
		-'title'	=> 'Circa',
		-'author'	=> 'alian@alianwebserver.com',
		-'meta'		=> {'keywords'=>'circa,recherche,annuaire,moteur',
        	-'copyright'	=> 'copyright 1997-2000 AlianWebServer'},
		-'style'	=> {'src'=>"circa.css"},
		-'dtd'		=> '-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd')."\n";
	}

=head2 fill_template($masque,$vars)

 $masque : Chemin du template
 $vars : hash des noms/valeurs à substituer dans le template

Rend le template avec ses variables substituées.
Ex: si $$vars{age}=12, et que le fichier $masque contient la chaine:

  J'ai <? $age ?> ans, 

la fonction rendra

  J'ai 12 ans,

=cut

sub fill_template
	{
	my ($self,$masque,$vars)=@_;
	open(FILE,$masque) || die "Can't read $masque<br>";
	my @buf=<FILE>;
	close(FILE);
	while (my ($n,$v)=each(%$vars)) 
		{
		if ($v) {map {s/<\? \$$n \?>/$v/gm} @buf;}
		else {map {s/<\? \$$n \?>//gm} @buf;}
		}
	return join('',@buf);
	}

=head2 advanced_form($id)

Affiche un formulaire minimum pour effectuer une recherche sur Circa

=cut

sub advanced_form
	{	
	my $self=shift;
	my ($id)=@_;
	if (!$id) {$id=1;}
	my @l;
	my $sth = $self->{DBH}->prepare("select distinct langue from ".$self->{PREFIX_TABLE}.$id."links");
	$sth->execute() || print "Erreur: $DBI::errstr\n";		
	while (my ($l)=$sth->fetchrow_array) {push(@l,$l);}
	$sth->finish;
	my %langue=(	
  		'da'=>'Dansk',
		'de'=>'Deutsch',
		'en'=>'English',
		'eo'=>'Esperanto',
  		'es'=>'Espanõl',
  		'fi'=>'Suomi', 
		'fr'=>'Francais',  		
  		'hr'=>'Hrvatski',
  		'hu'=>'Magyar',	
		'it'=>'Italiano',
    		'nl'=>'Nederlands',
  		'no'=>'Norsk',
  		'pl'=>'Polski', 
    		'pt'=>'Portuguese', 
  		'ro'=>'Românã', 
    		'sv'=>'Svenska', 
  		'tr'=>'TurkCe', 
		'0'=>'All'
		);
	my $scrollLangue =  
		"Langue :".
		scrolling_list(	-'name'=>'langue',
               		        -'values'=>\@l,
               		        -'size'=>1,
                       		-'default'=>'All',
                       		-'labels'=>\%langue);
	my @lno = (5,10,20,50);
	my $scrollNbPage = "Nombre de resultats par page:".
		scrolling_list(	-'name'=>'nbResultPerPage',
               		        -'values'=>\@lno,
               		        -'size'=>1,
                       		-'default'=>'5');
	my $buf=start_form.
		'<table align=center>'.
		Tr(td({'colspan'=>2}, [h1("Recherche")])).
		Tr(td(	textfield(-name=>'word')."<br>\n".
			hidden(-name=>'id',-value=>1)."\n".
			$scrollNbPage."<br>\n".
			$scrollLangue."<br>\n".
			"Sur le site: ".textfield({-name=>'url',-size=>12,-default=>'http://'})."<br>\n".
			"Modifié depuis le: ".textfield({-name=>'update',-size=>10,-default=>''})."(YYYY:MM:DD)<br>\n".
			"Ajouté depuis le: ".textfield({-name=>'create',-size=>10,-default=>''})."(YYYY:MM:DD)<br>\n"
		     ),
		   td(submit))."\n".
		'</table>'.
		end_form."<hr>";
	my ($cate,$titre)=$self->categories_in_categorie(undef,$id);
	$buf.=	h1("Navigation par catégorie (repertoire)").
		h2("Catégories").$cate.
		h2("Pages").$self->sites_in_categorie(undef,$id);
	return $buf;
	}

=head2 default_form

Affiche un formulaire minimum pour effectuer une recherche sur Circa

=cut

sub default_form
	{	
	my $buf=start_form.
		'<table align=center>'.
		Tr(td({'colspan'=>2}, [h1("Recherche")])).
		Tr(td(	textfield(-name=>'word')."<br>\n".
			hidden(-name=>'id',-value=>1)."\n"),td(submit))."\n".
		'</table>'.
		end_form;
	return $buf;
	}

=head2 get_liste_langue

Retourne le buffer HTML correspondant à la liste des langues disponibles

=cut

sub get_liste_langue
	{
	my %langue=(	
  		'da'=>'Dansk',
		'de'=>'Deutsch',
		'en'=>'English',
		'eo'=>'Esperanto',
  		'es'=>'Espanõl',
  		'fi'=>'Suomi', 
		'fr'=>'Francais',  		
  		'hr'=>'Hrvatski',
  		'hu'=>'Magyar',	
		'it'=>'Italiano',
    		'nl'=>'Nederlands',
  		'no'=>'Norsk',
  		'pl'=>'Polski', 
    		'pt'=>'Portuguese', 
  		'ro'=>'Românã', 
    		'sv'=>'Svenska', 
  		'tr'=>'TurkCe', 
		'0'=>'All'
		);
	my @l =keys %langue;
	return scrolling_list(	-'name'=>'langue',
               		        -'values'=>\@l,
               		        -'size'=>1,
                       		-'default'=>param('langue'),
                       		-'labels'=>\%langue);
        }

=head2 get_name_site($id)

Retourne le nom du site dans la table responsable correspondant à l'id $id

=cut

sub get_name_site
	{
	my($this,$id)=@_;
	my $sth = $this->{DBH}->prepare("select titre from ".$this->{PREFIX_TABLE}."responsable where id=$id");
	$sth->execute() || print "Erreur: $DBI::errstr\n";		
	my ($titre)=$sth->fetchrow_array;
	$sth->finish;
	return $titre;
	}

=head2 get_liste_categorie_fils($id,$idr)

 $id : Id de la categorie parent
 $idr : Site selectionne

Retourne la liste des categories fils de $id dans le site $idr

=cut

sub get_liste_categorie_fils
	{
	my ($self,$id,$idr)=@_;
	sub get_liste_categorie_fils_inner
		{
		my ($id,%tab)=@_;
		my (@l,@l2);
		foreach my $key (keys %tab) {push (@l,$key) if ($tab{$key}[1]==$id);}		
		foreach (@l) {push(@l2,get_liste_categorie_fils_inner($_,%tab));}
		return (@l,@l2);
		}

	my %tab;
	my $sth = $self->{DBH}->prepare("select id,nom,parent from ".$self->{PREFIX_TABLE}.$idr."categorie");
	#print "requete:$requete\n";
	$sth->execute() || print "Erreur $DBI::errstr\n";		
	while (my ($id,$nom,$parent)=$sth->fetchrow_array)
		{
		$tab{$id}[0]=$nom;
		$tab{$id}[1]=$parent;
		}
	return get_liste_categorie_fils_inner($id,%tab);
	}

sub appartient
	{
	my ($elem,@liste)=@_;
	foreach (@liste) {return 1 if ($_ eq $elem);}
	return 0;
	}

=head1 AUTHOR

Alain BARBET alian@alianwebserver.com

=cut

1;